// Grid.res
// 2D character grid data structure with efficient position-based operations
// Provides the foundation for spatial parsing of ASCII wireframes

open Types

type t = {
  cells: array<array<cellChar>>,
  width: int,
  height: int,
  cornerIndex: array<Position.t>,
  hLineIndex: array<Position.t>,
  vLineIndex: array<Position.t>,
  dividerIndex: array<Position.t>,
}

// Helper function to convert a string character to cellChar
let charToCellChar = (char: string): cellChar => {
  switch char {
  | "+" => Corner
  | "-" => HLine
  | "|" => VLine
  | "=" => Divider
  | " " => Space
  | c => Char(c)
  }
}

// Helper function to convert cellChar back to string
let cellCharToString = (cell: cellChar): string => {
  switch cell {
  | Corner => "+"
  | HLine => "-"
  | VLine => "|"
  | Divider => "="
  | Space => " "
  | Char(c) => c
  }
}

// Create grid from lines with normalization
// Normalizes line lengths by padding shorter lines with spaces
let fromLines = (lines: array<string>): t => {
  // Find maximum line width
  let maxWidth = Array.reduce(lines, 0, (acc, line) => {
    let len = String.length(line)
    acc > len ? acc : len
  })

  // Build 2D cell array with normalization
  let cells = Array.map(lines, line => {
    let chars = String.split(line, "")
    let cellRow = Array.map(chars, charToCellChar)

    // Pad to max width with spaces
    let paddingNeeded = maxWidth - Array.length(cellRow)
    if paddingNeeded > 0 {
      let padding = Array.make(~length=paddingNeeded, Space)
      Array.concat(cellRow, padding)
    } else {
      cellRow
    }
  })

  // Build special character indices for O(1) lookup
  let cornerIndex = []
  let hLineIndex = []
  let vLineIndex = []
  let dividerIndex = []

  Array.forEachWithIndex(cells, (row, rowIdx) => {
    Array.forEachWithIndex(row, (cell, colIdx) => {
      let pos = Position.make(rowIdx, colIdx)
      switch cell {
      | Corner => {
          let _ = Array.push(cornerIndex, pos)
        }
      | HLine => {
          let _ = Array.push(hLineIndex, pos)
        }
      | VLine => {
          let _ = Array.push(vLineIndex, pos)
        }
      | Divider => {
          let _ = Array.push(dividerIndex, pos)
        }
      | _ => ()
      }
    })
  })

  {
    cells,
    width: maxWidth,
    height: Array.length(cells),
    cornerIndex,
    hLineIndex,
    vLineIndex,
    dividerIndex,
  }
}

// Get character at position, returns None if out of bounds
let get = (grid: t, pos: Position.t): option<cellChar> => {
  if pos.row >= 0 && pos.row < grid.height && pos.col >= 0 && pos.col < grid.width {
    Array.get(grid.cells, pos.row)->Option.flatMap(row => Array.get(row, pos.col))
  } else {
    None
  }
}

// Get entire line at row index
let getLine = (grid: t, row: int): option<array<cellChar>> => {
  if row >= 0 && row < grid.height {
    Array.get(grid.cells, row)
  } else {
    None
  }
}

// Get range of characters from a line (inclusive)
let getRange = (grid: t, row: int, ~startCol: int, ~endCol: int): option<array<cellChar>> => {
  getLine(grid, row)->Option.map(line => {
    let start = startCol < 0 ? 0 : startCol
    let end = endCol >= Array.length(line) ? Array.length(line) - 1 : endCol
    Array.slice(line, ~start, ~end=end + 1)
  })
}

// Scan right from position while predicate is true
// Returns array of (position, cellChar) tuples
let scanRight = (grid: t, pos: Position.t, predicate: cellChar => bool): array<(
  Position.t,
  cellChar,
)> => {
  let results = []
  let currentPos = ref(pos)
  let continue = ref(true)

  while currentPos.contents.col < grid.width && continue.contents {
    switch get(grid, currentPos.contents) {
    | Some(cell) =>
      if predicate(cell) {
        let _ = Array.push(results, (currentPos.contents, cell))
        currentPos := Position.right(currentPos.contents)
      } else {
        continue := false
      }
    | None => continue := false
    }
  }

  results
}

// Scan down from position while predicate is true
let scanDown = (grid: t, pos: Position.t, predicate: cellChar => bool): array<(
  Position.t,
  cellChar,
)> => {
  let results = []
  let currentPos = ref(pos)
  let continue = ref(true)

  while currentPos.contents.row < grid.height && continue.contents {
    switch get(grid, currentPos.contents) {
    | Some(cell) =>
      if predicate(cell) {
        let _ = Array.push(results, (currentPos.contents, cell))
        currentPos := Position.down(currentPos.contents)
      } else {
        continue := false
      }
    | None => continue := false
    }
  }

  results
}

// Scan left from position while predicate is true
let scanLeft = (grid: t, pos: Position.t, predicate: cellChar => bool): array<(
  Position.t,
  cellChar,
)> => {
  let results = []
  let currentPos = ref(pos)
  let continue = ref(true)

  while currentPos.contents.col >= 0 && continue.contents {
    switch get(grid, currentPos.contents) {
    | Some(cell) =>
      if predicate(cell) {
        let _ = Array.push(results, (currentPos.contents, cell))
        currentPos := Position.left(currentPos.contents)
      } else {
        continue := false
      }
    | None => continue := false
    }
  }

  results
}

// Scan up from position while predicate is true
let scanUp = (grid: t, pos: Position.t, predicate: cellChar => bool): array<(Position.t, cellChar)> => {
  let results = []
  let currentPos = ref(pos)
  let continue = ref(true)

  while currentPos.contents.row >= 0 && continue.contents {
    switch get(grid, currentPos.contents) {
    | Some(cell) =>
      if predicate(cell) {
        let _ = Array.push(results, (currentPos.contents, cell))
        currentPos := Position.up(currentPos.contents)
      } else {
        continue := false
      }
    | None => continue := false
    }
  }

  results
}

// Find all positions of a specific cellChar type using prebuilt index
let findAll = (grid: t, cellType: cellChar): array<Position.t> => {
  switch cellType {
  | Corner => grid.cornerIndex
  | HLine => grid.hLineIndex
  | VLine => grid.vLineIndex
  | Divider => grid.dividerIndex
  | Space | Char(_) => {
      // For Space and Char types, we need to scan the entire grid
      let positions = []
      Array.forEachWithIndex(grid.cells, (row, rowIdx) => {
        Array.forEachWithIndex(row, (cell, colIdx) => {
          switch (cellType, cell) {
          | (Space, Space) => {
              let _ = Array.push(positions, Position.make(rowIdx, colIdx))
            }
          | (Char(expected), Char(actual)) if expected === actual => {
              let _ = Array.push(positions, Position.make(rowIdx, colIdx))
            }
          | _ => ()
          }
        })
      })
      positions
    }
  }
}

// Find all positions of a cellChar within bounds
let findInRange = (grid: t, cellType: cellChar, bounds: Bounds.t): array<Position.t> => {
  let allPositions = findAll(grid, cellType)
  Array.filter(allPositions, pos => Position.isWithin(pos, bounds))
}

// Check if position is valid (within grid bounds)
let isValidPosition = (grid: t, pos: Position.t): bool => {
  pos.row >= 0 && pos.row < grid.height && pos.col >= 0 && pos.col < grid.width
}
