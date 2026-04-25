```
  Program     = Definition*

  Definition  = FuncDef | DestructureDef | SignalDef
  DestructureDef = "(" NonemptyListOf<name, ","> ")" "=" Expr ";"
  FuncDef     = name "(" Params ")" "=" Expr ";"
  SignalDef   = name "=" Expr ";"

  Params      = NonemptyListOf<name, ",">

  Expr        = WhereExpr | IfExpr | BinExpr

  WhereExpr   = (IfExpr | BinExpr) kwWhere "{" Bindings "}"
  Bindings    = Binding (";" Binding)* ";"?
  Binding = "(" NonemptyListOf<name, ","> ")" "=" Expr  -- destructure
          | coord "=" Expr                                -- coordBind
          | name "=" Expr                                 -- simple

  IfExpr      = kwIf "{" Expr "}" kwThen "{" Expr "}" kwElse "{" Expr "}"

  BinExpr    = OrExpr
  OrExpr     = OrExpr "||" AndExpr  -- or
             | AndExpr              -- pass

  AndExpr    = AndExpr "&&" CmpExpr -- and
             | CmpExpr              -- pass

  CmpExpr    = CmpExpr ("==" | "!=" | "<=" | ">=" | "<" | ">") AddExpr -- cmp
             | AddExpr              -- pass

  AddExpr    = AddExpr ("+" | "-") MulExpr -- add
             | MulExpr              -- pass

  MulExpr    = MulExpr ("*" | "/" | "%") ExpExpr -- mul
             | ExpExpr              -- pass

  ExpExpr    = UnaryExpr "^" ExpExpr -- exp
             | UnaryExpr            -- pass

  UnaryExpr  = "-" UnaryExpr        -- neg
             | "!" UnaryExpr        -- not
             | PostfixExpr          -- pass

  PostfixExpr = PostfixExpr "(" Args ")"  -- call
              | PostfixExpr "." integer   -- index
              | PostfixExpr ".-" integer  -- negIndex
              | AtomExpr                  -- pass

  AtomExpr   = coord                -- coord
             | number               -- number
             | string               -- string
             | name                 -- name
             | Tuple                -- tuple
             | "(" Expr ")"        -- paren

  Args        = ListOf<Expr, ",">
  Tuple       = "(" NonemptyListOf<Expr, ","> ")"
  coord       = "@" name

  kwIf    = "if"    ~(alnum | "_")
  kwThen  = "then"  ~(alnum | "_")
  kwElse  = "else"  ~(alnum | "_")
  kwWhere = "where" ~(alnum | "_")

  name    = ~(kwIf | kwThen | kwElse | kwWhere) letter (alnum | "_")*
  integer = digit+
  number  = digit+ ("." digit+)?
  string  = "\"" (~"\"" any)* "\""

  space := " " | "\t" | "\n" | "\r" | comment
  comment = "--" (~"\n" any)* "\n"
}
```
