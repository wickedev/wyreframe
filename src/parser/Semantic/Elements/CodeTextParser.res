// CodeTextParser.res
// Parser for aligned text syntax: 'text'
//
// Recognizes single-quote-wrapped text and applies position-based alignment.
// Unlike regular text (which defaults to left), quoted text respects its
// position within the parent container for alignment calculation.
//
// Examples:
// - 'Submit' at center position -> Center aligned
// - 'Cancel' at left position -> Left aligned
// - 'Next' at right position -> Right aligned

open Types

/**
 * Quoted text pattern regex: 'text'
 * Matches text wrapped in single quotes
 * Examples:
 * - 'Submit'
 * - 'Centered Text'
 * - '  spaced  '
 */
let quotedPattern = %re("/^\s*'([^']+)'\s*$/")

/**
 * Quick test pattern for canParse (optimized for speed).
 * Just checks if content contains single quotes wrapping text
 */
let quickTestPattern = %re("/'.+'/")

/**
 * Check if content matches quoted text syntax pattern.
 *
 * @param content - The text content to test
 * @return true if content looks like quoted text
 */
let canParse = (content: string): bool => {
  Js.Re.test_(quickTestPattern, content)
}

/**
 * Parse quoted text element from content.
 *
 * Extracts text from 'text' syntax and creates a Text element with:
 * - Position-based alignment (RespectPosition strategy)
 * - emphasis: true (indicates special formatting)
 *
 * This allows single-quote-wrapped text to be centered or right-aligned
 * based on its position within the parent container, unlike regular
 * text which always defaults to left alignment.
 *
 * @param content - The text content containing quote syntax
 * @param position - Grid position where quoted text appears
 * @param bounds - Bounding box of containing box (for alignment calculation)
 * @return Some(Text element) or None
 */
let parse = (
  content: string,
  position: Position.t,
  bounds: Bounds.t,
): option<Types.element> => {
  switch quotedPattern->RegExp.exec(content) {
  | None => None
  | Some(result) => {
      let matches = result->RegExp.Result.matches
      // RegExp.Result.matches slices off the full match, so matches[0] is the first captured group
      switch matches[0] {
      | None => None
      | Some(quotedText) => {
          let trimmedText = quotedText->String.trim

          // Return None for empty quoted text
          if trimmedText === "" {
            None
          } else {
            // Calculate alignment based on position within bounds
            // Quoted text uses RespectPosition strategy for proper alignment
            let align = AlignmentCalc.calculateWithStrategy(
              content,
              position,
              bounds,
              AlignmentCalc.RespectPosition,
            )

            // Create Text element with emphasis=true to indicate special formatting
            Some(
              Types.Text({
                content: trimmedText,
                emphasis: true,
                position: Types.Position.make(position.row, position.col),
                align: align,
              }),
            )
          }
        }
      }
    }
  }
}

/**
 * Create a CodeTextParser instance.
 *
 * Priority: 75 (between EmphasisParser and LinkParser)
 * Higher than emphasis but lower than links/buttons
 *
 * @return An ElementParser configured for quoted text recognition
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(~priority=75, ~canParse, ~parse)
}
