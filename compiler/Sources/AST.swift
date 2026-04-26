struct Def {
  let name: String
  let params: [String]
  let body: Expr
  let span: Span
}

struct DestructureDef {
  let names: [String]
  let body: Expr
  let span: Span
}

enum TopLevel {
  case def(Def)
  case destructure(DestructureDef)
}

extension TopLevel {
  var span: Span {
    switch self {
    case .def(let d): return d.span
    case .destructure(let d): return d.span
    }
  }
}

enum Binding {
  case bind(name: String, expr: Expr, span: Span)
  case destructure(names: [String], expr: Expr, span: Span)
  // `@name = expr` inside a `where` block.
  case coordBind(coord: String, expr: Expr, span: Span)
}

extension Binding {
  var span: Span {
    switch self {
    case .bind(_, _, let s): return s
    case .destructure(_, _, let s): return s
    case .coordBind(_, _, let s): return s
    }
  }
}

indirect enum Expr {
  case number(Float, span: Span)
  case string(String, span: Span)
  case name(String, span: Span)
  case coord(String, span: Span)
  case tuple([Expr], span: Span)
  case call(fn: Expr, args: [Expr], span: Span)
  case index(expr: Expr, i: Int, span: Span)
  case binOp(op: BinOp, lhs: Expr, rhs: Expr, span: Span)
  case unOp(op: UnOp, expr: Expr, span: Span)
  case ifExpr(cond: Expr, then: Expr, else_: Expr, span: Span)
  case whereExpr(body: Expr, bindings: [Binding], span: Span)
}

extension Expr {
  var span: Span {
    switch self {
    case .number(_, let s): return s
    case .string(_, let s): return s
    case .name(_, let s): return s
    case .coord(_, let s): return s
    case .tuple(_, let s): return s
    case .call(_, _, let s): return s
    case .index(_, _, let s): return s
    case .binOp(_, _, _, let s): return s
    case .unOp(_, _, let s): return s
    case .ifExpr(_, _, _, let s): return s
    case .whereExpr(_, _, let s): return s
    }
  }
}
