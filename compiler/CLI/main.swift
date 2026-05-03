import WeftCompiler

// import WeftRuntime  // temporarily disabled while runtime is in progress

// MARK: - Test helpers (disabled while runtime is in progress)

/*
func runSignal(
  source: String,
  output: String,
  steps: Int,
  seed: [Int: [Float: Float]] = [:],
  coords: (Int) -> [String: Float]
) throws -> [Float] {
  let program = try compile(source)
  var runtime = Runtime(program: program)
  runtime.feedbackBuffers = seed
  return (0..<steps).map { i in
    runtime.run(outputName: output, coords: coords(i))!
  }
}

func check(_ name: String, _ actual: [Float], _ expected: [Float], tolerance: Float = 0.001) {
  print("\(name):")
  for (i, a) in actual.enumerated() { print("  [\(i)] \(a)") }
  for (i, (a, e)) in zip(actual, expected).enumerated() {
    if abs(a - e) > tolerance {
      print("  FAIL at step \(i): expected \(e) got \(a)")
      return
    }
  }
  print("  PASS")
}
*/

// MARK: - Tests

do {
  // Hem parsing test
  print("=== Hem parsing test ===")
  let hemSource = """
    #cam1[3] = camera(device: "FaceTime HD", width: 1920);
    #freq = slider(default: -440, min: -20000, max: 20000);
    #out = videoOut(monitor: 1);
    display = cam1;
    """
  let hemProgram = try parseSource(hemSource)
  prettyPrint(hemProgram)
  print("")

  // Now try full compilation
  print("=== Hem IR test ===")
  let ir = try compile(hemSource)
  prettyPrintIR(ir)
  print("")

  // More complex: hem used in expression
  print("=== Hem in expression ===")
  let hemExprSource = """
    #slider = slider(default: 0.5);
    #cam = camera(device: "test");
    display = cam * slider + 1;
    """
  let ir2 = try compile(hemExprSource)
  prettyPrintIR(ir2)
  print("")

  // Full integration: hems + coords + functions + where + conditionals
  print("=== Full integration test ===")
  let fullSource = """
    #cam[3] = camera(device: "FaceTime", width: 1920, height: 1080);
    #brightness = slider(default: 1.0, min: 0, max: 2);
    #contrast = slider(default: 1.0, min: -1, max: 3);

    clamp(x, lo, hi) = if { x < lo } then { lo } else { if { x > hi } then { hi } else { x } };

    display = if { @t > 0 } then { processed } else { cam }
      where {
    		processed = clamp((cam - 0.5) * contrast + 0.5, 0.0, 1.0) * brightness;
      };
    """
  let fullAST = try parseSource(fullSource)
  print("AST:")
  prettyPrint(fullAST)

  let fullIR = try compile(fullSource)
  print("IR:")
  prettyPrintIR(fullIR)
  print("")

  /* Runtime tests disabled
  // 1. Pure coord
  check(
    "pure coord",
    try runSignal(source: "play = @t * 2;", output: "play", steps: 5) { i in ["t": Float(i)] },
    [0, 2, 4, 6, 8])

  // 2. Conditional
  check(
    "conditional",
    try runSignal(source: "play = if { @t > 2 } then { 1 } else { 0 };", output: "play", steps: 5) {
      i in ["t": Float(i)]
    },
    [0, 0, 0, 1, 1])

  // 3. Function call
  check(
    "function call",
    try runSignal(source: "double(x) = x * 2; play = double(@t);", output: "play", steps: 5) { i in
      ["t": Float(i)]
    },
    [0, 2, 4, 6, 8])

  // 4. Signal remap via where
  check(
    "signal remap",
    try runSignal(
      source: "sig = @t * 2; play = sig where { @t = @t + 10; };", output: "play", steps: 5
    ) { i in ["t": Float(i)] },
    [20, 22, 24, 26, 28])

  // 5. 1D feedback decay
  check(
    "1D feedback decay",
    try runSignal(
      source: "trail = (trail where { @t = @t - 1; }) * 0.95; play = trail;",
      output: "play",
      steps: 5,
      seed: [0: [-1.0: 1.0]]
    ) { i in ["t": Float(i)] },
    [0.95, 0.9025, 0.857375, 0.81450625, 0.7737809])

  // 6. 0D accumulator
  check(
    "0D accumulator",
    try runSignal(source: "acc = acc + 1; play = acc;", output: "play", steps: 5) { i in
      ["t": Float(i)]
    },
    [1, 2, 3, 4, 5])

  // 7. Two coords
  check(
    "two coords",
    try runSignal(source: "play = @x + @y;", output: "play", steps: 4) { i in
      ["x": Float(i), "y": Float(i * 2)]
    },
    [0, 3, 6, 9])

  // 8. Multiple coord rebindings
  check(
    "multi coord remap",
    try runSignal(
      source: "sig = @x + @y; play = sig where { @x = @x + 1; @y = @y * 2; };",
      output: "play", steps: 4
    ) { i in ["x": Float(i), "y": Float(i)] },
    [1, 4, 7, 10])  // (i+1) + (i*2)

  // 9. Nested remap — remap inside remap
  check(
    "nested remap",
    try runSignal(
      source:
        "sig = @t * 3; shifted = sig where { @t = @t + 2; }; play = shifted where { @t = @t + 1; };",
      output: "play", steps: 4
    ) { i in ["t": Float(i)] },
    [9, 12, 15, 18])  // (i+1+2)*3

  // 10. Signal used at two different remaps in same expression
  check(
    "same signal two remaps",
    try runSignal(
      source: "sig = @t * 2; play = (sig where { @t = @t + 1; }) + (sig where { @t = @t + 10; });",
      output: "play", steps: 4
    ) { i in ["t": Float(i)] },
    [22, 26, 30, 34])  // (i+1)*2 + (i+10)*2

  // 11. Function with multiple args
  check(
    "multi-arg function",
    try runSignal(
      source: "lerp(a, b, t) = a + (b - a) * t; play = lerp(0, 10, @t);",
      output: "play", steps: 5
    ) { i in ["t": Float(i) * 0.25] },
    [0, 2.5, 5, 7.5, 10])

  // 12. Feedback used in expression with other signals
  check(
    "feedback + signal",
    try runSignal(
      source: "trail = (trail where { @t = @t - 1; }) * 0.5; play = trail + @t;",
      output: "play",
      steps: 5,
      seed: [0: [-1.0: 1.0]]
    ) { i in ["t": Float(i)] },
    [0.5, 1.25, 2.125, 3.0625, 4.03125])  // trail decays at 0.5x, play adds @t

  // 13. Negation
  check(
    "negation",
    try runSignal(source: "play = -@t;", output: "play", steps: 4) { i in ["t": Float(i)] },
    [0, -1, -2, -3])

  // 14. Boolean logic
  check(
    "boolean and",
    try runSignal(
      source: "play = if { @x > 0 && @y > 0 } then { 1 } else { 0 };",
      output: "play", steps: 4
    ) { i in ["x": Float(i) - 1, "y": Float(i) - 2] },
    [0, 0, 0, 1])  // both positive only when i=3

  // 15. @x remap
  check(
    "x remap",
    try runSignal(
      source: "sig = @x * @x; play = sig where { @x = @x + 1; };",
      output: "play", steps: 5
    ) { i in ["x": Float(i)] },
    [1, 4, 9, 16, 25])  // (i+1)^2

  // 16. @x and @y both remapped independently
  check(
    "x and y remap independently",
    try runSignal(
      source: "sig = @x - @y; play = (sig where { @x = @x * 2; }) + (sig where { @y = @y * 2; });",
      output: "play", steps: 4
    ) { i in ["x": Float(i), "y": Float(i)] },
    [0, 0, 0, 0])  // (2i - i) + (i - 2i) = i + (-i) = 0

  // 17. @x remap chained through named signal
  check(
    "x remap chained",
    try runSignal(
      source: "a = @x + 1; b = a where { @x = @x * 3; }; play = b;",
      output: "play", steps: 4
    ) { i in ["x": Float(i)] },
    [1, 4, 7, 10])  // (i*3) + 1

  // 19. Power operator
  check(
    "power",
    try runSignal(source: "play = @t ^ 2;", output: "play", steps: 5) { i in ["t": Float(i)] },
    [0, 1, 4, 9, 16])
  */

} catch let e as LexError {
  print("lex error at \(e.loc.line):\(e.loc.column): \(e.message)")
} catch let e as ParseError {
  print("parse error at \(e.loc.line):\(e.loc.column): \(e.message)")
} catch let e as LoweringError {
  let start = e.span.start
  let end = e.span.end
  print("lowering error at \(start.line):\(start.column)-\(end.line):\(end.column): \(e.message)")
}
