// RenderWarning.res
// Renderer-emitted diagnostics (non-fatal). Surfaced via
// renderToStringWithDiagnostics or RenderHandle.warnings.

type t =
  | DuplicateId(string, V2Types.sourceLocation)
  | UnresolvedProp(string, V2Types.sourceLocation)
  | UnknownEmojiShortcode(string, V2Types.sourceLocation)
  | ErrorNodeRendered(string, V2Types.sourceLocation)

let getMessage = (w: t): string =>
  switch w {
  | DuplicateId(id, _) => "Duplicate id: " ++ id
  | UnresolvedProp(name, _) => "Unresolved component prop: " ++ name
  | UnknownEmojiShortcode(s, _) => "Unknown emoji shortcode: " ++ s
  | ErrorNodeRendered(m, _) => "Rendered error node: " ++ m
  }

let getLocation = (w: t): V2Types.sourceLocation =>
  switch w {
  | DuplicateId(_, l) => l
  | UnresolvedProp(_, l) => l
  | UnknownEmojiShortcode(_, l) => l
  | ErrorNodeRendered(_, l) => l
  }
