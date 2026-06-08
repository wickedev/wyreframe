// Regressions17_test.res
// Codex-review-driven regressions, round 17.

open Vitest

describe("Regression P2: EmojiRegistry.reset wipes custom registrations (Codex round 17)", () => {
  test("register then reset → custom no longer resolves; built-ins still resolve", t => {
    EmojiRegistry.register("custom", "🎉")
    t->expect(EmojiRegistry.lookup("custom"))->Expect.toEqual(Some("🎉"))
    EmojiRegistry.reset()
    t->expect(EmojiRegistry.lookup("custom"))->Expect.toEqual(None)
    // Built-ins still present after reset.
    t->expect(EmojiRegistry.lookup("check"))->Expect.toEqual(Some("✔"))
  })

  test("multiple register/reset cycles stay clean", t => {
    EmojiRegistry.register("a", "A")
    EmojiRegistry.register("b", "B")
    EmojiRegistry.reset()
    t->expect(EmojiRegistry.lookup("a"))->Expect.toEqual(None)
    t->expect(EmojiRegistry.lookup("b"))->Expect.toEqual(None)
    EmojiRegistry.register("a", "A")
    EmojiRegistry.reset()
    t->expect(EmojiRegistry.lookup("a"))->Expect.toEqual(None)
  })
})

describe("Regression P2: Slugify replaces broader punctuation (Codex round 17)", () => {
  test("`/` is treated as a separator", t => {
    t->expect(Slugify.slugify("A/B"))->Expect.toBe("a-b")
  })

  test("`#` is treated as a separator", t => {
    t->expect(Slugify.slugify("Save #1"))->Expect.toBe("save-1")
  })

  test("`@` and `.` are treated as separators", t => {
    t->expect(Slugify.slugify("foo@bar.com"))->Expect.toBe("foo-bar-com")
  })

  test("multiple punctuation chars collapse to one `-`", t => {
    t->expect(Slugify.slugify("a // b"))->Expect.toBe("a-b")
  })

  test("CJK is preserved (not treated as separator)", t => {
    t->expect(Slugify.slugify("사용자 이름"))->Expect.toBe("사용자-이름")
  })

  test("alphanumeric-only text unchanged (after lowercase)", t => {
    t->expect(Slugify.slugify("Hello123"))->Expect.toBe("hello123")
  })
})
