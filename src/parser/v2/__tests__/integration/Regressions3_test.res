// Regressions3_test.res
// Codex-review-driven regressions, round 3.

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

let firstStringNode = (block: V2Types.blockNode): option<V2Types.stringNode> => {
  let found = ref(None)
  Array.forEach(collectNodes(block), n =>
    switch (found.contents, n) {
    | (None, StringNode(s)) => found := Some(s)
    | _ => ()
    }
  )
  found.contents
}

describe("Regression P1: nested container preserves contents (Codex round 3)", () => {
  test("box inside box keeps the inner text child", t => {
    let src = `@scene: s

+----------+
|+--------+|
||   Hi   ||
|+--------+|
+----------+`
    let result = V2Parser.parse(src, ())
    // Outer container + inner container both exist, AND the inner one has
    // a Text child whose content includes "Hi".
    let containers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ContainerNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(containers) >= 2)->Expect.toBe(true)
    // Find a container that itself contains a TextNode with "Hi"
    let foundInner = ref(false)
    Array.forEach(containers, (c: V2Types.containerNode) =>
      Array.forEach(c.children, child =>
        switch child {
        | TextNode(t) =>
          if String.includes(t.content, "Hi") {
            foundInner := true
          }
        | _ => ()
        }
      )
    )
    t->expect(foundInner.contents)->Expect.toBe(true)
  })

  test("3-level nested container preserves the deepest text", t => {
    let src = `@scene: s

+------------+
|+----------+|
||+--------+||
|||  deep  |||
||+--------+||
|+----------+|
+------------+`
    let result = V2Parser.parse(src, ())
    let containers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ContainerNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(containers) >= 3)->Expect.toBe(true)
    let foundDeep = ref(false)
    Array.forEach(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | TextNode(t) =>
        if String.includes(t.content, "deep") {
          foundDeep := true
        }
      | _ => ()
      }
    )
    t->expect(foundDeep.contents)->Expect.toBe(true)
  })
})

describe("Regression P2: horizontal radios become distinct nodes (Codex round 3)", () => {
  test("(*) A   ( ) B on one row produces TWO radios", t => {
    let src = `@scene: s

(*) Visa   ( ) MasterCard`
    let result = V2Parser.parse(src, ())
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
    let visa = radios->Array.get(0)
    let mc = radios->Array.get(1)
    switch (visa, mc) {
    | (Some(v), Some(m)) => {
        t->expect(v.selected)->Expect.toBe(true)
        t->expect(String.trim(v.label))->Expect.toBe("Visa")
        t->expect(m.selected)->Expect.toBe(false)
        t->expect(String.trim(m.label))->Expect.toBe("MasterCard")
      }
    | _ => t->expect("missing-radios")->Expect.toBe("found")
    }
  })

  test("three same-row radios produce three nodes", t => {
    let src = `@scene: s

( ) S  ( ) M  (*) L`
    let result = V2Parser.parse(src, ())
    let radios = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | RadioNode(r) => Some(r)
      | _ => None
      }
    )
    t->expect(Array.length(radios))->Expect.toBe(3)
  })
})

describe("Regression P2: emoji not double-rendered (Codex round 3)", () => {
  test("interpolations do not contain a Literal that also includes the resolved emoji glyph", t => {
    let src = `@scene: s

"hi :check:"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          let emoji = EmojiRegistry.lookup("check")->Option.getOr("?")
          // No Literal segment should contain the resolved emoji glyph
          // (that would double-render alongside the EmojiRef).
          let literalsContainEmoji = Array.some(s.interpolations, (p: V2Types.interpolationContent) =>
            switch p {
            | Literal(l) => String.includes(l, emoji)
            | _ => false
            }
          )
          t->expect(literalsContainEmoji)->Expect.toBe(false)
          // And exactly one EmojiRef recorded.
          let emojiRefs = Array.filter(s.interpolations, (p: V2Types.interpolationContent) =>
            switch p {
            | EmojiRef(_) => true
            | _ => false
            }
          )
          t->expect(Array.length(emojiRefs))->Expect.toBe(1)
          // Content carries the resolved glyph (rendered once).
          t->expect(String.includes(s.content, emoji))->Expect.toBe(true)
        }
      | None => t->expect("missing-string")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("reconstructing from interpolations equals content", t => {
    let src = `@scene: s

"hi :check: bye"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          let rendered = Array.reduce(s.interpolations, "", (acc, p) =>
            switch p {
            | Literal(l) => acc ++ l
            | EmojiRef(e) => acc ++ e.emoji
            | PropRef(_) => acc ++ "" // would substitute prop value
            }
          )
          // Walking interpolations should yield the same display string as `content`.
          t->expect(rendered)->Expect.toBe(s.content)
        }
      | None => t->expect("missing")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("unknown emoji appears once in content and once in interpolations", t => {
    let src = `@scene: s

"x :nope: y"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          // Content contains the raw shortcode exactly once.
          let firstIdx = String.indexOf(s.content, ":nope:")
          let lastIdx = String.lastIndexOf(s.content, ":nope:")
          t->expect(firstIdx >= 0)->Expect.toBe(true)
          t->expect(firstIdx)->Expect.toBe(lastIdx)
          // Warning emitted.
          let hasWarning = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
            switch w.code {
            | UnknownEmoji(name) => name == "nope"
            | _ => false
            }
          )
          t->expect(hasWarning)->Expect.toBe(true)
        }
      | None => t->expect("missing")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })
})
