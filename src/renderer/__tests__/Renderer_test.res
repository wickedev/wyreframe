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

  describe("isNoiseText - Issue #16: Empty lines should be preserved", () => {
    test("returns false for empty string (empty lines should be preserved)", t => {
      // Empty lines in wireframes should NOT be treated as noise
      // They represent intentional vertical spacing
      t->expect(Renderer.isNoiseText(""))->Expect.toBe(false)
    })

    test("returns false for whitespace-only string (empty lines should be preserved)", t => {
      // Lines with only spaces should be preserved as spacing
      t->expect(Renderer.isNoiseText("   "))->Expect.toBe(false)
    })

    test("returns true for box border patterns with pipes", t => {
      t->expect(Renderer.isNoiseText("|"))->Expect.toBe(true)
    })

    test("returns true for box border patterns with plus", t => {
      t->expect(Renderer.isNoiseText("+---+"))->Expect.toBe(true)
    })

    test("returns true for horizontal border", t => {
      t->expect(Renderer.isNoiseText("---"))->Expect.toBe(true)
    })

    test("returns false for actual text content", t => {
      t->expect(Renderer.isNoiseText("Hello World"))->Expect.toBe(false)
    })

    test("returns false for text with surrounding spaces", t => {
      t->expect(Renderer.isNoiseText("  Sarah Johnson  "))->Expect.toBe(false)
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

    test("parses wireframe and includes spacer elements for empty lines", t => {
      let parseResult = Parser.parse(loginWireframe)

      switch parseResult {
      | Ok((ast, _warnings)) => {
          // Get first scene's elements
          switch ast.scenes->Array.get(0) {
          | Some(scene) => {
              // Count all Text elements and empty text elements
              let (totalTextCount, spacerCount) =
                scene.elements->Array.reduce((0, 0), ((totalAcc, spacerAcc), elem) => {
                  switch elem {
                  | Box({children}) =>
                    // Count text elements inside the box
                    children->Array.reduce((totalAcc, spacerAcc), ((tAcc, sAcc), child) => {
                      switch child {
                      | Text({content}) => {
                          let isSpacer = content->String.trim == ""
                          (tAcc + 1, isSpacer ? sAcc + 1 : sAcc)
                        }
                      | _ => (tAcc, sAcc)
                      }
                    })
                  | Text({content}) => {
                      let isSpacer = content->String.trim == ""
                      (totalAcc + 1, isSpacer ? spacerAcc + 1 : spacerAcc)
                    }
                  | _ => (totalAcc, spacerAcc)
                  }
                })

              // Log for debugging
              Console.log2("Total Text elements:", totalTextCount)
              Console.log2("Spacer (empty) elements:", spacerCount)

              // The wireframe has multiple empty lines that should be preserved as spacers
              // Expecting at least 5 empty lines between content elements
              t->expect(spacerCount >= 5)->Expect.toBe(true)
            }
          | None => t->expect(true)->Expect.toBe(false) // Should have at least one scene
          }
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // Parsing should succeed
      }
    })

    // Note: renderElement tests require DOM environment (jsdom)
    // These tests verify the logic using isNoiseText which is the filtering function
    test("isNoiseText returns false for empty content (spacers should not be filtered)", t => {
      // Empty content should NOT be considered noise
      t->expect(Renderer.isNoiseText(""))->Expect.toBe(false)
    })

    test("isNoiseText returns false for whitespace content (spacers should not be filtered)", t => {
      // Whitespace-only content should NOT be considered noise
      t->expect(Renderer.isNoiseText("   "))->Expect.toBe(false)
    })

    test("empty Text elements are preserved in rendering logic", t => {
      // Verify the isNoiseText check used in renderElement would preserve empty lines
      let emptyContent = ""
      let whitespaceContent = "   "

      // Both should return false (NOT noise = should be rendered)
      let emptyIsPreserved = !Renderer.isNoiseText(emptyContent)
      let whitespaceIsPreserved = !Renderer.isNoiseText(whitespaceContent)

      t->expect(emptyIsPreserved && whitespaceIsPreserved)->Expect.toBe(true)
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
})
