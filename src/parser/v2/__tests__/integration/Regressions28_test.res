// Regressions28_test.res
// Codex-review-driven regressions, round 29.

open Vitest

describe("Regression P2: standalone CR line endings (Codex round 29)", () => {
  test("CR-only line endings parse a Container correctly (no UnclosedContainer)", t => {
    let src = "@scene: s\r\r+----+\r|    |\r+----+"
    let result = V2Parser.parse(src, ())
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(false)
    t->expect(result.success)->Expect.toBe(true)
  })

  test("CR rows increment row coordinate", t => {
    let tokens = Lexer.tokenize("a\rb")
    // a (row 0), newline, b (row 1)
    let bTok = tokens->Array.getUnsafe(2)
    t->expect(bTok.position.row)->Expect.toBe(1)
  })
})

describe("Regression P2: every nested block declaration reported (Codex round 29)", () => {
  test("two nested @scene declarations in one container → TWO NestedBlockDeclaration errors", t => {
    let src = `@scene: outer

+---------------+
| @scene: alpha |
| body          |
| @scene: beta  |
| body          |
+---------------+`
    let result = V2Parser.parse(src, ())
    let nestedCount = Array.length(
      Array.filter(result.errors, (e: V2Errors.parseError) =>
        switch e.code {
        | NestedBlockDeclaration => true
        | _ => false
        }
      ),
    )
    t->expect(nestedCount)->Expect.toBe(2)
  })

  test("three nested @scene declarations produce three errors", t => {
    let src = `@scene: outer

+----------------+
| @scene: a      |
| @scene: b      |
| @scene: c      |
+----------------+`
    let result = V2Parser.parse(src, ())
    let nestedCount = Array.length(
      Array.filter(result.errors, (e: V2Errors.parseError) =>
        switch e.code {
        | NestedBlockDeclaration => true
        | _ => false
        }
      ),
    )
    t->expect(nestedCount)->Expect.toBe(3)
  })
})
