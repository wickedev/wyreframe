// Regressions16_test.res
// Codex-review-driven regressions, round 16.

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

describe("Regression P2: one-sided corner shift (Codex round 16)", () => {
  test("bottom border with left corner exact, right shifted +1 still parses", t => {
    // Top: `+----+` cols 0..5 (width 6). Bottom shifted on the right: `+-----+` cols 0..6 (width 7).
    let src = `@scene: s

+----+
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
    // MisalignedContainerCorner should fire because the right corner drifted.
    let hasCornerWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerCorner => true
      | _ => false
      }
    )
    t->expect(hasCornerWarn)->Expect.toBe(true)
  })
})

describe("Regression P2: containerWidthTolerance + InconsistentContainerWidth (Codex round 16)", () => {
  test("bottom border one col WIDER than top emits InconsistentContainerWidth", t => {
    let src = `@scene: s

+----+
|    |
+-----+`
    let result = V2Parser.parse(src, ())
    let hasWidthWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | InconsistentContainerWidth => true
      | _ => false
      }
    )
    t->expect(hasWidthWarn)->Expect.toBe(true)
    // Carries the right ruleId
    let hasRuleId = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch (w.code, w.ruleId) {
      | (InconsistentContainerWidth, Some(id)) => id == Heuristics.Rule.containerWidthConsistency
      | _ => false
      }
    )
    t->expect(hasRuleId)->Expect.toBe(true)
  })

  test("bottom border one col NARROWER than top emits InconsistentContainerWidth", t => {
    let src = `@scene: s

+-----+
|     |
+----+`
    let result = V2Parser.parse(src, ())
    let hasWidthWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | InconsistentContainerWidth => true
      | _ => false
      }
    )
    t->expect(hasWidthWarn)->Expect.toBe(true)
  })

  test("equal widths emit NO InconsistentContainerWidth warning", t => {
    let src = `@scene: s

+----+
|    |
+----+`
    let result = V2Parser.parse(src, ())
    let hasWidthWarn = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | InconsistentContainerWidth => true
      | _ => false
      }
    )
    t->expect(hasWidthWarn)->Expect.toBe(false)
  })
})
