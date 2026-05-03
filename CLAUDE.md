# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A ground-up rewrite of the WEFT compiler in Swift. The rewrite targets ~4000-4500 lines vs. the original ~13k by eliminating pattern blocks, ownership analysis, and dual backend compilers.

## Development Commands

```bash
cd compiler && swift build   # build only
cd compiler && swift run     # build + run; entry point is main.swift
```

There is no test suite yet — exercise the compiler by editing the `source` literal in `main.swift` and re-running. `prettyPrint` (in `prettyprint.swift`) dumps the parsed AST.

## Compiler Pipeline

```
Source → Lexer (Lexer.swift, Token.swift) → Parser (Parser.swift) → AST (AST.swift)
       → Name Resolution (Resolution.swift) → IR (IR.swift, Lowering.swift)
       → Shared Expression Compiler → Backend Leaf Translators
```

**Current state:**
- Lexer and Parser are implemented; `prettyprint.swift` renders the AST for debugging.
- `Resolution.swift` is empty.
- `IR.swift` drafts the `IRNode` enum, but supporting types (`ID`, `CoordKind`, `BufferID`, `BindLHS`, `BinOp`, `UnOp`) aren't defined yet — the file does not compile in isolation.
- `Lowering.swift` has an `IRBuilder` skeleton that hash-conses nodes via `getNode(_:)`. No AST→IR walk yet.
- No backends.

## Architecture

### AST vs IR
`AST.swift` defines the surface representation. `Def` is the single definition form for both functions (non-empty `params`) and signals (empty `params`) — no `spindle` keyword.

The IR (designed, not yet implemented) introduces four **leaf types** that are backend-specific. Everything else — arithmetic, conditionals, calls, tuples — is shared across all backends:

| Leaf | Meaning |
|------|---------|
| `coord` | Runtime scalar: `@x`, `@y`, `@t`, `@sr`, `#param` values |
| `buffer` | Indexed runtime buffer: camera, mic, feedback, `#curve`, textures |
| `reduce` | Aggregate over coordinate range (`sum(expr for x in 0..1)`) |
| `sink` | Output write: `display`, `play`, `dmx_out` |

### Backend Protocol
Each backend implements exactly four methods — one per leaf type:
```swift
protocol BackendLeaves {
    func compileCoord(_ kind: CoordKind) -> String
    func compileBufferRead(_ id: BufferID, indices: [String]) -> String
    func compileSinkWrite(_ kind: SinkKind, value: String) -> String
    func compileReduce(_ body: String, op: ReduceOp, ranges: [(String, Range)]) -> String
}
```

### Runtime vs Compiler Responsibilities
The **runtime** resolves pragmas (`#param`, `#curve`), feedback buffers (self-referential defs), cross-domain signals, and hardware inputs (camera, mic) into named `Buffer` nodes **before** the compiler runs. The compiler never sees these concepts — only flat IR with buffer reads.

### Coordinate Provenance (Partitioning)
Instead of ownership analysis, the partitioner traces which runtime coordinates each signal depends on:
- `@x`/`@y` → visual domain
- `@i`/`@sr` → audio domain  
- Neither → pure, duplicated into any domain that needs it
- Both → cross-domain boundary, gets a buffer allocated

### Self-Reference → Feedback
Detected during name resolution via dependency graph cycle detection. The call site is replaced with a `Buffer` read; the backend never sees the self-reference.

## Language Grammar

Defined in `docs/ref-grammar.md`. Key points:
- `name(params) = expr` is the unified definition form (functions and signals)
- `@name` syntax for runtime coordinate sigils (`@x`, `@y`, `@t`, `@i`, `@sr`)
- `where { bindings }` for local decomposition
- `(a, b) = expr` for destructuring
- `--` line comments

## Docs

`docs/compiler-notes-apr-8.md` — full architecture spec with IR node definitions, backend pseudocode, width inference rules, and the planned pipeline. Read this before making structural changes.

`docs/design-notes-apr-8.md` — language design notes and syntax rationale.
