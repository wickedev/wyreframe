// Regressions33_test.res
// Codex-review-driven regressions, round 34.

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

describe("Regression P2: @props default with `=` preserved (Codex round 34)", () => {
  test("`@props: url=https://a=b` keeps full URL as default", t => {
    let src = `@component: c
@props: url=https://a=b

\${url}`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(ComponentBlock(c)) =>
      switch c.props->Array.get(0) {
      | Some(p) => {
          t->expect(p.name)->Expect.toBe("url")
          t->expect(p.defaultValue)->Expect.toEqual(Some("https://a=b"))
        }
      | None => t->expect("no-prop")->Expect.toBe("found")
      }
    | _ => t->expect("no-component")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: standalone ${prop:default} with `:` preserved (Codex round 34)", () => {
  test("${url:https://example.com} parses name=`url`, default=`https://example.com`", t => {
    let src = `@component: c
@props: url

\${url:https://example.com}`
    let result = V2Parser.parse(src, ())
    let prop = Array.find(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | PropPlaceholderNode(_) => true
      | _ => false
      }
    )
    switch prop {
    | Some(PropPlaceholderNode(p)) => {
        t->expect(p.name)->Expect.toBe("url")
        t->expect(p.defaultValue)->Expect.toEqual(Some("https://example.com"))
      }
    | _ => t->expect("no-prop")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: string-interpolation ${prop:default} with `:` (Codex round 34)", () => {
  test("\"Open ${url:https://example.com}\" → PropRef with full URL default", t => {
    let src = `@component: c
@props: url

"Open \${url:https://example.com}"`
    let result = V2Parser.parse(src, ())
    let strNode = Array.find(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | StringNode(_) => true
      | _ => false
      }
    )
    switch strNode {
    | Some(StringNode(s)) => {
        let propRef = Array.find(s.interpolations, (i: V2Types.interpolationContent) =>
          switch i {
          | PropRef(_) => true
          | _ => false
          }
        )
        switch propRef {
        | Some(PropRef(p)) => {
            t->expect(p.name)->Expect.toBe("url")
            t->expect(p.defaultValue)->Expect.toEqual(Some("https://example.com"))
          }
        | _ => t->expect("no-propref")->Expect.toBe("found")
        }
      }
    | _ => t->expect("no-string")->Expect.toBe("found")
    }
  })
})
