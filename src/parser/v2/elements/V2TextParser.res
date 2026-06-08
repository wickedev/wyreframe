// TextParser.res
// Priority 1 fallback. Consumes from cursor up to end of row (Newline / EOF)
// and packages the joined text as a TextNode. Alignment uses Algorithm 4
// when an enclosing Container has known bounds.

open Token

let priority = Priority.text

// canParse: always true; this is the fallback.
let canParse = (_stream: TokenStream.t): bool => true

let determineAlignment = (
  ctx: ParseContext.t,
  startCol: int,
  endCol: int,
): V2Types.alignment => {
  switch ParseContext.currentContainerBounds(ctx) {
  | None => V2Types.Left
  | Some(b) => {
      // Inner-left = b.x + 1, inner-right = b.x + b.width - 2 (exclude `|`)
      let innerLeft = b.x + 1
      let innerRight = b.x + b.width - 2
      let w = Int.toFloat(innerRight - innerLeft + 1)
      if w <= 0.0 {
        V2Types.Left
      } else {
        let leftPad = startCol - innerLeft
        let rightPad = innerRight - (endCol - 1)
        let lp = leftPad < 0 ? 0 : leftPad
        let rp = rightPad < 0 ? 0 : rightPad
        if lp < 2 && rp < 2 {
          V2Types.Left
        } else {
          let rpRatio = Int.toFloat(rp) /. w
          let symRatio = Math.abs(Int.toFloat(lp - rp)) /. w
          if (
            rpRatio <= ctx.heuristics.rightAlignThreshold &&
            lp > rp * 2
          ) {
            V2Types.Right
          } else if symRatio <= ctx.heuristics.centerSymmetryThreshold {
            V2Types.Center
          } else {
            V2Types.Left
          }
        }
      }
    }
  }
}

// Consume tokens until end of row, building the text content.
let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let startTok = TokenStream.peek(stream)
  // If we're on a Newline already, do not emit anything.
  switch startTok.kind {
  | Newline | EOF => None
  | _ => {
      let startPos = startTok.position
      let endPosRef = ref(startTok.endPosition)
      let textRef = ref("")
      let keep = ref(true)
      // After we have consumed at least one token, stop at any inline-element
      // start so the outer parseContent loop can dispatch the right parser.
      // The first iteration always advances (otherwise we'd loop forever — the
      // registry already chose Text fallback for *this* position).
      let consumedAny = ref(false)
      let isInlineElementStart = (): bool => {
        let a = TokenStream.peek(stream)
        let b = TokenStream.peekAt(stream, 1)
        let c = TokenStream.peekAt(stream, 2)
        switch a.kind {
        | LBracket => true                          // Button/Select/Input/Checkbox
        | LAngle => true                            // Link
        | Quote => true                             // String
        | LParen =>
          // Radio marker requires `(*)` or `( )` on same row.
          switch (b.kind, c.kind) {
          | (Asterisk, RParen) => true
          | (Whitespace(w), RParen) when w == 1 => true
          | _ => false
          }
        | Dollar =>
          switch b.kind {
          | LBrace => true                          // PropPlaceholder
          | _ => false
          }
        | Colon =>
          // Emoji `:name:` — all three tokens on same row.
          switch (b.kind, c.kind) {
          | (Identifier, Colon) => a.position.row == c.position.row
          | _ => false
          }
        | _ => false
        }
      }
      let isWallPipe = (tok: Token.t): bool =>
        switch (tok.kind, ctx.wallCols) {
        | (Pipe, Some((lc, rc))) => {
            // Allow the wall to sit within containerColumnTolerance of
            // the expected position. Without this, a recovered nested
            // block whose outer container's right wall drifted by 1
            // would still consume the wall as text.
            let tol = ctx.heuristics.containerColumnTolerance
            let c = tok.position.col
            let near = (target: int) => c >= target - tol && c <= target + tol
            near(lc) || near(rc)
          }
        | _ => false
        }
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Newline | EOF => keep := false
        | Pipe when isWallPipe(tok) =>
          // The container wall on the right end of a recovered nested
          // block's row must NOT be consumed as text.
          keep := false
        | _ =>
          if consumedAny.contents && isInlineElementStart() {
            keep := false
          } else {
            textRef := textRef.contents ++ tok.text
            endPosRef := tok.endPosition
            let _ = TokenStream.next(stream)
            consumedAny := true
          }
        }
      }
      let content = String.trim(textRef.contents)
      if content == "" {
        None
      } else {
        // Compute trimmed start/end columns by walking through leading whitespace.
        let raw = textRef.contents
        let leadingSpaces = ref(0)
        let n = String.length(raw)
        let i = ref(0)
        let keep2 = ref(true)
        while keep2.contents && i.contents < n {
          let c = String.charAt(raw, i.contents)
          if c == " " || c == "\t" {
            leadingSpaces := leadingSpaces.contents + 1
            i := i.contents + 1
          } else {
            keep2 := false
          }
        }
        let actualStartCol = startPos.col + leadingSpaces.contents
        // For end col, use endPos minus trailing whitespace count.
        let trailing = ref(0)
        let j = ref(n - 1)
        let keep3 = ref(true)
        while keep3.contents && j.contents >= 0 {
          let c = String.charAt(raw, j.contents)
          if c == " " || c == "\t" {
            trailing := trailing.contents + 1
            j := j.contents - 1
          } else {
            keep3 := false
          }
        }
        let actualEndCol = endPosRef.contents.col - trailing.contents
        let align = determineAlignment(ctx, actualStartCol, actualEndCol)
        let node: V2Types.textNode = {
          location: {start: startPos, end_: endPosRef.contents},
          content,
          align,
        }
        Some(V2Types.TextNode(node))
      }
    }
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(
    ~elementType=V2Types.Text,
    ~priority,
    ~canParse,
    ~parse,
  )
