typealias ID = Int

typealias BufferID = Int

enum BindLHS: Hashable {
  case name(String)
  case coord(String)
  case destructure([String])
}

enum IRNode: Hashable {
  case num(Float)
  case coord(String)
  case buffer(BufferID, indices: [ID])
  case tuple([ID])
  case index(ID, Int)
  case binOp(BinOp, ID, ID)
  case unOp(UnOp, ID)
  case ifExpr(cond: ID, then: ID, else_: ID)
  case whereBind(lhs: BindLHS, bound: ID, body: ID)
}
