# Wyreframe V2 ASCII Printer — Design

## Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Status**: Draft / RFC
- **Implements**: `requirements.md` in this directory
- **Companion**: `syntax-v2-parser/design.md`, `v2-renderer/design.md`, `ml-parser/self-improvement.md`
- **Implementation language**: ReScript

---

## 1. Module Layout

```
src/printer/v2/
├── V2Printer.res              # public entry — print / printWithLocations
├── V2Printer.resi             # interface
├── types/
│   ├── PrintOptions.res
│   ├── LayoutNode.res         # intermediate sized-tree node
│   └── Canvas.res             # 2D char buffer abstraction
├── inference/
│   ├── WidthInference.res     # bottom-up width computation
│   └── HeightInference.res    # bottom-up height computation
├── layout/
│   ├── DistributionSolver.res # space distribution algorithms
│   ├── AlignmentSolver.res
│   └── PositionPass.res       # top-down absolute position assignment
├── emit/
│   ├── BorderChars.res        # ASCII / Unicode char tables
│   ├── NodeEmitters/          # per-node-type painters
│   │   ├── SceneEmitter.res
│   │   ├── ComponentEmitter.res
│   │   ├── ContainerEmitter.res
│   │   ├── TextEmitter.res
│   │   ├── ButtonEmitter.res
│   │   ├── LinkEmitter.res
│   │   ├── InputEmitter.res
│   │   ├── SelectEmitter.res
│   │   ├── CheckboxEmitter.res
│   │   ├── RadioEmitter.res
│   │   ├── DividerEmitter.res
│   │   ├── StringEmitter.res
│   │   ├── EmojiEmitter.res
│   │   ├── PropPlaceholderEmitter.res
│   │   └── ErrorEmitter.res
│   └── CanvasEmitter.res      # Canvas → string serialization
└── __tests__/
    ├── golden/
    ├── roundtrip/             # corpus of ASTs proving round-trip
    ├── idempotent_test.res
    ├── determinism_test.res
    └── performance_test.res
```

---

## 2. Public API

```rescript
// V2Printer.resi

type charset = ASCII | Unicode
type lineEnding = LF | CRLF
type errorHandling = Skip | RenderComment | Throw

type printOptions = {
  charset: charset,                  // default ASCII
  lineEnding: lineEnding,            // default LF
  errorHandling: errorHandling,      // default RenderComment
  containerPadding: int,             // default 1
  trimTrailing: bool,                // default false
  maxColumns: option<int>,           // default None (warn-only when exceeded)
}

let defaultOptions: unit => printOptions

let print: (V2Types.astNode, printOptions) => string

let printWithLocations:
  (V2Types.astNode, printOptions)
  => (string, Dict.t<V2Types.sourceLocation>)

let printWithLayoutTree:  // debug
  (V2Types.astNode, printOptions)
  => (string, LayoutNode.t)
```

TypeScript wrapper (`V2Printer.d.ts`):

```ts
export interface PrintOptions {
  charset?: "ascii" | "unicode";
  lineEnding?: "lf" | "crlf";
  errorHandling?: "skip" | "render-comment" | "throw";
  containerPadding?: number;
  trimTrailing?: boolean;
  maxColumns?: number;
}

export function print(ast: V2AstNode, options?: PrintOptions): string;
```

---

## 3. Pipeline

```
V2 AST root
    │
    ▼
[1] Width Pass (bottom-up)
       computes  each_node.width  using node-type rules
       (LayoutNode tree built in parallel — sized but un-positioned)
    │
    ▼
[2] Height Pass (bottom-up)
       computes  each_node.height
    │
    ▼
[3] Position Pass (top-down)
       given parent (x, y, w, h), assigns child (x, y)
       applies distribution + alignment
    │
    ▼
[4] Canvas Allocation
       canvas: array<array<char>>  of shape (totalRows × totalCols)
       filled with spaces
    │
    ▼
[5] Paint Pass
       walks LayoutNode tree, each emitter paints its node onto canvas
       at its absolute (x, y) using BorderChars per charset
    │
    ▼
[6] Serialize
       canvas → string with configured line ending
       optional trailing-trim
    │
    ▼
output string  (+ optional locationMap)
```

The LayoutNode tree (intermediate representation) is the *single source of truth* between passes; this lets each pass be pure and testable in isolation.

---

## 4. LayoutNode Intermediate Representation

```rescript
type rec t = {
  source: V2Types.astNode,           // original AST node reference
  width: int,                         // computed in pass 1
  height: int,                        // computed in pass 2
  x: int,                             // computed in pass 3 (absolute)
  y: int,                             // computed in pass 3 (absolute)
  innerWidth: int,                    // width minus borders/padding
  innerHeight: int,
  children: array<t>,
  // node-specific overlay info:
  alignmentOffset: option<int>,       // for Text/Button/Link inside Column
  distributionGaps: array<int>,       // for Row containers: gap sequence
}
```

Each pass mutates only its own fields. Tests can construct LayoutNode trees directly to verify emitters in isolation.

---

## 5. Width Inference Table

Per Requirement 6. Bottom-up.

| Node | Width formula |
| --- | --- |
| `StringNode` | `String.length(text)` |
| `EmojiNode` | 1 (assume single-cell glyph, see Open Q #4) |
| `TextNode` | `String.length(content)` |
| `ButtonNode` | `String.length(text) + 2` (brackets `[`, `]`) |
| `LinkNode` | `String.length(text) + 2` (V2 link bracketing) |
| `InputNode` | `max(String.length(placeholder ?? ""), 3) + 2` (min `[___]`) |
| `SelectNode` | `max(option widths) + 2 + dropdown indicator width` |
| `CheckboxNode` | `3 + String.length(label) + 1` (`[x] label`) |
| `RadioNode` | `3 + String.length(label) + 1` (`(x) label`) |
| `DividerNode` | parent's interior width (fills the row) |
| `PropPlaceholderNode` | `String.length("{{" + name + ("=" + default ?? "") + "}}")` |
| `ContainerNode` | see below |
| `SceneNode` / `ComponentNode` | block syntax width (header lines + children block width) |

### Container width

```
container.width = max(
  borders + padding*2 + max(child.width for child in column children),
  borders + padding*2 + sum(child.width) + (len(row_children) - 1) * inter_gap,
  minimum_container_width  // 4 for `+--+`
)
```

For `Mixed` direction containers, width is `max` over all groups, where each group is computed per its own direction.

---

## 6. Height Inference

Similar bottom-up. Leaves are 1 (single line). Containers:

```
container.height =
  + 2 (top/bottom borders)
  + (
      if direction == Column: sum(child.height for column children)
      if direction == Row:    max(child.height for row children)
      if direction == Mixed:  sum(group.height for groups)
    )
  + content_vertical_padding (default 0)
```

Block (`Scene` / `Component`) height = header_lines (1–3) + children_block_height + optional trailing blank.

---

## 7. Position Pass (top-down)

Inputs: parent's `(x, y, innerWidth, innerHeight)` (interior region after borders/padding).

Algorithm per container:

1. Compute *child cluster widths* (for row: sum, for column: max).
2. Compute *available slack* = `innerWidth - cluster_width` (row) or `innerHeight - cluster_height` (column).
3. Apply distribution algorithm (§8) to assign per-child `(x, y)` coordinates.
4. Apply alignment for column children that have an `alignment` field (Text/Button/Link).
5. Recurse into each child with its assigned region.

For Mixed direction:

1. Compute group bounding regions (each group spans its row range).
2. For each group, apply its direction-specific layout within its region.

---

## 8. Distribution Algorithm

Per Requirement 7. All algorithms work on integer cell coordinates.

Given:
- `slack`: leftover cells after subtracting cluster width
- `n`: number of children
- All assignments produce integer offsets; uneven remainders distributed leftmost-first (deterministic).

| Distribution | Algorithm |
| --- | --- |
| **Equal** (`space-evenly`) | `gap = slack / (n + 1)`, `remainder = slack % (n + 1)`. First `remainder` gaps get +1. Place children at cumulative offsets. |
| **SpaceBetween** | First child at start, last at end. Interior `n-2` children evenly spaced: `interior_gap = (slack + cluster_width - first_w - last_w) / (n - 1)`. |
| **SpaceAround** | Half-gaps at edges: `outer_gap = slack / (2n)`, interior `gap = slack / n`. |
| **Start** | All children clustered left with fixed `inter_gap` (default 1). Slack at right. |
| **End** | Cluster right with fixed inter-gap. Slack at left. |
| **Center_** | Cluster centered; `outer_padding = slack / 2`. |

For column layout, the same algorithms apply on the Y axis with cluster_height instead of cluster_width.

---

## 9. Alignment Solver

For column children with an `alignment` field:

```rescript
let resolveAlignment = (child, parentInner) => {
  let xOffset = switch child.source.alignment {
  | Left => 0
  | Center => (parentInner.width - child.width) / 2
  | Right => parentInner.width - child.width
  }
  // tie-break for centering with odd remainder: leftmost-first
  ...
}
```

Alignment is ignored when the immediate parent is a row container (distribution governs horizontal placement).

---

## 10. Border Characters Table

| Position | ASCII | Unicode |
| --- | --- | --- |
| top-left | `+` | `┌` |
| top-right | `+` | `┐` |
| bottom-left | `+` | `└` |
| bottom-right | `+` | `┘` |
| top/bottom edge | `-` | `─` |
| left/right edge | `\|` | `│` |
| T-junction down | `+` | `┬` |
| T-junction up | `+` | `┴` |
| T-junction right | `+` | `├` |
| T-junction left | `+` | `┤` |
| cross | `+` | `┼` |

Stored in `BorderChars.res`:

```rescript
type set = {
  topLeft: string, topRight: string,
  bottomLeft: string, bottomRight: string,
  horizontal: string, vertical: string,
  teeDown: string, teeUp: string,
  teeRight: string, teeLeft: string,
  cross: string,
}

let ascii: set = {...}
let unicode: set = {...}
```

---

## 11. Canvas

```rescript
type t = {
  cols: int,
  rows: int,
  buffer: array<array<string>>,  // [row][col] → single-char string
}

let make = (rows: int, cols: int): t => {...}
let set = (canvas, row, col, ch): unit => ...
let writeText = (canvas, row, colStart, text): unit => ...
let drawBox = (canvas, x, y, w, h, ~chars: BorderChars.set): unit => ...
let drawHLine = (canvas, row, colStart, colEnd, ~char): unit => ...
let drawVLine = (canvas, col, rowStart, rowEnd, ~char): unit => ...
let toString = (canvas, ~lineEnding: lineEnding, ~trimTrailing: bool): string => ...
```

Canvas is mutable internally (performance) but the public API is functional (input AST → output string).

---

## 12. Per-Node Emitter Rules

| Node | Emit |
| --- | --- |
| `SceneNode` | line 1: `@scene: <slug>`; line 2 (if title): `@title: <title>`; line 3 (if device): `@device: <device>`; blank line; render children block at its position |
| `ComponentNode` | line 1: `@component: <slug>`; line 2 (if props): `@props: <prop list>`; blank; children block |
| `ContainerNode` | `drawBox` at (x, y) with (w, h); recursively paint children inside |
| `TextNode` (column inline) | `writeText` at (x + alignmentOffset, y) |
| `TextNode` (inside row) | `writeText` at assigned (x, y) |
| `ButtonNode` | `writeText "[" + text + "]"` at (x, y) |
| `LinkNode` | per V2 syntax; e.g. `writeText "<link-text>"` or `[link-text]` (TBD: check V2 spec for exact link syntax) |
| `InputNode` | `writeText "[" + placeholder_or_underscores + "]"` |
| `SelectNode` | `writeText "[" + first_option + " v]"` (dropdown indicator); other options rendered? — TBD per V2 syntax exact form |
| `CheckboxNode` | `writeText "[x] " + label` (or `[ ]` for unchecked) |
| `RadioNode` | `writeText "(x) " + label` (or `( )`) |
| `DividerNode` | `drawHLine` across parent's interior using `horizontal` char (or `==` for bold style) |
| `StringNode` | `writeText` at (x, y) |
| `EmojiNode` | `writeText` resolved glyph (single-char assumption) |
| `PropPlaceholderNode` | `writeText "{{" + name + (default ? "=" + default : "") + "}}"` |
| `ErrorNode` | per errorHandling option |

Exact V2 syntax for each node MUST be verified against `docs/syntax-v2.md` during implementation.

---

## 13. Round-Trip Verification Suite

`__tests__/roundtrip/` contains:

```
corpus/
├── empty_scene.ast.json
├── single_button.ast.json
├── login_form.ast.json
├── deep_nesting.ast.json
├── all_distributions.ast.json
├── all_alignments.ast.json
├── mixed_layout.ast.json
├── unicode_charset.ast.json
├── component_with_props.ast.json
└── ... (100+ fixtures total)
```

For each fixture, the test:

1. Reads AST_A from JSON.
2. Calls `print(AST_A, options)` to get string S_1.
3. Parses S_1 with V2 Parser to get AST_A'.
4. Asserts `semanticallyEqual(AST_A, AST_A')` (defined in `roundtrip/Compare.res`).
5. Calls `print(AST_A', options)` to get S_2.
6. Asserts `S_1 === S_2` byte-identical (idempotency, Requirement 4).

`semanticallyEqual` ignores `sourceLocation` and `bounds`, compares everything else.

---

## 14. Determinism Strategy

Mirrors `v2-renderer/design.md §9`:

1. AST traversal: strict document-order DFS.
2. Distribution remainders: leftmost-first.
3. No random / time / env input.
4. Canvas → string serialization: row-major, single canonical line ending.
5. Trailing space handling: deterministic per `trimTrailing` flag.
6. Same options → same output: enforced by 5000-case determinism test.

---

## 15. Performance Strategy

Target: 10k AST nodes in <100ms.

- Three passes, each O(N).
- Canvas allocated once at known total size (no resizing).
- Char writes are O(1) per cell.
- String serialization uses `Buffer.t`.
- Avoid intermediate string concatenation; build into Buffer directly.

Pre-pass to compute total grid size enables single canvas allocation.

Initial benchmark target: 10k nodes → 50ms with 50% headroom.

---

## 16. Relationship to ML Self-Improvement Loop

```
                  ASCII input  A
                       │
                       ▼
                ┌──────────────┐
                │  ML Parser   │
                └──────┬───────┘
                       │ V2 AST
              ┌────────┴────────┐
              ▼                 ▼
       ┌──────────────┐   ┌──────────────┐
       │ V2 Renderer  │   │ V2 Printer   │  (THIS spec)
       └──────┬───────┘   └──────┬───────┘
              │                  │
              ▼                  ▼
            HTML                ASCII A'
              │                  │
              ▼                  │
        screenshot               │
              │                  │
              ▼                  ▼
      ┌─────────────────────────────┐
      │   Verification              │
      │  - Pixel SSIM (HTML vs A)   │
      │  - Cycle edit dist (A vs A')│
      │  - LLM judge                │
      └─────────────────────────────┘
```

This Printer is the **second of two prerequisites** for the ML self-improvement loop. The first (`v2-renderer`) supplies the pixel-comparison branch; this Printer supplies the cycle-consistency branch.

---

## 17. Open Questions

1. **Comment syntax**: Requirement 12 / Open Q #1. Needs `syntax-v2` working group decision.
2. **Selector dropdown rendering**: Exact V2 syntax for `SelectNode` not finalized — check `docs/syntax-v2.md` during T-implementation. Open Q for grammar precision.
3. **Link syntax**: V2 may distinguish between `[text]` (button) and `<text>` (link) or use a different convention; verify before implementation.
4. **Unicode width**: Assume 1-cell-per-char in v0.1. Fail loudly on CJK/emoji-wide inputs.
5. **Round-trip with style hints**: If V2 adds `@align: center` style hints later, does the Printer round-trip them via the AST's alignment field or via explicit annotations? Defer.
6. **Mixed direction precedence**: When `direction = Mixed` has both row and column groups, what's the canonical group ordering rule? Recommendation: AST document order (groups already carry `startRow`).
7. **Distribution + alignment interaction**: For a `Row` container with `distribution = Center_`, children's individual alignment should be ignored (cluster is centered as a whole). Confirm in tests.

---

## 18. Out of Scope

- Parsing — V2 Parser's job.
- HTML emission — V2 Renderer's job.
- V1 AST.
- Text wrapping or width-cap reflow.
- Color/styling.
- Non-monospace fonts.
- Incremental update.
