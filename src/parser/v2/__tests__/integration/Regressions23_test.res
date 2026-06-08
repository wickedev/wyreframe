// Regressions23_test.res
// Codex-review-driven regressions, round 24.

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

describe("Regression P2: recovered block strips right wall too (Codex round 24)", () => {
  test("recovered nested block `| Hi |` produces TextNode('Hi'), not 'Hi |'", t => {
    let src = `@scene: outer

+----------+
| @scene: x |
| Hi       |
+----------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        let nodes = collectNodes(SceneBlock(s))
        let foundClean = Array.some(nodes, n =>
          switch n {
          | TextNode(tt) => String.trim(tt.content) == "Hi"
          | _ => false
          }
        )
        let foundDirty = Array.some(nodes, n =>
          switch n {
          | TextNode(tt) => String.includes(tt.content, "|")
          | _ => false
          }
        )
        t->expect(foundClean)->Expect.toBe(true)
        t->expect(foundDirty)->Expect.toBe(false)
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: header-attrs are read behind container walls (Codex round 24)", () => {
  test("`| @title: Inner |` after recovered header sets the title", t => {
    let src = `@scene: outer

+-----------------+
| @scene: inner   |
| @title: Cool    |
| Body            |
+-----------------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("inner")
        t->expect(s.title)->Expect.toEqual(Some("Cool"))
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })

  test("`| @device: mobile |` behind walls is honored", t => {
    let src = `@scene: outer

+--------------------+
| @scene: phone      |
| @device: mobile    |
+--------------------+`
    let result = V2Parser.parse(src, ())
    switch result.blocks->Array.get(1) {
    | Some(SceneBlock(s)) => {
        t->expect(s.device)->Expect.toEqual(Some(V2Types.Mobile))
      }
    | _ => t->expect("no-inner")->Expect.toBe("found")
    }
  })
})
