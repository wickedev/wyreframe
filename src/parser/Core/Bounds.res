// Bounds.res
// Bounding box representation for rectangular regions

type t = {
  top: int,
  left: int,
  bottom: int,
  right: int,
}

// Create a bounding box with validation
// Validates that top < bottom and left < right
let make = (~top: int, ~left: int, ~bottom: int, ~right: int): option<t> => {
  if top < bottom && left < right {
    Some({top, left, bottom, right})
  } else {
    None
  }
}

// Calculate width of the bounding box
let width = (bounds: t): int => {
  bounds.right - bounds.left
}

// Calculate height of the bounding box
let height = (bounds: t): int => {
  bounds.bottom - bounds.top
}

// Calculate area of the bounding box
let area = (bounds: t): int => {
  width(bounds) * height(bounds)
}

// Check if outer completely contains inner
// Returns true if outer's bounds completely enclose inner's bounds
let contains = (outer: t, inner: t): bool => {
  outer.top < inner.top &&
  outer.left < inner.left &&
  outer.bottom > inner.bottom &&
  outer.right > inner.right
}

// Check if two bounding boxes overlap (partially or completely)
// Returns true if there is any intersection between the two boxes
let overlaps = (a: t, b: t): bool => {
  // No overlap if:
  // - a is completely to the left of b (a.right <= b.left)
  // - a is completely to the right of b (a.left >= b.right)
  // - a is completely above b (a.bottom <= b.top)
  // - a is completely below b (a.top >= b.bottom)
  // Overlap exists if none of the above conditions are true
  !(a.right <= b.left || a.left >= b.right || a.bottom <= b.top || a.top >= b.bottom)
}

// Convert bounds to string for debugging
let toString = (bounds: t): string => {
  `Bounds{top: ${Int.toString(bounds.top)}, left: ${Int.toString(bounds.left)}, bottom: ${Int.toString(bounds.bottom)}, right: ${Int.toString(bounds.right)}}`
}

// Check if two bounds are equal
let equals = (a: t, b: t): bool => {
  a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right
}
