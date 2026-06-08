// Regressions8_test.res
// Codex-review-driven regressions, round 8.

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

describe("Regression P2: header-attr parsing stops at next block (Codex round 8)", () => {
  test("@scene immediately after another @scene does NOT become an attribute", t => {
    let src = `@scene: first
@scene: second`
    let result = V2Parser.parse(src, ())
    // The first block must have parsed cleanly with slug "first" and zero children.
    switch result.ast {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("first")
        // No content (the next @scene line was not eaten as content/attr).
        t->expect(Array.length(s.children))->Expect.toBe(0)
        // Title must be None (next @scene is not a value of unknown attr).
        t->expect(s.title)->Expect.toEqual(None)
      }
    | _ => t->expect("no-scene")->Expect.toBe("scene")
    }
  })

  test("@component immediately after @scene also terminates header-attrs", t => {
    let src = `@scene: a
@component: b`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("a")
        t->expect(Array.length(s.children))->Expect.toBe(0)
      }
    | _ => t->expect("no-scene")->Expect.toBe("scene")
    }
  })
})

describe("Regression P2: top border with trailing junk is rejected (Codex round 8)", () => {
  test("+---+ trailing does NOT become a Container", t => {
    let src = `@scene: s

+---+ trailing
|   |
+---+`
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
    // No container should be emitted for `+---+ trailing` (junk after the +).
    // The pristine `+---+ / |   | / +---+` block below would form one, but
    // here the very first `+---+` is junked. So we expect: maybe one if the
    // remaining lines `|   |\n+---+` start a container. But these no longer
    // form a valid top border either (the line starts with `|`).
    t->expect(Array.length(containers))->Expect.toBe(0)
  })

  test("clean `+---+` (no trailing) still parses", t => {
    let src = `@scene: s

+---+
|   |
+---+`
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
    t->expect(Array.length(containers))->Expect.toBe(1)
  })

  test("top border with trailing whitespace only is still accepted", t => {
    let src = "@scene: s\n\n+---+   \n|   |\n+---+"
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
    t->expect(Array.length(containers))->Expect.toBe(1)
  })
})

describe("Regression P2: duplicate prop names (Codex round 8)", () => {
  test("@props: name, name=Bob emits DuplicatePropName + last wins", t => {
    let src = `@component: greeting
@props: name, name=Bob

\${name}`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicatePropName(n) => n == "name"
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(true)
    // Component should carry a single prop entry (deduped) with defaultValue=Some("Bob").
    switch result.ast {
    | Some(ComponentBlock(c)) => {
        t->expect(Array.length(c.props))->Expect.toBe(1)
        switch c.props->Array.get(0) {
        | Some(p) => {
            t->expect(p.name)->Expect.toBe("name")
            t->expect(p.defaultValue)->Expect.toEqual(Some("Bob"))
          }
        | None => ()
        }
      }
    | _ => t->expect("no-component")->Expect.toBe("component")
    }
  })

  test("no warning for unique props", t => {
    let src = `@component: c
@props: a, b, c

\${a}\${b}\${c}`
    let result = V2Parser.parse(src, ())
    let hasDup = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | DuplicatePropName(_) => true
      | _ => false
      }
    )
    t->expect(hasDup)->Expect.toBe(false)
  })
})
