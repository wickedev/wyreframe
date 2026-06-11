# Wyreframe

> A library that converts ASCII wireframes into working HTML/UI with scene management

[![npm version](https://img.shields.io/npm/v/wyreframe.svg)](https://www.npmjs.com/package/wyreframe)
[![npm downloads](https://img.shields.io/npm/dm/wyreframe.svg)](https://www.npmjs.com/package/wyreframe)
[![codecov](https://codecov.io/gh/wickedev/wyreframe/branch/main/graph/badge.svg)](https://codecov.io/gh/wickedev/wyreframe)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![ReScript](https://img.shields.io/badge/ReScript-12-e6484f.svg)](https://rescript-lang.org/)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green.svg)](https://nodejs.org/)

```
+---------------------------+
|        "WYREFRAME"        |     Draw in ASCII
|  [__email____________]    |         ↓
|  [__password_________]    |     Parse to AST!
|       [ Login ]           |
|     < Forgot password >   |
+---------------------------+
```

## Features

- **Syntax v2.3**: 9 core UI elements, string literals, emoji shortcodes, and component props
- **Grid-aware parsing**: 2D coordinate lexer understands ASCII-art alignment, Unicode wide characters, and tabs
- **Implicit layout inference**: Row/Column arrangement detected from element positions — no layout keywords
- **Error recovery**: Collects all errors/warnings with precise source locations instead of halting at the first problem
- **Tunable heuristics**: Every parser tolerance is named, documented, and overridable per parse
- **TypeScript/ReScript**: Full type safety with both language support

## Installation

```bash
npm install wyreframe
```

## Quick Start

```javascript
import { parse } from 'wyreframe/parser/v2';

const source = `
@scene: login
@title: Login Page
@device: mobile

+---------------------------+
|         "Login"           |
|  [__email____________]    |
|  [__password_________]    |
|  [x] Remember me          |
|       [ Sign In ]         |
|    < Create Account >     |
+---------------------------+
`;

const result = parse(source);

if (result.success) {
  console.log(result.blocks);   // all @scene/@component blocks
  console.log(result.ast);      // first block (SceneBlock)
} else {
  console.error(result.errors); // [{ code, message, location, recoverable }]
}
console.warn(result.warnings);  // non-fatal issues with ruleId traceability
```

## Syntax v2.3 Reference

See [docs/syntax-v2.md](docs/syntax-v2.md) for the full specification.

### Block Types

```yaml
@scene: login          # Scene declaration (slug required)
@title: Login Page     # Optional page title
@device: mobile        # mobile | tablet | desktop
@transition: fade      # Default transition effect
```

```yaml
@component: user-card  # Reusable component declaration
@props: name, avatar?  # Props (`?` suffix = optional)
```

### Core Elements

| Syntax | Element | Description |
|--------|---------|-------------|
| `+---+` ... `+---+` | Container | Box drawn with `+`, `-`, `\|` |
| `Plain text` | Text | Fallback; alignment inferred from position |
| `[ Text ]` | Button | Clickable button, id auto-slugged from text |
| `< Text >` | Link | Navigation link, id auto-slugged from text |
| `[__email__]` | Input | Text input, placeholder from inner text |
| `[v: Choose...]` | Select | Dropdown with placeholder |
| `[x]` / `[ ]` Label | Checkbox | Checked / unchecked (also `[X]`, `[v]`, `[V]`) |
| `(*)` / `( )` Label | Radio | Selected / unselected, auto-grouped |
| `---` / `===` | Divider | Normal / bold; supports `--- label ---` and `-#id-` |

### Strings, Emoji, and Props

| Syntax | Element | Description |
|--------|---------|-------------|
| `"text"` | String literal | Inner syntax disabled; supports `\"`, `\\`, `\$`, multiline |
| `:check:` | Emoji shortcode | 14 built-ins (`:check:`, `:star:`, `:user:`, ...), extensible |
| `${prop}` | Prop placeholder | Inside `@component` only; `${prop?}` optional, `${prop:default}` default value |

### Container IDs

```
+--#login-form--+        | Format 1: ID in the top border
|  [ Submit ]   |
+---------------+

+---------------+
| #login-form   |        | Format 2: standalone `| #id |` line
|  [ Submit ]   |
+---------------+
```

### Implicit Layout

Elements starting on the same visual row become a **Row**; different rows become a **Column**. No layout keywords needed:

```
+--------------------------------+
|  [ Cancel ]      [ Confirm ]   |   <- Row (same start row)
|  "Terms apply"                 |   <- Column relative to the row above
+--------------------------------+
```

## Parser API

```typescript
import {
  parse,            // (source, options?) => ParseResult
  parseWireframe,   // (source) => ParseResult (default options)
  version,          // "2.3.0"
  implementation,   // "rescript-v2"
  defaultOptions,
} from 'wyreframe/parser/v2';
```

### Parse Options

```typescript
const result = parse(source, {
  strict: false,      // true: halt on first error, all errors fatal
  tabSize: 4,         // tab expansion width for visual columns
  maxDepth: 10,       // max container nesting depth
  heuristics: {       // partial override; unset fields keep defaults
    containerColumnTolerance: 1,   // ± cols for wall alignment
    containerWidthTolerance: 2,    // ± cols for border width match
    radioHorizontalGap: 6,         // max gap for same-row radio grouping
    centerSymmetryThreshold: 0.15, // center-align detection
    rightAlignThreshold: 0.10,     // right-align detection
    dividerMinRun: 3,              // min dashes for a divider
  },
  emojiRegistry: {    // per-parse shortcode overrides
    rocket: '🚀',
  },
});
```

### Parse Result

```typescript
interface ParseResult {
  ast?: BlockNode;          // first block (legacy single-block accessor)
  blocks: BlockNode[];      // all @scene/@component blocks in order
  errors: ParseError[];     // { code, message, location, recoverable }
  warnings: ParseWarning[]; // { code, message, location, ruleId? }
  success: boolean;         // errors.length === 0
}
```

All source locations use 0-based `row` / `col` (visual columns, Unicode-aware) / `offset`. See [docs/types.md](docs/types.md) for the complete AST node types.

## Rendering (V1 — Legacy)

> **Note**: HTML rendering, scene transitions, and the Interaction DSL currently run on the **V1 parser and V1 syntax** (`#id` inputs, `"text"` links, `'text'` emphasis). V2 renderer integration is planned — see the [migration path](#v1v2-migration). V1 syntax differs from v2.3; see [docs/api.md](docs/api.md#legacy-v1-api) before mixing them.

```javascript
import { createUI } from 'wyreframe';

const ui = `
@scene: login

+---------------------------+
|       'WYREFRAME'         |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|       [ Login ]           |
+---------------------------+

#email:
  placeholder: "Enter your email"

[Login]:
  @click -> goto(dashboard, slide-left)
`;

const result = createUI(ui);
if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
}
```

The V1 surface (`parse`, `render`, `createUI`, `fix`, `fixOnly`, `SceneManager`, render options) is documented in [docs/api.md](docs/api.md).

## V1/V2 Migration

Both parsers ship side by side:

| Stage | Status |
|-------|--------|
| 1. V2 parser developed in isolation (`src/parser/v2/`) | ✅ Done |
| 2. Side-by-side testing | In progress |
| 3. Runtime feature flag for parser selection | Planned |
| 4. V2 default, V1 fallback | Planned |
| 5. V1 removal | Planned |

```javascript
import { parse as parseV1 } from 'wyreframe/parser';     // V1
import { parse as parseV2 } from 'wyreframe/parser/v2';  // V2 (typed)
```

## Documentation

- [Syntax v2.3 Reference](docs/syntax-v2.md)
- [API Reference](docs/api.md)
- [Type Definitions](docs/types.md)
- [Examples](docs/examples.md)
- [Developer Guide](docs/developer-guide.md)
- [Testing Guide](docs/testing.md)
- [Live Demo](https://wyreframe.studio/)

## Development

```bash
npm install
npm run res:build    # ReScript build
npm run ts:build     # TypeScript build
npm run build        # Full build (res + ts + typecheck)
npm run dev          # Dev server (http://localhost:3000/examples)
npm test             # Run tests
npm run test:watch   # Test watch mode
npm run test:coverage # Generate coverage report
```

## Architecture

The V2 parser pipeline:

1. **Grid-aware Lexer**: Tokenizes source with both 1D offsets and 2D `(row, col)` visual coordinates (Unicode wide chars = 2 cols, tab-expanded); a `GridIndex` enables random column lookups
2. **Block Parser**: Detects `@scene:` / `@component:` headers and parses header attributes
3. **Element Registry**: Walks 12 element parsers in priority order (String 115 → ... → Container 10 → Text 1); disambiguation lives in each parser's `canParse`
4. **Layout Inferrer**: Derives Row/Column groups from element start rows, addressing children by index range
5. **Validator**: Cross-cutting checks (duplicate IDs/props, unknown prop refs, radio group consistency)

The V1 renderer generates pure DOM elements with CSS-based scene visibility and transitions. See [docs/developer-guide.md](docs/developer-guide.md).

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.
