// ASTBuilder.res
// Module for building Abstract Syntax Trees from parsed elements
// Handles scene construction, validation, and AST assembly

// Import core types
type element = Types.element
type scene = Types.scene
type ast = Types.ast
type parseError = ErrorTypes.t
type position = Types.Position.t

/**
 * Error specific to AST building operations
 */
type astError =
  | DuplicateSceneId({
      sceneId: string,
      firstPosition: position,
      secondPosition: position,
    })
  | EmptySceneId({position: position})
  | InvalidSceneStructure({
      sceneId: string,
      reason: string,
    })

/**
 * Convert AST-specific errors to ParseError
 */
let astErrorToParseError = (error: astError): parseError => {
  switch error {
  | DuplicateSceneId({sceneId, firstPosition, secondPosition: _}) =>
    ErrorTypes.make(
      InvalidElement({
        content: `Duplicate scene ID: "${sceneId}"`,
        position: firstPosition,
      }),
      None,
    )
  | EmptySceneId({position}) =>
    ErrorTypes.make(
      InvalidElement({
        content: "Scene ID cannot be empty",
        position: position,
      }),
      None,
    )
  | InvalidSceneStructure({sceneId, reason}) =>
    ErrorTypes.make(
      InvalidElement({
        content: `Invalid scene structure for "${sceneId}": ${reason}`,
        position: Types.Position.make(0, 0),
      }),
      None,
    )
  }
}

/**
 * Scene builder configuration with optional fields
 */
type sceneConfig = {
  id: string,
  title: option<string>,
  transition: option<string>,
  device: option<Types.deviceType>,
  elements: array<element>,
  position: position, // Position where scene directive was found
}

/**
 * Build a single scene from configuration
 * Handles optional fields by providing sensible defaults
 *
 * @param config - Scene configuration with id, title, transition, and elements
 * @returns Result with scene or error
 */
let buildScene = (config: sceneConfig): result<scene, astError> => {
  // Validate scene ID is not empty
  let trimmedId = String.trim(config.id)
  if trimmedId == "" {
    Error(EmptySceneId({position: config.position}))
  } else {
    // Use title from config or derive from ID (capitalize and replace hyphens/underscores)
    let title = switch config.title {
    | Some(t) => String.trim(t)
    | None => {
        // Derive title from ID: "login-page" -> "Login Page"
        trimmedId
        ->String.split("-")
        ->Array.map(word =>
          word->String.split("")->Array.mapWithIndex((char, i) => i == 0 ? String.toUpperCase(char) : char)->Array.join("")
        )
        ->Array.join(" ")
      }
    }

    // Use transition from config or default to "none"
    let transition = switch config.transition {
    | Some(t) => String.trim(t)
    | None => "none"
    }

    // Validate elements array (could add more validation here)
    let elements = config.elements

    // Use device from config or default to Desktop
    let device = switch config.device {
    | Some(d) => d
    | None => Types.Desktop
    }

    Ok({
      id: trimmedId,
      title: title,
      transition: transition,
      device: device,
      elements: elements,
    })
  }
}

/**
 * Build complete AST from scene configurations
 * Validates unique scene IDs and constructs the final AST
 *
 * @param sceneConfigs - Array of scene configurations to build
 * @returns Result with complete AST or array of errors
 */
let buildAST = (sceneConfigs: array<sceneConfig>): result<ast, array<parseError>> => {
  // Track seen scene IDs to detect duplicates
  let seenIds = Dict.make()
  let errors = []
  let validScenes = []

  // Process each scene configuration
  sceneConfigs->Array.forEach(config => {
    // Check for duplicate scene ID
    switch Dict.get(seenIds, config.id) {
    | Some(firstPosition) => {
        // Duplicate found
        let error = DuplicateSceneId({
          sceneId: config.id,
          firstPosition: firstPosition,
          secondPosition: config.position,
        })
        errors->Array.push(astErrorToParseError(error))->ignore
      }
    | None => {
        // Record this ID
        Dict.set(seenIds, config.id, config.position)

        // Build the scene
        switch buildScene(config) {
        | Ok(scene) => validScenes->Array.push(scene)->ignore
        | Error(error) => errors->Array.push(astErrorToParseError(error))->ignore
        }
      }
    }
  })

  // Return errors if any, otherwise return AST
  if Array.length(errors) > 0 {
    Error(errors)
  } else {
    Ok({scenes: validScenes})
  }
}

/**
 * Build AST from a single scene (convenience function)
 * Useful when parsing simple wireframes with only one scene
 */
let buildSingleSceneAST = (
  ~id: string,
  ~title: option<string>=?,
  ~transition: option<string>=?,
  ~elements: array<element>,
  ~position: position=Types.Position.make(0, 0),
): result<ast, array<parseError>> => {
  buildAST([
    {
      id: id,
      title: title,
      transition: transition,
      device: None,
      elements: elements,
      position: position,
    },
  ])
}

/**
 * Merge multiple ASTs into a single AST
 * Validates that scene IDs remain unique across merged ASTs
 */
let mergeASTs = (asts: array<ast>): result<ast, array<parseError>> => {
  // Extract all scenes from all ASTs
  let allScenes = asts->Array.flatMap(ast => ast.scenes)

  // Convert scenes back to configs for validation
  let configs = allScenes->Array.map(scene => {
    {
      id: scene.id,
      title: Some(scene.title),
      transition: Some(scene.transition),
      device: Some(scene.device),
      elements: scene.elements,
      position: Types.Position.make(0, 0), // Position not available from scene
    }
  })

  // Use buildAST to validate and merge
  buildAST(configs)
}

/**
 * Validate an existing AST
 * Checks for duplicate scene IDs and other structural issues
 */
let validateAST = (ast: ast): result<unit, array<parseError>> => {
  let seenIds = Dict.make()
  let errors = []

  ast.scenes->Array.forEach(scene => {
    switch Dict.get(seenIds, scene.id) {
    | Some(_) => {
        let error = ErrorTypes.make(
          InvalidElement({
            content: `Duplicate scene ID: "${scene.id}"`,
            position: Types.Position.make(0, 0),
          }),
          None,
        )
        errors->Array.push(error)->ignore
      }
    | None => Dict.set(seenIds, scene.id, Types.Position.make(0, 0))
    }

    // Validate scene has a non-empty ID
    if String.trim(scene.id) == "" {
      let error = ErrorTypes.make(
        InvalidElement({
          content: "Scene ID cannot be empty",
          position: Types.Position.make(0, 0),
        }),
        None,
      )
      errors->Array.push(error)->ignore
    }
  })

  if Array.length(errors) > 0 {
    Error(errors)
  } else {
    Ok()
  }
}

/**
 * Get scene by ID from AST
 */
let getSceneById = (ast: ast, sceneId: string): option<scene> => {
  ast.scenes->Array.find(scene => scene.id == sceneId)
}

/**
 * Check if AST contains a scene with given ID
 */
let hasScene = (ast: ast, sceneId: string): bool => {
  ast.scenes->Array.some(scene => scene.id == sceneId)
}

/**
 * Count total elements across all scenes
 */
let countElements = (ast: ast): int => {
  ast.scenes->Array.reduce(0, (count, scene) => {
    count + Array.length(scene.elements)
  })
}

/**
 * Get all scene IDs from AST
 */
let getSceneIds = (ast: ast): array<string> => {
  ast.scenes->Array.map(scene => scene.id)
}
