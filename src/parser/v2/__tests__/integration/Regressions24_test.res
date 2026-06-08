// Regressions24_test.res
// Codex-review-driven regressions, round 25.

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

describe("Regression P2: unclosed string returns ErrorNode (Codex round 25)", () => {
  test("unclosed `\"abc` produces ErrorNode (not StringNode)", t => {
    let src = `@scene: s

"abc`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let strings = Array.filter(nodes, n =>
      switch n {
      | StringNode(_) => true
      | _ => false
      }
    )
    let errs = Array.filter(nodes, n =>
      switch n {
      | ErrorNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(strings))->Expect.toBe(0)
    t->expect(Array.length(errs) >= 1)->Expect.toBe(true)
  })

  test("closed `\"abc\"` still produces a StringNode", t => {
    let src = `@scene: s

"abc"`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let strings = Array.filter(nodes, n =>
      switch n {
      | StringNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(strings))->Expect.toBe(1)
  })
})

describe("Regression P2: unclosed container returns ErrorNode (Codex round 25)", () => {
  test("`+--+` with no matching bottom produces an ErrorNode", t => {
    let src = `@scene: s

+--+
|  |`
    let result = V2Parser.parse(src, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let containers = Array.filter(nodes, n =>
      switch n {
      | ContainerNode(_) => true
      | _ => false
      }
    )
    let errs = Array.filter(nodes, n =>
      switch n {
      | ErrorNode(_) => true
      | _ => false
      }
    )
    t->expect(Array.length(containers))->Expect.toBe(0)
    t->expect(Array.length(errs) >= 1)->Expect.toBe(true)
    let hasUnclosed = Array.some(result.errors, (e: V2Errors.parseError) =>
      switch e.code {
      | UnclosedContainer => true
      | _ => false
      }
    )
    t->expect(hasUnclosed)->Expect.toBe(true)
  })
})

describe("Regression P2: per-parse emoji registry (Codex round 25)", () => {
  test("custom registry from parseOptions overrides defaults", t => {
    let custom: Dict.t<string> = Dict.make()
    Dict.set(custom, "rocket", "🚀")
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, emojiRegistry: Some(custom)}
    let result = V2Parser.parse(`@scene: s\n\n:rocket:`, ~options=opts, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let emojiNode = Array.find(nodes, n =>
      switch n {
      | EmojiNode(_) => true
      | _ => false
      }
    )
    switch emojiNode {
    | Some(EmojiNode(e)) => t->expect(e.emoji)->Expect.toBe("🚀")
    | _ => t->expect("no-emoji")->Expect.toBe("found")
    }
  })

  test("custom registry does NOT mutate the global default registry", t => {
    let custom: Dict.t<string> = Dict.make()
    Dict.set(custom, "ephemeral", "TEMP")
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, emojiRegistry: Some(custom)}
    let _ = V2Parser.parse(`@scene: s\n\n:ephemeral:`, ~options=opts, ())
    // Subsequent parse WITHOUT the custom registry should not see `ephemeral`.
    let result = V2Parser.parse(`@scene: s\n\n:ephemeral:`, ())
    let hasUnknown = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | UnknownEmoji(name) => name == "ephemeral"
      | _ => false
      }
    )
    t->expect(hasUnknown)->Expect.toBe(true)
  })

  test("custom registry falls back to defaults for missing shortcodes", t => {
    let custom: Dict.t<string> = Dict.make()
    Dict.set(custom, "rocket", "🚀")
    let opts: V2Parser.parseOptions = {...V2Parser.defaultOptions, emojiRegistry: Some(custom)}
    let result = V2Parser.parse(`@scene: s\n\n:check:`, ~options=opts, ())
    let nodes = switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }
    let emojiNode = Array.find(nodes, n =>
      switch n {
      | EmojiNode(_) => true
      | _ => false
      }
    )
    switch emojiNode {
    | Some(EmojiNode(e)) => t->expect(e.emoji)->Expect.toBe("✔")
    | _ => t->expect("no-emoji")->Expect.toBe("found")
    }
  })
})
