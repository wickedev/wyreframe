// Regressions_test.res
// Codex-review-driven regression tests.

open Vitest

let firstStringNode = (block: V2Types.blockNode): option<V2Types.stringNode> => {
  let found = ref(None)
  let rec walk = (n: V2Types.astNode) => {
    switch (found.contents, n) {
    | (None, StringNode(s)) => found := Some(s)
    | _ => ()
    }
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
  found.contents
}

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

describe("Regression: StringParser preserves content (Codex P2)", () => {
  test("plain string content is non-empty", t => {
    let src = `@scene: t

"hello world"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => t->expect(s.content)->Expect.toBe("hello world")
      | None => t->expect("missing-string-node")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("string with emoji resolves into content", t => {
    let src = `@scene: t

"hi :check: there"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          // Content should include the resolved emoji glyph.
          t->expect(String.includes(s.content, "✔"))->Expect.toBe(true)
          // Content should include the surrounding text.
          t->expect(String.includes(s.content, "hi"))->Expect.toBe(true)
          t->expect(String.includes(s.content, "there"))->Expect.toBe(true)
          // Interpolations should record the EmojiRef.
          let hasEmojiRef = Array.some(s.interpolations, (p: V2Types.interpolationContent) =>
            switch p {
            | EmojiRef(_) => true
            | _ => false
            }
          )
          t->expect(hasEmojiRef)->Expect.toBe(true)
        }
      | None => t->expect("missing-string-node")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("multiline string content keeps the newline", t => {
    let src = `@scene: t

"line1
line2"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          t->expect(s.multiline)->Expect.toBe(true)
          t->expect(String.includes(s.content, "line1"))->Expect.toBe(true)
          t->expect(String.includes(s.content, "line2"))->Expect.toBe(true)
          t->expect(String.includes(s.content, "\n"))->Expect.toBe(true)
        }
      | None => t->expect("missing")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })

  test("component-side ${prop} inside string keeps marker in content + PropRef in interpolations", t => {
    let src = `@component: greeting
@props: name

"Hello \${name}!"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          // Content carries the literal `${name}` marker.
          t->expect(String.includes(s.content, "Hello"))->Expect.toBe(true)
          t->expect(String.includes(s.content, "\${name}"))->Expect.toBe(true)
          let hasPropRef = Array.some(s.interpolations, (p: V2Types.interpolationContent) =>
            switch p {
            | PropRef(_) => true
            | _ => false
            }
          )
          t->expect(hasPropRef)->Expect.toBe(true)
        }
      | None => t->expect("missing")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
  })
})

describe("Regression: scene-level \${prop} becomes literal text (Codex P2)", () => {
  test("standalone scene-level \${prop} returns TextNode, not PropPlaceholderNode", t => {
    let src = `@scene: t

\${name}`
    let result = V2Parser.parse(src, ())
    let foundPlaceholder = ref(false)
    let foundTextLiteral = ref(false)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n => {
        switch n {
        | PropPlaceholderNode(_) => foundPlaceholder := true
        | TextNode(t) =>
          if String.includes(t.content, "\${name}") {
            foundTextLiteral := true
          }
        | _ => ()
        }
      })
    | None => ()
    }
    t->expect(foundPlaceholder.contents)->Expect.toBe(false)
    t->expect(foundTextLiteral.contents)->Expect.toBe(true)
  })

  test("scene-level \${prop} emits PropOutsideComponent warning", t => {
    let src = `@scene: t

\${name}`
    let result = V2Parser.parse(src, ())
    let hasWarning = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | PropOutsideComponent => true
      | _ => false
      }
    )
    t->expect(hasWarning)->Expect.toBe(true)
  })

  test("component-side \${prop} still returns PropPlaceholderNode", t => {
    let src = `@component: c
@props: name

\${name}`
    let result = V2Parser.parse(src, ())
    let foundPlaceholder = ref(false)
    switch result.ast {
    | Some(block) =>
      Array.forEach(collectNodes(block), n => {
        switch n {
        | PropPlaceholderNode(_) => foundPlaceholder := true
        | _ => ()
        }
      })
    | None => ()
    }
    t->expect(foundPlaceholder.contents)->Expect.toBe(true)
  })

  test("scene-level \${prop} inside string keeps literal marker, no PropRef", t => {
    let src = `@scene: t

"Hello \${name}"`
    let result = V2Parser.parse(src, ())
    switch result.ast {
    | Some(block) =>
      switch firstStringNode(block) {
      | Some(s) => {
          t->expect(String.includes(s.content, "\${name}"))->Expect.toBe(true)
          let hasPropRef = Array.some(s.interpolations, (p: V2Types.interpolationContent) =>
            switch p {
            | PropRef(_) => true
            | _ => false
            }
          )
          t->expect(hasPropRef)->Expect.toBe(false)
        }
      | None => t->expect("missing")->Expect.toBe("present")
      }
    | None => t->expect("no-ast")->Expect.toBe("ast")
    }
    let hasWarning = Array.some(result.warnings, (w: V2Errors.parseWarning) =>
      switch w.code {
      | PropOutsideComponent => true
      | _ => false
      }
    )
    t->expect(hasWarning)->Expect.toBe(true)
  })
})
