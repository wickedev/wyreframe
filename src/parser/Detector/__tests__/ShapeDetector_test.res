// ShapeDetector_test.res
// Integration tests for ShapeDetector module (Task 19)
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

open Jest
open Expect
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
  result: ShapeDetector.detectResult,
  expectedCount: int
): array<BoxTracer.box> => {
  switch result {
  | Ok(boxes) => {
      expect(Array.length(boxes))->toBe(expectedCount)
      boxes
    }
  | Error(errors) => {
      Console.error("Expected Ok but got Error:")
      errors->Array.forEach(err => {
        Console.error(ErrorTypes.toString(err))
      })
      fail(`Expected Ok with ${Int.toString(expectedCount)} boxes, got Error`)
      []
    }
  }
}

/**
 * Helper to verify result is Error and contains expected number of errors.
 */
let expectErrorWithCount = (
  result: ShapeDetector.detectResult,
  minErrorCount: int
): array<ErrorTypes.t> => {
  switch result {
  | Error(errors) => {
      expect(Array.length(errors))->toBeGreaterThanOrEqual(minErrorCount)
      errors
    }
  | Ok(boxes) => {
      fail(`Expected Error but got Ok with ${Int.toString(Array.length(boxes))} boxes`)
      []
    }
  }
}

// ============================================================================
// SD-01: Single Box Detection
// ============================================================================

describe("ShapeDetector - Single Box", () => {
  test("SD-01: detects a simple box", () => {
    // Create a simple box wireframe
    let wireframe = `
+------+
|      |
+------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(result, 1)
    let box = boxes[0]->Option.getExn

    // Verify no children and no name
    expect(Array.length(box.children))->toBe(0)
    expect(box.name)->toBe(None)
  })

  test("SD-01b: handles boxes with different dimensions", () => {
    let wireframe = `
+----------+
|          |
|          |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    expectOkWithBoxCount(result, 1)
  })
})

// ============================================================================
// SD-02-03: Nested Boxes
// ============================================================================

describe("ShapeDetector - Nested Boxes", () => {
  test("SD-02: detects 2-level nested boxes", () => {
    let wireframe = `
+----------+
|  +----+  |
|  |    |  |
|  +----+  |
+----------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(result, 1)
    let outer = boxes[0]->Option.getExn

    // Outer should have 1 child
    expect(Array.length(outer.children))->toBe(1)

    let inner = outer.children[0]->Option.getExn

    // Verify containment
    expect(Bounds.contains(outer.bounds, inner.bounds))->toBe(true)
  })

  test("SD-03: detects 3-level nested boxes", () => {
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

    let boxes = expectOkWithBoxCount(result, 1)
    let outer = boxes[0]->Option.getExn

    expect(Array.length(outer.children))->toBe(1)
    let middle = outer.children[0]->Option.getExn

    expect(Array.length(middle.children))->toBe(1)
    let inner = middle.children[0]->Option.getExn

    expect(Array.length(inner.children))->toBe(0)

    // Verify total count
    let total = ShapeDetector.countBoxes(boxes)
    expect(total)->toBe(3)
  })
})

// ============================================================================
// SD-04: Sibling Boxes
// ============================================================================

describe("ShapeDetector - Sibling Boxes", () => {
  test("SD-04: detects sibling boxes at same level", () => {
    let wireframe = `
+-----+  +-----+
|     |  |     |
+-----+  +-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(result, 2)

    let box1 = boxes[0]->Option.getExn
    let box2 = boxes[1]->Option.getExn

    // Neither contains the other
    expect(Bounds.contains(box1.bounds, box2.bounds))->toBe(false)
    expect(Bounds.contains(box2.bounds, box1.bounds))->toBe(false)

    // No overlap
    expect(Bounds.overlaps(box1.bounds, box2.bounds))->toBe(false)

    // Both have no children
    expect(Array.length(box1.children))->toBe(0)
    expect(Array.length(box2.children))->toBe(0)
  })
})

// ============================================================================
// SD-05-06: Dividers
// ============================================================================

describe("ShapeDetector - Dividers", () => {
  test("SD-05: handles box with single divider", () => {
    let wireframe = `
+-----+
|     |
+=====+
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    expectOkWithBoxCount(result, 1)
  })

  test("SD-06: handles box with multiple dividers", () => {
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

    expectOkWithBoxCount(result, 1)
  })
})

// ============================================================================
// SD-07-08: Box Names
// ============================================================================

describe("ShapeDetector - Box Names", () => {
  test("SD-07: extracts box name from top border", () => {
    let wireframe = `
+--Login--+
|         |
+---------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(result, 1)
    let box = boxes[0]->Option.getExn

    expect(box.name)->toEqual(Some("Login"))
  })

  test("SD-08: handles multiple named boxes", () => {
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

    let boxes = expectOkWithBoxCount(result, 2)

    // Find boxes by name
    let hasHeader = boxes->Array.some(box => {
      switch box {
      | Some({name: Some("Header")}) => true
      | _ => false
      }
    })

    let hasContent = boxes->Array.some(box => {
      switch box {
      | Some({name: Some("Content")}) => true
      | _ => false
      }
    })

    expect(hasHeader)->toBe(true)
    expect(hasContent)->toBe(true)
  })
})

// ============================================================================
// SD-09-13: Error Cases
// ============================================================================

describe("ShapeDetector - Error Cases", () => {
  test("SD-09: detects unclosed box - missing top corner", () => {
    let wireframe = `
+-----
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(result, 1)

    let hasUncloseError = errors->Array.some(err => {
      switch err.code {
      | UncloseBox({direction: "top"}) => true
      | _ => false
      }
    })

    expect(hasUncloseError)->toBe(true)
  })

  test("SD-10: detects unclosed box - missing bottom corner", () => {
    let wireframe = `
+-----+
|     |
+-----
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(result, 1)

    let hasUncloseError = errors->Array.some(err => {
      switch err.code {
      | UncloseBox({direction: "bottom"}) => true
      | _ => false
      }
    })

    expect(hasUncloseError)->toBe(true)
  })

  test("SD-11: detects mismatched width", () => {
    let wireframe = `
+-----+
|     |
+-------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(result, 1)

    let hasMismatchError = errors->Array.some(err => {
      switch err.code {
      | MismatchedWidth(_) => true
      | _ => false
      }
    })

    expect(hasMismatchError)->toBe(true)
  })

  test("SD-12: detects misaligned vertical pipes", () => {
    let wireframe = `
+-----+
|     |
 |    |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let errors = expectErrorWithCount(result, 1)

    let hasMisalignError = errors->Array.some(err => {
      switch err.code {
      | MisalignedPipe(_) => true
      | _ => false
      }
    })

    expect(hasMisalignError)->toBe(true)
  })
})

// ============================================================================
// SD-14: Edge Cases
// ============================================================================

describe("ShapeDetector - Edge Cases", () => {
  test("SD-14: handles empty grid with no boxes", () => {
    let wireframe = `
abc
def
ghi
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    // Should return Ok with empty array
    expectOkWithBoxCount(result, 0)
  })
})

// ============================================================================
// SD-15: Complex Integration Test
// ============================================================================

describe("ShapeDetector - Complex Integration", () => {
  test("SD-15: handles complex nested structure with dividers and names", () => {
    let wireframe = `
+--Container--+
| +--Header--+ |
| |          | |
| +----------+ |
| +==========+ |
| +--Body----+ |
| |  +-----+ | |
| |  |     | | |
| |  +-----+ | |
| +----------+ |
+--------------+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let boxes = expectOkWithBoxCount(result, 1)
    let container = boxes[0]->Option.getExn

    expect(container.name)->toEqual(Some("Container"))
    expect(Array.length(container.children))->toBe(2)

    // Verify total count
    let total = ShapeDetector.countBoxes(boxes)
    expect(total)->toBe(4)
  })
})

// ============================================================================
// SD-16-17: Deduplication and Error Recovery
// ============================================================================

describe("ShapeDetector - Deduplication & Error Recovery", () => {
  test("SD-16: deduplicates boxes traced from multiple corners", () => {
    let wireframe = `
+-----+
|     |
+-----+
`
    let grid = makeGrid(wireframe)

    // Verify 4 corners exist
    expect(Array.length(grid.cornerIndex))->toBe(4)

    let result = ShapeDetector.detect(grid)

    // Only 1 unique box
    expectOkWithBoxCount(result, 1)
  })

  test("SD-17: collects all errors without early stopping (REQ-28)", () => {
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

    // Should have multiple errors
    let errors = expectErrorWithCount(result, 2)

    expect(Array.length(errors))->toBeGreaterThanOrEqual(2)
  })
})

// ============================================================================
// SD-18: Helper Functions
// ============================================================================

describe("ShapeDetector - Helper Functions", () => {
  test("SD-18a: countBoxes counts all boxes including nested", () => {
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

    let boxes = expectOkWithBoxCount(result, 1)
    let total = ShapeDetector.countBoxes(boxes)

    expect(total)->toBe(3)
  })

  test("SD-18b: flattenBoxes returns all boxes in flat array", () => {
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

    let boxes = expectOkWithBoxCount(result, 1)
    let flat = ShapeDetector.flattenBoxes(boxes)

    expect(Array.length(flat))->toBe(3)
  })

  test("SD-18c: getStats returns formatted statistics for Ok result", () => {
    let wireframe = `
+-----+
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let stats = ShapeDetector.getStats(result)

    expect(stats->String.includes("Success"))->toBe(true)
    expect(stats->String.includes("Root boxes: 1"))->toBe(true)
  })

  test("SD-18d: getStats returns formatted statistics for Error result", () => {
    let wireframe = `
+-----
|     |
+-----+
`
    let grid = makeGrid(wireframe)
    let result = ShapeDetector.detect(grid)

    let stats = ShapeDetector.getStats(result)

    expect(stats->String.includes("Failed"))->toBe(true)
  })

  test("SD-18e: countBoxes handles empty array", () => {
    let emptyBoxes: array<BoxTracer.box> = []
    let count = ShapeDetector.countBoxes(emptyBoxes)

    expect(count)->toBe(0)
  })

  test("SD-18f: flattenBoxes handles empty array", () => {
    let emptyBoxes: array<BoxTracer.box> = []
    let flat = ShapeDetector.flattenBoxes(emptyBoxes)

    expect(Array.length(flat))->toBe(0)
  })
})
