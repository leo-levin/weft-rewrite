let source = """
  xor(a, b) = (a + b) % 2;
  """

do {
  var lexer = Lexer(source)
  let tokens = try lexer.tokenize()
  var parser = Parser(tokens: tokens)
  let ast = try parser.parse()
  prettyPrint(ast)
} catch let e as LexError {
  print("lex error at \(e.loc.line):\(e.loc.column): \(e.message)")
} catch let e as ParseError {
  print("parse error at \(e.loc.line):\(e.loc.column): \(e.message)")
}
