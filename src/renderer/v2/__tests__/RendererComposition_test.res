// Composition_test.res
// Realistic composite ASTs end-to-end: a login-form scene.

open Vitest
open V2RendererTestHelpers

let loginForm: V2Types.astNode = scene(
  ~slug="login",
  ~title=Some("Login"),
  ~device=Some(Mobile),
  ~layout=layout(~direction=Column, ()),
  ~children=[
    text(~content="Welcome back", ~align=Center, ()),
    container(
      ~layout=layout(~direction=Column, ()),
      ~children=[
        input(~placeholder="email", ()),
        input(~placeholder="password", ()),
        container(
          ~layout=layout(~direction=Row, ~distribution=Some(SpaceBetween), ()),
          ~children=[
            checkbox(~label="Remember me", ()),
            link(~id="forgot", ~text="Forgot?", ()),
          ],
          (),
        ),
        button(~id="signin", ~text="Sign in", ()),
      ],
      (),
    ),
    divider(),
    container(
      ~layout=layout(~direction=Row, ()),
      ~children=[
        text(~content="No account?", ()),
        link(~id="signup", ~text="Sign up", ()),
      ],
      (),
    ),
  ],
  (),
)

describe("V2Renderer / composition", () => {
  test("login form scene structure", t => {
    let html = render(loginForm)
    t->expect(html->String.startsWith("<section"))->Expect.toBe(true)
    t->expect(html->String.endsWith("</section>"))->Expect.toBe(true)
    t->expect(html->String.includes("wf-scene"))->Expect.toBe(true)
    t->expect(html->String.includes("wf-device-mobile"))->Expect.toBe(true)
    t->expect(html->String.includes("placeholder=\"email\""))->Expect.toBe(true)
    t->expect(html->String.includes("placeholder=\"password\""))->Expect.toBe(true)
    t->expect(html->String.includes("<button"))->Expect.toBe(true)
    t->expect(html->String.includes("Sign in"))->Expect.toBe(true)
    t->expect(html->String.includes("<hr"))->Expect.toBe(true)
    // Inline text (inside row container)
    t->expect(html->String.includes("<span class=\"wf-align-left wf-text\""))->Expect.toBe(true)
  })

  test("login form scene is deterministic across 50 renders", t => {
    let first = render(loginForm)
    let allEqual = ref(true)
    for _ in 1 to 49 {
      if render(loginForm) != first {
        allEqual := false
      }
    }
    t->expect(allEqual.contents)->Expect.toBe(true)
  })

  test("3-level nested containers respect document order", t => {
    let html = render(
      container(
        ~children=[
          container(
            ~children=[
              container(
                ~children=[
                  button(~id="deep", ~text="X", ()),
                ],
                (),
              ),
            ],
            (),
          ),
        ],
        (),
      ),
    )
    let openCount = html->String.split("<div")->Array.length - 1
    let closeCount = html->String.split("</div>")->Array.length - 1
    t->expect(openCount)->Expect.toBe(3)
    t->expect(closeCount)->Expect.toBe(3)
    t->expect(html->String.includes(">X<"))->Expect.toBe(true)
  })
})
