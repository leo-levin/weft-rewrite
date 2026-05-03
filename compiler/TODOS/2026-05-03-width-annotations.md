# Width Annotations

Add optional compile-time width assertions to definitions and hems.

## Syntax

```
foo[3] = (r, g, b)
#cam1[3] = camera(device: "FaceTime HD")
```

## What needs to change

**AST.swift:**
- Add `width: Int?` field to `Def`
- Add `width: Int?` field to `DestructureDef`
- Future: add to `HemDecl` when hems are implemented

**Parser.swift:**
- After parsing a name, check for `[` and parse an integer literal if present
- Store in the `width` field

**Lexer/Token:**
- `[` and `]` tokens may already exist; if not, add them

**Name resolution / type checking:**
- Validate that declared width matches inferred width
- Emit error if they conflict

## Notes

Width inference itself is a separate task — this is just the annotation syntax and storage.
