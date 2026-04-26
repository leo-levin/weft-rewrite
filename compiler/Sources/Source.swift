struct SourceLoc: Equatable, Hashable {
  let line: Int
  let column: Int
}

struct Span: Equatable, Hashable {
  let start: SourceLoc
  let end: SourceLoc

  /// Build a span covering both inputs. Assumes `a` precedes `b` in the source.
  static func merge(_ a: Span, _ b: Span) -> Span {
    Span(start: a.start, end: b.end)
  }
}
