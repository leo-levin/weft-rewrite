# Feedback Detection and Resolution

working notes — follows from weft-runtime-architecture-may-2.md

---

## The Problem

Self-referential signals like:

```
trail = (trail where { @t = @t - 1/60 }) * 0.95
```

need special handling. The compiler must:

1. Detect the cycle
2. Break it with a buffer read
3. Record that the buffer needs to be written after evaluation
4. Determine what coordinates index the buffer

---

## Resolution Strategy: Inline During Lowering

No separate resolution pass. Cycle detection happens during lowering with additional state in `Env`:

```swift
struct Env {
    var names: [String: ID] = [:]
    var coords: [String: ID] = [:]
    var funcs: [String: FuncDef] = [:]
    var resolving: [String: [String: ID]] = [:]  // name -> coord snapshot at def start
}
```

When lowering a top-level definition:

1. Snapshot current `env.coords`
2. Add `(name, snapshot)` to `resolving`
3. Lower the body
4. Remove from `resolving`

When lowering a name reference:

- If name is in `resolving` → cycle detected
- Otherwise → look up in `env.names` or re-lower the definition

---

## Buffer Index Determination

At cycle detection, diff current `env.coords` against the snapshot:

```swift
let snapshot = env.resolving[name]!
let reboundCoords = env.coords.filter { (coord, currentID) in
    // Only count as rebound if value actually changed
    // Handles @t = @t case (not a real rebinding)
    if let snapshotID = snapshot[coord] {
        return currentID != snapshotID
    }
    // Coord wasn't in snapshot — check if it's just the raw coord node
    return currentID != builder.getNode(.coord(coord))
}
let indices = reboundCoords.map { $0.value }
```

The rebound coords become the buffer indices:

- `trail where { @t = @t - 1/60 }` → 1D buffer indexed by `@t`
- `signal where { @x = @x - 1; @y = @y - 1 }` → 2D buffer indexed by `@x`, `@y`
- `accum where { foo = foo + 1 }` (no coord rebinding) → 0D buffer (scalar)

---

## Feedback Slots vs Concrete Buffers

The compiler doesn't know which outputs will pull a signal. Outputs are a runtime concept.

**Compiler emits feedback slots:**

```
feedbackRead(slotID, indices: [ID])
```

And records feedback writes in a side table:

```swift
struct IRProgram {
    let builder: IRBuilder
    let roots: [(name: String, id: ID)]
    let feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String])]
}
```

**Runtime instantiates concrete buffers per output:**

When an output is connected to a root:

1. Walk the IR to find all feedback slots reachable from that root
2. Allocate a concrete buffer for each slot, sized for that output's rate
3. During evaluation, `feedbackRead` uses the output's buffer instance
4. After evaluation, feedback writes update the output's buffer instance

This means `display` and `play` can both pull `trail`, and each gets independent feedback state. "Previous value" means "previous value _I_ computed," not "previous value anyone computed."

---

## IR Changes

Add a feedback read node (or flag on existing buffer node):

```swift
enum IRNode: Hashable {
    // ... existing nodes ...
    case feedbackRead(slotID: Int, indices: [ID])
}
```

Or reuse `buffer` with a distinguished ID range for feedback slots.

---

## Edge Cases

### Mutual recursion

```
foo = bar + 1
bar = foo + 1
```

Both get feedback slots. Two 0D buffers ping-ponging. Valid but probably not intended — worth a warning.

### Multiple self-references at different offsets

```
trail = (trail where { @t = @t - 1/60 }) + (trail where { @t = @t - 2/60 })
```

Same slot ID, two reads with different index expressions. Just works.

### Indirect cycle through another def

```
trail = (helper where { @t = @t - 1/60 }) * 0.95
helper = trail + 1
```

When lowering `helper`, we hit `trail` which is in `resolving`. The coord rebinding happened in `trail`'s lowering context, so the diff correctly identifies `@t` as rebound. Only `trail` gets a feedback slot.

### Coord rebound to itself

```
trail = (trail where { @t = 3@t }) * 0.95
```

The filter explicitly checks if the "rebound" value equals the raw coord node. `@t = @t` is a no-op, buffer is 0D.

### Name rebinding involving coords

```
foo = @x - 1
trail = (trail where { foo = foo * 2 }) * 0.1
```

`foo` is rebound, but `foo` is a name, not a coord. The coord `@x` isn't rebound. Buffer is 0D. We only track coord rebindings, not transitive coord dependencies through names.

---

## What the Runtime Needs

From the compiler:

- IR nodes including `feedbackRead(slotID, indices)`
- Feedback write table: `[(slotID, valueNodeID, indexCoords)]`

The runtime then:

1. For each output, find reachable feedback slots
2. Allocate buffers sized by: history depth (inferred from index offsets) × output rate
3. Initialize buffers to 0.0 (or user-specified initial value, future work)
4. On each tick: evaluate IR, then apply feedback writes to that output's buffers

---

## Buffer Sizing

Two options:

**Option A: Require literal offsets**

The compiler only accepts feedback index expressions of the form `@coord - literal` or `@coord + literal`. It extracts the literal offset and records it with the feedback slot. The runtime uses this to compute buffer size: `ceil(offset * outputRate)` frames.

This is restrictive but statically analyzable. `trail where { @t = @t - 1/60 }` works. `trail where { @t = @t - delay }` where `delay` is a signal does not — it's a compile error.

**Option B: Fixed maximum with runtime bounds checking**

The compiler doesn't analyze offsets. The runtime allocates a fixed maximum history (e.g., 1 second at output rate). If an index falls outside the buffer bounds, it's a runtime error (or clamps to the edge).

This is more flexible but wastes memory and fails late.

**Recommendation**: Start with Option A. Literal offsets cover the common cases (fixed frame delays, fixed time shifts). If dynamic offsets prove necessary, revisit.

---

## Open Questions

- **Initial values**: Currently default to 0.0. User-specified initialization not yet designed.

- **Cross-output shared state**: If you genuinely want two outputs to share feedback state, that's not feedback — it's an explicit resource buffer. Not covered here.
