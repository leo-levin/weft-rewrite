All projects
WEFT 2
I am building a MEDIA-AGNOSTIC programming language for creative coding.
Show more

How can I help you today?

Building a SWIFT parser with swift-parsing
Last message 1 minute ago
Timeline for new wefts and packs setup
Last message 20 minutes ago
Extending WEFT for financial data applications
Last message 53 minutes ago
Swift AST classes for new syntax
Last message 1 day ago
Bayer dithering implementation equivalence
Last message 1 day ago
WEFT language grammar in Ohm.js
Last message 1 day ago
💬 what would be a RADICAL altern…
Last message 1 day ago
Designing a domain-agnostic IR for transpilation
Last message 6 days ago
WEFT's memory model scalability
Last message 7 days ago
MediaPipe backend implementation
Last message 7 days ago
Recent notation design decisions
Last message 8 days ago
Extending WEFT with an embedded language
Last message 9 days ago
Why hasn't WEFT been built before?
Last message 18 days ago
Exploring contemporary media art and design
Last message 18 days ago
WEFT demo: audio-visual partitioner bug
Last message 25 days ago
WEFT partitioner necessity and monad architecture
Last message 29 days ago
Standard library as language multiplier
Last message 29 days ago
DMX backend implementation strategy
Last message 29 days ago
WEFT demo program ideas for YC video
Last message 30 days ago
Blog section for Weft.media site
Last message 1 month ago
Music-reactive gradient breathing animation
Last message 1 month ago
WEFT semantics in JavaScript
Last message 1 month ago
Weft's liveness advantage over TouchDesigner
Last message 1 month ago
Programming language choice for WEFT beta
Last message 1 month ago
Weft domains as monads
Last message 1 month ago
Writing distortion effects in WEFT
Last message 1 month ago
Screen recording on Mac without cursor
Last message 1 month ago
Correcting strands and bundles terminology
Last message 1 month ago
FRP vs WEFT differences
Last message 1 month ago
Orthogonality and linear independence in WEFT
Last message 1 month ago
Memory
Only you
Purpose & context Leo is a third-year UChicago student building WEFT, a domain-agnostic creative coding language where everything is a signal (ℝⁿ → ℝ), and LOOM, its associated IDE. The core premise: the same signal semantics drive audio, visual, DMX, OSC, and other outputs, with a compiler that automatically partitions a unified signal graph across backends. WEFT is a serious, long-running technical project — Leo has an existing ~13k line Swift codebase, a Haskell reference implementation for semantic verification, and a language website at weft.media. Leo's design philosophy throughout: find the minimal coherent foundation, treat ergonomic syntax as earned sugar over that foundation, push back on over-engineering, and prefer semantic honesty over clever abstraction. He communicates tersely and evaluates proposals quickly, often with brief aesthetic judgments rather than detailed critiques. Key people: Marc Downie (Associate Professor of Practice at UChicago MADD, marcdownie@uchicago.edu) — identified as the top contact given his background building Field, an open-source creative coding environment. Leo has connections in the AV installation world and is interested in fitting WEFT into real creative workflows beyond his own. --- Current state Leo has been through a major architectural rethink. The most recent direction: Compiler architecture: Targeting a significant reduction from ~13k lines by eliminating ownership analysis (replaced by coordinate provenance tracing), pattern block compilation (replaced by where + destructuring), and the two separate backend compilers (replaced by one shared recursive expression traversal with a four-method backend protocol). After the runtime resolves pragmas, feedback buffers, and cross-domain signals into named buffers pre-compilation, backends only need to handle four leaf types: Coord, Buffer, Reduce, Sink. All arithmetic, conditionals, function calls, and tuple operations are shared. Syntax redesign: Converged on a unified design where name(params) = expr is the single definition form for both signals and functions; where handles local decomposition; signal(coords) replaces the ~ remap operator; @x/@y/@t replace me.x/me.y/me.t as runtime coordinate sigils; tuples replace bundle declarations; destructuring replaces named strand access; self-reference at past coordinates replaces cache(). Pattern blocks, spindle, return.N, and ~ all disappear. Geometric primitives identified as: remap (pullback/coordinate transformation), integrate (for construct: sum(expr for x in 0..1, y in 0..1)), and differentiate — the fundamental operations of calculus on signal fields. #curve pragma designed alongside #param, allowing drawn curves in LOOM to be first-class signals. Two markdown documents produced: a full syntax/design notes document and a compiler/runtime architecture document. Enrolled in (or pursuing enrollment in) MADD 26210 with Marc Downie's section. --- On the horizon Implementing the revised compiler architecture in Swift Standard library development — Leo has nine modules as a current foundation; each new primitive multiplies the expressive surface of everything already present MediaPipe backend (mp): assessed as relatively simple — a thin backend registering the mediapipe() builtin, writing scalar values (broadcast as constant fields across visual coordinate space) into shared buffers each frame; roughly a weekend of work DMX backend: also ~weekend scope after partitioner is complete; maps onto Audio backend structure with me.channel (0–511) and me.t coordinates Headless Linux runtime: tractable near-term goal, requiring only a WGPU backend and portable audio backend (no IDE work needed; Swift compiler/IR already platform-agnostic) LOOM live performance interface: A/B deck model with two text fields and a mixer, preset swatches as panic/recall, beat-synced vs. smooth cuts for audio FFT/DFT support: spectrogram as a pre-computed 2D shared buffer identified as the best path Signal tinting in LOOM editor: hovering over output highlights code with colors reflecting signal values at that coordinate; essentially free on Apple Silicon unified memory via a side buffer piggybacking on the Metal render pass --- Key learnings & principles Semantic honesty over convenience: Language constructs should mean what they appear to mean; features that create uncanny valleys (e.g., JS-style surface syntax with non-JS semantics) are worse than honest complexity. Everything derives from me: All leaves in the expression tree are coordinate sigils, numeric literals, or hardware access functions; cache is the only stateful exception. Bundles, patterns, spindles, and remapping are different scoping/composition tools over the same core primitive. Spindles and bundles are the same concept: A spindle is a bundle that hasn't received its inputs yet; this insight drove the unified name(params) = expr form. The ~ remap operator is genuinely novel: Equivalent to the Reader monad's local — modifying an implicit environment for a sub-computation — and cannot be desugared away. (Now replaced by signal(coords) syntax in the current design.) Remap-as-cache: Temporal remaps like signal(me.t ~ me.t - 5) can make statefulness invisible infrastructure; most users shouldn't need to see cache() directly. Partitioner simplification: After backends own only the four leaf types, the partitioner reduces to a single graph walk over coordinate provenance rather than full ownership inference. WEFT's memory ceiling is architectural: The signal model (every strand as a pure function of coordinates) is load-bearing for the language's elegance and DAG-based partitioner tractability. Writable shared memory (needed for cellular automata, reaction-diffusion, FFT, reverb, global reductions) is genuinely incompatible — the ceiling is architectural, not implementational. Cross-backend value passing already works via fixed-topology swatch output buffers (audio writes, visual reads), extensible to additional backends as long as data flows as a DAG with no write-back. Lua/scripting as just another backend: Framing an embedded scripting layer as a buffer-producing, load-time source backend (wavetables, lookup tables, procedural textures) — rather than a general escape hatch — is the clean architectural path. Standard library motivation: WEFT's design is C-shaped (small and foundational); the right target is between C's minimalism and Python's maximalism — enough for someone to make something expressive quickly without prescribing an aesthetic. --- Approach & patterns Iterates rapidly on language design in conversation, testing proposals against concrete code examples and aesthetic intuitions Uses a Haskell reference implementation to verify semantic correctness and locate divergences in the Swift compiler Tests code directly, sharing compiler output, IR logs, and generated Metal shaders to diagnose issues Prefers switching files over live-typing complex changes during demos Documentation philosophy: concise, confident prose that builds concepts progressively through concrete examples; avoids "AI marketing copy" and hand-holding; targets the tone of Swift/Rust/Go documentation Demo philosophy: communicate creativity first, technical capability second; start with something already running rather than building up to it --- Tools & resources Implementation: Swift (compiler, IR, runtime — platform-agnostic), Metal (visual backend / GPU shaders), CoreAudio (audio backend), Apple Silicon unified memory Reference implementation: Haskell with aeson (JSON parsing) and QuickCheck (property-based testing) IDE: LOOM (custom, SwiftUI) Cross-platform path: wgpu/WGSL identified as the Metal swap for portability Reference tools/environments: Faust, Hydra, TouchDesigner, Strudel/TidalCycles, Renkon, Max/MSP — surveyed as competitive landscape; Marc Downie's Field (Field2, Java/Kotlin, active on GitHub) as closest analog for canvas-as-score and notation concepts Project site: weft.media
Last updated 22 hours ago
Instructions
Add instructions to tailor Claude’s responses
Files
2% of project capacity used

weft-design-notes.md
337 lines
MD

weft-compiler-architecture.md
427 lines
MD

updates
32 lines
TEXT

outline.md
121 lines
MD

catalog.md
374 lines
MD

Current implementation overview
161 lines
TEXT

weft-effects-research-2.md
405 lines
MD

Proto 2 Syntax
282 lines
TEXT

weft-compiler-architecture.md
17.20 KB •427 lines
Formatting may be inconsistent from source

# WEFT Compiler & Runtime Architecture

## New Design

---

## Overview

The new syntax and semantics enable a dramatically simpler compiler. The key insight: with `signal(coords)` unifying function call and remap, `where` replacing pattern blocks, and feedback/pragma signals resolved by the runtime before compilation, the backend never needs to handle anything except a flat expression tree with four leaf types.

The result is one shared compiler written once, plus a tiny per-backend translation layer. Two full backend compilers (MetalCodeGen, AudioCodeGen) become one shared recursive traversal with swappable leaves.

**Estimated total: ~4000-4500 lines vs current ~13k.**

The reduction comes from specific eliminations:

- Pattern block compilation (~1500-2000 lines): `..` expansion, reshape logic, full-body blocks, external references. All gone — replaced by `where` + destructuring which the shared name resolution handles.
- Ownership analysis + purity analysis (~1000-1500 lines): replaced by coordinate provenance tracing, ~200-300 lines.
- Two separate backend compilers (~2000-3000 lines combined): replaced by one shared expression compiler (~500 lines) + two small leaf translators (~300-500 lines each).
- `spindle` as a separate compilation path: gone, functions and signals compile identically.
- `cache()` special form handling (~500-800 lines): replaced by self-reference detection during name resolution + buffer allocation.

What stays the same size: parser, runtime scheduler, buffer management, LOOM integration.

---

## The Core Architectural Shift

**Current design:** Two full compilers (Metal, CoreAudio) that each handle similar-but-different IR shapes. A bug in pattern block handling manifests differently per backend. Adding a new backend means writing a new compiler.

**New design:** One shared expression compiler that handles all expression forms. Backends only translate four leaf types — the points where the shared compiler genuinely can't proceed without backend-specific knowledge. Everything else falls through to shared default implementations.

The backend isn't really a compiler anymore. It's a handful of leaf translations plugged into a shared recursive traversal.

---

## Full Pipeline

```
Source code
  │
  ▼
Lexer / Tokenizer
  │  tokens
  ▼
Parser
  │  AST
  ▼
Name Resolution
  │  resolves all Name nodes to definitions or leaf types
  │  detects self-referential definitions → marks as feedback
  │  flattens Where/Let into named definition scopes
  ▼
Width Inference
  │  annotates every IR node with output tuple width
  │  validates call-site arity (auto-destructure check)
  ▼
IR Lowering
  │  Where/Let → flat named bindings
  │  Destructure → individual named bindings
  │  self-references → Buffer nodes with pre-allocated BufferIDs
  │  pragma signals → Buffer or Coord nodes
  ▼
Shared Expression Compiler
  │  recursive traversal of IR
  │  handles all non-leaf nodes identically across backends
  │  calls backend for leaf translations
  ▼
Backend Leaf Translator  (4 leaf types, ~300-500 lines per backend)
  │  Coord    → target-language coordinate expression
  │  Buffer   → target-language indexed buffer read
  │  Sink     → target-language output write
  │  Reduce   → target-language reduce primitive
  ▼
Backend Execution Model
  │  Metal: compute shader dispatch, one thread per pixel/sample
  │  CoreAudio: render callback, sequential per sample
  │  DMX: channel loop at 40Hz
  │  wgpu: portable compute dispatch
  ▼
Output
```

---

## Runtime (runs before compilation)

The runtime's job is to resolve all external signals into concrete buffers or constants before the compiler runs. By the time the compiler sees the IR, there is no concept of pragmas, feedback, cross-domain plumbing, or hardware inputs — only named buffers.

**Pragma resolution:**

- `#param freq 440 20 20000` → allocates a scalar slot, injects as a `Coord(.param("freq"))` leaf. Runtime updates it when the user moves a slider.
- `#curve brightness` → allocates a 1D float buffer, injects as a `Buffer(brightnessID, [@t])`. Runtime writes curve samples into the buffer each frame.

**Feedback buffer allocation:**

- Self-referential definitions detected during name resolution are annotated with a `BufferID`.
- Runtime allocates the buffer with appropriate shape: frame-rate (2D texture history) if offset is `1/60`, sample-rate (circular delay line) if offset is `1/@sr`.
- The self-referential call site `trail(@t - 1/60)` becomes `Buffer(trailID, [t - 1/60])` in the IR — identical to reading a camera buffer or a `#curve` buffer. Backend has no idea it's feedback.

**Cross-domain buffer allocation:**

- Runtime identifies signals that are pulled by sinks running at different rates.
- Allocates shared buffers at the boundary. Audio backend writes `envelope` at sample rate; visual backend reads it at frame rate.
- The seam is explicit in the IR as `Buffer` nodes. No ownership analysis needed — coordinate provenance (which coordinates does this signal depend on?) determines which sink evaluates it.

**Hardware input injection:**

- `camera` → 2D RGBA buffer updated each frame by the capture session.
- `microphone` → 1D float buffer updated each audio callback.
- Both appear as `Buffer` nodes in the IR. Same leaf type as feedback, `#curve`, everything else.

**Execution scheduler:**

- Builds a DAG of sinks and their buffer dependencies.
- Topological sort determines execution order each frame.
- Metal sink executes, writes output buffers; CoreAudio sink executes, reads from those buffers.

---

## AST Nodes

Produced by the parser. Closely mirrors surface syntax.

```swift
indirect enum Expr {
    // Literals and references
    case num(Float)
    case name(String)

    // Structure
    case tuple([Expr])
    case index(Expr, Int)              // signal.0  signal.1  signal.-1
    case call(Expr, [Expr])            // signal(coords) — also remap, same node
    case binOp(Op, Expr, Expr)
    case unOp(Op, Expr)
    case ifExpr(Expr, Expr, Expr)      // if c then a else b

    // Aggregation
    case forExpr(Expr, [(String, Range)])  // sum(expr for x in 0..1)

    // Scoping
    case whereExpr(Expr, [Binding])    // expr where { bindings }
    case letIn([Binding], Expr)        // let bindings in expr
}

enum Binding {
    case bind(String, Expr)            // name = expr
    case destructure([String], Expr)   // (a, b, c) = expr
}

struct Def {
    let name: String
    let params: [String]               // empty for signals, non-empty for functions
    let body: Expr
}
```

Note: functions and signals are the same node (`Def`) with different param list lengths. No `spindle` keyword. No `return` statement. Width is inferred from the body expression.

---

## IR Nodes

The IR is the AST after resolution and lowering. Key differences from AST:

- `Name` replaced by resolved `Signal` (points to a `Def`) or a leaf type
- `Where` and `Let` flattened — all bindings become named `Def`s in a flat scope
- `Destructure` eliminated — replaced by individual `Def`s with `Index` expressions
- Self-references pre-wired to `Buffer` nodes
- Widths annotated on every node
- `For` annotated with resolved `ReduceOp`

```swift
indirect enum IR {
    // Literals
    case num(Float, width: Int = 1)

    // LEAF: runtime-provided scalar coordinate
    case coord(CoordKind)
    // CoordKind: .x, .y, .t, .i, .w, .h, .sr, .param(String)

    // LEAF: indexed read into a runtime-provided buffer
    // covers: camera, microphone, #curve, feedback, cross-domain, loaded resources
    case buffer(BufferID, indices: [IR], width: Int)

    // Resolved definition reference
    case signal(DefID, width: Int)

    // Structure
    case tuple([IR], width: Int)
    case index(IR, Int, width: Int)
    case call(IR, [IR], width: Int)
    case binOp(Op, IR, IR, width: Int)
    case unOp(Op, IR, width: Int)
    case ifExpr(IR, IR, IR, width: Int)

    // LEAF: aggregate over coordinate range
    case reduce(IR, ReduceOp, [(name: String, range: Range)], width: Int)

    // LEAF: sink output
    case sink(SinkKind)
    // SinkKind: .display, .play, .dmx, .osc, ...
}
```

**The four leaf types:**

| Leaf     | What it represents     | Examples                                  |
| -------- | ---------------------- | ----------------------------------------- |
| `coord`  | scalar runtime value   | `@x`, `@t`, `@sr`, `#param` values        |
| `buffer` | indexed runtime buffer | camera, mic, `#curve`, feedback, textures |
| `reduce` | aggregate over range   | `sum(expr for x in 0..1)`                 |
| `sink`   | output write           | `display`, `play`, `dmx_out`              |

Everything else (`tuple`, `call`, `binOp`, `ifExpr`, etc.) is shared across all backends.

---

## Shared Expression Compiler

One recursive function, written once, used by every backend. Calls into the backend only for the four leaf types.

```swift
protocol BackendLeaves {
    func compileCoord(_ kind: CoordKind) -> String
    func compileBufferRead(_ id: BufferID, indices: [String]) -> String
    func compileSinkWrite(_ kind: SinkKind, value: String) -> String
    func compileReduce(_ body: String, op: ReduceOp, ranges: [(String, Range)]) -> String
}

func compile(_ node: IR, backend: BackendLeaves) -> String {
    switch node {

    // Shared — identical across all backends
    case .num(let f, _):
        return "\(f)"
    case .signal(let id, _):
        return resolvedName(id)
    case .tuple(let elems, _):
        return elems.map { compile($0, backend: backend) }.joined(separator: ", ")
    case .index(let expr, let i, _):
        return "\(compile(expr, backend: backend))[\(i)]"
    case .call(let f, let args, _):
        let compiledArgs = args.map { compile($0, backend: backend) }.joined(separator: ", ")
        return "\(compile(f, backend: backend))(\(compiledArgs))"
    case .binOp(let op, let a, let b, _):
        return "(\(compile(a, backend: backend)) \(op.symbol) \(compile(b, backend: backend)))"
    case .unOp(let op, let a, _):
        return "\(op.symbol)\(compile(a, backend: backend))"
    case .ifExpr(let c, let a, let b, _):
        return "(\(compile(c, backend: backend)) ? \(compile(a, backend: backend)) : \(compile(b, backend: backend)))"

    // Leaf — backend-specific
    case .coord(let kind):
        return backend.compileCoord(kind)
    case .buffer(let id, let indices, _):
        let compiledIndices = indices.map { compile($0, backend: backend) }
        return backend.compileBufferRead(id, indices: compiledIndices)
    case .sink(let kind):
        return backend.compileSinkWrite(kind, value: "???") // value threaded through
    case .reduce(let body, let op, let ranges, _):
        return backend.compileReduce(compile(body, backend: backend), op: op, ranges: ranges)
    }
}
```

The backend protocol has exactly four methods. That's the entire interface between shared and backend-specific code.

---

## Per-Backend Implementation

### Metal Backend (~300-400 lines)

```swift
struct MetalBackend: BackendLeaves {
    func compileCoord(_ kind: CoordKind) -> String {
        switch kind {
        case .x: return "coords.x"          // thread_position_in_grid / resolution
        case .y: return "coords.y"
        case .t: return "uniforms.time"
        case .w: return "uniforms.width"
        case .h: return "uniforms.height"
        case .param(let name): return "uniforms.\(name)"
        default: fatalError("coord not available in Metal")
        }
    }

    func compileBufferRead(_ id: BufferID, indices: [String]) -> String {
        // all buffers — camera, feedback, #curve, textures — are Metal textures or buffers
        return "buffers[\(id.index)].sample(\(indices.joined(separator: ", ")))"
    }

    func compileSinkWrite(_ kind: SinkKind, value: String) -> String {
        switch kind {
        case .display: return "outTexture.write(\(value), coords)"
        default: fatalError("sink not available in Metal")
        }
    }

    func compileReduce(_ body: String, op: ReduceOp, ranges: [(String, Range)]) -> String {
        // emit a Metal compute reduce pass
        return "reduce_\(op.name)(\(body), \(ranges.map { $0.0 }.joined(separator: ", ")))"
    }
}
```

Execution model: compile to a Metal compute shader, dispatch one thread per output pixel.

### CoreAudio Backend (~300-400 lines)

```swift
struct AudioBackend: BackendLeaves {
    func compileCoord(_ kind: CoordKind) -> String {
        switch kind {
        case .t:  return "(Float(sampleIndex) / sampleRate)"
        case .i:  return "sampleIndex"
        case .sr: return "sampleRate"
        case .param(let name): return "params.\(name)"
        default: fatalError("coord not available in audio")
        }
    }

    func compileBufferRead(_ id: BufferID, indices: [String]) -> String {
        // circular delay lines, cross-domain buffers, #curve buffers
        return "audioBuffers[\(id.index)][clamp(\(indices[0]), 0, bufferSize-1)]"
    }

    func compileSinkWrite(_ kind: SinkKind, value: String) -> String {
        switch kind {
        case .play: return "outputBuffer[sampleIndex] = \(value)"
        default: fatalError("sink not available in audio")
        }
    }

    func compileReduce(_ body: String, op: ReduceOp, ranges: [(String, Range)]) -> String {
        // emit a CPU loop
        return """
        ({ () -> Float in
            var acc: Float = \(op.identity)
            for \(ranges[0].0) in \(ranges[0].1.compiledRange) {
                acc = \(op.combine("acc", body))
            }
            return acc
        })()
        """
    }
}
```

Execution model: compile to a Swift closure, call sequentially per sample in the CoreAudio render callback.

### New Backend Template (~100-200 lines to get started)

A DMX backend, OSC backend, or wgpu backend needs to implement four methods and an execution model. The entire expression language — arithmetic, conditionals, function calls, tuple operations — is free.

---

## Width Inference

Every IR node carries a `width: Int` — the number of signals in its output tuple. This is inferred bottom-up:

- `Num` → width 1
- `Coord` → width 1
- `Buffer` → width declared at allocation time (camera = 3, mic = 1, etc.)
- `Tuple([a, b, c])` → width 3
- `Index(expr, i)` → width 1
- `Call(f, args)` → width of `f`'s return type (known from its `Def`)
- `BinOp` → width of operands (must match, or one is width 1 and broadcasts)
- `If(c, a, b)` → width of `a` (must equal width of `b`)
- `Reduce` → width 1

Auto-destructure at call sites: if a `Tuple` of width N is passed where N individual arguments are expected, the compiler expands it. This is just a width-check pass after name resolution.

---

## Self-Reference Detection → Feedback

During name resolution, the compiler builds a dependency graph. Any definition that has a path to itself in the graph is self-referential. The compiler:

1. Annotates the definition with a `BufferID`
2. Finds the self-referential `Call` node (the one with a time/coordinate offset)
3. Replaces it with `Buffer(id, [offsetExpr])`
4. Infers buffer granularity from the offset:
   - Offset involves `1/60` or `1/@fps` → frame-rate buffer (2D texture history for visual, 1D for audio)
   - Offset involves `1/@sr` → sample-rate buffer (circular delay line)
   - Other → compile-time error, rate must be statically inferable

The backend never sees the self-reference. It sees a `Buffer` read, same as camera or `#curve`.

---

## Coordinate Provenance → Partitioning

The partitioner no longer does ownership analysis. Instead it traces coordinate provenance: which runtime coordinates does each signal ultimately depend on?

- Depends on `@x`, `@y` → evaluate in visual domain
- Depends on `@i`, `@sr` → evaluate in audio domain
- Depends on neither → pure, can be duplicated into any domain that needs it
- Depends on both → cross-domain signal, needs a buffer boundary

This falls directly out of the dependency graph walk that name resolution already does. No separate ownership analysis pass. The partition is a consequence of the IR, not an inference on top of it.

Cross-domain signals become `Buffer` nodes at the boundary — audio evaluates the signal into a buffer, visual reads from that buffer. Both sides see only a `Buffer` read in their IR.

---

## Haskell Reference Implementation

The Haskell reference implementation becomes dramatically simpler under this architecture. It only needs to implement:

- The shared recursive traversal (pure function over IR, easy to express in Haskell)
- One set of leaf translations (for a reference "print" backend)
- Width inference and self-reference detection (both pure passes, easy to QuickCheck)

It no longer needs to shadow ownership analysis, pattern block compilation, or the full Metal/CoreAudio codegen. Parity is easier to maintain and divergence is easier to detect.

---

## Summary

| Concern             | Current                         | New                                        |
| ------------------- | ------------------------------- | ------------------------------------------ |
| Backend compilers   | 2 full compilers                | 1 shared traversal + 4-method protocol     |
| Pattern blocks      | Dedicated compiler path         | Gone — `where` + destructuring             |
| Ownership analysis  | Full inference pass             | Coordinate provenance, ~200 lines          |
| Remap vs call       | Separate IR node                | Same node                                  |
| Feedback / cache    | Special form                    | Self-reference detected at name resolution |
| Pragma signals      | Runtime + compiler coordination | Runtime resolves to buffers before compile |
| New backend cost    | ~1 week                         | ~1 day                                     |
| Total LOC           | ~13k                            | ~4000-4500                                 |
| Correctness surface | Per-backend                     | Shared traversal, tested once              |
