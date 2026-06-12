// PerformanceSmoke_test.res
// Sanity check that the renderer is not pathologically slow on a
// medium-sized AST. Full benchmark suite is out of Phase 1 (per the
// task plan); this is a smoke test that catches obvious regressions.

open Vitest
open V2RendererTestHelpers

let buildBigContainer = (childCount: int): V2Types.astNode => {
  let kids: array<V2Types.astNode> = []
  for i in 0 to childCount - 1 {
    Array.push(
      kids,
      button(~id="b" ++ Int.toString(i), ~text="X" ++ Int.toString(i), ()),
    )
  }
  container(~layout=layout(~direction=Column, ()), ~children=kids, ())
}

describe("V2Renderer / performance smoke", () => {
  test("renders 1000-node AST in well under 1 second", t => {
    let ast = buildBigContainer(1000)
    let start = Date.now()
    let html = render(ast)
    let elapsed = Date.now() -. start
    t->expect(String.length(html) > 0)->Expect.toBe(true)
    // 1000 nodes should be far below 1000ms. 500ms is a generous ceiling.
    t->expect(elapsed < 500.0)->Expect.toBe(true)
  })
})
