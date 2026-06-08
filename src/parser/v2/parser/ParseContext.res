// ParseContext.res
// Mutable parse-time context: error/warning collection, container depth,
// component prop awareness, heuristics, optional GridIndex+tokens for parsers.

type blockType =
  | Scene
  | Component

type t = {
  blockType: blockType,
  blockSlug: string,
  props: array<V2Types.propDefinition>,
  mutable containerDepth: int,
  mutable errors: array<V2Errors.parseError>,
  mutable warnings: array<V2Errors.parseWarning>,
  heuristics: Heuristics.t,
  tokens: array<Token.t>,
  gridIndex: GridIndex.t,
  source: string,
  maxDepth: int,
  tabSize: int,
  mutable containerStack: list<V2Types.bounds>,
  // When a nested `@scene:` / `@component:` header is detected inside a
  // container's body, ContainerParser stores the OUTER row of that header
  // here so the caller can rewind the outer token stream and treat the
  // nested declaration as a fresh top-level block (REQ-18.6).
  mutable pendingNestedBlockRow: option<int>,
  // Companion: the outer container's bottom-border row, used as an
  // EXCLUSIVE upper bound when parsing the recovered nested block so the
  // outer's closing `+` is not consumed as inner-block content.
  mutable pendingNestedBlockBoundRow: option<int>,
  // Outer container's wall columns (lc, rc) so the recovered nested block
  // can skip `|` Pipe tokens at those positions.
  mutable pendingNestedBlockWallCols: option<(int, int)>,
  // Per-parse emoji overrides. Looked up before the module-default
  // registry so callers can register custom shortcodes without mutating
  // global state.
  emojiRegistry: option<Dict.t<string>>,
  // For the recovered block: parseContent must NOT process tokens whose
  // row is >= this value. Empty Map means no bound.
  parseBoundRow: option<int>,
  // For the recovered block: ignore `|` Pipe tokens that sit at these
  // visual columns (the outer container's wall positions). Without this,
  // a recovered block with body rows like `| Hi |` produces spurious
  // `|` TextNodes.
  wallCols: option<(int, int)>,
}

let make = (
  ~blockType: blockType,
  ~blockSlug: string,
  ~props: array<V2Types.propDefinition>=[],
  ~heuristics: Heuristics.t,
  ~tokens: array<Token.t>,
  ~gridIndex: GridIndex.t,
  ~source: string,
  ~maxDepth: int=10,
  ~tabSize: int=4,
  ~parseBoundRow: option<int>=None,
  ~wallCols: option<(int, int)>=None,
  ~emojiRegistry: option<Dict.t<string>>=None,
  (),
): t => {
  blockType,
  blockSlug,
  props,
  containerDepth: 0,
  errors: [],
  warnings: [],
  heuristics,
  tokens,
  gridIndex,
  source,
  maxDepth,
  tabSize,
  containerStack: list{},
  pendingNestedBlockRow: None,
  pendingNestedBlockBoundRow: None,
  pendingNestedBlockWallCols: None,
  parseBoundRow,
  wallCols,
  emojiRegistry,
}

let addError = (ctx: t, err: V2Errors.parseError): unit => {
  ctx.errors->Array.push(err)
}

let addWarning = (ctx: t, w: V2Errors.parseWarning): unit => {
  ctx.warnings->Array.push(w)
}

let isInComponent = (ctx: t): bool =>
  switch ctx.blockType {
  | Component => true
  | Scene => false
  }

let enterContainer = (ctx: t, bounds: V2Types.bounds): bool => {
  if ctx.containerDepth + 1 > ctx.maxDepth {
    false
  } else {
    ctx.containerDepth = ctx.containerDepth + 1
    ctx.containerStack = list{bounds, ...ctx.containerStack}
    true
  }
}

let exitContainer = (ctx: t): unit => {
  if ctx.containerDepth > 0 {
    ctx.containerDepth = ctx.containerDepth - 1
    switch ctx.containerStack {
    | list{_, ...rest} => ctx.containerStack = rest
    | list{} => ()
    }
  }
}

let currentContainerBounds = (ctx: t): option<V2Types.bounds> =>
  switch ctx.containerStack {
  | list{b, ..._} => Some(b)
  | list{} => None
  }
