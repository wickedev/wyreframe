// Regressions22_test.res
// Codex-review-driven regressions, round 23.

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

describe("Regression P2: recovered nested block strips container walls (Codex round 23)", () => {
  test("recovered nested block with body row `| Hi |` does NOT emit `|` TextNodes", t => {
    let src = `@scene: outer

+----------+
| @scene: x |
| Hi       |
+----------+`
    let result = V2Parser.parse(src, ())
    // Find the recovered nested block.
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        let nodes = collectNodes(SceneBlock(s))
        // No text content that consists ONLY of a `|` (the wall) should
        // appear in the recovered block.
        let badText = Array.some(nodes, n =>
          switch n {
          | TextNode(tt) => String.trim(tt.content) == "|"
          | _ => false
          }
        )
        t->expect(badText)->Expect.toBe(false)
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })

  test("recovered nested block correctly captures inner body text", t => {
    let src = `@scene: outer

+--------------+
| @scene: y    |
| Some content |
+--------------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        let nodes = collectNodes(SceneBlock(s))
        let hasInner = Array.some(nodes, n =>
          switch n {
          | TextNode(tt) => String.includes(tt.content, "Some content")
          | _ => false
          }
        )
        t->expect(hasInner)->Expect.toBe(true)
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })
})
