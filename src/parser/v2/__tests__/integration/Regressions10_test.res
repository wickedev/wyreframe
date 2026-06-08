// Regressions10_test.res
// Codex-review-driven regressions, round 10.

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

describe("Regression P2: underscores-only input (Codex round 10)", () => {
  test("`[____________]` parses as Input with empty placeholder", t => {
    let src = `@scene: s

[____________]`
    let result = V2Parser.parse(src, ())
    let foundInput = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | InputNode(i) => foundInput := Some(i)
        | _ => ()
        }
      )
    | None => ()
    }
    switch foundInput.contents {
    | Some(i) => t->expect(i.placeholder)->Expect.toBe("")
    | None => t->expect("no-input")->Expect.toBe("found")
    }
    // And no UnclosedInput error should be emitted.
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(false)
  })

  test("`[____]` (just 4 underscores) parses as Input with empty placeholder", t => {
    let src = `@scene: s

[____]`
    let result = V2Parser.parse(src, ())
    let foundInput = ref(None)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n =>
        switch n {
        | InputNode(i) => foundInput := Some(i)
        | _ => ()
        }
      )
    | None => ()
    }
    switch foundInput.contents {
    | Some(i) => t->expect(i.placeholder)->Expect.toBe("")
    | None => t->expect("no-input")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: child offsets after tab/wide chars (Codex round 10)", () => {
  test("tab-prefixed inner element offset points at the actual `[`", t => {
    // tab → cols 0-3, then `+----+` cols 4..9.
    // Inside: `| \t[OK] |` → cols 4='|', 5..7 = ` \t`, then `[OK]`.
    // We want the [ to live at the right byte offset.
    let src = "@scene: s\n\n\t+------+\n\t| [OK] |\n\t+------+"
    let result = V2Parser.parse(src, ())
    let buttons = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ButtonNode(b) => Some(b)
      | _ => None
      }
    )
    switch buttons->Array.get(0) {
    | Some(b) => {
        let off = b.location.start.offset
        let ch = String.charAt(src, off)
        t->expect(ch)->Expect.toBe("[")
      }
    | None => t->expect("no-button")->Expect.toBe("found")
    }
  })
})
