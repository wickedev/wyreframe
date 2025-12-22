// Grid_test.res
// Unit tests for Grid module

open Jest
open Expect

describe("Grid", () => {
  open Grid

  describe("fromLines", () => {
    test("creates correct dimensions for equal-length lines", () => {
      let lines = ["abc", "def", "ghi"]
      let grid = fromLines(lines)

      expect(grid.width)->toBe(3)
      expect(grid.height)->toBe(3)
    })

    test("normalizes uneven line lengths by padding", () => {
      let lines = ["abc", "de", "f"]
      let grid = fromLines(lines)

      expect(grid.width)->toBe(3)
      expect(grid.height)->toBe(3)

      // Check that shorter lines are padded with spaces
      switch getLine(grid, 1) {
      | Some(line) => {
          expect(Array.length(line))->toBe(3)
          expect(Array.get(line, 2))->toEqual(Some(Types.Space))
        }
      | None => fail("Expected line to exist")
      }
    })

    test("handles empty input", () => {
      let grid = fromLines([])
      expect(grid.width)->toBe(0)
      expect(grid.height)->toBe(0)
    })

    test("correctly identifies special characters", () => {
      let lines = ["+--+", "|  |", "+==+"]
      let grid = fromLines(lines)

      expect(Array.length(grid.cornerIndex))->toBe(4)
      expect(Array.length(grid.hLineIndex))->toBe(4)
      expect(Array.length(grid.vLineIndex))->toBe(2)
      expect(Array.length(grid.dividerIndex))->toBe(2)
    })

    test("builds character indices with correct positions", () => {
      let lines = ["+--+"]
      let grid = fromLines(lines)

      // Check corner positions
      expect(Array.get(grid.cornerIndex, 0))->toEqual(Some(Position.make(0, 0)))
      expect(Array.get(grid.cornerIndex, 1))->toEqual(Some(Position.make(0, 3)))
    })
  })

  describe("get", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns character at valid position", () => {
      expect(get(grid, Position.make(0, 0)))->toEqual(Some(Types.Corner))
      expect(get(grid, Position.make(0, 1)))->toEqual(Some(Types.HLine))
      expect(get(grid, Position.make(1, 0)))->toEqual(Some(Types.VLine))
    })

    test("returns None for out of bounds positions", () => {
      expect(get(grid, Position.make(-1, 0)))->toBe(None)
      expect(get(grid, Position.make(0, -1)))->toBe(None)
      expect(get(grid, Position.make(10, 0)))->toBe(None)
      expect(get(grid, Position.make(0, 10)))->toBe(None)
    })
  })

  describe("getLine", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns entire line at valid row", () => {
      switch getLine(grid, 0) {
      | Some(line) => {
          expect(Array.length(line))->toBe(4)
          expect(Array.get(line, 0))->toEqual(Some(Types.Corner))
        }
      | None => fail("Expected line to exist")
      }
    })

    test("returns None for out of bounds row", () => {
      expect(getLine(grid, -1))->toBe(None)
      expect(getLine(grid, 10))->toBe(None)
    })
  })

  describe("getRange", () => {
    let grid = fromLines(["+--Name--+"])

    test("returns range of characters", () => {
      switch getRange(grid, 0, ~startCol=1, ~endCol=3) {
      | Some(range) => {
          expect(Array.length(range))->toBe(3)
          expect(Array.get(range, 0))->toEqual(Some(Types.HLine))
        }
      | None => fail("Expected range to exist")
      }
    })

    test("handles negative start column", () => {
      switch getRange(grid, 0, ~startCol=-1, ~endCol=2) {
      | Some(range) => {
          expect(Array.length(range))->toBe(3)
        }
      | None => fail("Expected range to exist")
      }
    })

    test("returns None for invalid row", () => {
      expect(getRange(grid, -1, ~startCol=0, ~endCol=2))->toBe(None)
    })
  })

  describe("scanRight", () => {
    let grid = fromLines(["+----+"])

    test("scans right until predicate fails", () => {
      let start = Position.make(0, 0)
      let results = scanRight(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.HLine => true
        | _ => false
        }
      )

      expect(Array.length(results))->toBe(6)
    })

    test("stops at grid boundary", () => {
      let start = Position.make(0, 0)
      let results = scanRight(grid, start, _cell => true)

      expect(Array.length(results))->toBe(6)
    })

    test("returns empty array if predicate fails immediately", () => {
      let start = Position.make(0, 0)
      let results = scanRight(grid, start, cell =>
        switch cell {
        | Types.HLine => true
        | _ => false
        }
      )

      expect(Array.length(results))->toBe(0)
    })
  })

  describe("scanDown", () => {
    let grid = fromLines(["+", "|", "|", "+"])

    test("scans down until predicate fails", () => {
      let start = Position.make(0, 0)
      let results = scanDown(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.VLine => true
        | _ => false
        }
      )

      expect(Array.length(results))->toBe(4)
    })

    test("stops at grid boundary", () => {
      let start = Position.make(0, 0)
      let results = scanDown(grid, start, _cell => true)

      expect(Array.length(results))->toBe(4)
    })
  })

  describe("scanLeft", () => {
    let grid = fromLines(["+----+"])

    test("scans left until predicate fails", () => {
      let start = Position.make(0, 5)
      let results = scanLeft(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.HLine => true
        | _ => false
        }
      )

      expect(Array.length(results))->toBe(6)
    })

    test("stops at grid boundary", () => {
      let start = Position.make(0, 5)
      let results = scanLeft(grid, start, _cell => true)

      expect(Array.length(results))->toBe(6)
    })
  })

  describe("scanUp", () => {
    let grid = fromLines(["+", "|", "|", "+"])

    test("scans up until predicate fails", () => {
      let start = Position.make(3, 0)
      let results = scanUp(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.VLine => true
        | _ => false
        }
      )

      expect(Array.length(results))->toBe(4)
    })

    test("stops at grid boundary", () => {
      let start = Position.make(3, 0)
      let results = scanUp(grid, start, _cell => true)

      expect(Array.length(results))->toBe(4)
    })
  })

  describe("findAll", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("finds all corners using index", () => {
      let corners = findAll(grid, Types.Corner)
      expect(Array.length(corners))->toBe(4)
    })

    test("finds all horizontal lines using index", () => {
      let hlines = findAll(grid, Types.HLine)
      expect(Array.length(hlines))->toBe(4)
    })

    test("finds all vertical lines using index", () => {
      let vlines = findAll(grid, Types.VLine)
      expect(Array.length(vlines))->toBe(2)
    })

    test("finds spaces through scanning", () => {
      let spaces = findAll(grid, Types.Space)
      expect(Array.length(spaces))->toBe(2)
    })
  })

  describe("findInRange", () => {
    let grid = fromLines(["+--+", "|  |", "+--+", "|  |", "+--+"])

    test("finds characters within bounds", () => {
      // Create bounds that only include first box
      let bounds = {
        Bounds.top: 0,
        left: 0,
        bottom: 3,
        right: 4,
      }

      let corners = findInRange(grid, Types.Corner, bounds)
      expect(Array.length(corners))->toBe(4)
    })

    test("excludes characters outside bounds", () => {
      // Create tight bounds that exclude most corners
      let bounds = {
        Bounds.top: 1,
        left: 1,
        bottom: 2,
        right: 3,
      }

      let corners = findInRange(grid, Types.Corner, bounds)
      expect(Array.length(corners))->toBe(0)
    })
  })

  describe("isValidPosition", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns true for valid positions", () => {
      expect(isValidPosition(grid, Position.make(0, 0)))->toBe(true)
      expect(isValidPosition(grid, Position.make(1, 2)))->toBe(true)
      expect(isValidPosition(grid, Position.make(2, 3)))->toBe(true)
    })

    test("returns false for out of bounds positions", () => {
      expect(isValidPosition(grid, Position.make(-1, 0)))->toBe(false)
      expect(isValidPosition(grid, Position.make(0, -1)))->toBe(false)
      expect(isValidPosition(grid, Position.make(10, 0)))->toBe(false)
      expect(isValidPosition(grid, Position.make(0, 10)))->toBe(false)
    })
  })

  describe("Performance", () => {
    test("handles large grids efficiently", () => {
      // Generate a large grid (1000 lines)
      let lines = Array.make(1000, "+----+")

      let startTime = Date.now()
      let grid = fromLines(lines)
      let endTime = Date.now()

      let duration = endTime -. startTime

      expect(grid.height)->toBe(1000)
      // Performance requirement: should be < 10ms
      expect(duration)->toBeLessThan(10.0)
    })
  })
})
