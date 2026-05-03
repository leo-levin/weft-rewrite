# WEFT Runtime Architecture

working notes — not a spec, not a memo

---

## The Core Model

Everything is a signal: `ℝⁿ → ℝ`. A signal is a function from coordinates to a number. Tuples group signals. There is no other type.

The runtime has three components:

- **Resources** — buffers populated from outside the expression evaluator (hardware, files, FFT, etc.)
- **Outputs** — evaluation loops that drive over a coordinate space and write somewhere (display, play, dmx, etc.)
- **Expression evaluator** — shared, works for everything

That's it. No backends. No domain concept. No ownership analysis.

---

## Resources

A resource is anything that puts data into a buffer before outputs run. The buffer is just an array of floats, indexed by normalized coordinates.

Examples:
- camera → 2D buffer, updated each frame by capture session
- mp3 → 1D buffer, loaded once from disk
- microphone → 1D buffer, updated each audio callback
- FFT → 2D buffer (index × frequency), computed from mic buffer

Resources don't know about outputs. Outputs don't know how resources get populated. The runtime populates all resource buffers first, then runs outputs.

The coordinate axes you use to index a resource are just names — `@x`, `@frequency`, `@index`, whatever makes sense for that data. The compiler doesn't assign meaning to coordinate names. The user does.

### Buffer dimensionality

Buffer nodes in the IR carry their dimensionality explicitly:

```
buffer1D(id, [i])
buffer2D(id, [i, j])
buffer3D(id, [i, j, k])
```

The indices are IR nodes — they can be any expression. Mapping from normalized coordinates to buffer indices is the user's responsibility, consistent with WEFT's general philosophy of not hiding the math.

---

## Outputs

An output is an evaluation loop. It:
1. Iterates over its coordinate space
2. Provides concrete values for its grounded coordinates at each point
3. Evaluates the IR expression
4. Writes the result somewhere (screen, audio buffer, DMX packet, etc.)

```swift
protocol Output {
    var coordinates: [String]  // grounded coords this output provides
    func run(root: IRNode, evaluate: (IRNode, [String: Float]) -> Float)
}
```

Examples:
- `display` iterates pixels, provides `@x @y @t`, writes RGBA to screen
- `play` iterates samples, provides `@t @i`, writes floats to audio buffer
- `dmx` iterates 512 channels, provides `@channel`, writes DMX packet at 40Hz

Outputs are wholly separate from resources. An output just calls `evaluate` — it doesn't know or care what buffer reads are inside the expression.

### Slow and fast implementations

The naive output implementation is a tree-walking interpreter — iterate the coordinate space, walk the IR tree at each point, return a value. This is slow but correct and sufficient for validating the architecture.

Fast implementations replace the tree walk with something efficient:
- `display` → Metal compute shader generated from the IR, one thread per pixel
- `play` → CoreAudio render callback, generated Swift closure
- `dmx` → CPU loop, generated C

Same IR in, same values out. The output's fast implementation is a compile-time optimization, not an architectural concept. Metal only handles the pixel evaluation loop — when it hits a buffer read (say, audio data feeding into a visual), it just reads from a pre-populated buffer. The buffer was filled before Metal ran. Buffer reads are array lookups, essentially free.

---

## Expression Evaluator

One recursive function, shared across everything:

```swift
func evaluate(_ node: IRNode, coords: [String: Float], buffers: [ID: Buffer]) -> Float {
    switch node {
    case .num(let f): return f
    case .coord(let name): return coords[name]!
    case .buffer1D(let id, let i): return buffers[id]!.read(evaluate(i, ...))
    case .buffer2D(let id, let i, let j): return buffers[id]!.read(evaluate(i, ...), evaluate(j, ...))
    case .binOp(let op, let a, let b): return op(evaluate(a, ...), evaluate(b, ...))
    case .unOp(let op, let a): return op(evaluate(a, ...))
    case .ifExpr(let c, let t, let e): return evaluate(c, ...) != 0 ? evaluate(t, ...) : evaluate(e, ...)
    case .tuple(let elems): fatalError("tuple reached evaluator — should be destructured upstream")
    case .index(let expr, let i): ... // extract element i from tuple
    }
}
```

The evaluator doesn't know what output is calling it. It doesn't know what resources populated the buffers it reads. It just evaluates expressions.

---

## IR Nodes

```
num(Float)
coord(String)              — @x, @y, @t, @i, @frequency, etc.
buffer1D(ID, i)
buffer2D(ID, i, j)
buffer3D(ID, i, j, k)
binOp(Op, a, b)
unOp(Op, a)
tuple([nodes])
index(node, Int)
ifExpr(cond, then, else)
```

No backend-specific nodes. No domain nodes. No remap node — remapping is just calling a signal at different coordinates, which at the IR level is just `coord` nodes being replaced by expressions via name resolution. No ownership annotations.

Pure signals (no buffer reads, no coord dependencies that don't appear in the pulling output's coordinate set) can be evaluated identically in any output. Sharing is implicit — if two outputs reference the same named signal, the compiler produces the same node ID, and the IR graph naturally represents the sharing.

---

## Feedback / Self-Reference

A self-referential definition like:

```
trail = trail(@t - 1/60) * 0.95
```

is detected during name resolution. When the resolver encounters `trail` while already resolving `trail`, it knows there's a cycle. It:

1. Pre-allocates a buffer ID for `trail` (this happens lazily on cycle detection, single pass)
2. Replaces the self-referential call site with a buffer read: `buffer1D(trailID, [@t - 1/60])`
3. Annotates `trail`'s definition with a write: after evaluating `trail`, write the result back to `trailID`

The resulting IR for `trail`:
```
0: coord(@t)
1: num(1/60)
2: binOp(sub, 0, 1)
3: buffer1D(trailID, [2])    — self-reference, now a buffer read
4: num(0.95)
5: binOp(mul, 3, 4)

roots:
  trail = 5
  write: buffer1D(trailID) ← 5    — written after evaluation each frame
```

The write is not an IR node — it lives in a separate scheduler structure alongside the IR. The scheduler knows: after evaluating node 5 this frame, write its value into `trailID` at the current `@t`.

### Buffer initialization

A feedback buffer needs an initial value for frame 0. Default is 0.0. User-specified initialization is possible but not yet designed.

### Buffer sizing

Buffer size depends on history depth and evaluation rate:
- History depth: inferred from the offset in the self-reference (`1/60` → 1 frame, `1.0` → 60 frames at 60Hz)
- Rate: inferred from which output pulls the signal (`display` → 60Hz, `play` → 44100Hz)

Both fall out of the pull graph. No explicit annotation needed.

---

## The Runtime

Something has to own the loop. It's not an orchestrator coordinating backends — it's just a scheduler. It knows which resources exist, which outputs exist, and what order to run things in.

```swift
class Runtime {
    var resources: [Resource]
    var outputs: [Output]
    var buffers: [ID: Buffer]
    var feedbackWrites: [(ID, IRNode)]

    func tick(time: Float) {
        for resource in resources { resource.populate(buffers, time) }
        for output in outputs { output.run(buffers, time) }
        for (id, node) in feedbackWrites { buffers[id].write(evaluate(node, ...)) }
    }
}
```

The topo sort over outputs (to handle cross-output buffer dependencies) is maybe 20 lines. The complexity that used to live here — swatch graphs, ownership resolution, cross-domain scheduling — is just gone.

Timing is per-output: display runs at 60Hz, play runs at 44100Hz, dmx at 40Hz. Each output has its own tick rate. The runtime schedules them independently.

---

## Scheduling

The runtime schedule is simple:

1. Populate all resource buffers (camera frame, audio input, FFT, etc.)
2. Evaluate all outputs in dependency order
3. Write feedback buffer updates

Step 2 ordering: if `display` reads from a buffer that `play` writes into (cross-output data flow), `play` must run before `display`. This is a topological sort over the output dependency graph, which is built from buffer read/write annotations.

Cross-output data flow is always mediated by a buffer. There is no direct output-to-output dependency. An output reads from a buffer; another output writes to that buffer. The buffer is the seam.

---

## What Disappeared

| Old concept | What replaced it |
|-------------|-----------------|
| Backend | Output (evaluation loop) + Resource (buffer) |
| Ownership analysis | Coordinate provenance — falls out of pull graph |
| Domain (visual/audio) | Just which output is pulling |
| `cache()` special form | Self-reference detected at name resolution |
| `.remap` IR node | Just coord substitution during name resolution |
| Cross-domain buffer management | Buffers between outputs, scheduled by topo sort |
| Backend protocol (4 methods) | Output protocol (iterate + write) |

The key insight: "which backend owns this" was never a semantic question. It was always a consequence of which coordinates a signal depends on and which output is pulling it. Making that explicit eliminated the concept entirely.

---

## Open Questions

- Reductions (`sum(expr for x in 0..1)`) — where do these materialize? This is the one case where a full evaluation pass is genuinely needed before a result can be used. A reduction over a 2D space can't be pulled point-by-point — it needs to run first and write to a buffer. This is the only case that might require explicit materialization in the compiler.

- Multiple outputs pulling the same pure signal at different rates — currently each output just re-evaluates. Is that correct? For pure signals yes. For stateful signals (feedback) the rate matters for buffer sizing and scheduling.

- User-specified initial values for feedback buffers.

- `#param` and `#curve` pragmas — these are just resources. `#param` is a scalar buffer. `#curve` is a 1D buffer the runtime populates from a drawn curve. The compiler sees both as buffer reads.
