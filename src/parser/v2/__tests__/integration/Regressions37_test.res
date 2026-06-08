// Regressions37_test.res
// Codex-review-driven regressions, round 46.

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

let firstContainerTextContent = (block: V2Types.blockNode): option<string> => {
  let nodes = collectNodes(block)
  let inContainer = ref(false)
  let found = ref(None)
  Array.forEach(nodes, n =>
    switch (found.contents, inContainer.contents, n) {
    | (None, _, ContainerNode(_)) => inContainer := true
    | (None, true, TextNode(t)) => found := Some(t.content)
    | _ => ()
    }
  )
  found.contents
}

describe("Regression P2: literal trailing pipe preserved in container text (Codex round 46)", () => {
  test("`| a||` keeps `a|` (literal pipe before well-aligned wall)", t => {
    // Container 5 cols wide (cols 0..4). Left wall at 0, right wall at 4.
    // Content rows have a literal `|` at col 3 immediately before the right
    // wall at col 4. Before the fix, the trailing-pipe trim would eat the
    // user's pipe.
    let src = `@scene: s

+---+
|a| |
+---+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainerTextContent(block) {
      | Some(content) => t->expect(String.includes(content, "a|"))->Expect.toBe(true)
      | None => t->expect("no-text")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("`| a |` (no literal pipe) still parses as plain `a`", t => {
    let src = `@scene: s

+---+
| a |
+---+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainerTextContent(block) {
      | Some(content) =>
        let trimmed = String.trim(content)
        t->expect(trimmed)->Expect.toBe("a")
      | None => t->expect("no-text")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("literal pipe in middle of content preserved", t => {
    let src = `@scene: s

+-------+
|a|b|c  |
+-------+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainerTextContent(block) {
      | Some(content) =>
        t->expect(String.includes(content, "a|b|c"))->Expect.toBe(true)
      | None => t->expect("no-text")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })
})
