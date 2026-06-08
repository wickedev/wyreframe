// Regressions34_test.res
// Codex-review-driven regressions, round 38.

open Vitest

describe("Regression P2: duplicate Button/Link IDs reported (Codex round 38)", () => {
  test("two `[ Save ]` buttons emit DuplicateContainerId warning with slug=save", t => {
    let src = `@scene: s

[ Save ]
[ Save ]`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicateContainerId(id) => id == "save"
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(true)
  })

  test("two identical `< More >` links emit duplicate warning", t => {
    let src = `@scene: s

< More >
< More >`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicateContainerId(id) => id == "more"
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(true)
  })

  test("identical Select placeholders also emit duplicate warning", t => {
    let src = `@scene: s

[v: City ]
[v: City ]`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicateContainerId(id) => id == "city"
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(true)
  })

  test("distinct button labels emit NO duplicate warning", t => {
    let src = `@scene: s

[ Save ]
[ Cancel ]`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicateContainerId(_) => true
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(false)
  })

  test("Container id and Button id sharing a slug also emit duplicate", t => {
    let src = `@scene: s

+--#save--+
|         |
+---------+
[ Save ]`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicateContainerId(id) => id == "save"
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(true)
  })
})
