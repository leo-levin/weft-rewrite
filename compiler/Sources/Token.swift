// lexical tokens

enum Token: Equatable {
  case number(Float)
  case string(String)

  case name(String)
  case coord(String)

  case kwWhere
  case kwIf
  case kwThen
  case kwElse
  case kwFor
  case kwIn

  case op(String)
  case lparen
  case rparen
  case comma
  case equals
  case dot

  case lbrace
  case rbrace
  case semicolon

  case index(Int)

  case dotdot

  case hash
  case eof
}
