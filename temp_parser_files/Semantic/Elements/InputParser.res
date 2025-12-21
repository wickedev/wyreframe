// InputParser.res
// Parser for input field elements with syntax "#fieldname"
//
// Recognizes input fields denoted by a hash (#) followed by an identifier.
// Example: "#email", "#password", "#username"

/**
 * Regular expression pattern for input field syntax.
 * Matches: # followed by one or more word characters (letters, digits, underscores)
 * Examples:
 * - "#email" ✓
 * - "#password123" ✓
 * - "#user_name" ✓
 * - "#first-name" ✗ (contains hyphen, not a word character)
 * - "# email" ✗ (space after #)
 */
let inputPattern = %re("/^#(\w+)$/")

/**
 * Quick check if content matches input field pattern.
 *
 * @param content - Text content to check
 * @return true if content starts with # followed by word characters
 */
let canParse = (content: string): bool => {
  let trimmed = content->String.trim

  // Check if matches #\w+ pattern
  switch trimmed->Js.Re.exec_(inputPattern) {
  | Some(_) => true
  | None => false
  }
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
  _bounds: Types.bounds,
): ElementParser.parseResult<Types.element> => {
  let trimmed = content->String.trim

  // Extract identifier after # character
  switch trimmed->Js.Re.exec_(inputPattern) {
  | Some(result) => {
      let captures = result->Js.Re.captures

      // Get first capture group (the identifier after #)
      switch captures[1] {
      | Some(captureValue) => {
          switch captureValue->Js.Nullable.toOption {
          | Some(identifier) => {
              // Successfully extracted identifier
              Some(
                Types.Input({
                  id: identifier,
                  placeholder: None,
                  position: position,
                })
              )
            }
          | None => None
          }
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
