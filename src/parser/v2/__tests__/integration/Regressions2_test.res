// Regressions2_test.res
// Codex-review-driven regressions, round 2.

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

describe("Regression P1: unclosed input emits error (Codex round 2)", () => {
  test("[__email without closing __] reports UnclosedInput", t => {
    let src = `@scene: s

[__email`
    let result = V2Parser.parse(src, ())
    let hasUnclosedInput = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    t->expect(hasUnclosedInput)->Expect.toBe(true)
  })

  test("unclosed input recovery produces an ErrorNode in the AST", t => {
    let src = `@scene: s

[__email`
    let result = V2Parser.parse(src, ())
    let foundErrNode = ref(false)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | ErrorNode(_) => foundErrNode := true
        | _ => ()
        }
      )
    | None => ()
    }
    t->expect(foundErrNode.contents)->Expect.toBe(true)
  })
})

describe("Regression P1: radio grouping wired before validation (Codex round 2)", () => {
  test("vertical radios get assigned group IDs", t => {
    let src = `@scene: s

(*) A
( ) B`
    let result = V2Parser.parse(src, ())
    let radios = Array.filterMap(collectNodes(switch result.ast {
    | Some(b) => b
    | None => V2Types.SceneBlock({location: V2Types.zeroLoc, slug: "", title: None, device: None, transition: None, children: [], layout: V2Types.emptyLayout})
    }), n =>
      switch n {
      | RadioNode(r) => Some(r)
      | _ => None
      }
    )
    t->expect(Array.length(radios))->Expect.toBe(2)
    Array.forEach(radios, (r: V2Types.radioNode) => {
      t->expect(Option.isSome(r.group))->Expect.toBe(true)
    })
  })

  test("two selected radios in same group emits MultipleRadiosSelected", t => {
    let src = `@scene: s

(*) A
(*) B`
    let result = V2Parser.parse(src, ())
    let hasMultipleSelected = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MultipleRadiosSelected(_) => true
      | _ => false
      }
    )
    t->expect(hasMultipleSelected)->Expect.toBe(true)
  })
})

describe("Regression P2: invalid format-2 ID line emits InvalidIdFormat (Codex round 2)", () => {
  test("| #foo bar | inside container reports InvalidIdFormat", t => {
    let src = `@scene: s

+-----------+
| #foo bar  |
+-----------+`
    let result = V2Parser.parse(src, ())
    let hasInvalid = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | InvalidIdFormat => true
      | _ => false
      }
    )
    t->expect(hasInvalid)->Expect.toBe(true)
  })
})

describe("Regression P2: short divider forms (Codex round 2)", () => {
  test("-#id- parses as a Divider with id", t => {
    let src = `@scene: s

-#id-`
    let result = V2Parser.parse(src, ())
    let found = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | DividerNode(d) => found := Some(d)
        | _ => ()
        }
      )
    | None => ()
    }
    switch found.contents {
    | Some(d) => t->expect(d.id)->Expect.toEqual(Some("id"))
    | None => t->expect("no-divider")->Expect.toBe("found")
    }
  })

  test("=#id= parses as a bold Divider with id", t => {
    let src = `@scene: s

=#id=`
    let result = V2Parser.parse(src, ())
    let found = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | DividerNode(d) => found := Some(d)
        | _ => ()
        }
      )
    | None => ()
    }
    switch found.contents {
    | Some(d) => {
        t->expect(d.id)->Expect.toEqual(Some("id"))
        t->expect(d.style)->Expect.toEqual(V2Types.Bold)
      }
    | None => t->expect("no-divider")->Expect.toBe("found")
    }
  })

  test("=text= parses as a bold Divider with label", t => {
    let src = `@scene: s

=text=`
    let result = V2Parser.parse(src, ())
    let found = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | DividerNode(d) => found := Some(d)
        | _ => ()
        }
      )
    | None => ()
    }
    switch found.contents {
    | Some(d) => {
        t->expect(d.label)->Expect.toEqual(Some("text"))
        t->expect(d.style)->Expect.toEqual(V2Types.Bold)
      }
    | None => t->expect("no-divider")->Expect.toBe("found")
    }
  })

  test("leading dashes WITHOUT trailing dashes are NOT a divider", t => {
    let src = `@scene: s

- item`
    let result = V2Parser.parse(src, ())
    let foundDivider = ref(false)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | DividerNode(_) => foundDivider := true
        | _ => ()
        }
      )
    | None => ()
    }
    t->expect(foundDivider.contents)->Expect.toBe(false)
  })
})

describe("Regression P2: dashless +#id+ container (Codex round 2)", () => {
  test("+#id+ parses as a Container with id", t => {
    let src = `@scene: s

+#card+
|     |
+-----+`
    let result = V2Parser.parse(src, ())
    let foundContainer = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | ContainerNode(c) => foundContainer := Some(c)
        | _ => ()
        }
      )
    | None => ()
    }
    switch foundContainer.contents {
    | Some(c) => t->expect(c.id)->Expect.toEqual(Some("card"))
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })

  test("+-#id-+ also parses as a Container with id", t => {
    let src = `@scene: s

+-#card-+
|       |
+-------+`
    let result = V2Parser.parse(src, ())
    let foundContainer = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | ContainerNode(c) => foundContainer := Some(c)
        | _ => ()
        }
      )
    | None => ()
    }
    switch foundContainer.contents {
    | Some(c) => t->expect(c.id)->Expect.toEqual(Some("card"))
    | None => t->expect("no-container")->Expect.toBe("found")
    }
  })
})
