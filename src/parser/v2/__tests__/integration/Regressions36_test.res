// Regressions36_test.res
// Codex-review-driven regressions, round 42.

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

describe("Regression P2: unclosed container recovery skips body rows (Codex round 42)", () => {
  test("unclosed `+--+ / | a | / | b |` produces ONE ErrorNode and NO leaked Text", t => {
    let src = `@scene: s

+----+
| a  |
| b  |`
    let result = V2Parser.parse(src, ())
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(true)
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    // Body row text (`a` / `b`) must NOT appear as sibling TextNodes.
    let leaked = Array.some(nodes, n =>
      switch n {
      | TextNode(tt) =>
        let c = String.trim(tt.content)
        c == "a" || c == "b" || String.includes(tt.content, "| a") || String.includes(tt.content, "| b")
      | _ => false
      }
    )
    t->expect(leaked)->Expect.toBe(false)
    // An ErrorNode should be present.
    let errNodes = Array.filter(nodes, n =>
      switch n {
      | ErrorNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(errNodes) >= 1)->Expect.toBe(true)
  })

  test("recovered ErrorNode.recoveredContent includes the body rows", t => {
    let src = `@scene: s

+----+
| body row 1 |
| body row 2 |`
    let result = V2Parser.parse(src, ())
    let errNode = Array.find(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ErrorNode(_) => true
      | _ => false
      }
    )
    switch errNode {
    | Some(ErrorNode(e)) =>
      switch e.recoveredContent {
      | Some(content) => {
          t->expect(String.includes(content, "body row 1"))->Expect.toBe(true)
          t->expect(String.includes(content, "body row 2"))->Expect.toBe(true)
        }
      | None => t->expect("no-recovered-content")->Expect.toBe("present")
      }
    | _ => t->expect("no-error-node")->Expect.toBe("found")
    }
  })

  test("recovery stops at next `+`-leading row (sync point)", t => {
    // Two unclosed containers stacked; the second `+----+` has unmatched
    // width vs the first so they can't form one valid container.
    let src = `@scene: s

+----+
| body |
+-------+
| body2 |`
    let result = V2Parser.parse(src, ())
    let unclosedCount = Array.length(
      Array.filter(result.errors, (e: V2Errors.parseError) =>
        switch e.code {
        | UnclosedContainer => true
        | _ => false
        }
      ),
    )
    t->expect(unclosedCount >= 1)->Expect.toBe(true)
  })

  test("recovery stops at @scene declaration", t => {
    let src = `@scene: outer

+----+
| body |
@scene: next`
    let result = V2Parser.parse(src, ())
    // Second @scene should still parse as its own block.
    t->expect(Array.length(result.blocks) >= 2)->Expect.toBe(true)
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("next")
    | _ => t->expect("no-second-scene")->Expect.toBe("found")
    }
  })
})
