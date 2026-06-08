// GridIndex.res
// Random-access (row, col) → token index over a tokenized source.
// Per design.md §Component 1, Task 10.

type t = {
  // row -> array of (startCol, endCol, tokenIndex), sorted by startCol
  rows: Dict.t<array<(int, int, int)>>,
  lastRow: int,
}

let make = (tokens: array<Token.t>): t => {
  let rows: Dict.t<array<(int, int, int)>> = Dict.make()
  let lastRow = ref(0)
  Array.forEachWithIndex(tokens, (tok, i) => {
    switch tok.kind {
    | Newline | EOF | Whitespace(_) => ()
    | _ => {
        let row = tok.position.row
        if row > lastRow.contents {
          lastRow := row
        }
        let key = Int.toString(row)
        let existing = Dict.get(rows, key)->Option.getOr([])
        existing->Array.push((tok.position.col, tok.endPosition.col, i))
        Dict.set(rows, key, existing)
      }
    }
  })
  {rows, lastRow: lastRow.contents}
}

let rowTokensIndices = (g: t, ~row: int): array<(int, int, int)> =>
  Dict.get(g.rows, Int.toString(row))->Option.getOr([])

let tokenAt = (g: t, tokens: array<Token.t>, ~row: int, ~col: int): option<Token.t> => {
  let entries = rowTokensIndices(g, ~row)
  let found = ref(None)
  Array.forEach(entries, ((startCol, endCol, i)) => {
    if col >= startCol && col < endCol {
      found := Some(tokens->Array.getUnsafe(i))
    }
  })
  found.contents
}

// Char at visual column. Returns " " when whitespace / out of range.
let charAt = (g: t, tokens: array<Token.t>, ~row: int, ~col: int): string => {
  switch tokenAt(g, tokens, ~row, ~col) {
  | Some(tok) => {
      // Compute the relative column offset within the token.
      let rel = col - tok.position.col
      // For most tokens text length matches visual width 1:1 (ASCII punctuation).
      // For multi-char tokens (Dashes(n), Underscores(n), Equals(n)) it also matches.
      if rel >= 0 && rel < String.length(tok.text) {
        String.charAt(tok.text, rel)
      } else {
        " "
      }
    }
  | None => " "
  }
}

let lastRow = (g: t): int => g.lastRow
