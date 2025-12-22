/**
 * InteractionParser.res
 *
 * Main parser module for the Interaction DSL.
 * Uses SimpleInteractionParser for lightweight, dependency-free parsing.
 */

/**
 * Error type for interaction parsing failures.
 * Contains error message and optional position information.
 */
type parseError = {
  message: string,
  position: option<Types.Position.t>,
}

/**
 * Result type for parsing operations
 */
type parseResult = result<array<Types.sceneInteractions>, parseError>

/**
 * Extract position information from an error message.
 *
 * Error messages may include position in the format:
 * "Line X: ..."
 *
 * @param message - The error message
 * @returns Option<Position.t> - Extracted position or None
 */
let extractPosition = (message: string): option<Types.Position.t> => {
  let jsPattern: Js.Re.t = %re("/Line (\d+)/i")

  switch Js.Re.exec_(jsPattern, message) {
  | Some(result) => {
      let captures = Js.Re.captures(result)
      let lineOpt = captures->Array.get(1)->Option.flatMap(x => Js.Nullable.toOption(x))

      switch lineOpt {
      | Some(lineStr) =>
        switch Int.fromString(lineStr) {
        | Some(line) => Some(Types.Position.make(line - 1, 0))
        | None => None
        }
      | None => None
      }
    }
  | None => None
  }
}

/**
 * Main parsing function for the Interaction DSL.
 *
 * Uses SimpleInteractionParser for lightweight parsing without external dependencies.
 *
 * @param input - The interaction DSL string to parse
 * @returns Result with array of scene interactions or parse error
 */
let parse = (input: string): parseResult => {
  switch SimpleInteractionParser.parse(input) {
  | Ok(sceneInteractions) => Ok(sceneInteractions)
  | Error(errorMsg) => {
      let position = extractPosition(errorMsg)
      Error({
        message: errorMsg,
        position: position,
      })
    }
  }
}

/**
 * Convenience function that returns a more detailed error message.
 * Useful for debugging and user-facing error displays.
 *
 * @param input - The interaction DSL string to parse
 * @returns Result with detailed error information
 */
let parseWithDetailedError = (input: string): result<array<Types.sceneInteractions>, string> => {
  switch parse(input) {
  | Ok(result) => Ok(result)
  | Error({message, position}) => {
      let positionStr = switch position {
      | Some(pos) => ` at ${Types.Position.toString(pos)}`
      | None => ""
      }
      Error(`Interaction DSL parsing failed${positionStr}: ${message}`)
    }
  }
}

/**
 * Validate that the input can be parsed without returning the result.
 * Useful for validation-only scenarios.
 *
 * @param input - The interaction DSL string to validate
 * @returns true if valid, false otherwise
 */
let isValid = (input: string): bool => {
  switch parse(input) {
  | Ok(_) => true
  | Error(_) => false
  }
}

/**
 * Get all scene IDs from parsed interactions.
 * Helper function for validation and debugging.
 *
 * @param sceneInteractions - Parsed scene interactions
 * @returns Array of scene IDs
 */
let getSceneIds = (sceneInteractions: array<Types.sceneInteractions>): array<string> => {
  sceneInteractions->Array.map(si => si.sceneId)
}

/**
 * Get all element IDs referenced in a scene's interactions.
 * Useful for validation against the wireframe AST.
 *
 * @param sceneInteraction - A single scene's interactions
 * @returns Array of element IDs
 */
let getElementIds = (sceneInteraction: Types.sceneInteractions): array<string> => {
  sceneInteraction.interactions->Array.map(i => i.elementId)
}
