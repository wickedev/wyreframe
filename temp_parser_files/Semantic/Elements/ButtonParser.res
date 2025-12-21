// ButtonParser.res
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
let quickTestPattern = %re("/\[.*\]/)

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
 * @param bounds - Bounding box of containing box (for future alignment calc)
 * @return Some(Button element) or None
 */
let parse = (
  content: string,
  position: Position.t,
  _bounds: Types.bounds,
): option<Types.element> => {
  switch Js.Re.exec_(buttonPattern, content) {
  | None => None
  | Some(result) => {
      let captures = Js.Re.captures(result)
      // captures[0] is the full match, captures[1] is the captured group
      switch Js.Nullable.toOption(captures[1]) {
      | None => None
      | Some(textMatch) => {
          let buttonText = textMatch->String.trim

          // Return None for empty button text
          if buttonText === "" {
            None
          } else {
            let buttonId = slugify(buttonText)

            // Create Button element
            // Note: Using Left alignment as default until AlignmentCalc is implemented (TASK-028)
            Some(
              Types.Button({
                id: buttonId,
                text: buttonText,
                position: position,
                align: Types.Left,
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
