import WeftIR

public protocol BufferStore {
  func read(_ id: BufferID, at indices: [Float]) -> Float
  mutating func write(_ id: BufferID, at indices: [Float], value: Float)
  mutating func allocate(_ id: BufferID, shape: [Int], fill: Float)
  func exists(_ id: BufferID) -> Bool
}

struct Buffer {
  let shape: [Int]
  var data: [Float]

  init(shape: [Int], fill: Float = 0.0) {
    self.shape = shape
    let size = shape.isEmpty ? 1 : shape.reduce(1, *)
    self.data = [Float](repeating: fill, count: size)
  }

  func read(at indices: [Float]) -> Float {
    let offset = rowMajorOffset(indices)
    return data[offset]
  }

  mutating func write(at indices: [Float], value: Float) {
    let offset = rowMajorOffset(indices)
    data[offset] = value
  }

  private func rowMajorOffset(_ indices: [Float]) -> Int {
    precondition(
      indices.count == shape.count,
      "index count \(indices.count) != shape dimensions \(shape.count)")

    if shape.isEmpty { return 0 }

    var offset = 0
    var stride = 1
    for i in (0..<shape.count).reversed() {
      let idx = Int((indices[i] * Float(shape[i])).rounded(.down))
      let clamped = min(max(idx, 0), shape[i] - 1)
      offset += clamped * stride
      stride *= shape[i]
    }
    return offset
  }
}

public struct ArrayBufferStore: BufferStore {
  private var buffers: [BufferID: Buffer] = [:]

  public init() {}

  public mutating func allocate(_ id: BufferID, shape: [Int], fill: Float = 0.0) {
    buffers[id] = Buffer(shape: shape, fill: fill)
  }

  public func read(_ id: BufferID, at indices: [Float]) -> Float {
    guard let buffer = buffers[id] else {
      preconditionFailure("buffer \(id) not allocated")
    }
    return buffer.read(at: indices)
  }

  public mutating func write(_ id: BufferID, at indices: [Float], value: Float) {
    guard var buffer = buffers[id] else {
      preconditionFailure("buffer \(id) not allocated")
    }
    buffer.write(at: indices, value: value)
    buffers[id] = buffer
  }

  public func exists(_ id: BufferID) -> Bool {
    buffers[id] != nil
  }
}
