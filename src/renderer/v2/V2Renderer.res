// V2Renderer.res
// Public entry point for the V2 Renderer.
//
// Spec: .claude/specs/v2-renderer/{requirements,design}.md
// Companion: src/parser/v2/V2Parser.res

// Re-export public types from sub-modules so consumers don't have to
// reach into nested modules.
type errorHandling = RenderOptions.errorHandling
type renderOptions = RenderOptions.t
type renderWarning = RenderWarning.t

let defaultOptions = RenderOptions.defaultOptions

// ---------------------------------------------------------------------------
// renderToString
// ---------------------------------------------------------------------------

let rootFromBlock = (block: V2Types.blockNode): V2Types.astNode =>
  switch block {
  | SceneBlock(s) => SceneNode(s)
  | ComponentBlock(c) => ComponentNode(c)
  }

let renderNodeToIr = (
  ctx: RenderContext.t,
  node: V2Types.astNode,
): Ir.outputNode => {
  PrePass.run(ctx, node)
  ElementRenderer.render(ctx, node)
}

let renderToString = (node: V2Types.astNode, options: renderOptions): string => {
  let ctx = RenderContext.make(~options)
  let ir = renderNodeToIr(ctx, node)
  HtmlBuilder.emit(ir)
}

let renderToStringWithDiagnostics = (
  node: V2Types.astNode,
  options: renderOptions,
): (string, array<renderWarning>) => {
  let ctx = RenderContext.make(~options)
  let ir = renderNodeToIr(ctx, node)
  let html = HtmlBuilder.emit(ir)
  (html, ctx.warnings)
}

let renderBlockToString = (block: V2Types.blockNode, options: renderOptions): string =>
  renderToString(rootFromBlock(block), options)

let renderBlockToStringWithDiagnostics = (
  block: V2Types.blockNode,
  options: renderOptions,
): (string, array<renderWarning>) => renderToStringWithDiagnostics(rootFromBlock(block), options)

// ---------------------------------------------------------------------------
// renderToDOM
// ---------------------------------------------------------------------------

type renderHandle = {
  root: DomBuilder.Dom.element,
  warnings: array<renderWarning>,
  dispose: unit => unit,
  update: V2Types.astNode => unit,
}

@send external removeAllChildren: DomBuilder.Dom.element => unit = "replaceChildren"

let renderToDOM = (
  node: V2Types.astNode,
  container: DomBuilder.Dom.element,
  options: renderOptions,
): renderHandle => {
  let warnings = ref([])
  let lastRoot = ref(None)

  let renderInto = (ast: V2Types.astNode): unit => {
    // Clear container before each render.
    removeAllChildren(container)
    let ctx = RenderContext.make(~options)
    let ir = renderNodeToIr(ctx, ast)
    DomBuilder.mount(container, ir)
    warnings := ctx.warnings
    lastRoot := Some(container)
  }

  renderInto(node)

  let dispose = () => removeAllChildren(container)

  let update = (newAst: V2Types.astNode) => renderInto(newAst)

  {
    root: container,
    warnings: warnings.contents,
    dispose,
    update,
  }
}

// ---------------------------------------------------------------------------
// renderComponent — convenience wrapper that applies prop substitution
// ---------------------------------------------------------------------------

let renderComponent = (
  node: V2Types.astNode,
  ~props: Dict.t<string>,
  options: renderOptions,
): string => {
  let opts = {...options, componentPropValues: props}
  renderToString(node, opts)
}

// ---------------------------------------------------------------------------
// Version metadata
// ---------------------------------------------------------------------------

let version = "0.1.0"
let implementation = "rescript-v2-renderer"
