// Fixer.res
// Auto-fix functionality for common wireframe errors and warnings

open FixTypes

// ============================================================================
// String Manipulation Helpers
// ============================================================================

/**
 * Split text into lines (preserving empty lines)
 */
let splitLines = (text: string): array<string> => {
  text->String.split("\n")
}

/**
 * Join lines back into text
 */
let joinLines = (lines: array<string>): string => {
  lines->Array.join("\n")
}

/**
 * Get a specific line from text (0-indexed)
 */
let getLine = (lines: array<string>, row: int): option<string> => {
  lines->Array.get(row)
}

/**
 * Replace a specific line in the array (0-indexed)
 */
let replaceLine = (lines: array<string>, row: int, newLine: string): array<string> => {
  lines->Array.mapWithIndex((line, idx) => {
    if idx === row {
      newLine
    } else {
      line
    }
  })
}

/**
 * Insert characters at a specific position in a string
 */
let insertAt = (str: string, col: int, chars: string): string => {
  let before = str->String.slice(~start=0, ~end=col)
  let after = str->String.sliceToEnd(~start=col)
  before ++ chars ++ after
}

/**
 * Remove characters at a specific position in a string
 */
let removeAt = (str: string, col: int, count: int): string => {
  let before = str->String.slice(~start=0, ~end=col)
  let after = str->String.sliceToEnd(~start=col + count)
  before ++ after
}

/**
 * Replace a character at a specific position
 */
let replaceCharAt = (str: string, col: int, char: string): string => {
  let before = str->String.slice(~start=0, ~end=col)
  let after = str->String.sliceToEnd(~start=col + 1)
  before ++ char ++ after
}

// ============================================================================
// Fix Strategies for Each Error Type
// ============================================================================

/**
 * Fix MisalignedPipe - adjust column position of '|' character
 *
 * Before: |  content   |   (pipe at wrong column)
 * After:  | content    |  (pipe at correct column)
 *
 * Note: position.row is 1-indexed (from error messages), convert to 0-indexed for array access
 */
let fixMisalignedPipe = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  switch error.code {
  | MisalignedPipe({position, expectedCol, actualCol}) => {
      let lines = splitLines(text)
      // Convert 1-indexed row to 0-indexed for array access
      let rowIndex = position.row - 1

      switch getLine(lines, rowIndex) {
      | None => None
      | Some(line) => {
          // Calculate how many spaces to add or remove
          let diff = expectedCol - actualCol

          let newLine = if diff > 0 {
            // Need to add spaces before the pipe
            insertAt(line, actualCol, String.repeat(" ", diff))
          } else {
            // Need to remove spaces before the pipe
            let removeCount = Math.Int.abs(diff)
            // Make sure we're removing spaces, not content
            let beforePipe = line->String.slice(~start=actualCol + diff, ~end=actualCol)
            if beforePipe->String.trim === "" {
              removeAt(line, actualCol + diff, removeCount)
            } else {
              line // Can't safely remove non-space characters
            }
          }

          if newLine !== line {
            let newLines = replaceLine(lines, rowIndex, newLine)
            let fixedText = joinLines(newLines)

            Some((
              fixedText,
              {
                original: error,
                description: `Aligned pipe at line ${Int.toString(position.row)} to column ${Int.toString(expectedCol + 1)}`,
                line: position.row,
                column: expectedCol + 1,
              },
            ))
          } else {
            None
          }
        }
      }
    }
  | _ => None
  }
}

/**
 * Fix MisalignedClosingBorder - adjust closing '|' position
 *
 * Note: position.row is 1-indexed (from error messages), convert to 0-indexed for array access
 */
let fixMisalignedClosingBorder = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  switch error.code {
  | MisalignedClosingBorder({position, expectedCol, actualCol}) => {
      let lines = splitLines(text)
      // Convert 1-indexed row to 0-indexed for array access
      let rowIndex = position.row - 1

      switch getLine(lines, rowIndex) {
      | None => None
      | Some(line) => {
          let diff = expectedCol - actualCol

          let newLine = if diff > 0 {
            // Need to add spaces before the closing pipe
            insertAt(line, actualCol, String.repeat(" ", diff))
          } else {
            // Need to remove spaces before the closing pipe
            let removeCount = Math.Int.abs(diff)
            let beforePipe = line->String.slice(~start=actualCol + diff, ~end=actualCol)
            if beforePipe->String.trim === "" {
              removeAt(line, actualCol + diff, removeCount)
            } else {
              line
            }
          }

          if newLine !== line {
            let newLines = replaceLine(lines, rowIndex, newLine)
            let fixedText = joinLines(newLines)

            Some((
              fixedText,
              {
                original: error,
                description: `Aligned closing border at line ${Int.toString(position.row)} to column ${Int.toString(expectedCol + 1)}`,
                line: position.row,
                column: expectedCol + 1,
              },
            ))
          } else {
            None
          }
        }
      }
    }
  | _ => None
  }
}

/**
 * Fix UnusualSpacing - replace tabs with spaces
 *
 * Note: position.row is 1-indexed (from error messages), convert to 0-indexed for array access
 */
let fixUnusualSpacing = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  switch error.code {
  | UnusualSpacing({position, issue}) => {
      // Check if the issue is about tabs
      if issue->String.includes("tab") || issue->String.includes("Tab") {
        let lines = splitLines(text)
        // Convert 1-indexed row to 0-indexed for array access
        let rowIndex = position.row - 1

        switch getLine(lines, rowIndex) {
        | None => None
        | Some(line) => {
            // Replace tabs with 2 spaces (common convention)
            let newLine = line->String.replaceAll("\t", "  ")

            if newLine !== line {
              let newLines = replaceLine(lines, rowIndex, newLine)
              let fixedText = joinLines(newLines)

              Some((
                fixedText,
                {
                  original: error,
                  description: `Replaced tabs with spaces at line ${Int.toString(position.row)}`,
                  line: position.row,
                  column: position.col + 1,
                },
              ))
            } else {
              None
            }
          }
        }
      } else {
        None
      }
    }
  | _ => None
  }
}

/**
 * Fix UnclosedBracket - add closing ']' at end of line
 *
 * Note: opening.row is 1-indexed (from error messages), convert to 0-indexed for array access
 */
let fixUnclosedBracket = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  switch error.code {
  | UnclosedBracket({opening}) => {
      let lines = splitLines(text)
      // Convert 1-indexed row to 0-indexed for array access
      let rowIndex = opening.row - 1

      switch getLine(lines, rowIndex) {
      | None => None
      | Some(line) => {
          // Find the content after '[' and close it
          let trimmedLine = line->String.trimEnd

          // Only add ']' if the line doesn't already end with it
          if !(trimmedLine->String.endsWith("]")) {
            // Add ' ]' with proper spacing
            let newLine = trimmedLine ++ " ]"
            let newLines = replaceLine(lines, rowIndex, newLine)
            let fixedText = joinLines(newLines)

            Some((
              fixedText,
              {
                original: error,
                description: `Added closing bracket at line ${Int.toString(opening.row)}`,
                line: opening.row,
                column: String.length(trimmedLine) + 2,
              },
            ))
          } else {
            None
          }
        }
      }
    }
  | _ => None
  }
}

/**
 * Fix MismatchedWidth - extend the shorter border to match the longer one
 *
 * Note: topLeft.row is 1-indexed (from error messages), convert to 0-indexed for array access
 */
let fixMismatchedWidth = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  switch error.code {
  | MismatchedWidth({topLeft, topWidth, bottomWidth}) => {
      let lines = splitLines(text)
      let diff = topWidth - bottomWidth
      // Convert 1-indexed row to 0-indexed for array access
      let topLeftRowIndex = topLeft.row - 1

      if diff === 0 {
        None
      } else {
        // Find the bottom border line
        // We need to trace down from topLeft to find the bottom
        // Note: row here is 0-indexed array index
        let rec findBottomRow = (row: int): option<int> => {
          if row >= Array.length(lines) {
            None
          } else {
            switch getLine(lines, row) {
            | None => None
            | Some(line) => {
                // Check if this line has a '+' at the same column as topLeft
                let col = topLeft.col
                if col < String.length(line) {
                  let char = line->String.charAt(col)
                  if char === "+" && row > topLeftRowIndex {
                    Some(row)
                  } else {
                    findBottomRow(row + 1)
                  }
                } else {
                  findBottomRow(row + 1)
                }
              }
            }
          }
        }

        switch findBottomRow(topLeftRowIndex + 1) {
        | None => None
        | Some(bottomRowIndex) => {
            switch getLine(lines, bottomRowIndex) {
            | None => None
            | Some(bottomLine) => {
                if diff > 0 {
                  // Bottom is shorter, need to extend it
                  // Find the closing '+' and add dashes before it
                  let closingPlusCol = topLeft.col + bottomWidth - 1
                  if closingPlusCol >= 0 && closingPlusCol < String.length(bottomLine) {
                    let before = bottomLine->String.slice(~start=0, ~end=closingPlusCol)
                    let after = bottomLine->String.sliceToEnd(~start=closingPlusCol)
                    let dashes = String.repeat("-", diff)
                    let newLine = before ++ dashes ++ after

                    let newLines = replaceLine(lines, bottomRowIndex, newLine)
                    let fixedText = joinLines(newLines)

                    Some((
                      fixedText,
                      {
                        original: error,
                        description: `Extended bottom border at line ${Int.toString(bottomRowIndex + 1)} by ${Int.toString(diff)} characters`,
                        line: bottomRowIndex + 1,
                        column: closingPlusCol + 1,
                      },
                    ))
                  } else {
                    None
                  }
                } else {
                  // Top is shorter, need to extend it
                  // This is trickier as it affects content alignment
                  // For now, we extend the top border
                  switch getLine(lines, topLeftRowIndex) {
                  | None => None
                  | Some(topLine) => {
                      let closingPlusCol = topLeft.col + topWidth - 1
                      if closingPlusCol >= 0 && closingPlusCol < String.length(topLine) {
                        let before = topLine->String.slice(~start=0, ~end=closingPlusCol)
                        let after = topLine->String.sliceToEnd(~start=closingPlusCol)
                        let dashes = String.repeat("-", Math.Int.abs(diff))
                        let newLine = before ++ dashes ++ after

                        let newLines = replaceLine(lines, topLeftRowIndex, newLine)
                        let fixedText = joinLines(newLines)

                        Some((
                          fixedText,
                          {
                            original: error,
                            description: `Extended top border at line ${Int.toString(topLeft.row)} by ${Int.toString(Math.Int.abs(diff))} characters`,
                            line: topLeft.row,
                            column: closingPlusCol + 1,
                          },
                        ))
                      } else {
                        None
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
  | _ => None
  }
}

// ============================================================================
// Main Fix Function
// ============================================================================

/**
 * List of all fix strategies in order of application
 */
let fixStrategies: array<(string, ErrorTypes.errorCode => bool, (string, ErrorTypes.t) => option<(string, fixedIssue)>)> = [
  ("MisalignedPipe", code => {
    switch code {
    | MisalignedPipe(_) => true
    | _ => false
    }
  }, fixMisalignedPipe),
  ("MisalignedClosingBorder", code => {
    switch code {
    | MisalignedClosingBorder(_) => true
    | _ => false
    }
  }, fixMisalignedClosingBorder),
  ("UnusualSpacing", code => {
    switch code {
    | UnusualSpacing(_) => true
    | _ => false
    }
  }, fixUnusualSpacing),
  ("UnclosedBracket", code => {
    switch code {
    | UnclosedBracket(_) => true
    | _ => false
    }
  }, fixUnclosedBracket),
  ("MismatchedWidth", code => {
    switch code {
    | MismatchedWidth(_) => true
    | _ => false
    }
  }, fixMismatchedWidth),
]

/**
 * Try to fix a single error using available strategies
 */
let tryFixError = (text: string, error: ErrorTypes.t): option<(string, fixedIssue)> => {
  // Find the first strategy that can fix this error
  fixStrategies->Array.reduce(None, (acc, (_, canFix, apply)) => {
    switch acc {
    | Some(_) => acc // Already found a fix
    | None => {
        if canFix(error.code) {
          apply(text, error)
        } else {
          None
        }
      }
    }
  })
}

/**
 * Check if an error code is fixable
 */
let isFixable = (code: ErrorTypes.errorCode): bool => {
  fixStrategies->Array.some(((_, canFix, _)) => canFix(code))
}

/**
 * Main fix function - attempts to fix all errors in the text
 *
 * This function:
 * 1. Parses the text to get errors/warnings
 * 2. Attempts to fix each fixable error
 * 3. Re-parses after each fix to get updated positions
 * 4. Returns the fixed text and list of applied fixes
 *
 * @param text The wireframe markdown text
 * @returns FixResult with fixed text and details
 */
@genType
let fix = (text: string): fixResult => {
  // Maximum iterations to prevent infinite loops
  let maxIterations = 100

  // Recursive fix loop
  let rec fixLoop = (currentText: string, fixedSoFar: array<fixedIssue>, iteration: int): fixResult => {
    if iteration >= maxIterations {
      // Too many iterations, return what we have
      Ok({
        text: currentText,
        fixed: fixedSoFar,
        remaining: [],
      })
    } else {
      // Parse current text to get errors
      let parseResult = Parser.parse(currentText)

      switch parseResult {
      | Ok((_ast, warnings)) => {
          // Parse succeeded, only warnings remain
          // Try to fix warnings
          let fixableWarnings = warnings->Array.filter(w => isFixable(w.code))

          if Array.length(fixableWarnings) === 0 {
            // No more fixable issues
            Ok({
              text: currentText,
              fixed: fixedSoFar,
              remaining: warnings->Array.filter(w => !isFixable(w.code)),
            })
          } else {
            // Try to fix the first fixable warning
            switch fixableWarnings->Array.get(0) {
            | None => Ok({
                text: currentText,
                fixed: fixedSoFar,
                remaining: warnings,
              })
            | Some(warning) => {
                switch tryFixError(currentText, warning) {
                | None => {
                    // Couldn't fix, move on
                    Ok({
                      text: currentText,
                      fixed: fixedSoFar,
                      remaining: warnings,
                    })
                  }
                | Some((newText, fixedIssue)) => {
                    // Fixed! Continue with remaining
                    let newFixed = fixedSoFar->Array.concat([fixedIssue])
                    fixLoop(newText, newFixed, iteration + 1)
                  }
                }
              }
            }
          }
        }
      | Error(errors) => {
          // Parse failed, try to fix errors
          let fixableErrors = errors->Array.filter(e => isFixable(e.code))

          if Array.length(fixableErrors) === 0 {
            // No fixable errors, return what we have
            Ok({
              text: currentText,
              fixed: fixedSoFar,
              remaining: errors->Array.filter(e => !isFixable(e.code)),
            })
          } else {
            // Try to fix the first fixable error
            switch fixableErrors->Array.get(0) {
            | None => Ok({
                text: currentText,
                fixed: fixedSoFar,
                remaining: errors,
              })
            | Some(error) => {
                switch tryFixError(currentText, error) {
                | None => {
                    // Couldn't fix, return remaining errors
                    Ok({
                      text: currentText,
                      fixed: fixedSoFar,
                      remaining: errors,
                    })
                  }
                | Some((newText, fixedIssue)) => {
                    // Fixed! Continue fixing
                    let newFixed = fixedSoFar->Array.concat([fixedIssue])
                    fixLoop(newText, newFixed, iteration + 1)
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Start the fix loop
  fixLoop(text, [], 0)
}

/**
 * Convenience function - fix and return just the fixed text
 * Returns the original text if nothing was fixed
 */
@genType
let fixOnly = (text: string): string => {
  switch fix(text) {
  | Ok({text: fixedText, _}) => fixedText
  | Error(_) => text
  }
}
