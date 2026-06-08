// PositionUtils.res
// Row/col/offset tracking helpers. All visual-width math routed through UnicodeUtils.

type t = V2Types.position

let make = (~row: int, ~col: int, ~offset: int): t => {row, col, offset}

let zero: t = {row: 0, col: 0, offset: 0}

// Advance a position by consuming `s` (no newlines expected here).
let advance = (p: t, s: string, ~tabSize: int=4, ()): t => {
  let width = UnicodeUtils.visualWidth(s, ~startCol=p.col, ~tabSize, ())
  {
    row: p.row,
    col: p.col + width,
    offset: p.offset + String.length(s),
  }
}

// Advance one newline.
let newline = (p: t): t => {
  row: p.row + 1,
  col: 0,
  offset: p.offset + 1,
}

// Format for human display (1-based).
let toDisplay = (p: t): string =>
  `(line ${Int.toString(p.row + 1)}, col ${Int.toString(p.col + 1)})`
