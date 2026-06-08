// V2ElementParser.res
// Interface for element parsers.
// canParse: read-only probe (use save/restore for any look-ahead).
// parse: consume tokens and emit an astNode; record errors via ctx.

type parseResult = option<V2Types.astNode>

type t = {
  elementType: V2Types.nodeType,
  priority: int,
  canParse: TokenStream.t => bool,
  parse: (ParseContext.t, TokenStream.t) => parseResult,
}

let make = (
  ~elementType: V2Types.nodeType,
  ~priority: int,
  ~canParse: TokenStream.t => bool,
  ~parse: (ParseContext.t, TokenStream.t) => parseResult,
): t => {
  elementType,
  priority,
  canParse,
  parse,
}
