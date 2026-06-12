# Wyreframe V2 Renderer — Design

## Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Status**: Draft / RFC
- **Implements**: `requirements.md` in this directory
- **Companion**: `syntax-v2-parser/design.md`, `ml-parser/{design,self-improvement}.md`
- **Implementation language**: ReScript (matching the rest of `src/parser/v2/`)

---

## 1. Module Layout

```
src/renderer/v2/
├── V2Renderer.res             # public entry — renderToString / renderToDOM
├── V2Renderer.resi            # interface (typed public surface)
├── types/
│   ├── RenderOptions.res      # render options record
│   ├── RenderResult.res       # output shape (string / DomHandle)
│   └── RenderContext.res      # internal render-time state (ID dedupe, group counters)
├── elements/                  # one module per AST node variant
│   ├── SceneRenderer.res
│   ├── ComponentRenderer.res
│   ├── ContainerRenderer.res
│   ├── TextRenderer.res
│   ├── ButtonRenderer.res
│   ├── LinkRenderer.res
│   ├── InputRenderer.res
│   ├── SelectRenderer.res
│   ├── CheckboxRenderer.res
│   ├── RadioRenderer.res
│   ├── DividerRenderer.res
│   ├── StringRenderer.res
│   ├── EmojiRenderer.res
│   ├── PropPlaceholderRenderer.res
│   └── ErrorRenderer.res
├── layout/
│   ├── LayoutClasses.res      # direction/distribution → class translation
│   └── AlignmentClasses.res
├── output/
│   ├── HtmlBuilder.res        # string-mode builder (escape, attribute serialize)
│   └── DomBuilder.res         # DOM-mode builder (createElement, appendChild)
├── css/
│   └── wyreframe-v2.css       # reference stylesheet (shipped as separate sub-export)
├── emoji/
│   └── DefaultEmojiTable.res  # built-in shortcode → glyph map
└── __tests__/
    ├── golden/                # snapshot tests per node type + composition
    └── ...
```

Public TypeScript entry (`src/renderer/v2/index.ts`) re-exports the ReScript module with TypeScript types from `V2Renderer.d.ts` (manually authored, matching the V2 Parser's `.d.ts` convention).

---

## 2. Public API

```rescript
// V2Renderer.resi  (signature)

type renderOptions
type renderHandle    // returned by renderToDOM, supports dispose() and update()

let defaultOptions: unit => renderOptions

let renderToString: (V2Types.astNode, renderOptions) => string

let renderToDOM:
  (V2Types.astNode, DomBindings.element, renderOptions)
  => result<renderHandle, renderError>

// Component instantiation convenience
let renderComponent:
  (V2Types.astNode, ~props: Dict.t<string>, renderOptions)
  => string
```

`renderOptions` (record):

```rescript
type errorHandling = Skip | RenderMarker | Throw

type renderOptions = {
  classPrefix: string,                              // default "wf-"
  errorHandling: errorHandling,                     // default RenderMarker
  componentPropValues: Dict.t<string>,              // default empty
  emojiResolver: option<string => option<string>>,  // default None → use built-in
  includeSourceLocations: bool,                     // default true
  idPrefix: string,                                 // default "wf-"
  syntheticIdSalt: string,                          // for deterministic synthetic IDs
}
```

TypeScript shape (declared in `V2Renderer.d.ts`):

```ts
export interface RenderOptions {
  classPrefix?: string;
  errorHandling?: "skip" | "render" | "throw";
  componentPropValues?: Record<string, string>;
  emojiResolver?: (shortcode: string) => string | undefined;
  includeSourceLocations?: boolean;
  idPrefix?: string;
  syntheticIdSalt?: string;
}

export function renderToString(ast: V2AstNode, options?: RenderOptions): string;
export function renderToDOM(
  ast: V2AstNode,
  container: HTMLElement,
  options?: RenderOptions
): RenderHandle;
```

---

## 3. Render Pipeline

```
V2 AST root
    │
    ▼
[1] Pre-pass:  walk tree, build RenderContext
                - dedupe IDs (track seen, emit warnings)
                - group-name inference for Radio nodes
                - flatten String/Emoji into text-content map for parents
                - apply componentPropValues to PropPlaceholders
    │
    ▼
[2] Dispatch:  for each node, look up its renderer in ElementRegistry
    │
    ▼
[3] Build:     renderer returns an "output node" (intermediate IR)
                - tag, attributes, classes, dataAttrs, children
    │
    ▼
[4] Emit:      backend converts IR → string  (HtmlBuilder)
                       OR    IR → DOM     (DomBuilder)
    │
    ▼
output (string or RenderHandle)
```

The intermediate IR (output node) lets us share a single rendering implementation across both string and DOM backends. Each `elements/<X>Renderer.res` module exposes:

```rescript
let render: (RenderContext.t, <SpecificNode>) => Ir.outputNode
```

Where `Ir.outputNode` is:

```rescript
type rec outputNode = {
  tag: string,
  classes: array<string>,
  attrs: array<(string, string)>,           // ordered for deterministic output
  dataAttrs: array<(string, string)>,
  children: array<child>,
}
and child =
  | Element(outputNode)
  | Text(string)                            // pre-escaped flag handled in emitter
  | Raw(string)                             // already-safe HTML (e.g. emoji glyph)
```

---

## 4. Per-Node Rendering Rules

| AST Variant | Tag | Required classes | Required data-attrs | Children handling |
| --- | --- | --- | --- | --- |
| `SceneNode` | `<section>` | `wf-scene`, `wf-device-<x>` if device | `data-wf-slug`, `data-wf-title?`, `data-wf-device?`, `data-wf-transition?` | recursive |
| `ComponentNode` | `<section>` | `wf-component` | `data-wf-slug`, `data-wf-prop-<n>` per prop | recursive |
| `ContainerNode` | `<div>` | `wf-container`, `wf-direction-<x>`, `wf-dist-<x>?` | row/col | recursive |
| `TextNode` (block) | `<p>` | `wf-text`, `wf-align-<x>` | row/col | text content |
| `TextNode` (inline in row) | `<span>` | `wf-text`, `wf-align-<x>` | row/col | text content |
| `ButtonNode` | `<button type="button">` | `wf-button`, `wf-align-<x>` | row/col, `data-wf-id?` | text content |
| `LinkNode` | `<a>` (no href) | `wf-link`, `wf-align-<x>` | row/col, `data-wf-id?` | text content |
| `InputNode` | `<input>` | `wf-input` | row/col, `data-wf-id?` | none (placeholder via attr) |
| `SelectNode` | `<select>` containing `<option>`s | `wf-select` | row/col, `data-wf-id?` | one `<option>` per AST option |
| `CheckboxNode` | `<label class="wf-checkbox">` wrapping `<input type="checkbox">` + `<span>` | `wf-checkbox` | row/col, `data-wf-id?`, `data-wf-checked` | none |
| `RadioNode` | `<label class="wf-radio">` wrapping `<input type="radio" name="..">` + `<span>` | `wf-radio` | row/col, `data-wf-id?`, `data-wf-group` | none |
| `DividerNode` | `<hr>` | `wf-divider`, `wf-divider-bold?` | row/col | none |
| `StringNode` | `<span>` | `wf-string` | row/col | literal text |
| `EmojiNode` | `<span aria-label="<shortcode>">` | `wf-emoji` | row/col, `data-wf-emoji-shortcode` | resolved glyph |
| `PropPlaceholderNode` (resolved) | inline text or span | `wf-prop-resolved` | `data-wf-prop` | substituted text |
| `PropPlaceholderNode` (missing) | `<span>` | `wf-prop-missing` | `data-wf-prop` | placeholder marker `{{name}}` |
| `ErrorNode` | per `errorHandling` option | `wf-error` | `data-wf-error-code`, `data-wf-error-msg` | error message text |

### Inline vs block Text disambiguation

A `TextNode` directly inside a `Container` whose `layoutInfo.direction` is `Row` is rendered as `<span>` (inline); otherwise as `<p>` (block). This is a pure structural rule, no content sniffing.

---

## 5. Layout Translation

Implemented in `layout/LayoutClasses.res`:

```rescript
let directionClass = (dir: V2Types.layoutDirection): string =>
  switch dir {
  | Row    => "wf-direction-row"
  | Column => "wf-direction-column"
  | Mixed  => "wf-direction-mixed"
  }

let distributionClass = (d: V2Types.distribution): string =>
  switch d {
  | Equal        => "wf-dist-equal"
  | SpaceBetween => "wf-dist-space-between"
  | SpaceAround  => "wf-dist-space-around"
  | Start        => "wf-dist-start"
  | End          => "wf-dist-end"
  | Center_      => "wf-dist-center"
  }
```

Implemented in `layout/AlignmentClasses.res`:

```rescript
let alignmentClass = (a: V2Types.alignment): string =>
  switch a {
  | Left   => "wf-align-left"
  | Center => "wf-align-center"
  | Right  => "wf-align-right"
  }
```

Reference stylesheet (`css/wyreframe-v2.css`) implements the table from Requirement 7. The renderer never inlines these styles; consumers either include the reference sheet or write their own.

---

## 6. Radio Group Inference

V2 AST does not carry explicit group names. Default inference rule:

> Radios sharing the *same parent container* and *contiguous source rows* (no non-radio sibling between them) belong to the same group.

Algorithm (pre-pass, in `RenderContext`):

1. Walk the AST in document order.
2. For each `ContainerNode`, scan children: maintain a sliding window of consecutive `RadioNode` siblings.
3. Each contiguous window gets a synthetic group name `<idPrefix>radio-<row>-<col>` where row/col is from the first radio in the window.
4. Non-radio siblings break the window.

This rule is documented as a default; future revisions may add explicit grouping syntax in V2.x.

---

## 7. RenderContext

```rescript
type t = {
  options: renderOptions,
  seenIds: Set.t<string>,        // ID dedupe
  warnings: array<warning>,       // collected during render
  radioGroups: Dict.t<string>,    // nodeKey → group name (precomputed in pre-pass)
  propValues: Dict.t<string>,     // resolved prop substitution table
}

type warning =
  | DuplicateId(string, V2Types.sourceLocation)
  | UnresolvedProp(string, V2Types.sourceLocation)
  | UnknownEmojiShortcode(string, V2Types.sourceLocation)
```

Warnings are exposed via `RenderHandle.warnings` (DOM mode) or as a parallel return value (string mode):

```rescript
let renderToStringWithDiagnostics:
  (V2Types.astNode, renderOptions)
  => (string, array<warning>)
```

---

## 8. Output Backends

### 8.1 HtmlBuilder (string mode)

Pure string assembly. Escaping rules:

- All text content: HTML-escape `<`, `>`, `&`, `"`, `'`.
- Attribute values: HTML-escape `&`, `"`.
- Attribute serialization SHALL be deterministic — fixed order: `id`, `class`, then alphabetical for everything else, then alphabetical for `data-*`.
- Self-closing tags (`<input>`, `<hr>`): emit as `<input ... />`.
- No pretty-printing in default mode (single-line); optional `prettyPrint: bool` for debug.

### 8.2 DomBuilder (DOM mode)

Uses bindings from existing `Renderer.res`'s `DomBindings` module (consolidated into a shared module). Creates real DOM nodes:

- `document.createElement(tag)`
- Set attributes via `setAttribute` for all `data-*`, `setClassName` for `class`, etc.
- Append children recursively in document order.

`RenderHandle`:

```rescript
type renderHandle = {
  root: DomBindings.element,
  warnings: array<warning>,
  dispose: unit => unit,            // detaches root + cleans listeners
  update: V2Types.astNode => unit,  // Phase 2: incremental update
}
```

For Phase 1, `update` performs full re-render under the same root (remove all children, re-render from scratch). Phase 2 will introduce a diffing algorithm operating on the intermediate IR.

---

## 9. Determinism Strategy

To guarantee byte-identical output for identical inputs (Requirement 11):

1. **Attribute order**: fixed canonical order (see §8.1).
2. **Class order**: alphabetical within an element.
3. **Child order**: AST document order, no shuffling.
4. **Synthetic IDs**: derived from `(syntheticIdSalt, node.location.start.row, node.location.start.col)`. Never random.
5. **Iteration**: AST traversal is a strict left-first depth-first walk.
6. **Whitespace**: no insertion or stripping beyond what the AST contains. `StringNode` content emitted verbatim.
7. **Emoji resolution**: deterministic table lookup; if shortcode missing, emit shortcode literal between `:` (e.g. `:unknown:`) and record warning.

A dedicated test (`__tests__/determinism_test.res`) asserts `renderToString(ast, opts) === renderToString(ast, opts)` for a corpus of 100+ ASTs.

---

## 10. Error Handling

| Error class | When | Behavior |
| --- | --- | --- |
| Malformed AST (record shape mismatch) | Caught by type system at compile time | n/a (impossible by type) |
| `ErrorNode` in AST | Per `errorHandling` option | skip / marker / throw |
| `renderToDOM` with no `container.appendChild` | Container is null/wrong type | `Error.NoDomEnvironment` |
| Duplicate ID | Pre-pass detects two nodes with same id | Warning + keep first |
| Unresolved prop | PropPlaceholder with no value and no default | Warning + render marker |
| Unknown emoji shortcode | Resolver returns None and no built-in match | Warning + render shortcode literal |

The renderer never silently produces incorrect output. Either a warning is collected, or in `throw` mode an exception fires.

---

## 11. Accessibility Implementation Notes

- Form controls use native semantic tags (no `role` attributes added).
- Checkbox/Radio wrap input in `<label>` so click on text toggles the control.
- Emoji `<span>` gets `aria-label="{shortcode}"` so screen readers announce names rather than glyph confusion.
- Scenes use `<section aria-label="{title}">` when title is present.
- Errors (when rendered) have `role="alert"` so AT can announce them.

---

## 12. Performance Strategy

For Requirement 14 (10k nodes in <100ms for string mode):

- Single pass with pre-computed indices; no repeated tree walks.
- String builder uses ReScript's mutable `Buffer.t` rather than concatenation.
- Avoid regex-based escaping; use direct character checks.
- Class array kept small and concatenated once per element.
- No object allocation in hot path beyond what the IR strictly needs.

Initial benchmark target: 10k nodes → < 50ms string mode on M1-class hardware (50% headroom).

---

## 13. CSS Reference Stylesheet (snippet)

`css/wyreframe-v2.css`:

```css
/* Layout primitives */
.wf-direction-row    { display: flex; flex-direction: row; }
.wf-direction-column { display: flex; flex-direction: column; }
.wf-direction-mixed  { display: grid; grid-auto-flow: row; }

.wf-dist-equal         { justify-content: space-evenly;  }
.wf-dist-space-between { justify-content: space-between; }
.wf-dist-space-around  { justify-content: space-around;  }
.wf-dist-start         { justify-content: flex-start;    }
.wf-dist-end           { justify-content: flex-end;      }
.wf-dist-center        { justify-content: center;        }

.wf-align-left   { text-align: left;   }
.wf-align-center { text-align: center; }
.wf-align-right  { text-align: right;  }

/* Default visual treatments — opinionated but minimal */
.wf-container { border: 1px solid currentColor; padding: .5rem; }
.wf-divider   { border: none; border-top: 1px solid currentColor; }
.wf-error     { color: #c00; outline: 1px dashed #c00; }
.wf-prop-missing { opacity: .5; font-style: italic; }

/* Device hints (consumers may override or remove) */
.wf-scene.wf-device-mobile  { max-width: 375px; }
.wf-scene.wf-device-tablet  { max-width: 768px; }
.wf-scene.wf-device-desktop { max-width: 1280px; }
```

This stylesheet ships as a separate sub-export so consumers can opt in (`import "@wyreframe/renderer-v2/style.css"`).

---

## 14. Testing Strategy

Golden snapshot tests organized as:

```
__tests__/
├── golden/
│   ├── scene/             # one fixture per scene variant
│   ├── component/
│   ├── container/
│   │   ├── row.snap
│   │   ├── column.snap
│   │   ├── mixed.snap
│   │   ├── dist-equal.snap
│   │   ├── ...
│   ├── elements/          # per node type
│   │   ├── button.snap
│   │   ├── input.snap
│   │   ├── ...
│   ├── composition/       # realistic multi-node samples
│   │   ├── login-form.snap
│   │   ├── dashboard.snap
│   │   └── ...
│   └── edge-cases/
│       ├── empty-scene.snap
│       ├── duplicate-id.snap
│       ├── missing-prop.snap
│       └── ...
├── determinism_test.res
├── accessibility_test.res
├── performance_test.res   # benchmarks
└── api_surface_test.ts    # TS-level API contract test
```

Snapshot format: HTML string (single line), one per `.snap` file. Consumers can re-record with a `--update-snapshots` flag.

Determinism test: render each fixture twice, assert byte-identical.

Accessibility test: parse rendered HTML, assert presence of required ARIA / semantic elements per Requirement 13.

API surface test: TypeScript-level test that exercises every public function and verifies type signatures via `tsc --noEmit`.

---

## 15. Relationship to V2 Parser & ML Parser

```
                      ASCII input
                          │
                          ▼
                  ┌───────────────┐
                  │  V2 Parser    │  (existing)
                  └───────┬───────┘
                          │ V2 AST
                          ▼
                  ┌───────────────┐
                  │ V2 Renderer   │  (THIS spec)
                  │ (forward)     │
                  └───────┬───────┘
                          │
                          ▼
                       HTML/DOM
                          │
   ┌──────────────────────┼────────────────────────┐
   │                      │                        │
   │ used by user/         │ used by ML            │
   │ consumer directly     │ Self-Improvement      │
   │                      │ Loop's pixel verifier │
   │                      │ (browser screenshot)  │
   ▼                      ▼                        │
 final HTML            comparison signal           │
                                                   │
                       Cycle path:                 │
                       V2 AST → ASCII renderer ────┘
                       (separate spec:
                        `v2-ascii-printer`)
```

This spec is exactly *one half* of what the ML Parser self-improvement loop needs. The reverse half (V2 AST → ASCII) is intentionally split into its own spec because it has different design constraints (font metric determinism, grid alignment, character vocabulary) than HTML output.

---

## 16. Open Questions

1. **Class prefix collisions**: `wf-` is short and may collide with user code. Should we default to `wireframe-` and let `wf-` be opt-in? Decision deferred to first integration test.
2. **Default emoji table size**: 200 / 500 / 1000 shortcodes? Larger = more bundle. Start with ~200 (most common), make extensible.
3. **`update()` API for DOM mode**: full re-render in Phase 1 — is the API shape `update(newAst)` or `update(patches)`? Choose API in Phase 1 that doesn't preclude either Phase-2 implementation.
4. **Component instantiation vs Scene rendering**: Should we have a single `render(ast, options)` that dispatches based on root, or distinct `renderScene` / `renderComponent`? Recommendation: single entry, dispatches on root variant.
5. **Container vs Section heuristic**: Should a top-level `ContainerNode` (no parent Scene) render as `<section>` or `<div>`? Recommendation: always `<div>` for Container; semantic landmarks only for Scene/Component.
6. **Streaming / chunked output for very large ASTs**: Out of Phase 1 scope; reconsider when 10k-node target is exceeded in practice.

---

## 17. Out of Scope

- HTML → ASCII direction (see `v2-ascii-printer` spec).
- Interaction DSL execution.
- V1 AST support.
- Theming / domain registries (per `ml-parser/design.md §1.1`).
- Server-side hydration handshake (Phase 3 if needed).
- Web Components emission (could be a separate render mode in the future).
- Tailwind / CSS-in-JS integration (consumers can layer on top of emitted classes).
