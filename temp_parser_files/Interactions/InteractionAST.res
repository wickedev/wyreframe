// InteractionAST.res
// Type definitions for the Interaction DSL Abstract Syntax Tree

/**
 * Interaction variant types for button/element styling
 * - Primary: Main action button (e.g., submit, login)
 * - Secondary: Secondary action button (e.g., cancel, back)
 * - Ghost: Minimal/ghost style button
 */
type interactionVariant =
  | Primary
  | Secondary
  | Ghost

/**
 * Interaction action types that define what happens when an element is interacted with
 *
 * - Goto: Navigate to another scene with optional transition and condition
 * - Back: Navigate to the previous scene
 * - Forward: Navigate to the next scene in history
 * - Validate: Validate specified fields before proceeding
 * - Call: Call a custom function with arguments and optional condition
 */
type interactionAction =
  | Goto({
      target: string,
      transition: string,
      condition: option<string>,
    })
  | Back
  | Forward
  | Validate({fields: array<string>})
  | Call({
      function: string,
      args: array<string>,
      condition: option<string>,
    })

/**
 * Interaction record defining interactions for a specific UI element
 *
 * @field elementId - ID of the element to attach interactions to (e.g., "login-button", "email-input")
 * @field properties - Additional properties for the element (variant, disabled, etc.) as JSON dictionary
 * @field actions - Array of actions to perform on interaction (e.g., click, change events)
 */
type interaction = {
  elementId: string,
  properties: Js.Dict.t<Js.Json.t>,
  actions: array<interactionAction>,
}

/**
 * Scene interactions record grouping all interactions for a specific scene
 *
 * @field sceneId - ID of the scene these interactions belong to
 * @field interactions - Array of all element interactions in this scene
 */
type sceneInteractions = {
  sceneId: string,
  interactions: array<interaction>,
}
