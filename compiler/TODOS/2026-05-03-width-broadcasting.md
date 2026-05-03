# Width Broadcasting for Hems

Multi-width hems (e.g., `#cam[3]`) used in scalar operations need width handling.

## The Problem

```
#cam[3] = camera(...);
#threshold = slider(...);  // width 1

mask = if { cam > threshold } then { 1 } else { 0 };
```

`cam` is width 3 (RGB), `threshold` is width 1. The comparison `cam > threshold` and the result `mask` need defined semantics:

1. **Broadcast**: scalar ops apply per-strand, result is width 3
2. **Require explicit indexing**: `cam.0 > threshold`, etc.
3. **Reduce**: `cam > threshold` means "any strand" or "all strands"

## Where This Bites

- `hemRead` currently has `indices: []` everywhere
- Width inference not implemented yet
- When it is, need to decide broadcasting rules

## Related

- `2026-05-03-width-annotations.md` — parsing `[3]` syntax
- Name resolution will need width info from the registry to validate
