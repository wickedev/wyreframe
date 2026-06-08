// Regressions11_test.res
// Codex-review-driven regressions, round 11.

open Vitest

let collectNodes = (block: V2Types.blockNode): array<V2Types.astNode> => {
  let acc: array<V2Types.astNode> = []
  let rec walk = (n: V2Types.astNode) => {
    acc->Array.push(n)
    switch V2Types.getChildren(n) {
    | Some(c) => Array.forEach(c, walk)
    | None => ()
    }
  }
  let root = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }
  walk(root)
  acc
}

let isDivider = (n: V2Types.astNode): bool =>
  switch n {
  | DividerNode(_) => true
  | _ => false
  }

describe("Regression P2: dividerMinRun respected for plain dividers (Codex round 11)", () => {
  test("bare `-` is NOT a Divider", t => {
    let src = `@scene: s

-`
    let result = V2Parser.parse(src, ())
    let dividers = Array.filter(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, isDivider)
    t->expect(Array.length(dividers))->Expect.toBe(0)
  })

  test("`--` (2 chars) is NOT a Divider", t => {
    let src = `@scene: s

--`
    let result = V2Parser.parse(src, ())
    let dividers = Array.filter(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, isDivider)
    t->expect(Array.length(dividers))->Expect.toBe(0)
  })

  test("`---` (3 chars, meeting dividerMinRun) IS a Divider", t => {
    let src = `@scene: s

---`
    let result = V2Parser.parse(src, ())
    let dividers = Array.filter(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, isDivider)
    t->expect(Array.length(dividers))->Expect.toBe(1)
  })

  test("`==` is NOT a bold Divider", t => {
    let src = `@scene: s

==`
    let result = V2Parser.parse(src, ())
    let dividers = Array.filter(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, isDivider)
    t->expect(Array.length(dividers))->Expect.toBe(0)
  })

  test("`-#id-` (short form WITH content) is still a Divider", t => {
    let src = `@scene: s

-#section-`
    let result = V2Parser.parse(src, ())
    let dividers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | DividerNode(d) => Some(d)
      | _ => None
      }
    )
    t->expect(Array.length(dividers))->Expect.toBe(1)
    switch dividers->Array.get(0) {
    | Some(d) => t->expect(d.id)->Expect.toEqual(Some("section"))
    | None => ()
    }
  })

  test("custom dividerMinRun=1 admits bare `-` as divider", t => {
    let src = `@scene: s

-`
    let opts: V2Parser.parseOptions = {
      ...V2Parser.defaultOptions,
      heuristics: {...Heuristics.emptyPartial, dividerMinRun: Some(1)},
    }
    let result = V2Parser.parse(src, ~options=opts, ())
    let dividers = Array.filter(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, isDivider)
    t->expect(Array.length(dividers))->Expect.toBe(1)
  })
})
