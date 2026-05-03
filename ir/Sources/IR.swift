public typealias ID = Int
public typealias BufferID = Int

public enum BinOp: Equatable, Hashable {
  case add, sub, mul, div, mod, pow
  case lt, le, gt, ge, eq, neq
  case and, or
}

extension BinOp {
  public var symbol: String {
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

public enum UnOp: Equatable, Hashable {
  case neg, not
}

extension UnOp {
  public var symbol: String {
    switch self {
    case .neg: return "-"
    case .not: return "!"
    }
  }
}

public enum IRNode: Hashable {
  case num(Float)
  case coord(String)
  case buffer(BufferID, indices: [ID])
  case tuple([ID])
  case index(ID, Int)
  case binOp(BinOp, ID, ID)
  case unOp(UnOp, ID)
  case ifExpr(cond: ID, then: ID, else_: ID)
  case feedbackRead(slotID: Int, indices: [ID])
}

public struct IRProgram {
  public let nodes: [IRNode]
  public let roots: [(name: String, id: ID)]
  public let feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String])]
  public let feedbackSlots: [String: (slotID: Int, indexCoords: [String])]

  public init(
    nodes: [IRNode],
    roots: [(name: String, id: ID)],
    feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String])],
    feedbackSlots: [String: (slotID: Int, indexCoords: [String])]
  ) {
    self.nodes = nodes
    self.roots = roots
    self.feedbackWrites = feedbackWrites
    self.feedbackSlots = feedbackSlots
  }
}
