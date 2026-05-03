import WeftIR

public struct OutputContext {
  public let rootID: ID
  public let evaluate: (ID, [String: Float]) -> [Float]

  public init(rootID: ID, evaluate: @escaping (ID, [String: Float]) -> [Float]) {
    self.rootID = rootID
    self.evaluate = evaluate
  }
}

public protocol Output {
  var groundedCoords: [String] { get }
  func start(context: OutputContext)
  func stop()
}

public protocol Resource {
  var writes: [BufferID] { get }
  var reads: [BufferID] { get }

  func start(buffers: BufferStore)
  func sync(time: Float)
  func stop()
}
