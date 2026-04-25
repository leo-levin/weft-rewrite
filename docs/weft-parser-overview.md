# WEFT Parser
## What it is and what it needs to do

---

## The job

The parser takes WEFT source text and produces an AST. That's it. It knows nothing about signals, backends, or coordinate spaces — those are the compiler's concern. The parser only needs to answer: is this valid syntax, and if so, what is its structure?

The output is a list of definitions. Everything in WEFT is a definition.

---

## One definition form

There is exactly one way to define something in WEFT:

```
name = expr
name(params) = expr
```

A signal and a function look identical. `display`, `rotate`, and `lum` are all defined the same way. The parameter list being empty or non-empty is the only difference. The compiler figures out what kind of thing it is from context — the parser just records the structure.

---

## Expressions

An expression is one of seven things:

- a number: `0.5`
- a coordinate: `@x`, `@y`, `@t`, `@i`, `@w`, `@h`, `@sr`
- a name: `camera`, `shift`, `rotate`
- a tuple: `(a, b, c)`
- a call: `f(x, y)` — also how remapping is written
- an operator expression: `a + b`, `x > 0.5`
- a conditional: `if c then a else b`

Plus two scoping forms that let you name intermediate values:

- `where` — conclusion first, decomposition below
- `let-in` — decomposition first, conclusion at the end

That's the whole language surface. Everything else — feedback, cross-domain signals, coordinate remapping — emerges from these forms at the semantic level and is invisible to the parser.

---

## What the parser does not do

The parser does not resolve names. `trail` appearing on both sides of a definition is not a parse error — it's a self-reference, and whether that's valid is the compiler's problem.

The parser does not check widths. `(a, b, c) = someSignal` is valid syntax regardless of how wide `someSignal` is.

The parser does not distinguish a function call from a coordinate remap. `camera(@x + shift, @y)` and `rotate(x, y, angle)` are both `Call` nodes. The compiler knows the difference.

---

## The tricky parts

**Operator precedence.** `a + b * c` must parse as `a + (b * c)`, and `^` must be right-associative. This is handled by a Pratt parser at the expression level — a small table of binding powers, not a tower of recursive grammar rules.

**Tuple vs grouped expression.** `(a + b)` is just `a + b` with redundant parens. `(a, b)` is a two-wide tuple. The comma is the only distinguishing token.

**`.0` strand access.** `signal.0` should parse as index-into-signal, not signal-dot-zero in a property-access sense. The lexer handles this: `.` followed immediately by a digit (or `-` digit) produces a single strand-access token rather than a bare dot.

**`where` precedence.** `where` binds more loosely than any operator, so it always wraps the full expression to its left:

```
display = r * 0.5 + g * 0.3
  where { ... }
```

parses as the whole `r * 0.5 + g * 0.3` expression with `where` attached, not just `g * 0.3`.

---

## What comes out

The AST is a list of `Def` nodes. Each `Def` has a name, an optional parameter list, and a body expression. The body is a tree of the expression forms above. No type information, no backend hints, no resolved references — just structure.

The compiler takes it from there.
