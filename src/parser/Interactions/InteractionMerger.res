/**
 * InteractionMerger.res
 *
 * Merges interaction definitions with wireframe AST elements.
 * Validates that all element IDs referenced in interactions exist in the AST.
 * Attaches properties and actions to the appropriate elements.
 *
 * Requirements: REQ-20 (Integration - Backward Compatibility)
 */

open Types

// ============================================================================
// Error Types
// ============================================================================

/**
 * Errors that can occur during interaction merging
 */
type mergeError =
  | ElementNotFound({
      sceneId: string,
      elementId: string,
      position: option<string>, // Optional position info from interaction
    })
  | DuplicateInteraction({
      sceneId: string,
      elementId: string,
    })
  | SceneNotFound({sceneId: string})

/**
 * Result type for merge operation
 */
type mergeResult = result<ast, array<mergeError>>

// ============================================================================
// Element ID Collection
// ============================================================================

/**
 * Recursively collect all element IDs from an element and its children.
 * Returns a set of element IDs found in the element tree.
 *
 * @param element - The element to collect IDs from
 * @returns Set of element IDs
 */
let rec collectElementIds = (element: element): Belt.Set.String.t => {
  let ids = Belt.Set.String.empty

  switch element {
  | Box({children}) => {
      // Recursively collect IDs from all children
      children->Array.reduce(ids, (acc, child) => {
        Belt.Set.String.union(acc, collectElementIds(child))
      })
    }
  | Button({id}) => ids->Belt.Set.String.add(id)
  | Input({id}) => ids->Belt.Set.String.add(id)
  | Link({id}) => ids->Belt.Set.String.add(id)
  | Checkbox(_) => ids // Checkboxes don't have explicit IDs
  | Text(_) => ids // Text elements don't have explicit IDs
  | Divider(_) => ids // Dividers don't have IDs
  | Row({children}) => {
      children->Array.reduce(ids, (acc, child) => {
        Belt.Set.String.union(acc, collectElementIds(child))
      })
    }
  | Section({children, name}) => {
      // Add section name as ID
      let withSection = ids->Belt.Set.String.add(name)
      children->Array.reduce(withSection, (acc, child) => {
        Belt.Set.String.union(acc, collectElementIds(child))
      })
    }
  }
}

/**
 * Collect all element IDs from a scene's elements.
 *
 * @param scene - The scene to collect IDs from
 * @returns Set of element IDs in the scene
 */
let collectSceneElementIds = (scene: scene): Belt.Set.String.t => {
  scene.elements->Array.reduce(Belt.Set.String.empty, (acc, element) => {
    Belt.Set.String.union(acc, collectElementIds(element))
  })
}

/**
 * Build a map of scene IDs to their element ID sets.
 *
 * @param ast - The AST to analyze
 * @returns Map of sceneId -> Set of element IDs
 */
let buildSceneElementMap = (ast: ast): Belt.Map.String.t<Belt.Set.String.t> => {
  ast.scenes->Array.reduce(Belt.Map.String.empty, (acc, scene) => {
    let elementIds = collectSceneElementIds(scene)
    acc->Belt.Map.String.set(scene.id, elementIds)
  })
}

// ============================================================================
// Interaction Validation
// ============================================================================

/**
 * Validate that all element IDs in interactions exist in the AST.
 *
 * @param sceneInteractions - Interactions to validate
 * @param sceneElementMap - Map of scene IDs to element IDs
 * @returns Array of validation errors (empty if all valid)
 */
let validateInteractions = (
  sceneInteractionsList: array<sceneInteractions>,
  sceneElementMap: Belt.Map.String.t<Belt.Set.String.t>,
): array<mergeError> => {
  let errors = []

  sceneInteractionsList->Array.forEach(sceneInteractions => {
    let sceneId = sceneInteractions.sceneId

    // Check if scene exists
    switch sceneElementMap->Belt.Map.String.get(sceneId) {
    | None => {
        errors->Array.push(SceneNotFound({sceneId: sceneId}))->ignore
      }
    | Some(elementIds) => {
        // Track seen element IDs to detect duplicates
        let seenElements = ref(Belt.Set.String.empty)

        // Validate each interaction
        sceneInteractions.interactions->Array.forEach(interaction => {
          let elementId = interaction.elementId

          // Check for duplicate interaction
          if seenElements.contents->Belt.Set.String.has(elementId) {
            errors
            ->Array.push(
              DuplicateInteraction({
                sceneId: sceneId,
                elementId: elementId,
              }),
            )
            ->ignore
          } else {
            seenElements := seenElements.contents->Belt.Set.String.add(elementId)
          }

          // Check if element exists in scene
          if !(elementIds->Belt.Set.String.has(elementId)) {
            errors
            ->Array.push(
              ElementNotFound({
                sceneId: sceneId,
                elementId: elementId,
                position: None,
              }),
            )
            ->ignore
          }
        })
      }
    }
  })

  errors
}

// ============================================================================
// Element Enhancement
// ============================================================================

/**
 * Enhanced element type that includes interaction data.
 * This is used internally during merging but converted back to
 * the standard element type for the final AST.
 */
type elementWithInteraction = {
  element: element,
  interaction: option<interaction>,
}

/**
 * Find interaction for a given element ID in a scene's interactions.
 *
 * @param elementId - The element ID to find interaction for
 * @param sceneInteractions - Scene interactions to search
 * @returns Option containing the interaction if found
 */
let findInteractionForElement = (
  elementId: string,
  sceneInteractions: option<sceneInteractions>,
): option<interaction> => {
  switch sceneInteractions {
  | None => None
  | Some(si) => {
      si.interactions->Array.find(interaction => interaction.elementId === elementId)
    }
  }
}

/**
 * Helper to check if an interaction has type: "input" property.
 */
let hasInputType = (interaction: option<interaction>): bool => {
  switch interaction {
  | Some({properties}) => {
      switch properties->Js.Dict.get("type") {
      | Some(json) => {
          switch Js.Json.decodeString(json) {
          | Some(str) => str === "input"
          | None => false
          }
        }
      | None => false
      }
    }
  | None => false
  }
}

/**
 * Recursively attach interactions to elements.
 * This creates a new element tree with interaction data attached.
 *
 * Key feature: If an element has type: "input" in its interaction properties,
 * parent Box elements containing only that Input will be unwrapped to render
 * as the Input directly.
 *
 * @param element - The element to process
 * @param sceneInteractions - Interactions for the current scene
 * @returns The processed element (may be unwrapped if type: input specified)
 */
let rec attachInteractionsToElement = (
  element: element,
  sceneInteractions: option<sceneInteractions>,
): element => {
  switch element {
  | Box({name, bounds, children}) => {
      // Recursively process children first
      let enhancedChildren = children->Array.map(child => {
        attachInteractionsToElement(child, sceneInteractions)
      })

      // Check if this is an input-only box that should be unwrapped
      // A box is unwrapped if:
      // 1. It has no name (anonymous box)
      // 2. It contains only Input elements
      // 3. At least one Input has type: "input" in its interaction
      let isAnonymous = name === None
      let hasOnlyInputs =
        enhancedChildren->Array.length > 0 &&
        enhancedChildren->Array.every(child => {
          switch child {
          | Input(_) => true
          | _ => false
          }
        })

      let shouldUnwrap = isAnonymous && hasOnlyInputs && {
        enhancedChildren->Array.some(child => {
          switch child {
          | Input({id, _}) => {
              let interaction = findInteractionForElement(id, sceneInteractions)
              hasInputType(interaction)
            }
          | _ => false
          }
        })
      }

      if shouldUnwrap {
        // Return the first Input directly (unwrap the box)
        switch enhancedChildren->Array.get(0) {
        | Some(input) => input
        | None => Box({name, bounds, children: enhancedChildren})
        }
      } else {
        Box({name, bounds, children: enhancedChildren})
      }
    }
  | Button({id, text, position, align}) => {
      // Find interaction for this button (if any)
      let interaction = findInteractionForElement(id, sceneInteractions)
      // Extract actions from interaction
      let actions = switch interaction {
      | Some({actions}) => actions
      | None => []
      }
      Button({id, text, position, align, actions})
    }
  | Input({id, placeholder, position}) => {
      let interaction = findInteractionForElement(id, sceneInteractions)
      // Extract placeholder from interaction properties if available
      let enhancedPlaceholder = switch interaction {
      | Some({properties}) => {
          switch properties->Js.Dict.get("placeholder") {
          | Some(json) => {
              switch Js.Json.decodeString(json) {
              | Some(str) => Some(str)
              | None => placeholder
              }
            }
          | None => placeholder
          }
        }
      | None => placeholder
      }
      Input({id, placeholder: enhancedPlaceholder, position})
    }
  | Link({id, text, position, align}) => {
      // Find interaction for this link (if any)
      let interaction = findInteractionForElement(id, sceneInteractions)
      // Extract actions from interaction
      let actions = switch interaction {
      | Some({actions}) => actions
      | None => []
      }
      Link({id, text, position, align, actions})
    }
  | Row({children, align}) => {
      let enhancedChildren = children->Array.map(child => {
        attachInteractionsToElement(child, sceneInteractions)
      })
      Row({children: enhancedChildren, align})
    }
  | Section({name, children}) => {
      let _interaction = findInteractionForElement(name, sceneInteractions)
      let enhancedChildren = children->Array.map(child => {
        attachInteractionsToElement(child, sceneInteractions)
      })
      Section({name, children: enhancedChildren})
    }
  // Elements without IDs just pass through
  | Checkbox(_) as el => el
  | Text(_) as el => el
  | Divider(_) as el => el
  }
}

/**
 * Attach interactions to all elements in a scene.
 *
 * @param scene - The scene to process
 * @param sceneInteractionsList - All scene interactions
 * @returns Enhanced scene with interactions attached
 */
let attachInteractionsToScene = (
  scene: scene,
  sceneInteractionsList: array<sceneInteractions>,
): scene => {
  // Find interactions for this scene
  let sceneInteractions = sceneInteractionsList->Array.find(si => si.sceneId === scene.id)

  // Process all elements
  let enhancedElements = scene.elements->Array.map(element => {
    attachInteractionsToElement(element, sceneInteractions)
  })

  {
    id: scene.id,
    title: scene.title,
    transition: scene.transition,
    device: scene.device,
    elements: enhancedElements,
  }
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Merge interactions into the AST.
 * Validates that all element IDs exist and attaches interaction data to elements.
 *
 * Lenient mode: ElementNotFound errors are treated as warnings and skipped.
 * Only SceneNotFound and DuplicateInteraction are hard errors.
 *
 * @param ast - The wireframe AST
 * @param sceneInteractionsList - Array of scene interactions to merge
 * @returns Result containing merged AST or validation errors
 *
 * @example
 * let result = mergeInteractions(wireframeAst, interactions)
 * switch result {
 * | Ok(mergedAst) => Js.log("Merge successful!")
 * | Error(errors) => errors->Array.forEach(err => Js.log(err))
 * }
 */
let mergeInteractions = (
  ast: ast,
  sceneInteractionsList: array<sceneInteractions>,
): mergeResult => {
  // Build map of scene IDs to element IDs
  let sceneElementMap = buildSceneElementMap(ast)

  // Validate all interactions
  let validationErrors = validateInteractions(sceneInteractionsList, sceneElementMap)

  // Separate hard errors from soft errors (ElementNotFound)
  let hardErrors = validationErrors->Array.filter(error => {
    switch error {
    | ElementNotFound(_) => false // Soft error - element might not exist yet
    | SceneNotFound(_) => true // Hard error - scene must exist
    | DuplicateInteraction(_) => true // Hard error - duplicates are problematic
    }
  })

  if hardErrors->Array.length > 0 {
    // Return only hard errors
    Error(hardErrors)
  } else {
    // Attach interactions to scenes (missing elements are silently skipped)
    let enhancedScenes = ast.scenes->Array.map(scene => {
      attachInteractionsToScene(scene, sceneInteractionsList)
    })

    // Return enhanced AST
    Ok({scenes: enhancedScenes})
  }
}

/**
 * Format merge error for display.
 *
 * @param error - The merge error to format
 * @returns Human-readable error message
 */
let formatError = (error: mergeError): string => {
  switch error {
  | ElementNotFound({sceneId, elementId}) =>
    `Element "${elementId}" not found in scene "${sceneId}"`
  | DuplicateInteraction({sceneId, elementId}) =>
    `Duplicate interaction for element "${elementId}" in scene "${sceneId}"`
  | SceneNotFound({sceneId}) => `Scene "${sceneId}" not found in wireframe`
  }
}

/**
 * Format all merge errors for display.
 *
 * @param errors - Array of merge errors
 * @returns Formatted error messages joined with newlines
 */
let formatErrors = (errors: array<mergeError>): string => {
  errors->Array.map(formatError)->Array.join("\n")
}
