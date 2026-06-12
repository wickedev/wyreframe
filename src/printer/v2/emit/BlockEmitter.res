// BlockEmitter.res
// Produces multi-line output for AST nodes (containers, scenes, components).
// Strategy: each child gets its own row by default (Column layout).
// Row groups (from layoutInfo) are placed on the same row with single-space gaps.
// The parser's LayoutInferrer will re-derive direction from row alignment.

let stringRepeat = (s: string, n: int): string => {
  let buf = ref("")
  let i = ref(0)
  while i.contents < n {
    buf := buf.contents ++ s
    i := i.contents + 1
  }
  buf.contents
}

// Compute the inline width (visual columns; assume 1 cell per char for ASCII).
let inlineWidth = (s: string): int => String.length(s)

// For an AST node, return whether it must be multi-line (i.e. a Container).
let isContainer = (node: V2Types.astNode): bool =>
  switch node {
  | ContainerNode(_) => true
  | _ => false
  }

// Map a layoutInfo.groups list onto children indices.
// Each group has (start, end_, direction); we honor it by emitting all
// children in a row group on the same line.
type childRow =
  | InlineRow(array<V2Types.astNode>) // all on one visual row
  | BlockNode(V2Types.astNode) // a container — multi-line

// Convert a node's children + layout into a sequence of rows.
// Containers always get their own row(s). Inline nodes can share a row if
// they were part of a Row group.
let groupChildrenIntoRows = (
  children: array<V2Types.astNode>,
  layout: V2Types.layoutInfo,
): array<childRow> => {
  let rows: array<childRow> = []
  let n = Array.length(children)
  if n == 0 {
    rows
  } else {
    // Determine which children are in which group. Use layout.groups if
    // present; otherwise default to one-child-per-row.
    let groups = layout.groups
    let gCount = Array.length(groups)
    if gCount == 0 {
      // Fallback: each child on its own row
      Array.forEach(children, c => rows->Array.push(BlockNode(c)))
    } else {
      Array.forEach(groups, (g: V2Types.elementGroup) => {
        let start = g.start
        let end_ = g.end_
        let groupChildren = Array.slice(children, ~start, ~end=end_)
        // Containers in a group: each container gets its own row, even if
        // the group says Row. The parser places containers at their row's
        // top border; mixing inline + container in one row isn't safely
        // round-trippable in V2 syntax.
        let hasContainer = Array.some(groupChildren, isContainer)
        if hasContainer || Array.length(groupChildren) <= 1 {
          Array.forEach(groupChildren, c => rows->Array.push(BlockNode(c)))
        } else {
          switch g.direction {
          | V2Types.Row => rows->Array.push(InlineRow(groupChildren))
          | V2Types.Column | V2Types.Mixed =>
            Array.forEach(groupChildren, c => rows->Array.push(BlockNode(c)))
          }
        }
      })
    }
    rows
  }
}

// Distribution-to-gap mapping.
// `Equal`, `SpaceAround`, `SpaceBetween`, `Center_`, `Start`, `End` all
// re-parse from inner spacing alone. For round-trip we use leftmost-first
// deterministic spacing that the parser's heuristics map back to the same
// distribution.
//
// Heuristic mapping (see LayoutInferrer):
//   leftPad <= 1 && rightPad <= 1     → SpaceBetween (or fallback)
//   leftPad ~= rightPad && lp > 1     → Center_
//   leftPad <= 1 && rightPad > 1      → Start
//   leftPad > 1 && rightPad <= 1      → End
//   else                              → Equal (default)
//
// We pad the row so the parser maps it back to the recorded distribution.
let emitInlineRowLine = (
  children: array<V2Types.astNode>,
  innerWidth: int,
  distribution: option<V2Types.distribution>,
): string => {
  let inlines = Array.map(children, c => InlineEmitter.emitInline(c))
  let texts = inlines
  let n = Array.length(texts)
  if n == 0 {
    stringRepeat(" ", innerWidth)
  } else {
    // Sum of widths
    let sumW = Array.reduce(texts, 0, (acc, t) => acc + inlineWidth(t))
    let slack = innerWidth - sumW
    let slack = slack < 0 ? 0 : slack
    let dist = switch distribution {
    | Some(d) => d
    | None => V2Types.Start
    }
    // Compute (leftPad, gaps[], rightPad) for the requested distribution.
    let (leftPad, gaps, rightPad) = if n == 1 {
      switch dist {
      | V2Types.Center_ => {
          let lp = slack / 2
          (lp, [], slack - lp)
        }
      | V2Types.End => (slack, [], 0)
      | V2Types.Start | V2Types.Equal | V2Types.SpaceAround | V2Types.SpaceBetween => (0, [], slack)
      }
    } else {
      let gapCount = n - 1
      switch dist {
      | V2Types.SpaceBetween => {
          // 0 pad on edges; distribute slack across gapCount gaps (min 1).
          let totalGap = slack
          let baseGap = if gapCount == 0 { 0 } else { totalGap / gapCount }
          let baseGap = baseGap < 1 ? 1 : baseGap
          let used = baseGap * gapCount
          let extra = totalGap - used
          let extra = extra < 0 ? 0 : extra
          let gaps = Array.make(~length=gapCount, baseGap)
          // distribute extra leftmost-first
          let i = ref(0)
          while i.contents < extra && i.contents < gapCount {
            let cur = gaps->Array.getUnsafe(i.contents)
            gaps->Array.setUnsafe(i.contents, cur + 1)
            i := i.contents + 1
          }
          (0, gaps, 0)
        }
      | V2Types.SpaceAround => {
          // Heuristic-friendly: lp > 1, rp > 1, |lp-rp| > 1.
          // Use leftPad=2, rightPad=4 if total slack >= 6, else split slack
          // asymmetrically.
          let interGap = 1
          let used = interGap * gapCount
          let remaining = slack - used
          let remaining = remaining < 0 ? 0 : remaining
          // Want lp >= 2, rp >= 2, |lp-rp| > 1
          let (lp, rp) = if remaining >= 5 {
            (2, remaining - 2)
          } else {
            // can't satisfy strict heuristic — fall back to even split
            let half = remaining / 2
            (half, remaining - half)
          }
          let gaps = Array.make(~length=gapCount, interGap)
          (lp, gaps, rp)
        }
      | V2Types.Equal => {
          // space-evenly: equal padding before/between/after.
          let slots = n + 1
          let base = slack / slots
          let base = base < 1 ? 1 : base
          let rem = slack - base * slots
          let rem = rem < 0 ? 0 : rem
          // leftmost-first: edge gets +1 first
          let leftPad = base + (rem > 0 ? 1 : 0)
          let remAfter = ref(rem > 0 ? rem - 1 : 0)
          let gaps = Array.make(~length=gapCount, base)
          let i = ref(0)
          while i.contents < gapCount && remAfter.contents > 0 {
            let cur = gaps->Array.getUnsafe(i.contents)
            gaps->Array.setUnsafe(i.contents, cur + 1)
            remAfter := remAfter.contents - 1
            i := i.contents + 1
          }
          let rightPad = base + (remAfter.contents > 0 ? 1 : 0)
          (leftPad, gaps, rightPad)
        }
      | V2Types.Start => {
          // Cluster left with 1-space inter-gap, slack at right.
          let interGap = 1
          let used = interGap * gapCount
          let rightPad = slack - used
          let rightPad = rightPad < 0 ? 0 : rightPad
          let gaps = Array.make(~length=gapCount, interGap)
          (0, gaps, rightPad)
        }
      | V2Types.End => {
          let interGap = 1
          let used = interGap * gapCount
          let leftPad = slack - used
          let leftPad = leftPad < 0 ? 0 : leftPad
          let gaps = Array.make(~length=gapCount, interGap)
          (leftPad, gaps, 0)
        }
      | V2Types.Center_ => {
          let interGap = 1
          let used = interGap * gapCount
          let remaining = slack - used
          let remaining = remaining < 0 ? 0 : remaining
          let leftPad = remaining / 2
          let rightPad = remaining - leftPad
          let gaps = Array.make(~length=gapCount, interGap)
          (leftPad, gaps, rightPad)
        }
      }
    }
    // Build the line
    let buf = ref(stringRepeat(" ", leftPad))
    let i = ref(0)
    while i.contents < n {
      buf := buf.contents ++ texts->Array.getUnsafe(i.contents)
      if i.contents < n - 1 {
        let g = gaps->Array.getUnsafe(i.contents)
        buf := buf.contents ++ stringRepeat(" ", g)
      }
      i := i.contents + 1
    }
    buf := buf.contents ++ stringRepeat(" ", rightPad)
    let s = buf.contents
    // Pad/truncate to innerWidth exactly
    let cur = inlineWidth(s)
    if cur < innerWidth {
      s ++ stringRepeat(" ", innerWidth - cur)
    } else {
      s
    }
  }
}

// Compute the rendered width of a single inline element string.
let inlineNodeWidth = (node: V2Types.astNode): int =>
  switch node {
  | ContainerNode(_) | SceneNode(_) | ComponentNode(_) => 0
  | _ => inlineWidth(InlineEmitter.emitInline(node))
  }

// Recursively compute the natural (preferred) inner width of a node.
// Containers add 2 for borders. TextNodes add slack for non-default alignment.
let rec naturalWidth = (node: V2Types.astNode): int =>
  switch node {
  | ContainerNode(c) => containerNaturalWidth(c)
  | SceneNode(_) | ComponentNode(_) => 0
  | TextNode(t) => {
      let base = String.length(t.content)
      // Center: need lp ≈ rp ≥ 2 → +4
      // Right: need lp > 2*rp, rp/w <= 0.10 → +6 (rp=0, lp=6)
      let extra = switch t.align {
      | V2Types.Left => 0
      | V2Types.Center => 4
      | V2Types.Right => 6
      }
      base + extra
    }
  | _ => inlineNodeWidth(node)
  }

and containerNaturalWidth = (c: V2Types.containerNode): int => {
  let children = c.children
  let layout = c.layout
  let rows = groupChildrenIntoRows(children, layout)
  // Seed max_inner from name/id needs in top border.
  let nameLen = switch c.name {
  | Some(n) => String.length(n)
  | None => 0
  }
  let idLen = switch c.id {
  | Some(i) => String.length(i) + 1
  | None => 0
  }
  let topBorderNeed = nameLen > 0 ? nameLen + 2 : idLen > 0 ? idLen + 2 : 0
  let maxInner = ref(topBorderNeed)
  Array.forEach(rows, row =>
    switch row {
    | BlockNode(n) => {
        let w = naturalWidth(n)
        if w > maxInner.contents {
          maxInner := w
        }
      }
    | InlineRow(arr) => {
        let sum = Array.reduce(arr, 0, (acc, c) => acc + inlineNodeWidth(c))
        // 1-space gaps between items
        let withGaps = sum + (Array.length(arr) > 0 ? Array.length(arr) - 1 : 0)
        // Distribution requires extra slack to round-trip the inferred distribution:
        //   Start: rightPad ≥ 2  → +2
        //   End: leftPad ≥ 2     → +2
        //   Center_: both pads ≥ 2 → +4
        //   Equal: edge + internal both > 1 → +4 (rough)
        //   SpaceAround: edges have half-gap of internal → at least +4
        //   SpaceBetween: 0 edge pad → +0
        //   None: +0 (column inferred)
        // Note: SpaceAround needs lp>1,rp>1,|lp-rp|>1 → smallest is lp=2,rp=4.
        // Plus gaps for n-1 interior. Natural already includes 1-space gaps,
        // so we just need extra slack room for edges to be asymmetric.
        let extra = switch layout.distribution {
        | Some(V2Types.Start) | Some(V2Types.End) => 2
        | Some(V2Types.Center_) => 4
        | Some(V2Types.Equal) => 4
        | Some(V2Types.SpaceAround) => 6
        | Some(V2Types.SpaceBetween) => 0
        | None => 0
        }
        let total = withGaps + extra
        if total > maxInner.contents {
          maxInner := total
        }
      }
    }
  )
  // Need at least 2 for `+ +` minimum
  let interior = maxInner.contents < 2 ? 2 : maxInner.contents
  // Add 2 for borders + 0 padding (containerPadding is 0 by default for spec)
  interior + 2
}

// Compute the rendered inner-width of a container including the name in the
// top border. The name is embedded in the dash run so it doesn't affect width
// unless name is wider than the existing dashes.
let topBorderInteriorMin = (c: V2Types.containerNode): int => {
  let nameLen = switch c.name {
  | Some(n) => String.length(n)
  | None => 0
  }
  let idLen = switch c.id {
  | Some(i) => String.length(i) + 1 // `#id`
  | None => 0
  }
  // For Format-1 ID (`+--#id--+`), id sits inside; ensure interior accommodates it.
  // For name (`+--Name--+`), name sits inside.
  // Combined: we'll emit name OR id (not both since parser already handles
  // either format). Prefer name if both exist (V1 reading).
  let need = if nameLen > 0 {
    nameLen + 2 // " name " - actually no, parser just trims whitespace
  } else if idLen > 0 {
    idLen + 2
  } else {
    0
  }
  need
}

// Emit a container's lines. Returns array<string>.
let rec emitContainer = (
  c: V2Types.containerNode,
  ~chars: BorderChars.set,
): array<string> => {
  // Decide interior width.
  let kidNeed = containerNaturalWidth(c) - 2 // strip our own borders
  let nameNeed = topBorderInteriorMin(c)
  let interior = kidNeed > nameNeed ? kidNeed : nameNeed
  // Minimum 2 (so `+--+` is the smallest)
  let interior = interior < 2 ? 2 : interior
  let totalWidth = interior + 2
  // Top border
  let topLine = buildTopBorder(c, ~interior, ~chars)
  // Body lines
  let bodyLines = buildBody(c, ~interior, ~chars)
  // Bottom border
  let bottomLine = chars.bottomLeft ++ stringRepeat(chars.horizontal, interior) ++ chars.bottomRight
  let _ = totalWidth
  let out: array<string> = []
  out->Array.push(topLine)
  Array.forEach(bodyLines, l => out->Array.push(l))
  out->Array.push(bottomLine)
  out
}

and buildTopBorder = (
  c: V2Types.containerNode,
  ~interior: int,
  ~chars: BorderChars.set,
): string => {
  // Format 1 ID: `+--#id--+`, taking precedence over name when both exist.
  // V2 parser allows name OR id-via-format-1. If we have id, embed it
  // (works for ASCII charset only — Unicode chars in `-` runs would still
  // parse since the dash-run is `-` literal).
  // For Unicode charset, the parser doesn't recognize `┌`/`─` as a container
  // top border; so round-trip Unicode is not parseable. We document this
  // limitation: round-trip only works with ASCII charset.
  let dashes = stringRepeat(chars.horizontal, interior)
  switch (c.id, c.name) {
  | (Some(id), _) => {
      // Embed `#id` in the middle of the dashes.
      let token = "#" ++ id
      // Padding: at least 1 dash on each side. Distribute extra leftmost-first.
      let extra = interior - String.length(token)
      if extra >= 2 {
        let leftDash = extra / 2
        let rightDash = extra - leftDash
        chars.topLeft ++
        stringRepeat(chars.horizontal, leftDash) ++
        token ++
        stringRepeat(chars.horizontal, rightDash) ++
        chars.topRight
      } else {
        // Force interior to fit
        chars.topLeft ++ chars.horizontal ++ token ++ chars.horizontal ++ chars.topRight
      }
    }
  | (None, Some(name)) => {
      let extra = interior - String.length(name)
      if extra >= 2 {
        let leftDash = extra / 2
        let rightDash = extra - leftDash
        chars.topLeft ++
        stringRepeat(chars.horizontal, leftDash) ++
        name ++
        stringRepeat(chars.horizontal, rightDash) ++
        chars.topRight
      } else {
        chars.topLeft ++ chars.horizontal ++ name ++ chars.horizontal ++ chars.topRight
      }
    }
  | (None, None) => chars.topLeft ++ dashes ++ chars.topRight
  }
}

and buildBody = (
  c: V2Types.containerNode,
  ~interior: int,
  ~chars: BorderChars.set,
): array<string> => {
  let rows = groupChildrenIntoRows(c.children, c.layout)
  let lines: array<string> = []
  Array.forEach(rows, row =>
    switch row {
    | InlineRow(arr) => {
        let content = emitInlineRowLine(arr, interior, c.layout.distribution)
        let line = chars.vertical ++ content ++ chars.vertical
        lines->Array.push(line)
      }
    | BlockNode(n) =>
      switch n {
      | ContainerNode(child) => {
          // Nested container: emit its lines, indent by 1 space, and wrap
          // each line in `| ... |` with right-padding to fit `interior`.
          let childLines = emitContainer(child, ~chars)
          Array.forEach(childLines, cl => {
            let needed = interior - inlineWidth(cl)
            let needed = needed < 0 ? 0 : needed
            let line = chars.vertical ++ cl ++ stringRepeat(" ", needed) ++ chars.vertical
            lines->Array.push(line)
          })
        }
      | TextNode(t) => {
          let s = t.content
          let align = t.align
          let line = padAligned(s, interior, align)
          lines->Array.push(chars.vertical ++ line ++ chars.vertical)
        }
      | _ => {
          let s = InlineEmitter.emitInline(n)
          // Inline single element on a line: default Left alignment unless
          // node specifies otherwise.
          let line = padAligned(s, interior, V2Types.Left)
          lines->Array.push(chars.vertical ++ line ++ chars.vertical)
        }
      }
    }
  )
  lines
}

and padAligned = (s: string, width: int, align: V2Types.alignment): string => {
  let len = inlineWidth(s)
  if len >= width {
    s
  } else {
    let slack = width - len
    switch align {
    | V2Types.Left => s ++ stringRepeat(" ", slack)
    | V2Types.Right => stringRepeat(" ", slack) ++ s
    | V2Types.Center => {
        let lp = slack / 2
        let rp = slack - lp
        stringRepeat(" ", lp) ++ s ++ stringRepeat(" ", rp)
      }
    }
  }
}

// Top-level: emit a scene or component block (header + children rows).
let emitBlock = (
  block: V2Types.blockNode,
  ~chars: BorderChars.set,
): array<string> => {
  let lines: array<string> = []
  let (slug, children, layout, extraHeaders) = switch block {
  | SceneBlock(s) => {
      let headers: array<string> = []
      switch s.title {
      | Some(t) => headers->Array.push("@title: " ++ t)
      | None => ()
      }
      switch s.device {
      | Some(d) => {
          let str = switch d {
          | V2Types.Mobile => "mobile"
          | V2Types.Tablet => "tablet"
          | V2Types.Desktop => "desktop"
          }
          headers->Array.push("@device: " ++ str)
        }
      | None => ()
      }
      switch s.transition {
      | Some(t) => headers->Array.push("@transition: " ++ t)
      | None => ()
      }
      ("@scene: " ++ s.slug, s.children, s.layout, headers)
    }
  | ComponentBlock(c) => {
      let headers: array<string> = []
      if Array.length(c.props) > 0 {
        let parts = Array.map(c.props, (p: V2Types.propDefinition) => {
          let suffix = if p.optional && Option.isNone(p.defaultValue) {
            "?"
          } else {
            ""
          }
          let def = switch p.defaultValue {
          | Some(d) => "=" ++ d
          | None => ""
          }
          p.name ++ suffix ++ def
        })
        headers->Array.push("@props: " ++ Array.join(parts, ", "))
      }
      ("@component: " ++ c.slug, c.children, c.layout, headers)
    }
  }
  lines->Array.push(slug)
  Array.forEach(extraHeaders, h => lines->Array.push(h))
  // Blank line separator (V2 parser tolerates this)
  lines->Array.push("")
  // Children rows
  let childRows = groupChildrenIntoRows(children, layout)
  Array.forEach(childRows, row =>
    switch row {
    | InlineRow(arr) => {
        // No surrounding container — just emit children with single-space gaps.
        let parts = Array.map(arr, c => InlineEmitter.emitInline(c))
        lines->Array.push(Array.join(parts, " "))
      }
    | BlockNode(n) =>
      switch n {
      | ContainerNode(child) => {
          let childLines = emitContainer(child, ~chars)
          Array.forEach(childLines, cl => lines->Array.push(cl))
        }
      | _ => lines->Array.push(InlineEmitter.emitInline(n))
      }
    }
  )
  lines
}
