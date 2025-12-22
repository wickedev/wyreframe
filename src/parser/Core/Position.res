// Position.res
// Represents a position in the 2D grid with row and column coordinates

type t = {
  row: int,
  col: int,
}

// Create a position
let make = (row: int, col: int): t => {
  {row, col}
}

// Navigation functions
let right = (pos: t, ~n: int=1): t => {
  {row: pos.row, col: pos.col + n}
}

let down = (pos: t, ~n: int=1): t => {
  {row: pos.row + n, col: pos.col}
}

let left = (pos: t, ~n: int=1): t => {
  {row: pos.row, col: pos.col - n}
}

let up = (pos: t, ~n: int=1): t => {
  {row: pos.row - n, col: pos.col}
}

// Equality
let equals = (a: t, b: t): bool => {
  a.row == b.row && a.col == b.col
}

// String representation (1-indexed for user display)  
let toString = (pos: t): string => {
  let rowStr = Int.toString(pos.row + 1)
  let colStr = Int.toString(pos.col + 1)
  "(" ++ rowStr ++ ", " ++ colStr ++ ")"
}

// Create from user-friendly 1-indexed coordinates
let fromUserCoords = (row: int, col: int): t => {
  {row: row - 1, col: col - 1}
}

// Check if position is within bounds (inclusive)
let isWithin = (pos: t, bounds: Types.Bounds.t): bool => {
  pos.row >= bounds.top &&
  pos.row <= bounds.bottom &&
  pos.col >= bounds.left &&
  pos.col <= bounds.right
}
