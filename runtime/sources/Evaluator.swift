import WeftIR

public func evaluate(
  _ id: ID,
  nodes: [IRNode],
  coords: [String: Float],
  buffers: some BufferStore,
  feedbackBuffers: [Int: [Float: Float]]
) -> [Float] {
  func eval(_ id: ID) -> [Float] {
    switch nodes[id] {
    case .num(let f):
      return [f]

    case .coord(let name):
      guard let v = coords[name] else {
        preconditionFailure("coord '\(name)' not provided")
      }
      return [v]

    case .binOp(let op, let a, let b):
      let l = eval(a)[0]
      let r = eval(b)[0]
      let result: Float
      switch op {
      case .add: result = l + r
      case .sub: result = l - r
      case .mul: result = l * r
      case .div: result = r == 0 ? 0 : l / r
      case .mod: result = r == 0 ? 0 : l.truncatingRemainder(dividingBy: r)
      case .pow: result = pow(l, r)
      case .lt: result = l < r ? 1 : 0
      case .le: result = l <= r ? 1 : 0
      case .gt: result = l > r ? 1 : 0
      case .ge: result = l >= r ? 1 : 0
      case .eq: result = l == r ? 1 : 0
      case .neq: result = l != r ? 1 : 0
      case .and: result = (l != 0 && r != 0) ? 1 : 0
      case .or: result = (l != 0 || r != 0) ? 1 : 0
      }
      return [result]

    case .unOp(let op, let a):
      let v = eval(a)[0]
      switch op {
      case .neg: return [-v]
      case .not: return [v == 0 ? 1 : 0]
      }

    case .ifExpr(let c, let t, let e):
      return eval(c)[0] != 0 ? eval(t) : eval(e)

    case .tuple(let ids):
      return ids.flatMap { eval($0) }

    case .index(let expr, let i):
      return [eval(expr)[i]]

    case .buffer(let bufID, let indices):
      let indexValues = indices.map { eval($0)[0] }
      return [buffers.read(bufID, at: indexValues)]

    case .feedbackRead(let slotID, let indices):
      let key: Float = indices.isEmpty ? 0 : eval(indices[0])[0]
      return [feedbackBuffers[slotID]?[key] ?? 0]
    }
  }
  return eval(id)
}
