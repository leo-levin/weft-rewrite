struct LexError: Error {
  let message: String
  let line: Int
  let column: Int
}

struct Lexer {
  let source: [Character]
  var pos: Int = 0
  var line: Int = 1
  var column: Int = 1

  init(_ source: String) {
    self.source = Array(source)
  }

  var current: Character? {
    pos < source.count ? source[pos] : nil
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

  func peek() -> Character? {
    pos + 1 < source.count ? source[pos + 1] : nil
  }

  mutating func nextToken() throws -> Token {
    skipWhitespaceComments()
    guard let c = current else { return .eof }
    switch c {
    case "0"..."9": return try readNumber()
    case "a"..."z", "A"..."Z", "_": return try readName()
    case "@": return try readCoord()
    case "+", "-", "*", "/", "%", "^", "!", "<", ">": return try readOperator()
    case "(":
      advance()
      return .lparen
    case ")":
      advance()
      return .rparen
    case ",":
      advance()
      return .comma
    case "=":
      if peek() == "=" {
        advance()
        advance()
        return .op("==")
      }
      advance()
      return .equals
    case ".": return try readDot()
    case "{":
      advance()
      return .lbrace
    case "}":
      advance()
      return .rbrace
    case ";":
      advance()
      return .semicolon
    case "#":
      advance()
      return .hash
    case "\"": return try readString()
    default: throw LexError(message: "unexpected character \(c)", line: line, column: column)
    }
  }

  mutating func skipWhitespaceComments() {
    while let c = current {
      switch c {
      case " ", "\t", "\n", "\r":
        advance()
      case "-" where peek() == "-":
        while let c = current, c != "\n" { advance() }
      default:
        return
      }
    }
  }

  mutating func readName() throws -> Token {
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
    case "in": return .kwIn
    default: return .name(result)
    }
  }

  mutating func readCoord() throws -> Token {
    advance()  // consume @
    var result = ""
    while let c = current, c.isLetter {
      result.append(c)
      advance()
    }
    if result.isEmpty {
      throw LexError(message: "expected coordinate name after @", line: line, column: column)
    }
    return .coord(result)
  }

  mutating func readNumber() throws -> Token {
    var result = ""
    while let c = current, c.isNumber {
      result.append(c)
      advance()
    }
    if current == ".", let next = peek(), next.isNumber {
      result.append(".")
      advance()
      while let c = current, c.isNumber {
        result.append(c)
        advance()
      }
    }
    return .number(Float(result)!)
  }

  mutating func readString() throws -> Token {
    advance()  // consume opening "
    var result = ""
    while let c = current, c != "\"" {
      result.append(c)
      advance()
    }
    guard current == "\"" else {
      throw LexError(message: "unterminated string", line: line, column: column)
    }
    advance()  // consume closing "
    return .string(result)
  }

  mutating func readDot() throws -> Token {
    advance()  // consume .

    if current == "." {
      advance()
      return .dotdot
    }

    if current == "-" {
      advance()  // consume -
      var result = ""
      while let c = current, c.isNumber {
        result.append(c)
        advance()
      }
      if result.isEmpty {
        throw LexError(message: "expected digit after .-", line: line, column: column)
      }
      return .index(-Int(result)!)
    }
    if current?.isNumber == true {
      var result = ""
      while let c = current, c.isNumber {
        result.append(c)
        advance()
      }
      return .index(Int(result)!)
    }
    throw LexError(message: "expected digit after .", line: line, column: column)
  }

  mutating func readOperator() throws -> Token {
    let c = current!
    if let next = peek() {
      let two = String([c, next])
      if ["==", "!=", "<=", ">=", "&&", "||"].contains(two) {
        advance()
        advance()
        return .op(two)
      }
    }
    advance()
    return .op(String(c))
  }

  mutating func tokenize() throws -> [Token] {
    var tokens: [Token] = []
    while true {
      let t = try nextToken()
      tokens.append(t)
      if t == .eof { break }
    }
    return tokens
  }
}
