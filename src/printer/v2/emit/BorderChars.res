// BorderChars.res
// ASCII / Unicode border-character tables.

type set = {
  topLeft: string,
  topRight: string,
  bottomLeft: string,
  bottomRight: string,
  horizontal: string,
  vertical: string,
  teeDown: string,
  teeUp: string,
  teeRight: string,
  teeLeft: string,
  cross: string,
}

let ascii: set = {
  topLeft: "+",
  topRight: "+",
  bottomLeft: "+",
  bottomRight: "+",
  horizontal: "-",
  vertical: "|",
  teeDown: "+",
  teeUp: "+",
  teeRight: "+",
  teeLeft: "+",
  cross: "+",
}

let unicode: set = {
  topLeft: `┌`,
  topRight: `┐`,
  bottomLeft: `└`,
  bottomRight: `┘`,
  horizontal: `─`,
  vertical: `│`,
  teeDown: `┬`,
  teeUp: `┴`,
  teeRight: `├`,
  teeLeft: `┤`,
  cross: `┼`,
}

let forCharset = (cs: PrintOptions.charset): set =>
  switch cs {
  | ASCII => ascii
  | Unicode => unicode
  }
