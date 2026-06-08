// Token.res
// Physical (lexical) token kinds with grid-aware position info.
// Per design.md §Component 1 (Grid-Aware Lexer).

type position = V2Types.position

type tokenKind =
  | Identifier
  | Dashes(int)
  | Equals(int)
  | Plus
  | Pipe
  | LBracket
  | RBracket
  | LParen
  | RParen
  | LAngle
  | RAngle
  | Underscores(int)
  | Colon
  | Hash
  | Dollar
  | LBrace
  | RBrace
  | Asterisk
  | Quote
  | At
  | Comma
  | QuestionMark
  | Whitespace(int)
  | Newline
  | Other(string)
  | EOF

type t = {
  kind: tokenKind,
  text: string,
  position: position,
  endPosition: position,
}

let make = (~kind, ~text, ~position, ~endPosition): t => {
  kind,
  text,
  position,
  endPosition,
}

let isEof = (tok: t): bool =>
  switch tok.kind {
  | EOF => true
  | _ => false
  }

let isNewline = (tok: t): bool =>
  switch tok.kind {
  | Newline => true
  | _ => false
  }

let isWhitespace = (tok: t): bool =>
  switch tok.kind {
  | Whitespace(_) => true
  | _ => false
  }

let kindToString = (kind: tokenKind): string =>
  switch kind {
  | Identifier => "Identifier"
  | Dashes(n) => `Dashes(${Int.toString(n)})`
  | Equals(n) => `Equals(${Int.toString(n)})`
  | Plus => "Plus"
  | Pipe => "Pipe"
  | LBracket => "LBracket"
  | RBracket => "RBracket"
  | LParen => "LParen"
  | RParen => "RParen"
  | LAngle => "LAngle"
  | RAngle => "RAngle"
  | Underscores(n) => `Underscores(${Int.toString(n)})`
  | Colon => "Colon"
  | Hash => "Hash"
  | Dollar => "Dollar"
  | LBrace => "LBrace"
  | RBrace => "RBrace"
  | Asterisk => "Asterisk"
  | Quote => "Quote"
  | At => "At"
  | Comma => "Comma"
  | QuestionMark => "QuestionMark"
  | Whitespace(n) => `Whitespace(${Int.toString(n)})`
  | Newline => "Newline"
  | Other(s) => `Other(${s})`
  | EOF => "EOF"
  }
