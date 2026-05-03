import WeftIR

// MARK: - Hems

public enum HemValue: Equatable {
  case int(Int)
  case float(Float)
  case string(String)
  case bool(Bool)
}

public struct HemDecl {
  public let name: String
  public let width: Int?
  public let op: String
  public let args: [(String, HemValue)]
  public let span: Span
}

// MARK: - Definitions

public struct Def {
  public let name: String
  public let params: [String]
  public let body: Expr
  public let span: Span
}

public struct DestructureDef {
  public let names: [String]
  public let body: Expr
  public let span: Span
}

public enum TopLevel {
  case def(Def)
  case destructure(DestructureDef)
  case hem(HemDecl)
}

extension TopLevel {
  var span: Span {
    switch self {
    case .def(let d): return d.span
    case .destructure(let d): return d.span
    case .hem(let h): return h.span
    }
  }
}

public enum Binding {
  case bind(name: String, expr: Expr, span: Span)
  case destructure(names: [String], expr: Expr, span: Span)
  case coordBind(coord: String, expr: Expr, span: Span)
  case funcBind(name: String, params: [String], body: Expr, span: Span)
}

extension Binding {
  var span: Span {
    switch self {
    case .bind(_, _, let s): return s
    case .destructure(_, _, let s): return s
    case .coordBind(_, _, let s): return s
    case .funcBind(_, _, _, let s): return s
    }
  }
}
public indirect enum Expr {
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
