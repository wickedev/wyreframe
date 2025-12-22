# Wyreframe

> A library that converts ASCII wireframes into working HTML/UI

[![npm version](https://img.shields.io/npm/v/wyreframe.svg)](https://www.npmjs.com/package/wyreframe)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

```
+---------------------------+
|      'WYREFRAME'          |     Draw in ASCII
|  +---------------------+  |         ↓
|  | #email              |  |     Convert to HTML!
|  +---------------------+  |
|       [ Login ]           |
+---------------------------+
```

## Installation

```bash
npm install wyreframe
```

## Quick Start

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

## Syntax Summary

| Syntax | Description | Example |
|------|------|------|
| `+---+` | Box/Container | `<div>` |
| `[ Text ]` | Button | `<button>` |
| `#id` | Input field | `<input>` |
| `"text"` | Link | `<a>` |
| `'text'` | Emphasis text | Title, Heading |
| `[x]` / `[ ]` | Checkbox | `<input type="checkbox">` |
| `---` | Scene separator | Multi-scene |

## API

```javascript
import { parse, render, createUI, createUIOrThrow } from 'wyreframe';

// Parse only
const result = parse(text);

// Render only
const { root, sceneManager } = render(ast);

// Parse + Render (recommended)
const result = createUI(text);

// Throw on error
const { root, sceneManager } = createUIOrThrow(text);
```

### SceneManager

```javascript
sceneManager.goto('dashboard');           // Navigate to scene
sceneManager.getCurrentScene();           // Get current scene
sceneManager.getSceneIds();               // Get all scene IDs
```

## Interactions

```yaml
#email:
  placeholder: "Email"

[Login]:
  variant: primary
  @click -> goto(dashboard, slide-left)
```

**Transition effects:** `fade`, `slide-left`, `slide-right`, `zoom`

## Documentation

- [Parser Architecture](docs/PARSER_ARCHITECTURE.md)
- [Testing Guide](docs/TESTING.md)
- [Examples](examples/index.html)

## Development

```bash
npm install
npm run res:build    # ReScript build
npm run dev          # Dev server (http://localhost:3000/examples)
npm test             # Run tests
```

## License

MIT License
