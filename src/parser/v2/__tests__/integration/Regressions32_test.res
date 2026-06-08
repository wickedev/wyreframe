// Regressions32_test.res
// Codex-review-driven regressions, round 33.

open Vitest

describe("Regression P2: MultipleRadiosSelected uses a real location (Codex round 33)", () => {
  test("warning location points at a row in the conflicting group (not zeroLoc)", t => {
    // Both radios selected.
    let src = `@scene: s

(*) A
(*) B`
    let result = V2Parser.parse(src, ())
    let warn = Array.find(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MultipleRadiosSelected(_) => true
      | _ => false
      }
    )
    switch warn {
    | Some(w) => {
        // location should NOT be zeroLoc — it should be a real radio row (>0).
        t->expect(w.location.start.row > 0)->Expect.toBe(true)
      }
    | None => t->expect("no-warning")->Expect.toBe("present")
    }
  })

  test("warning location matches a radio in the same group", t => {
    let src = `@scene: s

(*) A
(*) B`
    let result = V2Parser.parse(src, ())
    let warn = Array.find(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | MultipleRadiosSelected(_) => true
      | _ => false
      }
    )
    let radioRows = switch result.ast {
    | Some(SceneBlock(s)) =>
      Array.filterMap(s.children, n =>
        switch n {
        | RadioNode(r) when r.selected => Some(r.location.start.row)
        | _ => None
        }
      )
    | _ => []
    }
    switch warn {
    | Some(w) => {
        let matchesRow = Array.some(radioRows, row => row == w.location.start.row)
        t->expect(matchesRow)->Expect.toBe(true)
      }
    | None => t->expect("no-warning")->Expect.toBe("present")
    }
  })
})
