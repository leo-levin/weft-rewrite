struct FuncDef {
  let params: [String]
  let body: Expr
}

struct Env {
  var names: [String: ID] = [:]
  var coords: [String: ID] = [:]
  var funcs: [String: FuncDef] = [:]
}

class IRBuilder {
  var nodes: [IRNode] = []
  var memo: [IRNode: ID] = [:]

  func getNode(_ node: IRNode) -> ID {
    if let existing = memo[node] { return existing }
    let id = nodes.count
    nodes.append(node)
    memo[node] = id
    return id
  }
}

func lower(_ expr: Expr, env: Env, builder: IRBuilder) -> ID {
  switch expr {
  case .number(let f, _):
    return builder.getNode(.num(f))

  case .coord(let c, _):
    if let rebound = env.coords[c] {
      return rebound
    }
    return builder.getNode(.coord(c))

  case .name(let n, _):
    return env.names[n]!

  case .binOp(let op, let lhs, let rhs, _):
    let lhsID = lower(lhs, env: env, builder: builder)
    let rhsID = lower(rhs, env: env, builder: builder)
    return builder.getNode(.binOp(op, lhsID, rhsID))

  case .unOp(let op, let expr, _):
    let exprID = lower(expr, env: env, builder: builder)
    return builder.getNode(.unOp(op, exprID))

  case .ifExpr(let cond, let t, let e, _):
    let condID = lower(cond, env: env, builder: builder)
    let thenID = lower(t, env: env, builder: builder)
    let elseID = lower(e, env: env, builder: builder)
    return builder.getNode(.ifExpr(cond: condID, then: thenID, else_: elseID))

  case .tuple(let elems, _):
    let ids = elems.map { lower($0, env: env, builder: builder) }
    return builder.getNode(.tuple(ids))

  case .index(let expr, let i, _):
    let exprID = lower(expr, env: env, builder: builder)
    return builder.getNode(.index(exprID, i))

  case .string(_, _):
    fatalError("strings don't lower to IR")

  case .whereExpr(let body, let bindings, _):
    var newEnv = env
    for bind in bindings {
      switch bind {
      case .bind(let name, let expr, _):
        let id = lower(expr, env: newEnv, builder: builder)
        newEnv.names[name] = id
      case .coordBind(let coord, let expr, _):
        let id = lower(expr, env: newEnv, builder: builder)
        newEnv.coords[coord] = id
      case .destructure(let names, let expr, _):
        let id = lower(expr, env: newEnv, builder: builder)
        for (i, name) in names.enumerated() {
          let indexNode = IRNode.index(id, i)
          let indexID = builder.getNode(indexNode)
          newEnv.names[name] = indexID
        }
      case .funcBind(let name, let params, let body, _):
        newEnv.funcs[name] = FuncDef(params: params, body: body)
      }
    }
    return lower(body, env: newEnv, builder: builder)
  case .call(let fn, let args, _):
    guard case .name(let fnName, _) = fn else {
      fatalError("only named functions can be called")
    }
    guard let funcDef = env.funcs[fnName] else {
      fatalError("unknown function: \(fnName)")
    }
    guard funcDef.params.count == args.count else {
      fatalError("arity mismatch calling \(fnName)")
    }
    var callEnv = env
    for (param, arg) in zip(funcDef.params, args) {
      let argID = lower(arg, env: env, builder: builder)
      callEnv.names[param] = argID
    }
    return lower(funcDef.body, env: callEnv, builder: builder)

  }
}

struct IRProgram {
  let builder: IRBuilder
  let roots: [(name: String, id: ID)]
}

func lowerProgram(_ program: [TopLevel]) -> IRProgram {
  let builder = IRBuilder()
  let env = buildInitialEnv(program: program)
  var roots: [(name: String, id: ID)] = []
  for topLevel in program {
    switch topLevel {
    case .def(let def):
      if def.params.isEmpty {
        let id = lower(def.body, env: env, builder: builder)
        roots.append((name: def.name, id: id))
      }
    case .destructure(let d):
      let id = lower(d.body, env: env, builder: builder)
      for (i, name) in d.names.enumerated() {
        let indexNode = IRNode.index(id, i)
        let indexID = builder.getNode(indexNode)
        roots.append((name: name, id: indexID))
      }
    }
  }
  return IRProgram(builder: builder, roots: roots)
}

func buildInitialEnv(program: [TopLevel]) -> Env {
  var env = Env()
  for topLevel in program {
    switch topLevel {
    case .def(let def):
      if def.params.isEmpty {
        env.funcs[def.name] = FuncDef(params: [], body: def.body)
      } else {
        env.funcs[def.name] = FuncDef(params: def.params, body: def.body)
      }
    case .destructure(let _):
      break
    }
  }
  return env
}
