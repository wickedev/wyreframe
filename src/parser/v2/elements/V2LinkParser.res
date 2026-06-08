// LinkParser.res
// `< text >` syntax — Priority 60.

open Token

let priority = Priority.link

let canParse = (stream: TokenStream.t): bool => {
  let tok = TokenStream.peek(stream)
  switch tok.kind {
  | LAngle =>
    switch TokenStream.findOnCurrentRow(stream, t =>
      switch t.kind {
      | RAngle => true
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
  let la = TokenStream.peek(stream)
  switch la.kind {
  | LAngle => {
      let startPos = la.position
      let _ = TokenStream.next(stream)
      let textRef = ref("")
      let endPosRef = ref(la.endPosition)
      let keep = ref(true)
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | RAngle => {
            endPosRef := tok.endPosition
            let _ = TokenStream.next(stream)
            keep := false
          }
        | Newline | EOF => keep := false
        | _ => {
            textRef := textRef.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        }
      }
      let text = String.trim(textRef.contents)
      let id = Slugify.slugify(text == "" ? "link" : text)
      let node: V2Types.linkNode = {
        location: {start: startPos, end_: endPosRef.contents},
        id,
        text,
      }
      Some(V2Types.LinkNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Link, ~priority, ~canParse, ~parse)
