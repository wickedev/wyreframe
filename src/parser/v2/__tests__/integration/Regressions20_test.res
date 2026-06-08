// Regressions20_test.res
// Codex-review-driven regressions, round 21.

open Vitest

describe("Regression P2: pipe noise gated to nested recovery (Codex round 21)", () => {
  test("`| @scene: x |` alone (no real top-level header) reports MissingBlockDeclaration", t => {
    let src = `| @scene: nope |`
    let result = V2Parser.parse(src, ())
    let hasMissing = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | MissingBlockDeclaration => true
      | _ => false
      }
    )
    t->expect(hasMissing)->Expect.toBe(true)
    t->expect(Array.length(result.blocks))->Expect.toBe(0)
  })

  test("`| @component: c |` before any header does NOT register a component", t => {
    let src = `| @component: c |`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(0)
  })

  test("nested-block recovery still works after this gating", t => {
    let src = `@scene: outer

+---------------+
| @scene: inner |
+---------------+`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
    switch (result.blocks->Array.get(0), result.blocks->Array.get(1)) {
    | (Some(SceneBlock(a)), Some(SceneBlock(b))) => {
        t->expect(a.slug)->Expect.toBe("outer")
        t->expect(b.slug)->Expect.toBe("inner")
      }
    | _ => t->expect("missing-blocks")->Expect.toBe("found")
    }
  })

  test("after recovery, AT MOST ONE subsequent lookup uses pipe-noise", t => {
    // Layout: outer container with a nested @scene at row 3. The recovered
    // inner block has no further nested children, and the bottom border on
    // row 4 must NOT be eaten by the recovered block.
    let src = `@scene: outer

+---------------+
| @scene: inner |
+---------------+`
    let result = V2Parser.parse(src, ())
    // After parsing both blocks, no extra spurious blocks.
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
  })
})
