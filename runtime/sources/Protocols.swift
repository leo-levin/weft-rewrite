import WeftIR

public struct OutputContext {
  public let evaluate: ([String: Float]) -> [Float]
}

protocol Output {
  var rootName: String { get }  // "display", "play", "dmx"
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
