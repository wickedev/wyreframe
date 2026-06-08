// Regressions18_test.res
// Codex-review-driven regressions, round 18.

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

describe("Regression P2: near-miss LooksLike warnings (Codex round 18)", () => {
  test("`[Save` text emits LooksLikeButton with nearMissPatterns ruleId", t => {
    let src = `@scene: s

[Save`
    let result = V2Parser.parse(src, ())
    let hit = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch (w.code, w.ruleId) {
      | (LooksLikeButton, Some(id)) => id == Heuristics.Rule.nearMissPatterns
      | _ => false
      }
    )
    t->expect(hit)->Expect.toBe(true)
  })

  test("`[x` text emits LooksLikeCheckbox", t => {
    let src = `@scene: s

[x`
    let result = V2Parser.parse(src, ())
    let hit = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | LooksLikeCheckbox => true
      | _ => false
      }
    )
    t->expect(hit)->Expect.toBe(true)
  })

  test("`[__email` (no closing) is handled by V2InputParser as ErrorNode + UnclosedInput", t => {
    let src = `@scene: s

[__email`
    let result = V2Parser.parse(src, ())
    // V2InputParser handles this case (canParse matches `[__`), produces an
    // ErrorNode and an UnclosedInput error — not a LooksLikeInput warning.
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedInput => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(true)
  })

  test("`(x` text emits LooksLikeRadio", t => {
    let src = `@scene: s

(x`
    let result = V2Parser.parse(src, ())
    let hit = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | LooksLikeRadio => true
      | _ => false
      }
    )
    t->expect(hit)->Expect.toBe(true)
  })

  test("clean text emits NO near-miss warning", t => {
    let src = `@scene: s

Just plain text`
    let result = V2Parser.parse(src, ())
    let hit = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | LooksLikeButton | LooksLikeInput | LooksLikeCheckbox | LooksLikeRadio => true
      | _ => false
      }
    )
    t->expect(hit)->Expect.toBe(false)
  })
})

describe("Regression P3: error end positions advance (Codex round 18)", () => {
  test("unclosed `[__abc` produces an ErrorNode whose end advances past start", t => {
    let src = `@scene: s

[__abc`
    let result = V2Parser.parse(src, ())
    let errNodes = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ErrorNode(e) => Some(e)
      | _ => None
      }
    )
    switch errNodes->Array.get(0) {
    | Some(e) => {
        let startCol = e.location.start.col
        let endCol = e.location.end_.col
        t->expect(endCol > startCol)->Expect.toBe(true)
      }
    | None => t->expect("no-error-node")->Expect.toBe("found")
    }
  })

  test("unclosed `\"abc` UnclosedString error has end past start", t => {
    let src = `@scene: s

"abc`
    let result = V2Parser.parse(src, ())
    let unclosed = Array.find(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedString => true
      | _ => false
      }
    )
    switch unclosed {
    | Some(e) => {
        let startCol = e.location.start.col
        let endCol = e.location.end_.col
        t->expect(endCol > startCol)->Expect.toBe(true)
      }
    | None => t->expect("no-unclosed-string")->Expect.toBe("found")
    }
  })
})
