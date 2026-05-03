import Foundation

struct Runtime {
  let program: IRProgram
  var feedbackBuffers: [Int: [Float: Float]] = [:]

  func evaluate(_ id: ID, coords: [String: Float]) -> Float {
    switch program.builder.nodes[id] {
    case .num(let f):
      return f
    case .coord(let name):
      guard let v = coords[name] else {
        fatalError("coord '\(name)' not provided by output")
      }
      return v
    case .binOp(let op, let a, let b):
      let l = evaluate(a, coords: coords)
      let r = evaluate(b, coords: coords)
      switch op {
      case .add: return l + r
      case .sub: return l - r
      case .mul: return l * r
      case .div: return r == 0 ? 0 : l / r
      case .mod: return r == 0 ? 0 : l.truncatingRemainder(dividingBy: r)
      case .pow: return pow(l, r)
      case .lt: return l < r ? 1 : 0
      case .le: return l <= r ? 1 : 0
      case .gt: return l > r ? 1 : 0
      case .ge: return l >= r ? 1 : 0
      case .eq: return l == r ? 1 : 0
      case .neq: return l != r ? 1 : 0
      case .and: return (l != 0 && r != 0) ? 1 : 0
      case .or: return (l != 0 || r != 0) ? 1 : 0
      }
    case .unOp(let op, let a):
      let v = evaluate(a, coords: coords)
      switch op {
      case .neg: return -v
      case .not: return v == 0 ? 1 : 0
      }
    case .ifExpr(let c, let t, let e):
      return evaluate(c, coords: coords) != 0
        ? evaluate(t, coords: coords)
        : evaluate(e, coords: coords)
    case .feedbackRead(let slotID, let indices):
      let key: Float = indices.isEmpty ? 0 : evaluate(indices[0], coords: coords)
      return feedbackBuffers[slotID]?[key] ?? 0
    case .buffer, .tuple, .index:
      return 0
    }
  }

  mutating func writeFeedback(coords: [String: Float]) {
    for write in program.feedbackWrites {
      let value = evaluate(write.valueID, coords: coords)
      let key: Float
      if write.indexCoords.isEmpty {
        key = 0
      } else if write.indexCoords.count == 1 {
        key = coords[write.indexCoords[0]] ?? 0
      } else {
        fatalError("2D+ feedback buffers not yet supported")
      }
      feedbackBuffers[write.slotID, default: [:]][key] = value
    }
  }
  mutating func run(outputName: String, coords: [String: Float]) -> Float? {
    guard let root = program.roots.first(where: { $0.name == outputName }) else { return nil }
    let value = evaluate(root.id, coords: coords)
    writeFeedback(coords: coords)
    return value
  }
}
