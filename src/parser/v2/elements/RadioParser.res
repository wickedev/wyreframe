// RadioParser.res
// `(*) label` selected; `( ) label` unselected. Priority 85.

open Token

let priority = Priority.radio

let canParse = (stream: TokenStream.t): bool => {
  let lp = TokenStream.peek(stream)
  let mid = TokenStream.peekAt(stream, 1)
  let rp = TokenStream.peekAt(stream, 2)
  switch (lp.kind, mid.kind, rp.kind) {
  | (LParen, Asterisk, RParen) => true
  | (LParen, Whitespace(w), RParen) when w == 1 => true
  | _ => false
  }
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let lp = TokenStream.peek(stream)
  let mid = TokenStream.peekAt(stream, 1)
  let rp = TokenStream.peekAt(stream, 2)
  let selected = switch mid.kind {
  | Asterisk => true
  | _ => false
  }
  switch (lp.kind, rp.kind) {
  | (LParen, RParen) => {
      let startPos = lp.position
      let _ = TokenStream.next(stream)
      let _ = TokenStream.next(stream)
      let _ = TokenStream.next(stream)
      let _ = TokenStream.skipInlineWhitespace(stream)
      let labelRef = ref("")
      let endPosRef = ref(rp.endPosition)
      let keep = ref(true)
      // Stop at row boundaries (Newline/EOF), wall (Pipe), OR a following
      // radio marker `(*)` / `( )` on the same row so horizontal radios are
      // not swallowed into a single label.
      let isNextRadioMarker = () => {
        let a = TokenStream.peek(stream)
        let b = TokenStream.peekAt(stream, 1)
        let c = TokenStream.peekAt(stream, 2)
        switch (a.kind, b.kind, c.kind) {
        | (LParen, Asterisk, RParen) => true
        | (LParen, Whitespace(w), RParen) when w == 1 => true
        | _ => false
        }
      }
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Newline | EOF | Pipe => keep := false
        | LParen when isNextRadioMarker() => keep := false
        | Whitespace(_) => {
            // Consume whitespace into the label text but do NOT advance
            // endPosRef — otherwise the radio's end position runs right up
            // to the next marker, and RadioGrouper sees a zero gap between
            // wide-spaced same-row radios.
            labelRef := labelRef.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        | _ => {
            labelRef := labelRef.contents ++ tok.text
            endPosRef := tok.endPosition
            let _ = TokenStream.next(stream)
          }
        }
      }
      let label = String.trim(labelRef.contents)
      if label == "" {
        ParseContext.addWarning(
          ctx,
          V2Errors.makeWarning(
            ~code=MissingRadioLabel,
            ~location={start: startPos, end_: endPosRef.contents},
            (),
          ),
        )
      }
      let node: V2Types.radioNode = {
        location: {start: startPos, end_: endPosRef.contents},
        selected,
        label,
        group: None,
      }
      Some(V2Types.RadioNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Radio, ~priority, ~canParse, ~parse)
