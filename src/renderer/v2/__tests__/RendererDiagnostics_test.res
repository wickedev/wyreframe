// Diagnostics_test.res
// Renderer warnings: duplicate ID, unresolved prop, unknown emoji, radio
// group inference, error nodes.

open Vitest
open V2RendererTestHelpers

let warningTag = (w: RenderWarning.t): string =>
  switch w {
  | DuplicateId(_, _) => "DuplicateId"
  | UnresolvedProp(_, _) => "UnresolvedProp"
  | UnknownEmojiShortcode(_, _) => "UnknownEmojiShortcode"
  | ErrorNodeRendered(_, _) => "ErrorNodeRendered"
  }

describe("V2Renderer / diagnostics", () => {
  test("duplicate id emits exactly one DuplicateId warning", t => {
    let (_, warnings) = renderWithDiag(
      container(
        ~children=[button(~id="dup", ()), button(~id="dup", ())],
        (),
      ),
    )
    let dups = warnings->Array.filter(w =>
      switch w {
      | RenderWarning.DuplicateId(_, _) => true
      | _ => false
      }
    )
    t->expect(Array.length(dups))->Expect.toBe(1)
  })

  test("clean input emits zero warnings", t => {
    let (_, warnings) = renderWithDiag(button(~id="ok", ~text="OK", ()))
    t->expect(Array.length(warnings))->Expect.toBe(0)
  })

  test("missing prop emits UnresolvedProp warning", t => {
    let (_, warnings) = renderWithDiag(propPlaceholder(~name="x", ()))
    let tags = warnings->Array.map(warningTag)
    t->expect(tags->Array.includes("UnresolvedProp"))->Expect.toBe(true)
  })

  test("unknown emoji shortcode emits UnknownEmojiShortcode warning", t => {
    let (_, warnings) = renderWithDiag(emoji(~shortcode="not_a_real_shortcode", ()))
    let tags = warnings->Array.map(warningTag)
    t->expect(tags->Array.includes("UnknownEmojiShortcode"))->Expect.toBe(true)
  })

  test("error node emits ErrorNodeRendered warning", t => {
    let (_, warnings) = renderWithDiag(errorNode(~message="bad", ()))
    let tags = warnings->Array.map(warningTag)
    t->expect(tags->Array.includes("ErrorNodeRendered"))->Expect.toBe(true)
  })

  test("custom emoji resolver overrides default table", t => {
    let opts = {
      ...RenderOptions.defaultOptions(),
      emojiResolver: Some(s => s == "custom" ? Some("⭐") : None),
    }
    let html = V2Renderer.renderToString(emoji(~shortcode="custom", ()), opts)
    t->expect(html->String.includes("⭐"))->Expect.toBe(true)
  })

  test("includeSourceLocations=false suppresses data-wf-row/col", t => {
    let opts = {...RenderOptions.defaultOptions(), includeSourceLocations: false}
    let html = V2Renderer.renderToString(button(~id="a", ()), opts)
    t->expect(html->String.includes("data-wf-row"))->Expect.toBe(false)
    t->expect(html->String.includes("data-wf-col"))->Expect.toBe(false)
  })
})

describe("V2Renderer / radio group inference", () => {
  test("contiguous radios share an inferred group name", t => {
    let r1 = radio(~label="A", ~location=loc(~startRow=1, ~startCol=2, ()), ())
    let r2 = radio(~label="B", ~location=loc(~startRow=2, ~startCol=2, ()), ())
    let r3 = radio(~label="C", ~location=loc(~startRow=3, ~startCol=2, ()), ())
    let html = render(container(~children=[r1, r2, r3], ()))
    // Each radio's <input name="..."> should match. Parse out names by
    // matching `name="<x>"` and asserting all equal.
    let parts = html->String.split("name=\"")
    let names = parts->Array.sliceToEnd(~start=1)->Array.map(p => {
      switch String.indexOf(p, "\"") {
      | -1 => p
      | n => String.slice(p, ~start=0, ~end=n)
      }
    })
    t->expect(Array.length(names))->Expect.toBe(3)
    let first = Array.getUnsafe(names, 0)
    t->expect(Array.every(names, n => n == first))->Expect.toBe(true)
  })

  test("non-radio sibling breaks the group", t => {
    let r1 = radio(~label="A", ~location=loc(~startRow=1, ~startCol=2, ()), ())
    let bk = text(~content="x", ~location=loc(~startRow=2, ~startCol=2, ()), ())
    let r2 = radio(~label="B", ~location=loc(~startRow=3, ~startCol=2, ()), ())
    let html = render(container(~children=[r1, bk, r2], ()))
    let parts = html->String.split("name=\"")
    let names = parts->Array.sliceToEnd(~start=1)->Array.map(p => {
      switch String.indexOf(p, "\"") {
      | -1 => p
      | n => String.slice(p, ~start=0, ~end=n)
      }
    })
    t->expect(Array.length(names))->Expect.toBe(2)
    t->expect(Array.getUnsafe(names, 0) != Array.getUnsafe(names, 1))->Expect.toBe(true)
  })

  test("explicit group overrides inference", t => {
    let r1 = radio(~label="A", ~group=Some("g1"), ())
    let r2 = radio(~label="B", ~group=Some("g1"), ())
    let html = render(container(~children=[r1, r2], ()))
    t->expect(html->String.includes("name=\"g1\""))->Expect.toBe(true)
  })
})
