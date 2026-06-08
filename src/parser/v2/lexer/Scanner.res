// Scanner.res
// Character-level scanner with CRLF normalization and visual-column tracking.
// Per design.md §Lexer.

type t = {
  source: string,
  mutable offset: int,
  mutable row: int,
  mutable col: int,
  tabSize: int,
  // When the previous advance() consumed U+200D (Zero Width Joiner), the
  // NEXT code point is part of the same grapheme cluster and must not add
  // visual width (emoji ZWJ sequences like `👨‍👩‍👧` are one wide cell).
  mutable prevWasZwj: bool,
}

let make = (~source: string, ~tabSize: int=4, ()): t => {
  source,
  offset: 0,
  row: 0,
  col: 0,
  tabSize,
  prevWasZwj: false,
}

let isAtEnd = (s: t): bool => s.offset >= String.length(s.source)

// Peek a single character (string of length 1 — ascii or one UTF-16 unit).
let peek = (s: t): string =>
  if isAtEnd(s) {
    ""
  } else {
    String.charAt(s.source, s.offset)
  }

// Peek n characters ahead.
let peekAt = (s: t, n: int): string =>
  if s.offset + n >= String.length(s.source) {
    ""
  } else {
    String.charAt(s.source, s.offset + n)
  }

// Peek the next code point (handles surrogate pairs).
let peekCodePoint = (s: t): int =>
  if isAtEnd(s) {
    -1
  } else {
    String.codePointAt(s.source, s.offset)->Option.getOr(-1)
  }

// Advance by one code unit (or two for surrogate pairs).
let rec advance = (s: t): string => {
  if isAtEnd(s) {
    ""
  } else {
    let cp = peekCodePoint(s)
    let cuLen = if cp > 0xFFFF { 2 } else { 1 }
    let ch = String.slice(s.source, ~start=s.offset, ~end=s.offset + cuLen)
    // CRLF: skip the \r; the \n on next call will bump row.
    if ch == "\r" && peekAt(s, 1) == "\n" {
      s.offset = s.offset + 1
      s.prevWasZwj = false
      // Recurse to return the \n properly so row bookkeeping is correct.
      advance(s)
    } else if ch == "\n" || ch == "\r" {
      // Treat both LF and standalone CR as a row break (old-Mac files).
      s.offset = s.offset + 1
      s.row = s.row + 1
      s.col = 0
      s.prevWasZwj = false
      "\n"
    } else if ch == "\t" {
      let next = (s.col / s.tabSize + 1) * s.tabSize
      s.col = next
      s.offset = s.offset + 1
      s.prevWasZwj = false
      "\t"
    } else if cp == 0x200D {
      // ZWJ: width 0, mark so the following code point is absorbed.
      s.offset = s.offset + cuLen
      s.prevWasZwj = true
      ch
    } else if s.prevWasZwj {
      // Part of a ZWJ-joined cluster: no width.
      s.offset = s.offset + cuLen
      s.prevWasZwj = false
      ch
    } else if UnicodeUtils.isCombining(cp) {
      s.offset = s.offset + cuLen
      ch
    } else if UnicodeUtils.isWide(cp) {
      s.offset = s.offset + cuLen
      s.col = s.col + 2
      ch
    } else {
      s.offset = s.offset + cuLen
      s.col = s.col + 1
      ch
    }
  }
}

let position = (s: t): V2Types.position => {
  row: s.row,
  col: s.col,
  offset: s.offset,
}
