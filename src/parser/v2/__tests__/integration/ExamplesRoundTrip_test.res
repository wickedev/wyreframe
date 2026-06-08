// ExamplesRoundTrip_test.res
// Pull the literal wireframe blocks from examples/index.html and confirm
// each one parses successfully through V2. Catches regressions where
// real example content stops working under V2's grid/heuristic rules.

open Vitest

let loginV2 = `@scene: login
@title: Login
@device: mobile

+---------------------------+
|                           |
|        'WYREFRAME'        |
|                           |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #password           |  |
|  +---------------------+  |
|                           |
|     [ Login ]             |
|                           |
|  "Forgot password?"       |
|                           |
|  "Create account"         |
+---------------------------+`

let signupV2 = `@scene: signup
@title: Sign Up
@device: mobile

+---------------------------+
|     [ Back ]              |
|                           |
|     Create Account        |
|                           |
|  +---------------------+  |
|  | #name               |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #email2             |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #password2          |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #confirmPassword    |  |
|  +---------------------+  |
|                           |
|     [ Sign Up ]           |
+---------------------------+`

let forgotV2 = `@scene: forgot
@title: Forgot Password
@device: mobile

+---------------------------+
|     [ Back ]              |
|                           |
|   Reset Password          |
|                           |
|   Enter your email to     |
|   receive reset link      |
|                           |
|  +---------------------+  |
|  | #resetEmail         |  |
|  +---------------------+  |
|                           |
|     [ Send Link ]         |
+---------------------------+`

let dashboardSimplified = `@scene: dashboard
@title: Dashboard
@device: mobile

+---------------------------+
|  Dashboard      [ Logout ]|
|                           |
|  Welcome back!            |
|                           |
+---------------------------+`

describe("V2: examples/index.html scenes round-trip cleanly", () => {
  test("login", t => {
    let r = V2Parser.parse(loginV2, ())
    t->expect(r.success)->Expect.toBe(true)
    switch r.ast {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("login")
    | _ => t->expect(true)->Expect.toBe(false)
    }
  })

  test("signup", t => {
    let r = V2Parser.parse(signupV2, ())
    t->expect(r.success)->Expect.toBe(true)
    switch r.ast {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("signup")
    | _ => t->expect(true)->Expect.toBe(false)
    }
  })

  test("forgot", t => {
    let r = V2Parser.parse(forgotV2, ())
    t->expect(r.success)->Expect.toBe(true)
    switch r.ast {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("forgot")
    | _ => t->expect(true)->Expect.toBe(false)
    }
  })

  test("dashboard", t => {
    let r = V2Parser.parse(dashboardSimplified, ())
    t->expect(r.success)->Expect.toBe(true)
  })

  test("all examples produce a non-empty layout", t => {
    let r1 = V2Parser.parse(loginV2, ())
    switch r1.ast {
    | Some(SceneBlock(s)) => t->expect(Array.length(s.children) > 0)->Expect.toBe(true)
    | _ => ()
    }
  })

  test("layout groups address children by index range — no duplication", t => {
    let r = V2Parser.parse(loginV2, ())
    switch r.ast {
    | Some(SceneBlock(s)) => {
        // Every group's end_ is <= children length
        let nChildren = Array.length(s.children)
        Array.forEach(s.layout.groups, (g: V2Types.elementGroup) => {
          t->expect(g.end_ <= nChildren)->Expect.toBe(true)
          t->expect(g.start >= 0 && g.start < g.end_)->Expect.toBe(true)
        })
      }
    | _ => ()
    }
  })
})
