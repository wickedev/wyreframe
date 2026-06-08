// EmojiParser.res
// `:name:` — Priority 100.
// canParse: Colon + Identifier + Colon, all on the same row.

open Token

let priority = Priority.emoji

let canParse = (stream: TokenStream.t): bool => {
  let c1 = TokenStream.peek(stream)
  let name = TokenStream.peekAt(stream, 1)
  let c2 = TokenStream.peekAt(stream, 2)
  switch (c1.kind, name.kind, c2.kind) {
  | (Colon, Identifier, Colon) =>
    // Require that all three sit on the same row.
    c1.position.row == c2.position.row
  | _ => false
  }
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let c1 = TokenStream.peek(stream)
  let name = TokenStream.peekAt(stream, 1)
  let c2 = TokenStream.peekAt(stream, 2)
  switch (c1.kind, name.kind, c2.kind) {
  | (Colon, Identifier, Colon) => {
      let _ = TokenStream.next(stream)
      let _ = TokenStream.next(stream)
      let _ = TokenStream.next(stream)
      let location: V2Types.sourceLocation = {start: c1.position, end_: c2.endPosition}
      let resolved = EmojiRegistry.lookupWithOverride(ctx.emojiRegistry, name.text)
      let emojiStr = switch resolved {
      | Some(e) => e
      | None => {
          ParseContext.addWarning(
            ctx,
            V2Errors.makeWarning(~code=UnknownEmoji(name.text), ~location, ()),
          )
          `:${name.text}:`
        }
      }
      let node: V2Types.emojiNode = {
        location,
        shortcode: name.text,
        emoji: emojiStr,
      }
      Some(V2Types.EmojiNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Emoji, ~priority, ~canParse, ~parse)
