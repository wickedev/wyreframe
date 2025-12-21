// HierarchyBuilder.res
// Module for building hierarchical relationships between boxes based on spatial containment

// Check if outer box completely contains inner box
// Returns true only if outer completely encloses inner (strict containment)
//
// Containment rules:
// - outer.top must be strictly less than inner.top (outer starts above inner)
// - outer.left must be strictly less than inner.left (outer starts to the left of inner)
// - outer.bottom must be strictly greater than inner.bottom (outer ends below inner)
// - outer.right must be strictly greater than inner.right (outer ends to the right of inner)
//
// Returns false for:
// - Partially overlapping boxes
// - Equal bounds (same box)
// - Disjoint boxes (no overlap)
let contains = (outer: Bounds.t, inner: Bounds.t): bool => {
  outer.top < inner.top &&
  outer.left < inner.left &&
  outer.bottom > inner.bottom &&
  outer.right > inner.right
}
