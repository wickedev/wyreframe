# Wyreframe Developer Guide

**Version**: 0.4.3
**Date**: 2026-06-11
**Language**: ReScript 12 (+ @rescript/core)
**Target Audience**: Developers extending or maintaining the parser

This guide covers the **V2 parser** (`src/parser/v2/`, syntax v2.3). The V1 pipeline is summarized in [Legacy V1 Architecture](#legacy-v1-architecture).

---

## Table of Contents

1. [Introduction](#introduction)
2. [Repository Layout](#repository-layout)
3. [V2 Pipeline Overview](#v2-pipeline-overview)
4. [Grid-Aware Lexer](#grid-aware-lexer)
5. [Priority Dispatch and the Registry](#priority-dispatch-and-the-registry)
6. [Creating a Custom Element Parser](#creating-a-custom-element-parser)
7. [Heuristics](#heuristics)
8. [Error Recovery](#error-recovery)
9. [Layout Inference](#layout-inference)
10. [Validator](#validator)
11. [Mutability Policy](#mutability-policy)
12. [Emoji Registry](#emoji-registry)
13. [Testing](#testing)
14. [Performance Targets](#performance-targets)
15. [Legacy V1 Architecture](#legacy-v1-architecture)
16. [V1/V2 Migration Path](#v1v2-migration-path)

---

## Introduction

The V2 parser converts syntax v2.3 ASCII wireframes into an immutable AST. Its core design decisions:

1. **Grid-aware lexer** — tokens carry both a 1D offset and 2D `(row, col)` visual coordinates; a `GridIndex` enables the random column lookups ASCII-art parsing needs.
2. **Heuristics are first-class** — every tolerance lives in one `Heuristics` module; every heuristic-driven warning carries a `ruleId`.
3. **Single dispatch mechanism** — `V2ParserRegistry.tryParse` walks parsers in priority order; disambiguation lives inside each parser's `canParse`.
4. **No data duplication in layout** — `layoutInfo` addresses children by index range; nodes live exactly once in `parent.children`.
5. **Bounded error recovery** — each recoverable error has a named synchronization rule.
6. **Narrow mutability** — `ParseContext` and the `TokenStream` cursor are the only mutable surfaces.

### Prerequisites

- ReScript 12 / @rescript/core basics (variants, records, `option`, `result`)
- Vitest (tests are written with `rescript-vitest` and plain Vitest)

Authoritative design documents live in `.claude/specs/syntax-v2-parser/` (requirements, design, tasks).

---

## Repository Layout

```
src/parser/
├── Core/                    # Shared V1 types (Position, Bounds)
├── Semantic/                # V1 parser implementation
├── Detector/                # V1 element detection
├── Errors/                  # V1 error handling
├── Interactions/            # V1 Interaction DSL parsing
├── Fixer/                   # V1 auto-fix
├── Parser.res               # V1 entry point
├── ParserTypes.res          # V1 types
└── v2/                      # V2 parser (syntax v2.3)
    ├── V2Parser.res         # Entry point: parse / parseWireframe
    ├── V2Parser.d.ts        # Hand-rolled TS declarations
    ├── types/               # Token, V2Types (AST), V2Errors
    ├── lexer/               # Scanner, Lexer, TokenStream, GridIndex
    ├── parser/              # BlockParser, ParseContext, Priority
    ├── elements/            # 12 element parsers + V2ElementParser + V2ParserRegistry
    ├── layout/              # LayoutInferrer, RadioGrouper
    ├── validator/           # Validator (cross-cutting checks)
    ├── registry/            # EmojiRegistry
    ├── utils/               # UnicodeUtils, Heuristics, Slugify, EscapeUtils, PositionUtils
    └── __tests__/           # V2 test suite
```

---

## V2 Pipeline Overview

`V2Parser.parse` runs the following stages:

```
source string
   │
   ▼
Lexer.tokenize(~tabSize)        // Scanner + Lexer: grid-aware tokens
   │
   ▼
GridIndex.make(tokens)          // random (row, col) lookups
TokenStream.make(tokens)        // sequential cursor with save/restore
   │
   ▼
V2Parser block loop             // find next @scene:/@component: header
   │   └─ BlockParser.parseHeaderAttrs   // @title/@device/@transition/@props
   │   └─ BlockParser.parseContent       // body rows
   │        └─ V2ParserRegistry.tryParse // priority dispatch → element parsers
   │
   ▼
RadioGrouper.assignGroupsRecursive       // radio group assignment
LayoutInferrer.inferLayout               // Row/Column groups by start row
Validator.validate                       // cross-cutting checks
   │
   ▼
parseResult { ast, blocks, errors, warnings, success }
```

Multiple top-level blocks are parsed in a loop; `parseContent` stops at the next block boundary. In `strict` mode the first erroring block halts the loop and all errors are promoted to non-recoverable.

---

## Grid-Aware Lexer

### Tokens

Every token carries:

- `kind` (e.g. `Plus`, `Dash`, `Pipe`, `LBracket`, `Text`, `Whitespace`, `Newline`, `EOF`)
- `text` — the raw lexeme
- `position` — `{ row, col, offset }`, all 0-based

`col` is a **visual column**: East Asian Wide characters and emoji grapheme clusters count as 2, combining marks as 0, and tabs expand per `tabSize`. All column math routes through `utils/UnicodeUtils.res` — no other module counts columns directly. LF, CRLF, and standalone CR line endings are normalized by the Scanner.

### GridIndex

`GridIndex` maps `(row, col)` to tokens, enabling the random lookups Container parsing needs (e.g. "is there a `|` at column 42 of every body row?", "does the bottom border width match the top?").

### TokenStream

A mutable cursor over the token array with `peek` / `next` / `save` / `restore` / `skipToEndOfRow` / `rewindToRow`. Element parsers use save/restore for speculative look-ahead.

---

## Priority Dispatch and the Registry

`V2ParserRegistry` owns trial order. `tryParse` walks parsers in **descending priority** and dispatches the first whose `canParse` returns `true`:

| Priority | Parser | Module |
|----------|--------|--------|
| 115 | String | `StringParser` |
| 105 | PropPlaceholder | `PropPlaceholderParser` |
| 100 | Emoji | `EmojiParser` |
| 95 | Select | `SelectParser` |
| 90 | Input | `V2InputParser` |
| 85 | Radio | `RadioParser` |
| 80 | Checkbox | `V2CheckboxParser` |
| 70 | Button | `V2ButtonParser` |
| 60 | Link | `V2LinkParser` |
| 40–50 | Divider (all forms) | `DividerParser` |
| 10 | Container | `ContainerParser` |
| 1 | Text (fallback) | `V2TextParser` |

Two contracts keep this simple:

1. **`canParse` is a read-only probe.** It must not advance the stream (the registry defensively restores the cursor either way).
2. **Disambiguation lives in each parser**, not in the registry. The bracket family (`[ ]`) resolves as Select > Input > Checkbox > Button purely through each parser's own `canParse` logic; the numeric gaps exist for debuggability, not tie-breaking.

A `parse` returning `None` also restores the cursor, letting lower-priority parsers try.

---

## Creating a Custom Element Parser

The parser interface (`elements/V2ElementParser.res`):

```rescript
type t = {
  elementType: V2Types.nodeType,
  priority: int,
  canParse: TokenStream.t => bool,
  parse: (ParseContext.t, TokenStream.t) => option<V2Types.astNode>,
}
```

Example — a `~~~` "wave divider":

```rescript
// WaveDividerParser.res
let canParse = (stream: TokenStream.t): bool => {
  // Probe only — registry restores the cursor afterwards
  let tok = TokenStream.peek(stream)
  tok.kind == Tilde  // simplified
}

let parse = (ctx: ParseContext.t, stream: TokenStream.t): option<V2Types.astNode> => {
  let start = TokenStream.position(stream)
  // ...consume tokens, or return None to let lower priorities try...
  Some(V2Types.DividerNode({
    location: {start, end_: TokenStream.position(stream)},
    style: V2Types.Normal,
    id: None,
    label: None,
  }))
}

let make = (): V2ElementParser.t =>
  V2ElementParser.make(
    ~elementType=V2Types.Divider,
    ~priority=42, // between Divider (40) and Divider ID (45)
    ~canParse,
    ~parse,
  )
```

Register it (see `V2Parser.makeRegistry` for the built-in registration order):

```rescript
let reg = V2ParserRegistry.make()
// ...register built-ins...
V2ParserRegistry.register(reg, WaveDividerParser.make())   // sorted by priority automatically
V2ParserRegistry.unregister(reg, V2Types.Divider)          // remove by element type
```

Guidelines:

- Report problems through `ParseContext.addError` / `addWarning` — don't throw.
- Heuristic-driven warnings must carry a `ruleId` (add the rule to `Heuristics.Rule`).
- Keep recovery row-bounded where possible (see [Error Recovery](#error-recovery)).
- Add boundary tests for any new threshold (just-inside / exact / just-outside).

---

## Heuristics

All tolerances live in `utils/Heuristics.res`:

```rescript
let default: t = {
  containerColumnTolerance: 1,
  containerWidthTolerance: 2,
  radioHorizontalGap: 6,
  radioVerticalColumnTolerance: 1,
  radioMaxBlankRows: 0,
  centerSymmetryThreshold: 0.15,
  rightAlignThreshold: 0.10,
  dividerMinRun: 3,
  nearMissTokenDistance: 1,
}
```

- User overrides arrive as `Heuristics.partial` (all-optional); `applyPartial` merges them over `default`.
- Stable rule IDs live in `Heuristics.Rule` (e.g. `container.wallAlignment`, `radioGrouping.vertical`, `text.center`, `nearMissPatterns`, `errorRecovery.containerSync`). Heuristic warnings reference these so users can trace *why* a tolerance fired.
- Changing a default requires updating the golden test fixtures in the same change (REQ-23.5).

---

## Error Recovery

Default mode is recovering: errors are recorded, an `ErrorNode` (or recovery flag) marks the region, and parsing continues. Named synchronization rules:

| Error | Sync rule |
|-------|-----------|
| `UnclosedInput` | Row-bounded — recovery never crosses the row |
| `UnclosedString` | Bounded at EOF/block boundary |
| `UnclosedContainer` | `errorRecovery.containerSync` — body rows are not leaked as normal siblings |
| `NestedBlockDeclaration` | Rewind to the nested header row; reparse as a new top-level block (pipes treated as wall noise, bounded by the outer container's bottom border) |
| `MaxDepthExceeded` | Offending container parses as empty, `containsErrorRecovery: true`, siblings continue |

`strict: true` flips the contract: first error halts parsing and all errors report `recoverable: false`.

---

## Layout Inference

`layout/LayoutInferrer.res` derives arrangement from element start rows:

- Same start row → `Row` group; consecutive different rows → `Column` group.
- A container's start row is its top-border row.
- Groups are `{ direction, start, end_, startRow }` — index ranges into `parent.children`. **Never duplicate child nodes.**
- Spacing affects only the optional `distribution` field, never direction.

`layout/RadioGrouper.res` runs before layout inference and assigns radio `group` names using the radio heuristics (vertical runs, same-row proximity, same container).

---

## Validator

`validator/Validator.res` runs once per block after parsing and owns **cross-cutting** checks only (per-element checks belong in element parsers):

- `DuplicatePropName` — duplicate `@props` entries (last wins)
- `DuplicateContainerId` — same `#id` on two containers
- `UnknownPropReference` — `${name}` not declared in `@props`
- `MultipleRadiosSelected` — more than one `(*)` in one group

---

## Mutability Policy

Only two surfaces are mutable:

1. **`ParseContext`** — error/warning accumulators, recovery bookkeeping (e.g. `pendingNestedBlockRow`).
2. **`TokenStream` cursor** — advanced by `next`, checkpointed with `save`/`restore`.

Everything else — tokens, the `GridIndex`, and all AST records — is immutable after construction. JS-facing entry points defensively normalize partial options (`V2Parser.normalizeOptions`) so `undefined` fields from JavaScript callers can't crash ReScript code.

---

## Emoji Registry

`registry/EmojiRegistry.res` maps shortcodes to emoji (14 built-ins).

```rescript
EmojiRegistry.register("rocket", "🚀")  // global registration
EmojiRegistry.reset()                    // restore pristine defaults
```

Per-parse overrides (`parseOptions.emojiRegistry`) are consulted first and **never mutate global state** — `lookupWithOverride` falls back to the module registry. Defaults are rebuilt per `reset()` call so a polluted dict can never become the new baseline.

---

## Testing

```bash
npm test              # full suite (V1 + V2)
npm run test:watch
npm run test:coverage
```

- V2 tests live in `src/parser/v2/__tests__/` (ReScript, `rescript-vitest`), including `Regressions*_test.res` suites accumulated from automated review rounds.
- TypeScript-facing behavior (package exports, `.d.ts` correctness) is covered by `*.test.ts` files.
- Heuristic thresholds require **boundary fixtures**: just-inside, exact, and just-outside the threshold (REQ-23.4).
- Build with `npm run build` (ReScript → TypeScript → typecheck) before running tests on parser changes.

See [testing.md](testing.md) for conventions.

---

## Performance Targets

Per REQ-19, on the reference platform (Apple Silicon or ≥2.5 GHz x86-64, ≥8 GB RAM, Node ≥20, single-threaded):

| Input | Target (best-of-5 wall time) |
|-------|------------------------------|
| ≤ 100 lines | < 50ms |
| ≤ 1000 lines | < 500ms |
| Memory | peak `heapUsed` delta ≤ 10× input bytes |

If a CI machine can't meet the baseline, adjust the threshold in `vitest.config` with a comment linking to the requirement — never silently relax it.

---

## Legacy V1 Architecture

The V1 parser (`src/parser/`, main `wyreframe` export) uses a 3-stage pipeline:

1. **Grid Scanner** — ASCII text → 2D character grid
2. **Shape Detector** — box tracing, nesting/hierarchy construction
3. **Semantic Parser** — pluggable element parsers → V1 AST

V1 additionally owns everything V2 does not yet cover:

- **Renderer** (`src/renderer/`) — AST → DOM with CSS scene transitions
- **Interaction DSL** (`Interactions/`) — `@click -> goto(...)` etc.
- **Auto-Fix** (`Fixer/`) — formatting auto-correction (`fix`, `fixOnly`)

V1 element parsers register through the V1 registry in `Semantic/`; the V1 extension workflow mirrors the V2 one but uses grid positions instead of token streams. V1 code is in maintenance mode — prefer building new features against V2.

---

## V1/V2 Migration Path

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | V2 parser developed in isolation (`src/parser/v2/`) | ✅ Done |
| 2 | Side-by-side testing — both parsers, same input, compare | In progress |
| 3 | Runtime feature flag selects V1 or V2 | Planned |
| 4 | V2 default, V1 fallback | Planned |
| 5 | V1 deprecation and removal | Planned |

AST conversion helpers (`v2ToV1` / `v1ToV2`) may be provided for gradual migration; until then the two ASTs are independent types.

---

## Getting Help

- [Syntax v2.3 Reference](./syntax-v2.md)
- [API Reference](./api.md)
- [Type Definitions](./types.md)
- Design documents: `.claude/specs/syntax-v2-parser/{requirements,design,tasks}.md`
- **Issues**: [GitHub Issues](https://github.com/wickedev/wyreframe/issues)

---

**Version**: 0.4.3
**Last Updated**: 2026-06-11
**License**: GPL-3.0
