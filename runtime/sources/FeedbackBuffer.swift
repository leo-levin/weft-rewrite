public struct FeedbackBuffer {
  public var data: [Float]
  public var writeHead: Int = 0

  public init(size: Int, fill: Float = 0.0) {
    self.data = [Float](repeating: fill, count: size)
  }

  public func read(offset: Int) -> Float {
    precondition(offset >= 1, "offset must be at least 1")
    let count = data.count
    let idx = ((writeHead - offset) % count + count) % count
    return data[idx]
  }

  public mutating func write(value: Float) {
    data[writeHead % data.count] = value
    writeHead += 1
  }
}
