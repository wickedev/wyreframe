// ButtonParser.res

open Types
// Parser for button syntax: [ Text ]
//
// Recognizes button elements in wireframes and extracts their text content.
// Buttons are defined with square brackets containing text: [ Submit ], [ Cancel ], etc.

/**
 * Slugify a string to create a valid identifier.
 * Converts text to lowercase, replaces spaces and special chars with hyphens.
 *
 * Examples:
 * - "Submit Form" -> "submit-form"
 * - "Log In" -> "log-in"
 * - "Create Account!" -> "create-account"
 *
 * @param text - The text to slugify
 * @return A slugified identifier string
 */
let slugify = (text: string): string => {
  text
  ->String.trim
  ->String.toLowerCase
  // Replace spaces with hyphens
  ->Js.String2.replaceByRe(%re("/\s+/g"), "-")
  // Remove non-alphanumeric characters (except hyphens)
  ->Js.String2.replaceByRe(%re("/[^a-z0-9-]/g"), "")
  // Remove consecutive hyphens
  ->Js.String2.replaceByRe(%re("/-+/g"), "-")
  // Remove leading/trailing hyphens
  ->Js.String2.replaceByRe(%re("/^-+|-+$/g"), "")
}

/**
 * Button pattern regex: \[\s*[^\]]+\s*\]
 * Matches: [ Text ] with optional whitespace
 * Examples:
 * - [ Submit ]
 * - [Login]
 * - [  Create Account  ]
 */
let buttonPattern = %re("/^\s*\[\s*([^\]]+?)\s*\]\s*$/")

/**
 * Quick test pattern for canParse (optimized for speed).
 * Just checks if content contains [ and ]
 */
let quickTestPattern = %re("/\[.*\]/")

/**
 * Check if content matches button syntax pattern.
 *
 * @param content - The text content to test
 * @return true if content looks like a button
 */
let canParse = (content: string): bool => {
  Js.Re.test_(quickTestPattern, content)
}

/**
 * Parse button element from content.
 *
 * Extracts button text from [ Text ] syntax and creates a Button element.
 * Returns None if:
 * - Pattern doesn't match
 * - Button text is empty after trimming
 *
 * @param content - The text content containing button syntax
 * @param position - Grid position where button appears
 * @param bounds - Bounding box of containing box (for alignment calculation)
 * @return Some(Button element) or None
 */
let parse = (
  content: string,
  position: Position.t,
  bounds: Bounds.t,
): option<Types.element> => {
  switch buttonPattern->RegExp.exec(content) {
  | None => None
  | Some(result) => {
      let matches = result->RegExp.Result.matches
      // RegExp.Result.matches slices off the full match, so matches[0] is the first captured group
      switch matches[0] {
      | None => None
      | Some(buttonText) => {
          let buttonText = buttonText->String.trim

          // Return None for empty button text
          if buttonText === "" {
            None
          } else {
            let buttonId = slugify(buttonText)

            // Calculate alignment based on position within bounds
            let align = AlignmentCalc.calculateWithStrategy(
              content,
              position,
              bounds,
              AlignmentCalc.RespectPosition,
            )

            // Create Button element
            Some(
              Types.Button({
                id: buttonId,
                text: buttonText,
                position: Types.Position.make(position.row, position.col),
                align: align,
                actions: [],
              }),
            )
          }
        }
      }
    }
  }
}

/**
 * Create a ButtonParser instance.
 *
 * Priority: 100 (high priority, checked early in the registry)
 *
 * @return An ElementParser configured for button recognition
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(~priority=100, ~canParse, ~parse)
}
