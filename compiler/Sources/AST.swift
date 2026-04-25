// AST.swift

struct Def {
  let name: String
  let params: [String]
  let body: Expr
}

struct DestructureDef {
  let names: [String]
  let body: Expr
}

enum TopLevel {
  case def(Def)
  case destructure(DestructureDef)
}

enum Binding {
  case bind(name: String, expr: Expr)
  case destructure(names: [String], expr: Expr)
}

indirect enum Expr {
  case number(Float)
  case string(String)
  case name(String)
  case coord(String)
  case tuple([Expr])
  case call(fn: Expr, args: [Expr])
  case index(expr: Expr, i: Int)
  case binOp(op: String, lhs: Expr, rhs: Expr)
  case unOp(op: String, expr: Expr)
  case ifExpr(cond: Expr, then: Expr, else_: Expr)
  case whereExpr(body: Expr, bindings: [Binding])
}
