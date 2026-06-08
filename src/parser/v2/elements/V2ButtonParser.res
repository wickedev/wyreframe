// ButtonParser.res
// `[ text ]` — bracket form that's NOT Select/Input/Checkbox.
// canParse defers to those higher-priority parsers; if we reach here we accept
// any `[ ... ]` on the current row.

open Token

let priority = Priority.button

let canParse = (stream: TokenStream.t): bool => {
  let tok = TokenStream.peek(stream)
  switch tok.kind {
  | LBracket => {
      // Make sure there's a matching `]` on the same row.
      switch TokenStream.findOnCurrentRow(stream, t =>
        switch t.kind {
        | RBracket => true
        | _ => false
        }
      ) {
      | Some(_) => true
      | None => false
      }
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
      let _ = TokenStream.next(stream)
      // Accumulate inner text until `]`
      let textRef = ref("")
      let endPosRef = ref(lb.endPosition)
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
            textRef := textRef.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        }
      }
      let text = String.trim(textRef.contents)
      let id = Slugify.slugify(text == "" ? "button" : text)
      let node: V2Types.buttonNode = {
        location: {start: startPos, end_: endPosRef.contents},
        id,
        text,
      }
      Some(V2Types.ButtonNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Button, ~priority, ~canParse, ~parse)
