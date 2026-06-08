// Regressions15_test.res
// Codex-review-driven regressions, round 15.

open Vitest

describe("Regression P2: strict parse mode (Codex round 15)", () => {
  test("strict=true halts at first block with an error (subsequent blocks NOT parsed)", t => {
    let src = `@scene: first

[__unclosed

@scene: second

OK here`
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, strict: true}
    let result = V2Parser.parse(src, ~options=opts, ())
    // Only the first block should appear; we halted on its UnclosedInput.
    t->expect(Array.length(result.blocks))->Expect.toBe(1)
    switch result.blocks->Array.get(0) {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("first")
    | _ => t->expect("missing-first")->Expect.toBe("found")
    }
    t->expect(result.success)->Expect.toBe(false)
  })

  test("strict=true promotes recoverable errors to non-recoverable", t => {
    let src = `@scene: s

[__unclosed`
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, strict: true}
    let result = V2Parser.parse(src, ~options=opts, ())
    // Find an UnclosedInput error and confirm recoverable=false.
    let unclosed = Array.find(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    switch unclosed {
    | Some(e) => t->expect(e.recoverable)->Expect.toBe(false)
    | None => t->expect("no-unclosed-error")->Expect.toBe("found")
    }
  })

  test("strict=false (default) still parses subsequent blocks after an error", t => {
    let src = `@scene: first

[__unclosed

@scene: second

OK here`
    let result = V2Parser.parse(src, ())
    // Both blocks should appear in non-strict mode.
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
  })

  test("strict=false keeps the recoverable=true flag", t => {
    let src = `@scene: s

[__unclosed`
    let result = V2Parser.parse(src, ())
    let unclosed = Array.find(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    switch unclosed {
    | Some(e) => t->expect(e.recoverable)->Expect.toBe(true)
    | None => t->expect("no-unclosed-error")->Expect.toBe("found")
    }
  })

  test("strict=true on clean input still produces success=true", t => {
    let src = `@scene: s

Hello`
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, strict: true}
    let result = V2Parser.parse(src, ~options=opts, ())
    t->expect(result.success)->Expect.toBe(true)
    t->expect(Array.length(result.errors))->Expect.toBe(0)
  })
})
