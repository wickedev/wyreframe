// CheckboxParser.res
// `[x]`, `[X]`, `[v]`, `[V]`, `[ ]` followed by an optional label. Priority 80.
// Pattern requires exactly LBracket + (identifier-single-char OR Whitespace(1)) + RBracket.

open Token

let priority = Priority.checkbox

let isCheckMark = (tok: Token.t): option<bool> =>
  switch tok.kind {
  | Identifier when tok.text == "x" || tok.text == "X" || tok.text == "v" || tok.text == "V" =>
    Some(true)
  | Whitespace(w) when w == 1 => Some(false)
  | _ => None
  }

let canParse = (stream: TokenStream.t): bool => {
  let lb = TokenStream.peek(stream)
  let mid = TokenStream.peekAt(stream, 1)
  let rb = TokenStream.peekAt(stream, 2)
  switch (lb.kind, isCheckMark(mid), rb.kind) {
  | (LBracket, Some(_), RBracket) => true
  | _ => false
  }
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let lb = TokenStream.peek(stream)
  let mid = TokenStream.peekAt(stream, 1)
  let rb = TokenStream.peekAt(stream, 2)
  switch (lb.kind, isCheckMark(mid), rb.kind) {
  | (LBracket, Some(checked), RBracket) => {
      let startPos = lb.position
      let _ = TokenStream.next(stream) // [
      let _ = TokenStream.next(stream) // x|X|v|V| |
      let _ = TokenStream.next(stream) // ]
      let _ = TokenStream.skipInlineWhitespace(stream)
      // Capture label up to end of row, OR the next same-row checkbox
      // marker (so `[x] One [ ] Two` becomes two CheckboxNodes, not one
      // checkbox with a merged label).
      let labelRef = ref("")
      let endPosRef = ref(rb.endPosition)
      let keep = ref(true)
      let isNextCheckboxMarker = () => {
        let a = TokenStream.peek(stream)
        let b = TokenStream.peekAt(stream, 1)
        let c = TokenStream.peekAt(stream, 2)
        switch (a.kind, isCheckMark(b), c.kind) {
        | (LBracket, Some(_), RBracket) => true
        | _ => false
        }
      }
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Newline | EOF | Pipe => keep := false
        | LBracket when isNextCheckboxMarker() => keep := false
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
            ~code=MissingCheckboxLabel,
            ~location={start: startPos, end_: endPosRef.contents},
            (),
          ),
        )
      }
      let node: V2Types.checkboxNode = {
        location: {start: startPos, end_: endPosRef.contents},
        checked,
        label,
      }
      Some(V2Types.CheckboxNode(node))
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Checkbox, ~priority, ~canParse, ~parse)
