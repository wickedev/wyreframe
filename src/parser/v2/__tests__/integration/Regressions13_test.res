// Regressions13_test.res
// Codex-review-driven regressions, round 13.

open Vitest

describe("Regression P2: partial heuristics override merges with defaults (Codex round 13)", () => {
  test("Heuristics.applyPartial fills in missing fields from base", t => {
    let p: Heuristics.partial = {...Heuristics.emptyPartial, radioHorizontalGap: Some(99)}
    let merged = Heuristics.applyPartial(p, Heuristics.default)
    t->expect(merged.radioHorizontalGap)->Expect.toBe(99)
    // Other fields retain default values.
    t->expect(merged.containerColumnTolerance)->Expect.toBe(
      Heuristics.default.containerColumnTolerance,
    )
    t->expect(merged.dividerMinRun)->Expect.toBe(Heuristics.default.dividerMinRun)
    t->expect(merged.centerSymmetryThreshold)->Expect.toBe(
      Heuristics.default.centerSymmetryThreshold,
    )
  })

  test("emptyPartial through applyPartial gives full default", t => {
    let merged = Heuristics.applyPartial(Heuristics.emptyPartial, Heuristics.default)
    t->expect(merged.containerColumnTolerance)->Expect.toBe(1)
    t->expect(merged.dividerMinRun)->Expect.toBe(3)
    t->expect(merged.radioHorizontalGap)->Expect.toBe(6)
  })

  test("V2Parser honors a single-field heuristic override", t => {
    let opts: V2Parser.parseOptions = {
      ...V2Parser.defaultOptions,
      heuristics: {...Heuristics.emptyPartial, dividerMinRun: Some(1)},
    }
    let result = V2Parser.parse("@scene: s\n\n-", ~options=opts, ())
    let hasDivider = switch result.ast {
    | Some(SceneBlock(s)) =>
      Array.some(s.children, n =>
        switch n {
        | DividerNode(_) => true
        | _ => false
        }
      )
    | _ => false
    }
    // dividerMinRun=1 admits bare `-` as a divider.
    t->expect(hasDivider)->Expect.toBe(true)
  })
})

describe("Regression P2: ZWJ emoji is one wide grapheme (Codex round 13)", () => {
  test("`👨‍👩‍👧` has visual width 2", t => {
    let w = UnicodeUtils.visualWidth("👨‍👩‍👧", ())
    t->expect(w)->Expect.toBe(2)
  })

  test("two ZWJ emoji + ascii has expected width", t => {
    // `👨‍👩‍👧X` → 2 + 1 = 3
    let w = UnicodeUtils.visualWidth("👨‍👩‍👧X", ())
    t->expect(w)->Expect.toBe(3)
  })

  test("non-ZWJ wide emoji is also 2", t => {
    let w = UnicodeUtils.visualWidth("\u{1F600}", ()) // 😀
    t->expect(w)->Expect.toBe(2)
  })

  test("plain ASCII width unchanged by ZWJ fix", t => {
    let w = UnicodeUtils.visualWidth("hello", ())
    t->expect(w)->Expect.toBe(5)
  })

  test("foldGraphemes treats ZWJ cluster as one grapheme of width 2", t => {
    let count = UnicodeUtils.foldGraphemes(
      "👨‍👩‍👧",
      (acc, ~start as _, ~end_ as _, ~width as _) => acc + 1,
      0,
    )
    t->expect(count)->Expect.toBe(1)
  })
})
