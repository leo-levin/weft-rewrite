struct IRBuilder {
  var nodes: [IRNode] = []
  var memo: [IRNode: ID] = [:]

  mutating func getNode(_ node: IRNode) -> ID {
    if let existing = memo[node] { return existing }
    let id = nodes.count
    nodes.append(node)
    memo[node] = id
    return id
  }
}
