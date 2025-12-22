/**
 * InteractionMerger_test.res
 *
 * Unit tests for the InteractionMerger module.
 * Tests validation, error detection, and successful merging of interactions.
 */

open Jest
open Expect
open Types
open InteractionMerger

describe("InteractionMerger", () => {
  // ============================================================================
  // Test Fixtures
  // ============================================================================

  let makePosition = (row, col) => Position.make(row, col)
  let makeBounds = (top, left, bottom, right) => Bounds.make(~top, ~left, ~bottom, ~right)

  // Simple scene with button and input
  let simpleScene: scene = {
    id: "login",
    title: "Login",
    transition: "fade",
    elements: [
      Button({
        id: "submit-btn",
        text: "Submit",
        position: makePosition(5, 10),
        align: Center,
      }),
      Input({
        id: "email",
        placeholder: Some("Email"),
        position: makePosition(3, 10),
      }),
    ],
  }

  // Scene with nested boxes
  let nestedScene: scene = {
    id: "dashboard",
    title: "Dashboard",
    transition: "slide",
    elements: [
      Box({
        name: Some("Container"),
        bounds: makeBounds(0, 0, 10, 20),
        children: [
          Button({
            id: "action-btn",
            text: "Action",
            position: makePosition(2, 5),
            align: Left,
          }),
          Section({
            name: "settings",
            children: [
              Link({
                id: "settings-link",
                text: "Settings",
                position: makePosition(4, 5),
                align: Left,
              }),
            ],
          }),
        ],
      }),
    ],
  }

  // Valid interactions for simple scene
  let validInteractions: array<sceneInteractions> = [
    {
      sceneId: "login",
      interactions: [
        {
          elementId: "submit-btn",
          properties: Js.Dict.fromArray([("variant", Js.Json.string("primary"))]),
          actions: [
            Goto({
              target: "dashboard",
              transition: "slide",
              condition: None,
            }),
          ],
        },
        {
          elementId: "email",
          properties: Js.Dict.fromArray([("required", Js.Json.bool(true))]),
          actions: [],
        },
      ],
    },
  ]

  // ============================================================================
  // Element ID Collection Tests
  // ============================================================================

  describe("collectElementIds", () => {
    test("collects ID from Button element", () => {
      let button = Button({
        id: "test-btn",
        text: "Test",
        position: makePosition(0, 0),
        align: Left,
      })

      let ids = collectElementIds(button)

      expect(ids->Belt.Set.String.has("test-btn"))->toBe(true)
    })

    test("collects ID from Input element", () => {
      let input = Input({
        id: "test-input",
        placeholder: None,
        position: makePosition(0, 0),
      })

      let ids = collectElementIds(input)

      expect(ids->Belt.Set.String.has("test-input"))->toBe(true)
    })

    test("collects ID from Link element", () => {
      let link = Link({
        id: "test-link",
        text: "Test Link",
        position: makePosition(0, 0),
        align: Left,
      })

      let ids = collectElementIds(link)

      expect(ids->Belt.Set.String.has("test-link"))->toBe(true)
    })

    test("collects name from Section element", () => {
      let section = Section({
        name: "test-section",
        children: [],
      })

      let ids = collectElementIds(section)

      expect(ids->Belt.Set.String.has("test-section"))->toBe(true)
    })

    test("returns empty set for elements without IDs", () => {
      let checkbox = Checkbox({
        checked: true,
        label: "Test",
        position: makePosition(0, 0),
      })

      let ids = collectElementIds(checkbox)

      expect(ids->Belt.Set.String.size)->toBe(0)
    })

    test("recursively collects IDs from Box children", () => {
      let box = Box({
        name: Some("Container"),
        bounds: makeBounds(0, 0, 10, 10),
        children: [
          Button({
            id: "btn1",
            text: "Button 1",
            position: makePosition(2, 2),
            align: Left,
          }),
          Button({
            id: "btn2",
            text: "Button 2",
            position: makePosition(4, 2),
            align: Left,
          }),
        ],
      })

      let ids = collectElementIds(box)

      expect(ids->Belt.Set.String.has("btn1"))->toBe(true)
      expect(ids->Belt.Set.String.has("btn2"))->toBe(true)
      expect(ids->Belt.Set.String.size)->toBe(2)
    })

    test("recursively collects IDs from nested Boxes", () => {
      let box = Box({
        name: Some("Outer"),
        bounds: makeBounds(0, 0, 20, 20),
        children: [
          Box({
            name: Some("Inner"),
            bounds: makeBounds(2, 2, 18, 18),
            children: [
              Input({
                id: "nested-input",
                placeholder: None,
                position: makePosition(5, 5),
              }),
            ],
          }),
        ],
      })

      let ids = collectElementIds(box)

      expect(ids->Belt.Set.String.has("nested-input"))->toBe(true)
    })

    test("collects IDs from Row children", () => {
      let row = Row({
        children: [
          Button({
            id: "row-btn1",
            text: "Button 1",
            position: makePosition(0, 0),
            align: Left,
          }),
          Button({
            id: "row-btn2",
            text: "Button 2",
            position: makePosition(0, 10),
            align: Left,
          }),
        ],
        align: Center,
      })

      let ids = collectElementIds(row)

      expect(ids->Belt.Set.String.has("row-btn1"))->toBe(true)
      expect(ids->Belt.Set.String.has("row-btn2"))->toBe(true)
    })

    test("collects IDs from Section and its children", () => {
      let section = Section({
        name: "my-section",
        children: [
          Link({
            id: "section-link",
            text: "Link",
            position: makePosition(0, 0),
            align: Left,
          }),
        ],
      })

      let ids = collectElementIds(section)

      expect(ids->Belt.Set.String.has("my-section"))->toBe(true)
      expect(ids->Belt.Set.String.has("section-link"))->toBe(true)
    })
  })

  describe("collectSceneElementIds", () => {
    test("collects all element IDs from scene", () => {
      let ids = collectSceneElementIds(simpleScene)

      expect(ids->Belt.Set.String.has("submit-btn"))->toBe(true)
      expect(ids->Belt.Set.String.has("email"))->toBe(true)
      expect(ids->Belt.Set.String.size)->toBe(2)
    })

    test("collects IDs from nested elements in scene", () => {
      let ids = collectSceneElementIds(nestedScene)

      expect(ids->Belt.Set.String.has("action-btn"))->toBe(true)
      expect(ids->Belt.Set.String.has("settings"))->toBe(true)
      expect(ids->Belt.Set.String.has("settings-link"))->toBe(true)
      expect(ids->Belt.Set.String.size)->toBe(3)
    })
  })

  describe("buildSceneElementMap", () => {
    test("builds map of scene IDs to element IDs", () => {
      let ast: ast = {
        scenes: [simpleScene, nestedScene],
      }

      let sceneMap = buildSceneElementMap(ast)

      expect(sceneMap->Belt.Map.String.size)->toBe(2)

      let loginIds = sceneMap->Belt.Map.String.get("login")
      expect(loginIds->Option.isSome)->toBe(true)
      loginIds->Option.forEach(ids => {
        expect(ids->Belt.Set.String.has("submit-btn"))->toBe(true)
        expect(ids->Belt.Set.String.has("email"))->toBe(true)
      })

      let dashboardIds = sceneMap->Belt.Map.String.get("dashboard")
      expect(dashboardIds->Option.isSome)->toBe(true)
      dashboardIds->Option.forEach(ids => {
        expect(ids->Belt.Set.String.has("action-btn"))->toBe(true)
        expect(ids->Belt.Set.String.has("settings-link"))->toBe(true)
      })
    })
  })

  // ============================================================================
  // Validation Tests
  // ============================================================================

  describe("validateInteractions", () => {
    test("returns no errors for valid interactions", () => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let errors = validateInteractions(validInteractions, sceneMap)

      expect(errors->Array.length)->toBe(0)
    })

    test("detects missing element", () => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let invalidInteractions = [
        {
          sceneId: "login",
          interactions: [
            {
              elementId: "nonexistent-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let errors = validateInteractions(invalidInteractions, sceneMap)

      expect(errors->Array.length)->toBe(1)
      switch errors[0] {
      | Some(ElementNotFound({elementId})) => expect(elementId)->toBe("nonexistent-btn")
      | _ => fail("Expected ElementNotFound error")
      }
    })

    test("detects missing scene", () => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let invalidInteractions = [
        {
          sceneId: "nonexistent-scene",
          interactions: [
            {
              elementId: "some-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let errors = validateInteractions(invalidInteractions, sceneMap)

      expect(errors->Array.length)->toBe(1)
      switch errors[0] {
      | Some(SceneNotFound({sceneId})) => expect(sceneId)->toBe("nonexistent-scene")
      | _ => fail("Expected SceneNotFound error")
      }
    })

    test("detects duplicate interaction for same element", () => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let duplicateInteractions = [
        {
          sceneId: "login",
          interactions: [
            {
              elementId: "submit-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
            {
              elementId: "submit-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let errors = validateInteractions(duplicateInteractions, sceneMap)

      expect(errors->Array.length)->toBe(1)
      switch errors[0] {
      | Some(DuplicateInteraction({elementId})) => expect(elementId)->toBe("submit-btn")
      | _ => fail("Expected DuplicateInteraction error")
      }
    })

    test("reports multiple errors", () => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let multiErrorInteractions = [
        {
          sceneId: "login",
          interactions: [
            {
              elementId: "nonexistent1",
              properties: Js.Dict.empty(),
              actions: [],
            },
            {
              elementId: "nonexistent2",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let errors = validateInteractions(multiErrorInteractions, sceneMap)

      expect(errors->Array.length)->toBe(2)
    })
  })

  // ============================================================================
  // Merge Function Tests
  // ============================================================================

  describe("mergeInteractions", () => {
    test("successfully merges valid interactions", () => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, validInteractions)

      expect(result->Result.isOk)->toBe(true)
      result->Result.forEach(mergedAst => {
        expect(mergedAst.scenes->Array.length)->toBe(1)
      })
    })

    test("returns error for invalid interactions", () => {
      let ast: ast = {scenes: [simpleScene]}

      let invalidInteractions = [
        {
          sceneId: "login",
          interactions: [
            {
              elementId: "nonexistent-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let result = mergeInteractions(ast, invalidInteractions)

      expect(result->Result.isError)->toBe(true)
      result->Result.getError->Option.forEach(errors => {
        expect(errors->Array.length)->toBeGreaterThan(0)
      })
    })

    test("preserves scene structure after merge", () => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, validInteractions)

      result->Result.forEach(mergedAst => {
        expect(mergedAst.scenes[0]->Option.map(s => s.id))->toEqual(Some("login"))
        expect(mergedAst.scenes[0]->Option.map(s => s.title))->toEqual(Some("Login"))
        expect(mergedAst.scenes[0]->Option.map(s => s.elements->Array.length))->toEqual(Some(2))
      })
    })

    test("handles multiple scenes with interactions", () => {
      let ast: ast = {scenes: [simpleScene, nestedScene]}

      let multiSceneInteractions = [
        {
          sceneId: "login",
          interactions: [
            {
              elementId: "submit-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
        {
          sceneId: "dashboard",
          interactions: [
            {
              elementId: "action-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let result = mergeInteractions(ast, multiSceneInteractions)

      expect(result->Result.isOk)->toBe(true)
      result->Result.forEach(mergedAst => {
        expect(mergedAst.scenes->Array.length)->toBe(2)
      })
    })

    test("merges empty interactions successfully", () => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, [])

      expect(result->Result.isOk)->toBe(true)
    })
  })

  // ============================================================================
  // Error Formatting Tests
  // ============================================================================

  describe("formatError", () => {
    test("formats ElementNotFound error", () => {
      let error = ElementNotFound({
        sceneId: "login",
        elementId: "missing-btn",
        position: None,
      })

      let message = formatError(error)

      expect(message)->toContain("missing-btn")
      expect(message)->toContain("login")
    })

    test("formats DuplicateInteraction error", () => {
      let error = DuplicateInteraction({
        sceneId: "login",
        elementId: "duplicate-btn",
      })

      let message = formatError(error)

      expect(message)->toContain("duplicate-btn")
      expect(message)->toContain("Duplicate")
    })

    test("formats SceneNotFound error", () => {
      let error = SceneNotFound({sceneId: "missing-scene"})

      let message = formatError(error)

      expect(message)->toContain("missing-scene")
      expect(message)->toContain("not found")
    })
  })

  describe("formatErrors", () => {
    test("formats multiple errors with newlines", () => {
      let errors = [
        ElementNotFound({
          sceneId: "login",
          elementId: "btn1",
          position: None,
        }),
        ElementNotFound({
          sceneId: "login",
          elementId: "btn2",
          position: None,
        }),
      ]

      let message = formatErrors(errors)

      expect(message)->toContain("btn1")
      expect(message)->toContain("btn2")
      expect(message)->toContain("\n")
    })
  })

  // ============================================================================
  // findInteractionForElement Tests
  // ============================================================================

  describe("findInteractionForElement", () => {
    test("finds interaction for element", () => {
      let sceneInteractions = Some({
        sceneId: "login",
        interactions: [
          {
            elementId: "test-btn",
            properties: Js.Dict.empty(),
            actions: [],
          },
        ],
      })

      let result = findInteractionForElement("test-btn", sceneInteractions)

      expect(result->Option.isSome)->toBe(true)
    })

    test("returns None when element not found", () => {
      let sceneInteractions = Some({
        sceneId: "login",
        interactions: [
          {
            elementId: "test-btn",
            properties: Js.Dict.empty(),
            actions: [],
          },
        ],
      })

      let result = findInteractionForElement("other-btn", sceneInteractions)

      expect(result->Option.isNone)->toBe(true)
    })

    test("returns None when no scene interactions", () => {
      let result = findInteractionForElement("test-btn", None)

      expect(result->Option.isNone)->toBe(true)
    })
  })
})
