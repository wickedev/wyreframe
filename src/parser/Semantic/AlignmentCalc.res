// AlignmentCalc.res
// Alignment calculation module for determining element positioning within boxes

open Types

/**
 * Calculates the horizontal alignment of an element based on its position
 * within a box's boundaries.
 *
 * Algorithm:
 * 1. Calculate the space to the left and right of the content
 * 2. Convert these to ratios relative to the box interior width
 * 3. Apply threshold rules to determine alignment:
 *    - Left: Element is close to left edge (leftRatio < 0.2 && rightRatio > 0.3)
 *    - Right: Element is close to right edge (rightRatio < 0.2 && leftRatio > 0.3)
 *    - Center: Element is roughly centered (abs(leftRatio - rightRatio) < 0.15)
 *    - Default to Left if no conditions match
 *
 * @param content The text content of the element
 * @param position The grid position where the content starts
 * @param boxBounds The bounding box containing the element
 * @return alignment The calculated alignment (Left, Center, or Right)
 */
let calculate = (
  content: string,
  position: Position.t,
  boxBounds: Bounds.t,
): Types.alignment => {
  // Trim content to get actual content length
  let trimmed = content->String.trim
  let contentStart = position.col
  let contentEnd = contentStart + String.length(trimmed)

  // Box interior bounds (excluding border characters '|' on both sides)
  // boxBounds.left is the column of the left '|', so interior starts at left + 1
  // boxBounds.right is the column of the right '|', so interior ends at right - 1
  let boxLeft = boxBounds.left + 1
  let boxRight = boxBounds.right - 1
  let boxWidth = boxRight - boxLeft

  // Handle edge case: box is too narrow (width <= 0)
  if boxWidth <= 0 {
    Left
  } else {
    // Calculate space on each side
    let leftSpace = contentStart - boxLeft
    let rightSpace = boxRight - contentEnd

    // Convert to ratios (0.0 to 1.0) relative to box width
    let leftRatio = Int.toFloat(leftSpace) /. Int.toFloat(boxWidth)
    let rightRatio = Int.toFloat(rightSpace) /. Int.toFloat(boxWidth)

    // Thresholds for alignment detection
    let leftThreshold = 0.2
    let rightThreshold = 0.2
    let centerTolerance = 0.15

    // Apply alignment rules
    if leftRatio < leftThreshold && rightRatio > 0.3 {
      // Element is close to left edge with significant space on right
      Left
    } else if rightRatio < rightThreshold && leftRatio > 0.3 {
      // Element is close to right edge with significant space on left
      Right
    } else if Math.abs(leftRatio -. rightRatio) < centerTolerance {
      // Element is roughly centered (ratios are similar)
      Center
    } else {
      // Default to left alignment
      Left
    }
  }
}

/**
 * Alignment strategy determines how alignment should be calculated.
 *
 * - RespectPosition: Use position-based alignment calculation (buttons, links, emphasis)
 * - AlwaysLeft: Always return Left alignment regardless of position (text, checkboxes, inputs)
 */
type alignmentStrategy =
  | RespectPosition // Buttons, links, emphasis text
  | AlwaysLeft // Regular text, checkboxes, inputs

/**
 * Calculates alignment with a specific strategy.
 *
 * @param content The text content of the element
 * @param position The grid position where the content starts
 * @param boxBounds The bounding box containing the element
 * @param strategy The alignment strategy to use
 * @return alignment The calculated alignment
 */
let calculateWithStrategy = (
  content: string,
  position: Position.t,
  boxBounds: Bounds.t,
  strategy: alignmentStrategy,
): Types.alignment => {
  switch strategy {
  | RespectPosition => calculate(content, position, boxBounds)
  | AlwaysLeft => Left
  }
}
