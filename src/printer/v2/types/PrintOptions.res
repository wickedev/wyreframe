// PrintOptions.res
// Public options record for the V2 ASCII Printer.

type charset =
  | ASCII
  | Unicode

type lineEnding =
  | LF
  | CRLF

type errorHandling =
  | Skip
  | RenderComment
  | Throw

type printOptions = {
  charset: charset,
  lineEnding: lineEnding,
  errorHandling: errorHandling,
  containerPadding: int,
  trimTrailing: bool,
  maxColumns: option<int>,
}

let defaultOptions = (): printOptions => {
  charset: ASCII,
  lineEnding: LF,
  errorHandling: RenderComment,
  containerPadding: 1,
  trimTrailing: false,
  maxColumns: None,
}

let lineEndingString = (le: lineEnding): string =>
  switch le {
  | LF => "\n"
  | CRLF => "\r\n"
  }
