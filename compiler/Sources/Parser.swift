struct ParseError: Error {
  let message: String
  let line: Int
  let column: Int
}

struct Parser {
  let tokens: [Token]
  var pos: Int = 0

  var current: Token { tokens[pos] }

  mutating func advance() {
    pos += 1
  }

  mutating func expect(_ token: Token) throws {
    guard current == token else {
      throw ParseError(message: "expected \(token), got \(current)", line: 0, column: 0)
    }
    advance()
  }

  mutating func parseCommaSeparated<T>(_ parse: (inout Parser) throws -> T) throws -> [T] {
    var results = [try parse(&self)]
    while case .comma = current {
      advance()
      results.append(try parse(&self))
    }
    return results
  }

  mutating func parse() throws -> [TopLevel] {
    var result: [TopLevel] = []
    while current != .eof {
      result.append(try parseDef())
    }
    return result
  }

  mutating func parseDef() throws -> TopLevel {
    if case .lparen = current {
      advance()
      let names = try parseCommaSeparated { p -> String in
        guard case .name(let s) = p.current else {
          throw ParseError(message: "expected name in destructure", line: 0, column: 0)
        }
        p.advance()
        return s
      }
      try expect(.rparen)
      try expect(.equals)
      let body = try parseExpr()
      try expect(.semicolon)
      return .destructure(DestructureDef(names: names, body: body))
    }

    guard case .name(let n) = current else {
      throw ParseError(message: "expected name", line: 0, column: 0)
    }
    advance()

    var params: [String] = []
    if case .lparen = current {
      advance()
      params = try parseCommaSeparated { p -> String in
        guard case .name(let s) = p.current else {
          throw ParseError(message: "expected parameter name", line: 0, column: 0)
        }
        p.advance()
        return s
      }
      try expect(.rparen)
    }
    try expect(.equals)
    let body = try parseExpr()

    if case .kwWhere = current {
      advance()
      try expect(.lbrace)
      let bindings = try parseBindings()
      try expect(.rbrace)
      try expect(.semicolon)
      return .def(Def(name: n, params: params, body: .whereExpr(body: body, bindings: bindings)))
    }

    try expect(.semicolon)
    return .def(Def(name: n, params: params, body: body))
  }

  mutating func parseExpr(minBP: Int = 0) throws -> Expr {
    var left = try parsePrefix()
    while bindingPower(current) > minBP {
      left = try parseInfix(left)
    }
    return left
  }

  mutating func parsePrefix() throws -> Expr {
    switch current {
    case .number(let f):
      advance()
      return .number(f)
    case .string(let s):
      advance()
      return .string(s)
    case .name(let s):
      advance()
      return .name(s)
    case .coord(let s):
      advance()
      return .coord(s)
    case .op("-"):
      advance()
      return .unOp(op: "-", expr: try parseExpr(minBP: 50))
    case .op("!"):
      advance()
      return .unOp(op: "!", expr: try parseExpr(minBP: 50))
    case .lparen:
      return try parseTupleOrGroup()
    case .kwIf:
      return try parseIf()
    default:
      throw ParseError(message: "expected expression, got \(current)", line: 0, column: 0)
    }
  }

  mutating func parseInfix(_ left: Expr) throws -> Expr {
    switch current {
    case .op(let s):
      advance()
      let rbp = s == "^" ? 39 : bindingPower(.op(s))
      let right = try parseExpr(minBP: rbp)
      return .binOp(op: s, lhs: left, rhs: right)
    case .lparen:
      advance()
      if case .rparen = current {
        advance()
        return .call(fn: left, args: [])
      }
      let args = try parseCommaSeparated { try $0.parseExpr() }
      try expect(.rparen)
      return .call(fn: left, args: args)
    case .index(let i):
      advance()
      return .index(expr: left, i: i)
    default:
      throw ParseError(message: "expected operator, got \(current)", line: 0, column: 0)
    }
  }

  mutating func parseBindings() throws -> [Binding] {
    var bindings: [Binding] = []
    while current != .rbrace {
      if case .lparen = current {
        advance()
        let names = try parseCommaSeparated { p -> String in
          guard case .name(let s) = p.current else {
            throw ParseError(message: "expected name in destructure", line: 0, column: 0)
          }
          p.advance()
          return s
        }
        try expect(.rparen)
        try expect(.equals)
        let expr = try parseExpr()
        bindings.append(.destructure(names: names, expr: expr))
      } else {
        guard case .name(let n) = current else {
          throw ParseError(message: "expected name in binding", line: 0, column: 0)
        }
        advance()
        try expect(.equals)
        let expr = try parseExpr()
        bindings.append(.bind(name: n, expr: expr))
      }
      if case .semicolon = current { advance() }
    }
    return bindings
  }

  mutating func parseTupleOrGroup() throws -> Expr {
    try expect(.lparen)
    if case .rparen = current {
      advance()
      return .tuple([])
    }
    let elems = try parseCommaSeparated { try $0.parseExpr() }
    try expect(.rparen)
    if elems.count == 1 { return elems[0] }
    return .tuple(elems)
  }

  mutating func parseBraced() throws -> Expr {
    try expect(.lbrace)
    let expr = try parseExpr()
    try expect(.rbrace)
    return expr
  }

  mutating func parseIf() throws -> Expr {
    advance()  // consume if
    let cond = try parseBraced()
    try expect(.kwThen)
    let then = try parseBraced()
    try expect(.kwElse)
    let else_ = try parseBraced()
    return .ifExpr(cond: cond, then: then, else_: else_)
  }

  func bindingPower(_ token: Token) -> Int {
    switch token {
    case .op("||"): return 5
    case .op("&&"): return 6
    case .op("=="), .op("!="),
      .op("<"), .op(">"),
      .op("<="), .op(">="):
      return 9
    case .op("+"), .op("-"): return 20
    case .op("*"), .op("/"), .op("%"): return 30
    case .op("^"): return 40
    case .lparen: return 60
    case .index(_): return 70
    default: return 0
    }
  }
}
