public struct LexError: Error {
  public let message: String
  public let loc: SourceLoc
}

struct Lexer {
  let source: [Character]
  var pos: Int = 0
  var line: Int = 1
  var column: Int = 1

  init(_ source: String) {
    self.source = Array(source)
  }

  // MARK: Position helpers

  var current: Character? {
    pos < source.count ? source[pos] : nil
  }

  var loc: SourceLoc {
    SourceLoc(line: line, column: column)
  }

  func peek() -> Character? {
    pos + 1 < source.count ? source[pos + 1] : nil
  }

  mutating func advance() {
    if current == "\n" {
      line += 1
      column = 1
    } else {
      column += 1
    }
    pos += 1
  }

  // MARK: Top-level driver

  mutating func tokenize() throws -> [Token] {
    var tokens: [Token] = []
    while true {
      let token = try nextToken()
      tokens.append(token)
      if token.kind == .eof { break }
    }
    return tokens
  }

  mutating func nextToken() throws -> Token {
    skipWhitespaceComments()
    let start = loc
    guard let c = current else {
      return Token(kind: .eof, span: Span(start: start, end: start))
    }
    let kind = try readKind(starting: c)
    let end = loc
    return Token(kind: kind, span: Span(start: start, end: end))
  }

  mutating func readKind(starting c: Character) throws -> TokenKind {
    switch c {
    case "0"..."9":
      return try readNumber()
    case "a"..."z", "A"..."Z", "_":
      return try readNameOrKeyword()
    case "@":
      return try readCoord()
    case "+", "-", "*", "/", "%", "^", "!", "<", ">", "&", "|":
      return try readOperator()
    case "=":
      return try readEquals()
    case ".":
      return try readDot()
    case "\"":
      return try readString()
    case "(":
      advance()
      return .lparen
    case ")":
      advance()
      return .rparen
    case "{":
      advance()
      return .lbrace
    case "}":
      advance()
      return .rbrace
    case ",":
      advance()
      return .comma
    case ";":
      advance()
      return .semicolon
    default:
      throw LexError(message: "unexpected character \(c)", loc: loc)
    }
  }

  // MARK: Whitespace and comments

  mutating func skipWhitespaceComments() {
    while let c = current {
      switch c {
      case " ", "\t", "\n", "\r":
        advance()
      case "-" where peek() == "-":
        // Line comment: consume up to (but not including) the newline.
        while let c = current, c != "\n" { advance() }
      default:
        return
      }
    }
  }

  // MARK: Identifiers and keywords

  mutating func readNameOrKeyword() throws -> TokenKind {
    var result = ""
    while let c = current, c.isLetter || c.isNumber || c == "_" {
      result.append(c)
      advance()
    }
    switch result {
    case "where": return .kwWhere
    case "if": return .kwIf
    case "then": return .kwThen
    case "else": return .kwElse
    default: return .name(result)
    }
  }

  // MARK: Coords

  mutating func readCoord() throws -> TokenKind {
    let atLoc = loc
    advance()  // consume '@'
    var name = ""
    while let c = current, c.isLetter || c.isNumber || c == "_" {
      name.append(c)
      advance()
    }
    if name.isEmpty {
      throw LexError(message: "expected coord name after @", loc: atLoc)
    }
    return .coord(name)
  }

  // MARK: Numbers

  mutating func readNumber() throws -> TokenKind {
    let startLoc = loc
    var text = ""
    while let c = current, c.isNumber {
      text.append(c)
      advance()
    }
    if current == ".", let next = peek(), next.isNumber {
      text.append(".")
      advance()
      while let c = current, c.isNumber {
        text.append(c)
        advance()
      }
    }
    guard let value = Float(text) else {
      throw LexError(message: "invalid number literal '\(text)'", loc: startLoc)
    }
    return .number(value)
  }

  // MARK: Strings

  mutating func readString() throws -> TokenKind {
    let startLoc = loc
    advance()  // consume opening "
    var result = ""
    while let c = current, c != "\"" {
      result.append(c)
      advance()
    }
    guard current == "\"" else {
      throw LexError(message: "unterminated string literal", loc: startLoc)
    }
    advance()  // consume closing "
    return .string(result)
  }

  // MARK: Operators

  mutating func readOperator() throws -> TokenKind {
    let c = current!
    let next = peek()

    // Two-character operators take priority over their one-char prefixes.
    switch (c, next) {
    case ("=", "="):
      advance()
      advance()
      return .op(.eqeq)
    case ("!", "="):
      advance()
      advance()
      return .op(.neq)
    case ("<", "="):
      advance()
      advance()
      return .op(.le)
    case (">", "="):
      advance()
      advance()
      return .op(.ge)
    case ("&", "&"):
      advance()
      advance()
      return .op(.andand)
    case ("|", "|"):
      advance()
      advance()
      return .op(.oror)
    default: break
    }

    advance()
    switch c {
    case "+": return .op(.plus)
    case "-": return .op(.minus)
    case "*": return .op(.star)
    case "/": return .op(.slash)
    case "%": return .op(.percent)
    case "^": return .op(.caret)
    case "!": return .op(.bang)
    case "<": return .op(.lt)
    case ">": return .op(.gt)
    case "&", "|":
      throw LexError(
        message: "unexpected '\(c)' (did you mean '\(c)\(c)'?)",
        loc: loc)
    default:
      throw LexError(message: "internal: unhandled operator '\(c)'", loc: loc)
    }
  }

  /// `=` alone is the assignment punctuation; `==` is an operator.
  mutating func readEquals() throws -> TokenKind {
    if peek() == "=" {
      advance()
      advance()
      return .op(.eqeq)
    }
    advance()
    return .equals
  }

  // MARK: Dot-prefixed tokens (postfix index)

  /// `.0`, `.42`, `.-3`. Bare `.` and `..` are not valid tokens.
  mutating func readDot() throws -> TokenKind {
    let dotLoc = loc
    advance()  // consume '.'

    var negative = false
    if current == "-" {
      negative = true
      advance()
    }

    var digits = ""
    while let c = current, c.isNumber {
      digits.append(c)
      advance()
    }

    if digits.isEmpty {
      let hint =
        negative
        ? "expected digits after '.-'"
        : "expected digits after '.'"
      throw LexError(message: hint, loc: dotLoc)
    }

    guard let value = Int(digits) else {
      throw LexError(message: "invalid index literal '\(digits)'", loc: dotLoc)
    }
    return .index(negative ? -value : value)
  }
}
