// TokenStream.res
// Cursor over a pre-tokenized array with save/restore for canParse probes.
// Per design.md §Component 1, Task 8.

type t = {
  tokens: array<Token.t>,
  mutable cursor: int,
}

let make = (tokens: array<Token.t>): t => {tokens, cursor: 0}

let eofToken = (ts: t): Token.t => {
  let n = Array.length(ts.tokens)
  if n == 0 {
    Token.make(
      ~kind=EOF,
      ~text="",
      ~position=V2Types.zeroPos,
      ~endPosition=V2Types.zeroPos,
    )
  } else {
    ts.tokens->Array.getUnsafe(n - 1)
  }
}

let peek = (ts: t): Token.t => {
  if ts.cursor < Array.length(ts.tokens) {
    ts.tokens->Array.getUnsafe(ts.cursor)
  } else {
    eofToken(ts)
  }
}

let peekAt = (ts: t, n: int): Token.t => {
  let i = ts.cursor + n
  if i < Array.length(ts.tokens) {
    ts.tokens->Array.getUnsafe(i)
  } else {
    eofToken(ts)
  }
}

let next = (ts: t): Token.t => {
  let tok = peek(ts)
  if !Token.isEof(tok) {
    ts.cursor = ts.cursor + 1
  }
  tok
}

let isAtEnd = (ts: t): bool => Token.isEof(peek(ts))

let position = (ts: t): V2Types.position => peek(ts).position

let save = (ts: t): int => ts.cursor
let restore = (ts: t, snapshot: int): unit => {ts.cursor = snapshot}

// Move the cursor to the first token whose row is >= `row`. If no such
// token exists, set cursor at EOF.
let rewindToRow = (ts: t, row: int): unit => {
  let n = Array.length(ts.tokens)
  let i = ref(0)
  let found = ref(false)
  while !found.contents && i.contents < n {
    let tok = ts.tokens->Array.getUnsafe(i.contents)
    if tok.position.row >= row {
      ts.cursor = i.contents
      found := true
    } else {
      i := i.contents + 1
    }
  }
  if !found.contents {
    ts.cursor = n
  }
}

// Skip whitespace tokens (but not newlines) and return how many we skipped.
let skipInlineWhitespace = (ts: t): int => {
  let start = ts.cursor
  let keep = ref(true)
  while keep.contents {
    switch peek(ts).kind {
    | Whitespace(_) => let _ = next(ts)
    | _ => keep := false
    }
  }
  ts.cursor - start
}

// Skip to the next newline token (consuming it).
let skipToEndOfRow = (ts: t): unit => {
  let keep = ref(true)
  while keep.contents {
    let tok = peek(ts)
    switch tok.kind {
    | Newline => {
        let _ = next(ts)
        keep := false
      }
    | EOF => keep := false
    | _ => let _ = next(ts)
    }
  }
}

// Find the index of the next token on the current row with the given matcher,
// without advancing the cursor. Returns None if not found before row end.
let findOnCurrentRow = (ts: t, matcher: Token.t => bool): option<int> => {
  let start = ts.cursor
  let row = peek(ts).position.row
  let found = ref(None)
  let i = ref(start)
  let n = Array.length(ts.tokens)
  let keep = ref(true)
  while keep.contents && i.contents < n {
    let tok = ts.tokens->Array.getUnsafe(i.contents)
    if tok.position.row != row {
      keep := false
    } else {
      switch tok.kind {
      | Newline | EOF => keep := false
      | _ =>
        if matcher(tok) {
          found := Some(i.contents)
          keep := false
        } else {
          i := i.contents + 1
        }
      }
    }
  }
  found.contents
}
