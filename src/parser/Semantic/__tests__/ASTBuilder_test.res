// ASTBuilder_test.res
// Unit tests for AST Builder module

open Jest
open Expect

describe("ASTBuilder", () => {
  describe("buildScene", () => {
    test("builds scene with all fields provided", () => {
      let config = {
        ASTBuilder.id: "login",
        title: Some("Login Page"),
        transition: Some("slide"),
        elements: [],
        position: Position.make(1, 0),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          expect(scene.id)->toBe("login")
          expect(scene.title)->toBe("Login Page")
          expect(scene.transition)->toBe("slide")
          expect(Array.length(scene.elements))->toBe(0)
        }
      | Error(_) => fail("Expected successful scene build")
      }
    })

    test("derives title from ID when title not provided", () => {
      let config = {
        ASTBuilder.id: "login-page",
        title: None,
        transition: None,
        elements: [],
        position: Position.make(1, 0),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          expect(scene.id)->toBe("login-page")
          expect(scene.title)->toBe("Login Page")
        }
      | Error(_) => fail("Expected successful scene build")
      }
    })

    test("uses default transition when not provided", () => {
      let config = {
        ASTBuilder.id: "home",
        title: Some("Home"),
        transition: None,
        elements: [],
        position: Position.make(1, 0),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(scene) => {
          expect(scene.transition)->toBe("none")
        }
      | Error(_) => fail("Expected successful scene build")
      }
    })

    test("rejects empty scene ID", () => {
      let config = {
        ASTBuilder.id: "",
        title: Some("Empty ID"),
        transition: None,
        elements: [],
        position: Position.make(1, 0),
      }

      let result = ASTBuilder.buildScene(config)

      switch result {
      | Ok(_) => fail("Expected error for empty scene ID")
      | Error(ASTBuilder.EmptySceneId(_)) => pass
      | Error(_) => fail("Expected EmptySceneId error")
      }
    })
  })

  describe("buildAST", () => {
    test("builds AST with single scene", () => {
      let configs = [
        {
          ASTBuilder.id: "home",
          title: Some("Home"),
          transition: Some("fade"),
          elements: [],
          position: Position.make(1, 0),
        },
      ]

      let result = ASTBuilder.buildAST(configs)

      switch result {
      | Ok(ast) => {
          expect(Array.length(ast.scenes))->toBe(1)
        }
      | Error(_) => fail("Expected successful AST build")
      }
    })

    test("detects duplicate scene IDs", () => {
      let configs = [
        {
          ASTBuilder.id: "home",
          title: Some("Home"),
          transition: None,
          elements: [],
          position: Position.make(1, 0),
        },
        {
          ASTBuilder.id: "home",
          title: Some("Home Again"),
          transition: None,
          elements: [],
          position: Position.make(20, 0),
        },
      ]

      let result = ASTBuilder.buildAST(configs)

      switch result {
      | Ok(_) => fail("Expected error for duplicate scene IDs")
      | Error(errors) => {
          expect(Array.length(errors))->toBeGreaterThan(0)
        }
      }
    })
  })

  describe("helper functions", () => {
    let testAST = {
      Types.scenes: [
        {
          id: "home",
          title: "Home",
          transition: "none",
          elements: [],
        },
        {
          id: "about",
          title: "About",
          transition: "fade",
          elements: [],
        },
      ],
    }

    test("getSceneById finds existing scene", () => {
      let scene = ASTBuilder.getSceneById(testAST, "about")

      switch scene {
      | Some(s) => {
          expect(s.id)->toBe("about")
          expect(s.title)->toBe("About")
        }
      | None => fail("Expected to find scene")
      }
    })

    test("hasScene returns true for existing scene", () => {
      let exists = ASTBuilder.hasScene(testAST, "home")

      expect(exists)->toBe(true)
    })

    test("getSceneIds returns all scene IDs", () => {
      let ids = ASTBuilder.getSceneIds(testAST)

      expect(Array.length(ids))->toBe(2)
    })
  })
})
