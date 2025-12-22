// ErrorContext.res
// Error context builder for generating code snippets with visual indicators
// Provides contextual information around error locations for better debugging

// Import core types
open Types

// ============================================================================
// Error Context Type
// ============================================================================

/**
 * Contains contextual information about an error location.
 * Includes a code snippet with surrounding lines and visual indicators.
 */
type t = {
  codeSnippet: option<string>, // Formatted code snippet with line numbers and markers
  linesBefore: int, // Number of lines shown before error
  linesAfter: int, // Number of lines shown after error
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Convert a cellChar to a displayable string.
 * This is used to render the grid characters in the error context.
 */
let cellCharToString = (cell: cellChar): string => {
  switch cell {
  | Corner => "+"
  | HLine => "-"
  | VLine => "|"
  | Divider => "="
  | Space => " "
  | Char(s) => s
  }
}

/**
 * Build a formatted code snippet showing the error location.
 *
 * Features:
 * - Line numbers (1-indexed, padded to 4 digits)
 * - Arrow indicator (→) marking the error line
 * - Column pointer (^) showing exact error position
 * - Context lines before and after the error
 *
 * Format example:
 * ```
 *    1 │ +--------+
 *    2 │ |  Test  |
 *  → 3 │ +-------+
 *      │         ^
 *    4 │
 * ```
 *
 * @param grid The grid containing the source code
 * @param position The error position (row, col)
 * @param radius Number of lines to show before and after
 * @returns Formatted code snippet as a string
 *
 * REQ-18: Contextual Code Snippets
 */
let buildCodeSnippet = (grid: Grid.t, position: Position.t, radius: int): string => {
  // Calculate the range of lines to display
  // Ensure we don't go out of bounds
  let startRow = Js.Math.max_int(0, position.row - radius)
  let endRow = Js.Math.min_int(grid.height - 1, position.row + radius)

  // Helper function to pad string to the left
  let padStart = (str: string, targetLength: int, padChar: string): string => {
    let currentLength = String.length(str)
    if currentLength >= targetLength {
      str
    } else {
      let padLength = targetLength - currentLength
      let padding = String.repeat(padChar, padLength)
      padding ++ str
    }
  }

  // Build the snippet line by line
  let lines = []

  for row in startRow to endRow {
    // Format line number (1-indexed, padded to 4 spaces)
    let lineNum = (row + 1)->Int.toString->padStart(4, " ")

    // Add arrow indicator for error line, spaces for others
    let prefix = if row == position.row { " → " } else { "   " }

    // Get the line content from the grid
    switch Grid.getLine(grid, row) {
    | Some(chars) => {
        // Convert cell characters to string
        let lineText = chars->Belt.Array.map(cellCharToString)->Js.Array2.joinWith("")

        // Build the formatted line: "  → 123 │ content"
        let formattedLine = `${prefix}${lineNum} │ ${lineText}`
        lines->Js.Array2.push(formattedLine)->ignore

        // Add column pointer under error position
        if row == position.row {
          // Calculate spacing: account for prefix (4) + line number (4) + separator (2) = 10 chars
          let spacingBeforePointer = 10 + position.col
          let pointer = " "->Js.String2.repeat(spacingBeforePointer) ++ "^"
          lines->Js.Array2.push(`      │ ${pointer}`)->ignore
        }
      }
    | None => {
        // Handle missing lines gracefully (shouldn't happen in valid grid)
        let formattedLine = `${prefix}${lineNum} │ `
        lines->Js.Array2.push(formattedLine)->ignore
      }
    }
  }

  // Join all lines with newlines
  lines->Js.Array2.joinWith("\n")
}

// ============================================================================
// Main Constructor
// ============================================================================

/**
 * Create an error context from a grid and position.
 * Automatically builds a code snippet with default or custom radius.
 *
 * @param grid The grid containing the source code
 * @param position The error position
 * @param radius Number of lines to show before/after (default: 2)
 * @returns Error context with formatted code snippet
 */
let make = (grid: Grid.t, position: Position.t, ~radius: int=2): t => {
  // Calculate actual lines shown (may be less at boundaries)
  let startRow = Js.Math.max_int(0, position.row - radius)
  let endRow = Js.Math.min_int(grid.height - 1, position.row + radius)

  let linesBefore = position.row - startRow
  let linesAfter = endRow - position.row

  // Build the code snippet
  let snippet = buildCodeSnippet(grid, position, radius)

  {
    codeSnippet: Some(snippet),
    linesBefore: linesBefore,
    linesAfter: linesAfter,
  }
}

/**
 * Create an empty error context (no snippet).
 * Used when grid information is not available.
 */
let empty = (): t => {
  codeSnippet: None,
  linesBefore: 0,
  linesAfter: 0,
}

/**
 * Get the code snippet from the context.
 * Returns empty string if no snippet is available.
 */
let getSnippet = (ctx: t): string => {
  switch ctx.codeSnippet {
  | Some(snippet) => snippet
  | None => ""
  }
}

/**
 * Check if context has a code snippet.
 */
let hasSnippet = (ctx: t): bool => {
  switch ctx.codeSnippet {
  | Some(_) => true
  | None => false
  }
}

/**
 * Get the total number of context lines shown.
 */
let totalLines = (ctx: t): int => {
  ctx.linesBefore + 1 + ctx.linesAfter // +1 for the error line itself
}
