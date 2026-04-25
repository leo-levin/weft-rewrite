// PrettyPrint.swift

func prettyPrint(_ program: [TopLevel]) {
  for node in program {
    switch node {
    case .def(let d):
      prettyPrintDef(d)
    case .destructure(let d):
      print("(\(d.names.joined(separator: ", "))) = ")
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
  case .number(let f):
    print("\(pad)number \(f)")
  case .string(let s):
    print("\(pad)string \"\(s)\"")
  case .name(let s):
    print("\(pad)name \(s)")
  case .coord(let s):
    print("\(pad)coord @\(s)")
  case .tuple(let elems):
    print("\(pad)tuple")
    for e in elems { prettyPrintExpr(e, indent: indent + 2) }
  case .call(let fn, let args):
    print("\(pad)call")
    prettyPrintExpr(fn, indent: indent + 2)
    if !args.isEmpty {
      print("\(pad)  args")
      for a in args { prettyPrintExpr(a, indent: indent + 4) }
    }
  case .index(let expr, let i):
    print("\(pad)index .\(i)")
    prettyPrintExpr(expr, indent: indent + 2)
  case .binOp(let op, let lhs, let rhs):
    print("\(pad)binOp \(op)")
    prettyPrintExpr(lhs, indent: indent + 2)
    prettyPrintExpr(rhs, indent: indent + 2)
  case .unOp(let op, let expr):
    print("\(pad)unOp \(op)")
    prettyPrintExpr(expr, indent: indent + 2)
  case .ifExpr(let cond, let then, let else_):
    print("\(pad)if")
    print("\(pad)  cond")
    prettyPrintExpr(cond, indent: indent + 4)
    print("\(pad)  then")
    prettyPrintExpr(then, indent: indent + 4)
    print("\(pad)  else")
    prettyPrintExpr(else_, indent: indent + 4)
  case .whereExpr(let body, let bindings):
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
  case .bind(let name, let expr):
    print("\(pad)\(name) =")
    prettyPrintExpr(expr, indent: indent + 2)
  case .destructure(let names, let expr):
    print("\(pad)(\(names.joined(separator: ", "))) =")
    prettyPrintExpr(expr, indent: indent + 2)
  }
}
