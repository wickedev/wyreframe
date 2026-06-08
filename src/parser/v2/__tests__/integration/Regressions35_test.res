// Regressions35_test.res
// Codex-review-driven regressions, round 40.

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

let firstContainer = (block: V2Types.blockNode): option<V2Types.containerNode> => {
  let found = ref(None)
  Array.forEach(collectNodes(block), n =>
    switch (found.contents, n) {
    | (None, ContainerNode(c)) => found := Some(c)
    | _ => ()
    }
  )
  found.contents
}

describe("Regression P2: hyphenated format-1 container ID (Codex round 40)", () => {
  test("`+--#account-email--+` parses with id=account-email", t => {
    let src = `@scene: s

+--#account-email--+
|                  |
+------------------+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainer(block) {
      | Some(c) => t->expect(c.id)->Expect.toEqual(Some("account-email"))
      | None => t->expect("no-container")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("`+--#multi-word-id--+` keeps both hyphens", t => {
    let src = `@scene: s

+--#multi-word-id--+
|                  |
+------------------+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainer(block) {
      | Some(c) => t->expect(c.id)->Expect.toEqual(Some("multi-word-id"))
      | None => t->expect("no-container")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("`+--#simple--+` still parses (no regression)", t => {
    let src = `@scene: s

+--#simple--+
|           |
+-----------+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainer(block) {
      | Some(c) => t->expect(c.id)->Expect.toEqual(Some("simple"))
      | None => t->expect("no-container")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("`+-#card-+` (single-dash form) still parses as `card`", t => {
    let src = `@scene: s

+-#card-+
|       |
+-------+`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstContainer(block) {
      | Some(c) => t->expect(c.id)->Expect.toEqual(Some("card"))
      | None => t->expect("no-container")->Expect.toBe("found")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })
})
