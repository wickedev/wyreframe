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

          // Step 4: Scan down from top-right to find bottom-right corner
          let rightEdgeScan = Grid.scanDown(grid, topRight, isValidVerticalChar)

          let bottomRightOpt = {
            let lastCorner = ref(None)
            Array.forEach(rightEdgeScan, ((pos, cell)) => {
              switch cell {
              | Corner if !Position.equals(pos, topRight) => lastCorner := Some(pos)
              | _ => ()
              }
            })
            lastCorner.contents
          }

          switch bottomRightOpt {
          | None => {
              // Right edge scan failed - could be width mismatch
              // Try tracing from left side to detect width mismatch
              let leftEdgeScan = Grid.scanDown(grid, topLeft, isValidVerticalChar)
              let bottomLeftOpt = {
                let lastCorner = ref(None)
                Array.forEach(leftEdgeScan, ((pos, cell)) => {
                  switch cell {
                  | Corner if !Position.equals(pos, topLeft) => lastCorner := Some(pos)
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
                        // Widths match but right edge still failed - unclosed box
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
