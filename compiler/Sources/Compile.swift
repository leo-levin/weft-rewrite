import WeftIR

public func compile(_ source: String) throws -> IRProgram {
  var lexer = Lexer(source)
  let tokens = try lexer.tokenize()
  var parser = Parser(tokens: tokens)
  let ast = try parser.parse()
  return try lowerProgram(ast)
}
