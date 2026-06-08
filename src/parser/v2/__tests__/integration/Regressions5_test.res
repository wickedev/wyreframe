// Regressions5_test.res
// Codex-review-driven regressions, round 5.

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

describe("Regression P2: inner container diagnostics not duplicated (Codex round 5)", () => {
  test("${foo} inside a scene container emits exactly ONE PropOutsideComponent warning", t => {
    let src = `@scene: s

+-------+
|\${foo}|
+-------+`
    let result = V2Parser.parse(src, ())
    let propOutsideWarns = Array.filter(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | PropOutsideComponent => true
      | _ => false
      }
    )
    t->expect(Array.length(propOutsideWarns))->Expect.toBe(1)
  })

  test("two distinct inner diagnostics each appear exactly once", t => {
    let src = `@scene: s

+----------+
|\${a}     |
|\${b}     |
+----------+`
    let result = V2Parser.parse(src, ())
    let propOutsideWarns = Array.filter(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | PropOutsideComponent => true
      | _ => false
      }
    )
    t->expect(Array.length(propOutsideWarns))->Expect.toBe(2)
  })
})

describe("Regression P2: checkbox same-row separation (Codex round 5)", () => {
  test("[x] One [ ] Two on one row produces two CheckboxNodes", t => {
    let src = `@scene: s

[x] One [ ] Two`
    let result = V2Parser.parse(src, ())
    let checkboxes = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | CheckboxNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(checkboxes))->Expect.toBe(2)
    switch (checkboxes->Array.get(0), checkboxes->Array.get(1)) {
    | (Some(c1), Some(c2)) => {
        t->expect(c1.checked)->Expect.toBe(true)
        t->expect(String.trim(c1.label))->Expect.toBe("One")
        t->expect(c2.checked)->Expect.toBe(false)
        t->expect(String.trim(c2.label))->Expect.toBe("Two")
      }
    | _ => t->expect("missing-checkboxes")->Expect.toBe("found")
    }
  })

  test("three same-row checkboxes produce three nodes", t => {
    let src = `@scene: s

[ ] A [ ] B [x] C`
    let result = V2Parser.parse(src, ())
    let checkboxes = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | CheckboxNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(checkboxes))->Expect.toBe(3)
  })
})
