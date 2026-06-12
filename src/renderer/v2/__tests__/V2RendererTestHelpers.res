// TestHelpers.res
// Shared fixture builders for V2 renderer tests.

let pos = (~row: int, ~col: int, ~offset: int=0): V2Types.position => {row, col, offset}

let loc = (
  ~startRow: int=0,
  ~startCol: int=0,
  ~endRow: int=0,
  ~endCol: int=0,
  (),
): V2Types.sourceLocation => {
  start: pos(~row=startRow, ~col=startCol),
  end_: pos(~row=endRow, ~col=endCol),
}

let emptyLayout: V2Types.layoutInfo = {direction: Column, groups: [], distribution: None}

let layout = (
  ~direction: V2Types.layoutDirection,
  ~distribution: option<V2Types.distribution>=None,
  (),
): V2Types.layoutInfo => {
  direction,
  groups: [],
  distribution,
}

let scene = (
  ~slug: string="s",
  ~title: option<string>=None,
  ~device: option<V2Types.deviceType>=None,
  ~transition: option<string>=None,
  ~children: array<V2Types.astNode>=[],
  ~layout: V2Types.layoutInfo=emptyLayout,
  (),
): V2Types.astNode =>
  SceneNode({
    location: loc(),
    slug,
    title,
    device,
    transition,
    children,
    layout,
  })

let component = (
  ~slug: string="c",
  ~props: array<V2Types.propDefinition>=[],
  ~children: array<V2Types.astNode>=[],
  ~layout: V2Types.layoutInfo=emptyLayout,
  (),
): V2Types.astNode =>
  ComponentNode({
    location: loc(),
    slug,
    props,
    children,
    layout,
  })

let bounds: V2Types.bounds = {x: 0, y: 0, width: 0, height: 0}

let container = (
  ~id: option<string>=None,
  ~name: option<string>=None,
  ~children: array<V2Types.astNode>=[],
  ~layout: V2Types.layoutInfo=emptyLayout,
  (),
): V2Types.astNode =>
  ContainerNode({
    location: loc(),
    id,
    name,
    children,
    layout,
    bounds,
    containsErrorRecovery: false,
  })

let text = (
  ~content: string="hello",
  ~align: V2Types.alignment=Left,
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => TextNode({location, content, align})

let button = (
  ~id: string="btn",
  ~text: string="Click",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => ButtonNode({location, id, text})

let link = (
  ~id: string="lnk",
  ~text: string="here",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => LinkNode({location, id, text})

let input = (
  ~placeholder: string="",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => InputNode({location, placeholder})

let select = (
  ~id: string="sel",
  ~placeholder: string="",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => SelectNode({location, id, placeholder})

let checkbox = (
  ~checked: bool=false,
  ~label: string="",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => CheckboxNode({location, checked, label})

let radio = (
  ~selected: bool=false,
  ~label: string="",
  ~group: option<string>=None,
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => RadioNode({location, selected, label, group})

let divider = (
  ~style: V2Types.dividerStyle=Normal,
  ~id: option<string>=None,
  ~label: option<string>=None,
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => DividerNode({location, style, id, label})

let string_ = (
  ~content: string="",
  ~location: V2Types.sourceLocation=loc(),
  ~multiline: bool=false,
  (),
): V2Types.astNode =>
  StringNode({
    location,
    content,
    interpolations: [],
    multiline,
  })

let emoji = (
  ~shortcode: string="smile",
  ~emoji: string="",
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => EmojiNode({location, shortcode, emoji})

let propPlaceholder = (
  ~name: string="title",
  ~required: bool=true,
  ~defaultValue: option<string>=None,
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => PropPlaceholderNode({location, name, required, defaultValue})

let errorNode = (
  ~message: string="boom",
  ~recoveredContent: option<string>=None,
  ~location: V2Types.sourceLocation=loc(),
  (),
): V2Types.astNode => ErrorNode({location, message, recoveredContent})

let render = (node: V2Types.astNode): string =>
  V2Renderer.renderToString(node, RenderOptions.defaultOptions())

let renderWithOptions = (
  node: V2Types.astNode,
  options: RenderOptions.t,
): string => V2Renderer.renderToString(node, options)

let renderWithDiag = (
  node: V2Types.astNode,
): (string, array<RenderWarning.t>) =>
  V2Renderer.renderToStringWithDiagnostics(node, RenderOptions.defaultOptions())
