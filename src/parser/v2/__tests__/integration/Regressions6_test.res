// Regressions6_test.res
// Codex-review-driven regressions, round 6.

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

describe("Regression P2: container child offsets are outer-source-absolute (Codex round 6)", () => {
  test("button inside a container has start.offset pointing at the actual [", t => {
    let src = `@scene: s

+--------------+
|   [ Login ]  |
+--------------+`
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
        // Source slice starting at that offset should begin with `[`.
        // We only check that the offset is plausibly large (well past the
        // header) — the inner offset bug pointed at offset < 5.
        t->expect(off > 20)->Expect.toBe(true)
        // And the character at the offset is `[`.
        let ch = String.charAt(src, off)
        t->expect(ch)->Expect.toBe("[")
      }
    | None => t->expect("no-button")->Expect.toBe("found")
    }
  })

  test("input inside a container preserves outer source offset", t => {
    let src = `@scene: s

+----------------+
|  [__email__]   |
+----------------+`
    let result = V2Parser.parse(src, ())
    let inputs = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | InputNode(i) => Some(i)
      | _ => None
      }
    )
    switch inputs->Array.get(0) {
    | Some(i) => {
        let off = i.location.start.offset
        let ch = String.charAt(src, off)
        t->expect(ch)->Expect.toBe("[")
      }
    | None => t->expect("no-input")->Expect.toBe("found")
    }
  })
})

describe("Regression P2: wide-gap same-row radios are NOT grouped (Codex round 6)", () => {
  test("(*) A (10 spaces) (*) B -> different groups, no MultipleRadiosSelected", t => {
    // Default radioHorizontalGap = 6. Gap of 10 (well above) should keep them apart.
    let src = `@scene: s

(*) A          (*) B`
    let result = V2Parser.parse(src, ())
    let multipleSelected = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MultipleRadiosSelected(_) => true
      | _ => false
      }
    )
    t->expect(multipleSelected)->Expect.toBe(false)
    // Confirm the two radios got DIFFERENT group ids.
    let radios = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | RadioNode(r) => Some(r)
      | _ => None
      }
    )
    t->expect(Array.length(radios))->Expect.toBe(2)
    switch (radios->Array.get(0), radios->Array.get(1)) {
    | (Some(a), Some(b)) => t->expect(a.group != b.group)->Expect.toBe(true)
    | _ => ()
    }
  })

  test("close-gap (default 6 or fewer) same-row radios ARE grouped", t => {
    let src = `@scene: s

(*) A   (*) B`
    let result = V2Parser.parse(src, ())
    let multipleSelected = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MultipleRadiosSelected(_) => true
      | _ => false
      }
    )
    t->expect(multipleSelected)->Expect.toBe(true)
  })
})
