// DividerParser.res
// `---`, `===`, `--- text ---`, `--- #id ---`. Priorities 40/45/48/50.

open Token

// Priority is dynamic per pattern but we use a single parser entry with
// the highest possible numeric priority among divider variants (50).
let priority = Priority.dividerLabeledBold

let isLineOnly = (stream: TokenStream.t, kind: Token.tokenKind): bool => {
  // Returns true if current cursor is the only non-whitespace token in the row
  // (followed only by Newline/EOF) and matches the given run.
  let snap = TokenStream.save(stream)
  let result = ref(false)
  let tok = TokenStream.peek(stream)
  if tok.kind == kind {
    let _ = TokenStream.next(stream)
    let next = TokenStream.peek(stream)
    switch next.kind {
    | Newline | EOF => result := true
    | _ => ()
    }
  }
  TokenStream.restore(stream, snap)
  result.contents
}

// Accept any leading run of `-` or `=`; `parse` validates the full row shape
// and returns None if it's not actually a divider pattern. This admits the
// documented short forms `-#id-`, `=#id=`, `=text=` (REQ-11.5/6 and REQ-11.4).
let canParse = (stream: TokenStream.t): bool => {
  let tok = TokenStream.peek(stream)
  switch tok.kind {
  | Dashes(n) | Equals(n) when n >= 1 => true
  | _ => false
  }
}

// Helper: collect tokens up to end of row into a string + last position.
let collectRow = (stream: TokenStream.t): (string, V2Types.position) => {
  let s = ref("")
  let endPos = ref((TokenStream.peek(stream)).position)
  let keep = ref(true)
  while keep.contents {
    let tok = TokenStream.peek(stream)
    switch tok.kind {
    | Newline | EOF => keep := false
    | _ => {
        s := s.contents ++ tok.text
        endPos := tok.endPosition
        let _ = TokenStream.next(stream)
      }
    }
  }
  (s.contents, endPos.contents)
}

let parse = (
  ctx: ParseContext.t,
  stream: TokenStream.t,
): V2ElementParser.parseResult => {
  let tok = TokenStream.peek(stream)
  let bold = switch tok.kind {
  | Equals(_) => true
  | _ => false
  }
  let style: V2Types.dividerStyle = bold ? Bold : Normal
  let startPos = tok.position

  // Consume the full row to inspect for label/id.
  let (raw, endPos) = collectRow(stream)
  let trimmed = String.trim(raw)
  let location: V2Types.sourceLocation = {start: startPos, end_: endPos}

  // Strip leading/trailing dash-or-equal runs from the trimmed content
  // to inspect the middle. Pattern variants:
  //   ---     → plain
  //   --- text ---
  //   --- #id ---
  //   --- text #id ---  (mixed → warning, treat as text)
  let stripRun = (s: string, ch: string): string => {
    let n = String.length(s)
    let i = ref(0)
    while i.contents < n && String.charAt(s, i.contents) == ch {
      i := i.contents + 1
    }
    let j = ref(n)
    while j.contents > i.contents && String.charAt(s, j.contents - 1) == ch {
      j := j.contents - 1
    }
    String.slice(s, ~start=i.contents, ~end=j.contents)
  }

  let stripped = stripRun(trimmed, bold ? "=" : "-")
  let middle = String.trim(stripped)

  // If we stripped both ends, `stripped` must be strictly shorter than `trimmed`
  // on BOTH sides — meaning the row had both a leading AND a trailing run of
  // the same char. If only the leading run existed (e.g. `-text`), this is
  // not a divider; fall through to TextParser.
  let hasLeading = String.length(trimmed) > 0 && String.charAt(trimmed, 0) == (bold ? "=" : "-")
  let hasTrailing =
    String.length(trimmed) > 0 &&
    String.charAt(trimmed, String.length(trimmed) - 1) == (bold ? "=" : "-")

  if middle != "" && (!hasLeading || !hasTrailing) {
    // Looks like leading dashes followed by content with no closing dashes —
    // not a divider. Let TextParser handle it.
    None
  } else if middle == "" {
    // Plain divider — require dividerMinRun characters of `-` / `=`.
    // Short forms with content between dashes (`-#id-`, `=text=`) bypass
    // this minimum because they carry the content as disambiguation.
    if String.length(trimmed) < ctx.heuristics.dividerMinRun {
      None
    } else {
      let node: V2Types.dividerNode = {
        location,
        style,
        id: None,
        label: None,
      }
      Some(V2Types.DividerNode(node))
    }
  } else {
    // Detect `#id` only, label only, or mixed.
    let isIdOnly =
      String.length(middle) > 1 &&
      String.charAt(middle, 0) == "#" &&
      !(middle->String.includes(" "))
    let hasHashInside = String.includes(middle, "#")
    if isIdOnly {
      let id = String.slice(middle, ~start=1, ~end=String.length(middle))
      let node: V2Types.dividerNode = {
        location,
        style,
        id: Some(id),
        label: None,
      }
      Some(V2Types.DividerNode(node))
    } else if hasHashInside {
      // Mixed label + id → warning, treat as text
      ParseContext.addWarning(
        ctx,
        V2Errors.makeWarning(~code=MixedDividerLabelId, ~location, ()),
      )
      let node: V2Types.textNode = {
        location,
        content: trimmed,
        align: V2Types.Left,
      }
      Some(V2Types.TextNode(node))
    } else {
      let node: V2Types.dividerNode = {
        location,
        style,
        id: None,
        label: Some(middle),
      }
      Some(V2Types.DividerNode(node))
    }
  }
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(
    ~elementType=V2Types.Divider,
    ~priority,
    ~canParse,
    ~parse,
  )
