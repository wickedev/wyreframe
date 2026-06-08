// Examples_test.res
// End-to-end smoke tests using the wireframe snippets from examples/index.html.
// Verifies V2 parses real-world examples without erroring and produces a
// structurally sane AST (correct slug, child counts, container nesting).

open Vitest

let loginScene = `@scene: login
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

let signupScene = `@scene: signup
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
|     [ Sign Up ]           |
+---------------------------+`

let dashboardScene = `@scene: dashboard
@title: Dashboard
@device: mobile

+---------------------------+
|  Dashboard      [ Logout ]|
|                           |
|  Welcome back!            |
|                           |
+---------------------------+`

let countContainers = (block: V2Types.blockNode): int => {
  let count = ref(0)
  let rec walk = (node: V2Types.astNode) => {
    switch node {
    | ContainerNode(_) => count := count.contents + 1
    | _ => ()
    }
    switch V2Types.getChildren(node) {
    | Some(children) => Array.forEach(children, walk)
    | None => ()
    }
  }
  let root = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }
  walk(root)
  count.contents
}

let countButtons = (block: V2Types.blockNode): int => {
  let count = ref(0)
  let rec walk = (node: V2Types.astNode) => {
    switch node {
    | ButtonNode(_) => count := count.contents + 1
    | _ => ()
    }
    switch V2Types.getChildren(node) {
    | Some(children) => Array.forEach(children, walk)
    | None => ()
    }
  }
  let root = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }
  walk(root)
  count.contents
}

let countStrings = (block: V2Types.blockNode): int => {
  let count = ref(0)
  let rec walk = (node: V2Types.astNode) => {
    switch node {
    | StringNode(_) => count := count.contents + 1
    | _ => ()
    }
    switch V2Types.getChildren(node) {
    | Some(children) => Array.forEach(children, walk)
    | None => ()
    }
  }
  let root = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }
  walk(root)
  count.contents
}

describe("V2 Parser - examples/index.html scenes", () => {
  test("parses the login scene without errors", t => {
    let result = V2Parser.parse(loginScene, ())
    t->expect(result.success)->Expect.toBe(true)
    t->expect(Array.length(result.errors))->Expect.toBe(0)
  })

  test("login scene has the correct slug, title, device", t => {
    let result = V2Parser.parse(loginScene, ())
    switch result.ast {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("login")
        t->expect(s.title)->Expect.toEqual(Some("Login"))
        t->expect(s.device)->Expect.toEqual(Some(V2Types.Mobile))
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail
    }
  })

  test("login scene contains the outer container", t => {
    let result = V2Parser.parse(loginScene, ())
    switch result.ast {
    | Some(block) => {
        // 1 outer + 2 inner (email/password) = 3 containers
        t->expect(countContainers(block))->Expect.toBe(3)
      }
    | None => t->expect(true)->Expect.toBe(false)
    }
  })

  test("login scene includes the Login button", t => {
    let result = V2Parser.parse(loginScene, ())
    switch result.ast {
    | Some(block) => t->expect(countButtons(block) >= 1)->Expect.toBe(true)
    | None => t->expect(true)->Expect.toBe(false)
    }
  })

  test("login scene includes two string literals (forgot/create)", t => {
    let result = V2Parser.parse(loginScene, ())
    switch result.ast {
    | Some(block) => t->expect(countStrings(block))->Expect.toBe(2)
    | None => t->expect(true)->Expect.toBe(false)
    }
  })

  test("parses the signup scene", t => {
    let result = V2Parser.parse(signupScene, ())
    t->expect(result.success)->Expect.toBe(true)
    switch result.ast {
    | Some(SceneBlock(s)) => {
        t->expect(s.slug)->Expect.toBe("signup")
        t->expect(countButtons(SceneBlock(s)) >= 2)->Expect.toBe(true)
      }
    | _ => t->expect(true)->Expect.toBe(false)
    }
  })

  test("parses the dashboard scene", t => {
    let result = V2Parser.parse(dashboardScene, ())
    t->expect(result.success)->Expect.toBe(true)
    switch result.ast {
    | Some(SceneBlock(s)) => t->expect(s.slug)->Expect.toBe("dashboard")
    | _ => t->expect(true)->Expect.toBe(false)
    }
  })
})

describe("V2 Parser - error cases", () => {
  test("missing block declaration", t => {
    let result = V2Parser.parse("Just some text", ())
    t->expect(result.success)->Expect.toBe(false)
    t->expect(Array.length(result.errors) >= 1)->Expect.toBe(true)
  })

  test("unclosed container produces an error", t => {
    let src = `@scene: bad

+--Top--+
|       |
|       |`
    let result = V2Parser.parse(src, ())
    t->expect(Array.length(result.errors) >= 1)->Expect.toBe(true)
  })

  test("priority disambiguation: [v: foo] parses as Select", t => {
    let src = `@scene: t

+------------+
| [v: pick]  |
+------------+`
    let result = V2Parser.parse(src, ())
    let foundSelect = ref(false)
    switch result.ast {
    | Some(block) => {
        let rec walk = (n: V2Types.astNode) => {
          switch n {
          | SelectNode(_) => foundSelect := true
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
      }
    | None => ()
    }
    t->expect(foundSelect.contents)->Expect.toBe(true)
  })

  test("priority disambiguation: [__email__] parses as Input", t => {
    let src = `@scene: t

+-------------+
| [__email__] |
+-------------+`
    let result = V2Parser.parse(src, ())
    let foundInput = ref(false)
    switch result.ast {
    | Some(block) => {
        let rec walk = (n: V2Types.astNode) => {
          switch n {
          | InputNode(_) => foundInput := true
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
      }
    | None => ()
    }
    t->expect(foundInput.contents)->Expect.toBe(true)
  })

  test("priority disambiguation: [x] parses as Checkbox", t => {
    let src = `@scene: t

[x] Accept terms`
    let result = V2Parser.parse(src, ())
    let foundCheckbox = ref(false)
    switch result.ast {
    | Some(block) => {
        let rec walk = (n: V2Types.astNode) => {
          switch n {
          | CheckboxNode(c) => if c.checked { foundCheckbox := true }
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
      }
    | None => ()
    }
    t->expect(foundCheckbox.contents)->Expect.toBe(true)
  })
})
