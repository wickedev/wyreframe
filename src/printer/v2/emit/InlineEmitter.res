// InlineEmitter.res
// Produces the inline-text form (single visual chunk on one row) of an AST node.
// Used to emit children inside a container row.

let escapeStringContent = (s: string): string => {
  let buf = ref("")
  let n = String.length(s)
  let i = ref(0)
  while i.contents < n {
    let ch = String.charAt(s, i.contents)
    if ch == "\"" {
      buf := buf.contents ++ "\\\""
    } else if ch == "\\" {
      buf := buf.contents ++ "\\\\"
    } else {
      buf := buf.contents ++ ch
    }
    i := i.contents + 1
  }
  buf.contents
}

// Emit a non-container AST node as inline text.
// Containers must be emitted as multi-line and are NOT supported here.
let emitInline = (node: V2Types.astNode): string =>
  switch node {
  | TextNode(t) => t.content
  | ButtonNode(b) => "[ " ++ b.text ++ " ]"
  | LinkNode(l) => "< " ++ l.text ++ " >"
  | InputNode(i) =>
    // Empty placeholder uses extra underscores; otherwise use the placeholder
    // text surrounded by `__`.
    if i.placeholder == "" {
      "[__________]"
    } else {
      "[__" ++ i.placeholder ++ "__]"
    }
  | SelectNode(s) => "[v: " ++ s.placeholder ++ "]"
  | CheckboxNode(c) =>
    let mark = c.checked ? "x" : " "
    let label = c.label == "" ? "" : " " ++ c.label
    "[" ++ mark ++ "]" ++ label
  | RadioNode(r) =>
    let mark = r.selected ? "*" : " "
    let label = r.label == "" ? "" : " " ++ r.label
    "(" ++ mark ++ ")" ++ label
  | DividerNode(d) =>
    let ch = switch d.style {
    | Bold => "="
    | Normal => "-"
    }
    let run3 = ch ++ ch ++ ch
    switch (d.label, d.id) {
    | (Some(lbl), _) => run3 ++ " " ++ lbl ++ " " ++ run3
    | (None, Some(id)) => run3 ++ "#" ++ id ++ run3
    | (None, None) => run3
    }
  | StringNode(s) =>
    // Use the raw content; we currently re-emit interpolations as already
    // appearing in the literal content (parser preserves `${name}` literally
    // in content when not in component, and as ${...} markers when in
    // component too).
    "\"" ++ escapeStringContent(s.content) ++ "\""
  | EmojiNode(e) => ":" ++ e.shortcode ++ ":"
  | PropPlaceholderNode(p) =>
    let body = switch (p.required, p.defaultValue) {
    | (_, Some(d)) => p.name ++ ":" ++ d
    | (false, None) => p.name ++ "?"
    | (true, None) => p.name
    }
    "${" ++ body ++ "}"
  | ErrorNode(e) =>
    switch e.recoveredContent {
    | Some(c) => c
    | None => "[ERR:" ++ e.message ++ "]"
    }
  | ContainerNode(_) | SceneNode(_) | ComponentNode(_) =>
    // These require multi-line emission; should not be called inline.
    ""
  }

