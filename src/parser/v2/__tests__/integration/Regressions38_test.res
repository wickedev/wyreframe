// Regressions38_test.res
// Codex-review-driven regressions, round 48.

open Vitest

describe("Regression P2: tab-separated format-2 ID line is invalid (Codex round 48)", () => {
  test("`#foo\\tbar` inside container emits InvalidIdFormat (not silently assigned id=foo\\tbar)", t => {
    let src = "@scene: s\n\n+----------+\n|#foo\tbar |\n+----------+"
    let result = V2Parser.parse(src, ())
    let hasInvalid = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | InvalidIdFormat => true
      | _ => false
      }
    )
    t->expect(hasInvalid)->Expect.toBe(true)
  })

  test("`#foo bar` (space-separated) still emits InvalidIdFormat", t => {
    let src = `@scene: s

+----------+
|#foo bar  |
+----------+`
    let result = V2Parser.parse(src, ())
    let hasInvalid = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | InvalidIdFormat => true
      | _ => false
      }
    )
    t->expect(hasInvalid)->Expect.toBe(true)
  })

  test("`#foo` alone (no extra content) is still a valid format-2 ID", t => {
    let src = `@scene: s

+----------+
|  #foo    |
+----------+`
    let result = V2Parser.parse(src, ())
    let hasInvalid = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | InvalidIdFormat => true
      | _ => false
      }
    )
    t->expect(hasInvalid)->Expect.toBe(false)
  })

  test("tab-only id `#a\\tb\\tc` still rejected", t => {
    let src = "@scene: s\n\n+----------+\n|#a\tb\tc   |\n+----------+"
    let result = V2Parser.parse(src, ())
    let hasInvalid = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | InvalidIdFormat => true
      | _ => false
      }
    )
    t->expect(hasInvalid)->Expect.toBe(true)
  })
})
