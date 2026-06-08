// SelectParser.res
// `[v: Placeholder]` — Priority 95.

open Token

let priority = Priority.select

let canParse = (stream: TokenStream.t): bool => {
  let lb = TokenStream.peek(stream)
  let id = TokenStream.peekAt(stream, 1)
  let colon = TokenStream.peekAt(stream, 2)
  switch (lb.kind, id.kind, colon.kind) {
  | (LBracket, Identifier, Colon) when id.text == "v" || id.text == "V" =>
    switch TokenStream.findOnCurrentRow(stream, t =>
      switch t.kind {
      | RBracket => true
      | _ => false
      }
    ) {
    | Some(_) => true
    | None => false
    }
  | _ => false
  }
}

let parse = (
  _ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let lb = TokenStream.peek(stream)
  switch lb.kind {
  | LBracket => {
      let startPos = lb.position
      let _ = TokenStream.next(stream) // [
      let _ = TokenStream.next(stream) // v
      let _ = TokenStream.next(stream) // :
      let inner = ref("")
      let endPosRef = ref(startPos)
      let keep = ref(true)
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | RBracket => {
            endPosRef := tok.endPosition
            let _ = TokenStream.next(stream)
            keep := false
          }
        | Newline | EOF => keep := false
        | _ => {
            inner := inner.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        }
      }
      let placeholder = String.trim(inner.contents)
      let id = Slugify.slugify(placeholder == "" ? "select" : placeholder)
      let node: V2Types.selectNode = {
        location: {start: startPos, end_: endPosRef.contents},
        id,
        placeholder,
      }
      Some(V2Types.SelectNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Select, ~priority, ~canParse, ~parse)
