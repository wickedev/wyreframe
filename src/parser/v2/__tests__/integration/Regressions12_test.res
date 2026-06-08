// Regressions12_test.res
// Codex-review-driven regressions, round 12.

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

describe("Regression P1: TextParser stops before inline elements (Codex round 12)", () => {
  test("`Dashboard      [ Logout ]` becomes Text + Button (not one giant Text)", t => {
    let src = `@scene: s

Dashboard      [ Logout ]`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let texts = Array.filterMap(nodes, n =>
      switch n {
      | TextNode(tt) => Some(tt)
      | _ => None
      }
    )
    let buttons = Array.filterMap(nodes, n =>
      switch n {
      | ButtonNode(b) => Some(b)
      | _ => None
      }
    )
    t->expect(Array.length(buttons))->Expect.toBe(1)
    // At least one text node whose content begins with "Dashboard" and does
    // NOT include the bracket.
    let foundDashText = Array.some(texts, (tt: V2Types.textNode) =>
      String.includes(tt.content, "Dashboard") && !(String.includes(tt.content, "["))
    )
    t->expect(foundDashText)->Expect.toBe(true)
    switch buttons->Array.get(0) {
    | Some(b) => t->expect(b.text)->Expect.toBe("Logout")
    | None => ()
    }
  })

  test("inline string after text: `Title \"sub\"` becomes Text + String", t => {
    let src = `@scene: s

Title "sub"`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let strings = Array.filter(nodes, n =>
      switch n {
      | StringNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(strings) >= 1)->Expect.toBe(true)
  })

  test("inline link after text: `See <docs>` becomes Text + Link", t => {
    let src = `@scene: s

See <docs>`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let links = Array.filter(nodes, n =>
      switch n {
      | LinkNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(links) >= 1)->Expect.toBe(true)
  })

  test("inline radio after text: `Size: ( ) S (*) M` becomes Text + two Radios", t => {
    let src = `@scene: s

Size: ( ) S (*) M`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let radios = Array.filter(nodes, n =>
      switch n {
      | RadioNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(radios))->Expect.toBe(2)
  })
})

describe("Regression P2: V2Parser parses multiple top-level blocks (Codex round 12)", () => {
  test("two @scene blocks both appear in parseResult.blocks", t => {
    let src = `@scene: first

Hello

@scene: second

World`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
    switch (result.blocks->Array.get(0), result.blocks->Array.get(1)) {
    | (Some(SceneBlock(a)), Some(SceneBlock(b))) => {
        t->expect(a.slug)->Expect.toBe("first")
        t->expect(b.slug)->Expect.toBe("second")
      }
    | _ => t->expect("missing-blocks")->Expect.toBe("found")
    }
  })

  test("legacy `ast` accessor still returns the FIRST block", t => {
    let src = `@scene: first

@scene: second`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("first")
    | _ => t->expect("missing-ast")->Expect.toBe("found")
    }
  })

  test("mixed @scene + @component blocks both parse", t => {
    let src = `@scene: page

Hi

@component: card
@props: title

\${title}`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.blocks))->Expect.toBe(2)
    switch (result.blocks->Array.get(0), result.blocks->Array.get(1)) {
    | (Some(SceneBlock(s)), Some(ComponentBlock(c))) => {
        t->expect(s.slug)->Expect.toBe("page")
        t->expect(c.slug)->Expect.toBe("card")
        t->expect(Array.length(c.props))->Expect.toBe(1)
      }
    | _ => t->expect("wrong-block-kinds")->Expect.toBe("right")
    }
  })

  test("source with no blocks still produces MissingBlockDeclaration", t => {
    let result = V2Parser.parse("just text", ())
    t->expect(result.success)->Expect.toBe(false)
    t->expect(Array.length(result.blocks))->Expect.toBe(0)
  })
})
