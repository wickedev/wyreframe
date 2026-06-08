// Regressions19_test.res
// Codex-review-driven regressions, round 20.

open Vitest

describe("Regression P2: nested block declaration is recovered as a new top-level block (Codex round 20)", () => {
  test("@scene inside container produces NestedBlockDeclaration AND the nested block parses as top-level", t => {
    let src = `@scene: outer

+---------------+
| @scene: inner |
+---------------+`
    let result = V2Parser.parse(src, ())
    // Error reported.
    let hasNested = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | NestedBlockDeclaration => true
      | _ => false
      }
    )
    t->expect(hasNested)->Expect.toBe(true)
    // BOTH outer and inner scenes appear in result.blocks.
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
    switch (result.blocks->Array.get(0), result.blocks->Array.get(1)) {
    | (Some(SceneBlock(a)), Some(SceneBlock(b))) => {
        t->expect(a.slug)->Expect.toBe("outer")
        t->expect(b.slug)->Expect.toBe("inner")
      }
    | _ => t->expect("missing-blocks")->Expect.toBe("found")
    }
  })

  test("@component inside scene container is recovered as top-level component", t => {
    let src = `@scene: outer

+---------------------+
| @component: gadget  |
+---------------------+`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
    switch (result.blocks->Array.get(0), result.blocks->Array.get(1)) {
    | (Some(SceneBlock(s)), Some(ComponentBlock(c))) => {
        t->expect(s.slug)->Expect.toBe("outer")
        t->expect(c.slug)->Expect.toBe("gadget")
      }
    | _ => t->expect("wrong-blocks")->Expect.toBe("right")
    }
  })

  test("non-nested input still works (no false rewind)", t => {
    let src = `@scene: outer

+----+
| Hi |
+----+`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(1)
    let hasNested = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | NestedBlockDeclaration => true
      | _ => false
      }
    )
    t->expect(hasNested)->Expect.toBe(false)
  })
})
