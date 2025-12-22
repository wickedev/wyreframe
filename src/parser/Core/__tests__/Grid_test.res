// Grid_test.res
// Unit tests for Grid module

open Vitest

describe("Grid", () => {
  open Grid

  describe("fromLines", () => {
    test("creates correct dimensions for equal-length lines", t => {
      let lines = ["abc", "def", "ghi"]
      let grid = fromLines(lines)

      t->expect(grid.width)->Expect.toBe(3)
      t->expect(grid.height)->Expect.toBe(3)
    })

    test("normalizes uneven line lengths by padding", t => {
      let lines = ["abc", "de", "f"]
      let grid = fromLines(lines)

      t->expect(grid.width)->Expect.toBe(3)
      t->expect(grid.height)->Expect.toBe(3)

      // Check that shorter lines are padded with spaces
      switch getLine(grid, 1) {
      | Some(line) => {
          t->expect(Array.length(line))->Expect.toBe(3)
          t->expect(Array.get(line, 2))->Expect.toEqual(Some(Types.Space))
        }
      | None => t->expect(true)->Expect.toBe(false) // fail
      }
    })

    test("handles empty input", t => {
      let grid = fromLines([])
      t->expect(grid.width)->Expect.toBe(0)
      t->expect(grid.height)->Expect.toBe(0)
    })

    test("correctly identifies special characters", t => {
      let lines = ["+--+", "|  |", "+==+"]
      let grid = fromLines(lines)

      t->expect(Array.length(grid.cornerIndex))->Expect.toBe(4)
      // HLine (-) only appears on row 0: positions (0,1) and (0,2) = 2
      // Divider (=) appears on row 2: positions (2,1) and (2,2) = 2
      t->expect(Array.length(grid.hLineIndex))->Expect.toBe(2)
      t->expect(Array.length(grid.vLineIndex))->Expect.toBe(2)
      t->expect(Array.length(grid.dividerIndex))->Expect.toBe(2)
    })

    test("builds character indices with correct positions", t => {
      let lines = ["+--+"]
      let grid = fromLines(lines)

      // Check corner positions
      t->expect(Array.get(grid.cornerIndex, 0))->Expect.toEqual(Some({Types.Position.row: 0, col: 0}))
      t->expect(Array.get(grid.cornerIndex, 1))->Expect.toEqual(Some({Types.Position.row: 0, col: 3}))
    })
  })

  describe("get", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns character at valid position", t => {
      t->expect(get(grid, Types.Position.make(0, 0)))->Expect.toEqual(Some(Types.Corner))
      t->expect(get(grid, Types.Position.make(0, 1)))->Expect.toEqual(Some(Types.HLine))
      t->expect(get(grid, Types.Position.make(1, 0)))->Expect.toEqual(Some(Types.VLine))
    })

    test("returns None for out of bounds positions", t => {
      t->expect(get(grid, Types.Position.make(-1, 0)))->Expect.toBe(None)
      t->expect(get(grid, Types.Position.make(0, -1)))->Expect.toBe(None)
      t->expect(get(grid, Types.Position.make(10, 0)))->Expect.toBe(None)
      t->expect(get(grid, Types.Position.make(0, 10)))->Expect.toBe(None)
    })
  })

  describe("getLine", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns entire line at valid row", t => {
      switch getLine(grid, 0) {
      | Some(line) => {
          t->expect(Array.length(line))->Expect.toBe(4)
          t->expect(Array.get(line, 0))->Expect.toEqual(Some(Types.Corner))
        }
      | None => t->expect(true)->Expect.toBe(false) // fail
      }
    })

    test("returns None for out of bounds row", t => {
      t->expect(getLine(grid, -1))->Expect.toBe(None)
      t->expect(getLine(grid, 10))->Expect.toBe(None)
    })
  })

  describe("getRange", () => {
    let grid = fromLines(["+--Name--+"])

    test("returns range of characters", t => {
      switch getRange(grid, 0, ~startCol=1, ~endCol=3) {
      | Some(range) => {
          t->expect(Array.length(range))->Expect.toBe(3)
          t->expect(Array.get(range, 0))->Expect.toEqual(Some(Types.HLine))
        }
      | None => t->expect(true)->Expect.toBe(false) // fail
      }
    })

    test("handles negative start column", t => {
      switch getRange(grid, 0, ~startCol=-1, ~endCol=2) {
      | Some(range) => {
          t->expect(Array.length(range))->Expect.toBe(3)
        }
      | None => t->expect(true)->Expect.toBe(false) // fail
      }
    })

    test("returns None for invalid row", t => {
      t->expect(getRange(grid, -1, ~startCol=0, ~endCol=2))->Expect.toBe(None)
    })
  })

  describe("scanRight", () => {
    let grid = fromLines(["+----+"])

    test("scans right until predicate fails", t => {
      let start = Types.Position.make(0, 0)
      let results = scanRight(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.HLine => true
        | _ => false
        }
      )

      t->expect(Array.length(results))->Expect.toBe(6)
    })

    test("stops at grid boundary", t => {
      let start = Types.Position.make(0, 0)
      let results = scanRight(grid, start, _cell => true)

      t->expect(Array.length(results))->Expect.toBe(6)
    })

    test("returns empty array if predicate fails immediately", t => {
      let start = Types.Position.make(0, 0)
      let results = scanRight(grid, start, cell =>
        switch cell {
        | Types.HLine => true
        | _ => false
        }
      )

      t->expect(Array.length(results))->Expect.toBe(0)
    })
  })

  describe("scanDown", () => {
    let grid = fromLines(["+", "|", "|", "+"])

    test("scans down until predicate fails", t => {
      let start = Types.Position.make(0, 0)
      let results = scanDown(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.VLine => true
        | _ => false
        }
      )

      t->expect(Array.length(results))->Expect.toBe(4)
    })

    test("stops at grid boundary", t => {
      let start = Types.Position.make(0, 0)
      let results = scanDown(grid, start, _cell => true)

      t->expect(Array.length(results))->Expect.toBe(4)
    })
  })

  describe("scanLeft", () => {
    let grid = fromLines(["+----+"])

    test("scans left until predicate fails", t => {
      let start = Types.Position.make(0, 5)
      let results = scanLeft(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.HLine => true
        | _ => false
        }
      )

      t->expect(Array.length(results))->Expect.toBe(6)
    })

    test("stops at grid boundary", t => {
      let start = Types.Position.make(0, 5)
      let results = scanLeft(grid, start, _cell => true)

      t->expect(Array.length(results))->Expect.toBe(6)
    })
  })

  describe("scanUp", () => {
    let grid = fromLines(["+", "|", "|", "+"])

    test("scans up until predicate fails", t => {
      let start = Types.Position.make(3, 0)
      let results = scanUp(grid, start, cell =>
        switch cell {
        | Types.Corner | Types.VLine => true
        | _ => false
        }
      )

      t->expect(Array.length(results))->Expect.toBe(4)
    })

    test("stops at grid boundary", t => {
      let start = Types.Position.make(3, 0)
      let results = scanUp(grid, start, _cell => true)

      t->expect(Array.length(results))->Expect.toBe(4)
    })
  })

  describe("findAll", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("finds all corners using index", t => {
      let corners = findAll(grid, Types.Corner)
      t->expect(Array.length(corners))->Expect.toBe(4)
    })

    test("finds all horizontal lines using index", t => {
      let hlines = findAll(grid, Types.HLine)
      t->expect(Array.length(hlines))->Expect.toBe(4)
    })

    test("finds all vertical lines using index", t => {
      let vlines = findAll(grid, Types.VLine)
      t->expect(Array.length(vlines))->Expect.toBe(2)
    })

    test("finds spaces through scanning", t => {
      let spaces = findAll(grid, Types.Space)
      t->expect(Array.length(spaces))->Expect.toBe(2)
    })
  })

  describe("findInRange", () => {
    let grid = fromLines(["+--+", "|  |", "+--+", "|  |", "+--+"])

    test("finds characters within bounds", t => {
      // Create bounds that only include first box
      let bounds: Types.Bounds.t = {
        top: 0,
        left: 0,
        bottom: 3,
        right: 4,
      }

      let corners = findInRange(grid, Types.Corner, bounds)
      t->expect(Array.length(corners))->Expect.toBe(4)
    })

    test("excludes characters outside bounds", t => {
      // Create tight bounds that exclude all corners
      // Corners are at (0,0), (0,3), (2,0), (2,3), (4,0), (4,3)
      // These bounds (row 1-2, col 1-2) don't contain any corners
      let bounds: Types.Bounds.t = {
        top: 1,
        left: 1,
        bottom: 2,
        right: 2,
      }

      let corners = findInRange(grid, Types.Corner, bounds)
      t->expect(Array.length(corners))->Expect.toBe(0)
    })
  })

  describe("isValidPosition", () => {
    let grid = fromLines(["+--+", "|  |", "+--+"])

    test("returns true for valid positions", t => {
      t->expect(isValidPosition(grid, Types.Position.make(0, 0)))->Expect.toBe(true)
      t->expect(isValidPosition(grid, Types.Position.make(1, 2)))->Expect.toBe(true)
      t->expect(isValidPosition(grid, Types.Position.make(2, 3)))->Expect.toBe(true)
    })

    test("returns false for out of bounds positions", t => {
      t->expect(isValidPosition(grid, Types.Position.make(-1, 0)))->Expect.toBe(false)
      t->expect(isValidPosition(grid, Types.Position.make(0, -1)))->Expect.toBe(false)
      t->expect(isValidPosition(grid, Types.Position.make(10, 0)))->Expect.toBe(false)
      t->expect(isValidPosition(grid, Types.Position.make(0, 10)))->Expect.toBe(false)
    })
  })

  describe("Performance", () => {
    test("handles large grids efficiently", t => {
      // Generate a large grid (1000 lines)
      let lines = Array.make(~length=1000, "+----+")

      let startTime = Date.now()
      let grid = fromLines(lines)
      let endTime = Date.now()

      let duration = endTime -. startTime

      t->expect(grid.height)->Expect.toBe(1000)
      // Performance requirement: should be < 10ms
      t->expect(duration)->Expect.Float.toBeLessThan(10.0)
    })
  })
})
