// Position.res
// Core position type for 2D grid navigation with row/col coordinates

type t = {
  row: int,
  col: int,
}

// Create a new position with row and column coordinates
let make = (row: int, col: int): t => {
  row: row,
  col: col,
}

// Move right by n columns (default: 1)
let right = (pos: t, ~n: int=1): t => {
  {row: pos.row, col: pos.col + n}
}

// Move down by n rows (default: 1)
let down = (pos: t, ~n: int=1): t => {
  {row: pos.row + n, col: pos.col}
}

// Move left by n columns (default: 1)
let left = (pos: t, ~n: int=1): t => {
  {row: pos.row, col: pos.col - n}
}

// Move up by n rows (default: 1)
let up = (pos: t, ~n: int=1): t => {
  {row: pos.row - n, col: pos.col}
}

// Check if two positions are equal
let equals = (pos1: t, pos2: t): bool => {
  pos1.row === pos2.row && pos1.col === pos2.col
}

// Convert position to string format "(row, col)"
let toString = (pos: t): string => {
  "(" ++ Int.toString(pos.row) ++ ", " ++ Int.toString(pos.col) ++ ")"
}
