// Regressions14_test.res
// Codex-review-driven regressions, round 14.

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

describe("Regression P2: body-wall tolerance for containers (Codex round 14)", () => {
  test("body wall shifted +1 col still produces a Container", t => {
    // Top is `+-----+` at cols 0..6 (width 7). Body wall on the right shifted
    // one col left (`|` at col 5 instead of 6).
    let src = `@scene: s

+-----+
|    |
+-----+`
    let result = V2Parser.parse(src, ())
    let containers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ContainerNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(containers))->Expect.toBe(1)
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(true)
  })

  test("perfectly aligned container emits NO wall-tolerance warning", t => {
    let src = `@scene: s

+-----+
|     |
+-----+`
    let result = V2Parser.parse(src, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    t->expect(hasWallWarn)->Expect.toBe(false)
  })

  test("warning carries the wallAlignment ruleId", t => {
    let src = `@scene: s

+-----+
|    |
+-----+`
    let result = V2Parser.parse(src, ())
    let hasRuleId = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch (w.code, w.ruleId) {
      | (MisalignedContainerWall, Some(id)) => id == Heuristics.Rule.containerWallAlignment
      | _ => false
      }
    )
    t->expect(hasRuleId)->Expect.toBe(true)
  })

  test("body row with content + only one wall present emits MisalignedContainerWall (regardless of tolerance)", t => {
    // Row 2 right wall missing — REQ-2.2 says body rows need both walls.
    let src = `@scene: s

+-----+
|    |
+-----+`
    let opts: V2Parser.parseOptions = {
      ...V2Parser.defaultOptions,
      heuristics: {...Heuristics.emptyPartial, containerColumnTolerance: Some(0)},
    }
    let result = V2Parser.parse(src, ~options=opts, ())
    let hasWallWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerWall => true
      | _ => false
      }
    )
    // Even with tolerance=0, a missing wall on a non-blank body row is
    // reported (the warning marks malformed body shape, not just drift).
    t->expect(hasWallWarn)->Expect.toBe(true)
  })
})
