// BoxTracer.res
// Box boundary tracing implementation
// Traces rectangular boxes starting from corner characters and validates structure
// Integrates with ErrorTypes for structured error reporting with context

open Types

// Box structure (without children initially, those are added by HierarchyBuilder)
type rec box = {
  name: option<string>,
  bounds: Bounds.t,
  mutable children: array<box>,
}

// Result type using structured ParseError from ErrorTypes module
// Requirements: REQ-16 (Structured Error Objects)
type traceResult = result<box, ErrorTypes.t>

// Extract box name from top border characters
// Recognizes patterns like "+--Name--+" and extracts "Name"
// Also handles divider borders like "+===+" by treating "=" as a border char
let extractBoxName = (topEdgeChars: array<cellChar>): option<string> => {
  // Convert cellChars to string
  let chars = Array.map(topEdgeChars, Grid.cellCharToString)
  let content = Array.join(chars, "")

  // Remove leading and trailing dashes, equals signs, and corners
  // These are all border characters that should not be part of the name
  let trimmed = content
    ->String.replaceAll("+", "")
    ->String.replaceAll("-", "")
    ->String.replaceAll("=", "")  // Divider character is also a border
    ->String.trim

  // If there's any content left, it's the box name
  if String.length(trimmed) > 0 {
    Some(trimmed)
  } else {
    None
  }
}

// Check if a cellChar is valid for horizontal edges (top/bottom)
let isValidHorizontalChar = (cell: cellChar): bool => {
  switch cell {
  | HLine | Divider | Corner | Char(_) => true
  | _ => false
  }
}

// Check if a cellChar is valid for vertical edges (left/right)
let isValidVerticalChar = (cell: cellChar): bool => {
  switch cell {
  | VLine | Corner => true
  | _ => false
  }
}

// Check if a top edge is a divider-only pattern (e.g., +===+)
// These should not be treated as box borders
let isDividerOnlyEdge = (edgeChars: array<cellChar>): bool => {
  // Check if edge contains only Corners and Dividers (no HLine or Char)
  let hasHLineOrChar = edgeChars->Array.some(cell => {
    switch cell {
    | HLine | Char(_) => true
    | _ => false
    }
  })
  // If there are no HLine or Char, it's a divider-only pattern
  !hasHLineOrChar
}

/**
 * Find the last Corner character below a given position in the same column.
 * Simple version used for fallback width mismatch detection.
 *
 * @param grid - The 2D character grid
 * @param startPos - Starting position (searches below this row)
 * @returns Option of position where the last corner was found
 */
let findLastCornerInColumn = (grid: Grid.t, startPos: Position.t): option<Position.t> => {
  let lastCorner = ref(None)
  for row in startPos.row + 1 to grid.height - 1 {
    let pos = Position.make(row, startPos.col)
    switch Grid.get(grid, pos) {
    | Some(Corner) => lastCorner := Some(pos)
    | _ => ()
    }
  }
  lastCorner.contents
}

/**
 * Check if a row has any VLine character between left and right columns (inclusive).
 * Used to determine if a row is part of a box (even with misaligned borders).
 */
let rowHasVLineInRange = (grid: Grid.t, row: int, leftCol: int, rightCol: int): bool => {
  let found = ref(false)
  let col = ref(leftCol)
  while col.contents <= rightCol && !found.contents {
    switch Grid.get(grid, Position.make(row, col.contents)) {
    | Some(VLine) => found := true
    | _ => ()
    }
    col := col.contents + 1
  }
  found.contents
}

/**
 * Find the bottom-right corner of a box by scanning down from top-right.
 *
 * This is more tolerant than the strict scanDown approach:
 * - Continues through rows with misaligned VLines (records for warnings)
 * - Stops at rows with no VLine at all in the box's column range (box boundary)
 * - Handles internal dividers (+=====+) correctly by finding the last corner
 *
 * @param grid - The 2D character grid
 * @param topLeft - Position of top-left corner (for determining left boundary)
 * @param topRight - Position of top-right corner (starting point for scan)
 * @returns Option of position where the bottom-right corner was found
 */
let findBottomRightCorner = (grid: Grid.t, topLeft: Position.t, topRight: Position.t): option<Position.t> => {
  let lastCorner = ref(None)
  let row = ref(topRight.row + 1)
  let continue = ref(true)

  while row.contents < grid.height && continue.contents {
    let pos = Position.make(row.contents, topRight.col)

    switch Grid.get(grid, pos) {
    | Some(Corner) => {
        // Found a corner at the expected column - remember it
        lastCorner := Some(pos)
        row := row.contents + 1
      }
    | Some(VLine) => {
        // Found a VLine at the expected column - continue scanning
        row := row.contents + 1
      }
    | _ => {
        // No VLine/Corner at expected column - check if row is part of this box
        if rowHasVLineInRange(grid, row.contents, topLeft.col, topRight.col) {
          // Row has a VLine somewhere (misaligned) - continue scanning
          row := row.contents + 1
        } else {
          // No VLine in this row's box range - we've reached the end of the box
          continue := false
        }
      }
    }
  }

  lastCorner.contents
}

/**
 * Trace a box starting from the top-left corner position.
 *
 * Algorithm:
 * 1. Verify starting position is a Corner ('+')
 * 2. Scan right along top edge to find top-right corner
 * 3. Extract box name from top edge if present
 * 4. Scan down from top-right to find bottom-right corner
 * 5. Scan left from bottom-right to find bottom-left corner
 * 6. Validate bottom width matches top width
 * 7. Scan up from bottom-left to verify it reaches starting position
 * 8. Validate vertical pipe alignment
 * 9. Create Bounds and return box
 */
let traceBox = (grid: Grid.t, topLeft: Position.t): traceResult => {
  // Step 1: Verify starting position is a corner
  switch Grid.get(grid, topLeft) {
  | Some(Corner) => {
      // Step 2: Scan right along top edge to find top-right corner
      let topEdgeScan = Grid.scanRight(grid, topLeft, isValidHorizontalChar)

      // Find the top-right corner (last Corner in the scan)
      let topRightOpt = {
        let lastCorner = ref(None)
        Array.forEach(topEdgeScan, ((pos, cell)) => {
          switch cell {
          | Corner if !Position.equals(pos, topLeft) => lastCorner := Some(pos)
          | _ => ()
          }
        })
        lastCorner.contents
      }

      switch topRightOpt {
      | None =>
        Error(
          ErrorTypes.makeSimple(
            ErrorTypes.UncloseBox({
              corner: Position.make(topLeft.row, topLeft.col),
              direction: "top",
            }),
          ),
        )
      | Some(topRight) => {
          // Step 3: Extract box name from top edge
          let topEdgeChars = Array.map(topEdgeScan, ((_, cell)) => cell)

          // Check if this is a divider-only pattern (+===+)
          // These should not be traced as boxes
          if isDividerOnlyEdge(topEdgeChars) {
            Error(
              ErrorTypes.makeSimple(
                ErrorTypes.InvalidElement({
                  content: "Divider-only pattern, not a box border",
                  position: topLeft,
                }),
              ),
            )
          } else {
          let boxName = extractBoxName(topEdgeChars)

          // Calculate top width
          let topWidth = topRight.col - topLeft.col

          // Step 4: Find bottom-right corner by searching the column
          // Use tolerant search that ignores interior rows with misaligned VLines
          let bottomRightOpt = findBottomRightCorner(grid, topLeft, topRight)

          // Store rightEdgeScan for later validation (after we know the box is valid)
          let rightEdgeScan = Grid.scanDown(grid, topRight, isValidVerticalChar)

          switch bottomRightOpt {
          | None => {
              // No corner found in the right column at topRight.col
              // Try to detect width mismatch by finding bottom-left via left edge
              let bottomLeftViaLeft = findLastCornerInColumn(grid, topLeft)

              switch bottomLeftViaLeft {
              | None =>
                // No bottom-left corner found either - unclosed box
                Error(
                  ErrorTypes.makeSimple(
                    ErrorTypes.UncloseBox({
                      corner: topRight,
                      direction: "right",
                    }),
                  ),
                )
              | Some(bottomLeft) => {
                  // Found bottom-left, now scan right to find bottom edge width
                  let bottomEdgeScan = Grid.scanRight(grid, bottomLeft, isValidHorizontalChar)
                  let bottomRightFromLeft = {
                    let lastCorner = ref(None)
                    Array.forEach(bottomEdgeScan, ((pos, cell)) => {
                      switch cell {
                      | Corner if !Position.equals(pos, bottomLeft) => lastCorner := Some(pos)
                      | _ => ()
                      }
                    })
                    lastCorner.contents
                  }

                  switch bottomRightFromLeft {
                  | None =>
                    Error(
                      ErrorTypes.makeSimple(
                        ErrorTypes.UncloseBox({
                          corner: bottomLeft,
                          direction: "bottom",
                        }),
                      ),
                    )
                  | Some(actualBottomRight) => {
                      // Check if this is a width mismatch
                      let bottomWidth = actualBottomRight.col - bottomLeft.col
                      if topWidth !== bottomWidth {
                        Error(
                          ErrorTypes.makeSimple(
                            ErrorTypes.MismatchedWidth({
                              topLeft: topLeft,
                              topWidth: topWidth,
                              bottomWidth: bottomWidth,
                            }),
                          ),
                        )
                      } else {
                        // Widths match but right edge corners don't align - unclosed box
                        Error(
                          ErrorTypes.makeSimple(
                            ErrorTypes.UncloseBox({
                              corner: topRight,
                              direction: "right",
                            }),
                          ),
                        )
                      }
                    }
                  }
                }
              }
            }
          | Some(bottomRight) => {
              // Step 5: Scan left from bottom-right to find bottom-left corner
              let bottomEdgeScan = Grid.scanLeft(grid, bottomRight, isValidHorizontalChar)

              let bottomLeftOpt = {
                let lastCorner = ref(None)
                Array.forEach(bottomEdgeScan, ((pos, cell)) => {
                  switch cell {
                  | Corner if !Position.equals(pos, bottomRight) => lastCorner := Some(pos)
                  | _ => ()
                  }
                })
                lastCorner.contents
              }

              switch bottomLeftOpt {
              | None =>
                Error(
                  ErrorTypes.makeSimple(
                    ErrorTypes.UncloseBox({
                      corner: bottomRight,
                      direction: "bottom",
                    }),
                  ),
                )
              | Some(bottomLeft) => {
                  // Step 6: Validate bottom width matches top width
                  let bottomWidth = bottomRight.col - bottomLeft.col

                  if topWidth !== bottomWidth {
                    Error(
                      ErrorTypes.makeSimple(
                        ErrorTypes.MismatchedWidth({
                          topLeft: topLeft,
                          topWidth: topWidth,
                          bottomWidth: bottomWidth,
                        }),
                      ),
                    )
                  } else {
                    // Step 7: Scan up from bottom-left to verify closure
                    let leftEdgeScan = Grid.scanUp(grid, bottomLeft, isValidVerticalChar)

                    // Check if we reach the starting position
                    let reachesStart = Array.some(leftEdgeScan, ((pos, _)) =>
                      Position.equals(pos, topLeft)
                    )

                    if !reachesStart {
                      Error(
                        ErrorTypes.makeSimple(
                          ErrorTypes.UncloseBox({
                            corner: bottomLeft,
                            direction: "left",
                          }),
                        ),
                      )
                    } else {
                      // Step 8: Validate vertical pipe alignment
                      // Check that all vertical pipes on the left edge are aligned with topLeft.col
                      let leftAlignmentError = ref(None)
                      Array.forEach(leftEdgeScan, ((pos, cell)) => {
                        switch cell {
                        | VLine =>
                          if pos.col !== topLeft.col {
                            leftAlignmentError :=
                              Some(
                                ErrorTypes.makeSimple(
                                  ErrorTypes.MisalignedPipe({
                                    position: pos,
                                    expectedCol: topLeft.col,
                                    actualCol: pos.col,
                                  }),
                                ),
                              )
                          }
                        | _ => ()
                        }
                      })

                      switch leftAlignmentError.contents {
                      | Some(err) => Error(err)
                      | None => {
                          // Check right edge alignment
                          let rightAlignmentError = ref(None)
                          Array.forEach(rightEdgeScan, ((pos, cell)) => {
                            switch cell {
                            | VLine =>
                              if pos.col !== topRight.col {
                                rightAlignmentError :=
                                  Some(
                                    ErrorTypes.makeSimple(
                                      ErrorTypes.MisalignedPipe({
                                        position: pos,
                                        expectedCol: topRight.col,
                                        actualCol: pos.col,
                                      }),
                                    ),
                                  )
                              }
                            | _ => ()
                            }
                          })

                          switch rightAlignmentError.contents {
                          | Some(err) => Error(err)
                          | None => {
                              // Step 9: Create Bounds and return box
                              let bounds = {
                                Bounds.top: topLeft.row,
                                left: topLeft.col,
                                bottom: bottomLeft.row,
                                right: topRight.col,
                              }

                              Ok({
                                name: boxName,
                                bounds: bounds,
                                children: [],
                              })
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } // Close else block for isDividerOnlyEdge
      }
    }
  | _ =>
    Error(
      ErrorTypes.makeSimple(
        ErrorTypes.InvalidElement({
          content: "Expected '+' corner at start position",
          position: topLeft,
        }),
      ),
    )
  }
}

/**
 * Validate interior row alignment for a successfully traced box.
 *
 * Checks each row between the top and bottom borders to ensure:
 * - The closing '|' character is at the expected column (bounds.right)
 * - Generates MisalignedClosingBorder warnings for any misaligned rows
 *
 * This validation runs AFTER successful box tracing to detect visual
 * alignment issues that don't prevent parsing but should be warned about.
 *
 * @param grid - The 2D character grid
 * @param bounds - The bounds of the traced box
 * @returns Array of warnings for any misaligned closing borders
 */
let validateInteriorAlignment = (grid: Grid.t, bounds: Bounds.t): array<ErrorTypes.t> => {
  let warnings = []

  // Check each interior row (excluding top and bottom border rows)
  for row in bounds.top + 1 to bounds.bottom - 1 {
    // Check if there's a VLine at the expected right border column
    let expectedRightCol = bounds.right
    let rightCell = Grid.get(grid, Position.make(row, expectedRightCol))

    switch rightCell {
    | Some(VLine) => () // Properly aligned, no warning needed
    | Some(_) | None => {
        // The expected column doesn't have a VLine
        // Try to find where the actual closing '|' is on this row
        // Search in both directions from the expected position
        let actualCol = ref(None)

        // First, search to the RIGHT of expectedRightCol (for pipes beyond the expected boundary)
        // Search up to 50 chars beyond to catch misaligned pipes
        let maxSearchRight = expectedRightCol + 50
        let colRight = ref(expectedRightCol + 1)
        while colRight.contents <= maxSearchRight && Option.isNone(actualCol.contents) {
          switch Grid.get(grid, Position.make(row, colRight.contents)) {
          | Some(VLine) => actualCol := Some(colRight.contents)
          | _ => ()
          }
          colRight := colRight.contents + 1
        }

        // If not found to the right, search to the LEFT (for pipes before the expected boundary)
        // But only if it's not the opening pipe (bounds.left)
        if Option.isNone(actualCol.contents) {
          let col = ref(expectedRightCol - 1)
          while col.contents > bounds.left && Option.isNone(actualCol.contents) {
            switch Grid.get(grid, Position.make(row, col.contents)) {
            | Some(VLine) => actualCol := Some(col.contents)
            | _ => ()
            }
            col := col.contents - 1
          }
        }

        // If we found a VLine at a different position, generate a warning
        switch actualCol.contents {
        | Some(foundCol) if foundCol !== expectedRightCol => {
            let warning = ErrorTypes.makeSimple(
              ErrorTypes.MisalignedClosingBorder({
                position: Position.make(row, foundCol),
                expectedCol: expectedRightCol,
                actualCol: foundCol,
              }),
            )
            warnings->Array.push(warning)->ignore
          }
        | _ => () // No VLine found or it's at the correct position (already handled above)
        }
      }
    }
  }

  warnings
}
