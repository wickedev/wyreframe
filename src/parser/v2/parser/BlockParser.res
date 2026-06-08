// BlockParser.res
// Detect @scene: / @component: header and parse the block body.

open Token

type parseOptions = {
  strict: bool,
  tabSize: int,
  maxDepth: int,
  // Partial heuristics override; missing fields fall back to defaults.
  heuristics: Heuristics.partial,
  // Per-parse emoji shortcode overrides. Missing keys fall back to the
  // module-default registry. None = use defaults only (no mutation of the
  // global registry).
  emojiRegistry: option<Dict.t<string>>,
}

let defaultOptions: parseOptions = {
  strict: false,
  tabSize: 4,
  maxDepth: 10,
  heuristics: Heuristics.emptyPartial,
  emojiRegistry: None,
}

// Read identifier-like text up to end of row (including embedded whitespace).
// Used for `@title:` etc.
let readLineContent = (stream: TokenStream.t): string => {
  let buf = ref("")
  let keep = ref(true)
  while keep.contents {
    let tok = TokenStream.peek(stream)
    switch tok.kind {
    | Newline | EOF => keep := false
    | _ => {
        buf := buf.contents ++ tok.text
        let _ = TokenStream.next(stream)
      }
    }
  }
  String.trim(buf.contents)
}

// Parse a comma-separated @props: list per Algorithm 5.
// Returns (deduped props, duplicate names found). The caller emits
// DuplicatePropName warnings using its own position context. Last
// occurrence of a duplicate wins.
let parseProps = (raw: string): (array<V2Types.propDefinition>, array<string>) => {
  if String.trim(raw) == "" {
    ([], [])
  } else {
    let entries = String.split(raw, ",")
    let parsed: array<V2Types.propDefinition> = Array.filterMap(entries, (e: string) => {
      let entry = String.trim(e)
      if entry == "" {
        None
      } else {
        // Split on the FIRST `=` only so defaults can contain `=`
        // (e.g. URLs like `url=https://a=b`).
        let eqIdx = String.indexOf(entry, "=")
        let (lhs, defaultValue) = if eqIdx < 0 {
          (entry, None)
        } else {
          (
            String.trim(String.slice(entry, ~start=0, ~end=eqIdx)),
            Some(String.trim(String.slice(entry, ~start=eqIdx + 1, ~end=String.length(entry)))),
          )
        }
        let (name, optional) = if String.endsWith(lhs, "?") {
          (String.slice(lhs, ~start=0, ~end=String.length(lhs) - 1), true)
        } else {
          (lhs, false)
        }
        let stripQuotes = (s: string) => {
          if String.length(s) >= 2 && String.startsWith(s, "\"") && String.endsWith(s, "\"") {
            String.slice(s, ~start=1, ~end=String.length(s) - 1)
          } else {
            s
          }
        }
        let pd: V2Types.propDefinition = {
          name: stripQuotes(String.trim(name)),
          optional,
          defaultValue,
        }
        Some(pd)
      }
    })
    // Walk in order; last occurrence wins. Track which names were duplicated.
    let seenIdx: Dict.t<int> = Dict.make()
    let dups: array<string> = []
    let dedup: array<V2Types.propDefinition> = []
    Array.forEachWithIndex(parsed, (p, _) => {
      switch Dict.get(seenIdx, p.name) {
      | Some(prevIdx) => {
          dups->Array.push(p.name)
          dedup->Array.setUnsafe(prevIdx, p) // last wins
        }
      | None => {
          Dict.set(seenIdx, p.name, Array.length(dedup))
          dedup->Array.push(p)
        }
      }
    })
    (dedup, dups)
  }
}

let parseDeviceType = (s: string): option<V2Types.deviceType> =>
  switch String.toLowerCase(String.trim(s)) {
  | "mobile" => Some(V2Types.Mobile)
  | "tablet" => Some(V2Types.Tablet)
  | "desktop" => Some(V2Types.Desktop)
  | _ => None
  }

// Detect first `@scene:` / `@component:` at cursor. Returns kind + slug + skips the row.
let detectBlockHeader = (
  stream: TokenStream.t,
): option<(ParseContext.blockType, string, V2Types.position)> => {
  let snap = TokenStream.save(stream)
  let at = TokenStream.peek(stream)
  switch at.kind {
  | At => {
      let _ = TokenStream.next(stream)
      let id = TokenStream.peek(stream)
      switch id.kind {
      | Identifier when id.text == "scene" || id.text == "component" => {
          let _ = TokenStream.next(stream)
          let colon = TokenStream.peek(stream)
          switch colon.kind {
          | Colon => {
              let _ = TokenStream.next(stream)
              let _ = TokenStream.skipInlineWhitespace(stream)
              let slug = readLineContent(stream)
              // Consume Newline if present
              let nl = TokenStream.peek(stream)
              switch nl.kind {
              | Newline => let _ = TokenStream.next(stream)
              | _ => ()
              }
              let kind = if id.text == "scene" {
                ParseContext.Scene
              } else {
                ParseContext.Component
              }
              Some((kind, Slugify.slugify(slug), at.position))
            }
          | _ => {
              TokenStream.restore(stream, snap)
              None
            }
          }
        }
      | _ => {
          TokenStream.restore(stream, snap)
          None
        }
      }
    }
  | _ => {
      TokenStream.restore(stream, snap)
      None
    }
  }
}

// Parse `@title:`/`@device:`/`@transition:`/`@props:` until non-header line.
// The 5th tuple element is the list of duplicate prop names found inside
// any `@props:` line (caller emits warnings).
// `~wallCols` lets recovered nested blocks (REQ-18.6) treat their enclosing
// container's `|` walls as transparent — otherwise `| @title: Inner |`
// would be misread as body text.
let parseHeaderAttrs = (
  stream: TokenStream.t,
  ~wallCols: option<(int, int)>=None,
  (),
): (
  option<string>,
  option<V2Types.deviceType>,
  option<string>,
  array<V2Types.propDefinition>,
  array<string>,
) => {
  let title = ref(None)
  let device = ref(None)
  let transition = ref(None)
  let props = ref([])
  let propDups = ref([])
  let isWallPipe = (tok: Token.t): bool =>
    switch (tok.kind, wallCols) {
    | (Pipe, Some((lc, rc))) => tok.position.col == lc || tok.position.col == rc
    | _ => false
    }
  let keep = ref(true)
  while keep.contents {
    let snap = TokenStream.save(stream)
    let at = TokenStream.peek(stream)
    switch at.kind {
    | At => {
        let _ = TokenStream.next(stream)
        let id = TokenStream.peek(stream)
        switch id.kind {
        | Identifier when id.text == "scene" || id.text == "component" => {
            // The next block's declaration. Header-attr parsing must NOT
            // swallow it — restore and bail so the outer loop can detect
            // it as a new top-level block.
            TokenStream.restore(stream, snap)
            keep := false
          }
        | Identifier => {
            let key = id.text
            let _ = TokenStream.next(stream)
            let colon = TokenStream.peek(stream)
            switch colon.kind {
            | Colon => {
                let _ = TokenStream.next(stream)
                let _ = TokenStream.skipInlineWhitespace(stream)
                let value = readLineContent(stream)
                // For recovered nested blocks (wallCols set), the value may
                // have absorbed the trailing `|` wall — strip it.
                let value = switch wallCols {
                | Some(_) => {
                    let trimmed = String.trim(value)
                    if String.endsWith(trimmed, "|") {
                      String.trim(String.slice(trimmed, ~start=0, ~end=String.length(trimmed) - 1))
                    } else {
                      trimmed
                    }
                  }
                | None => value
                }
                let nl = TokenStream.peek(stream)
                switch nl.kind {
                | Newline => let _ = TokenStream.next(stream)
                | _ => ()
                }
                switch key {
                | "title" => title := Some(value)
                | "device" => device := parseDeviceType(value)
                | "transition" => transition := Some(value)
                | "props" => {
                    let (deduped, dups) = parseProps(value)
                    props := deduped
                    propDups := dups
                  }
                | _ => () // unknown attr — discard silently
                }
              }
            | _ => {
                TokenStream.restore(stream, snap)
                keep := false
              }
            }
          }
        | _ => {
            TokenStream.restore(stream, snap)
            keep := false
          }
        }
      }
    | Whitespace(_) | Newline => let _ = TokenStream.next(stream)
    | Pipe when isWallPipe(at) => let _ = TokenStream.next(stream)
    | _ => keep := false
    }
  }
  (title.contents, device.contents, transition.contents, props.contents, propDups.contents)
}

// Parse content until next @scene/@component or EOF.
// If ctx.parseBoundRow is Some(r), parsing stops as soon as the cursor reaches
// row >= r. Used by REQ-18.6 nested-block recovery to keep the recovered block
// from consuming an enclosing container's closing border.
let parseContent = (
  ctx: ParseContext.t,
  registry: V2ParserRegistry.t,
  stream: TokenStream.t,
): array<V2Types.astNode> => {
  let children: array<V2Types.astNode> = []
  let keep = ref(true)
  let isPastBound = (): bool =>
    switch ctx.parseBoundRow {
    | Some(b) => (TokenStream.peek(stream)).position.row >= b
    | None => false
    }
  let isWallPipe = (tok: Token.t): bool =>
    switch (tok.kind, ctx.wallCols) {
    | (Pipe, Some((lc, rc))) => {
        let tol = ctx.heuristics.containerColumnTolerance
        let c = tok.position.col
        let near = (t: int) => c >= t - tol && c <= t + tol
        near(lc) || near(rc)
      }
    | _ => false
    }
  while keep.contents && !TokenStream.isAtEnd(stream) && !isPastBound() {
    // Check for the next block header.
    let snap = TokenStream.save(stream)
    switch detectBlockHeader(stream) {
    | Some(_) => {
        TokenStream.restore(stream, snap)
        keep := false
      }
    | None => {
        TokenStream.restore(stream, snap)
        let tok = TokenStream.peek(stream)
        switch tok.kind {
        | Newline => let _ = TokenStream.next(stream)
        | Whitespace(_) => let _ = TokenStream.next(stream)
        | Pipe when isWallPipe(tok) => let _ = TokenStream.next(stream)
        | EOF => keep := false
        | _ =>
          switch V2ParserRegistry.tryParse(registry, ctx, stream) {
          | Some(node) => children->Array.push(node)
          | None => {
              // Avoid infinite loop.
              let _ = TokenStream.next(stream)
            }
          }
        }
      }
    }
  }
  children
}
