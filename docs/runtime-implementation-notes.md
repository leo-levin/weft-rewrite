# Runtime Implementation Notes

working notes — tracks decisions made during implementation

---

## File Structure

```
runtime/Sources/
  Protocols.swift       # Output, Resource, OutputContext
  BufferStore.swift     # BufferStore protocol, Buffer, ArrayBufferStore
  FeedbackBuffer.swift  # FeedbackBuffer ring buffer
  Evaluator.swift       # evaluate() free function
  Analysis.swift        # coord deps, output DAG, topo sort (not started)
  Runtime.swift         # owns everything, setup + tick (in progress)
```

---

## Design Decisions

### OutputContext

```swift
public struct OutputContext {
    public let evaluate: ([String: Float]) -> [Float]
}
```

Closure captures rootID and outputID internally. Output just provides coords, knows nothing about buffers, feedback, or its own ID.

### Output Protocol

```swift
public protocol Output {
    var rootName: String { get }         // e.g. "display", "play"
    var groundedCoords: [String] { get } // coords this output provides
    func start(context: OutputContext)
    func stop()
}
```

Output declares its rootName. Runtime binds it to the corresponding root ID at registration time. Registration throws `RuntimeError.unknownRoot` if rootName doesn't exist in the program.

### Resource Protocol

```swift
public protocol Resource {
    var writes: [BufferID] { get }  // buffers this resource populates
    var reads: [BufferID] { get }   // buffers this resource needs as input
    func start(buffers: BufferStore)
    func sync(time: Float)
    func stop()
}
```

Resources are topo-sorted by reads/writes edges before sync is called. Async resources (mic) push to buffers continuously; sync() is a no-op. Polled resources (camera, FFT) do their work in sync().

### Buffer vs FeedbackBuffer

Two distinct types — fundamentally different access patterns:

| Type | Indexing | Use case |
|------|----------|----------|
| `Buffer` | Normalized [0,1], spatial | Camera, FFT, #curve |
| `FeedbackBuffer` | Absolute offset, ring | Self-reference history |

### BufferStore

Protocol, not concrete struct — allows future MetalBufferStore without changing consumers.

```swift
public protocol BufferStore {
    func read(_ id: BufferID, at indices: [Float]) -> Float
    mutating func write(_ id: BufferID, at indices: [Float], value: Float)
    mutating func allocate(_ id: BufferID, shape: [Int], fill: Float)
    func exists(_ id: BufferID) -> Bool
}
```

Buffer shape is `[Int]` — arbitrary dimensionality. `[]` = scalar, `[512]` = 1D, `[1920, 1080]` = 2D. Row-major indexing with clamp-to-edge bounds.

### FeedbackBuffer

```swift
public struct FeedbackBuffer {
    public var data: [Float]
    public var writeHead: Int = 0

    public func read(offset: Int) -> Float  // offset >= 1, 1 = most recent
    public mutating func write(value: Float)
}
```

writeHead points to next slot to write. offset 1 = most recent written value. offset 0 is invalid (precondition enforces offset >= 1).

### Evaluator

Free function with inner `eval()` closure to avoid repeating context parameters on every recursive call:

```swift
public func evaluate(
    _ id: ID,
    nodes: [IRNode],
    coords: [String: Float],
    buffers: some BufferStore,
    feedbackBuffers: [Int: FeedbackBuffer]  // read-only, immutability enforced by value type
) -> [Float]
```

Returns `[Float]` throughout — scalars are `[x]`, tuples are `[a, b, c]`.

### Feedback Buffers are Per-Output

Each output gets independent feedback state. `display` and `play` can both pull `trail` and each tracks its own history. Keyed by OutputID (opaque int assigned at registration), not rootName.

### Double Buffering

Resources write to `backBuffers`. Outputs read from `frontBuffers`. Runtime.tick() syncs resources then swaps front/back. Outputs always read a consistent snapshot from the previous frame.

```swift
public func tick(time: Float) {
    for resource in topoSortedResources {
        resource.sync(time: time)  // writes to backBuffers
    }
    swap(&frontBuffers, &backBuffers)
}
```

On Apple Silicon, swap is pointer swap — essentially free.

### Feedback Buffer Sizing

Requires literal offset recorded in IRProgram.feedbackWrites. IRProgram needs to be updated:

```swift
feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String], offset: Float)]
```

Runtime then computes: `max(1, ceil(offset * outputRate))`.

### Setup Order

```
Runtime.init(program:)
  1. Build output DAG (Analysis)

Runtime.start()
  2. Start outputs → learn their rates
  3. Allocate feedback buffers per output: ceil(offset * rate)
  4. Start resources (each allocates its spatial buffers into backBuffers)

Runtime.tick()
  5. Sync resources → swap buffers → outputs evaluate from frontBuffers
```

---

## Open / Not Started

- **Analysis.swift**: coord dependency walk, output binding, resource topo sort, output DAG
- **Runtime.swift**: full implementation — structure agreed on, not written yet
- **feedbackBufferSize**: needs `offset` field added to IRProgram.feedbackWrites in the compiler
- **Who calls tick()?** Probably tied to a CADisplayLink or fastest frame-synced resource
- **Thread safety**: deferred — double buffering handles the read/write race, but feedbackBuffers are still mutable and shared
