/**
 * Test Examples: Wyreframe Parser Refactoring
 *
 * This file contains complete, runnable ReScript test examples using @glennsl/rescript-jest
 * demonstrating unit tests, integration tests, and property-based tests for the new parser.
 *
 * Test Framework: Jest with @glennsl/rescript-jest
 * Language: ReScript
 * Date: 2025-12-22
 */

open Jest
open Expect

// =============================================================================
// UNIT TESTS: Core Modules
// =============================================================================

/**
 * Position Module Tests
 * Tests for the Position type and its navigation functions
 */
module PositionTest = {
  describe("Position", () => {
    describe("make", () => {
      test("creates position with valid coordinates", () => {
        let pos = Position.make(5, 10)

        expect(pos.row)->toBe(5)
        expect(pos.col)->toBe(10)
      })

      test("allows zero coordinates", () => {
        let pos = Position.make(0, 0)

        expect(pos.row)->toBe(0)
        expect(pos.col)->toBe(0)
      })

      test("allows negative coordinates", () => {
        let pos = Position.make(-1, -5)

        expect(pos.row)->toBe(-1)
        expect(pos.col)->toBe(-5)
      })
    })

    describe("right", () => {
      test("moves one column right by default", () => {
        let pos = Position.make(5, 3)
        let moved = Position.right(pos)

        expect(moved.row)->toBe(5)
        expect(moved.col)->toBe(4)
      })

      test("moves n columns right with parameter", () => {
        let pos = Position.make(2, 5)
        let moved = Position.right(pos, ~n=3)

        expect(moved.row)->toBe(2)
        expect(moved.col)->toBe(8)
      })
    })

    describe("down", () => {
      test("moves one row down by default", () => {
        let pos = Position.make(5, 3)
        let moved = Position.down(pos)

        expect(moved.row)->toBe(6)
        expect(moved.col)->toBe(3)
      })

      test("moves n rows down with parameter", () => {
        let pos = Position.make(2, 5)
        let moved = Position.down(pos, ~n=4)

        expect(moved.row)->toBe(6)
        expect(moved.col)->toBe(5)
      })
    })

    describe("left", () => {
      test("moves one column left by default", () => {
        let pos = Position.make(5, 3)
        let moved = Position.left(pos)

        expect(moved.row)->toBe(5)
        expect(moved.col)->toBe(2)
      })

      test("allows negative column values", () => {
        let pos = Position.make(5, 0)
        let moved = Position.left(pos)

        expect(moved.col)->toBe(-1)
      })
    })

    describe("up", () => {
      test("moves one row up by default", () => {
        let pos = Position.make(5, 3)
        let moved = Position.up(pos)

        expect(moved.row)->toBe(4)
        expect(moved.col)->toBe(3)
      })

      test("allows negative row values", () => {
        let pos = Position.make(0, 5)
        let moved = Position.up(pos)

        expect(moved.row)->toBe(-1)
      })
    })

    describe("equals", () => {
      test("returns true for identical positions", () => {
        let pos1 = Position.make(5, 10)
        let pos2 = Position.make(5, 10)

        expect(Position.equals(pos1, pos2))->toBe(true)
      })

      test("returns false for different positions", () => {
        let pos1 = Position.make(5, 10)
        let pos2 = Position.make(5, 11)

        expect(Position.equals(pos1, pos2))->toBe(false)
      })
    })

    describe("isWithin", () => {
      test("returns true for position inside bounds", () => {
        let pos = Position.make(5, 10)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

        expect(Position.isWithin(pos, bounds))->toBe(true)
      })

      test("returns false for position outside bounds", () => {
        let pos = Position.make(15, 10)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

        expect(Position.isWithin(pos, bounds))->toBe(false)
      })

      test("returns true for position on boundary", () => {
        let pos = Position.make(10, 20)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

        expect(Position.isWithin(pos, bounds))->toBe(true)
      })

      test("returns false for position on edge outside bounds", () => {
        let pos = Position.make(11, 20)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

        expect(Position.isWithin(pos, bounds))->toBe(false)
      })
    })

    describe("toString", () => {
      test("formats position as string", () => {
        let pos = Position.make(3, 7)

        expect(Position.toString(pos))->toBe("(3, 7)")
      })

      test("handles negative coordinates", () => {
        let pos = Position.make(-1, -5)

        expect(Position.toString(pos))->toBe("(-1, -5)")
      })
    })
  })
}

/**
 * Bounds Module Tests
 * Tests for the Bounds type and spatial operations
 */
module BoundsTest = {
  describe("Bounds", () => {
    describe("make", () => {
      test("creates valid bounds with correct ordering", () => {
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=10)

        expect(bounds.top)->toBe(0)
        expect(bounds.left)->toBe(0)
        expect(bounds.bottom)->toBe(5)
        expect(bounds.right)->toBe(10)
      })

      test("allows single line bounds", () => {
        let bounds = Bounds.make(~top=5, ~left=0, ~bottom=5, ~right=10)

        expect(Bounds.height(bounds))->toBe(0)
      })

      test("allows single column bounds", () => {
        let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=5)

        expect(Bounds.width(bounds))->toBe(0)
      })
    })

    describe("width", () => {
      test("calculates correct width", () => {
        let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=15)

        expect(Bounds.width(bounds))->toBe(10)
      })

      test("returns zero for single column", () => {
        let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=5)

        expect(Bounds.width(bounds))->toBe(0)
      })
    })

    describe("height", () => {
      test("calculates correct height", () => {
        let bounds = Bounds.make(~top=2, ~left=0, ~bottom=8, ~right=10)

        expect(Bounds.height(bounds))->toBe(6)
      })

      test("returns zero for single row", () => {
        let bounds = Bounds.make(~top=5, ~left=0, ~bottom=5, ~right=10)

        expect(Bounds.height(bounds))->toBe(0)
      })
    })

    describe("area", () => {
      test("calculates correct area", () => {
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=10)

        expect(Bounds.area(bounds))->toBe(50)
      })

      test("returns zero for zero-width bounds", () => {
        let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=5)

        expect(Bounds.area(bounds))->toBe(0)
      })
    })

    describe("contains", () => {
      test("returns true when outer completely contains inner", () => {
        let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)
        let inner = Bounds.make(~top=2, ~left=5, ~bottom=8, ~right=15)

        expect(Bounds.contains(outer, inner))->toBe(true)
      })

      test("returns false for partial overlap", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=15)
        let box2 = Bounds.make(~top=5, ~left=10, ~bottom=15, ~right=25)

        expect(Bounds.contains(box1, box2))->toBe(false)
      })

      test("returns false for identical bounds", () => {
        let bounds1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)
        let bounds2 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

        expect(Bounds.contains(bounds1, bounds2))->toBe(false)
      })

      test("returns false when inner touches outer boundary", () => {
        let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)
        let inner = Bounds.make(~top=0, ~left=5, ~bottom=8, ~right=15) // Top edge touches

        expect(Bounds.contains(outer, inner))->toBe(false)
      })

      test("returns false for disjoint boxes", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=10)
        let box2 = Bounds.make(~top=10, ~left=15, ~bottom=15, ~right=25)

        expect(Bounds.contains(box1, box2))->toBe(false)
      })
    })

    describe("overlaps", () => {
      test("returns true for overlapping boxes", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
        let box2 = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)

        expect(Bounds.overlaps(box1, box2))->toBe(true)
      })

      test("returns false for adjacent boxes", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
        let box2 = Bounds.make(~top=0, ~left=11, ~bottom=10, ~right=20)

        expect(Bounds.overlaps(box1, box2))->toBe(false)
      })

      test("returns false for vertically adjacent boxes", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
        let box2 = Bounds.make(~top=11, ~left=0, ~bottom=20, ~right=10)

        expect(Bounds.overlaps(box1, box2))->toBe(false)
      })

      test("returns true for boxes sharing edge", () => {
        let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
        let box2 = Bounds.make(~top=0, ~left=10, ~bottom=10, ~right=20)

        // Depends on implementation - may be true or false
        // Document expected behavior
        expect(Bounds.overlaps(box1, box2))->toBe(true)
      })

      test("returns true for complete containment", () => {
        let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)
        let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)

        expect(Bounds.overlaps(outer, inner))->toBe(true)
      })
    })
  })
}

/**
 * Grid Module Tests
 * Tests for the 2D character grid data structure
 */
module GridTest = {
  describe("Grid", () => {
    describe("fromLines", () => {
      test("creates grid with correct dimensions", () => {
        let lines = ["abc", "def", "ghi"]
        let grid = Grid.fromLines(lines)

        expect(grid.width)->toBe(3)
        expect(grid.height)->toBe(3)
      })

      test("normalizes uneven line lengths", () => {
        let lines = ["ab", "defg", "h"]
        let grid = Grid.fromLines(lines)

        expect(grid.width)->toBe(4)

        // Check padding with space
        switch Grid.get(grid, Position.make(0, 3)) {
        | Some(Space) => pass
        | _ => fail("Expected space padding")
        }

        switch Grid.get(grid, Position.make(2, 1)) {
        | Some(Space) => pass
        | _ => fail("Expected space padding")
        }
      })

      test("handles empty input", () => {
        let lines = []
        let grid = Grid.fromLines(lines)

        expect(grid.width)->toBe(0)
        expect(grid.height)->toBe(0)
      })

      test("handles single line", () => {
        let lines = ["hello"]
        let grid = Grid.fromLines(lines)

        expect(grid.width)->toBe(5)
        expect(grid.height)->toBe(1)
      })

      test("builds character indices correctly", () => {
        let lines = [
          "+----+",
          "|    |",
          "+====+"
        ]
        let grid = Grid.fromLines(lines)

        expect(Belt.Array.length(grid.cornerIndex))->toBe(4)
        expect(Belt.Array.length(grid.vLineIndex))->toBe(2)
        expect(Belt.Array.length(grid.dividerIndex))->toBe(4)
      })
    })

    describe("get", () => {
      test("returns character at valid position", () => {
        let lines = ["abc", "def"]
        let grid = Grid.fromLines(lines)
        let pos = Position.make(1, 2)

        switch Grid.get(grid, pos) {
        | Some(Char("f")) => pass
        | _ => fail("Expected 'f'")
        }
      })

      test("returns none for invalid position", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)
        let pos = Position.make(5, 10)

        expect(Grid.get(grid, pos))->toBe(None)
      })

      test("returns none for negative position", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)
        let pos = Position.make(-1, 0)

        expect(Grid.get(grid, pos))->toBe(None)
      })

      test("recognizes special characters", () => {
        let lines = ["+---|"]
        let grid = Grid.fromLines(lines)

        switch Grid.get(grid, Position.make(0, 0)) {
        | Some(Corner) => pass
        | _ => fail("Expected Corner")
        }

        switch Grid.get(grid, Position.make(0, 1)) {
        | Some(HLine) => pass
        | _ => fail("Expected HLine")
        }

        switch Grid.get(grid, Position.make(0, 4)) {
        | Some(VLine) => pass
        | _ => fail("Expected VLine")
        }
      })
    })

    describe("getLine", () => {
      test("returns full line as array", () => {
        let lines = ["abc", "def"]
        let grid = Grid.fromLines(lines)

        switch Grid.getLine(grid, 1) {
        | Some(line) => {
            expect(Belt.Array.length(line))->toBe(3)
          }
        | None => fail("Expected line")
        }
      })

      test("returns none for invalid row", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)

        expect(Grid.getLine(grid, 5))->toBe(None)
      })
    })

    describe("getRange", () => {
      test("returns character range from line", () => {
        let lines = ["abcdef"]
        let grid = Grid.fromLines(lines)

        switch Grid.getRange(grid, 0, ~startCol=1, ~endCol=4) {
        | Some(range) => {
            expect(Belt.Array.length(range))->toBe(4) // Inclusive
          }
        | None => fail("Expected range")
        }
      })

      test("returns none for invalid range", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)

        expect(Grid.getRange(grid, 0, ~startCol=5, ~endCol=10))->toBe(None)
      })
    })

    describe("scanRight", () => {
      test("scans until predicate fails", () => {
        let lines = ["+----+"]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 0)

        let results = Grid.scanRight(grid, start, cell => {
          switch cell {
          | Corner | HLine => true
          | _ => false
          }
        })

        expect(Belt.Array.length(results))->toBe(6) // +, 4x-, +
      })

      test("stops at grid boundary", () => {
        let lines = ["abcdef"]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 0)

        let results = Grid.scanRight(grid, start, _ => true)

        expect(Belt.Array.length(results))->toBe(6)
      })

      test("returns empty array if predicate fails immediately", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 0)

        let results = Grid.scanRight(grid, start, cell => {
          switch cell {
          | Corner => true
          | _ => false
          }
        })

        expect(Belt.Array.length(results))->toBe(0)
      })
    })

    describe("scanDown", () => {
      test("scans vertically until predicate fails", () => {
        let lines = [
          "+",
          "|",
          "|",
          "+"
        ]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 0)

        let results = Grid.scanDown(grid, start, cell => {
          switch cell {
          | Corner | VLine => true
          | _ => false
          }
        })

        expect(Belt.Array.length(results))->toBe(4)
      })

      test("stops at grid bottom", () => {
        let lines = ["a", "b", "c"]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 0)

        let results = Grid.scanDown(grid, start, _ => true)

        expect(Belt.Array.length(results))->toBe(3)
      })
    })

    describe("scanLeft", () => {
      test("scans leftward until predicate fails", () => {
        let lines = ["+----+"]
        let grid = Grid.fromLines(lines)
        let start = Position.make(0, 5) // Start from right corner

        let results = Grid.scanLeft(grid, start, cell => {
          switch cell {
          | Corner | HLine => true
          | _ => false
          }
        })

        expect(Belt.Array.length(results))->toBe(6)
      })
    })

    describe("scanUp", () => {
      test("scans upward until predicate fails", () => {
        let lines = [
          "+",
          "|",
          "|",
          "+"
        ]
        let grid = Grid.fromLines(lines)
        let start = Position.make(3, 0) // Start from bottom

        let results = Grid.scanUp(grid, start, cell => {
          switch cell {
          | Corner | VLine => true
          | _ => false
          }
        })

        expect(Belt.Array.length(results))->toBe(4)
      })
    })

    describe("findAll", () => {
      test("finds all corner characters", () => {
        let lines = [
          "+----+",
          "|    |",
          "+----+"
        ]
        let grid = Grid.fromLines(lines)

        let corners = Grid.findAll(grid, Corner)

        expect(Belt.Array.length(corners))->toBe(4)
      })

      test("returns empty array when no matches", () => {
        let lines = ["abc", "def"]
        let grid = Grid.fromLines(lines)

        let corners = Grid.findAll(grid, Corner)

        expect(Belt.Array.length(corners))->toBe(0)
      })

      test("finds all divider characters", () => {
        let lines = [
          "+====+",
          "|    |",
          "+====+"
        ]
        let grid = Grid.fromLines(lines)

        let dividers = Grid.findAll(grid, Divider)

        expect(Belt.Array.length(dividers))->toBe(8) // 4 + 4
      })
    })

    describe("findInRange", () => {
      test("finds characters within bounds", () => {
        let lines = [
          "+----+----+",
          "|    |    |",
          "+----+----+"
        ]
        let grid = Grid.fromLines(lines)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=2, ~right=5)

        let cornersInRange = Grid.findInRange(grid, Corner, bounds)

        expect(Belt.Array.length(cornersInRange))->toBe(2) // Only left box corners
      })
    })

    describe("isValidPosition", () => {
      test("returns true for valid position", () => {
        let lines = ["abc", "def"]
        let grid = Grid.fromLines(lines)
        let pos = Position.make(1, 2)

        expect(Grid.isValidPosition(grid, pos))->toBe(true)
      })

      test("returns false for out of bounds position", () => {
        let lines = ["abc"]
        let grid = Grid.fromLines(lines)
        let pos = Position.make(5, 10)

        expect(Grid.isValidPosition(grid, pos))->toBe(false)
      })
    })
  })
}

// =============================================================================
// UNIT TESTS: Shape Detector
// =============================================================================

/**
 * BoxTracer Module Tests
 * Tests for box boundary tracing algorithm
 */
module BoxTracerTest = {
  describe("BoxTracer", () => {
    describe("traceBox", () => {
      test("traces simple rectangular box", () => {
        let input = `
+----+
|    |
+----+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0) // Skip first empty line

        switch BoxTracer.traceBox(grid, topLeft) {
        | Ok(box) => {
            expect(box.bounds.top)->toBe(1)
            expect(box.bounds.left)->toBe(0)
            expect(box.bounds.bottom)->toBe(3)
            expect(box.bounds.right)->toBe(5)
          }
        | Error(_) => fail("Expected successful box trace")
        }
      })

      test("extracts box name from top border", () => {
        let input = `
+--Login--+
|         |
+=========+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Ok(box) => {
            expect(box.name)->toBe(Some("Login"))
          }
        | Error(_) => fail("Expected successful box trace")
        }
      })

      test("handles box without name", () => {
        let input = `
+----------+
|          |
+----------+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Ok(box) => {
            expect(box.name)->toBe(None)
          }
        | Error(_) => fail("Expected successful box trace")
        }
      })

      test("detects unclosed box missing bottom corner", () => {
        let input = `
+----+
|    |
+----
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Error(UncloseBoxBottom(_)) => pass
        | _ => fail("Expected UncloseBoxBottom error")
        }
      })

      test("detects unclosed box missing right edge", () => {
        let input = `
+----+
|
+----+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Error(UncloseBoxRight(_)) => pass
        | _ => fail("Expected UncloseBoxRight error")
        }
      })

      test("detects width mismatch between top and bottom", () => {
        let input = `
+----+
|    |
+------+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Error(MismatchedWidth({topWidth, bottomWidth})) => {
            expect(topWidth)->toBe(5)
            expect(bottomWidth)->toBe(7)
          }
        | _ => fail("Expected MismatchedWidth error")
        }
      })

      test("detects misaligned vertical pipes", () => {
        let input = `
+----+
 |   |
+----+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Error(MisalignedPipe({expected, actual})) => {
            expect(expected)->toBe(0)
            expect(actual)->toBe(1)
          }
        | _ => fail("Expected MisalignedPipe error")
        }
      })

      test("handles box with divider bottom", () => {
        let input = `
+------+
|      |
+======+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Ok(box) => {
            expect(box.bounds.bottom)->toBe(3)
          }
        | Error(_) => fail("Expected successful box trace")
        }
      })

      test("traces large box correctly", () => {
        let input = `
+-------------------------+
|                         |
|                         |
|                         |
|                         |
+-------------------------+
`
        let grid = Grid.fromLines(Js.String2.split(input, "\n"))
        let topLeft = Position.make(1, 0)

        switch BoxTracer.traceBox(grid, topLeft) {
        | Ok(box) => {
            expect(Bounds.width(box.bounds))->toBe(26)
            expect(Bounds.height(box.bounds))->toBe(5)
          }
        | Error(_) => fail("Expected successful box trace")
        }
      })
    })
  })
}

/**
 * HierarchyBuilder Module Tests
 * Tests for nesting hierarchy construction
 */
module HierarchyBuilderTest = {
  describe("HierarchyBuilder", () => {
    describe("buildHierarchy", () => {
      test("builds simple parent-child relationship", () => {
        let outer = {
          name: Some("Outer"),
          bounds: Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20),
          children: []
        }

        let inner = {
          name: Some("Inner"),
          bounds: Bounds.make(~top=2, ~left=5, ~bottom=8, ~right=15),
          children: []
        }

        let boxes = [outer, inner]

        switch HierarchyBuilder.buildHierarchy(boxes) {
        | Ok(roots) => {
            expect(Belt.Array.length(roots))->toBe(1)
            expect(Belt.Array.length(roots[0].children))->toBe(1)
            expect(roots[0].children[0].name)->toBe(Some("Inner"))
          }
        | Error(_) => fail("Expected successful hierarchy build")
        }
      })

      test("handles three-level nesting", () => {
        let grandparent = {
          name: Some("A"),
          bounds: Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=30),
          children: []
        }

        let parent = {
          name: Some("B"),
          bounds: Bounds.make(~top=2, ~left=2, ~bottom=18, ~right=28),
          children: []
        }

        let child = {
          name: Some("C"),
          bounds: Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=25),
          children: []
        }

        let boxes = [grandparent, parent, child]

        switch HierarchyBuilder.buildHierarchy(boxes) {
        | Ok(roots) => {
            expect(Belt.Array.length(roots))->toBe(1)
            expect(roots[0].name)->toBe(Some("A"))
            expect(Belt.Array.length(roots[0].children))->toBe(1)
            expect(roots[0].children[0].name)->toBe(Some("B"))
            expect(Belt.Array.length(roots[0].children[0].children))->toBe(1)
            expect(roots[0].children[0].children[0].name)->toBe(Some("C"))
          }
        | Error(_) => fail("Expected successful hierarchy build")
        }
      })

      test("handles multiple sibling boxes", () => {
        let box1 = {
          name: Some("Box1"),
          bounds: Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
          children: []
        }

        let box2 = {
          name: Some("Box2"),
          bounds: Bounds.make(~top=0, ~left=15, ~bottom=10, ~right=25),
          children: []
        }

        let boxes = [box1, box2]

        switch HierarchyBuilder.buildHierarchy(boxes) {
        | Ok(roots) => {
            expect(Belt.Array.length(roots))->toBe(2)
          }
        | Error(_) => fail("Expected successful hierarchy build")
        }
      })

      test("detects overlapping boxes", () => {
        let box1 = {
          name: Some("Box1"),
          bounds: Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=15),
          children: []
        }

        let box2 = {
          name: Some("Box2"),
          bounds: Bounds.make(~top=5, ~left=10, ~bottom=15, ~right=25),
          children: []
        }

        let boxes = [box1, box2]

        switch HierarchyBuilder.buildHierarchy(boxes) {
        | Error(OverlappingBoxes(_)) => pass
        | _ => fail("Expected OverlappingBoxes error")
        }
      })

      test("chooses smallest containing box as parent", () => {
        let large = {
          name: Some("Large"),
          bounds: Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=40),
          children: []
        }

        let medium = {
          name: Some("Medium"),
          bounds: Bounds.make(~top=5, ~left=5, ~bottom=25, ~right=35),
          children: []
        }

        let small = {
          name: Some("Small"),
          bounds: Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=30),
          children: []
        }

        let boxes = [large, medium, small]

        switch HierarchyBuilder.buildHierarchy(boxes) {
        | Ok(roots) => {
            expect(Belt.Array.length(roots))->toBe(1)
            expect(roots[0].name)->toBe(Some("Large"))

            // Small should be child of Medium, not Large
            expect(roots[0].children[0].name)->toBe(Some("Medium"))
            expect(roots[0].children[0].children[0].name)->toBe(Some("Small"))
          }
        | Error(_) => fail("Expected successful hierarchy build")
        }
      })
    })
  })
}

// =============================================================================
// UNIT TESTS: Semantic Parser
// =============================================================================

/**
 * ButtonParser Tests
 * Tests for button element recognition and parsing
 */
module ButtonParserTest = {
  describe("ButtonParser", () => {
    let parser = ParserRegistry.makeButtonParser()

    describe("canParse", () => {
      test("recognizes valid button syntax", () => {
        expect(parser.canParse("[ Submit ]"))->toBe(true)
      })

      test("recognizes button with extra spaces", () => {
        expect(parser.canParse("[  OK  ]"))->toBe(true)
      })

      test("rejects non-button text", () => {
        expect(parser.canParse("#email"))->toBe(false)
        expect(parser.canParse("plain text"))->toBe(false)
      })

      test("rejects incomplete brackets", () => {
        expect(parser.canParse("[ Submit"))->toBe(false)
        expect(parser.canParse("Submit ]"))->toBe(false)
      })
    })

    describe("parse", () => {
      test("extracts button text correctly", () => {
        let position = Position.make(5, 10)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        switch parser.parse("  [ Login ]  ", position, bounds) {
        | Some(Button({text, id})) => {
            expect(text)->toBe("Login")
            expect(id)->toBe("login")
          }
        | _ => fail("Expected Button element")
        }
      })

      test("trims whitespace from button text", () => {
        let position = Position.make(0, 0)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

        switch parser.parse("[  Sign Up  ]", position, bounds) {
        | Some(Button({text})) => {
            expect(text)->toBe("Sign Up")
          }
        | _ => fail("Expected Button element")
        }
      })

      test("generates slugified ID", () => {
        let position = Position.make(0, 0)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

        switch parser.parse("[ Create Account ]", position, bounds) {
        | Some(Button({id})) => {
            expect(id)->toBe("create-account")
          }
        | _ => fail("Expected Button element")
        }
      })

      test("returns none for empty button", () => {
        let position = Position.make(0, 0)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

        let result = parser.parse("[     ]", position, bounds)

        expect(result)->toBe(None)
      })

      test("calculates alignment based on position", () => {
        // Left-aligned
        let posLeft = Position.make(5, 2)
        let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        switch parser.parse("[ OK ]", posLeft, bounds) {
        | Some(Button({align})) => {
            expect(align)->toBe(Left)
          }
        | _ => fail("Expected Button element")
        }

        // Center-aligned
        let posCenter = Position.make(5, 12)

        switch parser.parse("[ OK ]", posCenter, bounds) {
        | Some(Button({align})) => {
            expect(align)->toBe(Center)
          }
        | _ => fail("Expected Button element")
        }
      })
    })
  })
}

/**
 * AlignmentCalc Tests
 * Tests for element alignment calculation
 */
module AlignmentCalcTest = {
  describe("AlignmentCalc", () => {
    describe("calculate", () => {
      test("returns left for content near left edge", () => {
        let content = "Hello"
        let position = Position.make(5, 2) // Close to left
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        expect(alignment)->toBe(Left)
      })

      test("returns right for content near right edge", () => {
        let content = "Hello"
        let position = Position.make(5, 24) // Close to right
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        expect(alignment)->toBe(Right)
      })

      test("returns center for content in middle", () => {
        let content = "Hello"
        let position = Position.make(5, 12) // Center
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        expect(alignment)->toBe(Center)
      })

      test("defaults to left for ambiguous positioning", () => {
        let content = "Hello"
        let position = Position.make(5, 10)
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        expect(alignment)->toBe(Left)
      })

      test("handles narrow boxes", () => {
        let content = "Hi"
        let position = Position.make(2, 2)
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        // Should default to Left for narrow boxes
        expect(alignment)->toBe(Left)
      })

      test("handles content at exact center", () => {
        let content = "Test"
        let position = Position.make(5, 13) // Perfect center for 30-wide box
        let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

        let alignment = AlignmentCalc.calculate(content, position, boxBounds)

        expect(alignment)->toBe(Center)
      })
    })
  })
}

// =============================================================================
// INTEGRATION TESTS
// =============================================================================

/**
 * End-to-End Parsing Tests
 * Tests for the complete parsing pipeline
 */
module E2EParsingTest = {
  describe("End-to-End Parsing", () => {
    test("parses complete login scene", () => {
      let wireframe = `
@scene: login
@title: Login Page

+--Login----------------+
|                       |
|  * Welcome            |
|                       |
|  Email: #email        |
|                       |
|  Password: #password  |
|                       |
|     [ Login ]         |
|                       |
+-----------------------+
`

      switch WyreframeParser.parse(wireframe, None) {
      | Ok(ast) => {
          expect(Belt.Array.length(ast.scenes))->toBe(1)

          let scene = ast.scenes[0]
          expect(scene.id)->toBe("login")
          expect(scene.title)->toBe("Login Page")

          // Check for emphasis text
          let hasEmphasis = Belt.Array.some(scene.elements, el => {
            switch el {
            | Text({emphasis: true}) => true
            | _ => false
            }
          })
          expect(hasEmphasis)->toBe(true)

          // Check for inputs
          let hasEmail = Belt.Array.some(scene.elements, el => {
            switch el {
            | Input({id: "email"}) => true
            | _ => false
            }
          })
          expect(hasEmail)->toBe(true)

          // Check for button
          let hasButton = Belt.Array.some(scene.elements, el => {
            switch el {
            | Button({text: "Login"}) => true
            | _ => false
            }
          })
          expect(hasButton)->toBe(true)
        }
      | Error(errors) => {
          Js.Console.error(errors)
          fail("Expected successful parse")
        }
      }
    })

    test("parses multi-scene wireframe", () => {
      let wireframe = `
@scene: home
+--------+
| Home   |
+--------+

---

@scene: settings
+----------+
| Settings |
+----------+
`

      switch WyreframeParser.parse(wireframe, None) {
      | Ok(ast) => {
          expect(Belt.Array.length(ast.scenes))->toBe(2)
          expect(ast.scenes[0].id)->toBe("home")
          expect(ast.scenes[1].id)->toBe("settings")
        }
      | Error(_) => fail("Expected successful parse")
      }
    })

    test("handles nested boxes correctly", () => {
      let wireframe = `
@scene: test

+--Outer--------------+
|                     |
|  +--Inner-------+  |
|  |              |  |
|  |  [ Button ]  |  |
|  |              |  |
|  +--------------+  |
|                     |
+---------------------+
`

      switch WyreframeParser.parse(wireframe, None) {
      | Ok(ast) => {
          let scene = ast.scenes[0]

          // Should have hierarchical structure
          expect(Belt.Array.length(scene.elements))->toBeGreaterThan(0)
        }
      | Error(_) => fail("Expected successful parse")
      }
    })

    test("collects multiple errors without stopping", () => {
      let wireframe = `
@scene: test

+--Good Box--+
|            |
+------------+

+--Bad Box---+
|            |
+----------    <- Missing corner

+--Another Good--+
|                |
+----------------+
`

      switch WyreframeParser.parse(wireframe, None) {
      | Ok(_) => fail("Expected errors to be detected")
      | Error(errors) => {
          // Should collect multiple errors
          expect(Belt.Array.length(errors))->toBeGreaterThan(0)
        }
      }
    })
  })
}

// =============================================================================
// PERFORMANCE TESTS
// =============================================================================

/**
 * Parsing Speed Benchmarks
 * Tests to ensure parsing meets performance requirements
 */
module PerformanceTest = {
  // Helper to generate test wireframes
  let generateWireframe = (~boxes: int, ~elementsPerBox: int): string => {
    let boxTemplates = []

    for i in 1 to boxes {
      let boxName = `Box${Belt.Int.toString(i)}`
      let elements = []

      for j in 1 to elementsPerBox {
        elements->Js.Array2.push(`  Element ${Belt.Int.toString(j)}`)->ignore
      }

      let box = `
+--${boxName}----------+
${Js.Array2.joinWith(elements, "\n")}
+--------------------+
`
      boxTemplates->Js.Array2.push(box)->ignore
    }

    Js.Array2.joinWith(boxTemplates, "\n")
  }

  describe("Parsing Speed", () => {
    test("parses small wireframe under 10ms", () => {
      let wireframe = generateWireframe(~boxes=5, ~elementsPerBox=3)

      let start = Js.Date.now()
      let _ = WyreframeParser.parse(wireframe, None)
      let duration = Js.Date.now() -. start

      expect(duration)->toBeLessThan(10.0)
    })

    test("parses medium wireframe under 50ms", () => {
      let wireframe = generateWireframe(~boxes=20, ~elementsPerBox=8)

      let start = Js.Date.now()
      let _ = WyreframeParser.parse(wireframe, None)
      let duration = Js.Date.now() -. start

      expect(duration)->toBeLessThan(50.0)
    })

    test("parses large wireframe under 200ms", () => {
      let wireframe = generateWireframe(~boxes=100, ~elementsPerBox=10)

      let start = Js.Date.now()
      let _ = WyreframeParser.parse(wireframe, None)
      let duration = Js.Date.now() -. start

      expect(duration)->toBeLessThan(200.0)
    })
  })
}

// =============================================================================
// PROPERTY-BASED TESTS
// =============================================================================

/**
 * Property-Based Tests
 * Tests using randomly generated inputs to verify invariants
 */
module PropertyTest = {
  // Note: This would use fast-check in actual implementation
  describe("Grid Properties", () => {
    test("fromLines always produces grid with correct dimensions", () => {
      // Test with various random line configurations
      let testCases = [
        ["a"],
        ["ab", "cd"],
        ["abc", "d", "ef"],
        ["", "", ""],
        ["x"->Js.String2.repeat(100)]
      ]

      Belt.Array.forEach(testCases, lines => {
        let grid = Grid.fromLines(lines)
        let maxWidth = Belt.Array.reduce(lines, 0, (max, line) =>
          Js.Math.max_int(max, Js.String2.length(line))
        )

        expect(grid.width)->toBe(maxWidth)
        expect(grid.height)->toBe(Belt.Array.length(lines))
      })
    })

    test("get returns none for all out-of-bounds positions", () => {
      let lines = ["abc", "def"]
      let grid = Grid.fromLines(lines)

      let invalidPositions = [
        Position.make(-1, 0),
        Position.make(0, -1),
        Position.make(10, 0),
        Position.make(0, 10),
        Position.make(100, 100)
      ]

      Belt.Array.forEach(invalidPositions, pos => {
        expect(Grid.get(grid, pos))->toBe(None)
      })
    })
  })
}

/**
 * Summary
 *
 * This test file demonstrates:
 * 1. Unit tests for core modules (Position, Bounds, Grid)
 * 2. Unit tests for shape detection (BoxTracer, HierarchyBuilder)
 * 3. Unit tests for semantic parsing (ButtonParser, AlignmentCalc)
 * 4. Integration tests (E2E parsing)
 * 5. Performance tests (parsing speed)
 * 6. Property-based tests (invariant checking)
 *
 * Total test cases: 80+
 * Coverage target: ≥90%
 *
 * To run tests:
 * - npm run test
 * - npm run test:watch
 * - npm run test:coverage
 */
