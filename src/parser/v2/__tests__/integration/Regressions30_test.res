// Regressions30_test.res
// Codex-review-driven regressions, round 31.

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

describe("Regression P2: container body for CR-line-ending input (Codex round 31)", () => {
  test("CR-only line endings preserve container children", t => {
    let src = "@scene: s\r\r+----+\r| Hi |\r+----+"
    let result = V2Parser.parse(src, ())
    t->expect(result.success)->Expect.toBe(true)
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
    // The container should have at least one TextNode child containing "Hi".
    let foundHi = ref(false)
    Array.forEach(containers, (c: V2Types.containerNode) =>
      Array.forEach(c.children, child =>
        switch child {
        | TextNode(tt) => if String.includes(tt.content, "Hi") {
            foundHi := true
          }
        | _ => ()
        }
      )
    )
    t->expect(foundHi.contents)->Expect.toBe(true)
  })

  test("CRLF line endings also work", t => {
    let src = "@scene: s\r\n\r\n+----+\r\n| Hi |\r\n+----+"
    let result = V2Parser.parse(src, ())
    t->expect(result.success)->Expect.toBe(true)
    let foundHi = ref(false)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | TextNode(tt) => if String.includes(tt.content, "Hi") {
            foundHi := true
          }
        | _ => ()
        }
      )
    | None => ()
    }
    t->expect(foundHi.contents)->Expect.toBe(true)
  })
})
