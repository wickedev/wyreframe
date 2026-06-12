// ElementRenderer.res
// Dispatcher + per-node implementation. All variants are mutually
// recursive (containers recurse into arbitrary children) so the
// implementations live together rather than in 15 separate files.
//
// Public façade: `render(ctx, node)` returns an Ir.outputNode.
//
// For the design.md §1 module layout, each per-node implementation is
// kept as a small named function below so it can be referenced by its
// design.md identifier (SceneRenderer, ButtonRenderer, ...).

exception ErrorNodeException(string, V2Types.sourceLocation)

let kebabify = (s: string): string => String.toLowerCase(s)

let deviceClass = (d: V2Types.deviceType): string =>
  switch d {
  | Mobile => "wf-device-mobile"
  | Tablet => "wf-device-tablet"
  | Desktop => "wf-device-desktop"
  }

let deviceName = (d: V2Types.deviceType): string =>
  switch d {
  | Mobile => "mobile"
  | Tablet => "tablet"
  | Desktop => "desktop"
  }

let alignmentName = (a: V2Types.alignment): string =>
  switch a {
  | Left => "left"
  | Center => "center"
  | Right => "right"
  }

let resolveEmoji = (
  ctx: RenderContext.t,
  shortcode: string,
  fallback: string,
): (string, bool) => {
  // (glyph, knownFlag)
  // Try user resolver first, then default table.
  let userResolved = switch ctx.options.emojiResolver {
  | Some(fn) => fn(shortcode)
  | None => None
  }
  switch userResolved {
  | Some(g) => (g, true)
  | None =>
    switch DefaultEmojiTable.lookup(shortcode) {
    | Some(g) => (g, true)
    | None =>
      // Parser may have stuffed an actual glyph into the emoji field; if
      // it's non-empty, use it (still considered "known" so we don't warn).
      if String.length(fallback) > 0 && fallback != shortcode {
        (fallback, true)
      } else {
        (":" ++ shortcode ++ ":", false)
      }
    }
  }
}

// Synthetic ID derived from (salt, row, col). design.md §9.
let syntheticId = (ctx: RenderContext.t, prefix: string, loc: V2Types.sourceLocation): string =>
  ctx.options.idPrefix ++
  prefix ++
  "-" ++
  ctx.options.syntheticIdSalt ++
  "-" ++
  Int.toString(loc.start.row) ++
  "-" ++
  Int.toString(loc.start.col)

// ---------------------------------------------------------------------------
// Dispatcher
// ---------------------------------------------------------------------------

let rec render = (ctx: RenderContext.t, node: V2Types.astNode): Ir.outputNode =>
  switch node {
  | SceneNode(n) => renderScene(ctx, n)
  | ComponentNode(n) => renderComponent(ctx, n)
  | ContainerNode(n) => renderContainer(ctx, n)
  | TextNode(n) => renderText(ctx, n)
  | ButtonNode(n) => renderButton(ctx, n)
  | LinkNode(n) => renderLink(ctx, n)
  | InputNode(n) => renderInput(ctx, n)
  | SelectNode(n) => renderSelect(ctx, n)
  | CheckboxNode(n) => renderCheckbox(ctx, n)
  | RadioNode(n) => renderRadio(ctx, n)
  | DividerNode(n) => renderDivider(ctx, n)
  | StringNode(n) => renderString(ctx, n)
  | EmojiNode(n) => renderEmoji(ctx, n)
  | PropPlaceholderNode(n) => renderPropPlaceholder(ctx, n)
  | ErrorNode(n) => renderError(ctx, n)
  }

and renderChildren = (
  ctx: RenderContext.t,
  children: array<V2Types.astNode>,
): array<Ir.child> => {
  let out: array<Ir.child> = []
  Array.forEach(children, child => {
    let ir = render(ctx, child)
    if Ir.isEmpty(ir) && Array.length(ir.children) == 0 {
      // Skip mode produces an empty IR with no children; drop it.
      ()
    } else if ir.tag == "" {
      // Transparent wrapper: inline its children.
      Array.forEach(ir.children, c => Array.push(out, c))
    } else {
      Array.push(out, Ir.Element(ir))
    }
  })
  out
}

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

and renderScene = (ctx: RenderContext.t, n: V2Types.sceneNode): Ir.outputNode => {
  let classes = ["wf-scene"]
  let dataAttrs: array<(string, string)> = [("data-wf-slug", n.slug)]
  switch n.title {
  | Some(t) => Array.push(dataAttrs, ("data-wf-title", t))
  | None => ()
  }
  switch n.device {
  | Some(d) => {
      Array.push(classes, deviceClass(d))
      Array.push(dataAttrs, ("data-wf-device", deviceName(d)))
    }
  | None => ()
  }
  switch n.transition {
  | Some(t) => Array.push(dataAttrs, ("data-wf-transition", t))
  | None => ()
  }
  let attrs: array<(string, string)> = []
  switch n.title {
  | Some(t) => Array.push(attrs, ("aria-label", t))
  | None => ()
  }
  let locAttrs = AttrHelpers.locationAttrs(ctx, n.location)
  let dataAttrs = AttrHelpers.mergeAttrs(dataAttrs, locAttrs)

  let childCtx = RenderContext.pushDirection(ctx, n.layout.direction)
  let children = renderChildren(childCtx, n.children)

  Ir.make(
    ~tag="section",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs,
    ~dataAttrs,
    ~children,
    (),
  )
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

and renderComponent = (ctx: RenderContext.t, n: V2Types.componentNode): Ir.outputNode => {
  let classes = ["wf-component"]
  let dataAttrs: array<(string, string)> = [("data-wf-slug", n.slug)]
  Array.forEach(n.props, prop => {
    let value = switch prop {
    | {defaultValue: Some(v)} => v
    | {optional: true} => "optional"
    | _ => "required"
    }
    Array.push(dataAttrs, ("data-wf-prop-" ++ prop.name, value))
  })
  let locAttrs = AttrHelpers.locationAttrs(ctx, n.location)
  let dataAttrs = AttrHelpers.mergeAttrs(dataAttrs, locAttrs)

  let childCtx = RenderContext.pushDirection(ctx, n.layout.direction)
  let children = renderChildren(childCtx, n.children)

  Ir.make(
    ~tag="section",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~dataAttrs,
    ~children,
    (),
  )
}

// ---------------------------------------------------------------------------
// Container
// ---------------------------------------------------------------------------

and renderContainer = (ctx: RenderContext.t, n: V2Types.containerNode): Ir.outputNode => {
  let classes = ["wf-container", LayoutClasses.directionClass(n.layout.direction)]
  switch n.layout.distribution {
  | Some(d) => Array.push(classes, LayoutClasses.distributionClass(d))
  | None => ()
  }

  let (idAttrs, idData) = AttrHelpers.identityAttrs(ctx, n.id, n.location)
  let attrs = idAttrs
  let dataAttrs = AttrHelpers.mergeAttrs(idData, AttrHelpers.locationAttrs(ctx, n.location))
  switch n.name {
  | Some(name) => Array.push(dataAttrs, ("data-wf-name", name))
  | None => ()
  }

  let childCtx = RenderContext.pushDirection(ctx, n.layout.direction)
  let children = renderChildren(childCtx, n.children)

  Ir.make(
    ~tag="div",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs,
    ~dataAttrs,
    ~children,
    (),
  )
}

// ---------------------------------------------------------------------------
// Text — block vs inline based on parent direction
// ---------------------------------------------------------------------------

and renderText = (ctx: RenderContext.t, n: V2Types.textNode): Ir.outputNode => {
  let isInline = switch RenderContext.currentDirection(ctx) {
  | Some(Row) => true
  | _ => false
  }
  let tag = if isInline {
    "span"
  } else {
    "p"
  }
  let classes = ["wf-text", AlignmentClasses.alignmentClass(n.align)]
  let dataAttrs = AttrHelpers.locationAttrs(ctx, n.location)

  Ir.make(
    ~tag,
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~dataAttrs,
    ~children=[Ir.Text(n.content)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

and renderButton = (ctx: RenderContext.t, n: V2Types.buttonNode): Ir.outputNode => {
  let classes = ["wf-button"]
  let (idAttrs, idData) = AttrHelpers.identityAttrs(ctx, Some(n.id), n.location)
  let attrs = AttrHelpers.mergeAttrs(idAttrs, [("type", "button")])
  let dataAttrs = AttrHelpers.mergeAttrs(idData, AttrHelpers.locationAttrs(ctx, n.location))
  Ir.make(
    ~tag="button",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs,
    ~dataAttrs,
    ~children=[Ir.Text(n.text)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Link
// ---------------------------------------------------------------------------

and renderLink = (ctx: RenderContext.t, n: V2Types.linkNode): Ir.outputNode => {
  let classes = ["wf-link"]
  let (idAttrs, idData) = AttrHelpers.identityAttrs(ctx, Some(n.id), n.location)
  let dataAttrs = AttrHelpers.mergeAttrs(idData, AttrHelpers.locationAttrs(ctx, n.location))
  Ir.make(
    ~tag="a",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs=idAttrs,
    ~dataAttrs,
    ~children=[Ir.Text(n.text)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------

and renderInput = (ctx: RenderContext.t, n: V2Types.inputNode): Ir.outputNode => {
  let classes = ["wf-input"]
  let attrs: array<(string, string)> = if String.length(n.placeholder) > 0 {
    [("placeholder", n.placeholder)]
  } else {
    []
  }
  let dataAttrs = AttrHelpers.locationAttrs(ctx, n.location)
  Ir.make(
    ~tag="input",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs,
    ~dataAttrs,
    ~selfClosing=true,
    (),
  )
}

// ---------------------------------------------------------------------------
// Select
// ---------------------------------------------------------------------------

and renderSelect = (ctx: RenderContext.t, n: V2Types.selectNode): Ir.outputNode => {
  let classes = ["wf-select"]
  let (idAttrs, idData) = AttrHelpers.identityAttrs(ctx, Some(n.id), n.location)
  let dataAttrs = AttrHelpers.mergeAttrs(idData, AttrHelpers.locationAttrs(ctx, n.location))
  // The V2 selectNode currently exposes a single placeholder string — no
  // option list in the AST. Render that as a single disabled-looking option
  // when present; otherwise an empty select.
  let optionChildren: array<Ir.child> = if String.length(n.placeholder) > 0 {
    [
      Ir.Element(
        Ir.make(
          ~tag="option",
          ~attrs=[("value", "")],
          ~children=[Ir.Text(n.placeholder)],
          (),
        ),
      ),
    ]
  } else {
    []
  }
  Ir.make(
    ~tag="select",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs=idAttrs,
    ~dataAttrs,
    ~children=optionChildren,
    (),
  )
}

// ---------------------------------------------------------------------------
// Checkbox
// ---------------------------------------------------------------------------

and renderCheckbox = (ctx: RenderContext.t, n: V2Types.checkboxNode): Ir.outputNode => {
  let classes = ["wf-checkbox"]
  let dataAttrs = AttrHelpers.mergeAttrs(
    [("data-wf-checked", n.checked ? "true" : "false")],
    AttrHelpers.locationAttrs(ctx, n.location),
  )
  let inputAttrs: array<(string, string)> = [("type", "checkbox")]
  if n.checked {
    Array.push(inputAttrs, ("checked", "checked"))
  }
  let inputEl = Ir.make(~tag="input", ~attrs=inputAttrs, ~selfClosing=true, ())
  let spanEl = Ir.make(~tag="span", ~children=[Ir.Text(n.label)], ())
  Ir.make(
    ~tag="label",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~dataAttrs,
    ~children=[Ir.Element(inputEl), Ir.Element(spanEl)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Radio (group name resolved via RenderContext.radioGroups)
// ---------------------------------------------------------------------------

and renderRadio = (ctx: RenderContext.t, n: V2Types.radioNode): Ir.outputNode => {
  let classes = ["wf-radio"]
  let key = RenderContext.positionKey(n.location)
  let groupName = switch Dict.get(ctx.radioGroups, key) {
  | Some(g) => g
  | None =>
    switch n.group {
    | Some(g) => g
    | None => syntheticId(ctx, "radio", n.location)
    }
  }
  let dataAttrs = AttrHelpers.mergeAttrs(
    [("data-wf-group", groupName)],
    AttrHelpers.locationAttrs(ctx, n.location),
  )
  let inputAttrs: array<(string, string)> = [("type", "radio"), ("name", groupName)]
  if n.selected {
    Array.push(inputAttrs, ("checked", "checked"))
  }
  let inputEl = Ir.make(~tag="input", ~attrs=inputAttrs, ~selfClosing=true, ())
  let spanEl = Ir.make(~tag="span", ~children=[Ir.Text(n.label)], ())
  Ir.make(
    ~tag="label",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~dataAttrs,
    ~children=[Ir.Element(inputEl), Ir.Element(spanEl)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

and renderDivider = (ctx: RenderContext.t, n: V2Types.dividerNode): Ir.outputNode => {
  let classes = ["wf-divider"]
  switch n.style {
  | Bold => Array.push(classes, "wf-divider-bold")
  | Normal => ()
  }
  let (idAttrs, idData) = AttrHelpers.identityAttrs(ctx, n.id, n.location)
  let dataAttrs = AttrHelpers.mergeAttrs(idData, AttrHelpers.locationAttrs(ctx, n.location))
  let dataAttrs = switch n.label {
  | Some(l) => AttrHelpers.mergeAttrs(dataAttrs, [("data-wf-label", l)])
  | None => dataAttrs
  }
  Ir.make(
    ~tag="hr",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs=idAttrs,
    ~dataAttrs,
    ~selfClosing=true,
    (),
  )
}

// ---------------------------------------------------------------------------
// String
// ---------------------------------------------------------------------------

and renderString = (ctx: RenderContext.t, n: V2Types.stringNode): Ir.outputNode => {
  let classes = ["wf-string"]
  let dataAttrs = AttrHelpers.locationAttrs(ctx, n.location)
  // Render content; interpolations are pre-resolved by the parser into the
  // .content string. We preserve verbatim whitespace.
  Ir.make(
    ~tag="span",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~dataAttrs,
    ~children=[Ir.Text(n.content)],
    (),
  )
}

// ---------------------------------------------------------------------------
// Emoji
// ---------------------------------------------------------------------------

and renderEmoji = (ctx: RenderContext.t, n: V2Types.emojiNode): Ir.outputNode => {
  let (glyph, known) = resolveEmoji(ctx, n.shortcode, n.emoji)
  if !known {
    Array.push(ctx.warnings, RenderWarning.UnknownEmojiShortcode(n.shortcode, n.location))
  }
  let classes = ["wf-emoji"]
  let attrs: array<(string, string)> = [("aria-label", n.shortcode)]
  let dataAttrs = AttrHelpers.mergeAttrs(
    [("data-wf-emoji-shortcode", n.shortcode)],
    AttrHelpers.locationAttrs(ctx, n.location),
  )
  Ir.make(
    ~tag="span",
    ~classes=AttrHelpers.prefixClasses(ctx, classes),
    ~attrs,
    ~dataAttrs,
    ~children=[Ir.Text(glyph)],
    (),
  )
}

// ---------------------------------------------------------------------------
// PropPlaceholder
// ---------------------------------------------------------------------------

and renderPropPlaceholder = (
  ctx: RenderContext.t,
  n: V2Types.propPlaceholderNode,
): Ir.outputNode => {
  let supplied = Dict.get(ctx.options.componentPropValues, n.name)
  let resolved = switch supplied {
  | Some(v) => Some(v)
  | None => n.defaultValue
  }
  switch resolved {
  | Some(value) => {
      let classes = ["wf-prop-resolved"]
      let dataAttrs = AttrHelpers.mergeAttrs(
        [("data-wf-prop", n.name)],
        AttrHelpers.locationAttrs(ctx, n.location),
      )
      Ir.make(
        ~tag="span",
        ~classes=AttrHelpers.prefixClasses(ctx, classes),
        ~dataAttrs,
        ~children=[Ir.Text(value)],
        (),
      )
    }
  | None => {
      Array.push(ctx.warnings, RenderWarning.UnresolvedProp(n.name, n.location))
      let classes = ["wf-prop-missing"]
      let dataAttrs = AttrHelpers.mergeAttrs(
        [("data-wf-prop", n.name)],
        AttrHelpers.locationAttrs(ctx, n.location),
      )
      Ir.make(
        ~tag="span",
        ~classes=AttrHelpers.prefixClasses(ctx, classes),
        ~dataAttrs,
        ~children=[Ir.Text("{{" ++ n.name ++ "}}")],
        (),
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Error
// ---------------------------------------------------------------------------

and renderError = (ctx: RenderContext.t, n: V2Types.errorNode): Ir.outputNode => {
  Array.push(ctx.warnings, RenderWarning.ErrorNodeRendered(n.message, n.location))
  switch ctx.options.errorHandling {
  | Skip => Ir.empty()
  | Throw => throw(ErrorNodeException(n.message, n.location))
  | RenderMarker => {
      let classes = ["wf-error"]
      let attrs: array<(string, string)> = [("role", "alert")]
      let dataAttrs = AttrHelpers.mergeAttrs(
        [
          ("data-wf-error-code", "error"),
          ("data-wf-error-msg", n.message),
        ],
        AttrHelpers.locationAttrs(ctx, n.location),
      )
      Ir.make(
        ~tag="span",
        ~classes=AttrHelpers.prefixClasses(ctx, classes),
        ~attrs,
        ~dataAttrs,
        ~children=[Ir.Text(n.message)],
        (),
      )
    }
  }
}
