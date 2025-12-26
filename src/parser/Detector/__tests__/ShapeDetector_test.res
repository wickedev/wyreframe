// ShapeDetector_test.res
// Integration tests for ShapeDetector module
//
// Tests shape detection including:
// - Single boxes
// - Nested boxes (2-3 levels)
// - Sibling boxes
// - Dividers
// - Box names
// - Malformed boxes (error cases)
//
// Requirements: REQ-25 (Testability - Unit Test Coverage ≥90%)

open Vitest
open Types

// ============================================================================
// Test Helpers
// ============================================================================

/**
 * Create a grid from a multi-line string wireframe.
 * Handles newline splitting and normalization.
 */
let makeGrid = (wireframe: string): Grid.t => {
  wireframe
    ->String.trim
    ->String.split("\n")
    ->Grid.fromLines
}

/**
 * Helper to verify result is Ok and contains expected number of boxes.
 */
let expectOkWithBoxCount = (
  t: Vitest_Types.testCtx,
  result: ShapeDetector.detectResult,
  expectedCount: int
): array<BoxTracer.box> => {
  switch result {
  | Ok((boxes, _warnings)) => {
      t->expect(Array.length(boxes))->Expect.toBe(expectedCount)
      boxes
    }
  | Error(errors) => {
      Console.error("Expected Ok but got Error:")
      errors->Array.forEach(err => {
        Console.error(ErrorTypes.getCodeName(err.code))
      })
      t->expect(true)->Expect.toBe(false) // fail: Expected Ok with boxes, got Error
      []
    }
  }
}

/**
 * Helper to verify result is Error and contains expected number of errors.
 */
let expectErrorWithCount = (
  t: Vitest_Types.testCtx,
  result: ShapeDetector.detectResult,
  minErrorCount: int
): array<ErrorTypes.t> => {
  switch result {
  | Error(errors) => {
      t->expect(Array.length(errors))->Expect.Int.toBeGreaterThanOrEqual(minErrorCount)
      errors
    }
  | Ok((_boxes, _warnings)) => {
      t->expect(true)->Expect.toBe(false) // fail: Expected Error but got Ok
      []
    }
  }
}

// ============================================================================
// SD-01: Single Box Detection
// ============================================================================

describe("ShapeDetector - Single Box", () => {
  test("SD-01: detects a simple box", t => {
    // Create a simple box wireframe
    let wireframe = `
+------+
|      |
+------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let box = boxes[0]->Option.getExn

    // Verify no children and no name
    t->expect(Array.length(box.children))->Expect.toBe(0)
    t->expect(box.name)->Expect.toBe(None)
  })

  test("SD-01b: handles boxes with different dimensions", t => {
    let wireframe = `
+----------+
|          |
|          |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let _ = expectOkWithBoxCount(t, result, 1)
  })
})

// ============================================================================
// SD-02-03: Nested Boxes
// ============================================================================

describe("ShapeDetector - Nested Boxes", () => {
  test("SD-02: detects 2-level nested boxes", t => {
    let wireframe = `
+----------+
|  +----+  |
|  |    |  |
|  +----+  |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let outer = boxes[0]->Option.getExn

    // Outer should have 1 child
    t->expect(Array.length(outer.children))->Expect.toBe(1)

    let inner = outer.children[0]->Option.getExn

    // Verify containment
    t->expect(Bounds.contains(outer.bounds, inner.bounds))->Expect.toBe(true)
  })

  test("SD-03: detects 3-level nested boxes", t => {
    let wireframe = `
+--------------+
| +----------+ |
| | +------+ | |
| | |      | | |
| | +------+ | |
| +----------+ |
+--------------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let outer = boxes[0]->Option.getExn

    t->expect(Array.length(outer.children))->Expect.toBe(1)
    let middle = outer.children[0]->Option.getExn

    t->expect(Array.length(middle.children))->Expect.toBe(1)
    let inner = middle.children[0]->Option.getExn

    t->expect(Array.length(inner.children))->Expect.toBe(0)

    // Verify total count
    let total = ShapeDetector.countBoxes(boxes)
    t->expect(total)->Expect.toBe(3)
  })
})

// ============================================================================
// SD-04: Sibling Boxes
// ============================================================================

describe("ShapeDetector - Sibling Boxes", () => {
  test("SD-04: detects sibling boxes at same level", t => {
    let wireframe = `
+-----+  +-----+
|     |  |     |
+-----+  +-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 2)

    let box1 = boxes[0]->Option.getExn
    let box2 = boxes[1]->Option.getExn

    // Neither contains the other
    t->expect(Bounds.contains(box1.bounds, box2.bounds))->Expect.toBe(false)
    t->expect(Bounds.contains(box2.bounds, box1.bounds))->Expect.toBe(false)

    // No overlap
    t->expect(Bounds.overlaps(box1.bounds, box2.bounds))->Expect.toBe(false)

    // Both have no children
    t->expect(Array.length(box1.children))->Expect.toBe(0)
    t->expect(Array.length(box2.children))->Expect.toBe(0)
  })
})

// ============================================================================
// SD-05-06: Dividers
// ============================================================================

describe("ShapeDetector - Dividers", () => {
  test("SD-05: handles box with single divider", t => {
    let wireframe = `
+-----+
|     |
+=====+
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let _ = expectOkWithBoxCount(t, result, 1)
  })

  test("SD-06: handles box with multiple dividers", t => {
    let wireframe = `
+-----+
|     |
+=====+
|     |
+=====+
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let _ = expectOkWithBoxCount(t, result, 1)
  })
})

// ============================================================================
// SD-07-08: Box Names
// ============================================================================

describe("ShapeDetector - Box Names", () => {
  test("SD-07: extracts box name from top border", t => {
    let wireframe = `
+--Login--+
|         |
+---------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let box = boxes[0]->Option.getExn

    t->expect(box.name)->Expect.toEqual(Some("Login"))
  })

  test("SD-08: handles multiple named boxes", t => {
    let wireframe = `
+--Header--+
|          |
+----------+

+--Content-+
|          |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 2)

    // Find boxes by name
    let hasHeader = boxes->Array.some(box => {
      switch box.name {
      | Some("Header") => true
      | _ => false
      }
    })

    let hasContent = boxes->Array.some(box => {
      switch box.name {
      | Some("Content") => true
      | _ => false
      }
    })

    t->expect(hasHeader)->Expect.toBe(true)
    t->expect(hasContent)->Expect.toBe(true)
  })
})

// ============================================================================
// SD-09-13: Error Cases
// ============================================================================

describe("ShapeDetector - Error Cases", () => {
  test("SD-09: detects unclosed box - missing top corner", t => {
    let wireframe = `
+-----
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(t, result, 1)

    let hasUncloseError = errors->Array.some(err => {
      switch err.code {
      | UncloseBox({direction: "top"}) => true
      | _ => false
      }
    })

    t->expect(hasUncloseError)->Expect.toBe(true)
  })

  test("SD-10: detects unclosed box - missing bottom corner", t => {
    let wireframe = `
+-----+
|     |
+-----
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(t, result, 1)

    let hasUncloseError = errors->Array.some(err => {
      switch err.code {
      | UncloseBox({direction: "bottom"}) => true
      | _ => false
      }
    })

    t->expect(hasUncloseError)->Expect.toBe(true)
  })

  test("SD-11: detects mismatched width", t => {
    let wireframe = `
+-----+
|     |
+-------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(t, result, 1)

    let hasMismatchError = errors->Array.some(err => {
      switch err.code {
      | MismatchedWidth(_) => true
      | _ => false
      }
    })

    t->expect(hasMismatchError)->Expect.toBe(true)
  })

  test("SD-12: detects unclosed box - misaligned left edge", t => {
    // This wireframe has a space at row 2 col 0 where a pipe should be
    // This causes an unclosed box error on the left edge
    let wireframe = `
+-----+
|     |
 |    |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(t, result, 1)

    let hasUncloseError = errors->Array.some(err => {
      switch err.code {
      | UncloseBox({direction: "left"}) => true
      | _ => false
      }
    })

    t->expect(hasUncloseError)->Expect.toBe(true)
  })
})

// ============================================================================
// SD-14: Edge Cases
// ============================================================================

describe("ShapeDetector - Edge Cases", () => {
  test("SD-14: handles empty grid with no boxes", t => {
    let wireframe = `
abc
def
ghi
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    // Should return Ok with empty array
    let _ = expectOkWithBoxCount(t, result, 0)
  })
})

// ============================================================================
// SD-15: Complex Integration Test
// ============================================================================

describe("ShapeDetector - Complex Integration", () => {
  test("SD-15: handles nested structure with sibling inner boxes", t => {
    // Simplified test: outer box with two sibling inner boxes
    let wireframe = `
+----------+
| +--+ +--+|
| |  | |  ||
| +--+ +--+|
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let outer = boxes[0]->Option.getExn

    // Outer box should have 2 sibling children
    t->expect(Array.length(outer.children))->Expect.toBe(2)

    // Verify total count: outer + 2 inner = 3
    let total = ShapeDetector.countBoxes(boxes)
    t->expect(total)->Expect.toBe(3)
  })
})

// ============================================================================
// SD-16-17: Deduplication and Error Recovery
// ============================================================================

describe("ShapeDetector - Deduplication & Error Recovery", () => {
  test("SD-16: deduplicates boxes traced from multiple corners", t => {
    let wireframe = `
+-----+
|     |
+-----+
`
    let grid = makeGrid(wireframe)

    // Verify 4 corners exist
    t->expect(Array.length(grid.cornerIndex))->Expect.toBe(4)

    let result = ShapeDetector.detect(grid)

    // Only 1 unique box
    let _ = expectOkWithBoxCount(t, result, 1)
  })

  test("SD-17: returns valid boxes when some traces succeed (REQ-28)", t => {
    // This wireframe has one valid box and two malformed ones
    // Current implementation returns Ok with valid boxes when some succeed
    let wireframe = `
+---+  +-----
|   |  |     |
+---+  +-----+

+-----+
|     |
+-------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    // Should have at least 1 valid box (the left one: +---+)
    let boxes = expectOkWithBoxCount(t, result, 1)
    t->expect(Array.length(boxes))->Expect.Int.toBeGreaterThanOrEqual(1)
  })
})

// ============================================================================
// SD-18: Helper Functions
// ============================================================================

describe("ShapeDetector - Helper Functions", () => {
  test("SD-18a: countBoxes counts all boxes including nested", t => {
    let wireframe = `
+----------+
| +------+ |
| | +--+ | |
| | |  | | |
| | +--+ | |
| +------+ |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let total = ShapeDetector.countBoxes(boxes)

    t->expect(total)->Expect.toBe(3)
  })

  test("SD-18b: flattenBoxes returns all boxes in flat array", t => {
    let wireframe = `
+----------+
| +------+ |
| | +--+ | |
| | |  | | |
| | +--+ | |
| +------+ |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(t, result, 1)
    let flat = ShapeDetector.flattenBoxes(boxes)

    t->expect(Array.length(flat))->Expect.toBe(3)
  })

  test("SD-18c: getStats returns formatted statistics for Ok result", t => {
    let wireframe = `
+-----+
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let stats = ShapeDetector.getStats(result)

    t->expect(stats->String.includes("Success"))->Expect.toBe(true)
    t->expect(stats->String.includes("Root boxes: 1"))->Expect.toBe(true)
  })

  test("SD-18d: getStats returns formatted statistics for Error result", t => {
    let wireframe = `
+-----
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let stats = ShapeDetector.getStats(result)

    t->expect(stats->String.includes("Failed"))->Expect.toBe(true)
  })

  test("SD-18e: countBoxes handles empty array", t => {
    let emptyBoxes: array<BoxTracer.box> = []
    let count = ShapeDetector.countBoxes(emptyBoxes)

    t->expect(count)->Expect.toBe(0)
  })

  test("SD-18f: flattenBoxes handles empty array", t => {
    let emptyBoxes: array<BoxTracer.box> = []
    let flat = ShapeDetector.flattenBoxes(emptyBoxes)

    t->expect(Array.length(flat))->Expect.toBe(0)
  })
})
