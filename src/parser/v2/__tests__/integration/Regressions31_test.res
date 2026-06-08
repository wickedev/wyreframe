// Regressions31_test.res
// Codex-review-driven regressions, round 32.

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

describe("Regression P2: CRLF-accurate child offsets (Codex round 32)", () => {
  test("button inside CRLF-source container has start.offset pointing at real `[`", t => {
    let src = "@scene: s\r\n\r\n+----------+\r\n| [ Go ]   |\r\n+----------+"
    let result = V2Parser.parse(src, ())
    let buttons = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ButtonNode(b) => Some(b)
      | _ => None
      }
    )
    switch buttons->Array.get(0) {
    | Some(b) => {
        let off = b.location.start.offset
        let ch = String.charAt(src, off)
        t->expect(ch)->Expect.toBe("[")
      }
    | None => t->expect("no-button")->Expect.toBe("found")
    }
  })

  test("LF-source child offset still correct (regression baseline)", t => {
    let src = "@scene: s\n\n+----------+\n| [ Go ]   |\n+----------+"
    let result = V2Parser.parse(src, ())
    let buttons = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ButtonNode(b) => Some(b)
      | _ => None
      }
    )
    switch buttons->Array.get(0) {
    | Some(b) => {
        let off = b.location.start.offset
        let ch = String.charAt(src, off)
        t->expect(ch)->Expect.toBe("[")
      }
    | None => t->expect("no-button")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: containsErrorRecovery flag for multi-id (Codex round 32)", () => {
  test("two Format-2 IDs marks container.containsErrorRecovery=true", t => {
    let src = `@scene: s

+--------+
| #foo   |
| #bar   |
+--------+`
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
    switch containers->Array.get(0) {
    | Some(c) => t->expect(c.containsErrorRecovery)->Expect.toBe(true)
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })

  test("invalid Format-2 ID (`| #foo bar |`) also flags containsErrorRecovery", t => {
    let src = `@scene: s

+-----------+
| #foo bar  |
+-----------+`
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
    switch containers->Array.get(0) {
    | Some(c) => t->expect(c.containsErrorRecovery)->Expect.toBe(true)
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })

  test("normal container has containsErrorRecovery=false", t => {
    let src = `@scene: s

+----+
| Hi |
+----+`
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
    switch containers->Array.get(0) {
    | Some(c) => t->expect(c.containsErrorRecovery)->Expect.toBe(false)
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })
})
