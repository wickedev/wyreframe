// Heuristics_test.res
// Boundary tests for the Heuristics module + select rule-driven warnings.

open Vitest

describe("Heuristics module", () => {
  test("default thresholds are stable", t => {
    let h = Heuristics.default
    t->expect(h.containerColumnTolerance)->Expect.toBe(1)
    t->expect(h.containerWidthTolerance)->Expect.toBe(2)
    t->expect(h.radioHorizontalGap)->Expect.toBe(6)
    t->expect(h.radioVerticalColumnTolerance)->Expect.toBe(1)
    t->expect(h.radioMaxBlankRows)->Expect.toBe(0)
    t->expect(h.dividerMinRun)->Expect.toBe(3)
    t->expect(h.nearMissTokenDistance)->Expect.toBe(1)
  })

  test("rule IDs are stable strings", t => {
    t->expect(Heuristics.Rule.containerWallAlignment)->Expect.toBe("container.wallAlignment")
    t->expect(Heuristics.Rule.textCenter)->Expect.toBe("text.center")
    t->expect(Heuristics.Rule.radioGroupingHorizontal)->Expect.toBe("radioGrouping.horizontal")
    t->expect(Heuristics.Rule.nearMissPatterns)->Expect.toBe("nearMissPatterns")
  })
})

describe("Slugify", () => {
  test("simple lowercase words", t => {
    t->expect(Slugify.slugify("Hello World"))->Expect.toBe("hello-world")
  })

  test("strips surrounding punctuation", t => {
    t->expect(Slugify.slugify("Sign In!"))->Expect.toBe("sign-in")
  })

  test("empty input returns 'empty'", t => {
    t->expect(Slugify.slugify(""))->Expect.toBe("empty")
    t->expect(Slugify.slugify("  "))->Expect.toBe("empty")
  })
})

describe("UnicodeUtils", () => {
  test("graphemeWidth handles narrow/wide/combining", t => {
    t->expect(UnicodeUtils.graphemeWidth("a"))->Expect.toBe(1)
    t->expect(UnicodeUtils.graphemeWidth("한"))->Expect.toBe(2)
    t->expect(UnicodeUtils.graphemeWidth(""))->Expect.toBe(0)
  })

  test("visualWidth accounts for tab stops", t => {
    // "\tx" with tabSize=4 from col 0: tab → 4, x → 5. Width = 5.
    t->expect(UnicodeUtils.visualWidth("\tx", ()))->Expect.toBe(5)
    // "ab\tc" from col 0: ab → 2, tab to next stop 4, c → 5. Width = 5.
    t->expect(UnicodeUtils.visualWidth("ab\tc", ()))->Expect.toBe(5)
  })
})

describe("EscapeUtils", () => {
  test("unescapes \\\" \\\\ \\$", t => {
    t->expect(EscapeUtils.unescapeString("a\\\"b"))->Expect.toBe("a\"b")
    t->expect(EscapeUtils.unescapeString("a\\\\b"))->Expect.toBe("a\\b")
    t->expect(EscapeUtils.unescapeString("a\\$b"))->Expect.toBe("a$b")
  })

  test("unknown escapes pass through", t => {
    t->expect(EscapeUtils.unescapeString("a\\xb"))->Expect.toBe("a\\xb")
  })
})
