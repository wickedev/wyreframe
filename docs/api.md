# Wyreframe API Documentation

**Version**: 0.4.3
**Language**: ReScript (compiled to JavaScript/TypeScript)
**Last Updated**: 2026-06-11

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [V2 Parser API](#v2-parser-api)
  - [Quick Start](#quick-start)
  - [`parse`](#parsesource-string-options-parseoptions-parseresult)
  - [`parseWireframe`](#parsewireframesource-string-parseresult)
  - [Parse Options](#parse-options)
  - [Parse Result](#parse-result)
  - [Error Handling](#error-handling)
  - [Heuristics Overrides](#heuristics-overrides)
  - [Custom Emoji Shortcodes](#custom-emoji-shortcodes)
  - [TypeScript Integration](#typescript-integration)
  - [ReScript API](#rescript-api)
- [Legacy V1 API](#legacy-v1-api)
  - [Core Functions](#core-functions-v1)
  - [Render Options](#render-options-v1)
  - [Scene Manager](#scene-manager-v1)
  - [Auto-Fix API](#auto-fix-api-v1)

---

## Overview

Wyreframe converts ASCII wireframes into structured ASTs and (via the V1 renderer) into working HTML/UI.

Two parsers ship side by side:

| Parser | Import | Syntax | Status |
|--------|--------|--------|--------|
| **V2** | `wyreframe/parser/v2` | [Syntax v2.3](syntax-v2.md) | Current — parser only |
| V1 | `wyreframe` (main), `wyreframe/parser` | V1 syntax | Legacy — powers rendering + Interaction DSL |

> Rendering (`createUI`, `render`, `SceneManager`) currently consumes V1 ASTs only. Use the V2 parser for syntax v2.3 analysis, tooling, and code generation; use the V1 surface when you need live HTML output.

---

## Installation

```bash
npm install wyreframe
```

---

## V2 Parser API

### Quick Start

```typescript
import { parse } from 'wyreframe/parser/v2';

const result = parse(`
@scene: login
@device: mobile

+---------------------------+
|         "Login"           |
|  [__email____________]    |
|       [ Sign In ]         |
+---------------------------+
`);

if (result.success) {
  for (const block of result.blocks) {
    console.log(block.TAG, block._0.slug);
  }
}
```

### `parse(source: string, options?: ParseOptions): ParseResult`

Parse syntax v2.3 source into an AST.

**Parameters:**
- `source` (string): UTF-8 wireframe text (LF / CRLF / CR line endings supported)
- `options` (ParseOptions, optional): partial options; missing fields use defaults

**Returns:** [`ParseResult`](#parse-result). Never throws — all problems are reported via `errors` / `warnings`.

### `parseWireframe(source: string): ParseResult`

Convenience wrapper — `parse(source)` with default options.

### Module Exports

```typescript
import {
  parse,
  parseWireframe,
  version,        // "2.3.0" — spec version implemented
  implementation, // "rescript-v2"
  defaultOptions, // ParseOptions defaults
} from 'wyreframe/parser/v2';
```

### Parse Options

```typescript
interface ParseOptions {
  /** Promote recoverable errors to fatal and halt on the first error. Default: false */
  strict?: boolean;
  /** Tab expansion width for visual-column calculation. Default: 4 */
  tabSize?: number;
  /** Maximum container nesting depth. Default: 10 */
  maxDepth?: number;
  /** Partial heuristics override; unspecified fields keep defaults */
  heuristics?: HeuristicsPartial;
  /** Per-parse emoji shortcode overrides (merged over the 14 built-ins) */
  emojiRegistry?: Record<string, string>;
}
```

All fields are optional — `parse(src, { strict: true })` is valid; the parser defensively merges with `defaultOptions`.

### Parse Result

```typescript
interface ParseResult {
  /** First parsed block — legacy single-block accessor (=== blocks[0]) */
  ast?: BlockNode;
  /** All top-level @scene / @component blocks in declaration order */
  blocks: BlockNode[];
  errors: ParseError[];
  warnings: ParseWarning[];
  /** true iff errors.length === 0 */
  success: boolean;
}
```

`BlockNode` is a tagged union:

```typescript
type BlockNode =
  | { TAG: 'SceneBlock';     _0: SceneNode['_0'] }      // slug, title?, device?, transition?, children, layout
  | { TAG: 'ComponentBlock'; _0: ComponentNode['_0'] }; // slug, props, children, layout
```

See [types.md](types.md) for all 15 AST node types.

**Multi-block sources** — multiple `@scene:` / `@component:` declarations in one file each become an entry in `blocks`:

```typescript
const result = parse(multiSceneSource);
const scenes = result.blocks.filter(b => b.TAG === 'SceneBlock');
```

### Error Handling

```typescript
interface ParseError {
  code: ErrorCode;            // e.g. 'UnclosedContainer'
  message: string;            // human-readable, 1-based positions
  location: SourceLocation;   // 0-based { start, end_ } with row/col/offset
  recoverable: boolean;
}

interface ParseWarning {
  code: WarningCode;
  message: string;
  location: SourceLocation;
  /** Present on heuristic-driven warnings; links to the Heuristics Catalog */
  ruleId?: string;
}
```

By default the parser **recovers**: it marks the failed region, records the error, and continues. With `strict: true` parsing halts at the first erroring block and every error is reported as non-recoverable.

```typescript
const result = parse(source);

for (const err of result.errors) {
  console.error(
    `${err.code} at ${err.location.start.row + 1}:${err.location.start.col + 1} — ${err.message}`
  );
}

for (const warn of result.warnings) {
  console.warn(`${warn.message}${warn.ruleId ? ` [${warn.ruleId}]` : ''}`);
}
```

The full error/warning code catalog is in [syntax-v2.md → Errors and Warnings](syntax-v2.md#errors-and-warnings).

### Heuristics Overrides

Every parser tolerance is named and tunable. Pass a partial object — unset fields keep their defaults:

```typescript
const result = parse(source, {
  heuristics: {
    containerColumnTolerance: 0,  // require perfectly aligned walls
    radioHorizontalGap: 10,       // group radios up to 10 cols apart
  },
});
```

| Field | Default | Purpose |
|-------|---------|---------|
| `containerColumnTolerance` | 1 | ± cols for container wall/corner alignment |
| `containerWidthTolerance` | 2 | ± cols for top/bottom border width match |
| `radioHorizontalGap` | 6 | Max col gap for same-row radio grouping |
| `radioVerticalColumnTolerance` | 1 | ± cols for vertical radio grouping |
| `radioMaxBlankRows` | 0 | Blank rows allowed inside a vertical radio group |
| `centerSymmetryThreshold` | 0.15 | Symmetry ratio for center-align detection |
| `rightAlignThreshold` | 0.10 | Right-margin ratio for right-align detection |
| `dividerMinRun` | 3 | Minimum dash/equals run for a divider |
| `nearMissTokenDistance` | 1 | Token edit distance for near-miss warnings |

### Custom Emoji Shortcodes

```typescript
const result = parse(source, {
  emojiRegistry: {
    rocket: '🚀',
    check: '✅',   // overrides the built-in ✔ for this parse only
  },
});
```

Overrides are per-parse and never mutate global state. Lookups fall back to the 14 built-in shortcodes.

### TypeScript Integration

The V2 export ships hand-rolled declarations (`V2Parser.d.ts`). AST nodes are ReScript variants encoded as `{ TAG, _0 }` — narrow on `TAG`:

```typescript
import type { AstNode, ContainerNode } from 'wyreframe/parser/v2';

function walk(node: AstNode, depth = 0) {
  console.log('  '.repeat(depth) + node.TAG);
  switch (node.TAG) {
    case 'ContainerNode':
    case 'SceneNode':
    case 'ComponentNode':
      node._0.children.forEach(c => walk(c, depth + 1));
      break;
    case 'ButtonNode':
      console.log('  '.repeat(depth + 1) + node._0.text);
      break;
  }
}
```

Treat all AST fields as read-only — the parser never mutates records after construction.

### ReScript API

```rescript
let result = V2Parser.parse(source, ())

if result.success {
  result.blocks->Array.forEach(block =>
    switch block {
    | V2Types.SceneBlock({slug, children, _}) =>
      Console.log2("scene", (slug, Array.length(children)))
    | V2Types.ComponentBlock({slug, props, _}) =>
      Console.log2("component", (slug, Array.length(props)))
    }
  )
}

// With options
let result = V2Parser.parse(
  source,
  ~options={
    ...V2Parser.defaultOptions,
    strict: true,
    maxDepth: 5,
  },
  (),
)
```

---

## Legacy V1 API

> The V1 surface is the `wyreframe` main export. It parses **V1 syntax** (`#id` inputs, `"text"` links, `'text'` emphasis — different from v2.3) and is the only path that renders HTML, scene transitions, and the Interaction DSL. It will remain available until V2 renderer integration lands (migration phases 3–5).

### Core Functions (V1)

| Function | Signature | Description |
|----------|-----------|-------------|
| `parse` | `(text: string) => ParseResult` | Parse wireframe + Interaction DSL |
| `parseOrThrow` | `(text: string) => AST` | Parse or throw |
| `parseWireframe` | `(wireframe: string) => ParseResult` | Wireframe only |
| `parseInteractions` | `(dsl: string) => InteractionResult` | Interaction DSL only |
| `render` | `(ast: AST, options?: RenderOptions) => RenderResult` | Render AST to DOM (pass `ast`, not the parse result) |
| `createUI` | `(text: string, options?: RenderOptions) => CreateUIResult` | Parse + render combined (recommended) |
| `createUIOrThrow` | `(text, options?) => RenderResult & { ast }` | Parse + render or throw |
| `fix` | `(text: string) => FixResult` | Auto-fix formatting issues |
| `fixOnly` | `(text: string) => string` | Fix and return text only |
| `version` | `string` | Library version |
| `implementation` | `string` | `"rescript"` |

```typescript
import { createUI } from 'wyreframe';

const result = createUI(wireframe, { device: 'mobile' });

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
} else {
  console.error(result.errors);
}
```

### Render Options (V1)

```typescript
interface RenderOptions {
  containerClass?: string;   // extra CSS class on the root container
  injectStyles?: boolean;    // inject default styles (default: true)
  device?: DeviceType;       // override @device for all scenes
  onSceneChange?: (fromScene: string | undefined, toScene: string) => void;
  onDeadEndClick?: (info: DeadEndClickInfo) => void; // clicks with no navigation target
}

type DeviceType =
  | 'desktop'           // 1440x900
  | 'laptop'            // 1280x800
  | 'tablet'            // 768x1024
  | 'tablet-landscape'  // 1024x768
  | 'mobile'            // 375x812
  | 'mobile-landscape'; // 812x375

interface DeadEndClickInfo {
  sceneId: string;
  elementId: string;
  elementText: string;
  elementType: 'button' | 'link';
}
```

### Scene Manager (V1)

```typescript
interface SceneManager {
  goto(sceneId: string, transition?: TransitionType): void;
  back(): void;
  forward(): void;
  getCurrentScene(): string | undefined;
  getSceneIds(): string[];
}

type TransitionType = 'fade' | 'slide-left' | 'slide-right' | 'zoom';
```

### Auto-Fix API (V1)

```typescript
import { fix, fixOnly } from 'wyreframe';

const result = fix(messyWireframe);
if (result.success) {
  console.log(`Fixed ${result.fixed.length} issues`);   // FixedIssue[]
  console.warn('Manual fixes needed:', result.remaining);
  const parsed = parse(result.text);
}

const cleanText = fixOnly(rawWireframe);
```

**Fixable issues:** `MisalignedPipe`, `MisalignedClosingBorder`, `UnusualSpacing` (tabs → spaces), `UnclosedBracket`, `MismatchedWidth`.

### V1 Error Codes

| Code | Severity |
|------|----------|
| `UnclosedBox`, `MismatchedWidth`, `MisalignedPipe`, `OverlappingBoxes`, `InvalidElement`, `UnclosedBracket`, `EmptyButton`, `InvalidInteractionDSL` | Error |
| `UnusualSpacing`, `DeepNesting` | Warning |

### ReScript (V1)

```rescript
switch Renderer.createUI(wireframe, None) {
| Ok({root, sceneManager, _}) => sceneManager.goto("login")
| Error(errors) => Console.error(errors)
}
```

---

## See Also

- [Syntax v2.3 Reference](./syntax-v2.md) - Complete syntax specification
- [Type Definitions](./types.md) - Complete type reference
- [Examples](./examples.md) - Comprehensive usage examples
- [Developer Guide](./developer-guide.md) - Architecture and extending the parser

---

## Support

- **Issues**: [GitHub Issues](https://github.com/wickedev/wyreframe/issues)
- **Repository**: [GitHub](https://github.com/wickedev/wyreframe)

---

**Version**: 0.4.3
**Last Updated**: 2026-06-11
**License**: GPL-3.0
