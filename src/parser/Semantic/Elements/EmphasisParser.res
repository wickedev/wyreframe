// EmphasisParser.res

open Types
// Parser for emphasis text syntax: * Text
// Task 25: Implement EmphasisParser

/**
 * Emphasis pattern regex: ^\s*\*\s+(.+)
 * Matches: * Important text
 */
let emphasisPattern = %re("/^\s*\*\s+(.+)$/")

/**
 * Quick test pattern for canParse (optimized for speed).
 */
let quickTestPattern = %re("/^\s*\*\s/")

/**
 * Check if content matches emphasis syntax pattern.
 */
let canParse = (content: string): bool => {
  Js.Re.test_(quickTestPattern, content)
}

/**
 * Parse emphasis element from content.
 */
let parse = (
  content: string,
  position: Position.t,
  bounds: Bounds.t,
): option<Types.element> => {
  switch emphasisPattern->RegExp.exec(content) {
  | None => None
  | Some(result) => {
      // RegExp.Result.matches slices off the full match, so matches[0] is the first captured group
      let matches = result->RegExp.Result.matches
      switch matches[0] {
      | None => None
      | Some(textContent) => {
          let align = AlignmentCalc.calculateWithStrategy(
            content,
            position,
            bounds,
            AlignmentCalc.RespectPosition,
          )

          Some(
            Types.Text({
              content: textContent,
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

/**
 * Create an EmphasisParser instance.
 * Priority: 70
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(~priority=70, ~canParse, ~parse)
}
