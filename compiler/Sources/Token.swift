struct Token: Equatable {
  let kind: TokenKind
  let span: Span
}

enum TokenKind: Equatable, Hashable {
  // Literals and identifiers
  case number(Float)
  case string(String)
  case name(String)
  // Coord carries the raw name without the leading `@`. The compiler does
  // not enumerate valid coord names — see project_coords_agnostic.md.
  case coord(String)

  // Keywords
  case kwWhere
  case kwIf
  case kwThen
  case kwElse

  // Operators (typed; see Operators.swift)
  case op(OpToken)

  // Punctuation
  case lparen
  case rparen
  case lbrace
  case rbrace
  case comma
  case equals
  case semicolon

  // Postfix index: `.0`, `.1`, `.-2`, etc.
  case index(Int)

  case eof
}
