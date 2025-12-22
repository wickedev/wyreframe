// ShapeDetector.res
// Main Shape Detector Module - Stage 2 of the parser pipeline
//
// Integrates BoxTracer, DividerDetector, and HierarchyBuilder to:
// 1. Find all boxes in the grid
// 2. Detect dividers within boxes
// 3. Build nesting hierarchy
// 4. Collect all errors without early stopping
//
// Requirements:
// - REQ-28: Reliability - Error Recovery (collect all errors)
// - Task 18: Implement ShapeDetector Main Module

open Types

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * Result type for shape detection.
 * Returns either:
 * - Ok(boxes): Array of root-level boxes with nested hierarchy
 * - Error(errors): Array of all errors encountered during detection
 */
type detectResult = result<array<BoxTracer.box>, array<ErrorTypes.t>>

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Convert HierarchyBuilder.hierarchyError to ErrorTypes.t
 */
let hierarchyErrorToParseError = (error: HierarchyBuilder.hierarchyError): ErrorTypes.t => {
  switch error {
  | OverlappingBoxes({box1, box2}) =>
    ErrorTypes.make(
      InvalidElement({
        content: `Overlapping boxes detected at (${Int.toString(box1.bounds.top)},${Int.toString(
            box1.bounds.left,
          )}) and (${Int.toString(box2.bounds.top)},${Int.toString(box2.bounds.left)})`,
        position: {row: box1.bounds.top, col: box1.bounds.left},
      }),
      None,
    )
  | CircularNesting =>
    ErrorTypes.make(
      InvalidElement({
        content: "Circular nesting detected in box hierarchy",
        position: {row: 0, col: 0},
      }),
      None,
    )
  }
}

// ============================================================================
// Helper Functions (must be defined before detect)
// ============================================================================

/**
 * Remove duplicate boxes that have the same bounds.
 *
 * This handles the case where multiple corners might trace the same box.
 * We keep only the first occurrence of each unique box.
 *
 * @param boxes - Array of traced boxes
 * @return Array of unique boxes (deduplicated by bounds)
 */
let deduplicateBoxes = (boxes: array<BoxTracer.box>): array<BoxTracer.box> => {
  let seen = []
  let unique = []

  boxes->Array.forEach(box => {
    // Check if we've seen a box with these bounds before
    let isDuplicate = seen->Array.some(seenBounds => {
      Bounds.equals(seenBounds, box.bounds)
    })

    if !isDuplicate {
      // New unique box
      unique->Array.push(box)
      seen->Array.push(box.bounds)
    }
  })

  unique
}

// ============================================================================
// Main Detection Function (Task 18)
// ============================================================================

/**
 * Detect all shapes (boxes, dividers) in the grid and build hierarchy.
 *
 * Algorithm:
 * 1. Find all '+' corner positions using grid.cornerIndex
 * 2. For each corner, attempt to trace a box using BoxTracer
 * 3. Collect all successfully traced boxes
 * 4. For each box, detect dividers within its bounds
 * 5. Build parent-child hierarchy using HierarchyBuilder
 * 6. Return Result with boxes or errors
 *
 * IMPORTANT: Not all '+' corners are top-left corners of boxes.
 * A '+' can be a top-right, bottom-left, bottom-right corner, or
 * part of nested box structure. traceBox failures for non-top-left
 * corners are EXPECTED and should NOT be treated as errors.
 *
 * @param grid - The 2D character grid from GridScanner
 * @return detectResult - Ok(root boxes) or Error(all errors)
 *
 * Requirements: REQ-28 (Error Recovery - no early stopping)
 */
let detect = (grid: Grid.t): detectResult => {
  // Step 1: Find all '+' corner positions using pre-built index
  let corners = grid.cornerIndex

  // Step 2: Trace boxes from each corner
  // Note: Most corners will NOT be valid top-left corners, which is expected.
  // Only corners that are actually top-left of a box will trace successfully.
  let boxes = []
  let _traceFailures = [] // Keep track of failures for debugging only

  corners->Array.forEach(corner => {
    switch BoxTracer.traceBox(grid, corner) {
    | Ok(box) => {
        // Successfully traced a box - add to collection
        boxes->Array.push(box)
      }
    | Error(_traceError) => {
        // This corner is not a valid top-left of a box.
        // This is NORMAL - most '+' characters are not top-left corners.
        // Don't treat this as an error.
        _traceFailures->Array.push(_traceError)
      }
    }
  })

  // Step 3: Check if we found any boxes
  if Array.length(boxes) === 0 {
    // No boxes traced successfully
    // This could mean:
    // 1. The wireframe has no boxes (valid but empty)
    // 2. All box structures are malformed
    // Return empty array (no boxes) - this is not necessarily an error
    Ok([])
  } else {
    // Step 4: Detect dividers for each successfully traced box
    // TODO: Implement when DividerDetector module is available

    // Step 5: Remove duplicate boxes (same bounds traced multiple times)
    let uniqueBoxes = deduplicateBoxes(boxes)

    // Step 6: Build hierarchy using HierarchyBuilder
    switch HierarchyBuilder.buildHierarchy(uniqueBoxes) {
    | Ok(rootBoxes) => {
        // Hierarchy built successfully - return the boxes
        Ok(rootBoxes)
      }
    | Error(hierarchyError) => {
        // Hierarchy building failed (e.g., overlapping boxes)
        // This IS a real error that should be reported
        let parseError = hierarchyErrorToParseError(hierarchyError)
        Error([parseError])
      }
    }
  }
}

// ============================================================================
// Additional Helper Functions
// ============================================================================

/**
 * Count total number of boxes including nested children.
 *
 * @param boxes - Array of boxes (can include nested children)
 * @return Total count of all boxes
 */
let rec countBoxes = (boxes: array<BoxTracer.box>): int => {
  boxes->Array.reduce(0, (acc, box) => {
    1 + acc + countBoxes(box.children)
  })
}

/**
 * Get all boxes as a flat array (including nested children).
 *
 * @param boxes - Array of root boxes
 * @return Flat array of all boxes
 */
let rec flattenBoxes = (boxes: array<BoxTracer.box>): array<BoxTracer.box> => {
  boxes->Array.reduce([], (acc, box) => {
    let childBoxes = flattenBoxes(box.children)
    Array.concat(Array.concat(acc, [box]), childBoxes)
  })
}

/**
 * Get statistics about detected shapes for debugging.
 *
 * @param result - Detection result
 * @return String with statistics
 */
let getStats = (result: detectResult): string => {
  switch result {
  | Ok(boxes) => {
      let rootCount = Array.length(boxes)
      let totalCount = countBoxes(boxes)
      `Shape Detection Success:
  Root boxes: ${Int.toString(rootCount)}
  Total boxes (including nested): ${Int.toString(totalCount)}`
    }
  | Error(errors) => {
      let errorCount = Array.length(errors)
      let warningCount = errors->Array.reduce(0, (acc, err) => {
        if ErrorTypes.isWarning(err) {
          acc + 1
        } else {
          acc
        }
      })
      let realErrorCount = errorCount - warningCount

      `Shape Detection Failed:
  Errors: ${Int.toString(realErrorCount)}
  Warnings: ${Int.toString(warningCount)}`
    }
  }
}
