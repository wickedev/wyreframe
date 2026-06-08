// ContainerParser.res
// Grid-based container detection per Algorithm 1.
// Cursor enters at row R where a `+--...--+` (top border) sits.
// We detect Lc, Rc, walk rows down, find matching bottom border, then
// recursively parse the inner content via the registry (re-tokenize sub-region).

open Token

let priority = Priority.container

// Split a source into rows independent of line-ending convention.
// Matches the lexer's handling of LF, CRLF, and bare CR (REQ-22 / Assumption 2).
let splitLines = (source: string): array<string> => {
  let normalized =
    source
    ->String.replaceRegExp(%re("/\r\n/g"), "\n")
    ->String.replaceRegExp(%re("/\r/g"), "\n")
  String.split(normalized, "\n")
}

// Compute the byte/UTF-16 start offset of every row in the ORIGINAL source.
// Required so child-node offsets stay accurate under CRLF: `splitLines`
// normalizes separators to LF and would otherwise undercount by 1 byte per
// preceding CRLF row.
let rowStartOffsets = (source: string): array<int> => {
  let n = String.length(source)
  let result: array<int> = [0]
  let i = ref(0)
  while i.contents < n {
    let ch = String.charAt(source, i.contents)
    if ch == "\r" {
      let next = i.contents + 1
      let isCRLF =
        next < n && String.charAt(source, next) == "\n"
      let skip = isCRLF ? 2 : 1
      result->Array.push(i.contents + skip)
      i := i.contents + skip
    } else if ch == "\n" {
      result->Array.push(i.contents + 1)
      i := i.contents + 1
    } else {
      i := i.contents + 1
    }
  }
  result
}

// Detect a top border at cursor position. Returns Some(Lc, Rc, name, format1Id, endPos)
// where Lc/Rc are visual columns of the corner `+`s, name is text between dashes
// or None for purely `+---+`, and format1Id is parsed from `+--#id--+`.
let detectTopBorder = (
  stream: TokenStream.t,
): option<(int, int, option<string>, option<string>, V2Types.position)> => {
  let snap = TokenStream.save(stream)
  let plus1 = TokenStream.peek(stream)
  switch plus1.kind {
  | Plus => {
      let lc = plus1.position.col
      let _ = TokenStream.next(stream)
      let nameBuf = ref("")
      let idCandidate = ref(None)
      let sawDashes = ref(false)
      let keep = ref(true)
      let endPos = ref(plus1.endPosition)
      let plus2Col = ref(-1)
      while keep.contents {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Dashes(_) => {
            sawDashes := true
            let _ = TokenStream.next(stream)
          }
        | Plus => {
            plus2Col := tok.position.col
            endPos := tok.endPosition
            let _ = TokenStream.next(stream)
            keep := false
          }
        | Newline | EOF => keep := false
        | Hash => {
            // `+--#id--+` — the ID can contain hyphens (`#account-email`).
            // Accumulate Identifier tokens; a single-Dash is part of the ID
            // ONLY when followed by another Identifier (so a trailing `-`
            // before the closing `+` is left to the border, not the id).
            let _ = TokenStream.next(stream)
            let idBuf = ref("")
            let keepId = ref(true)
            while keepId.contents {
              let t = TokenStream.peek(stream)
              switch t.kind {
              | Identifier => {
                  idBuf := idBuf.contents ++ t.text
                  let _ = TokenStream.next(stream)
                }
              | Dashes(1) => {
                  let next = TokenStream.peekAt(stream, 1)
                  switch next.kind {
                  | Identifier => {
                      idBuf := idBuf.contents ++ "-"
                      let _ = TokenStream.next(stream)
                    }
                  | _ => keepId := false
                  }
                }
              | _ => keepId := false
              }
            }
            if idBuf.contents != "" {
              idCandidate := Some(idBuf.contents)
            }
          }
        | Identifier => {
            nameBuf := nameBuf.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        | Whitespace(_) => {
            nameBuf := nameBuf.contents ++ tok.text
            let _ = TokenStream.next(stream)
          }
        | _ => {
            // Anything unexpected in a top border → reject.
            keep := false
            plus2Col := -2
          }
        }
      }
      // Require either a dash run OR a Format-1 ID between the corner pluses.
      // REQ-3.1 lists `+#id+`, `+-#id-+`, `+--#id--+` as valid formats.
      let hasShape = sawDashes.contents || Option.isSome(idCandidate.contents)
      if plus2Col.contents < 0 || !hasShape {
        TokenStream.restore(stream, snap)
        None
      } else {
        // Require the line to end at Newline/EOF after optional trailing
        // whitespace. Anything else (e.g. `+---+ trailing text`) disqualifies
        // the row as a top border — otherwise we silently drop the trailing
        // content and mis-construct the container.
        let after = TokenStream.peek(stream)
        let trailingOk = switch after.kind {
        | Newline | EOF => true
        | Whitespace(_) =>
          switch (TokenStream.peekAt(stream, 1)).kind {
          | Newline | EOF => true
          | _ => false
          }
        | _ => false
        }
        if !trailingOk {
          TokenStream.restore(stream, snap)
          None
        } else {
          TokenStream.restore(stream, snap)
          let name = String.trim(nameBuf.contents)
          Some((
            lc,
            plus2Col.contents,
            name == "" ? None : Some(name),
            idCandidate.contents,
            endPos.contents,
          ))
        }
      }
    }
  | _ => {
      TokenStream.restore(stream, snap)
      None
    }
  }
}

let canParse = (stream: TokenStream.t): bool => {
  switch detectTopBorder(stream) {
  | Some(_) => true
  | None => false
  }
}

// Advance the cursor past the rest of the current row (consuming Newline if any).
let consumeRow = (stream: TokenStream.t): unit => {
  let keep = ref(true)
  while keep.contents {
    let tok = TokenStream.peek(stream)
    switch tok.kind {
    | Newline => {
        let _ = TokenStream.next(stream)
        keep := false
      }
    | EOF => keep := false
    | _ => let _ = TokenStream.next(stream)
    }
  }
}

// Result of bottom-border probing for a single row.
type bottomMatch =
  | NoMatch
  | Exact
  | Tolerated  // matched within heuristic tolerance — caller should warn

// Probe one row. Returns:
//   Exact     — both corners exactly `+` and dash run between → ours.
//   Tolerated — corners are within `tolerance` columns AND lc/rc themselves
//               are NOT `|` (wall present means we're still inside the outer
//               container's body, e.g. a nested container row).
//   NoMatch   — neither applies.
let isBottomBorderRow = (
  gridIndex: GridIndex.t,
  tokens: array<Token.t>,
  ~row: int,
  ~lc: int,
  ~rc: int,
  ~tolerance: int,
): bottomMatch => {
  let chL = GridIndex.charAt(gridIndex, tokens, ~row, ~col=lc)
  let chR = GridIndex.charAt(gridIndex, tokens, ~row, ~col=rc)
  let dashRunPresent = () => {
    let foundDash = ref(false)
    let c = ref(lc + 1)
    while !foundDash.contents && c.contents < rc {
      let ch = GridIndex.charAt(gridIndex, tokens, ~row, ~col=c.contents)
      if ch == "-" || ch == "=" {
        foundDash := true
      }
      c := c.contents + 1
    }
    foundDash.contents
  }
  if chL == "+" && chR == "+" && dashRunPresent() {
    Exact
  } else if chL == "|" || chR == "|" {
    // Outer container's wall still present → this is a body row (possibly
    // hosting a nested container). NEVER tolerate, otherwise an inner
    // container's `+` would be mistaken for our bottom corner.
    NoMatch
  } else if tolerance <= 0 {
    NoMatch
  } else {
    // Seed from EXACT-corner matches first: if one corner sits at lc/rc
    // and the other is within the tolerance window, this is still a one-
    // sided drift we want to accept (e.g. `+----+` top vs `+---+` bottom).
    let leftHit = ref(chL == "+")
    let rightHit = ref(chR == "+")
    let d = ref(1)
    while (!leftHit.contents || !rightHit.contents) && d.contents <= tolerance {
      if !leftHit.contents {
        let lm = GridIndex.charAt(gridIndex, tokens, ~row, ~col=lc - d.contents)
        let lp = GridIndex.charAt(gridIndex, tokens, ~row, ~col=lc + d.contents)
        if lm == "+" || lp == "+" {
          leftHit := true
        }
      }
      if !rightHit.contents {
        let rm = GridIndex.charAt(gridIndex, tokens, ~row, ~col=rc - d.contents)
        let rp = GridIndex.charAt(gridIndex, tokens, ~row, ~col=rc + d.contents)
        if rm == "+" || rp == "+" {
          rightHit := true
        }
      }
      d := d.contents + 1
    }
    if leftHit.contents && rightHit.contents && dashRunPresent() {
      Tolerated
    } else {
      NoMatch
    }
  }
}

// Test if a body row's walls are `|` at lc/rc (Exact) or within
// `containerColumnTolerance` of them (Tolerated). Returns (leftMatch, rightMatch)
// where each is `Exact | Tolerated | NoMatch`. A `|` within tolerance counts
// as a body wall but the caller should emit MisalignedContainerWall.
type wallMatch = Exact | Tolerated | NoMatch

let wallAt = (
  gridIndex: GridIndex.t,
  tokens: array<Token.t>,
  ~row: int,
  ~col: int,
  ~tolerance: int,
): wallMatch => {
  let ch = GridIndex.charAt(gridIndex, tokens, ~row, ~col)
  if ch == "|" {
    Exact
  } else if tolerance <= 0 {
    NoMatch
  } else {
    let found = ref(false)
    let d = ref(1)
    while !found.contents && d.contents <= tolerance {
      let chM = GridIndex.charAt(gridIndex, tokens, ~row, ~col=col - d.contents)
      let chP = GridIndex.charAt(gridIndex, tokens, ~row, ~col=col + d.contents)
      if chM == "|" || chP == "|" {
        found := true
      }
      d := d.contents + 1
    }
    found.contents ? Tolerated : NoMatch
  }
}

let bodyRowWalls = (
  gridIndex: GridIndex.t,
  tokens: array<Token.t>,
  ~row: int,
  ~lc: int,
  ~rc: int,
  ~tolerance: int,
): (wallMatch, wallMatch) => {
  (
    wallAt(gridIndex, tokens, ~row, ~col=lc, ~tolerance),
    wallAt(gridIndex, tokens, ~row, ~col=rc, ~tolerance),
  )
}

// Locate the `+` columns on the bottom-border row (it's known to contain
// two `+`s with a dash run between them; corner alignment may have drifted).
// Returns (lcBottom, rcBottom) or (-1, -1) when not found.
let bottomCornerCols = (
  gridIndex: GridIndex.t,
  tokens: array<Token.t>,
  ~row: int,
  ~hintLc: int,
  ~hintRc: int,
  ~tolerance: int,
): (int, int) => {
  let lcOut = ref(-1)
  let rcOut = ref(-1)
  // Search around hintLc for `+`, then search rightward from there for the
  // matching `+`.
  // Try exact first, then tolerance window.
  let probe = (col: int) =>
    GridIndex.charAt(gridIndex, tokens, ~row, ~col) == "+"
  if probe(hintLc) {
    lcOut := hintLc
  } else {
    let d = ref(1)
    while lcOut.contents < 0 && d.contents <= tolerance {
      if probe(hintLc - d.contents) {
        lcOut := hintLc - d.contents
      } else if probe(hintLc + d.contents) {
        lcOut := hintLc + d.contents
      }
      d := d.contents + 1
    }
  }
  if probe(hintRc) {
    rcOut := hintRc
  } else {
    let d = ref(1)
    while rcOut.contents < 0 && d.contents <= tolerance {
      if probe(hintRc - d.contents) {
        rcOut := hintRc - d.contents
      } else if probe(hintRc + d.contents) {
        rcOut := hintRc + d.contents
      }
      d := d.contents + 1
    }
  }
  (lcOut.contents, rcOut.contents)
}

// Find the matching bottom-border row. Returns:
//   (row, bottomTolerated, wallTolerated, widthMismatch)
// row=-1 on failure.
let findBottomRow = (
  ctx: ParseContext.t,
  topRow: int,
  ~lc: int,
  ~rc: int,
): (int, bool, bool, bool) => {
  let colTolerance = ctx.heuristics.containerColumnTolerance
  let widthTolerance = ctx.heuristics.containerWidthTolerance
  // Use the larger window for the bottom-border SCAN so we find drifted
  // borders. Width-tolerance is then evaluated separately.
  let tolerance =
    colTolerance > widthTolerance ? colTolerance : widthTolerance
  let r = ref(topRow + 1)
  let maxRow = GridIndex.lastRow(ctx.gridIndex) + 1
  let found = ref(-1)
  let bottomTolerated = ref(false)
  let wallTolerated = ref(false)
  let keep = ref(true)
  while keep.contents && r.contents <= maxRow {
    switch isBottomBorderRow(ctx.gridIndex, ctx.tokens, ~row=r.contents, ~lc, ~rc, ~tolerance) {
    | Exact => {
        found := r.contents
        keep := false
      }
    | Tolerated => {
        found := r.contents
        bottomTolerated := true
        keep := false
      }
    | NoMatch => {
      // Body walls use the *column* tolerance, not the (possibly larger) width
      // tolerance: a body wall further than colTolerance away is not a wall.
      let (lWall, rWall) = bodyRowWalls(ctx.gridIndex, ctx.tokens, ~row=r.contents, ~lc, ~rc, ~tolerance=colTolerance)
      // A wall is "present" (exact or tolerated). Both NoMatch means this
      // row neither matches a bottom border nor has body walls — bail
      // unless the row is entirely blank.
      let lPresent = switch lWall { | NoMatch => false | _ => true }
      let rPresent = switch rWall { | NoMatch => false | _ => true }
      if (lWall == Tolerated || rWall == Tolerated) && (lPresent && rPresent) {
        wallTolerated := true
      }
      // Row content presence check, shared between two branches below.
      let hasAnything = ref(false)
      let c = ref(lc + 1)
      while !hasAnything.contents && c.contents < rc {
        let ch = GridIndex.charAt(ctx.gridIndex, ctx.tokens, ~row=r.contents, ~col=c.contents)
        if ch != " " && ch != "" {
          hasAnything := true
        }
        c := c.contents + 1
      }
      if !lPresent && !rPresent {
        // Blank rows are fine; non-blank rows with no walls bail.
        if hasAnything.contents {
          keep := false
        } else {
          r := r.contents + 1
        }
      } else if !lPresent || !rPresent {
        // Exactly one wall present. If the row has body content, this is a
        // malformed body row (REQ-2.2 requires `|` on both ends). Emit
        // MisalignedContainerWall warning and continue scanning.
        if hasAnything.contents {
          wallTolerated := true
        }
        r := r.contents + 1
      } else {
        r := r.contents + 1
      }
    }
    }
  }
  // Compute width-mismatch flag: if we found a bottom, scan its actual `+`
  // columns and compare width with the top's. Differing by >0 but ≤ widthTolerance
  // → mismatch warning. >widthTolerance is technically still accepted (the
  // border was matched via the colTolerance/widthTolerance scan above), so
  // we still flag it but the caller already has a warning option.
  let widthMismatch = ref(false)
  if found.contents >= 0 {
    let (lcB, rcB) =
      bottomCornerCols(ctx.gridIndex, ctx.tokens, ~row=found.contents, ~hintLc=lc, ~hintRc=rc, ~tolerance)
    if lcB >= 0 && rcB >= 0 {
      let topWidth = rc - lc + 1
      let bottomWidth = rcB - lcB + 1
      if topWidth != bottomWidth {
        widthMismatch := true
      }
    }
  }
  (found.contents, bottomTolerated.contents, wallTolerated.contents, widthMismatch.contents)
}

// Re-tokenize a substring (inner region) and run the registry on it.
// We re-use the source: just slice rows topRow+1..bottomRow-1 between columns (lc+1, rc-1).
let extractInnerSource = (
  ctx: ParseContext.t,
  ~topRow: int,
  ~bottomRow: int,
  ~lc: int,
  ~rc: int,
): string => {
  let lines = splitLines(ctx.source)
  // Convert a visual column target to the corresponding byte/UTF-16 index in
  // the given line, accounting for tabs and wide characters.
  let byteIndexForVisualCol = (line: string, targetCol: int): int => {
    let n = String.length(line)
    let i = ref(0)
    let col = ref(0)
    let keep = ref(true)
    while keep.contents && i.contents < n && col.contents < targetCol {
      let cp = String.codePointAt(line, i.contents)->Option.getOr(0x20)
      let cuLen = if cp > 0xFFFF { 2 } else { 1 }
      if cp == 0x09 {
        let next = (col.contents / ctx.tabSize + 1) * ctx.tabSize
        col := next
      } else if UnicodeUtils.isCombining(cp) {
        ()
      } else if UnicodeUtils.isWide(cp) {
        col := col.contents + 2
      } else {
        col := col.contents + 1
      }
      i := i.contents + cuLen
      if col.contents >= targetCol {
        keep := false
      }
    }
    i.contents
  }
  let buf = ref("")
  let r = ref(topRow + 1)
  while r.contents < bottomRow {
    let line = lines->Array.get(r.contents)->Option.getOr("")
    let len = String.length(line)
    // lc/rc are visual columns of the outer walls. Inner content lives in
    // [lc+1, rc-1] visually. Convert both endpoints to byte indices.
    let innerStartByte = byteIndexForVisualCol(line, lc + 1)
    let innerEndByte = byteIndexForVisualCol(line, rc)
    let safeStart = innerStartByte > len ? len : innerStartByte
    let safeEnd = innerEndByte > len ? len : innerEndByte
    let slice = if safeStart >= safeEnd {
      ""
    } else {
      String.slice(line, ~start=safeStart, ~end=safeEnd)
    }
    // Strip a trailing pipe ONLY when the row's canonical right-wall column
    // does NOT actually contain `|` — i.e. the row is mis-aligned (the right
    // wall sits earlier than rc) and the slice has engulfed that wall.
    // For well-aligned rows the wall is at column rc and the slice's content
    // stops one byte before it; any trailing `|` in the slice is literal
    // user text and MUST be preserved (e.g. `| a||` → "a|").
    let wallAtCanonical = String.charAt(line, innerEndByte) == "|"
    let trimmedSlice = if !wallAtCanonical && String.endsWith(slice, "|") {
      String.slice(slice, ~start=0, ~end=String.length(slice) - 1)
    } else {
      slice
    }
    buf := buf.contents ++ trimmedSlice
    if r.contents < bottomRow - 1 {
      buf := buf.contents ++ "\n"
    }
    r := r.contents + 1
  }
  buf.contents
}

// Helper: parse content recursively using the parser registry. Returns array
// of astNodes. Caller passes a registry.
type registryRef = {
  registry: V2ParserRegistry.t,
}

let registryHolder: ref<option<registryRef>> = ref(None)

let setRegistry = (r: V2ParserRegistry.t): unit => {
  registryHolder := Some({registry: r})
}

let getRegistry = (): option<V2ParserRegistry.t> =>
  switch registryHolder.contents {
  | Some(rr) => Some(rr.registry)
  | None => None
  }

let parseInnerContent = (
  ctx: ParseContext.t,
  ~inner: string,
  ~lc: int,
  ~rc: int,
  ~topRow: int,
  ~bottomRow: int,
): array<V2Types.astNode> => {
  switch getRegistry() {
  | None => []
  | Some(reg) => {
      // Tokenize inner source. Honor the outer parse's tabSize so tabs
      // inside containers expand the same way as at the top level.
      let tokens = Lexer.tokenize(~tabSize=ctx.tabSize, inner)
      // Adjust positions to be in the outer coordinate space.
      // Wrap positions: row += topRow+1, col += lc+1
      // Also recompute the absolute byte offset in ctx.source so consumers
      // (diagnostics, editor highlights) get the right slice. Inner-relative
      // offsets would otherwise point at a tiny prefix of the original file.
      let outerLines = splitLines(ctx.source)
      // Use ORIGINAL-source-aware row offsets — they account for CRLF
      // (2-byte separator) versus LF/CR (1 byte) so children's
      // `location.offset` stays accurate under any line-ending convention.
      let offsetTable = rowStartOffsets(ctx.source)
      let rowStartOffset = (outerRow: int): int =>
        offsetTable->Array.get(outerRow)->Option.getOr(String.length(ctx.source))
      // Convert a visual column on a given outer row to the byte/UTF-16
      // index inside that row's source line. Required because lc/rc and
      // adjusted col values are visual columns, but `ctx.source` is indexed
      // by code-unit position. Without this, tabs and wide characters in
      // ancestor whitespace push children's offsets past their real position.
      let byteIndexInRow = (outerRow: int, targetCol: int): int => {
        let line = outerLines->Array.get(outerRow)->Option.getOr("")
        let n = String.length(line)
        let i = ref(0)
        let col = ref(0)
        let keep = ref(true)
        while keep.contents && i.contents < n && col.contents < targetCol {
          let cp = String.codePointAt(line, i.contents)->Option.getOr(0x20)
          let cuLen = if cp > 0xFFFF { 2 } else { 1 }
          if cp == 0x09 {
            col := (col.contents / ctx.tabSize + 1) * ctx.tabSize
          } else if UnicodeUtils.isCombining(cp) {
            ()
          } else if UnicodeUtils.isWide(cp) {
            col := col.contents + 2
          } else {
            col := col.contents + 1
          }
          i := i.contents + cuLen
          if col.contents >= targetCol {
            keep := false
          }
        }
        i.contents
      }
      let adjusted = Array.map(tokens, (tok: Token.t) => {
        let outerRowS = tok.position.row + topRow + 1
        let outerRowE = tok.endPosition.row + topRow + 1
        let outerColS = tok.position.col + lc + 1
        let outerColE = tok.endPosition.col + lc + 1
        let pos: V2Types.position = {
          row: outerRowS,
          col: outerColS,
          offset: rowStartOffset(outerRowS) + byteIndexInRow(outerRowS, outerColS),
        }
        let endPos: V2Types.position = {
          row: outerRowE,
          col: outerColE,
          offset: rowStartOffset(outerRowE) + byteIndexInRow(outerRowE, outerColE),
        }
        {...tok, position: pos, endPosition: endPos}
      })
      let innerGrid = GridIndex.make(adjusted)
      // Keep source = outer source (NOT the inner slice). Token positions are
      // already in the outer coordinate space, so a nested ContainerParser
      // that calls extractInnerSource will index ctx.source by outer row
      // numbers and find the right lines. Replacing source with the inner
      // slice here caused nested containers to silently lose all their
      // contents (out-of-range row indices → empty inner source).
      // Use FRESH error/warning arrays for the inner context. Shallow-
      // copying ctx via `{...ctx}` shares the underlying mutable arrays,
      // so an inner emit lands in ctx directly AND then the explicit
      // post-loop merge below pushes the same entry a second time —
      // resulting in duplicate diagnostics for every container-local issue.
      let innerCtx: ParseContext.t = {
        ...ctx,
        tokens: adjusted,
        gridIndex: innerGrid,
        errors: [],
        warnings: [],
      }
      let stream = TokenStream.make(adjusted)
      let result: array<V2Types.astNode> = []
      let keep = ref(true)
      // Detect `@scene:` / `@component:` headers inside container content
      // and report NestedBlockDeclaration. Scene/Component cannot be nested
      // in v2.3 (REQ-18.6).
      let isNestedBlockHeader = () => {
        let a = TokenStream.peek(stream)
        let b = TokenStream.peekAt(stream, 1)
        let c = TokenStream.peekAt(stream, 2)
        switch (a.kind, b.kind, c.kind) {
        | (At, Identifier, Colon) when b.text == "scene" || b.text == "component" => true
        | _ => false
        }
      }
      while keep.contents && !TokenStream.isAtEnd(stream) {
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Newline => let _ = TokenStream.next(stream)
        | Whitespace(_) => let _ = TokenStream.next(stream)
        | EOF => keep := false
        | At when isNestedBlockHeader() => {
            ParseContext.addError(
              innerCtx,
              V2Errors.makeError(
                ~code=NestedBlockDeclaration,
                ~location={start: tok.position, end_: tok.endPosition},
                ~recoverable=true,
                (),
              ),
            )
            // REQ-18.6: start a NEW top-level block at the nested header.
            // Record both the OUTER row of the header AND the outer
            // container's bottom-border row (exclusive upper bound) so
            // V2Parser can: (a) rewind to the nested header and (b) cap
            // the recovered block so it doesn't consume the outer's
            // closing border as inner-block content.
            switch ctx.pendingNestedBlockRow {
            | Some(_) => ()
            | None => {
                ctx.pendingNestedBlockRow = Some(tok.position.row)
                ctx.pendingNestedBlockBoundRow = Some(bottomRow)
                ctx.pendingNestedBlockWallCols = Some((lc, rc))
              }
            }
            keep := false
          }
        | _ =>
          switch V2ParserRegistry.tryParse(reg, innerCtx, stream) {
          | Some(node) => result->Array.push(node)
          | None => {
              // Skip this token to avoid infinite loops.
              let _ = TokenStream.next(stream)
            }
          }
        }
      }
      // Merge inner ctx's errors back into outer ctx.
      Array.forEach(innerCtx.errors, e => ParseContext.addError(ctx, e))
      Array.forEach(innerCtx.warnings, w => ParseContext.addWarning(ctx, w))
      result
    }
  }
}

// Extract Format 2 ID candidates from children: rows whose entire content is `#id`.
// Lines that START with `#id` but contain additional content (e.g. `#foo bar`)
// are NOT IDs — they are invalid and emit InvalidIdFormat per REQ-3.3.
let extractFormat2 = (
  ctx: ParseContext.t,
  children: array<V2Types.astNode>,
): array<(string, V2Types.sourceLocation)> => {
  let out: array<(string, V2Types.sourceLocation)> = []
  Array.forEach(children, (node: V2Types.astNode) => {
    switch node {
    | TextNode(t) => {
        let c = String.trim(t.content)
        if String.length(c) > 1 && String.charAt(c, 0) == "#" {
          let rest = String.slice(c, ~start=1, ~end=String.length(c))
          // Reject any whitespace (space, tab, CR — newline already stripped
          // by String.trim). Tab-separated content `#foo\tbar` must be
          // treated as invalid, not folded into the id.
          let hasWhitespace = ref(false)
          let i = ref(0)
          let restLen = String.length(rest)
          while i.contents < restLen && !hasWhitespace.contents {
            let ch = String.charAt(rest, i.contents)
            if ch == " " || ch == "\t" || ch == "\r" {
              hasWhitespace := true
            }
            i := i.contents + 1
          }
          if !hasWhitespace.contents {
            out->Array.push((rest, t.location))
          } else {
            // Starts with `#` but has trailing content → invalid ID line.
            ParseContext.addError(
              ctx,
              V2Errors.makeError(
                ~code=InvalidIdFormat,
                ~location=t.location,
                (),
              ),
            )
          }
        }
      }
    | _ => ()
    }
  })
  out
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  switch detectTopBorder(stream) {
  | None => None
  | Some((lc, rc, name, format1Id, _topEndPos)) => {
      let topTok = TokenStream.peek(stream)
      let topRow = topTok.position.row
      let (bottomRow, bottomTolerated, wallTolerated, widthMismatch) = findBottomRow(ctx, topRow, ~lc, ~rc)
      if bottomRow < 0 {
        // Unclosed container — emit error AND emit an ErrorNode so the
        // malformed boundary is preserved in the AST (consumers can
        // distinguish recovered text from real Text).
        // Recovery per Heuristics.containerSync: consume the top row AND
        // every following row until we hit a sync point (blank row, next
        // `+`-leading row, next `@scene/@component`, or EOF). Bundle all
        // skipped rows into the ErrorNode's recoveredContent so consumers
        // can still surface the malformed input. Without this the body
        // rows leak out as normal AST children.
        let startPos = topTok.position
        let lines = splitLines(ctx.source)
        let endRowRef = ref(topRow)
        consumeRow(stream)
        let isSyncRow = (line: string): bool => {
          let trimmed = String.trim(line)
          if trimmed == "" {
            true
          } else if String.startsWith(trimmed, "+") {
            true
          } else if String.startsWith(trimmed, "@scene:") || String.startsWith(trimmed, "@component:") {
            true
          } else {
            false
          }
        }
        let keepRec = ref(true)
        while keepRec.contents {
          let nextRow = endRowRef.contents + 1
          let line = lines->Array.get(nextRow)->Option.getOr("")
          if nextRow >= Array.length(lines) {
            keepRec := false
          } else if isSyncRow(line) {
            keepRec := false
          } else {
            consumeRow(stream)
            endRowRef := nextRow
          }
        }
        let endRowPos = TokenStream.position(stream)
        let loc: V2Types.sourceLocation = {start: startPos, end_: endRowPos}
        ParseContext.addError(
          ctx,
          V2Errors.makeError(~code=UnclosedContainer, ~location=loc, ()),
        )
        let recoveredRows = []
        let i = ref(topRow)
        while i.contents <= endRowRef.contents {
          recoveredRows->Array.push(lines->Array.get(i.contents)->Option.getOr(""))
          i := i.contents + 1
        }
        let errNode: V2Types.errorNode = {
          location: loc,
          message: V2Errors.getErrorMessage(UnclosedContainer),
          recoveredContent: Some(recoveredRows->Array.join("\n")),
        }
        Some(V2Types.ErrorNode(errNode))
      } else {
        // Consume rows topRow..bottomRow (both inclusive) from the outer stream.
        let endLineCount = bottomRow - topRow + 1
        let i = ref(0)
        while i.contents < endLineCount {
          consumeRow(stream)
          i := i.contents + 1
        }
        let bounds: V2Types.bounds = {
          x: lc,
          y: topRow,
          width: rc - lc + 1,
          height: bottomRow - topRow + 1,
        }
        if bottomTolerated {
          // Bottom corners drifted within the tolerance heuristic — accept
          // but flag so the user can clean up the source.
          ParseContext.addWarning(
            ctx,
            V2Errors.makeWarning(
              ~code=MisalignedContainerCorner,
              ~location={start: topTok.position, end_: topTok.endPosition},
              ~ruleId=Heuristics.Rule.containerCornerAlignment,
              (),
            ),
          )
        }
        if wallTolerated {
          ParseContext.addWarning(
            ctx,
            V2Errors.makeWarning(
              ~code=MisalignedContainerWall,
              ~location={start: topTok.position, end_: topTok.endPosition},
              ~ruleId=Heuristics.Rule.containerWallAlignment,
              (),
            ),
          )
        }
        if widthMismatch {
          ParseContext.addWarning(
            ctx,
            V2Errors.makeWarning(
              ~code=InconsistentContainerWidth,
              ~location={start: topTok.position, end_: topTok.endPosition},
              ~ruleId=Heuristics.Rule.containerWidthConsistency,
              (),
            ),
          )
        }
        let canDescend = ParseContext.enterContainer(ctx, bounds)
        let children = if !canDescend {
          ParseContext.addError(
            ctx,
            V2Errors.makeError(
              ~code=MaxDepthExceeded,
              ~location={start: topTok.position, end_: topTok.position},
              ~recoverable=true,
              (),
            ),
          )
          []
        } else {
          let inner = extractInnerSource(ctx, ~topRow, ~bottomRow, ~lc, ~rc)
          let ch = parseInnerContent(ctx, ~inner, ~lc, ~rc, ~topRow, ~bottomRow)
          ParseContext.exitContainer(ctx)
          ch
        }
        // Resolve container id per Algorithm 2.
        // `recoveredFromIds` tracks ID-resolution recoveries (MultipleIdDeclarations
        // or InvalidIdFormat surfaced by extractFormat2) so the container's
        // `containsErrorRecovery` flag reflects them, not just maxDepth.
        let errorsBefore = Array.length(ctx.errors)
        let format2 = extractFormat2(ctx, children)
        let recoveredFromIds = ref(Array.length(ctx.errors) > errorsBefore)
        let (finalId, finalChildren) = switch (format1Id, format2->Array.length) {
        | (Some(id1), 0) => (Some(id1), children)
        | (Some(id1), _) => (Some(id1), children) // Format 1 wins; format 2 left as text
        | (None, 0) => (None, children)
        | (None, 1) => {
            let (id2, _loc) = format2->Array.getUnsafe(0)
            let filtered = children->Array.filter(n =>
              switch n {
              | TextNode(t) => {
                  let c = String.trim(t.content)
                  c != `#${id2}`
                }
              | _ => true
              }
            )
            (Some(id2), filtered)
          }
        | (None, _) => {
            let (id2, _) = format2->Array.getUnsafe(0)
            ParseContext.addError(
              ctx,
              V2Errors.makeError(
                ~code=MultipleIdDeclarations,
                ~location={start: topTok.position, end_: topTok.position},
                (),
              ),
            )
            recoveredFromIds := true
            (Some(id2), children)
          }
        }
        // Layout inference will be wired by LayoutInferrer in Phase 5.
        let layout = LayoutInferrer.inferLayout(~children=finalChildren, ~containerBounds=Some(bounds), ())
        // Compute the byte offset of (bottomRow, rc + 1) so diagnostics and
        // editor highlights point at the real end of the container, not
        // back at the start.
        let endOffset = {
          let lines = splitLines(ctx.source)
          let offsetTable = rowStartOffsets(ctx.source)
          let off = offsetTable->Array.get(bottomRow)->Option.getOr(String.length(ctx.source))
          // Convert (bottomRow, rc + 1) visual col → byte index for the row.
          let bottomLine = lines->Array.get(bottomRow)->Option.getOr("")
          let n = String.length(bottomLine)
          let bi = ref(0)
          let col = ref(0)
          let target = rc + 1
          let keep = ref(true)
          while keep.contents && bi.contents < n && col.contents < target {
            let cp = String.codePointAt(bottomLine, bi.contents)->Option.getOr(0x20)
            let cuLen = if cp > 0xFFFF { 2 } else { 1 }
            if cp == 0x09 {
              col := (col.contents / ctx.tabSize + 1) * ctx.tabSize
            } else if UnicodeUtils.isCombining(cp) {
              ()
            } else if UnicodeUtils.isWide(cp) {
              col := col.contents + 2
            } else {
              col := col.contents + 1
            }
            bi := bi.contents + cuLen
            if col.contents >= target {
              keep := false
            }
          }
          off + bi.contents
        }
        let node: V2Types.containerNode = {
          location: {
            start: topTok.position,
            end_: {row: bottomRow, col: rc + 1, offset: endOffset},
          },
          id: finalId,
          name,
          children: finalChildren,
          layout,
          bounds,
          containsErrorRecovery: !canDescend || recoveredFromIds.contents,
        }
        Some(V2Types.ContainerNode(node))
      }
    }
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(~elementType=V2Types.Container, ~priority, ~canParse, ~parse)
