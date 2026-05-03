import WeftIR

public func parseSource(_ source: String) throws -> [TopLevel] {
  var lexer = Lexer(source)
  let tokens = try lexer.tokenize()
  var parser = Parser(tokens: tokens)
  return try parser.parse()
}

public func compile(_ source: String) throws -> IRProgram {
  let ast = try parseSource(source)
  return try lowerProgram(ast)
}
