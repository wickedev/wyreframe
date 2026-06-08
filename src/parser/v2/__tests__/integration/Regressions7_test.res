// Regressions7_test.res
// Codex-review-driven regressions, round 7.

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

describe("Regression P2: misaligned bottom border tolerance (Codex round 7)", () => {
  test("bottom border drifted +1 col is accepted with a warning", t => {
    // Top is 7 chars `+-----+` at cols 0..6.
    // Bottom is 7 chars but shifted right by 1: ` +-----+` at cols 1..7.
    let src = `@scene: s

+-----+
|     |
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
    t->expect(Array.length(containers) >= 1)->Expect.toBe(true)
    let hasWarning = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerCorner => true
      | _ => false
      }
    )
    t->expect(hasWarning)->Expect.toBe(true)
  })

  test("warning carries the cornerAlignment ruleId", t => {
    let src = `@scene: s

+-----+
|     |
 +-----+`
    let result = V2Parser.parse(src, ())
    let hasRuleId = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch (w.code, w.ruleId) {
      | (MisalignedContainerCorner, Some(id)) => id == Heuristics.Rule.containerCornerAlignment
      | _ => false
      }
    )
    t->expect(hasRuleId)->Expect.toBe(true)
  })

  test("aligned containers do NOT emit a tolerance warning", t => {
    let src = `@scene: s

+-----+
|     |
+-----+`
    let result = V2Parser.parse(src, ())
    let hasWarning = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MisalignedContainerCorner => true
      | _ => false
      }
    )
    t->expect(hasWarning)->Expect.toBe(false)
  })

  test("nested container's `+` is NOT mistaken for outer's bottom (no false tolerance match)", t => {
    let src = `@scene: s

+----------+
|+--------+|
||   Hi   ||
|+--------+|
+----------+`
    let result = V2Parser.parse(src, ())
    // Should be valid: outer + inner = 2 containers, no UnclosedContainer.
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(false)
    let containers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ContainerNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(containers) >= 2)->Expect.toBe(true)
  })
})

describe("Regression P2: tabSize propagates into containers (Codex round 7)", () => {
  test("tab inside container respects tabSize=2 vs default", t => {
    let src = "@scene: s\n\n+--------+\n|\tx     |\n+--------+"
    let opts2: V2Parser.parseOptions = {...V2Parser.defaultOptions, tabSize: 2}
    let opts8: V2Parser.parseOptions = {...V2Parser.defaultOptions, tabSize: 8}
    let r2 = V2Parser.parse(src, ~options=opts2, ())
    let r8 = V2Parser.parse(src, ~options=opts8, ())
    let textOf = (r: V2Parser.parseResult) => {
      switch r.ast {
      | Some(block) => {
          let nodes = collectNodes(block)
          Array.find(nodes, n =>
            switch n {
            | TextNode(_) => true
            | _ => false
            }
          )
        }
      | None => None
      }
    }
    // The inner Text/Container's start.col should differ between tabSize 2 and 8.
    switch (textOf(r2), textOf(r8)) {
    | (Some(TextNode(t2)), Some(TextNode(t8))) =>
      t->expect(t2.location.start.col != t8.location.start.col)->Expect.toBe(true)
    | _ => t->expect("missing-text-nodes")->Expect.toBe("present")
    }
  })
})
