import Foundation
import WeftIR

public enum RuntimeError: Error {
  case unknownRoot(String)
}

public struct OutputID: Hashable {
  let id: Int
}

public class Runtime {
  let program: IRProgram
  var buffers: ArrayBufferStore
  // TODO: double buffering — frontBuffers/backBuffers + swap

  var feedbackBuffers: [OutputID: [Int: FeedbackBuffer]]
  var resources: [Resource]
  var outputs: [(id: OutputID, output: Output, rootID: ID, rate: Float)]

  private var nextOutputID = 0

  public init(program: IRProgram) {
    self.program = program
    self.buffers = ArrayBufferStore()
    self.feedbackBuffers = [:]
    self.resources = []
    self.outputs = []
  }

  public func register(resource: Resource) {
    resources.append(resource)
  }
  public func register(output: Output, rate: Float) throws -> OutputID {
    guard let root = program.roots.first(where: { $0.name == output.rootName }) else {
      throw RuntimeError.unknownRoot(output.rootName)
    }

    let outputID = OutputID(id: nextOutputID)
    nextOutputID += 1

    outputs.append((id: outputID, output: output, rootID: root.id, rate: rate))
    return outputID
  }
}
