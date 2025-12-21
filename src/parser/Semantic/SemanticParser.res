// SemanticParser.res
// Stage 3: Semantic parsing - extracts and interprets box content

// Type aliases for clarity (these should match Core/Types.res when it exists)
type box = {
  name: option<string>,
  bounds: Bounds.t,
  children: array<box>,
}

// Grid type placeholder (should match Core/Grid.res when it exists)
type cellChar =
  | Corner // '+'
  | HLine // '-'
  | VLine // '|'
  | Divider // '='
  | Space // ' '
  | Char(string) // Any other character

type grid = {
  cells: array<array<cellChar>>,
  width: int,
  height: int,
}

/**
 * Extracts content lines from within a box's bounds
 *
 * This function:
 * - Excludes the top border line (row at bounds.top)
 * - Excludes the bottom border line (row at bounds.bottom)
 * - Extracts content from rows between top and bottom
 * - Removes the left and right border characters ('|') from each line
 * - Preserves all internal whitespace
 *
 * @param box - The box to extract content from
 * @param grid - The grid containing the box
 * @returns Array of content lines (strings) without borders
 *
 * Example:
 * ```
 * +--Login--+
 * |  #email |
 * | [Submit]|
 * +---------+
 * ```
 * Returns: ["  #email ", " [Submit]"]
 */
let extractContentLines = (box: box, grid: grid): array<string> => {
  let bounds = box.bounds

  // Calculate content rows (exclude top and bottom borders)
  let contentStartRow = bounds.top + 1
  let contentEndRow = bounds.bottom - 1

  // If box has no content area (height <= 2), return empty array
  if contentStartRow > contentEndRow {
    []
  } else {
    // Build array of content lines
    let contentLines = []

    for row in contentStartRow to contentEndRow {
      // Check if row is within grid bounds
      if row >= 0 && row < grid.height {
        // Get the row from the grid
        switch grid.cells[row] {
        | Some(rowCells) => {
            // Extract content between left and right borders
            // Left border is at bounds.left, right border is at bounds.right
            let contentStartCol = bounds.left + 1
            let contentEndCol = bounds.right - 1

            // Extract characters between borders
            let lineChars = []

            for col in contentStartCol to contentEndCol {
              if col >= 0 && col < Array.length(rowCells) {
                switch rowCells[col] {
                | Char(c) => lineChars->Array.push(c)
                | Space => lineChars->Array.push(" ")
                | VLine => lineChars->Array.push("|") // Preserve | if it's not at the border
                | HLine => lineChars->Array.push("-")
                | Corner => lineChars->Array.push("+")
                | Divider => lineChars->Array.push("=")
                }
              }
            }

            // Convert character array to string
            let line = lineChars->Array.joinWith("")
            contentLines->Array.push(line)
          }
        | None => {
            // Row doesn't exist in grid, skip it
            ()
          }
        }
      }
    }

    contentLines
  }
}

/**
 * Helper function to convert a line of cellChar array to string
 * (for internal use)
 */
let cellCharsToString = (cells: array<cellChar>): string => {
  cells
  ->Array.map(cell => {
    switch cell {
    | Char(c) => c
    | Space => " "
    | VLine => "|"
    | HLine => "-"
    | Corner => "+"
    | Divider => "="
    }
  })
  ->Array.joinWith("")
}

/**
 * Alternative implementation using getLine helper
 * (commented out until Grid module is fully implemented)
 */
/*
let extractContentLinesAlt = (box: box, grid: grid): array<string> => {
  let bounds = box.bounds
  let contentStartRow = bounds.top + 1
  let contentEndRow = bounds.bottom - 1

  if contentStartRow > contentEndRow {
    []
  } else {
    let contentLines = []

    for row in contentStartRow to contentEndRow {
      switch Grid.getLine(grid, row) {
      | Some(rowCells) => {
          let contentStartCol = bounds.left + 1
          let contentEndCol = bounds.right - 1

          // Extract slice of the row
          let contentChars = rowCells->Array.slice(~start=contentStartCol, ~end=contentEndCol + 1)
          let line = cellCharsToString(contentChars)
          contentLines->Array.push(line)
        }
      | None => ()
      }
    }

    contentLines
  }
}
*/
