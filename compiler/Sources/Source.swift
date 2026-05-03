public struct SourceLoc: Equatable, Hashable {
  public let line: Int
  public let column: Int
}

public struct Span: Equatable, Hashable {
  public let start: SourceLoc
  public let end: SourceLoc

  static func merge(_ a: Span, _ b: Span) -> Span {
    Span(start: a.start, end: b.end)
  }
}
