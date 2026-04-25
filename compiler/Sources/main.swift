let source = """
  xor(a, b) = (a + b) % 2;

  bayer(ix, iy) = (8*xor(x0,y0) + 4*y0 + 2*xor(x1,y1) + y1) / 16
    where {
      x0 = ix % 2 ;
      x1 = floor(ix / 2) % 2 ;
      y0 = iy % 2;
      y1 = floor(iy / 2) % 2
    };

  display = if {lum > threshold} then {1.0} else {0.0}
    where {
      lum = r*0.299 + g*0.587 + b*0.114;
      (r, g, b) = camera;
      threshold = bayer(ix, iy);
      ix = floor(@x * @w) % 4;
      iy = floor(@y * @h) % 4
    };

  """

do {
  var lexer = Lexer(source)
  let tokens = try lexer.tokenize()
  var parser = Parser(tokens: tokens)
  let ast = try parser.parse()
  prettyPrint(ast)
} catch let e as LexError {
  print("lex error at \(e.line):\(e.column): \(e.message)")
} catch let e as ParseError {
  print("parse error: \(e.message)")
}
