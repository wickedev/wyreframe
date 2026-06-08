// Regressions26_test.res
// Codex-review-driven regressions, round 27.

open Vitest

describe("Regression P2: body row missing one wall is reported (Codex round 27)", () => {
  test("`+-----+ / | abc / +-----+` (right wall missing on row 2) emits MisalignedContainerWall", t => {
    let src = `@scene: s

+-----+
| abc
+-----+`
    let result = V2Parser.parse(src, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(true)
  })

  test("`+--+ / abc | / +--+` (left wall missing) also emits MisalignedContainerWall", t => {
    let src = `@scene: s

+----+
abc  |
+----+`
    let result = V2Parser.parse(src, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(true)
  })

  test("perfectly walled body row emits NO wall warning", t => {
    let src = `@scene: s

+----+
| ab |
+----+`
    let result = V2Parser.parse(src, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(false)
  })

  test("blank row with only one wall does NOT emit warning", t => {
    // A blank "body" row is fine even with no walls.
    let src = `@scene: s

+----+
|    |

+----+`
    let result = V2Parser.parse(src, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(false)
  })
})
