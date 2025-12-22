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

### ReScript

```rescript
let ui = `
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
`

switch Renderer.createUI(ui, None) {
| Ok({root, sceneManager, _}) => {
    // Append root to DOM
    sceneManager.goto("login")
  }
| Error(errors) => Console.error(errors)
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

### JavaScript/TypeScript

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

### ReScript

```rescript
// Parse only
let result = Parser.parse(text)

// Render only
let {root, sceneManager} = Renderer.render(ast, None)

// Parse + Render (recommended)
let result = Renderer.createUI(text, None)

// Throw on error
let {root, sceneManager, ast} = Renderer.createUIOrThrow(text, None)
```

### SceneManager

```javascript
sceneManager.goto('dashboard');           // Navigate to scene
sceneManager.getCurrentScene();           // Get current scene
sceneManager.getSceneIds();               // Get all scene IDs
```

```rescript
sceneManager.goto("dashboard")            // Navigate to scene
sceneManager.getCurrentScene()            // Get current scene (option<string>)
sceneManager.getSceneIds()                // Get all scene IDs (array<string>)
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

- [API Reference](docs/api.md)
- [Developer Guide](docs/developer-guide.md)
- [Examples](docs/examples.md)
- [Testing Guide](docs/testing.md)
- [Live Demo](examples/index.html)

## Development

```bash
npm install
npm run res:build    # ReScript build
npm run dev          # Dev server (http://localhost:3000/examples)
npm test             # Run tests
```

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.
