# Wyreframe V2 ASCII Printer Requirements Document

## Introduction

This document defines the requirements for the Wyreframe V2 ASCII Printer. The V2 ASCII Printer is the *reverse direction* of the V2 Parser — it converts a validated V2 AST back into ASCII wireframe text conforming to V2 syntax v2.3. Together, the Parser and Printer form a round-trip pair.

The primary consumers are:

1. **ML Parser self-improvement loop** (`ml-parser/self-improvement.md`) — cycle consistency check needs `AST → ASCII` to compare with the original input.
2. **Synthetic data generator** — start from a clean AST, print canonical ASCII, then perturb for training augmentation.
3. **Snapshot tests** — verify round-trip parsability of new V2 features.
4. **Code formatter** — canonicalize messy ASCII into the printer's deterministic output.

### Document Information

- **Version**: 0.1.0 (Draft)
- **Created**: 2026-06-12
- **Based on Spec**: Wyreframe Syntax v2.3, V2 AST in `src/parser/v2/types/V2Types.res`
- **Status**: Draft
- **Companion Specs**: `syntax-v2-parser` (parser side), `v2-renderer` (HTML side), `ml-parser/self-improvement.md` (primary consumer)

### Scope

The V2 ASCII Printer handles the following:

- All 15 node types of the V2 AST.
- 2D grid character layout: width/height inference, child positioning, alignment, distribution-to-spacing mapping.
- Canonical ASCII output that is parseable by the V2 Parser to a *semantically equivalent* AST.
- Configurable character set: pure ASCII (`+-|`) or Unicode box-drawing (`┌─│`).
- Configurable line endings (LF / CRLF).
- Configurable padding/spacing constants (within the V2 grammar's valid range).

The V2 ASCII Printer does NOT handle the following:

- ASCII parsing (covered by V2 Parser).
- HTML output (covered by `v2-renderer`).
- V1 AST input.
- Pixel-perfect reproduction of arbitrary input ASCII — the printer emits its *canonical* form, which may differ from the input in whitespace/alignment but is semantically equivalent.
- Color/styling — output is pure text.

---

## Requirements

### Requirement 1: V2 AST Input Acceptance

**User Story:** As a developer, I want the V2 ASCII Printer to accept any validated V2 AST so that I can roundtrip-test the parser and feed it into the ML self-improvement cycle.

#### Acceptance Criteria

1. WHEN the Printer receives a value of type `V2Types.astNode` rooted at `SceneNode` or `ComponentNode` THEN it SHALL produce a string output without runtime error.
2. WHEN the input contains any of the 15 documented node variants THEN the Printer SHALL emit syntax for that variant (see Requirements 3–7).
3. The Printer SHALL NOT mutate the input AST.

---

### Requirement 2: ASCII Grid Output

**User Story:** As a developer, I want the Printer's output to be a well-formed ASCII grid so that downstream consumers (parser, image renderer, diff tools) can process it without ambiguity.

#### Acceptance Criteria

1. The output SHALL be a single string with lines separated by the configured line ending (default `\n`).
2. Each line SHALL be a sequence of 7-bit ASCII characters by default, switching to Unicode box-drawing characters only when `charset = Unicode` option is set.
3. Lines MAY be space-padded on the right to a uniform width but SHALL NOT contain trailing whitespace beyond what is needed for grid alignment within a container.
4. The output SHALL NOT contain tab characters.
5. The final line SHALL end with the configured line ending (i.e. the string ends with `\n`).

---

### Requirement 3: Round-Trip Semantic Equivalence

**User Story:** As a developer, I want `V2Parser.parse(V2Printer.print(ast))` to produce an AST semantically equal to `ast` so that the round-trip property holds and the printer can be trusted as a canonical form.

#### Acceptance Criteria

1. WHEN the Printer prints an AST `A` to produce string `S` AND `S` is parsed by the V2 Parser to produce AST `A'` THEN `A` and `A'` SHALL be *semantically equal*.
2. Semantic equality is defined as:
   - Same node tree shape (same variant at every position).
   - Same metadata: slugs, IDs, text content, prop names, default values, alignment, distribution, direction, device, transition, etc.
   - **Source locations MAY differ** (the printer assigns new locations).
   - **`bounds` / position coordinates MAY differ** (the printer recomputes them based on output grid).
3. A test corpus of at least 100 representative ASTs SHALL be defined and 100% of them SHALL satisfy round-trip equality.
4. WHEN round-trip fails for any AST THEN the failure SHALL be reported with both the diff between `A` and `A'` and the produced string `S`.

---

### Requirement 4: Idempotent Print

**User Story:** As a developer, I want the Printer to be a *fixed-point* function in composition with the Parser so that re-printing already-canonical input produces byte-identical output.

#### Acceptance Criteria

1. WHEN the Printer prints AST `A` to produce string `S₁`, AND `S₁` is parsed to `A'`, AND `A'` is printed to produce `S₂` THEN `S₁` and `S₂` SHALL be byte-identical.
2. This idempotency SHALL hold for the entire round-trip corpus from Requirement 3.

---

### Requirement 5: Determinism

**User Story:** As a developer, I want the Printer to produce byte-identical output for the same input so that snapshot tests and cycle verification work reliably.

#### Acceptance Criteria

1. WHEN the Printer is called twice with `(ast, options)` THEN it SHALL produce byte-identical strings.
2. The Printer SHALL NOT depend on any non-deterministic source (timestamps, random IDs, environment variables, iteration order of non-ordered structures).
3. Child node printing order SHALL be document order from the AST.

---

### Requirement 6: Width/Height Inference

**User Story:** As a developer, I want the Printer to compute the grid dimensions of each node automatically so that I do not have to supply layout coordinates.

#### Acceptance Criteria

1. The Printer SHALL compute each node's grid width and height via a deterministic bottom-up pass.
2. The width of a leaf node (Text, String, Button, Input, etc.) SHALL be determined by its content length plus syntax-required decoration (e.g. `[Button]` has width `len("Button") + 2`).
3. The width of a Container SHALL be at least `max(child widths) + 2 (borders) + 2 (default padding)`, configurable via `containerPadding` option.
4. The height of a Container SHALL be at least `sum(child heights for column layout) + 2 (borders)` or `max(child heights for row layout) + 2`.
5. Specific width/height rules per node type SHALL be documented in `design.md §Width/Height Inference Table`.

---

### Requirement 7: Layout Distribution & Direction Mapping

**User Story:** As a developer, I want the Printer to lay out children inside containers according to the AST's `layoutInfo` so that the printed wireframe visually reflects the parsed layout.

#### Acceptance Criteria

1. WHEN a Container has `direction = Row` THEN children SHALL be placed on the same row(s), separated by spacing.
2. WHEN a Container has `direction = Column` THEN children SHALL be placed in successive rows.
3. WHEN a Container has `direction = Mixed` THEN child groups (from `layoutInfo.elementGroup`) SHALL be honored: each group is laid out per its own direction.
4. WHEN `distribution = Equal` THEN spacing between Row children SHALL be `space-evenly` equivalent on the ASCII grid (i.e. equal padding before, between, and after).
5. WHEN `distribution = SpaceBetween` THEN children SHALL be at extreme ends with even gaps between interior children.
6. WHEN `distribution = SpaceAround` THEN half-padding at edges, full padding between children.
7. WHEN `distribution = Start` THEN children clustered to the left with consistent gap.
8. WHEN `distribution = End` THEN children clustered to the right.
9. WHEN `distribution = Center_` THEN children grouped at center.
10. The exact pixel-grid algorithm for each distribution SHALL be documented in `design.md §Distribution Algorithm`.

---

### Requirement 8: Alignment Mapping

**User Story:** As a developer, I want `alignment` fields on Text/Button/Link to translate to grid positioning within the parent so that center/right-aligned text renders correctly.

#### Acceptance Criteria

1. WHEN a Text/Button/Link node has `alignment = Left` AND is inside a Column container THEN it SHALL be placed at the leftmost valid column (after parent's padding).
2. WHEN `alignment = Center` THEN the node SHALL be centered within its parent's interior width.
3. WHEN `alignment = Right` THEN the node SHALL be flush-right within its parent's interior.
4. Alignment is ignored when the parent direction is Row (distribution handles horizontal placement instead).

---

### Requirement 9: Character Set Selection

**User Story:** As a developer, I want to choose between pure ASCII borders and Unicode box-drawing characters so that the output suits the consumer's environment.

#### Acceptance Criteria

1. The Printer SHALL accept option `charset: "ascii" | "unicode"` (default `"ascii"`).
2. WHEN `charset = "ascii"` THEN borders SHALL use `+`, `-`, `|` per V2 syntax v2.3.
3. WHEN `charset = "unicode"` THEN borders SHALL use `┌`, `─`, `│`, `└`, `┘`, `┐`, `├`, `┤`, `┬`, `┴`, `┼`.
4. The chosen charset SHALL be applied consistently across the entire output; no mixing.
5. Both charsets SHALL satisfy the round-trip property (V2 Parser must accept both).

---

### Requirement 10: Line Endings & Trailing Whitespace

**User Story:** As a developer, I want configurable line endings and predictable whitespace so the output works across platforms and diff tools.

#### Acceptance Criteria

1. The Printer SHALL accept option `lineEnding: "lf" | "crlf"` (default `"lf"`).
2. The final character of output SHALL be the line ending.
3. Trailing whitespace within a line SHALL only exist when needed to right-pad to a container's interior width (i.e. to keep the right border vertical). The Printer MAY also support `trimTrailing: bool` option (default `false`) that strips this padding if the consumer accepts ragged-right output.
4. The Printer SHALL NOT emit blank lines between sibling nodes unless the AST explicitly requires them (e.g. layoutInfo gap).

---

### Requirement 11: Component & PropPlaceholder Rendering

**User Story:** As a developer, I want `@component` blocks and `PropPlaceholder` nodes to round-trip through the Printer correctly so that component definitions can be serialized.

#### Acceptance Criteria

1. WHEN a `ComponentNode` is printed THEN the output SHALL begin with `@component: <slug>` on its own line, followed by `@props: <prop list>` if props exist.
2. Prop list syntax SHALL match V2 syntax: comma-separated, with `?` suffix for optional, `= "value"` for defaults.
3. WHEN a `PropPlaceholderNode` is printed THEN the output SHALL use V2 syntax (`{{name}}` or per the canonical V2 placeholder syntax) verbatim. Default values SHALL be preserved in the placeholder syntax.
4. The Printer SHALL NOT substitute prop values when printing — that is the V2 Renderer's job. The Printer produces the *template* form.

---

### Requirement 12: Error Node Handling

**User Story:** As a developer, I want the Printer to handle Error nodes in the AST in a controlled way so that errored ASTs can still produce inspectable output.

#### Acceptance Criteria

1. The Printer SHALL accept option `errorHandling: "skip" | "render-comment" | "throw"` (default `"render-comment"`).
2. WHEN `errorHandling = "skip"` AND an `ErrorNode` is encountered THEN nothing SHALL be emitted at that position.
3. WHEN `errorHandling = "render-comment"` AND an `ErrorNode` is encountered THEN the Printer SHALL emit a comment-style marker that is *ignored by the V2 Parser* (V2 currently has no comment syntax; if introduced, this maps to that; otherwise, the marker is documented and accepted as "non-roundtrippable artifact" — see Open Questions).
4. WHEN `errorHandling = "throw"` THEN a typed exception SHALL be thrown.
5. `errorHandling != "skip"` configurations SHALL NOT claim to satisfy round-trip; round-trip is only guaranteed for *error-free* ASTs.

---

### Requirement 13: Source Location Regeneration

**User Story:** As a developer, I want each printed node to have a correct `sourceLocation` reflecting its position in the output string, so that printer-output can be parsed and used in editor integrations.

#### Acceptance Criteria

1. The Printer SHALL expose `printWithLocations(ast, options) -> (string, locationMap)` where `locationMap: Map<AstNodeKey, sourceLocation>` provides each input AST node's start/end position in the output.
2. The simpler `print(ast, options) -> string` SHALL be available for consumers that do not need location data.
3. When the printer output is parsed by V2 Parser, the resulting AST's `sourceLocation` fields SHALL match the `locationMap` returned by `printWithLocations` (within zero-based grid coordinate semantics).

---

### Requirement 14: Performance

**User Story:** As a developer, I want the Printer fast enough for use in the self-improvement loop's cycle check on every training pair.

#### Acceptance Criteria

1. The Printer SHALL complete printing an AST of 10,000 nodes in under 100ms on a current development machine.
2. The Printer SHALL be O(N) in the number of AST nodes for both width-inference and emit passes.
3. The bottom-up width pass SHALL not require backtracking; ambiguities (when child widths force parent re-layout) SHALL be resolved in a single second pass at most.

---

### Requirement 15: Output Width Bounds

**User Story:** As a developer, I want to optionally cap the output width so that wireframes fit terminal columns or PDF pages.

#### Acceptance Criteria

1. The Printer SHALL accept option `maxColumns: option<int>` (default `None`).
2. WHEN `maxColumns` is set AND a container's natural width exceeds the cap THEN the Printer SHALL log a warning AND emit anyway (i.e. wrapping is NOT performed automatically — that breaks V2 grammar). Wrapping is explicitly out of scope.
3. The warning SHALL include the overflowing node's location and the exceeded amount.

---

## Open Questions

1. **Comment syntax**: V2 currently has no comment syntax. `errorHandling = "render-comment"` thus has no clean target. Options: (a) add `#` line-comment syntax to V2 spec, (b) accept that error-render output is non-roundtrippable, (c) emit Errors as `String` literals with a sentinel prefix. Decision deferred to design.md but flagged as a syntax-level question for `syntax-v2` working group.

2. **Whitespace canonicalization**: The Printer chooses spacing constants (container padding = 1, inter-child gap for `Start` distribution = 1, etc.). Should these be fixed or configurable? Recommendation: fixed in v0.1 for predictability; expose options in v0.2 if requested.

3. **Distribution rounding**: For `Equal` distribution with odd remainders, where do the extra spaces go? Recommendation: distribute leftmost-first deterministically.

4. **Unicode width edge cases**: Some Unicode characters (CJK, emoji) take 2 cells in a monospace font. Should the Printer support `displayWidth` calculation? Recommendation: assume 1-char-per-cell in v0.1; document the limitation; revisit when emoji/CJK fixtures fail.

5. **Container minimum width**: What is the minimum width of an empty container? Recommendation: `+--+` (width 4) — bordering with single-cell interior is the smallest legal V2 container.

6. **Recovery from impossible layouts**: If a child is wider than allowed by alignment/distribution constraints, what happens? Recommendation: child width wins (container grows); never truncate.

7. **Should Printer expose intermediate "layout tree"?** Useful for debugging and editor integration. Recommendation: yes, as `printWithLayoutTree(ast, options) -> (string, layoutTree)` debug-only API.
