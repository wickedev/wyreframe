// StringParser.res
// `"text"` literal — Priority 115. Highest priority because once we enter a
// string, inner element-syntax must be treated as literal text.
// Supports multiline strings and ${prop}, :emoji: interpolations.

open Token

let priority = Priority.string

let canParse = (stream: TokenStream.t): bool =>
  switch TokenStream.peek(stream).kind {
  | Quote => true
  | _ => false
  }

// Parse the inner text of the string, accumulating literal chunks and
// interpolation refs. Returns (contentStr, interpolations, endPosOfClosingQuote, multiline, closed).
let parseInner = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): (string, array<V2Types.interpolationContent>, V2Types.position, bool, bool) => {
  // `content` accumulates the full string text (literal chars + resolved emoji
  // + literal `${...}` markers). `buf` only buffers the *current* literal run
  // that will be flushed into `parts` when an interpolation appears; flushing
  // must NOT drain `content`.
  let content = ref("")
  let buf = ref("")
  let parts: array<V2Types.interpolationContent> = []
  let multiline = ref(false)
  let closed = ref(false)
  let endPos = ref((TokenStream.peek(stream)).position)
  let keep = ref(true)
  // Append text to BOTH the visible content and the pending literal buffer.
  let append = (s: string) => {
    content := content.contents ++ s
    buf := buf.contents ++ s
  }
  // Flush pending buf into parts as a Literal segment WITHOUT touching content.
  let pushLiteral = () => {
    if buf.contents != "" {
      parts->Array.push(V2Types.Literal(buf.contents))
      buf := ""
    }
  }
  while keep.contents {
    let tok = TokenStream.peek(stream)
    switch tok.kind {
    | EOF => keep := false
    | Quote => {
        endPos := tok.endPosition
        let _ = TokenStream.next(stream)
        pushLiteral()
        closed := true
        keep := false
      }
    | Newline => {
        append("\n")
        endPos := tok.endPosition
        multiline := true
        let _ = TokenStream.next(stream)
      }
    | Dollar => {
        // Possibly ${prop}
        let next = TokenStream.peekAt(stream, 1)
        switch next.kind {
        | LBrace => {
            // Look forward for `}`
            let snap = TokenStream.save(stream)
            let _ = TokenStream.next(stream) // $
            let _ = TokenStream.next(stream) // {
            let inner = ref("")
            let foundClose = ref(false)
            let propEnd = ref(tok.position)
            let k = ref(true)
            while k.contents {
              let t = TokenStream.peek(stream)
              switch t.kind {
              | RBrace => {
                  propEnd := t.endPosition
                  let _ = TokenStream.next(stream)
                  foundClose := true
                  k := false
                }
              | Newline | EOF | Quote => k := false
              | _ => {
                  inner := inner.contents ++ t.text
                  let _ = TokenStream.next(stream)
                }
              }
            }
            if foundClose.contents {
              endPos := propEnd.contents
              // Parse the inner for name + optional default. Split on the
              // FIRST `:` only so defaults can contain colons (URLs etc.).
              let raw = String.trim(inner.contents)
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
              let propNode: V2Types.propPlaceholderNode = {
                location: {start: tok.position, end_: propEnd.contents},
                name,
                required,
                defaultValue,
              }
              if !ParseContext.isInComponent(ctx) {
                // Scene-level: warn AND preserve literal text — do NOT
                // emit a PropRef so consumers cannot misinterpret it as
                // a component placeholder.
                ParseContext.addWarning(
                  ctx,
                  V2Errors.makeWarning(
                    ~code=PropOutsideComponent,
                    ~location=propNode.location,
                    (),
                  ),
                )
                append("${" ++ raw ++ "}")
              } else {
                // Component-side: flush pending literal, record the ref,
                // and reflect the `${...}` marker in content so toString
                // shows the unresolved placeholder.
                pushLiteral()
                content := content.contents ++ "${" ++ raw ++ "}"
                parts->Array.push(V2Types.PropRef(propNode))
              }
            } else {
              // Treat as literal `$`
              TokenStream.restore(stream, snap)
              append("$")
              endPos := tok.endPosition
              let _ = TokenStream.next(stream)
            }
          }
        | _ => {
            append("$")
            endPos := tok.endPosition
            let _ = TokenStream.next(stream)
          }
        }
      }
    | Colon => {
        // Possibly :emoji:
        let nameTok = TokenStream.peekAt(stream, 1)
        let closeTok = TokenStream.peekAt(stream, 2)
        switch (nameTok.kind, closeTok.kind) {
        | (Identifier, Colon) => {
            let resolved = EmojiRegistry.lookupWithOverride(ctx.emojiRegistry, nameTok.text)
            let emojiNode: V2Types.emojiNode = {
              location: {start: tok.position, end_: closeTok.endPosition},
              shortcode: nameTok.text,
              emoji: resolved->Option.getOr(`:${nameTok.text}:`),
            }
            // Flush the prior literal run BEFORE recording the emoji.
            // The emoji glyph is appended only to `content` — not to `buf`
            // — so the next pushLiteral does not duplicate it inside a
            // Literal segment alongside the EmojiRef. Renderers walk
            // `interpolations` and would otherwise render the emoji twice.
            pushLiteral()
            switch resolved {
            | Some(e) => content := content.contents ++ e
            | None => {
                ParseContext.addWarning(
                  ctx,
                  V2Errors.makeWarning(
                    ~code=UnknownEmoji(nameTok.text),
                    ~location=emojiNode.location,
                    (),
                  ),
                )
                content := content.contents ++ `:${nameTok.text}:`
              }
            }
            parts->Array.push(V2Types.EmojiRef(emojiNode))
            endPos := closeTok.endPosition
            let _ = TokenStream.next(stream)
            let _ = TokenStream.next(stream)
            let _ = TokenStream.next(stream)
          }
        | _ => {
            append(":")
            endPos := tok.endPosition
            let _ = TokenStream.next(stream)
          }
        }
      }
    | _ => {
        // Handle backslash escapes within Other tokens.
        let text = tok.text
        // Update endPos as we consume so an unclosed string still reports a
        // location that covers the consumed literal.
        endPos := tok.endPosition
        if text == "\\" {
          let nextTok = TokenStream.peekAt(stream, 1)
          let nc = nextTok.text
          let decoded = switch nc {
          | "\"" => Some("\"")
          | "\\" => Some("\\")
          | "$" => Some("$")
          | _ => None
          }
          switch decoded {
          | Some(d) => {
              append(d)
              let _ = TokenStream.next(stream)
              endPos := nextTok.endPosition
              let _ = TokenStream.next(stream)
            }
          | None => {
              append(text)
              let _ = TokenStream.next(stream)
            }
          }
        } else {
          append(text)
          let _ = TokenStream.next(stream)
        }
      }
    }
  }
  pushLiteral()
  (content.contents, parts, endPos.contents, multiline.contents, closed.contents)
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let q = TokenStream.peek(stream)
  switch q.kind {
  | Quote => {
      let startPos = q.position
      let _ = TokenStream.next(stream)
      let (content, parts, endPos, multiline, closed) = parseInner(ctx, stream)
      if !closed {
        let loc: V2Types.sourceLocation = {start: startPos, end_: endPos}
        ParseContext.addError(
          ctx,
          V2Errors.makeError(~code=UnclosedString, ~location=loc, ()),
        )
        let errNode: V2Types.errorNode = {
          location: loc,
          message: V2Errors.getErrorMessage(UnclosedString),
          recoveredContent: Some("\"" ++ content),
        }
        Some(V2Types.ErrorNode(errNode))
      } else {
        let node: V2Types.stringNode = {
          location: {start: startPos, end_: endPos},
          content,
          interpolations: parts,
          multiline,
        }
        Some(V2Types.StringNode(node))
      }
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.String, ~priority, ~canParse, ~parse)
