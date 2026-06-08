// InputParser.res
// `[__placeholder__]` — Priority 90.
// canParse: LBracket immediately followed by Underscores(2+). Whether the
// closing `__]` actually exists is decided in `parse`; if missing, parse
// emits an UnclosedInput error rather than letting TextParser swallow it.

open Token

let priority = Priority.input

let canParse = (stream: TokenStream.t): bool => {
  let lb = TokenStream.peek(stream)
  let underscore = TokenStream.peekAt(stream, 1)
  switch (lb.kind, underscore.kind) {
  | (LBracket, Underscores(n)) when n >= 2 => true
  | _ => false
  }
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let lb = TokenStream.peek(stream)
  switch lb.kind {
  | LBracket => {
      let startPos = lb.position
      let _ = TokenStream.next(stream) // [
      // The Lexer merges all consecutive underscores into a single
      // Underscores(N) token. Two cases for the opening:
      //   (a) Underscores(N>=4) directly followed by `]` → an empty-
      //       placeholder input like `[____________]` (REQ-7.4).
      //   (b) Otherwise consume the leading Underscores token as the
      //       opening delimiter and parse content until `Underscores(>=2) ]`.
      let opening = TokenStream.peek(stream)
      let emptyShortCircuit = switch opening.kind {
      | Underscores(n) when n >= 4 => {
          let next = TokenStream.peekAt(stream, 1)
          switch next.kind {
          | RBracket => true
          | _ => false
          }
        }
      | _ => false
      }
      let inner = ref("")
      let endPosRef = ref(startPos)
      let keep = ref(true)
      let closed = ref(false)
      if emptyShortCircuit {
        let rb = TokenStream.peekAt(stream, 1)
        endPosRef := rb.endPosition
        let _ = TokenStream.next(stream) // __...__
        let _ = TokenStream.next(stream) // ]
        closed := true
        keep := false
      } else {
        switch opening.kind {
        | Underscores(_) => let _ = TokenStream.next(stream)
        | _ => ()
        }
      }
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Underscores(n) when n >= 2 => {
            let next = TokenStream.peekAt(stream, 1)
            switch next.kind {
            | RBracket => {
                endPosRef := next.endPosition
                let _ = TokenStream.next(stream) // __
                let _ = TokenStream.next(stream) // ]
                closed := true
                keep := false
              }
            | _ => {
                inner := inner.contents ++ tok.text
                endPosRef := tok.endPosition
                let _ = TokenStream.next(stream)
              }
            }
          }
        | Newline | EOF => keep := false
        | _ => {
            inner := inner.contents ++ tok.text
            endPosRef := tok.endPosition
            let _ = TokenStream.next(stream)
          }
        }
      }
      if !closed.contents {
        // errorRecovery.inputSync: bounded to current row only.
        // Emit error AND surface an ErrorNode so the cursor stays advanced
        // (TextParser cannot retry these tokens and re-consume the prefix).
        let loc: V2Types.sourceLocation = {start: startPos, end_: endPosRef.contents}
        ParseContext.addError(
          ctx,
          V2Errors.makeError(~code=UnclosedInput, ~location=loc, ()),
        )
        let recovered = "[__" ++ inner.contents
        let errNode: V2Types.errorNode = {
          location: loc,
          message: V2Errors.getErrorMessage(UnclosedInput),
          recoveredContent: Some(recovered),
        }
        Some(V2Types.ErrorNode(errNode))
      } else {
        let placeholder = String.trim(inner.contents)
        let node: V2Types.inputNode = {
          location: {start: startPos, end_: endPosRef.contents},
          placeholder,
        }
        Some(V2Types.InputNode(node))
      }
    }
  | _ => None
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Input, ~priority, ~canParse, ~parse)
