# Wyreframe V2 Renderer Requirements Document

## Introduction

This document defines the requirements for the Wyreframe V2 Renderer. The V2 Renderer is responsible for converting a validated V2 AST (produced by the V2 Parser as specified in `syntax-v2-parser`) into semantic HTML/DOM. It is a *forward* renderer; the reverse direction (AST → ASCII) is covered by a separate spec.

### Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Based on Spec**: Wyreframe Syntax v2.3, V2 AST types defined in `src/parser/v2/types/V2Types.res`
- **Status**: Draft
- **Companion Spec**: `syntax-v2-parser` (parser side), `v2-ascii-printer` (reverse direction, separate)

### Scope

The V2 Renderer handles the following:

- All 15 node types of the V2 AST (Scene, Component, Container, Text, Button, Link, Input, Select, Checkbox, Radio, Divider, String, Emoji, PropPlaceholder, Error).
- Conversion of `layoutInfo` (direction + distribution) into CSS layout primitives.
- Translation of `alignment` to CSS text/flex alignment.
- Preservation of `sourceLocation` as DOM data-attributes (for editor integrations).
- Preservation of element IDs from the V2 AST.
- Component prop resolution: replacing `PropPlaceholder` nodes with values supplied at render time.
- Two output modes: `renderToString` (HTML string for SSR/snapshot tests) and `renderToDOM` (live DOM mutation for browser).
- Configurable error-node handling (skip / render-as-marker / throw).

The V2 Renderer does NOT handle the following:

- Parsing (covered by `syntax-v2-parser`).
- Interaction DSL execution (out-of-scope for V2 syntax).
- HTML → ASCII reverse rendering (covered by `v2-ascii-printer`).
- V1 AST input (the existing `Renderer.res` continues to serve V1).
- CSS shipping; the renderer emits semantic class names and data-attributes, but the consumer supplies the stylesheet.
- Theming or domain-specific component registries (per `ml-parser/design.md §1.1`).

---

## Requirements

### Requirement 1: V2 AST Input Acceptance

**User Story:** As a developer, I want the V2 Renderer to accept any validated V2 AST so that the parser and renderer can compose without intermediate transformations.

**Reference**: `src/parser/v2/types/V2Types.res`, V2 AST schema.

#### Acceptance Criteria

1. WHEN the Renderer receives a value of type `V2Types.astNode` rooted at `SceneNode` or `ComponentNode` THEN the Renderer SHALL produce output without runtime error.
2. WHEN the input contains any of the 15 documented node variants THEN the Renderer SHALL handle that variant with its dedicated rendering rule (see Requirements 3–7).
3. IF the input is not a valid V2 AST shape (e.g. malformed record) THEN the Renderer SHALL surface a typed error rather than producing partial output.
4. The Renderer SHALL NOT mutate the input AST.

---

### Requirement 2: HTML Output Conventions

**User Story:** As a developer, I want the rendered HTML to follow consistent semantic and styling conventions so that downstream CSS/JS integration is predictable.

#### Acceptance Criteria

1. WHEN any non-Error node is rendered THEN the output element SHALL carry a CSS class of the form `wf-<node-type>` (e.g. `wf-container`, `wf-button`).
2. WHEN any node has a `sourceLocation` THEN the output element SHALL carry `data-wf-row` and `data-wf-col` attributes with the start position (zero-based).
3. WHEN any node has a stable ID THEN the output element SHALL carry `data-wf-id` AND a DOM `id` attribute (the DOM `id` SHALL be prefixed by `wf-` to avoid collisions with host page IDs).
4. WHEN a node carries an `alignment` field THEN the output SHALL include a class `wf-align-<left|center|right>`.
5. The class prefix `wf-` SHALL be configurable via render options (`classPrefix`) but default to `wf-`.

---

### Requirement 3: Block-Level Rendering (Scene, Component)

**User Story:** As a developer, I want Scene and Component blocks to render as top-level HTML containers carrying their metadata so the consumer can switch scenes or instantiate components.

#### Acceptance Criteria

1. WHEN a `SceneNode` is rendered THEN the Renderer SHALL emit a `<section class="wf-scene">` element with `data-wf-slug` set to the scene's slug.
2. WHEN the scene has a `title` THEN the output SHALL include `data-wf-title` with the title text.
3. WHEN the scene has a `device` (Mobile/Tablet/Desktop) THEN the output SHALL include class `wf-device-<value>` AND `data-wf-device` attribute.
4. WHEN the scene has a `transition` THEN the output SHALL include `data-wf-transition` with the transition name.
5. WHEN a `ComponentNode` is rendered THEN the Renderer SHALL emit `<section class="wf-component">` with `data-wf-slug` for the component slug.
6. WHEN the component declares `props` THEN each prop SHALL be reflected as `data-wf-prop-<name>` attribute with values `"required"`, `"optional"`, or the default value if specified.

---

### Requirement 4: Container Rendering with Layout

**User Story:** As a developer, I want Container nodes to render as flexbox/grid containers whose layout reflects the parser-inferred `layoutInfo`, so the rendered output visually matches the wireframe structure.

#### Acceptance Criteria

1. WHEN a `ContainerNode` is rendered THEN the Renderer SHALL emit a `<div class="wf-container">` element.
2. WHEN the container's `layoutInfo.direction` is `Row` THEN the output element SHALL carry class `wf-direction-row` AND CSS-equivalent class for `display: flex; flex-direction: row` (see Requirement 7 for the exact translation).
3. WHEN the container's `layoutInfo.direction` is `Column` THEN it SHALL carry `wf-direction-column`.
4. WHEN the container's `layoutInfo.direction` is `Mixed` THEN it SHALL carry `wf-direction-mixed` and use grid-based class semantics.
5. WHEN the container's `layoutInfo.distribution` is one of `Equal | SpaceBetween | SpaceAround | Start | End | Center_` THEN it SHALL carry class `wf-dist-<value>` with the kebab-cased value (e.g. `wf-dist-space-between`).
6. Children of the container SHALL be rendered recursively in document order.

---

### Requirement 5: Form Element Rendering

**User Story:** As a developer, I want UI primitive nodes (Button, Link, Input, Select, Checkbox, Radio) to render as their semantically correct HTML form/control elements with proper labels.

#### Acceptance Criteria

1. WHEN a `ButtonNode` is rendered THEN it SHALL produce `<button class="wf-button" type="button">` with the button text as content.
2. WHEN a `LinkNode` is rendered THEN it SHALL produce `<a class="wf-link">`. The `href` attribute SHALL NOT be set by the renderer (link targets are out-of-scope, supplied by interaction layer if present).
3. WHEN an `InputNode` is rendered THEN it SHALL produce `<input class="wf-input">` with `placeholder` attribute set from the node's text when present.
4. WHEN a `SelectNode` is rendered THEN it SHALL produce `<select class="wf-select">` containing one `<option>` per declared option.
5. WHEN a `CheckboxNode` is rendered THEN it SHALL produce `<label class="wf-checkbox"><input type="checkbox"/><span>{label}</span></label>`. The checkbox state (checked) SHALL reflect the AST's checked field.
6. WHEN a `RadioNode` is rendered THEN it SHALL produce `<label class="wf-radio"><input type="radio" name="{group}"/><span>{label}</span></label>`. Radios with the same parent container and same labeling pattern SHALL share a `name` attribute (group inference rule defined in design.md).
7. All form elements SHALL be focusable; the Renderer SHALL NOT add `disabled` or `readonly` unless the AST explicitly says so.

---

### Requirement 6: Content & Decorative Node Rendering

**User Story:** As a developer, I want Text, String, Emoji, and Divider nodes to render as their natural HTML equivalents.

#### Acceptance Criteria

1. WHEN a `TextNode` is rendered THEN it SHALL produce `<p class="wf-text">` with the text content as a child text node. Inline text within a row container MAY be rendered as `<span class="wf-text">` instead (see design.md for the rule).
2. WHEN a `StringNode` (literal) is rendered THEN it SHALL produce a `<span class="wf-string">` containing the literal text. Strings SHALL preserve any whitespace from the AST.
3. WHEN an `EmojiNode` is rendered THEN it SHALL produce a `<span class="wf-emoji">` containing the resolved emoji glyph. The Renderer SHALL accept an `emojiResolver` option to map shortcodes to glyphs; if no resolver is supplied, a built-in default table SHALL be used.
4. WHEN a `DividerNode` is rendered THEN it SHALL produce `<hr class="wf-divider">`. If `style` is `Bold` THEN class `wf-divider-bold` SHALL also be applied.

---

### Requirement 7: Layout Translation Rules

**User Story:** As a developer, I want a deterministic and documented mapping from V2 layout categories to CSS so the rendered output's visual layout is predictable.

#### Acceptance Criteria

1. The Renderer SHALL document the full mapping table in `design.md §Layout Translation`.
2. The minimum mapping table SHALL include:

| V2 field & value | Output class | Implied CSS (in shipped reference stylesheet) |
| --- | --- | --- |
| `direction = Row` | `wf-direction-row` | `display: flex; flex-direction: row` |
| `direction = Column` | `wf-direction-column` | `display: flex; flex-direction: column` |
| `direction = Mixed` | `wf-direction-mixed` | `display: grid` (auto-flow) |
| `distribution = Equal` | `wf-dist-equal` | `justify-content: space-evenly` |
| `distribution = SpaceBetween` | `wf-dist-space-between` | `justify-content: space-between` |
| `distribution = SpaceAround` | `wf-dist-space-around` | `justify-content: space-around` |
| `distribution = Start` | `wf-dist-start` | `justify-content: flex-start` |
| `distribution = End` | `wf-dist-end` | `justify-content: flex-end` |
| `distribution = Center_` | `wf-dist-center` | `justify-content: center` |
| `alignment = Left` | `wf-align-left` | `text-align: left` |
| `alignment = Center` | `wf-align-center` | `text-align: center` |
| `alignment = Right` | `wf-align-right` | `text-align: right` |

3. The Renderer SHALL emit ONLY classes; it SHALL NOT inline CSS styles. A reference stylesheet (`wyreframe-v2.css`) SHALL ship alongside the package implementing the table above.

---

### Requirement 8: Component Prop Resolution

**User Story:** As a developer, I want PropPlaceholder nodes inside a Component to be replaced by user-supplied prop values at render time so I can instantiate components with different content.

#### Acceptance Criteria

1. WHEN a `PropPlaceholderNode` is encountered AND the render options include `componentPropValues[name]` THEN the Renderer SHALL substitute the placeholder with the supplied value as a `StringNode`-equivalent rendering.
2. WHEN a `PropPlaceholderNode` is encountered AND no value is supplied AND the prop has a `defaultValue` THEN the Renderer SHALL substitute with the default value.
3. WHEN a `PropPlaceholderNode` is encountered AND no value is supplied AND no default exists THEN the Renderer SHALL render a visible placeholder marker `<span class="wf-prop-missing" data-wf-prop="{name}">{{{name}}}</span>` (configurable via options).
4. Prop substitution SHALL be purely textual; the substituted value SHALL NOT be re-parsed as wireframe syntax.

---

### Requirement 9: Error Node Handling

**User Story:** As a developer, I want a configurable behavior for AST Error nodes so I can choose between strict (fail) and lenient (visible marker / silent skip) modes.

#### Acceptance Criteria

1. The Renderer SHALL accept a render option `errorHandling: "skip" | "render" | "throw"` (default `"render"`).
2. WHEN `errorHandling = "skip"` AND an `ErrorNode` is encountered THEN the node SHALL produce no output.
3. WHEN `errorHandling = "render"` AND an `ErrorNode` is encountered THEN the renderer SHALL produce `<span class="wf-error" data-wf-error-code="{code}" data-wf-error-msg="{message}">{message}</span>`.
4. WHEN `errorHandling = "throw"` AND an `ErrorNode` is encountered THEN the renderer SHALL throw a typed exception containing the error node's location and message.
5. Error handling mode SHALL NOT affect rendering of non-Error siblings.

---

### Requirement 10: Output Modes

**User Story:** As a developer, I want the renderer to support both SSR (HTML string) and browser (live DOM) outputs so I can use it in build pipelines and in interactive editors.

#### Acceptance Criteria

1. The Renderer SHALL expose `renderToString(ast, options) -> string` producing a complete HTML string (no DOM dependencies).
2. The Renderer SHALL expose `renderToDOM(ast, container, options) -> RenderHandle` where `container` is a target DOM element and `RenderHandle` allows subsequent updates and disposal.
3. Both modes SHALL produce structurally equivalent output (same tag tree, same classes, same data-attributes) for the same input AST and options.
4. `renderToString` SHALL be available in Node.js environments without DOM polyfills.
5. `renderToDOM` SHALL detect when no DOM is available and throw a clear error.

---

### Requirement 11: Determinism

**User Story:** As a developer, I want the renderer's output to be perfectly deterministic so I can use it for snapshot tests, content hashing, and self-improvement cycle verification.

#### Acceptance Criteria

1. WHEN the renderer is called twice with the same `(ast, options)` THEN it SHALL produce byte-identical string outputs (under `renderToString`) AND structurally identical DOM (under `renderToDOM`).
2. The Renderer SHALL NOT inject any timestamp, random ID, or environment-dependent value into the output.
3. The Renderer SHALL NOT depend on iteration order of non-deterministic data structures (e.g. unordered Sets); all sequences SHALL respect AST document order.
4. Generated synthetic IDs (e.g. for radio groups without explicit names) SHALL be derived deterministically from AST node positions.

---

### Requirement 12: Source Location & ID Preservation

**User Story:** As a developer, I want every rendered element to carry traceability back to the source ASCII position so I can build editor integrations (hover-to-highlight, click-to-jump).

#### Acceptance Criteria

1. WHEN any non-meta node is rendered THEN the output element SHALL carry `data-wf-row` and `data-wf-col` reflecting the start position from `sourceLocation`.
2. WHEN a node has an end position different from start THEN the output element SHALL additionally carry `data-wf-row-end` and `data-wf-col-end`.
3. WHEN a node has an explicit ID in the V2 AST THEN the output element SHALL carry `id="wf-{id}"` AND `data-wf-id="{id}"`.
4. Element IDs SHALL be globally unique across a single render; if duplicates are present in the input AST then the renderer SHALL emit a typed warning (not error) and keep the first occurrence's ID.

---

### Requirement 13: Accessibility

**User Story:** As a developer, I want rendered wireframes to be accessible by default so basic screen-reader and keyboard usage works without extra work.

#### Acceptance Criteria

1. Form controls (Button, Link, Input, Select, Checkbox, Radio) SHALL use their semantic HTML elements (no `<div role="button">`).
2. Checkbox and Radio labels SHALL be associated via `<label>` wrapping the input.
3. Scenes and Components SHALL use landmark elements (`<section>`, optionally with `aria-label` when title is present).
4. Dividers SHALL use `<hr>`.
5. Emoji glyphs SHALL include `aria-label` derived from the original shortcode (e.g. `aria-label="smile"`).
6. The Renderer SHALL NOT add gratuitous ARIA roles that contradict the native semantics.

---

### Requirement 14: Performance

**User Story:** As a developer, I want the renderer to be fast enough for interactive editors so I can re-render on every keystroke without perceptible lag.

#### Acceptance Criteria

1. The Renderer SHALL complete `renderToString` on an AST of 10,000 nodes in under 100ms on a current development machine.
2. The Renderer SHALL be O(N) in the number of AST nodes; pathological inputs SHALL NOT trigger superlinear behavior.
3. `renderToDOM` SHALL support incremental update (re-render with diff applied to existing DOM) as a Phase-2 capability; full re-render is acceptable for Phase 1.

---

### Requirement 15: V1 Coexistence & Migration

**User Story:** As a developer of an existing wyreframe consumer, I want the V2 Renderer to ship in parallel with the V1 Renderer so I can migrate at my own pace without breaking changes.

#### Acceptance Criteria

1. The V2 Renderer SHALL live under a separate module path (`src/renderer/v2/V2Renderer.res`) AND be exported under a separate public entry (`@wyreframe/renderer-v2` or equivalent named export).
2. The existing V1 Renderer (`src/renderer/Renderer.res`) SHALL remain unchanged by this work; V1 consumers SHALL continue to function.
3. V2 Renderer SHALL NOT accept V1 AST shapes. The two renderers are isolated.
4. The package's top-level `index.ts` SHALL expose both renderers under distinct named exports (`renderV1`, `renderV2`, or similar), with the V2 export accompanied by deprecation guidance pointing future consumers to V2.
5. TypeScript declarations (.d.ts) SHALL be generated for the V2 Renderer's public surface (matching the pattern established for the V2 Parser).

---

## Open Questions

1. **Sealed stylesheet vs. user-supplied**: Should we ship a single canonical CSS file or only emit classes? Recommendation: emit classes + ship a reference stylesheet as a separate sub-export, so users can opt in or override.
2. **Radio group inference**: How do we determine which radios belong to the same group when the V2 AST does not carry explicit group names? Candidate: same parent container + adjacent positions = same group. To be finalized in design.md.
3. **Component instantiation API**: How does the public API express "render this Component with these prop values"? Candidate: `renderComponent(ast, {props: {...}}, options)`. To be designed in design.md.
4. **Emoji resolver default**: Use a small built-in shortcode map, or require user to supply? Recommendation: built-in default (~200 common shortcodes), overridable.
5. **Incremental DOM update**: Phase 2 feature, but the API surface should not preclude it. Need to confirm the chosen module shape supports adding it later without breaking change.
