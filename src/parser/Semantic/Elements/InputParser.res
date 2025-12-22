// InputParser.res

open Types
// Parser for input field elements with syntax "#fieldname"
//
// Recognizes input fields denoted by a hash (#) followed by an identifier.
// Example: "#email", "#password", "#username"

/**
 * Regular expression pattern for input field syntax.
 * Matches: # followed by one or more word characters (letters, digits, underscores)
 * The field must be at the end of the string (with optional trailing whitespace).
 * Can appear anywhere in the line, optionally preceded by a label.
 * Examples:
 * - "#email" ✓
 * - "#password123" ✓
 * - "#user_name" ✓
 * - "Email: #email" ✓ (with label prefix)
 * - "Password: #password" ✓ (with label prefix)
 * - "#first-name" ✗ (contains hyphen after word characters)
 * - "#email.address" ✗ (dot not allowed)
 * - "##email" ✗ (double hash not allowed)
 * - "# email" ✗ (space after #)
 */
// Pattern: (start or non-#) + # + word chars + optional trailing whitespace + end
let inputPattern = %re("/(?:^|[^#])#(\w+)\s*$/")

/**
 * Quick check if content matches input field pattern.
 *
 * @param content - Text content to check
 * @return true if content contains # followed by word characters
 */
let canParse = (content: string): bool => {
  let trimmed = content->String.trim

  // Check if contains #\w+ pattern anywhere in the string
  inputPattern->RegExp.test(trimmed)
}

/**
 * Parse input field element from content.
 *
 * Extracts the field identifier after the # character and creates
 * an Input element with that ID.
 *
 * @param content - Text content to parse (e.g., "#email")
 * @param position - Grid position where input was found
 * @param _bounds - Bounding box (not used for inputs, they are always left-aligned)
 * @return Some(Input element) if parsing succeeds, None otherwise
 */
let parse = (
  content: string,
  position: Position.t,
  _bounds: Bounds.t,
): ElementParser.parseResult<Types.element> => {
  let trimmed = content->String.trim

  // Extract identifier after # character
  switch inputPattern->RegExp.exec(trimmed) {
  | Some(result) => {
      // Get first capture group (the identifier after #)
      // RegExp.Result.matches slices off the full match, so matches[0] is the first captured group
      let matches = result->RegExp.Result.matches
      switch matches[0] {
      | Some(identifier) => {
          // Successfully extracted identifier
          Some(
            Types.Input({
              id: identifier,
              placeholder: None,
              position: Types.Position.make(position.row, position.col),
            })
          )
        }
      | None => None
      }
    }
  | None => None
  }
}

/**
 * Create an InputParser instance with priority 90.
 *
 * Priority explanation:
 * - 100: Buttons (highest priority)
 * - 90: Inputs (this parser)
 * - 80: Links
 * - 70: Emphasis
 * - 1: Text (fallback, lowest priority)
 *
 * @return ElementParser.elementParser configured for input fields
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(~priority=90, ~canParse, ~parse)
}
