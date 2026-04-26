// MARK: - Lexer-level operator tokens

enum OpToken: Equatable, Hashable {
  case plus  // +
  case minus  // -
  case star  // *
  case slash  // /
  case percent  // %
  case caret  // ^
  case bang  // !
  case lt  // <
  case le  // <=
  case gt  // >
  case ge  // >=
  case eqeq  // ==
  case neq  // !=
  case andand  // &&
  case oror  // ||
}

extension OpToken {
  /// Source spelling, used in error messages and the pretty-printer.
  var symbol: String {
    switch self {
    case .plus: return "+"
    case .minus: return "-"
    case .star: return "*"
    case .slash: return "/"
    case .percent: return "%"
    case .caret: return "^"
    case .bang: return "!"
    case .lt: return "<"
    case .le: return "<="
    case .gt: return ">"
    case .ge: return ">="
    case .eqeq: return "=="
    case .neq: return "!="
    case .andand: return "&&"
    case .oror: return "||"
    }
  }
}

// MARK: - AST/IR binary operators

enum BinOp: Equatable, Hashable {
  case add, sub, mul, div, mod, pow
  case lt, le, gt, ge, eq, neq
  case and, or
}

extension BinOp {
  var symbol: String {
    switch self {
    case .add: return "+"
    case .sub: return "-"
    case .mul: return "*"
    case .div: return "/"
    case .mod: return "%"
    case .pow: return "^"
    case .lt: return "<"
    case .le: return "<="
    case .gt: return ">"
    case .ge: return ">="
    case .eq: return "=="
    case .neq: return "!="
    case .and: return "&&"
    case .or: return "||"
    }
  }
}

// MARK: - AST/IR unary operators

enum UnOp: Equatable, Hashable {
  case neg, not
}

extension UnOp {
  var symbol: String {
    switch self {
    case .neg: return "-"
    case .not: return "!"
    }
  }
}
