// Core Type Definitions for Wyreframe Parser
// This module defines all fundamental types used throughout the parser pipeline

// ============================================================================
// Grid Cell Character Types
// ============================================================================

/**
 * Represents a single character in the 2D grid with semantic meaning.
 *
 * Variants:
 * - Corner: '+' character (box corners)
 * - HLine: '-' character (horizontal lines/borders)
 * - VLine: '|' character (vertical lines/borders)
 * - Divider: '=' character (section dividers)
 * - Space: ' ' character (whitespace)
 * - Char(string): Any other character content
 */
type cellChar =
  | Corner // '+'
  | HLine // '-'
  | VLine // '|'
  | Divider // '='
  | Space // ' '
  | Char(string) // Any other character

// ============================================================================
// Alignment Types
// ============================================================================

/**
 * Represents horizontal alignment of elements within a box.
 *
 * Used by alignment calculation to determine visual positioning.
 */
type alignment =
  | Left
  | Center
  | Right

// ============================================================================
// Element Types
// ============================================================================

/**
 * Represents UI elements recognized in wireframes.
 *
 * Each variant corresponds to a specific UI component type with its
 * associated properties and metadata.
 */
type rec element =
  /**
   * Container box element with optional name and nested children.
   *
   * Properties:
   * - name: Optional box name extracted from top border (e.g., "+--Login--+")
   * - bounds: Rectangular bounds in the grid
   * - children: Nested elements contained within this box
   */
  | Box({
      name: option<string>,
      bounds: bounds,
      children: array<element>,
    })
  /**
   * Button element with text label.
   *
   * Syntax: [ Text ]
   *
   * Properties:
   * - id: Slugified identifier from button text
   * - text: Display text for the button
   * - position: Grid position where button appears
   * - align: Horizontal alignment (left/center/right)
   */
  | Button({
      id: string,
      text: string,
      position: position,
      align: alignment,
    })
  /**
   * Input field element.
   *
   * Syntax: #fieldname
   *
   * Properties:
   * - id: Field identifier
   * - placeholder: Optional placeholder text
   * - position: Grid position where input appears
   */
  | Input({
      id: string,
      placeholder: option<string>,
      position: position,
    })
  /**
   * Link/anchor element with text.
   *
   * Syntax: "Link Text"
   *
   * Properties:
   * - id: Generated identifier
   * - text: Display text for the link
   * - position: Grid position where link appears
   * - align: Horizontal alignment (left/center/right)
   */
  | Link({
      id: string,
      text: string,
      position: position,
      align: alignment,
    })
  /**
   * Checkbox element with label.
   *
   * Syntax: [x] or [ ]
   *
   * Properties:
   * - checked: Whether checkbox is checked ([x]) or unchecked ([ ])
   * - label: Associated label text
   * - position: Grid position where checkbox appears
   */
  | Checkbox({
      checked: bool,
      label: string,
      position: position,
    })
  /**
   * Text element with optional emphasis.
   *
   * Syntax: Plain text or * Emphasized Text
   *
   * Properties:
   * - content: Text content
   * - emphasis: Whether text is emphasized (starts with *)
   * - position: Grid position where text appears
   * - align: Horizontal alignment (left/center/right)
   */
  | Text({
      content: string,
      emphasis: bool,
      position: position,
      align: alignment,
    })
  /**
   * Horizontal divider line.
   *
   * Syntax: Line of '=' characters
   *
   * Properties:
   * - position: Grid position of the divider
   */
  | Divider({position: position})
  /**
   * Row container for horizontally arranged elements.
   *
   * Properties:
   * - children: Elements in the row
   * - align: Row alignment
   */
  | Row({
      children: array<element>,
      align: alignment,
    })
  /**
   * Section container for grouped elements.
   *
   * Properties:
   * - name: Section name/identifier
   * - children: Elements in the section
   */
  | Section({
      name: string,
      children: array<element>,
    })

// Forward reference to Position and Bounds types
// These are defined in separate modules but needed here for element definitions
and position = {
  row: int,
  col: int,
}

and bounds = {
  top: int,
  left: int,
  bottom: int,
  right: int,
}

// ============================================================================
// Scene Types
// ============================================================================

/**
 * Represents a single scene (screen/page) in the wireframe.
 *
 * Properties:
 * - id: Unique scene identifier (from @scene directive)
 * - title: Optional scene title (from @title directive)
 * - transition: Optional transition type (from @transition directive)
 * - elements: Array of UI elements in this scene
 */
type scene = {
  id: string,
  title: option<string>,
  transition: option<string>,
  elements: array<element>,
}

// ============================================================================
// AST Types
// ============================================================================

/**
 * Complete Abstract Syntax Tree representing the parsed wireframe.
 *
 * Properties:
 * - scenes: Array of all scenes in the wireframe
 */
type ast = {scenes: array<scene>}

// ============================================================================
// Interaction Types
// ============================================================================

/**
 * Visual variant/style for interactive elements.
 */
type interactionVariant =
  | Primary
  | Secondary
  | Ghost

/**
 * Actions that can be triggered by user interactions.
 */
type interactionAction =
  /**
   * Navigate to another scene.
   *
   * Properties:
   * - target: Target scene ID
   * - transition: Optional transition animation
   * - condition: Optional condition for navigation
   */
  | Goto({
      target: string,
      transition: string,
      condition: option<string>,
    })
  /** Navigate back in history */
  | Back
  /** Navigate forward in history */
  | Forward
  /**
   * Validate form fields before proceeding.
   *
   * Properties:
   * - fields: Array of field IDs to validate
   */
  | Validate({fields: array<string>})
  /**
   * Call a custom function.
   *
   * Properties:
   * - function: Function name to call
   * - args: Function arguments
   * - condition: Optional condition for execution
   */
  | Call({
      function: string,
      args: array<string>,
      condition: option<string>,
    })

/**
 * Interaction definition for a specific element.
 *
 * Properties:
 * - elementId: ID of the element this interaction applies to
 * - properties: Additional properties as key-value pairs
 * - actions: Array of actions to execute
 */
type interaction = {
  elementId: string,
  properties: Js.Dict.t<Js.Json.t>,
  actions: array<interactionAction>,
}

/**
 * Collection of interactions for a specific scene.
 *
 * Properties:
 * - sceneId: ID of the scene these interactions belong to
 * - interactions: Array of interaction definitions
 */
type sceneInteractions = {
  sceneId: string,
  interactions: array<interaction>,
}
