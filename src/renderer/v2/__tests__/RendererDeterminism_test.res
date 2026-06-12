// Determinism_test.res
// Render the same AST 50× and assert byte-identical output. Covers a
// representative corpus of fixtures including duplicate ids, mixed
// children, and explicit attribute permutations.

open Vitest
open V2RendererTestHelpers

let fixtures: array<V2Types.astNode> = [
  scene(~slug="empty", ()),
  scene(
    ~slug="login",
    ~title=Some("Login"),
    ~device=Some(Mobile),
    ~children=[
      container(
        ~layout=layout(~direction=Column, ()),
        ~children=[
          text(~content="Welcome", ()),
          input(~placeholder="email", ()),
          input(~placeholder="password", ()),
          button(~id="login", ~text="Sign In", ()),
        ],
        (),
      ),
    ],
    (),
  ),
  scene(
    ~slug="forms",
    ~children=[
      checkbox(~checked=true, ~label="Remember me", ()),
      radio(~label="A", ~group=Some("opts"), ()),
      radio(~label="B", ~group=Some("opts"), ()),
      divider(~style=Bold, ()),
      string_(~content="<hi> 'world' & \"co\"", ()),
      emoji(~shortcode="smile", ()),
      propPlaceholder(~name="title", ~defaultValue=Some("X"), ()),
      errorNode(~message="oops", ()),
    ],
    (),
  ),
  component(
    ~slug="card",
    ~props=[
      {name: "title", optional: false, defaultValue: None},
      {name: "kind", optional: true, defaultValue: Some("primary")},
    ],
    ~children=[propPlaceholder(~name="title", ()), propPlaceholder(~name="kind", ())],
    (),
  ),
  container(
    ~layout=layout(~direction=Row, ~distribution=Some(SpaceBetween), ()),
    ~children=[
      button(~id="a", ~text="A", ()),
      button(~id="b", ~text="B", ()),
      button(~id="c", ~text="C", ()),
    ],
    (),
  ),
]

describe("V2Renderer / determinism", () => {
  fixtures->Array.forEachWithIndex((fixture, i) => {
    test("fixture #" ++ Int.toString(i) ++ " is byte-identical across 50 renders", t => {
      let first = render(fixture)
      let allEqual = ref(true)
      for _ in 1 to 49 {
        let next = render(fixture)
        if next != first {
          allEqual := false
        }
      }
      t->expect(allEqual.contents)->Expect.toBe(true)
    })
  })

  test("synthetic radio group IDs are deterministic across renders", t => {
    let radios = [
      radio(~label="A", ~location=loc(~startRow=1, ~startCol=2, ()), ()),
      radio(~label="B", ~location=loc(~startRow=2, ~startCol=2, ()), ()),
    ]
    let fixture = container(~children=radios, ())
    let a = render(fixture)
    let b = render(fixture)
    t->expect(a)->Expect.toBe(b)
  })

  test("synthetic ID changes when salt changes", t => {
    let radios = [radio(~label="A", ~location=loc(~startRow=1, ~startCol=2, ()), ())]
    let fixture = container(~children=radios, ())
    let optsA = RenderOptions.defaultOptions()
    let optsB = {...optsA, syntheticIdSalt: "alt"}
    let a = V2Renderer.renderToString(fixture, optsA)
    let b = V2Renderer.renderToString(fixture, optsB)
    t->expect(a != b)->Expect.toBe(true)
  })
})
