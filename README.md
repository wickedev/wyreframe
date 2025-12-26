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
|      'WYREFRAME'          |     Draw in ASCII
|  +---------------------+  |         ↓
|  | #email              |  |     Convert to HTML!
|  +---------------------+  |
|       [ Login ]           |
+---------------------------+
```

## Features

- **ASCII to HTML**: Convert simple ASCII art into interactive UI elements
- **Scene Management**: Multi-screen prototypes with transitions (fade, slide, zoom)
- **Interaction DSL**: Define button clicks, navigation, and form validation
- **Device Preview**: Responsive previews for mobile, tablet, and desktop
- **Auto-Fix**: Automatically correct common wireframe formatting issues
- **TypeScript/ReScript**: Full type safety with both language support

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

## Syntax Reference

### UI Elements

| Syntax | Description | HTML Output |
|--------|-------------|-------------|
| `+---+` | Box/Container | `<div>` |
| `[ Text ]` | Button | `<button>` |
| `#id` | Input field | `<input>` |
| `"text"` | Link | `<a>` |
| `'text'` | Emphasis text | Title, Heading |
| `[x]` / `[ ]` | Checkbox | `<input type="checkbox">` |
| `---` | Divider | `<hr>` |

### Scene Directives

```yaml
@scene: sceneId        # Scene identifier (required)
@title: Page Title     # Optional page title
@device: mobile        # Device type for sizing
@transition: fade      # Default transition effect
```

### Device Types

| Device | Dimensions | Description |
|--------|------------|-------------|
| `desktop` | 1440x900 | Desktop monitor |
| `laptop` | 1280x800 | Laptop screen |
| `tablet` | 768x1024 | Tablet portrait |
| `tablet-landscape` | 1024x768 | Tablet landscape |
| `mobile` | 375x812 | iPhone X ratio |
| `mobile-landscape` | 812x375 | Mobile landscape |

### Interactions

```yaml
#email:
  placeholder: "Email"

[Login]:
  variant: primary
  @click -> goto(dashboard, slide-left)

"Forgot Password":
  @click -> goto(reset)
```

**Actions:**

| Action | Description | Example |
|--------|-------------|---------|
| `goto(scene, transition?)` | Navigate to scene | `@click -> goto(home, fade)` |
| `back()` | Navigate back | `@click -> back()` |
| `forward()` | Navigate forward | `@click -> forward()` |
| `validate(fields)` | Validate inputs | `@submit -> validate(email, password)` |
| `call(fn, args)` | Custom function | `@click -> call(submit, form)` |

**Transitions:** `fade`, `slide-left`, `slide-right`, `zoom`

**Variants:** `primary`, `secondary`, `ghost`

## API

### JavaScript/TypeScript

```javascript
import {
  parse,
  parseOrThrow,
  render,
  createUI,
  createUIOrThrow,
  fix,
  fixOnly
} from 'wyreframe';

// Parse only - returns { success, ast, warnings } or { success: false, errors }
const parseResult = parse(text);

// Parse and throw on error
const ast = parseOrThrow(text);

// Render AST to DOM (pass ast, not parseResult!)
if (parseResult.success) {
  const { root, sceneManager } = render(parseResult.ast, options);
}

// Parse + Render combined (recommended)
const result = createUI(text, options);

// Parse + Render, throw on error
const { root, sceneManager } = createUIOrThrow(text, options);

// Auto-fix wireframe formatting issues
const fixResult = fix(text);
if (fixResult.success) {
  console.log('Fixed:', fixResult.fixed.length, 'issues');
  const cleanText = fixResult.text;
}

// Fix and return text only
const fixedText = fixOnly(text);
```

### Render Options

```typescript
const options = {
  // Additional CSS class for container
  containerClass: 'my-app',

  // Inject default styles (default: true)
  injectStyles: true,

  // Override device type for all scenes
  device: 'mobile',

  // Scene change callback
  onSceneChange: (fromScene, toScene) => {
    console.log(`Navigated from ${fromScene} to ${toScene}`);
  },

  // Dead-end click callback (buttons/links without navigation)
  onDeadEndClick: (info) => {
    console.log(`Clicked: ${info.elementText} in scene ${info.sceneId}`);
    // Show modal, custom logic, etc.
  }
};

const result = createUI(text, options);
```

### SceneManager

```javascript
const { sceneManager } = result;

sceneManager.goto('dashboard');        // Navigate to scene
sceneManager.goto('home', 'fade');     // Navigate with transition
sceneManager.back();                   // Go back in history
sceneManager.forward();                // Go forward in history
sceneManager.getCurrentScene();        // Get current scene ID
sceneManager.getSceneIds();            // Get all scene IDs
```

### ReScript

```rescript
// Parse + Render
switch Renderer.createUI(ui, None) {
| Ok({root, sceneManager, _}) =>
    sceneManager.goto("login")
| Error(errors) => Console.error(errors)
}

// With options
let options = {
  device: Some(#mobile),
  onSceneChange: Some((from, to) => Console.log2(from, to)),
  onDeadEndClick: None,
  containerClass: None,
  injectStyles: None,
}
switch Renderer.createUI(ui, Some(options)) {
| Ok({root, sceneManager, _}) => ...
| Error(errors) => ...
}
```

## Auto-Fix

Wyreframe can automatically fix common formatting issues:

```javascript
import { fix, fixOnly } from 'wyreframe';

const messyWireframe = `
+----------+
| Button  |    <- Misaligned pipe
+---------+    <- Width mismatch
`;

const result = fix(messyWireframe);
if (result.success) {
  console.log('Fixed issues:', result.fixed);
  console.log('Remaining issues:', result.remaining);
  console.log('Clean wireframe:', result.text);
}

// Or just get the fixed text
const cleanText = fixOnly(messyWireframe);
```

**Fixable Issues:**
- Misaligned pipes (|)
- Mismatched border widths
- Tabs instead of spaces
- Unclosed brackets

## Multi-Scene Example

```javascript
const app = `
@scene: login
@device: mobile

+---------------------------+
|         'Login'           |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|  +---------------------+  |
|  | #password           |  |
|  +---------------------+  |
|       [ Sign In ]         |
|                           |
|    "Create Account"       |
+---------------------------+

---

@scene: signup
@device: mobile

+---------------------------+
|       'Sign Up'           |
|  +---------------------+  |
|  | #name               |  |
|  +---------------------+  |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|       [ Register ]        |
|                           |
|    "Back to Login"        |
+---------------------------+

#email:
  placeholder: "Email"
#password:
  placeholder: "Password"
#name:
  placeholder: "Full Name"

[Sign In]:
  variant: primary
  @click -> goto(signup, slide-left)

"Create Account":
  @click -> goto(signup, slide-left)

[Register]:
  variant: primary
  @click -> goto(login, slide-right)

"Back to Login":
  @click -> goto(login, slide-right)
`;

const result = createUI(app, {
  onSceneChange: (from, to) => {
    console.log(`Scene: ${from} -> ${to}`);
  }
});

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
}
```

## Documentation

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
npm run build        # Full build
npm run dev          # Dev server (http://localhost:3000/examples)
npm test             # Run tests
npm run test:watch   # Test watch mode
npm run test:coverage # Generate coverage report
```

## Architecture

Wyreframe uses a 3-stage parsing pipeline:

1. **Grid Scanner**: Converts ASCII text to 2D character grid
2. **Shape Detector**: Identifies boxes, nesting, and hierarchy
3. **Semantic Parser**: Recognizes UI elements via pluggable parsers

The renderer generates pure DOM elements with CSS-based scene visibility and transitions.

## License

GPL-3.0 License - see [LICENSE](LICENSE) for details.
