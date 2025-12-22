// HierarchyBuilder.res
// Build hierarchical parent-child relationships between boxes based on spatial containment
// Requirements: REQ-6 (Shape Detector - Nesting Hierarchy Construction)

open Types

// Re-use the box type from BoxTracer
type box = BoxTracer.box

// Hierarchy building errors
type hierarchyError =
  | OverlappingBoxes({
      box1: box,
      box2: box,
    })
  | CircularNesting

// ============================================================================
// Containment Detection
// ============================================================================

/**
 * Check if outer box completely contains inner box.
 * Uses the Bounds.contains function for the actual containment check.
 *
 * A box is considered to contain another if its bounds completely enclose
 * the other box's bounds (strict containment, not touching edges).
 *
 * @param outer - The potentially containing box bounds
 * @param inner - The potentially contained box bounds
 * @return bool - true if outer completely contains inner
 *
 * Requirements: REQ-6 (Nesting Hierarchy Construction)
 */
let contains = (outer: Bounds.t, inner: Bounds.t): bool => {
  Bounds.contains(outer, inner)
}

// ============================================================================
// Parent-Child Relationships
// ============================================================================

/**
 * Find the smallest box that completely contains the given box.
 * This identifies the immediate parent in the hierarchy.
 *
 * Algorithm:
 * 1. Filter candidates to only boxes that contain the target
 * 2. Among containing boxes, find the one with the smallest area
 * 3. Return None if no containing box exists (box is a root)
 *
 * @param target - The box to find a parent for
 * @param candidates - Array of potential parent boxes
 * @return option<box> - Some(parent) if found, None if box is a root
 *
 * Requirements: REQ-6 (Nesting Hierarchy Construction)
 */
let findParent = (target: box, candidates: array<box>): option<box> => {
  // Find all boxes that contain this box
  let containers =
    candidates->Array.filter(candidate => {
      // Don't compare with self
      candidate !== target && contains(candidate.bounds, target.bounds)
    })

  // If no containers, this is a root box
  if Array.length(containers) === 0 {
    None
  } else {
    // Find the smallest container (immediate parent)
    // Sort by area ascending and take the first
    let sorted =
      containers->Array.toSorted((a, b) => {
        let areaA = Bounds.area(a.bounds)
        let areaB = Bounds.area(b.bounds)
        Int.toFloat(areaA - areaB) // Ascending - smallest first
      })

    Array.get(sorted, 0)
  }
}

/**
 * Build parent-child hierarchy from a flat array of boxes.
 *
 * Algorithm:
 * 1. Sort boxes by area (descending) - larger boxes processed first
 * 2. For each box, find its immediate parent (smallest containing box)
 * 3. Populate children arrays by adding child to parent's children
 * 4. Validate no invalid overlaps exist (boxes must be nested or disjoint)
 * 5. Return only root-level boxes (boxes with no parent)
 *
 * This function mutates the children arrays of the boxes to build the hierarchy.
 *
 * @param boxes - Flat array of all boxes detected
 * @return result<array<box>, hierarchyError> - Ok(roots) or Error(overlap)
 *
 * Example hierarchy:
 *   Root1
 *     ├── Child1-1
 *     │     └── Child1-1-1
 *     └── Child1-2
 *   Root2
 *     └── Child2-1
 *
 * Requirements: REQ-6 (Nesting Hierarchy Construction)
 */
let buildHierarchy = (boxes: array<box>): result<array<box>, hierarchyError> => {
  // Step 1: Check for invalid overlapping boxes first (before building hierarchy)
  // Boxes are invalid if they overlap but neither contains the other
  let overlappingPair = boxes->Array.find(box1 => {
    boxes->Array.some(box2 => {
      // Check if boxes are different
      box1 !== box2 &&
      // Not nested (neither contains the other)
      !contains(box1.bounds, box2.bounds) &&
      !contains(box2.bounds, box1.bounds) &&
      // But they overlap
      Bounds.overlaps(box1.bounds, box2.bounds)
    })
  })

  switch overlappingPair {
  | Some(box1) => {
      // Find the specific box2 that overlaps with box1
      let box2 =
        boxes
        ->Array.find(box2 => {
          box1 !== box2 &&
          !contains(box1.bounds, box2.bounds) &&
          !contains(box2.bounds, box1.bounds) &&
          Bounds.overlaps(box1.bounds, box2.bounds)
        })
        ->Belt.Option.getExn // Safe because we just found an overlapping pair

      Error(OverlappingBoxes({box1, box2}))
    }
  | None => {
      // Step 2: Sort by area (descending) for efficient parent finding
      // Larger boxes are processed first as they are potential parents
      let sorted =
        boxes->Array.toSorted((a, b) => {
          let areaA = Bounds.area(a.bounds)
          let areaB = Bounds.area(b.bounds)
          Int.toFloat(areaB - areaA) // Descending - largest first
        })

      // Step 3: Build parent-child relationships
      sorted->Array.forEach(box => {
        // Find immediate parent for this box
        switch findParent(box, sorted) {
        | Some(parent) => {
            // Add this box to parent's children array (mutation)
            parent.children->Array.push(box)->ignore
          }
        | None => ()  // No parent - this is a root box
        }
      })

      // Step 4: Return only root boxes (boxes with no parent)
      // A root box is one that is not in any other box's children array
      let roots = sorted->Array.filter(box => {
        // Check if this box is in any other box's children
        let isChild = sorted->Array.some(candidate => {
          candidate !== box && candidate.children->Array.includes(box)
        })
        !isChild
      })

      Ok(roots)
    }
  }
}

/**
 * Get the depth of nesting for a box (0 for root, 1 for first level child, etc.)
 * Useful for validation and testing.
 *
 * @param box - The box to calculate depth for
 * @param allBoxes - All boxes in the hierarchy (to find parent)
 * @return int - Nesting depth
 */
let rec getDepth = (box: box, allBoxes: array<box>): int => {
  // Find this box's parent
  switch findParent(box, allBoxes) {
  | None => 0 // Root box
  | Some(parent) => 1 + getDepth(parent, allBoxes)
  }
}

// ============================================================================
// Deep Nesting Warning Detection
// ============================================================================

/**
 * Recursively collect deep nesting warnings for boxes exceeding depth threshold.
 *
 * This function traverses the box hierarchy and generates warnings for any box
 * that is nested deeper than the specified threshold (default: 4 levels).
 *
 * Algorithm:
 * 1. Check if current box depth exceeds threshold
 * 2. If yes, create a DeepNesting warning with depth and position
 * 3. Recursively check all children with incremented depth
 * 4. Collect and return all warnings found
 *
 * @param box - The box to check (and its children)
 * @param currentDepth - Current nesting depth (0 for root)
 * @param threshold - Maximum allowed depth before warning (default: 4)
 * @return array<ErrorTypes.t> - Array of deep nesting warnings
 *
 * Example:
 *   Root (depth 0) - OK
 *     Child1 (depth 1) - OK
 *       Child1-1 (depth 2) - OK
 *         Child1-1-1 (depth 3) - OK
 *           Child1-1-1-1 (depth 4) - OK
 *             Child1-1-1-1-1 (depth 5) - WARNING!
 *
 * Requirements: REQ-19 (Deep Nesting Warning)
 */
let rec collectDeepNestingWarnings = (
  box: box,
  currentDepth: int,
  ~threshold: int=4,
): array<ErrorTypes.t> => {
  let warnings = []

  // Check if current box exceeds threshold
  if currentDepth > threshold {
    // Create warning with depth and position information
    let warningCode = ErrorTypes.DeepNesting({
      depth: currentDepth,
      position: {
        row: box.bounds.top,
        col: box.bounds.left,
      },
    })

    // Create ParseError from warning code (no context needed for warnings)
    let warning = ErrorTypes.make(warningCode, None)
    warnings->Array.push(warning)->ignore
  }

  // Recursively check all children with incremented depth
  box.children->Array.forEach(child => {
    let childWarnings = collectDeepNestingWarnings(child, currentDepth + 1, ~threshold)
    childWarnings->Array.forEach(w => warnings->Array.push(w)->ignore)
  })

  warnings
}

/**
 * Scan entire hierarchy and collect all deep nesting warnings.
 *
 * This is the main entry point for deep nesting detection. It processes
 * all root boxes and their entire subtrees.
 *
 * @param roots - Array of root boxes (from buildHierarchy)
 * @param threshold - Maximum allowed depth before warning (default: 4)
 * @return array<ErrorTypes.t> - All deep nesting warnings found
 *
 * Requirements: REQ-19 (Deep Nesting Warning)
 */
let detectDeepNesting = (roots: array<box>, ~threshold: int=4): array<ErrorTypes.t> => {
  let allWarnings = []

  // Process each root tree
  roots->Array.forEach(root => {
    // Root boxes start at depth 0
    let warnings = collectDeepNestingWarnings(root, 0, ~threshold)
    warnings->Array.forEach(w => allWarnings->Array.push(w)->ignore)
  })

  allWarnings
}

/**
 * Get maximum nesting depth in the entire hierarchy.
 * Useful for metrics, validation, and testing.
 *
 * @param roots - Array of root boxes
 * @return int - Maximum depth found (0 if no boxes)
 */
let getMaxDepth = (roots: array<box>): int => {
  let maxDepth = ref(0)

  let rec traverse = (box: box, depth: int) => {
    if depth > maxDepth.contents {
      maxDepth := depth
    }

    box.children->Array.forEach(child => traverse(child, depth + 1))
  }

  roots->Array.forEach(root => traverse(root, 0))

  maxDepth.contents
}

/**
 * Create a box for testing purposes.
 *
 * @param name - Optional box name
 * @param bounds - Bounding box coordinates
 * @return box - New box instance with empty children array
 */
let makeBox = (~name: option<string>=?, bounds: Bounds.t): box => {
  {
    name: name,
    bounds: bounds,
    children: [],
  }
}
