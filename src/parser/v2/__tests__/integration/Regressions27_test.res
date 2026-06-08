// Regressions27_test.res
// Codex-review-driven regressions, round 28.

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

describe("Regression P2: consecutive recovered blocks keep their bound (Codex round 28)", () => {
  test("two nested @scene declarations in same container don't trigger UnclosedContainer", t => {
    let src = `@scene: outer

+--------------+
| @scene: a    |
| body of a    |
| @scene: b    |
| body of b    |
+--------------+`
    let result = V2Parser.parse(src, ())
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(false)
    // outer, a, b → 3 blocks total
    t->expect(Array.length(result.blocks) >= 3)->Expect.toBe(true)
  })
})

describe("Regression P2: tolerated wall pipe stripped from recovered text (Codex round 28)", () => {
  test("recovered block with right-wall drifted -1 col: text is clean", t => {
    // Top border width 14 (cols 0..13). Body right wall at col 12 (drifted -1).
    let src = `@scene: outer

+------------+
| @scene: x   |
| Hi         |
+------------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        let nodes = collectNodes(SceneBlock(s))
        let dirty = Array.some(nodes, n =>
          switch n {
          | TextNode(tt) => String.includes(tt.content, "|")
          | _ => false
          }
        )
        t->expect(dirty)->Expect.toBe(false)
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })
})
