# WEFT Design Notes

## Summary of syntax and architecture decisions

---

## 1. The Core Semantic Insight (unchanged)

Everything is a signal: `ℝⁿ → ℝ`. Coordinates are signals. Functions are signals with explicit coordinate parameters. There is one base type and everything composes freely. This isn't new — it's what WEFT has always been. The syntax work below is an attempt to make the language _look like_ what it already _is_.

---

## 2. What's Wrong with Current Syntax

The `=` sign implies storage and sequencing. `me.x` implies coordinates are a special bundle rather than just signals. `spindle` and `return.N` imply functions are a different kind of thing from signals. Pattern blocks with `->{}` imply data flowing forward rather than signals being pulled.

The new syntax tries to close the gap between the semantics and the surface.

---

## 3. New Syntax

### Definitions — one rule for everything

```
name = expr
name(params) = expr
```

A signal with no parameters and a function are the same thing syntactically. `rotate` and `display` and `lum` are all defined the same way. No `spindle` keyword. No `return`. Width is inferred from the expression.

### Where — local decomposition

```
display = (r, g, b)
  where
    (r, g, b) = camera
    r = camera.0(x + shift, y)
    shift = sin(t) * 0.05
```

`where` defines things subordinate to the expression above. Order is irrelevant — these are definitions, not steps. The sink comes first, decomposition follows. This is the primary tool for managing complexity in longer programs.

### Let-in — top-down decomposition

```
let (r, g, b) = camera
let warped = camera(x + shift, y)
in warped * brightness
```

Alternative when top-down reading order feels more natural. Both `where` and `let-in` coexist.

### Tuples — grouping signals

```
(a, b, c)
```

No `[]` bundle syntax. No named strand declarations. Tuples are just parenthesized comma-separated expressions. Width is always statically known.

### Destructuring

```
(r, g, b) = camera
img = (r, g, b) = load("foo.png")
```

The chained form declares both `img` as the whole tuple and `r`, `g`, `b` as individual signals. This is how resource width is declared — assert at the destructure site, compiler verifies against the file.

### Strand access — positional only

```
signal.0
signal.1
signal.-1
```

No named strand access (`.r`, `.g`, `.b`). Names only exist via destructuring. Negative indexing retained.

### Remapping — call with coordinates

```
camera(x + shift, y)     -- whole tuple, all strands shifted
camera.0(x + shift, y)   -- single strand
```

Calling a signal with explicit coordinates IS remapping. Calling with no arguments (`camera`) or empty parens (`camera()`) means current coordinates. This replaces `~` entirely. The operator disappears; the semantics are preserved.

### Runtime coordinates

```
@x  @y  @t  @i  @w  @h  @sr
```

`@` sigil distinguishes runtime-provided coordinates from user-defined signals. Not ambient — you write `@x` explicitly. Visually distinct, semantically just signals the runtime provides.

### Conditionals

```
if condition then a else b
```

Clean, familiar, no special indexing trick. `select` remains available in stdlib for signal-level use.

### Variadic fold

```
sum(t...) = fold(t, +, 0)
```

`...` suffix means "tuple of any width, recurse over it." Compiler unrolls statically since width is always known. No runtime variadic concept. User-defined variadic functions allowed via this mechanism.

Auto-destructuring at call sites: passing a 3-tuple to a 3-argument function just works.

---

## 4. What Disappeared

| Old                         | Replaced by                       |
| --------------------------- | --------------------------------- |
| `spindle` keyword           | `name(params) = expr`             |
| `return.N =`                | tuple expression, width inferred  |
| `me.x`, `me.y`, `me.t`      | `@x`, `@y`, `@t`                  |
| `~` remap operator          | `signal(coords)` call syntax      |
| `->{}` pattern blocks       | `where` + destructuring           |
| `bundle[names] =`           | `(a, b, c) = expr`                |
| `cache(...)`                | self-reference at past coordinate |
| `[a,b].(cond)` conditionals | `if-then-else`                    |
| Named strand access `.r`    | destructuring                     |

---

## 5. Grammar Sketch

```
program     = definition*

definition  = name "=" expr
            | name "(" params ")" "=" expr

expr        = tuple
            | expr "(" args ")"           -- call / remap
            | expr "." integer            -- strand access .0 .1 .-1
            | expr op expr
            | unop expr
            | expr "where" "{" binding+ "}"
            | "let" binding+ "in" expr
            | "if" expr "then" expr "else" expr
            | coord
            | number
            | name

binding     = name "=" expr
            | "(" name+ ")" "=" expr      -- destructure

tuple       = "(" expr "," expr+ ")"

coord       = "@x" | "@y" | "@t" | "@i" | "@w" | "@h" | "@sr"

op          = "+" | "-" | "*" | "/" | "^" | "%"
            | "==" | "!=" | "<" | ">" | "<=" | ">="
            | "&&" | "||"

unop        = "-" | "!"
```

Seven expression forms. Everything else is stdlib or semantics.

---

## 6. Examples

```
-- gradient
display = (@x, @y, 0)

-- camera passthrough
display = camera

-- darken
display = camera * 0.5

-- channel swap
display = (g, r, b)
  where (r, g, b) = camera

-- chromatic aberration
display = (r(@x + shift, @y), g, b(@x - shift, @y))
  where
    (r, g, b) = camera
    shift = sin(@t) * 0.05

-- Bayer dithering
xor(a, b) = (a + b) % 2

bayer(ix, iy) = (8*xor(x0,y0) + 4*y0 + 2*xor(x1,y1) + y1) / 16
  where
    x0 = ix % 2
    x1 = floor(ix / 2) % 2
    y0 = iy % 2
    y1 = floor(iy / 2) % 2

display = if lum > threshold then 1.0 else 0.0
  where
    lum = r*0.299 + g*0.587 + b*0.114
    (r, g, b) = camera
    threshold = bayer(ix, iy)
    ix = floor(@x * @w) % 4
    iy = floor(@y * @h) % 4

-- feedback trail
trail = max(camera.0, trail(@t - 1/60) * 0.95)
display = (trail, trail, trail)

-- audio filter (self-reference at previous sample)
lpf(input, freq) = prev + alpha * (input - prev)
  where
    prev = lpf(input, freq)(@t - 1/@sr)
    alpha = 1 - exp(-2 * pi * freq / @sr)

play = lpf(sine(440) * 0.3, 800)

-- cross-domain: envelope shared between audio and visual
envelope = ar(gate, 0.01, 0.3)
  where gate = btrig(120)

display = camera * envelope
play = sine(440) * envelope
```

---

## 7. Semantics: What the Language Is

### One base type

A signal is `ℝⁿ → ℝ`. A tuple is `(ℝⁿ → ℝ, ...)`. There are two types and the second is just grouping.

### Coordinates are signals

`@x`, `@y`, `@t` are not special. They are signals the runtime provides. User-defined coordinate spaces are identical in status — just define `r = sqrt(@x^2 + @y^2)` and use `r` anywhere you'd use `@x`.

### Calling IS remapping

`camera(@x + shift, @y)` is not "passing arguments to a function." It is evaluating a signal at a different point in its coordinate space. These are the same operation. There is no `~` operator because there doesn't need to be.

### Self-reference IS feedback

`trail = max(camera.0, trail(@t - 1/60) * 0.95)` is just a definition that references itself. The compiler detects this during name resolution and allocates a buffer. Buffer granularity is inferred from the self-reference offset — `1/60` → frame-rate buffer, `1/@sr` → sample-rate buffer.

### Partitioning falls out of coordinate provenance

The compiler doesn't do domain ownership analysis. It traces which sink pulls which signals and what coordinate space they're evaluated in. GPU vs CPU, visual vs audio — these emerge from pull-graph analysis, not explicit annotation.

---

## 8. Geometric Primitives

Three fundamental operations on signal fields:

**Remap** — coordinate transformation. Includes projection (fixing a coordinate), rotation, scaling, warping. This is `signal(coords)` — already in the language.

**Integrate** — collapse a signal over a region of its domain.

```
mean_lum = total / area
  where
    total = sum(camera(x, y).0 for x in 0..1, y in 0..1)
    area  = sum(1 for x in 0..1, y in 0..1)
```

`for x in 0..1` introduces range variables scoped to the expression. The compiler emits a GPU reduce pass or unrolled loop. Mathematically pure — same inputs, same output.

**Differentiate** — rate of change along a coordinate axis. Approximated in stdlib, potentially a primitive:

```
dsdx(s, x, y) = (s(x + ε, y) - s(x - ε, y)) / (2*ε)
```

These three correspond to the fundamental operations of calculus applied to fields. Together they cover most of differential geometry — gradient, divergence, curl, Laplacian, pullback, change of coordinates, line and surface integrals.

---

## 9. What WEFT Cannot Express

**Intra-pass sequential dependencies**: computing the value at position N from the already-computed value at position N-1 within the same evaluation pass. The canonical case is sequential audio filters (LPF output at sample 512 depends on LPF output at sample 511).

**Pushforward operations**: scattering values from input positions to output positions (particle splatting, histogram accumulation). These are inexpressible as pullback — but many can be reframed as integration over preimages using `for`, which brings them back into the model.

Everything else — reaction-diffusion, Game of Life, convolution, feedback networks, large FIR filters — is expressible. The documented constraint is narrower than it appeared.

---

## 10. Pragmas

Pragmas are metadata annotations that let runtimes expose parameters without baking UI semantics into the language.

```
#param freq 440 20 20000    -- exposes a scalar: slider, knob, etc.
#curve brightness            -- exposes a time-varying signal: drawable curve
#curve filter_freq 200 800   -- with range annotation
```

`#param` is a constant signal — one number. `#curve` is a `ℝ → ℝ` signal — a full function of time (or any coordinate). The compiler treats both identically to user-defined signals. The runtime decides the UI surface.

`#curve` is inspired by the notation/intersection system in Marc Downie's Field environment. In LOOM, curves are drawn directly on the canvas and are first-class signals — not UI controls driving parameters, but actual program values you happen to have drawn rather than typed.

Open questions:

- Can `#curve` range over coordinates other than `@t`? A curve over `@x` would be a spatial mask.
- A/B deck model: multiple curves with the same name for crossfading.
- `#curve beat` vs `#curve time` — beat-synced vs wall-clock.

---

## 11. Architecture Notes

### Partitioner

The partitioner exists and is correct in principle. The improvement is replacing ownership analysis with coordinate provenance tracing — cleaner, fewer edge cases, same result.

### IR

With the new semantics, the IR simplifies. No separate `.remap` node — remapping is just `.call`. No separate `.cacheRead` — feedback is just self-referential `.reference` detected at name resolution. The IR is essentially the AST with names resolved and cycles annotated.

### Backends as output geometries

Backends are coordinate spaces + wire protocols. `display` evaluates over a 2D grid and ships pixels. `play` evaluates over a 1D sequence at 44100Hz and ships samples. `dmx` evaluates over 512 channels and ships a DMX packet. The partition is: for each sink, evaluate the dependency subgraph over that sink's geometry. No domain concept in the language at all.

### Shared memory

Apple Silicon unified memory means cross-domain buffer passing has near-zero cost. The seam between backends is architecturally important but performance-cheap. The headless Linux / wgpu target breaks this assumption — worth tracking.

---
