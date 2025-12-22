/**
 * InteractionMerger_test.res
 *
 * Unit tests for the InteractionMerger module.
 * Tests validation, error detection, and successful merging of interactions.
 */

open Vitest
open Types
open InteractionMerger

describe("InteractionMerger", t => {
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
    device: Desktop,
    elements: [
      Button({
        id: "submit-btn",
        text: "Submit",
        position: makePosition(5, 10),
        align: Center,
        actions: [],
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
    device: Desktop,
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
            actions: [],
          }),
          Section({
            name: "settings",
            children: [
              Link({
                id: "settings-link",
                text: "Settings",
                position: makePosition(4, 5),
                align: Left,
                actions: [],
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
          properties: Dict.fromArray([("required", JSON.Encode.bool(true))]),
          actions: [],
        },
      ],
    },
  ]

  // ============================================================================
  // Element ID Collection Tests
  // ============================================================================

  describe("collectElementIds", t => {
    test("collects ID from Button element", t => {
      let button = Button({
        id: "test-btn",
        text: "Test",
        position: makePosition(0, 0),
        align: Left,
        actions: [],
      })

      let ids = collectElementIds(button)

      t->expect(ids->Belt.Set.String.has("test-btn"))->Expect.toBe(true)
    })

    test("collects ID from Input element", t => {
      let input = Input({
        id: "test-input",
        placeholder: None,
        position: makePosition(0, 0),
      })

      let ids = collectElementIds(input)

      t->expect(ids->Belt.Set.String.has("test-input"))->Expect.toBe(true)
    })

    test("collects ID from Link element", t => {
      let link = Link({
        id: "test-link",
        text: "Test Link",
        position: makePosition(0, 0),
        align: Left,
        actions: [],
      })

      let ids = collectElementIds(link)

      t->expect(ids->Belt.Set.String.has("test-link"))->Expect.toBe(true)
    })

    test("collects name from Section element", t => {
      let section = Section({
        name: "test-section",
        children: [],
      })

      let ids = collectElementIds(section)

      t->expect(ids->Belt.Set.String.has("test-section"))->Expect.toBe(true)
    })

    test("returns empty set for elements without IDs", t => {
      let checkbox = Checkbox({
        checked: true,
        label: "Test",
        position: makePosition(0, 0),
      })

      let ids = collectElementIds(checkbox)

      t->expect(ids->Belt.Set.String.size)->Expect.toBe(0)
    })

    test("recursively collects IDs from Box children", t => {
      let box = Box({
        name: Some("Container"),
        bounds: makeBounds(0, 0, 10, 10),
        children: [
          Button({
            id: "btn1",
            text: "Button 1",
            position: makePosition(2, 2),
            align: Left,
            actions: [],
          }),
          Button({
            id: "btn2",
            text: "Button 2",
            position: makePosition(4, 2),
            align: Left,
            actions: [],
          }),
        ],
      })

      let ids = collectElementIds(box)

      t->expect(ids->Belt.Set.String.has("btn1"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("btn2"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.size)->Expect.toBe(2)
    })

    test("recursively collects IDs from nested Boxes", t => {
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

      t->expect(ids->Belt.Set.String.has("nested-input"))->Expect.toBe(true)
    })

    test("collects IDs from Row children", t => {
      let row = Row({
        children: [
          Button({
            id: "row-btn1",
            text: "Button 1",
            position: makePosition(0, 0),
            align: Left,
            actions: [],
          }),
          Button({
            id: "row-btn2",
            text: "Button 2",
            position: makePosition(0, 10),
            align: Left,
            actions: [],
          }),
        ],
        align: Center,
      })

      let ids = collectElementIds(row)

      t->expect(ids->Belt.Set.String.has("row-btn1"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("row-btn2"))->Expect.toBe(true)
    })

    test("collects IDs from Section and its children", t => {
      let section = Section({
        name: "my-section",
        children: [
          Link({
            id: "section-link",
            text: "Link",
            position: makePosition(0, 0),
            align: Left,
            actions: [],
          }),
        ],
      })

      let ids = collectElementIds(section)

      t->expect(ids->Belt.Set.String.has("my-section"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("section-link"))->Expect.toBe(true)
    })
  })

  describe("collectSceneElementIds", t => {
    test("collects all element IDs from scene", t => {
      let ids = collectSceneElementIds(simpleScene)

      t->expect(ids->Belt.Set.String.has("submit-btn"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("email"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.size)->Expect.toBe(2)
    })

    test("collects IDs from nested elements in scene", t => {
      let ids = collectSceneElementIds(nestedScene)

      t->expect(ids->Belt.Set.String.has("action-btn"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("settings"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.has("settings-link"))->Expect.toBe(true)
      t->expect(ids->Belt.Set.String.size)->Expect.toBe(3)
    })
  })

  describe("buildSceneElementMap", t => {
    test("builds map of scene IDs to element IDs", t => {
      let ast: ast = {
        scenes: [simpleScene, nestedScene],
      }

      let sceneMap = buildSceneElementMap(ast)

      t->expect(sceneMap->Belt.Map.String.size)->Expect.toBe(2)

      let loginIds = sceneMap->Belt.Map.String.get("login")
      t->expect(loginIds->Option.isSome)->Expect.toBe(true)
      loginIds->Option.forEach(ids => {
        t->expect(ids->Belt.Set.String.has("submit-btn"))->Expect.toBe(true)
        t->expect(ids->Belt.Set.String.has("email"))->Expect.toBe(true)
      })

      let dashboardIds = sceneMap->Belt.Map.String.get("dashboard")
      t->expect(dashboardIds->Option.isSome)->Expect.toBe(true)
      dashboardIds->Option.forEach(ids => {
        t->expect(ids->Belt.Set.String.has("action-btn"))->Expect.toBe(true)
        t->expect(ids->Belt.Set.String.has("settings-link"))->Expect.toBe(true)
      })
    })
  })

  // ============================================================================
  // Validation Tests
  // ============================================================================

  describe("validateInteractions", t => {
    test("returns no errors for valid interactions", t => {
      let ast: ast = {scenes: [simpleScene]}
      let sceneMap = buildSceneElementMap(ast)

      let errors = validateInteractions(validInteractions, sceneMap)

      t->expect(errors->Array.length)->Expect.toBe(0)
    })

    test("detects missing element", t => {
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

      t->expect(errors->Array.length)->Expect.toBe(1)
      switch errors[0] {
      | Some(ElementNotFound({elementId})) => t->expect(elementId)->Expect.toBe("nonexistent-btn")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected ElementNotFound error
      }
    })

    test("detects missing scene", t => {
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

      t->expect(errors->Array.length)->Expect.toBe(1)
      switch errors[0] {
      | Some(SceneNotFound({sceneId})) => t->expect(sceneId)->Expect.toBe("nonexistent-scene")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected SceneNotFound error
      }
    })

    test("detects duplicate interaction for same element", t => {
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

      t->expect(errors->Array.length)->Expect.toBe(1)
      switch errors[0] {
      | Some(DuplicateInteraction({elementId})) => t->expect(elementId)->Expect.toBe("submit-btn")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected DuplicateInteraction error
      }
    })

    test("reports multiple errors", t => {
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

      t->expect(errors->Array.length)->Expect.toBe(2)
    })
  })

  // ============================================================================
  // Merge Function Tests
  // ============================================================================

  describe("mergeInteractions", t => {
    test("successfully merges valid interactions", t => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, validInteractions)

      t->expect(result->Result.isOk)->Expect.toBe(true)
      result->Result.forEach(mergedAst => {
        t->expect(mergedAst.scenes->Array.length)->Expect.toBe(1)
      })
    })

    test("returns error for invalid interactions (hard errors)", t => {
      let ast: ast = {scenes: [simpleScene]}

      // SceneNotFound is a hard error (unlike ElementNotFound which is soft)
      let invalidInteractions = [
        {
          sceneId: "nonexistent-scene", // This scene doesn't exist
          interactions: [
            {
              elementId: "some-btn",
              properties: Js.Dict.empty(),
              actions: [],
            },
          ],
        },
      ]

      let result = mergeInteractions(ast, invalidInteractions)

      t->expect(result->Result.isError)->Expect.toBe(true)
      switch result {
      | Error(errors) => t->expect(errors->Array.length)->Expect.Int.toBeGreaterThan(0)
      | Ok(_) => t->expect(true)->Expect.toBe(false) // fail: Expected error result
      }
    })

    test("preserves scene structure after merge", t => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, validInteractions)

      result->Result.forEach(mergedAst => {
        t->expect(mergedAst.scenes[0]->Option.map(s => s.id))->Expect.toEqual(Some("login"))
        t->expect(mergedAst.scenes[0]->Option.map(s => s.title))->Expect.toEqual(Some("Login"))
        t->expect(mergedAst.scenes[0]->Option.map(s => s.elements->Array.length))->Expect.toEqual(Some(2))
      })
    })

    test("handles multiple scenes with interactions", t => {
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

      t->expect(result->Result.isOk)->Expect.toBe(true)
      result->Result.forEach(mergedAst => {
        t->expect(mergedAst.scenes->Array.length)->Expect.toBe(2)
      })
    })

    test("merges empty interactions successfully", t => {
      let ast: ast = {scenes: [simpleScene]}

      let result = mergeInteractions(ast, [])

      t->expect(result->Result.isOk)->Expect.toBe(true)
    })
  })

  // ============================================================================
  // Error Formatting Tests
  // ============================================================================

  describe("formatError", t => {
    test("formats ElementNotFound error", t => {
      let error = ElementNotFound({
        sceneId: "login",
        elementId: "missing-btn",
        position: None,
      })

      let message = formatError(error)

      t->expect(message)->Expect.String.toContain("missing-btn")
      t->expect(message)->Expect.String.toContain("login")
    })

    test("formats DuplicateInteraction error", t => {
      let error = DuplicateInteraction({
        sceneId: "login",
        elementId: "duplicate-btn",
      })

      let message = formatError(error)

      t->expect(message)->Expect.String.toContain("duplicate-btn")
      t->expect(message)->Expect.String.toContain("Duplicate")
    })

    test("formats SceneNotFound error", t => {
      let error = SceneNotFound({sceneId: "missing-scene"})

      let message = formatError(error)

      t->expect(message)->Expect.String.toContain("missing-scene")
      t->expect(message)->Expect.String.toContain("not found")
    })
  })

  describe("formatErrors", t => {
    test("formats multiple errors with newlines", t => {
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

      t->expect(message)->Expect.String.toContain("btn1")
      t->expect(message)->Expect.String.toContain("btn2")
      t->expect(message)->Expect.String.toContain("\n")
    })
  })

  // ============================================================================
  // findInteractionForElement Tests
  // ============================================================================

  describe("findInteractionForElement", t => {
    test("finds interaction for element", t => {
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

      t->expect(result->Option.isSome)->Expect.toBe(true)
    })

    test("returns None when element not found", t => {
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

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })

    test("returns None when no scene interactions", t => {
      let result = findInteractionForElement("test-btn", None)

      t->expect(result->Option.isNone)->Expect.toBe(true)
    })
  })
})
