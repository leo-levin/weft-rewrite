struct FuncDef {
  let params: [String]
  let body: Expr
}

struct LoweringError: Error {
  let message: String
  let span: Span
}

struct Env {
  var names: [String: ID] = [:]
  var coords: [String: ID] = [:]
  var funcs: [String: FuncDef] = [:]
  var resolving: [String: [String: ID]] = [:]
}

class IRBuilder {
  var nodes: [IRNode] = []
  var memo: [IRNode: ID] = [:]
  var feedbackSlots: [String: (slotID: Int, indexCoords: [String])] = [:]
  var feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String])] = []
  private var nextSlotID = 0

  func getNode(_ node: IRNode) -> ID {
    if let existing = memo[node] { return existing }
    let id = nodes.count
    nodes.append(node)
    memo[node] = id
    return id
  }

  func allocateSlot(for name: String, indexCoords: [String]) -> Int {
    if let existing = feedbackSlots[name] { return existing.slotID }
    let id = nextSlotID
    nextSlotID += 1
    feedbackSlots[name] = (slotID: id, indexCoords: indexCoords)
    return id
  }
}

func lowerSignal(_ name: String, def: FuncDef, env: Env, builder: IRBuilder) throws -> ID {
  if let snapshot = env.resolving[name] {
    var indexCoords: [String] = []
    let indices = env.coords.compactMap { (coord, currentID) -> ID? in
      let rawCoord = builder.getNode(.coord(coord))
      let snapshotID = snapshot[coord] ?? rawCoord
      guard currentID != snapshotID else { return nil }
      indexCoords.append(coord)
      return currentID
    }
    let slotID = builder.allocateSlot(for: name, indexCoords: indexCoords)
    return builder.getNode(.feedbackRead(slotID: slotID, indices: indices))
  }

  var newEnv = env
  newEnv.resolving[name] = env.coords
  let id = try lower(def.body, env: newEnv, builder: builder)
  if let slot = builder.feedbackSlots[name],
    !builder.feedbackWrites.contains(where: { $0.slotID == slot.slotID })
  {
    builder.feedbackWrites.append((slotID: slot.slotID, valueID: id, indexCoords: slot.indexCoords))
  }
  return id
}

func lower(_ expr: Expr, env: Env, builder: IRBuilder) throws -> ID {
  switch expr {
  case .number(let f, _):
    return builder.getNode(.num(f))

  case .coord(let c, _):
    if let rebound = env.coords[c] {
      return rebound
    }
    return builder.getNode(.coord(c))

  case .name(let n, _):
    if let id = env.names[n] { return id }
    if let def = env.funcs[n], def.params.isEmpty {
      return try lowerSignal(n, def: def, env: env, builder: builder)
    }
    throw LoweringError(message: "unknown name '\(n)'", span: expr.span)

  case .binOp(let op, let lhs, let rhs, _):
    let lhsID = try lower(lhs, env: env, builder: builder)
    let rhsID = try lower(rhs, env: env, builder: builder)
    return builder.getNode(.binOp(op, lhsID, rhsID))

  case .unOp(let op, let expr, _):
    let exprID = try lower(expr, env: env, builder: builder)
    return builder.getNode(.unOp(op, exprID))

  case .ifExpr(let cond, let t, let e, _):
    let condID = try lower(cond, env: env, builder: builder)
    let thenID = try lower(t, env: env, builder: builder)
    let elseID = try lower(e, env: env, builder: builder)
    return builder.getNode(.ifExpr(cond: condID, then: thenID, else_: elseID))

  case .tuple(let elems, _):
    let ids = try elems.map { try lower($0, env: env, builder: builder) }
    return builder.getNode(.tuple(ids))

  case .index(let expr, let i, _):
    let exprID = try lower(expr, env: env, builder: builder)
    return builder.getNode(.index(exprID, i))

  case .string(_, _):
    throw LoweringError(message: "strings do not lower to IR", span: expr.span)

  case .whereExpr(let body, let bindings, _):
    var newEnv = env
    for bind in bindings {
      switch bind {
      case .bind(let name, let expr, _):
        newEnv.funcs[name] = FuncDef(params: [], body: expr)
      case .coordBind(let coord, let expr, _):
        let id = try lower(expr, env: newEnv, builder: builder)
        newEnv.coords[coord] = id
      case .destructure(let names, let expr, _):
        let id = try lower(expr, env: newEnv, builder: builder)
        for (i, name) in names.enumerated() {
          let indexNode = IRNode.index(id, i)
          let indexID = builder.getNode(indexNode)
          newEnv.names[name] = indexID
        }

      case .funcBind(let name, let params, let body, _):
        newEnv.funcs[name] = FuncDef(params: params, body: body)
      }
    }
    return try lower(body, env: newEnv, builder: builder)
  case .call(let fn, let args, _):
    guard case .name(let fnName, _) = fn else {
      throw LoweringError(message: "only named functions can be called", span: fn.span)
    }
    guard let funcDef = env.funcs[fnName] else {
      throw LoweringError(message: "unknown function '\(fnName)'", span: fn.span)
    }
    guard funcDef.params.count == args.count else {
      throw LoweringError(
        message:
          "arity mismatch calling '\(fnName)': expected \(funcDef.params.count), got \(args.count)",
        span: expr.span)
    }
    var callEnv = env
    for (param, arg) in zip(funcDef.params, args) {
      let argID = try lower(arg, env: env, builder: builder)
      callEnv.names[param] = argID
    }
    return try lower(funcDef.body, env: callEnv, builder: builder)

  }
}

struct IRProgram {
  let builder: IRBuilder
  let roots: [(name: String, id: ID)]
  var feedbackWrites: [(slotID: Int, valueID: ID, indexCoords: [String])] { builder.feedbackWrites }
}

func lowerProgram(_ program: [TopLevel]) throws -> IRProgram {
  let builder = IRBuilder()
  var env = Env()
  var rootNames: [String] = []
  var roots: [(name: String, id: ID)] = []

  for topLevel in program {
    switch topLevel {
    case .def(let def):
      env.funcs[def.name] = FuncDef(params: def.params, body: def.body)
      if def.params.isEmpty { rootNames.append(def.name) }
    case .destructure(let d):
      let id = try lower(d.body, env: env, builder: builder)
      for (i, name) in d.names.enumerated() {
        let indexID = builder.getNode(.index(id, i))
        env.names[name] = indexID
        roots.append((name: name, id: indexID))
      }
    }
  }

  for name in rootNames {
    let id = try lowerSignal(name, def: env.funcs[name]!, env: env, builder: builder)
    roots.append((name: name, id: id))
  }

  return IRProgram(builder: builder, roots: roots)
}
