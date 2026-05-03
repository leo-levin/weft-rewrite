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

