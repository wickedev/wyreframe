// Conformance_test.res
// Confirm every V2 AST node variant emits *something* printable
// (string length > 0) via InlineEmitter or BlockEmitter.

open Vitest

let dummyLoc: V2Types.sourceLocation = V2Types.zeroLoc

describe("V2 Printer — conformance: every node variant emits", () => {
  test("ButtonNode", t => {
    let n = V2Types.ButtonNode({location: dummyLoc, id: "go", text: "Go"})
    let s = InlineEmitter.emitInline(n)
    t->expect(String.length(s) > 0)->Expect.toBe(true)
  })
  test("LinkNode", t => {
    let n = V2Types.LinkNode({location: dummyLoc, id: "x", text: "X"})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("InputNode", t => {
    let n = V2Types.InputNode({location: dummyLoc, placeholder: "email"})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("SelectNode", t => {
    let n = V2Types.SelectNode({location: dummyLoc, id: "x", placeholder: "pick"})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("CheckboxNode", t => {
    let n = V2Types.CheckboxNode({location: dummyLoc, checked: true, label: "Yes"})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("RadioNode", t => {
    let n = V2Types.RadioNode({
      location: dummyLoc,
      selected: false,
      label: "No",
      group: None,
    })
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("DividerNode", t => {
    let n = V2Types.DividerNode({
      location: dummyLoc,
      style: Normal,
      id: None,
      label: None,
    })
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("StringNode", t => {
    let n = V2Types.StringNode({
      location: dummyLoc,
      content: "hi",
      interpolations: [],
      multiline: false,
    })
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("EmojiNode", t => {
    let n = V2Types.EmojiNode({location: dummyLoc, shortcode: "smile", emoji: ":)"})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("PropPlaceholderNode", t => {
    let n = V2Types.PropPlaceholderNode({
      location: dummyLoc,
      name: "foo",
      required: true,
      defaultValue: None,
    })
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("TextNode", t => {
    let n = V2Types.TextNode({location: dummyLoc, content: "hello", align: Left})
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("ErrorNode skip-or-marker", t => {
    let n = V2Types.ErrorNode({
      location: dummyLoc,
      message: "bad",
      recoveredContent: Some("oops"),
    })
    t->expect(String.length(InlineEmitter.emitInline(n)) > 0)->Expect.toBe(true)
  })
  test("ContainerNode (block-level)", t => {
    let n: V2Types.containerNode = {
      location: dummyLoc,
      id: None,
      name: None,
      children: [],
      layout: V2Types.emptyLayout,
      bounds: {x: 0, y: 0, width: 4, height: 3},
      containsErrorRecovery: false,
    }
    let lines = BlockEmitter.emitContainer(n, ~chars=BorderChars.ascii)
    t->expect(Array.length(lines) >= 2)->Expect.toBe(true)
  })
  test("SceneBlock", t => {
    let s: V2Types.sceneNode = {
      location: dummyLoc,
      slug: "test",
      title: None,
      device: None,
      transition: None,
      children: [],
      layout: V2Types.emptyLayout,
    }
    let out = V2Printer.printBlock(V2Types.SceneBlock(s), V2Printer.defaultOptions())
    t->expect(String.length(out) > 0)->Expect.toBe(true)
  })
  test("ComponentBlock", t => {
    let c: V2Types.componentNode = {
      location: dummyLoc,
      slug: "comp",
      props: [],
      children: [],
      layout: V2Types.emptyLayout,
    }
    let out = V2Printer.printBlock(V2Types.ComponentBlock(c), V2Printer.defaultOptions())
    t->expect(String.length(out) > 0)->Expect.toBe(true)
  })
})
