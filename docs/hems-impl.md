# Implementing Hems

Working notes for adding hem support to the parser, AST, name resolution, and runtime.

---

## What a hem is

A hem is a top-level declaration that connects a signal name to a runtime resource. Syntactically:

```
#cam1[3]  = camera(device: "FaceTime HD", width: 1920, height: 1080)
#freq     = slider(default: 440, min: 20, max: 20000)
#out[3]   = videoOut(monitor: 1, width: 1920, height: 1080)
#cam1     = history(depth: 60, units: "frames")
```

Multiple hems can share the same name — they stack. `cam1` above gets both a camera resource and a history buffer.

Hem argument values are **literals only** — numbers, strings, booleans. They cannot reference signals from the signal graph, or other hems. Hems are setup-time, not evaluation-time. A hem like `#mic = mic(rate: freq)` where `freq` is a slider is not valid — the runtime needs to set up the mic before the signal graph runs, so hem args must be fully resolved at load time. If you want a live-controllable sample rate, that's an architectural feature for later.

---

## Can hems reference other hems?

No. Same reason — hems are resolved before the signal graph runs, and allowing inter-hem references adds ordering dependencies and potential cycles for no clear gain. Keep them flat.

---

## Lexer changes

Add `#` as a token type. Since `#` only appears at the start of a hem declaration (top-level, not inside expressions), it can be a simple single-character token with no lookahead ambiguity.

```swift
case hash = "#"
```

Nothing else in the lexer needs to change.

---

## Parser changes

Hems are parsed at the top-level statement loop, before the regular expression parser runs. When the parser sees `#`, it branches to `parseHem()` instead of `parseDefinition()`.

`parseHem()` never calls the Pratt expression parser — the RHS is always `identifier(named_args)`, simple enough to handle inline.

```swift
func parseHem() throws -> HemDecl {
    try consume(.hash)
    let name = try parseName()
    let width = try parseOptionalWidthAssertion()  // [3] if present
    try consume(.equals)
    let op = try parseName()                        // camera, slider, videoOut, etc.
    try consume(.leftParen)
    let args = try parseNamedArgs()                 // key: value, key: value, ...
    try consume(.rightParen)
    return HemDecl(name: name, width: width, op: op, args: args)
}

func parseNamedArgs() throws -> [(String, HemValue)] {
    var args: [(String, HemValue)] = []
    while !check(.rightParen) {
        let key = try parseName()
        try consume(.colon)
        let value = try parseHemValue()
        args.append((key, value))
        if check(.comma) { try consume(.comma) }
    }
    return args
}

enum HemValue {
    case int(Int)
    case float(Float)
    case string(String)
    case bool(Bool)
}
```

`parseHemValue()` only accepts literals — no names, no expressions.

Note: `:` as a named-arg separator is new to the lexer. Add it as a token if it isn't already there. It only appears inside hem argument lists so there's no ambiguity with existing syntax.

---

## AST changes

```swift
struct HemDecl {
    let name: String
    let width: Int?          // optional compile-time width assertion
    let op: String           // "camera", "slider", "videoOut", "history", etc.
    let args: [(String, HemValue)]
}

struct Program {
    var hems: [HemDecl]      // all hem declarations, in order
    var defs: [Def]          // signal graph definitions
}
```

Multiple hems with the same name are kept as separate entries in `hems` — don't collapse them at parse time. The runtime and name resolution handle stacking.

---

## Name resolution changes

After parsing, group hems by name:

```swift
let hemsByName: [String: [HemDecl]] = Dictionary(grouping: program.hems, by: \.name)
```

For each name, validate that the combination of operators makes sense — e.g. `history` can stack on `camera` but two `camera` hems on the same name is probably an error.

Width assertions: if a hem declares `#cam1[3]` and another hem or definition later declares `#cam1[4]`, that's a compile error. Width assertions on hems work the same as on regular definitions.

In the IR, each hemmed name becomes a `buffer` leaf node. The name resolver replaces references to `cam1`, `freq`, etc. with the appropriate buffer read. The signal graph never sees the hem — just a buffer.

Width for hemmed signals: if a width assertion is present, use it. If not, infer from the operator's known output width (e.g. `slider` is always width 1, `audioOut` is always width 2). If the operator's width is unknown (e.g. a future third-party operator), require an explicit assertion.

---

## Runtime changes

The runtime receives the `[HemDecl]` list before compilation and resolves each operator to a resource constructor:

```swift
protocol HemOperator {
    func setup(name: String, args: [(String, HemValue)]) throws -> Resource
}

let hemRegistry: [String: HemOperator] = [
    "camera":   CameraHemOperator(),
    "slider":   SliderHemOperator(),
    "audioFile": AudioFileHemOperator(),
    "videoOut": VideoOutHemOperator(),
    "audioOut": AudioOutHemOperator(),
    "history":  HistoryHemOperator(),
]
```

`setup()` allocates the buffer, opens the capture session, registers the slider, whatever the resource needs. Returns a `Resource` that the runtime owns.

Adding new hardware = adding a new `HemOperator` to the registry. Language and compiler unchanged.

---

## The `history` hem

`history` is slightly different — it doesn't introduce a new name, it annotates an existing one. At setup time, if a name has both a `camera` hem and a `history` hem, the runtime allocates the camera buffer with the specified history depth as a ring buffer.

If a name has _only_ a `history` hem and also has a self-referential definition in the signal graph, the runtime allocates a plain ring buffer (no hardware input) that the signal graph writes into each frame.

The `history` hem is only required when the self-reference offset is not a static literal. If `foo = foo(@t - 0.1)`, the compiler infers 0.1 seconds of history automatically. If `foo = foo(@t - bar)` where `bar` is live, the compiler emits an error:

```
can't infer history depth for 'foo' — offset depends on live signal 'bar'.
add: #foo = history(depth: N, units: "seconds")
```

---

## Open questions

- Unit syntax: `depth: 5, units: "seconds"` is a bit clunky. Could be `depth: 5s` as a special literal suffix, or just accept the verbosity for now.

**Lexer/Parser disambiguation**

`#` is only valid at statement level. Inside an expression it's a parse error. The old `#param`/`#curve` inside-expression references are abolished — you just write the bare name. Migration: find all `#name` in expressions, strip the `#`.

**Width**

Two-phase load. Runtime sets up all resources first, returns `{ name → (BufferID, width) }`. Compiler receives that map alongside the AST and uses it during name resolution to wire up `buffer` leaf nodes. Width flows runtime → compiler. If a width assertion conflicts with the runtime-supplied width, compile error at name resolution. Operator widths are never hardcoded in the compiler — they come from the registry (see below).

**Valid hem operators**

The hem registry lives in the runtime, not the compiler. The compiler has no hardcoded list of valid operators. The runtime registers operators with their category and width behavior before compilation:

```swift
runtime.registerHem("camera",    category: .input,      width: .asserted)
runtime.registerHem("slider",    category: .input,      width: .fixed(1))
runtime.registerHem("audioFile", category: .input,      width: .fixed(1))
runtime.registerHem("videoOut",  category: .output,     width: .asserted)
runtime.registerHem("audioOut",  category: .output,     width: .fixed(2))
runtime.registerHem("history",   category: .annotation, width: .none)
```

The compiler reads category and width behavior off the registry at load time. New hardware = new `registerHem` call. A DMX backend registers `dmxOut`, it works, the compiler never needed to know about it. The valid set of hem operators is fully open.

**Name shadowing**

Driven by operator category from the registry:

- Input hem (`camera`, `slider`, `audioFile`): definition forbidden, error if one exists
- Output hem (`videoOut`, `audioOut`): definition required, error if absent
- Annotation hem (`history`): definition required, error if absent

Output hems are the one case where a name has both a hem and a definition — the hem declares the sink geometry, the definition declares what to evaluate. They're complementary, not competing.

**Stacking validation**

Compiler, using registry categories. Rules: `input + annotation` ok, `input + input` error, `output + output` error. No hardcoded list of valid pairs — just category logic. New operator categories would need new stacking rules but that's unlikely.

**History hem specifics**

`#foo = history(...)` with no other hem is only valid if `foo` is self-referential in the signal graph — checked after cycle detection. Automatic inference happens during cycle detection: if the offset is a numeric literal, infer depth, no hem needed. If the offset is anything else, require a `#history` hem, error if absent with a clear message pointing at the fix.

**Runtime/compiler boundary**

```
parse hems
    ↓
runtime.setup(hems) → registry + { name: (BufferID, width) }
    ↓
compiler.compile(ast, registry, hemMap)
    ↓
name resolution replaces hem names with buffer leaf nodes
stacking + shadowing validated against registry categories
width assertions checked against hemMap
```

Compiler never knows what `camera` or `videoOut` mean. It sees buffer IDs, widths, and categories. Everything else is the runtime's business.
