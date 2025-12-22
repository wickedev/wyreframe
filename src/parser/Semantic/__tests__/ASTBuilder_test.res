// ASTBuilder_test.res
// Unit tests for AST Builder module

open Vitest

let pass = ()

describe("ASTBuilder", t => {
  describe("buildScene", t => {
    test("builds scene with all fields provided", t => {
      let config = {
        ASTBuilder.id: "login",
        title: Some("Login Page"),
        transition: Some("slide"),
        elements: [],
        position: Types.Position.make(1, 0),
        device: Some(Types.Desktop),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          t->expect(scene.id)->Expect.toBe("login")
          t->expect(scene.title)->Expect.toBe("Login Page")
          t->expect(scene.transition)->Expect.toBe("slide")
          t->expect(Array.length(scene.elements))->Expect.toBe(0)
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected successful scene build
      }
    })

    test("derives title from ID when title not provided", t => {
      let config = {
        ASTBuilder.id: "login-page",
        title: None,
        transition: None,
        elements: [],
        position: Types.Position.make(1, 0),
        device: Some(Types.Desktop),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          t->expect(scene.id)->Expect.toBe("login-page")
          t->expect(scene.title)->Expect.toBe("Login Page")
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected successful scene build
      }
    })

    test("uses default transition when not provided", t => {
      let config = {
        ASTBuilder.id: "home",
        title: Some("Home"),
        transition: None,
        elements: [],
        position: Types.Position.make(1, 0),
        device: Some(Types.Desktop),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          t->expect(scene.transition)->Expect.toBe("none")
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected successful scene build
      }
    })

    test("rejects empty scene ID", t => {
      let config = {
        ASTBuilder.id: "",
        title: Some("Empty ID"),
        transition: None,
        elements: [],
        position: Types.Position.make(1, 0),
        device: Some(Types.Desktop),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(_) => t->expect(true)->Expect.toBe(false) // fail: Expected error for empty scene ID
      | Error(ASTBuilder.EmptySceneId(_)) => pass
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected EmptySceneId error
      }
    })
  })

  describe("buildAST", t => {
    test("builds AST with single scene", t => {
      let configs = [
        {
          ASTBuilder.id: "home",
          title: Some("Home"),
          transition: Some("fade"),
          elements: [],
          position: Types.Position.make(1, 0),
          device: Some(Types.Desktop),
        },
      ]

      let result = ASTBuilder.buildAST(configs)

      switch result {
      | Ok(ast) => {
          t->expect(Array.length(ast.scenes))->Expect.toBe(1)
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected successful AST build
      }
    })

    test("detects duplicate scene IDs", t => {
      let configs = [
        {
          ASTBuilder.id: "home",
          title: Some("Home"),
          transition: None,
          elements: [],
          position: Types.Position.make(1, 0),
          device: Some(Types.Desktop),
        },
        {
          ASTBuilder.id: "home",
          title: Some("Home Again"),
          transition: None,
          elements: [],
          position: Types.Position.make(20, 0),
          device: Some(Types.Desktop),
        },
      ]

      let result = ASTBuilder.buildAST(configs)

      switch result {
      | Ok(_) => t->expect(true)->Expect.toBe(false) // fail: Expected error for duplicate scene IDs
      | Error(errors) => {
          t->expect(Array.length(errors))->Expect.Int.toBeGreaterThan(0)
        }
      }
    })
  })

  describe("helper functions", t => {
    let testAST = {
      Types.scenes: [
        {
          id: "home",
          title: "Home",
          transition: "none",
          device: Types.Desktop,
          elements: [],
        },
        {
          id: "about",
          title: "About",
          transition: "fade",
          device: Types.Desktop,
          elements: [],
        },
      ],
    }

    test("getSceneById finds existing scene", t => {
      let scene = ASTBuilder.getSceneById(testAST, "about")

      switch scene {
      | Some(s) => {
          t->expect(s.id)->Expect.toBe("about")
          t->expect(s.title)->Expect.toBe("About")
        }
      | None => t->expect(true)->Expect.toBe(false) // fail: Expected to find scene
      }
    })

    test("hasScene returns true for existing scene", t => {
      let exists = ASTBuilder.hasScene(testAST, "home")

      t->expect(exists)->Expect.toBe(true)
    })

    test("getSceneIds returns all scene IDs", t => {
      let ids = ASTBuilder.getSceneIds(testAST)

      t->expect(Array.length(ids))->Expect.toBe(2)
    })
  })
})
