let source = """
  xor(a, b) = (a + b) % 2;

  bayer(ix, iy) = (8*xor(x0,y0) + 4*y0 + 2*xor(x1,y1) + y1) / 16
    where {
      x0 = ix % 2;
      x1 = ix / 2 % 2;
      y0 = iy % 2;
      y1 = iy / 2 % 2;
    };

  display = if { lum > threshold } then { 1.0 } else { 0.0 }
    where {
      ix = @x * @w % 4;
      iy = @y * @h % 4;
      threshold = bayer(ix, iy);
      lum = @x * 0.5;
    };
  """

do {
  var lexer = Lexer(source)
  let tokens = try lexer.tokenize()
  var parser = Parser(tokens: tokens)
  let ast = try parser.parse()
  let irProgram = lowerProgram(ast)
  func countNodes(_ expr: Expr) -> Int {
    switch expr {
    case .number, .string, .name, .coord:
      return 1
    case .tuple(let es, _):
      return 1 + es.map(countNodes).reduce(0, +)
    case .call(let fn, let args, _):
      return 1 + countNodes(fn) + args.map(countNodes).reduce(0, +)
    case .index(let e, _, _):
      return 1 + countNodes(e)
    case .binOp(_, let l, let r, _):
      return 1 + countNodes(l) + countNodes(r)
    case .unOp(_, let e, _):
      return 1 + countNodes(e)
    case .ifExpr(let c, let t, let e, _):
      return 1 + countNodes(c) + countNodes(t) + countNodes(e)
    case .whereExpr(let body, let bindings, _):
      return 1 + countNodes(body)
        + bindings.map { b -> Int in
          switch b {
          case .bind(_, let e, _): return countNodes(e)
          case .destructure(_, let e, _): return countNodes(e)
          case .coordBind(_, let e, _): return countNodes(e)
          case .funcBind(_, _, let e, _): return countNodes(e)
          }
        }.reduce(0, +)
    }
  }

  let totalAST = ast.map { tl -> Int in
    switch tl {
    case .def(let d): return countNodes(d.body)
    case .destructure(let d): return countNodes(d.body)
    }
  }.reduce(0, +)
  print("AST nodes: \(totalAST)")
  print("IR nodes: \(irProgram.builder.nodes.count)")
  prettyPrint(ast)
  prettyPrintIR(irProgram)
} catch let e as LexError {
  print("lex error at \(e.loc.line):\(e.loc.column): \(e.message)")
} catch let e as ParseError {
  print("parse error at \(e.loc.line):\(e.loc.column): \(e.message)")
}
