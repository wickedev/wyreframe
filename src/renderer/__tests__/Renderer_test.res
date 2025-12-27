// Renderer_test.res
// Unit tests for Renderer module
//
// Tests for navigation helpers, callback types, and render options

open Vitest
open Types

describe("Renderer", () => {
  describe("isNavigationAction", () => {
    test("returns true for Goto action", t => {
      let action = Goto({
        target: "home",
        transition: "fade",
        condition: None,
      })
      t->expect(Renderer.isNavigationAction(action))->Expect.toBe(true)
    })

    test("returns true for Back action", t => {
      t->expect(Renderer.isNavigationAction(Back))->Expect.toBe(true)
    })

    test("returns true for Forward action", t => {
      t->expect(Renderer.isNavigationAction(Forward))->Expect.toBe(true)
    })

    test("returns false for Validate action", t => {
      let action = Validate({fields: ["email", "password"]})
      t->expect(Renderer.isNavigationAction(action))->Expect.toBe(false)
    })

    test("returns false for Call action", t => {
      let action = Call({
        function: "submitForm",
        args: ["data"],
        condition: None,
      })
      t->expect(Renderer.isNavigationAction(action))->Expect.toBe(false)
    })
  })

  describe("hasNavigationAction", () => {
    test("returns true when array contains Goto action", t => {
      let actions = [
        Goto({target: "dashboard", transition: "slide", condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })

    test("returns true when array contains Back action", t => {
      let actions = [Back]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })

    test("returns true when array contains Forward action", t => {
      let actions = [Forward]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })

    test("returns true when array has mixed actions with navigation", t => {
      let actions = [
        Validate({fields: ["email"]}),
        Goto({target: "success", transition: "fade", condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })

    test("returns false for empty array", t => {
      let actions: array<interactionAction> = []
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(false)
    })

    test("returns false when array contains only Validate action", t => {
      let actions = [Validate({fields: ["username", "password"]})]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(false)
    })

    test("returns false when array contains only Call action", t => {
      let actions = [
        Call({function: "submit", args: [], condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(false)
    })

    test("returns false when array has only non-navigation actions", t => {
      let actions = [
        Validate({fields: ["email"]}),
        Call({function: "trackEvent", args: ["click"], condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(false)
    })
  })

  describe("defaultOptions", () => {
    test("has theme set to None", t => {
      t->expect(Renderer.defaultOptions.theme)->Expect.toEqual(None)
    })

    test("has interactive set to true", t => {
      t->expect(Renderer.defaultOptions.interactive)->Expect.toBe(true)
    })

    test("has injectStyles set to true", t => {
      t->expect(Renderer.defaultOptions.injectStyles)->Expect.toBe(true)
    })

    test("has containerClass set to None", t => {
      t->expect(Renderer.defaultOptions.containerClass)->Expect.toEqual(None)
    })

    test("has onSceneChange set to None", t => {
      t->expect(Renderer.defaultOptions.onSceneChange)->Expect.toEqual(None)
    })

    test("has onDeadEndClick set to None", t => {
      t->expect(Renderer.defaultOptions.onDeadEndClick)->Expect.toEqual(None)
    })

    test("has device set to None", t => {
      t->expect(Renderer.defaultOptions.device)->Expect.toEqual(None)
    })
  })

  describe("deadEndClickInfo type", () => {
    test("can create info with button type", t => {
      let info: Renderer.deadEndClickInfo = {
        sceneId: "login",
        elementId: "submit-btn",
        elementText: "Submit",
        elementType: #button,
      }
      t->expect(info.sceneId)->Expect.toBe("login")
      t->expect(info.elementId)->Expect.toBe("submit-btn")
      t->expect(info.elementText)->Expect.toBe("Submit")
      t->expect(info.elementType)->Expect.toEqual(#button)
    })

    test("can create info with link type", t => {
      let info: Renderer.deadEndClickInfo = {
        sceneId: "home",
        elementId: "help-link",
        elementText: "Help",
        elementType: #link,
      }
      t->expect(info.sceneId)->Expect.toBe("home")
      t->expect(info.elementId)->Expect.toBe("help-link")
      t->expect(info.elementText)->Expect.toBe("Help")
      t->expect(info.elementType)->Expect.toEqual(#link)
    })
  })

  describe("renderOptions with onDeadEndClick", () => {
    test("can create options with custom onDeadEndClick callback", t => {
      let clickedInfo: ref<option<Renderer.deadEndClickInfo>> = ref(None)

      let options: Renderer.renderOptions = {
        ...Renderer.defaultOptions,
        onDeadEndClick: Some(info => {
          clickedInfo := Some(info)
        }),
      }

      // Verify callback is set
      t->expect(options.onDeadEndClick)->Expect.not->Expect.toEqual(None)

      // Simulate calling the callback
      switch options.onDeadEndClick {
      | Some(callback) =>
        callback({
          sceneId: "test-scene",
          elementId: "test-btn",
          elementText: "Test Button",
          elementType: #button,
        })
      | None => ()
      }

      // Verify callback was invoked with correct info
      switch clickedInfo.contents {
      | Some(info) => {
          t->expect(info.sceneId)->Expect.toBe("test-scene")
          t->expect(info.elementId)->Expect.toBe("test-btn")
          t->expect(info.elementText)->Expect.toBe("Test Button")
          t->expect(info.elementType)->Expect.toEqual(#button)
        }
      | None => t->expect(true)->Expect.toBe(false) // Callback should have been called
      }
    })

    test("can create options with both onSceneChange and onDeadEndClick", t => {
      let sceneChangeCalled = ref(false)
      let deadEndCalled = ref(false)

      let options: Renderer.renderOptions = {
        ...Renderer.defaultOptions,
        onSceneChange: Some((_from, _to) => {
          sceneChangeCalled := true
        }),
        onDeadEndClick: Some(_info => {
          deadEndCalled := true
        }),
      }

      // Verify both callbacks are set
      t->expect(options.onSceneChange)->Expect.not->Expect.toEqual(None)
      t->expect(options.onDeadEndClick)->Expect.not->Expect.toEqual(None)

      // Call scene change callback
      switch options.onSceneChange {
      | Some(callback) => callback(Some("login"), "dashboard")
      | None => ()
      }
      t->expect(sceneChangeCalled.contents)->Expect.toBe(true)

      // Call dead end callback
      switch options.onDeadEndClick {
      | Some(callback) =>
        callback({
          sceneId: "test",
          elementId: "btn",
          elementText: "Click",
          elementType: #button,
        })
      | None => ()
      }
      t->expect(deadEndCalled.contents)->Expect.toBe(true)
    })
  })

  describe("SemanticParser.isNoiseText - Issue #16: Empty lines should be preserved", () => {
    test("returns false for empty string (empty lines become Spacer elements)", t => {
      // Empty lines in wireframes should NOT be treated as noise
      // They represent intentional vertical spacing (Spacer elements)
      t->expect(SemanticParser.isNoiseText(""))->Expect.toBe(false)
    })

    test("returns false for whitespace-only string (empty lines become Spacer elements)", t => {
      // Lines with only spaces become Spacer elements
      t->expect(SemanticParser.isNoiseText("   "))->Expect.toBe(false)
    })

    test("returns true for box border patterns with pipes", t => {
      t->expect(SemanticParser.isNoiseText("|"))->Expect.toBe(true)
    })

    test("returns true for box border patterns with plus", t => {
      t->expect(SemanticParser.isNoiseText("+---+"))->Expect.toBe(true)
    })

    test("returns true for horizontal border", t => {
      t->expect(SemanticParser.isNoiseText("---"))->Expect.toBe(true)
    })

    test("returns false for actual text content", t => {
      t->expect(SemanticParser.isNoiseText("Hello World"))->Expect.toBe(false)
    })

    test("returns false for text with surrounding spaces", t => {
      t->expect(SemanticParser.isNoiseText("  Sarah Johnson  "))->Expect.toBe(false)
    })
  })

  describe("Issue #16: Empty lines should render as spacer elements", () => {
    let loginWireframe = `
+------------------------------------------+
|                                          |
|              'Welcome Back'              |
|                                          |
|         +----------------------------+   |
|         | #email                     |   |
|         +----------------------------+   |
|                                          |
|         +----------------------------+   |
|         | #password                  |   |
|         +----------------------------+   |
|                                          |
|              [ Sign In ]                 |
|                                          |
|                   ---                    |
|                                          |
|           [ Continue with Google ]       |
|                                          |
|           [ Continue with GitHub ]       |
|                                          |
|            "Forgot password?"            |
|                                          |
+------------------------------------------+
`

    test("parses wireframe and includes Spacer elements for empty lines", t => {
      let parseResult = Parser.parse(loginWireframe)

      switch parseResult {
      | Ok((ast, _warnings)) => {
          // Get first scene's elements
          switch ast.scenes->Array.get(0) {
          | Some(scene) => {
              // Count Spacer elements
              let spacerCount =
                scene.elements->Array.reduce(0, (acc, elem) => {
                  switch elem {
                  | Box({children}) =>
                    // Count Spacer elements inside the box
                    children->Array.reduce(acc, (count, child) => {
                      switch child {
                      | Spacer(_) => count + 1
                      | _ => count
                      }
                    })
                  | Spacer(_) => acc + 1
                  | _ => acc
                  }
                })

              // Log for debugging
              Console.log2("Spacer elements:", spacerCount)

              // The wireframe has multiple empty lines that should be preserved as Spacers
              // Expecting at least 5 empty lines between content elements
              t->expect(spacerCount >= 5)->Expect.toBe(true)
            }
          | None => t->expect(true)->Expect.toBe(false) // Should have at least one scene
          }
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // Parsing should succeed
      }
    })
  })

  describe("navigation action edge cases", () => {
    test("Goto with condition is still a navigation action", t => {
      let action = Goto({
        target: "admin",
        transition: "fade",
        condition: Some("isAdmin"),
      })
      t->expect(Renderer.isNavigationAction(action))->Expect.toBe(true)
    })

    test("Call with condition is not a navigation action", t => {
      let action = Call({
        function: "logout",
        args: [],
        condition: Some("isLoggedIn"),
      })
      t->expect(Renderer.isNavigationAction(action))->Expect.toBe(false)
    })

    test("multiple navigation actions in array returns true", t => {
      let actions = [
        Back,
        Forward,
        Goto({target: "home", transition: "slide", condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })

    test("single Back in array of non-navigation actions returns true", t => {
      let actions = [
        Validate({fields: ["form"]}),
        Call({function: "log", args: [], condition: None}),
        Back,
        Call({function: "track", args: [], condition: None}),
      ]
      t->expect(Renderer.hasNavigationAction(actions))->Expect.toBe(true)
    })
  })

  describe("Issue #23: Row button distribution with flexbox justify-content", () => {
    describe("getElementAlignment", () => {
      test("returns Some(align) for Button elements", t => {
        let button = Button({
          id: "test",
          text: "Test",
          position: {row: 1, col: 1},
          align: Center,
          actions: [],
        })
        t->expect(Renderer.getElementAlignment(button))->Expect.toEqual(Some(Center))
      })

      test("returns Some(align) for Link elements", t => {
        let link = Link({
          id: "test",
          text: "Test",
          position: {row: 1, col: 1},
          align: Right,
          actions: [],
        })
        t->expect(Renderer.getElementAlignment(link))->Expect.toEqual(Some(Right))
      })

      test("returns Some(align) for Text elements", t => {
        let text = Text({
          content: "Test",
          emphasis: false,
          position: {row: 1, col: 1},
          align: Left,
        })
        t->expect(Renderer.getElementAlignment(text))->Expect.toEqual(Some(Left))
      })

      test("returns None for Spacer elements", t => {
        let spacer = Spacer({position: {row: 1, col: 1}})
        t->expect(Renderer.getElementAlignment(spacer))->Expect.toEqual(None)
      })

      test("returns None for Divider elements", t => {
        let divider = Divider({position: {row: 1, col: 1}})
        t->expect(Renderer.getElementAlignment(divider))->Expect.toEqual(None)
      })
    })

    describe("hasDistributedChildren", () => {
      test("returns true for Left/Center/Right button pattern", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Left, actions: []}),
          Button({id: "b", text: "B", position: {row: 1, col: 10}, align: Center, actions: []}),
          Button({id: "c", text: "C", position: {row: 1, col: 20}, align: Right, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(true)
      })

      test("returns true for Left/Right pattern (2 different alignments)", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Left, actions: []}),
          Button({id: "b", text: "B", position: {row: 1, col: 20}, align: Right, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(true)
      })

      test("returns true for Left/Center pattern (2 different alignments)", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Left, actions: []}),
          Button({id: "b", text: "B", position: {row: 1, col: 10}, align: Center, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(true)
      })

      test("returns false for all Center-aligned buttons", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Center, actions: []}),
          Button({id: "b", text: "B", position: {row: 1, col: 10}, align: Center, actions: []}),
          Button({id: "c", text: "C", position: {row: 1, col: 20}, align: Center, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(false)
      })

      test("returns false for all Left-aligned buttons", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Left, actions: []}),
          Button({id: "b", text: "B", position: {row: 1, col: 10}, align: Left, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(false)
      })

      test("returns false for single element", t => {
        let children = [
          Button({id: "a", text: "A", position: {row: 1, col: 1}, align: Center, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(false)
      })

      test("returns false for empty array", t => {
        let children: array<element> = []
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(false)
      })

      test("works with mixed element types (Text and Link)", t => {
        let children = [
          Text({content: "Hello", emphasis: false, position: {row: 1, col: 1}, align: Left}),
          Link({id: "link", text: "Click", position: {row: 1, col: 20}, align: Right, actions: []}),
        ]
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(true)
      })

      test("ignores elements without alignment (Spacer)", t => {
        let children = [
          Spacer({position: {row: 1, col: 1}}),
          Button({id: "a", text: "A", position: {row: 1, col: 5}, align: Center, actions: []}),
        ]
        // Only one element with alignment, so not distributed
        t->expect(Renderer.hasDistributedChildren(children))->Expect.toBe(false)
      })
    })
  })

  describe("Issue #25: Social login buttons should use space-evenly distribution", () => {
    test("defaultStyles uses space-evenly for distributed rows", t => {
      // The .wf-row.wf-distribute class should use space-evenly for equal spacing
      // between buttons and at both ends, not space-between which pushes to edges
      let hasSpaceEvenly = Renderer.defaultStyles->String.includes("space-evenly")
      t->expect(hasSpaceEvenly)->Expect.toBe(true)
    })

    test("defaultStyles does not use space-between for distributed rows", t => {
      // space-between creates uneven visual spacing with buttons at edges
      // space-evenly creates equal spacing everywhere for better aesthetics
      let distributeRule = ".wf-row.wf-distribute { justify-content:space-between"
      let hasSpaceBetween = Renderer.defaultStyles->String.includes(distributeRule)
      t->expect(hasSpaceBetween)->Expect.toBe(false)
    })
  })
})
