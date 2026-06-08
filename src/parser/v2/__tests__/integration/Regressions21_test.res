// Regressions21_test.res
// Codex-review-driven regressions, round 22.

open Vitest

describe("Regression P2: defensive options merge from JS (Codex round 22)", () => {
  test("partial options object `{strict: true}` does NOT throw", t => {
    // Construct a partial-ish options shape via %raw and pass through parse.
    let partial: V2Parser.parseOptions = %raw(`{ strict: true }`)
    let result = V2Parser.parse("@scene: s\n\nHello", ~options=partial, ())
    t->expect(result.success)->Expect.toBe(true)
  })

  test("totally undefined options (no `~options` passed) still parses", t => {
    let result = V2Parser.parse("@scene: s\n\nHi", ())
    t->expect(result.success)->Expect.toBe(true)
  })

  test("partial options preserves the explicit `strict` value", t => {
    let partial: V2Parser.parseOptions = %raw(`{ strict: true }`)
    let result = V2Parser.parse("@scene: s\n\n[__abc", ~options=partial, ())
    // strict=true → error promoted to non-recoverable
    let unclosed = Array.find(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    switch unclosed {
    | Some(e) => t->expect(e.recoverable)->Expect.toBe(false)
    | None => t->expect("no-error")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: recovered nested block doesn't consume outer's closing border (Codex round 22)", () => {
  test("no spurious UnclosedContainer when recovering nested block", t => {
    let src = `@scene: outer

+---------------+
| @scene: inner |
+---------------+`
    let result = V2Parser.parse(src, ())
    // The only error must be NestedBlockDeclaration. No UnclosedContainer.
    let hasUnclosedContainer = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosedContainer)->Expect.toBe(false)
    // Both blocks parsed.
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
  })

  test("recovered nested block has empty body when nothing follows it inside the container", t => {
    let src = `@scene: outer

+---------------+
| @scene: inner |
+---------------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("inner")
        t->expect(Array.length(s.children))->Expect.toBe(0)
      }
    | _ => t->expect("missing-inner")->Expect.toBe("found")
    }
  })
})
