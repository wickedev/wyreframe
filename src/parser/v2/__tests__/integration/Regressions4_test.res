// Regressions4_test.res
// Codex-review-driven regressions, round 4.

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

describe("Regression P2: nested @scene/@component inside container (Codex round 4)", () => {
  test("@scene inside a container reports NestedBlockDeclaration", t => {
    let src = `@scene: outer

+---------------+
| @scene: bad   |
+---------------+`
    let result = V2Parser.parse(src, ())
    let hasNested = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | NestedBlockDeclaration => true
      | _ => false
      }
    )
    t->expect(hasNested)->Expect.toBe(true)
    t->expect(result.success)->Expect.toBe(false)
  })

  test("@component inside a container is also reported", t => {
    let src = `@scene: outer

+---------------+
| @component: c |
+---------------+`
    let result = V2Parser.parse(src, ())
    let hasNested = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | NestedBlockDeclaration => true
      | _ => false
      }
    )
    t->expect(hasNested)->Expect.toBe(true)
  })
})

describe("Regression P2: unknown prop refs inside strings (Codex round 4)", () => {
  test("${missing} inside a string warns just like the standalone form", t => {
    let src = `@component: greeting
@props: name

"\${missing}"`
    let result = V2Parser.parse(src, ())
    let hasUnknown = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | UnknownPropReference(n) => n == "missing"
      | _ => false
      }
    )
    t->expect(hasUnknown)->Expect.toBe(true)
  })

  test("${name} inside a string does NOT warn when declared", t => {
    let src = `@component: greeting
@props: name

"Hello \${name}!"`
    let result = V2Parser.parse(src, ())
    let hasUnknown = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | UnknownPropReference(_) => true
      | _ => false
      }
    )
    t->expect(hasUnknown)->Expect.toBe(false)
  })

  test("scene block does NOT emit UnknownPropReference for placeholder text", t => {
    let src = `@scene: s

"\${name}"`
    let result = V2Parser.parse(src, ())
    let hasUnknown = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | UnknownPropReference(_) => true
      | _ => false
      }
    )
    // Only PropOutsideComponent applies here, not UnknownPropReference.
    t->expect(hasUnknown)->Expect.toBe(false)
  })
})

describe("Regression P3: ContainerNode end offset (Codex round 4)", () => {
  test("container end_.offset > start.offset", t => {
    let src = `@scene: s

+----+
|    |
+----+`
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
    t->expect(Array.length(containers) >= 1)->Expect.toBe(true)
    switch containers->Array.get(0) {
    | Some(c) => {
        let startOff = c.location.start.offset
        let endOff = c.location.end_.offset
        t->expect(endOff > startOff)->Expect.toBe(true)
        // 3 rows × 6 chars (5 + newline), minus the final newline → 17 chars.
        // The container starts at the offset of `+----+\n`'s first `+`.
        let span = endOff - startOff
        t->expect(span >= 10)->Expect.toBe(true)
      }
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })

  test("end position row/col match the bottom border", t => {
    let src = `@scene: s

+----+
|    |
+----+`
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
    switch containers->Array.get(0) {
    | Some(c) => {
        // Bottom border row should be start.row + 2 (3 rows total).
        t->expect(c.location.end_.row)->Expect.toBe(c.location.start.row + 2)
      }
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })
})
