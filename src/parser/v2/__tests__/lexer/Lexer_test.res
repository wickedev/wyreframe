// Lexer smoke tests.
open Vitest
open Token

let getKind = (tokens, i) => (tokens->Array.getUnsafe(i)).kind
let getText = (tokens, i) => (tokens->Array.getUnsafe(i)).text

describe("V2 Lexer", () => {
  test("tokenizes a simple container line", t => {
    let tokens = Lexer.tokenize("+--Login--+")
    t->expect(Array.length(tokens))->Expect.toBe(6)
    t->expect(getKind(tokens, 0))->Expect.toBe(Plus)
    t->expect(getKind(tokens, 1))->Expect.toEqual(Dashes(2))
    t->expect(getKind(tokens, 2))->Expect.toBe(Identifier)
    t->expect(getText(tokens, 2))->Expect.toBe("Login")
    t->expect(getKind(tokens, 3))->Expect.toEqual(Dashes(2))
    t->expect(getKind(tokens, 4))->Expect.toBe(Plus)
    t->expect(getKind(tokens, 5))->Expect.toBe(EOF)
  })

  test("tracks row/col across newlines", t => {
    let tokens = Lexer.tokenize("a\nb")
    let aTok = tokens->Array.getUnsafe(0)
    let nl = tokens->Array.getUnsafe(1)
    let bTok = tokens->Array.getUnsafe(2)
    t->expect(aTok.position.row)->Expect.toBe(0)
    t->expect(aTok.position.col)->Expect.toBe(0)
    t->expect(nl.kind)->Expect.toBe(Newline)
    t->expect(bTok.position.row)->Expect.toBe(1)
    t->expect(bTok.position.col)->Expect.toBe(0)
  })

  test("tokenizes input bracket as separate tokens", t => {
    let tokens = Lexer.tokenize("[__email__]")
    t->expect(getKind(tokens, 0))->Expect.toBe(LBracket)
    t->expect(getKind(tokens, 1))->Expect.toEqual(Underscores(2))
    t->expect(getKind(tokens, 2))->Expect.toBe(Identifier)
    t->expect(getText(tokens, 2))->Expect.toBe("email")
    t->expect(getKind(tokens, 3))->Expect.toEqual(Underscores(2))
    t->expect(getKind(tokens, 4))->Expect.toBe(RBracket)
  })

  test("counts wide characters as 2 visual columns", t => {
    let tokens = Lexer.tokenize("한x")
    let id = tokens->Array.getUnsafe(0)
    t->expect(id.kind)->Expect.toBe(Identifier)
    t->expect(id.endPosition.col)->Expect.toBe(3)
  })

  test("handles CRLF as a single Newline", t => {
    let tokens = Lexer.tokenize("a\r\nb")
    t->expect(Array.length(tokens))->Expect.toBe(4)
    t->expect(getKind(tokens, 1))->Expect.toBe(Newline)
    let bTok = tokens->Array.getUnsafe(2)
    t->expect(bTok.position.row)->Expect.toBe(1)
  })
})

describe("V2 GridIndex", () => {
  test("charAt returns the expected character", t => {
    let src = "+--+\n|  |\n+--+"
    let tokens = Lexer.tokenize(src)
    let g = GridIndex.make(tokens)
    t->expect(GridIndex.charAt(g, tokens, ~row=0, ~col=0))->Expect.toBe("+")
    t->expect(GridIndex.charAt(g, tokens, ~row=0, ~col=1))->Expect.toBe("-")
    t->expect(GridIndex.charAt(g, tokens, ~row=1, ~col=0))->Expect.toBe("|")
    t->expect(GridIndex.charAt(g, tokens, ~row=2, ~col=3))->Expect.toBe("+")
    t->expect(GridIndex.charAt(g, tokens, ~row=1, ~col=2))->Expect.toBe(" ")
  })
})
