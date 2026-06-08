// V2Parser.res
// Public entry point. Tokenize source, detect block header(s), parse content
// via registry, infer scene/component-level layout, and run cross-cutting
// validation.

type parseOptions = BlockParser.parseOptions
let defaultOptions = BlockParser.defaultOptions

type parseResult = {
  // First block (legacy single-block accessor); same as blocks[0] when present.
  ast: option<V2Types.blockNode>,
  // All top-level @scene/@component blocks in declaration order.
  blocks: array<V2Types.blockNode>,
  errors: array<V2Errors.parseError>,
  warnings: array<V2Errors.parseWarning>,
  success: bool,
}

let makeRegistry = (): V2ParserRegistry.t => {
  let reg = V2ParserRegistry.make()
  V2ParserRegistry.register(reg, StringParser.make())
  V2ParserRegistry.register(reg, PropPlaceholderParser.make())
  V2ParserRegistry.register(reg, EmojiParser.make())
  V2ParserRegistry.register(reg, SelectParser.make())
  V2ParserRegistry.register(reg, V2InputParser.make())
  V2ParserRegistry.register(reg, RadioParser.make())
  V2ParserRegistry.register(reg, V2CheckboxParser.make())
  V2ParserRegistry.register(reg, V2ButtonParser.make())
  V2ParserRegistry.register(reg, V2LinkParser.make())
  V2ParserRegistry.register(reg, DividerParser.make())
  V2ParserRegistry.register(reg, ContainerParser.make())
  V2ParserRegistry.register(reg, V2TextParser.make())
  reg
}

// Advance the stream over leading whitespace/newlines/non-block lines until
// the next `@scene:` / `@component:` header. Returns Some(header) or None at EOF.
//
// `~pipeNoise` controls whether `|` is skipped as leading noise. It MUST be
// false for normal top-level discovery (otherwise a wireframe row like
// `| @component: c |` would falsely match a header). It is true only when
// V2Parser has just rewound the cursor to recover a nested-block declaration
// found inside a container body — that recovery position is known to be a
// real header behind the container's left wall.
let advanceToNextHeader = (
  stream: TokenStream.t,
  ~pipeNoise: bool=false,
  (),
): option<(ParseContext.blockType, string, V2Types.position)> => {
  let header = ref(None)
  let keep = ref(true)
  while keep.contents && !TokenStream.isAtEnd(stream) {
    let tok = TokenStream.peek(stream)
    switch tok.kind {
    | Newline | Whitespace(_) => let _ = TokenStream.next(stream)
    | Pipe when pipeNoise => let _ = TokenStream.next(stream)
    | EOF => keep := false
    | _ =>
      switch BlockParser.detectBlockHeader(stream) {
      | Some(h) => {
          header := Some(h)
          keep := false
        }
      | None => TokenStream.skipToEndOfRow(stream)
      }
    }
  }
  header.contents
}

// Parse exactly one block starting from the position just after its header
// (we consume the @scene/@component line here). Returns the block and any
// errors/warnings accumulated during parsing + validation.
let parseOneBlock = (
  ~source: string,
  ~tokens: array<Token.t>,
  ~gridIndex: GridIndex.t,
  ~stream: TokenStream.t,
  ~registry: V2ParserRegistry.t,
  ~options: parseOptions,
  ~kind: ParseContext.blockType,
  ~slug: string,
  ~startPos: V2Types.position,
  ~parseBoundRow: option<int>=None,
  ~wallCols: option<(int, int)>=None,
): (
  V2Types.blockNode,
  array<V2Errors.parseError>,
  array<V2Errors.parseWarning>,
  option<(int, option<int>, option<(int, int)>)>,
) => {
  let (title, device, transition, props, propDups) =
    BlockParser.parseHeaderAttrs(stream, ~wallCols, ())
  let blockType: ParseContext.blockType = switch kind {
  | ParseContext.Scene => ParseContext.Scene
  | ParseContext.Component => ParseContext.Component
  }
  let ctx = ParseContext.make(
    ~blockType,
    ~blockSlug=slug,
    ~props,
    ~heuristics=Heuristics.applyPartial(options.heuristics, Heuristics.default),
    ~tokens,
    ~gridIndex,
    ~source,
    ~maxDepth=options.maxDepth,
    ~tabSize=options.tabSize,
    ~parseBoundRow,
    ~wallCols,
    ~emojiRegistry=options.emojiRegistry,
    (),
  )
  Array.forEach(propDups, name =>
    ParseContext.addWarning(
      ctx,
      V2Errors.makeWarning(
        ~code=DuplicatePropName(name),
        ~location={start: startPos, end_: startPos},
        (),
      ),
    )
  )
  let rawChildren = BlockParser.parseContent(ctx, registry, stream)
  let children =
    RadioGrouper.assignGroupsRecursive(
      rawChildren,
      ~parentSlug=slug,
      ~heuristics=Heuristics.applyPartial(options.heuristics, Heuristics.default),
    )
  let layout = LayoutInferrer.inferLayout(~children, ())
  let loc: V2Types.sourceLocation = {start: startPos, end_: TokenStream.position(stream)}
  let block: V2Types.blockNode = switch blockType {
  | ParseContext.Scene =>
    V2Types.SceneBlock({
      location: loc,
      slug,
      title,
      device,
      transition,
      children,
      layout,
    })
  | ParseContext.Component =>
    V2Types.ComponentBlock({
      location: loc,
      slug,
      props,
      children,
      layout,
    })
  }
  let (vErrs, vWarns) = Validator.validate(block)
  let pending = switch ctx.pendingNestedBlockRow {
  | Some(r) => Some((r, ctx.pendingNestedBlockBoundRow, ctx.pendingNestedBlockWallCols))
  | None => None
  }
  (
    block,
    Array.concat(ctx.errors, vErrs),
    Array.concat(ctx.warnings, vWarns),
    pending,
  )
}

// JS callers may pass partial options like `{strict: true}` from JavaScript;
// missing fields then surface as `undefined` and crash when read. Defensively
// merge each field with `defaultOptions`. The %raw shim is the simplest way
// to do an undefined-aware merge from ReScript.
let normalizeOptions: (parseOptions, parseOptions) => parseOptions = %raw(`
  function(opts, dflt) {
    if (opts === undefined || opts === null) return dflt;
    return {
      strict: opts.strict !== undefined ? opts.strict : dflt.strict,
      tabSize: opts.tabSize !== undefined ? opts.tabSize : dflt.tabSize,
      maxDepth: opts.maxDepth !== undefined ? opts.maxDepth : dflt.maxDepth,
      heuristics: opts.heuristics !== undefined && opts.heuristics !== null
        ? opts.heuristics
        : dflt.heuristics,
      emojiRegistry: opts.emojiRegistry !== undefined && opts.emojiRegistry !== null
        ? opts.emojiRegistry
        : dflt.emojiRegistry,
    };
  }
`)

let parse = (source: string, ~options: parseOptions=defaultOptions, ()): parseResult => {
  let options = normalizeOptions(options, defaultOptions)
  let tokens = Lexer.tokenize(~tabSize=options.tabSize, source)
  let gridIndex = GridIndex.make(tokens)
  let stream = TokenStream.make(tokens)
  let registry = makeRegistry()
  ContainerParser.setRegistry(registry)

  let blocks: array<V2Types.blockNode> = []
  let allErrors: array<V2Errors.parseError> = []
  let allWarnings: array<V2Errors.parseWarning> = []

  // Loop: while there is another `@scene:` or `@component:` header in the
  // remaining stream, parse one block. parseContent stops at the next block
  // boundary, so the outer loop naturally picks it up here.
  // In strict mode, the first block that emits any error halts the loop and
  // every error is promoted to non-recoverable (fail-fast contract).
  let keep = ref(true)
  let nextLookupPipeNoise = ref(false)
  let nextParseBoundRow: ref<option<int>> = ref(None)
  let nextWallCols: ref<option<(int, int)>> = ref(None)
  // True when this iteration is taking over from a previous recovered block
  // that stopped at another nested header (NOT from ContainerParser's
  // first-recovery handoff — that already emits NestedBlockDeclaration).
  let nextIsPropagated = ref(false)
  while keep.contents {
    let pipeNoise = nextLookupPipeNoise.contents
    let parseBoundRow = nextParseBoundRow.contents
    let wallCols = nextWallCols.contents
    let isPropagated = nextIsPropagated.contents
    nextLookupPipeNoise := false
    nextParseBoundRow := None
    nextWallCols := None
    nextIsPropagated := false
    switch advanceToNextHeader(stream, ~pipeNoise, ()) {
    | None => keep := false
    | Some((kind, slug, startPos)) => {
        // Propagation case: the header we just found is a 2nd-or-later
        // nested declaration inside the same container body. The first
        // such header was already reported by ContainerParser; here we
        // emit NestedBlockDeclaration for the propagated one.
        if isPropagated {
          allErrors->Array.push(
            V2Errors.makeError(
              ~code=NestedBlockDeclaration,
              ~location={start: startPos, end_: startPos},
              ~recoverable=true,
              (),
            ),
          )
        }
        let (block, errs, warns, pendingRow) =
          parseOneBlock(
            ~source,
            ~tokens,
            ~gridIndex,
            ~stream,
            ~registry,
            ~options,
            ~kind,
            ~slug,
            ~startPos,
            ~parseBoundRow,
            ~wallCols,
          )
        blocks->Array.push(block)
        let strict = options.strict
        Array.forEach(errs, e => {
          let e2 = strict ? {...e, recoverable: false} : e
          allErrors->Array.push(e2)
        })
        Array.forEach(warns, w => allWarnings->Array.push(w))
        if strict && Array.length(errs) > 0 {
          keep := false
        }
        // REQ-18.6 recovery: a nested @scene/@component declaration was
        // found inside a container. The container already consumed the
        // outer stream past it, so rewind the cursor and tell the NEXT
        // header-lookup that pipes are "noise" (the nested header sits
        // behind a container wall). Pass the outer's bottom-border row
        // as a bound so the recovered block can't consume that closing
        // `+` and spuriously emit UnclosedContainer.
        switch pendingRow {
        | Some((r, boundRow, walls)) => {
            TokenStream.rewindToRow(stream, r)
            nextLookupPipeNoise := true
            nextParseBoundRow := boundRow
            nextWallCols := walls
          }
        | None =>
          // No ContainerParser-discovered nested header this round, but if
          // the block we just parsed was itself a RECOVERED nested block and
          // its parseContent stopped at ANOTHER sub-header (not at EOF),
          // the cursor is still inside the original outer container's body.
          // Propagate the parseBoundRow/wallCols/pipe-noise so the next
          // recovered sub-block stays within the outer bound (otherwise it
          // consumes the outer's closing `+` and spuriously errors).
          switch parseBoundRow {
          | Some(b) =>
            if (TokenStream.peek(stream)).position.row < b {
              nextParseBoundRow := Some(b)
              nextWallCols := wallCols
              nextLookupPipeNoise := true
              nextIsPropagated := true
            }
          | None => ()
          }
        }
      }
    }
  }

  if Array.length(blocks) == 0 {
    {
      ast: None,
      blocks: [],
      errors: [
        V2Errors.makeError(
          ~code=MissingBlockDeclaration,
          ~location=V2Types.zeroLoc,
          ~recoverable=false,
          (),
        ),
      ],
      warnings: [],
      success: false,
    }
  } else {
    let success = Array.length(allErrors) == 0
    {
      ast: blocks->Array.get(0),
      blocks,
      errors: allErrors,
      warnings: allWarnings,
      success,
    }
  }
}

let parseWireframe = (source: string): parseResult => parse(source, ())

let version: string = "2.3.0"
let implementation: string = "rescript-v2"
