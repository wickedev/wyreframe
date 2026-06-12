// Elements_test.res
// Golden snapshot tests for each of the 15 V2 AST node variants.
//
// Each variant has a minimal canonical fixture; the assertion is
// expressed as `t->expect(actual)->Expect.toBe(expected)` so a diff is
// immediately readable on failure.

open Vitest
open V2RendererTestHelpers

describe("V2Renderer / elements", () => {
  test("SceneNode minimal", t => {
    let html = render(scene(~slug="login", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<section class=\"wf-scene\" data-wf-col=\"0\" data-wf-row=\"0\" data-wf-slug=\"login\"></section>",
    )
  })

  test("SceneNode with title/device/transition", t => {
    let html = render(
      scene(
        ~slug="home",
        ~title=Some("Home"),
        ~device=Some(Mobile),
        ~transition=Some("fade"),
        (),
      ),
    )
    t
    ->expect(html)
    ->Expect.toBe(
      "<section class=\"wf-device-mobile wf-scene\" aria-label=\"Home\" data-wf-col=\"0\" data-wf-device=\"mobile\" data-wf-row=\"0\" data-wf-slug=\"home\" data-wf-title=\"Home\" data-wf-transition=\"fade\"></section>",
    )
  })

  test("ComponentNode with props", t => {
    let html = render(
      component(
        ~slug="card",
        ~props=[
          {name: "title", optional: false, defaultValue: None},
          {name: "subtitle", optional: true, defaultValue: None},
          {name: "kind", optional: true, defaultValue: Some("primary")},
        ],
        (),
      ),
    )
    t
    ->expect(html)
    ->Expect.toBe(
      "<section class=\"wf-component\" data-wf-col=\"0\" data-wf-prop-kind=\"primary\" data-wf-prop-subtitle=\"optional\" data-wf-prop-title=\"required\" data-wf-row=\"0\" data-wf-slug=\"card\"></section>",
    )
  })

  test("ContainerNode Row + SpaceBetween + children", t => {
    let html = render(
      container(
        ~layout=layout(~direction=Row, ~distribution=Some(SpaceBetween), ()),
        ~children=[button(~id="a", ~text="A", ()), button(~id="b", ~text="B", ())],
        (),
      ),
    )
    t
    ->expect(html)
    ->Expect.toBe(
      "<div class=\"wf-container wf-direction-row wf-dist-space-between\" data-wf-col=\"0\" data-wf-row=\"0\">" ++
      "<button id=\"wf-a\" class=\"wf-button\" type=\"button\" data-wf-col=\"0\" data-wf-id=\"a\" data-wf-row=\"0\">A</button>" ++
      "<button id=\"wf-b\" class=\"wf-button\" type=\"button\" data-wf-col=\"0\" data-wf-id=\"b\" data-wf-row=\"0\">B</button>" ++
      "</div>",
    )
  })

  test("TextNode block (column parent)", t => {
    let html = render(
      container(
        ~layout=layout(~direction=Column, ()),
        ~children=[text(~content="hello", ())],
        (),
      ),
    )
    t->expect(html->String.includes("<p class=\"wf-align-left wf-text\""))->Expect.toBe(true)
  })

  test("TextNode inline (row parent)", t => {
    let html = render(
      container(
        ~layout=layout(~direction=Row, ()),
        ~children=[text(~content="hi", ())],
        (),
      ),
    )
    t->expect(html->String.includes("<span class=\"wf-align-left wf-text\""))->Expect.toBe(true)
  })

  test("ButtonNode minimal", t => {
    let html = render(button(~id="ok", ~text="OK", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<button id=\"wf-ok\" class=\"wf-button\" type=\"button\" data-wf-col=\"0\" data-wf-id=\"ok\" data-wf-row=\"0\">OK</button>",
    )
  })

  test("LinkNode minimal", t => {
    let html = render(link(~id="more", ~text="More", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<a id=\"wf-more\" class=\"wf-link\" data-wf-col=\"0\" data-wf-id=\"more\" data-wf-row=\"0\">More</a>",
    )
  })

  test("InputNode with placeholder", t => {
    let html = render(input(~placeholder="email", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<input class=\"wf-input\" placeholder=\"email\" data-wf-col=\"0\" data-wf-row=\"0\" />",
    )
  })

  test("InputNode no placeholder", t => {
    let html = render(input())
    t->expect(html)->Expect.toBe("<input class=\"wf-input\" data-wf-col=\"0\" data-wf-row=\"0\" />")
  })

  test("SelectNode with placeholder option", t => {
    let html = render(select(~id="country", ~placeholder="Pick one", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<select id=\"wf-country\" class=\"wf-select\" data-wf-col=\"0\" data-wf-id=\"country\" data-wf-row=\"0\">" ++
      "<option value=\"\">Pick one</option>" ++ "</select>",
    )
  })

  test("CheckboxNode checked", t => {
    let html = render(checkbox(~checked=true, ~label="Remember me", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<label class=\"wf-checkbox\" data-wf-checked=\"true\" data-wf-col=\"0\" data-wf-row=\"0\">" ++
      "<input checked=\"checked\" type=\"checkbox\" />" ++ "<span>Remember me</span>" ++ "</label>",
    )
  })

  test("CheckboxNode unchecked", t => {
    let html = render(checkbox(~label="Agree", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<label class=\"wf-checkbox\" data-wf-checked=\"false\" data-wf-col=\"0\" data-wf-row=\"0\">" ++
      "<input type=\"checkbox\" />" ++ "<span>Agree</span>" ++ "</label>",
    )
  })

  test("RadioNode with explicit group", t => {
    let html = render(radio(~label="A", ~group=Some("opts"), ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<label class=\"wf-radio\" data-wf-col=\"0\" data-wf-group=\"opts\" data-wf-row=\"0\">" ++
      "<input name=\"opts\" type=\"radio\" />" ++ "<span>A</span>" ++ "</label>",
    )
  })

  test("DividerNode normal", t => {
    let html = render(divider())
    t
    ->expect(html)
    ->Expect.toBe("<hr class=\"wf-divider\" data-wf-col=\"0\" data-wf-row=\"0\" />")
  })

  test("DividerNode bold", t => {
    let html = render(divider(~style=Bold, ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<hr class=\"wf-divider wf-divider-bold\" data-wf-col=\"0\" data-wf-row=\"0\" />",
    )
  })

  test("StringNode preserves whitespace and escapes", t => {
    let html = render(string_(~content="  hi <b>x</b>  ", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-string\" data-wf-col=\"0\" data-wf-row=\"0\">  hi &lt;b&gt;x&lt;/b&gt;  </span>",
    )
  })

  test("EmojiNode known shortcode resolves via default table", t => {
    let html = render(emoji(~shortcode="smile", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-emoji\" aria-label=\"smile\" data-wf-col=\"0\" data-wf-emoji-shortcode=\"smile\" data-wf-row=\"0\">😄</span>",
    )
  })

  test("EmojiNode unknown shortcode emits literal", t => {
    let html = render(emoji(~shortcode="not_a_real_shortcode", ()))
    t->expect(html->String.includes(":not_a_real_shortcode:"))->Expect.toBe(true)
  })

  test("PropPlaceholderNode missing renders marker", t => {
    let html = render(propPlaceholder(~name="title", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-prop-missing\" data-wf-col=\"0\" data-wf-prop=\"title\" data-wf-row=\"0\">{{title}}</span>",
    )
  })

  test("PropPlaceholderNode with default", t => {
    let html = render(propPlaceholder(~name="kind", ~defaultValue=Some("primary"), ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-prop-resolved\" data-wf-col=\"0\" data-wf-prop=\"kind\" data-wf-row=\"0\">primary</span>",
    )
  })

  test("PropPlaceholderNode resolved via componentPropValues", t => {
    let opts = RenderOptions.defaultOptions()
    let propValues = Dict.make()
    Dict.set(propValues, "title", "Hello")
    let opts = {...opts, componentPropValues: propValues}
    let html = V2Renderer.renderToString(propPlaceholder(~name="title", ()), opts)
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-prop-resolved\" data-wf-col=\"0\" data-wf-prop=\"title\" data-wf-row=\"0\">Hello</span>",
    )
  })

  test("ErrorNode default mode renders marker", t => {
    let html = render(errorNode(~message="bad", ()))
    t
    ->expect(html)
    ->Expect.toBe(
      "<span class=\"wf-error\" role=\"alert\" data-wf-col=\"0\" data-wf-error-code=\"error\" data-wf-error-msg=\"bad\" data-wf-row=\"0\">bad</span>",
    )
  })

  test("ErrorNode Skip mode produces empty output", t => {
    let opts = {...RenderOptions.defaultOptions(), errorHandling: Skip}
    let html = V2Renderer.renderToString(errorNode(~message="bad", ()), opts)
    t->expect(html)->Expect.toBe("")
  })

  test("ErrorNode Throw mode raises", t => {
    let opts = {...RenderOptions.defaultOptions(), errorHandling: Throw}
    let didThrow = try {
      let _ = V2Renderer.renderToString(errorNode(~message="bad", ()), opts)
      false
    } catch {
    | _ => true
    }
    t->expect(didThrow)->Expect.toBe(true)
  })
})
