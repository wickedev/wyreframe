// PropPlaceholderParser.res
// `${name}`, `${name?}`, `${name:default}` — Priority 105.
// Standalone form (not inside a string). Inside `"..."` the StringParser
// handles interpolation.

open Token

let priority = Priority.propPlaceholder

let canParse = (stream: TokenStream.t): bool => {
  let d = TokenStream.peek(stream)
  let lb = TokenStream.peekAt(stream, 1)
  switch (d.kind, lb.kind) {
  | (Dollar, LBrace) => true
  | _ => false
  }
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let d = TokenStream.peek(stream)
  switch d.kind {
  | Dollar => {
      let startPos = d.position
      let _ = TokenStream.next(stream) // $
      let _ = TokenStream.next(stream) // {
      let inner = ref("")
      let endPos = ref(startPos)
      let closed = ref(false)
      let keep = ref(true)
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | RBrace => {
            endPos := tok.endPosition
            let _ = TokenStream.next(stream)
            closed := true
            keep := false
          }
        | Newline | EOF => keep := false
        | _ => {
            inner := inner.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        }
      }
      if !closed.contents {
        None
      } else {
        let raw = String.trim(inner.contents)
        // Split on the FIRST `:` only so defaults can contain colons
        // (URLs, timestamps, namespaces).
        let colonIdx = String.indexOf(raw, ":")
        let (name, required, defaultValue) = if colonIdx >= 0 {
          (
            String.trim(String.slice(raw, ~start=0, ~end=colonIdx)),
            true,
            Some(String.trim(String.slice(raw, ~start=colonIdx + 1, ~end=String.length(raw)))),
          )
        } else if String.endsWith(raw, "?") {
          (String.slice(raw, ~start=0, ~end=String.length(raw) - 1), false, None)
        } else {
          (raw, true, None)
        }
        let location: V2Types.sourceLocation = {start: startPos, end_: endPos.contents}
        if !ParseContext.isInComponent(ctx) {
          // REQ-14.4: scene-level ${...} is preserved as literal text. Emit
          // the warning AND return a TextNode so downstream consumers cannot
          // misinterpret it as a real component placeholder.
          let _ = (name, required, defaultValue) // values were computed for warning context only
          ParseContext.addWarning(
            ctx,
            V2Errors.makeWarning(~code=PropOutsideComponent, ~location, ()),
          )
          let textNode: V2Types.textNode = {
            location,
            content: "${" ++ raw ++ "}",
            align: V2Types.Left,
          }
          Some(V2Types.TextNode(textNode))
        } else {
          let node: V2Types.propPlaceholderNode = {
            location,
            name,
            required,
            defaultValue,
          }
          Some(V2Types.PropPlaceholderNode(node))
        }
      }
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.PropPlaceholder, ~priority, ~canParse, ~parse)
