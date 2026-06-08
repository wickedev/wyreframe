// Regressions25_test.res
// Codex-review-driven regressions, round 26.

open Vitest

describe("Regression P2: null emojiRegistry from JS does NOT crash (Codex round 26)", () => {
  test("`{emojiRegistry: null}` falls back to default registry", t => {
    let partial: V2Parser.parseOptions = %raw(`{ emojiRegistry: null }`)
    let result = V2Parser.parse("@scene: s\n\n:check:", ~options=partial, ())
    t->expect(result.success)->Expect.toBe(true)
    // Default `:check:` still resolves.
    switch result.ast {
    | Some(SceneBlock(s)) => {
        let foundCheck = Array.some(s.children, n =>
          switch n {
          | EmojiNode(e) => e.emoji == "✔"
          | _ => false
          }
        )
        t->expect(foundCheck)->Expect.toBe(true)
      }
    | _ => t->expect("no-scene")->Expect.toBe("scene")
    }
  })

  test("`{emojiRegistry: undefined}` is equivalent to omitting the field", t => {
    let partial: V2Parser.parseOptions = %raw(`{ emojiRegistry: undefined }`)
    let result = V2Parser.parse("@scene: s\n\n:check:", ~options=partial, ())
    t->expect(result.success)->Expect.toBe(true)
  })

  test("EmojiRegistry.lookupWithOverride(null, name) doesn't throw", t => {
    let nullOverride: option<Dict.t<string>> = %raw(`null`)
    let r = EmojiRegistry.lookupWithOverride(nullOverride, "check")
    t->expect(r)->Expect.toEqual(Some("✔"))
  })
})
