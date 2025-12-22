// LinkParser.res

open Types
// Parser for link syntax: "Link Text" (quoted text)
//
// Recognizes quoted text patterns and generates Link elements.
// Priority: 80 (between inputs and checkboxes)

/**
 * Regular expression pattern for matching quoted text.
 * Matches: "text content" where content can include any character except unescaped quotes
 *
 * Pattern breakdown:
 * - " : Opening quote
 * - [^"]+ : One or more characters that are not quotes
 * - " : Closing quote
 */
let linkPattern = %re("/\"([^\"]+)\"/")

/**
 * Quick check pattern for canParse (faster, no capture groups)
 */
let quickPattern = %re("/\"[^\"]+\"/")

/**
 * Convert text to a URL-friendly slug identifier.
 *
 * Rules:
 * - Convert to lowercase
 * - Replace spaces and special characters with hyphens
 * - Remove consecutive hyphens
 * - Trim leading/trailing hyphens
 *
 * Examples:
 * - "Login Here" -> "login-here"
 * - "Sign Up!" -> "sign-up"
 * - "  Multiple   Spaces  " -> "multiple-spaces"
 *
 * @param text - The text to slugify
 * @return URL-friendly identifier
 */
let slugify = (text: string): string => {
  text
  ->String.toLowerCase
  ->String.trim
  // Replace whitespace and special chars with hyphens
  ->Js.String2.replaceByRe(%re("/[^a-z0-9]+/g"), "-")
  // Remove consecutive hyphens
  ->Js.String2.replaceByRe(%re("/-+/g"), "-")
  // Trim hyphens from start and end
  ->Js.String2.replaceByRe(%re("/^-+|-+$/g"), "")
}

/**
 * Unescape quotes within the link text.
 * Handles escaped quotes (\") within the text content.
 *
 * @param text - The extracted text with potential escape sequences
 * @return Text with escape sequences resolved
 */
let unescapeQuotes = (text: string): string => {
  text->Js.String2.replaceByRe(%re("/\\\\\"/g"), "\"")
}

/**
 * Check if content matches the link pattern.
 *
 * This is a fast pattern check that doesn't extract data.
 * Used by the parser registry to quickly determine if this parser should be tried.
 *
 * @param content - The content string to check
 * @return true if content matches link syntax
 */
let canParse = (content: string): bool => {
  quickPattern->Js.Re.test_(content)
}

/**
 * Parse link content and generate a Link element.
 *
 * Extracts text between quotes and creates a Link element with:
 * - id: Slugified version of the link text
 * - text: The extracted link text
 * - position: Grid position of the link
 * - align: Left alignment (default for links)
 *
 * @param content - The content string to parse
 * @param position - Position in the grid
 * @param _bounds - Bounding box (unused for now, will be used for alignment calculation)
 * @return Some(Link element) if parsing succeeds, None otherwise
 */
let parse = (
  content: string,
  position: Position.t,
  _bounds: Bounds.t,
): ElementParser.parseResult<Types.element> => {
  switch linkPattern->RegExp.exec(content) {
  | Some(result) => {
      // RegExp.Result.matches slices off the full match, so matches[0] is the first captured group
      let matches = result->RegExp.Result.matches

      switch matches[0] {
      | Some(linkText) => {
          // linkText is already a string, no need for Nullable conversion

          // Check for empty text
          if linkText->String.trim === "" {
            None
          } else {
            // Unescape any escaped quotes in the text
            let unescapedText = unescapeQuotes(linkText)

            // Generate ID from text
            let linkId = slugify(unescapedText)

            // Create Link element
            // Note: Using Left alignment as default
            // When AlignmentCalc is implemented, this will use calculated alignment
            Some(
              Types.Link({
                id: linkId,
                text: unescapedText,
                position: Types.Position.make(position.row, position.col),
                align: Left,
                actions: [],
              }),
            )
          }
        }
      | None => None
      }
    }
  | None => None
  }
}

/**
 * Create a LinkParser instance with priority 80.
 *
 * Priority 80 places it:
 * - After buttons (100) and inputs (90)
 * - Before checkboxes (85) and emphasis (70)
 * - Well before text fallback (1)
 *
 * @return ElementParser.t configured for link parsing
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(~priority=80, ~canParse, ~parse)
}
