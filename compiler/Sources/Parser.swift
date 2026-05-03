// Parser.swift
//
// Recursive descent for top-level structure; Pratt for expressions.
// `infixOp(_:)` is the single dispatch table for infix-position parsing
// — both `parseExpr` and `applyInfix` consult it.

import WeftIR

public struct ParseError: Error {
  public let message: String
  public let loc: SourceLoc
}

// MARK: - Pratt dispatch

enum Associativity {
  case left
  case right
}

enum InfixOp {
  case binary(BinOp, prec: Int, assoc: Associativity)
  case call(prec: Int)
  case index(prec: Int)
  case where_(prec: Int)
}

extension InfixOp {
  var prec: Int {
    switch self {
    case .binary(_, let p, _): return p
    case .call(let p): return p
    case .index(let p): return p
    case .where_(let p): return p
    }
  }
}

func infixOp(_ kind: TokenKind) -> InfixOp? {
  switch kind {
  case .op(.oror): return .binary(.or, prec: 5, assoc: .left)
  case .op(.andand): return .binary(.and, prec: 7, assoc: .left)
  case .op(.eqeq): return .binary(.eq, prec: 9, assoc: .left)
  case .op(.neq): return .binary(.neq, prec: 9, assoc: .left)
  case .op(.lt): return .binary(.lt, prec: 9, assoc: .left)
  case .op(.le): return .binary(.le, prec: 9, assoc: .left)
  case .op(.gt): return .binary(.gt, prec: 9, assoc: .left)
  case .op(.ge): return .binary(.ge, prec: 9, assoc: .left)
  case .op(.plus): return .binary(.add, prec: 20, assoc: .left)
  case .op(.minus): return .binary(.sub, prec: 20, assoc: .left)
  case .op(.star): return .binary(.mul, prec: 30, assoc: .left)
  case .op(.slash): return .binary(.div, prec: 30, assoc: .left)
  case .op(.percent): return .binary(.mod, prec: 30, assoc: .left)
  case .op(.caret): return .binary(.pow, prec: 40, assoc: .right)
  case .kwWhere: return .where_(prec: 2)
  case .lparen: return .call(prec: 60)
  case .index(_): return .index(prec: 70)
  default: return nil
  }
}

/// Right-binding power: what `minBP` to recurse with for the right operand.
/// Left-associative: `prec + 1` so an equal-precedence operator on the
/// right won't be consumed by the recursion. Right-associative: `prec - 1`
/// so it will.
func rightBindingPower(prec: Int, assoc: Associativity) -> Int {
  switch assoc {
  case .left: return prec + 1
  case .right: return prec - 1
  }
}

/// `minBP` for the operand of a prefix unary (`-x`, `!x`). Above
/// multiplicative (30), below `^` (40), so `-2*3` parses as `(-2)*3` and
/// `-2^3` parses as `(-2)^3`.
let unaryOperandPrec = 50

// MARK: - Parser

struct Parser {
  let tokens: [Token]
  var pos: Int = 0

  // The lexer always terminates with `.eof`, so `tokens[pos]` is safe.
  var current: Token { tokens[pos] }
  var currentKind: TokenKind { tokens[pos].kind }

  mutating func advance() {
    pos += 1
  }

  // MARK: Errors

  private func error(_ message: String) -> ParseError {
    ParseError(message: message, loc: current.span.start)
  }

  // MARK: Token-matching

  mutating func expect(_ kind: TokenKind) throws {
    guard currentKind == kind else {
      throw error("expected \(kind), got \(currentKind)")
    }
    advance()
  }

  mutating func expectName() throws -> String {
    guard case .name(let s) = currentKind else {
      throw error("expected name, got \(currentKind)")
    }
    advance()
    return s
  }

  mutating func expectCoord() throws -> String {
    guard case .coord(let s) = currentKind else {
      throw error("expected coord, got \(currentKind)")
    }
    advance()
    return s
  }

  /// Parse `name (, name)*`.
  mutating func parseNameList() throws -> [String] {
    var names: [String] = [try expectName()]
    while currentKind == .comma {
      advance()
      names.append(try expectName())
    }
    return names
  }

  // MARK: Top-level

  mutating func parse() throws -> [TopLevel] {
    var result: [TopLevel] = []
    while currentKind != .eof {
      let before = pos
      result.append(try parseDef())
      assert(pos > before, "parseDef did not consume any tokens")
    }
    return result
  }

  mutating func parseDef() throws -> TopLevel {
    let startTok = current

    // Destructure def: `(a, b) = expr;`
    if currentKind == .lparen {
      advance()
      let names = try parseNameList()
      try expect(.rparen)
      try expect(.equals)
      let body = try parseExpr()
      let endTok = current
      try expect(.semicolon)
      return .destructure(
        DestructureDef(
          names: names,
          body: body,
          span: .merge(startTok.span, endTok.span)))
    }

    // Function or signal def: `name(params) = expr;` or `name = expr;`
    let name = try expectName()

    var params: [String] = []
    if currentKind == .lparen {
      advance()
      if currentKind == .rparen {
        throw error(
          "function must declare at least one parameter; "
            + "use signal form 'name = expr' instead")
      }
      params = try parseNameList()
      try expect(.rparen)
    }
    try expect(.equals)
    let finalBody = try parseExpr()

    let endTok = current
    try expect(.semicolon)
    return .def(
      Def(
        name: name,
        params: params,
        body: finalBody,
        span: .merge(startTok.span, endTok.span)))
  }

  // MARK: Bindings

  mutating func parseBindings() throws -> [Binding] {
    // Bindings = Binding (";" Binding)* ";"?
    var bindings: [Binding] = [try parseBinding()]
    while currentKind == .semicolon {
      advance()
      if currentKind == .rbrace { break }
      bindings.append(try parseBinding())
    }
    return bindings
  }

  mutating func parseBinding() throws -> Binding {
    let startTok = current
    if currentKind == .lparen {
      advance()
      let names = try parseNameList()
      try expect(.rparen)
      try expect(.equals)
      let expr = try parseExpr()
      return .destructure(
        names: names,
        expr: expr,
        span: .merge(startTok.span, expr.span))
    }
    if case .coord = currentKind {
      let coord = try expectCoord()
      try expect(.equals)
      let expr = try parseExpr()
      return .coordBind(
        coord: coord,
        expr: expr,
        span: .merge(startTok.span, expr.span))
    }
    let name = try expectName()
    if currentKind == .lparen {
      advance()
      let params = try parseNameList()
      try expect(.rparen)
      try expect(.equals)
      let body = try parseExpr()
      return .funcBind(
        name: name,
        params: params,
        body: body,
        span: .merge(startTok.span, body.span))
    }
    try expect(.equals)
    let expr = try parseExpr()
    return .bind(
      name: name,
      expr: expr,
      span: .merge(startTok.span, expr.span))
  }

  // MARK: Expressions

  mutating func parseExpr(minBP: Int = 0) throws -> Expr {
    var left = try parsePrefix()
    while let infix = infixOp(currentKind), infix.prec > minBP {
      left = try applyInfix(left, infix)
    }
    return left
  }

  mutating func parsePrefix() throws -> Expr {
    let startTok = current
    switch currentKind {
    case .number(let f):
      advance()
      return .number(f, span: startTok.span)

    case .string(let s):
      advance()
      return .string(s, span: startTok.span)

    case .name(let s):
      advance()
      return .name(s, span: startTok.span)

    case .coord(let c):
      advance()
      return .coord(c, span: startTok.span)

    case .op(.minus):
      advance()
      let inner = try parseExpr(minBP: unaryOperandPrec)
      return .unOp(
        op: .neg, expr: inner,
        span: .merge(startTok.span, inner.span))

    case .op(.bang):
      advance()
      let inner = try parseExpr(minBP: unaryOperandPrec)
      return .unOp(
        op: .not, expr: inner,
        span: .merge(startTok.span, inner.span))

    case .lparen:
      return try parseTupleOrGroup()

    case .kwIf:
      return try parseIf()

    default:
      throw error("expected expression, got \(currentKind)")
    }
  }

  mutating func applyInfix(_ left: Expr, _ infix: InfixOp) throws -> Expr {
    switch infix {
    case .binary(let op, let prec, let assoc):
      advance()
      let rbp = rightBindingPower(prec: prec, assoc: assoc)
      let right = try parseExpr(minBP: rbp)
      return .binOp(
        op: op, lhs: left, rhs: right,
        span: .merge(left.span, right.span))

    case .call:
      advance()
      var args: [Expr] = []
      if currentKind != .rparen {
        args.append(try parseExpr())
        while currentKind == .comma {
          advance()
          args.append(try parseExpr())
        }
      }
      let endTok = current
      try expect(.rparen)
      return .call(
        fn: left, args: args,
        span: .merge(left.span, endTok.span))

    case .index:
      guard case .index(let i) = currentKind else {
        throw error("internal: index dispatch with non-index token")
      }
      let endTok = current
      advance()
      return .index(
        expr: left, i: i,
        span: .merge(left.span, endTok.span))

    case .where_:
      advance()
      try expect(.lbrace)
      let bindings = try parseBindings()
      let endTok = current
      try expect(.rbrace)
      return .whereExpr(
        body: left, bindings: bindings,
        span: .merge(left.span, endTok.span))
    }
  }

  mutating func parseTupleOrGroup() throws -> Expr {
    let startTok = current
    try expect(.lparen)
    if currentKind == .rparen {
      throw error("empty parens are not a valid expression")
    }
    var elems: [Expr] = [try parseExpr()]
    while currentKind == .comma {
      advance()
      elems.append(try parseExpr())
    }
    let endTok = current
    try expect(.rparen)
    if elems.count == 1 { return elems[0] }
    return .tuple(elems, span: .merge(startTok.span, endTok.span))
  }

  mutating func parseIf() throws -> Expr {
    let startTok = current
    try expect(.kwIf)
    let cond = try parseBraced()
    try expect(.kwThen)
    let then = try parseBraced()
    try expect(.kwElse)
    try expect(.lbrace)
    let else_ = try parseExpr()
    let endTok = current
    try expect(.rbrace)
    return .ifExpr(
      cond: cond, then: then, else_: else_,
      span: .merge(startTok.span, endTok.span))
  }

  /// `{ expr }` — used for the cond and then branches of an if. The else
  /// branch is parsed inline so the if-expr's span reaches the closing `}`.
  mutating func parseBraced() throws -> Expr {
    try expect(.lbrace)
    let expr = try parseExpr()
    try expect(.rbrace)
    return expr
  }
}
