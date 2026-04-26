// prettyprint.swift
//
// Indented dump of a parsed AST, used for eyeballing parser output.
// Spans are intentionally not printed — they'd dominate the output.
// Operator and coord names print as their source spelling via the
// `symbol` / raw-string accessors.

func prettyPrint(_ program: [TopLevel]) {
  for node in program {
    switch node {
    case .def(let d):
      prettyPrintDef(d)
    case .destructure(let d):
      print("(\(d.names.joined(separator: ", "))) =")
      prettyPrintExpr(d.body, indent: 2)
    }
    print("")
  }
}

func prettyPrintDef(_ d: Def) {
  if d.params.isEmpty {
    print("def \(d.name)")
  } else {
    print("def \(d.name)(\(d.params.joined(separator: ", ")))")
  }
  prettyPrintExpr(d.body, indent: 2)
}

func prettyPrintExpr(_ expr: Expr, indent: Int) {
  let pad = String(repeating: " ", count: indent)
  switch expr {
  case .number(let f, _):
    print("\(pad)number \(f)")

  case .string(let s, _):
    print("\(pad)string \"\(s)\"")

  case .name(let s, _):
    print("\(pad)name \(s)")

  case .coord(let c, _):
    print("\(pad)coord @\(c)")

  case .tuple(let elems, _):
    print("\(pad)tuple")
    for e in elems { prettyPrintExpr(e, indent: indent + 2) }

  case .call(let fn, let args, _):
    print("\(pad)call")
    prettyPrintExpr(fn, indent: indent + 2)
    if !args.isEmpty {
      print("\(pad)  args")
      for a in args { prettyPrintExpr(a, indent: indent + 4) }
    }

  case .index(let expr, let i, _):
    print("\(pad)index .\(i)")
    prettyPrintExpr(expr, indent: indent + 2)

  case .binOp(let op, let lhs, let rhs, _):
    print("\(pad)binOp \(op.symbol)")
    prettyPrintExpr(lhs, indent: indent + 2)
    prettyPrintExpr(rhs, indent: indent + 2)

  case .unOp(let op, let expr, _):
    print("\(pad)unOp \(op.symbol)")
    prettyPrintExpr(expr, indent: indent + 2)

  case .ifExpr(let cond, let then, let else_, _):
    print("\(pad)if")
    print("\(pad)  cond")
    prettyPrintExpr(cond, indent: indent + 4)
    print("\(pad)  then")
    prettyPrintExpr(then, indent: indent + 4)
    print("\(pad)  else")
    prettyPrintExpr(else_, indent: indent + 4)

  case .whereExpr(let body, let bindings, _):
    print("\(pad)where")
    print("\(pad)  body")
    prettyPrintExpr(body, indent: indent + 4)
    print("\(pad)  bindings")
    for b in bindings { prettyPrintBinding(b, indent: indent + 4) }
  }
}

func prettyPrintBinding(_ binding: Binding, indent: Int) {
  let pad = String(repeating: " ", count: indent)
  switch binding {
  case .funcBind(let name, let params, let body, _):
    print("\(pad)\(name)(\(params.joined(separator: ", "))) =")
    prettyPrintExpr(body, indent: indent + 2)
  case .bind(let name, let expr, _):
    print("\(pad)\(name) =")
    prettyPrintExpr(expr, indent: indent + 2)

  case .destructure(let names, let expr, _):
    print("\(pad)(\(names.joined(separator: ", "))) =")
    prettyPrintExpr(expr, indent: indent + 2)

  case .coordBind(let coord, let expr, _):
    print("\(pad)@\(coord) =")
    prettyPrintExpr(expr, indent: indent + 2)
  }
}

func prettyPrintIR(_ program: IRProgram) {
  print("=== IR ===")
  print("Nodes:")
  for (id, node) in program.builder.nodes.enumerated() {
    print("  \(id): \(prettyIRNode(node))")
  }
  print("Roots:")
  for (name, id) in program.roots {
    print("  \(name) = \(id)")
  }
}

func prettyIRNode(_ node: IRNode) -> String {
  switch node {
  case .num(let f):
    return "num(\(f))"
  case .coord(let c):
    return "coord(@\(c))"
  case .buffer(let id, let indices):
    return "buffer(\(id), [\(indices.map { "\($0)" }.joined(separator: ", "))])"
  case .tuple(let ids):
    return "tuple(\(ids.map { "\($0)" }.joined(separator: ", ")))"
  case .index(let id, let i):
    return "index(\(id), \(i))"
  case .binOp(let op, let lhs, let rhs):
    return "binOp(\(op), \(lhs), \(rhs))"
  case .unOp(let op, let expr):
    return "unOp(\(op), \(expr))"
  case .ifExpr(let cond, let then, let else_):
    return "ifExpr(cond: \(cond), then: \(then), else: \(else_))"
  case .whereBind(let lhs, let bound, let body):
    return "whereBind(\(lhs), bound: \(bound), body: \(body))"
  }
}
