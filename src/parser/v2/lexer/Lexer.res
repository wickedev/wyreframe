// Lexer.res
// Eager tokenizer producing physical tokens with grid-aware positions.
// Per design.md §Component 1, Task 9.

open Token

let isIdentChar = (cp: int): bool =>
  (cp >= 0x30 && cp <= 0x39) || // 0-9
  (cp >= 0x41 && cp <= 0x5A) || // A-Z
  (cp >= 0x61 && cp <= 0x7A) || // a-z
  // Allow CJK and wide identifier chars (Korean/Japanese/Chinese words).
  cp >= 0x80

// Read a run of a single ASCII char like '-' or '='.
let readRun = (s: Scanner.t, ch: string): int => {
  let count = ref(0)
  while !Scanner.isAtEnd(s) && Scanner.peek(s) == ch {
    let _ = Scanner.advance(s)
    count := count.contents + 1
  }
  count.contents
}

let readIdentifier = (s: Scanner.t): string => {
  let start = s.offset
  while !Scanner.isAtEnd(s) && isIdentChar(Scanner.peekCodePoint(s)) {
    let _ = Scanner.advance(s)
  }
  String.slice(s.source, ~start, ~end=s.offset)
}

let readWhitespaceRun = (s: Scanner.t): int => {
  let startCol = s.col
  let keep = ref(true)
  while keep.contents && !Scanner.isAtEnd(s) {
    let c = Scanner.peek(s)
    if c == " " || c == "\t" {
      let _ = Scanner.advance(s)
    } else {
      keep := false
    }
  }
  s.col - startCol
}

// Tokenize the entire source. Eager — returns the full array.
let tokenize = (~tabSize: int=4, source: string): array<Token.t> => {
  let s = Scanner.make(~source, ~tabSize, ())
  let tokens: array<Token.t> = []

  while !Scanner.isAtEnd(s) {
    let startPos = Scanner.position(s)
    let ch = Scanner.peek(s)
    let cp = Scanner.peekCodePoint(s)

    if ch == "\n" || ch == "\r" {
      // Scanner.advance handles CRLF → single newline; capture the resulting end pos.
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Newline, ~text="\n", ~position=startPos, ~endPosition=endPos))
    } else if ch == " " || ch == "\t" {
      let visW = readWhitespaceRun(s)
      let endPos = Scanner.position(s)
      let text = String.slice(source, ~start=startPos.offset, ~end=endPos.offset)
      tokens->Array.push(Token.make(~kind=Whitespace(visW), ~text, ~position=startPos, ~endPosition=endPos))
    } else if ch == "-" {
      let n = readRun(s, "-")
      let endPos = Scanner.position(s)
      let text = String.slice(source, ~start=startPos.offset, ~end=endPos.offset)
      tokens->Array.push(Token.make(~kind=Dashes(n), ~text, ~position=startPos, ~endPosition=endPos))
    } else if ch == "=" {
      let n = readRun(s, "=")
      let endPos = Scanner.position(s)
      let text = String.slice(source, ~start=startPos.offset, ~end=endPos.offset)
      tokens->Array.push(Token.make(~kind=Equals(n), ~text, ~position=startPos, ~endPosition=endPos))
    } else if ch == "_" {
      let n = readRun(s, "_")
      let endPos = Scanner.position(s)
      let text = String.slice(source, ~start=startPos.offset, ~end=endPos.offset)
      tokens->Array.push(Token.make(~kind=Underscores(n), ~text, ~position=startPos, ~endPosition=endPos))
    } else if ch == "+" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Plus, ~text="+", ~position=startPos, ~endPosition=endPos))
    } else if ch == "|" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Pipe, ~text="|", ~position=startPos, ~endPosition=endPos))
    } else if ch == "[" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=LBracket, ~text="[", ~position=startPos, ~endPosition=endPos))
    } else if ch == "]" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=RBracket, ~text="]", ~position=startPos, ~endPosition=endPos))
    } else if ch == "(" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=LParen, ~text="(", ~position=startPos, ~endPosition=endPos))
    } else if ch == ")" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=RParen, ~text=")", ~position=startPos, ~endPosition=endPos))
    } else if ch == "<" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=LAngle, ~text="<", ~position=startPos, ~endPosition=endPos))
    } else if ch == ">" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=RAngle, ~text=">", ~position=startPos, ~endPosition=endPos))
    } else if ch == ":" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Colon, ~text=":", ~position=startPos, ~endPosition=endPos))
    } else if ch == "#" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Hash, ~text="#", ~position=startPos, ~endPosition=endPos))
    } else if ch == "$" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Dollar, ~text="$", ~position=startPos, ~endPosition=endPos))
    } else if ch == "{" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=LBrace, ~text="{", ~position=startPos, ~endPosition=endPos))
    } else if ch == "}" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=RBrace, ~text="}", ~position=startPos, ~endPosition=endPos))
    } else if ch == "*" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Asterisk, ~text="*", ~position=startPos, ~endPosition=endPos))
    } else if ch == "\"" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Quote, ~text="\"", ~position=startPos, ~endPosition=endPos))
    } else if ch == "@" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=At, ~text="@", ~position=startPos, ~endPosition=endPos))
    } else if ch == "," {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Comma, ~text=",", ~position=startPos, ~endPosition=endPos))
    } else if ch == "?" {
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=QuestionMark, ~text="?", ~position=startPos, ~endPosition=endPos))
    } else if isIdentChar(cp) {
      let text = readIdentifier(s)
      let endPos = Scanner.position(s)
      tokens->Array.push(Token.make(~kind=Identifier, ~text, ~position=startPos, ~endPosition=endPos))
    } else {
      // Any other character — emit as Other (single char/code-point)
      let _ = Scanner.advance(s)
      let endPos = Scanner.position(s)
      let text = String.slice(source, ~start=startPos.offset, ~end=endPos.offset)
      tokens->Array.push(Token.make(~kind=Other(text), ~text, ~position=startPos, ~endPosition=endPos))
    }
  }

  let endPos = Scanner.position(s)
  tokens->Array.push(Token.make(~kind=EOF, ~text="", ~position=endPos, ~endPosition=endPos))
  tokens
}
