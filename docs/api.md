# Wyreframe API Documentation

**Version**: 0.4.3
**Language**: ReScript (compiled to JavaScript/TypeScript)
**Last Updated**: 2025-12-27

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core API](#core-api)
- [Render Options](#render-options)
- [Scene Manager](#scene-manager)
- [Auto-Fix API](#auto-fix-api)
- [Error Handling](#error-handling)
- [TypeScript Integration](#typescript-integration)
- [ReScript API](#rescript-api)

---

## Overview

Wyreframe is a type-safe library for converting ASCII wireframes into working HTML/UI with scene management and interactions. The library implements a 3-stage parsing pipeline:

1. **Grid Scanner**: Converts ASCII text to a 2D character grid
2. **Shape Detector**: Identifies boxes, dividers, and nesting relationships
3. **Semantic Parser**: Recognizes UI elements and generates AST

### Key Features

- **Type Safety**: Built with ReScript, compiled to TypeScript-friendly JavaScript
- **Comprehensive Error Messages**: Natural language errors with code snippets and solutions
- **Extensible**: Plugin-based element parser system
- **Auto-Fix**: Automatically correct common wireframe formatting issues
- **Scene Management**: Multi-screen prototypes with navigation and transitions
- **Device Support**: Responsive previews for mobile, tablet, and desktop

---

## Installation

```bash
npm install wyreframe
```

---

## Quick Start

### Basic Usage

```typescript
import { createUI } from 'wyreframe';

const wireframe = `
@scene: login
@title: Login Screen
@device: mobile

+---------------------------+
|       'Welcome'           |
|                           |
|  #email                   |
|  #password                |
|                           |
|       [ Login ]           |
+---------------------------+

#email:
  placeholder: "Email"

#password:
  placeholder: "Password"

[Login]:
  variant: primary
  @click -> goto(dashboard, slide-left)
`;

const result = createUI(wireframe);

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
} else {
  console.error('Parsing errors:', result.errors);
}
```

---

## Core API

### `parse(text: string): ParseResult`

Parse mixed text containing wireframe and interactions.

**Parameters:**
- `text` (string): Text containing ASCII wireframe and/or interaction DSL

**Returns:**
```typescript
type ParseResult =
  | { success: true; ast: AST; warnings: ParseError[] }
  | { success: false; errors: ParseError[] };
```

**Example:**

```typescript
import { parse } from 'wyreframe';

const result = parse(wireframe);

if (result.success) {
  console.log('Parsed successfully');
  console.log('Scenes:', result.ast.scenes.length);
  console.log('Warnings:', result.warnings);
} else {
  console.error('Errors:', result.errors);
}
```

---

### `parseOrThrow(text: string): AST`

Parse text and throw on error. Use for simpler code when you expect parsing to succeed.

**Parameters:**
- `text` (string): Text containing ASCII wireframe and/or interaction DSL

**Returns:**
- `AST`: Parsed abstract syntax tree

**Throws:**
- `Error`: If parsing fails

**Example:**

```typescript
import { parseOrThrow } from 'wyreframe';

try {
  const ast = parseOrThrow(wireframe);
  console.log('Scenes:', ast.scenes.length);
} catch (error) {
  console.error('Parse failed:', error.message);
}
```

---

### `parseWireframe(wireframe: string): ParseResult`

Parse only the wireframe structure (no interactions).

**Parameters:**
- `wireframe` (string): ASCII wireframe text

**Returns:**
- `ParseResult`: Parse result with success flag

---

### `parseInteractions(dsl: string): InteractionResult`

Parse only the interaction DSL.

**Parameters:**
- `dsl` (string): Interaction DSL text

**Returns:**
```typescript
type InteractionResult =
  | { success: true; interactions: unknown[] }
  | { success: false; errors: ParseError[] };
```

---

### `render(ast: AST, options?: RenderOptions): RenderResult`

Render AST to DOM elements.

**Parameters:**
- `ast` (AST): Parsed AST from parse()
- `options` (RenderOptions, optional): Render configuration

**Returns:**
```typescript
interface RenderResult {
  root: HTMLElement;
  sceneManager: SceneManager;
}
```

**Important:** Pass `ast`, not the parse result!

**Example:**

```typescript
import { parse, render } from 'wyreframe';

const result = parse(wireframe);

if (result.success) {
  // Correct: pass result.ast
  const { root, sceneManager } = render(result.ast);

  // WRONG: render(result) - will throw error!

  document.getElementById('app').appendChild(root);
  sceneManager.goto('login');
}
```

---

### `createUI(text: string, options?: RenderOptions): CreateUIResult`

Parse and render in one step. **Recommended for most use cases.**

**Parameters:**
- `text` (string): Text containing ASCII wireframe and/or interaction DSL
- `options` (RenderOptions, optional): Render configuration

**Returns:**
```typescript
type CreateUIResult =
  | { success: true; root: HTMLElement; sceneManager: SceneManager; ast: AST; warnings: ParseError[] }
  | { success: false; errors: ParseError[] };
```

**Example:**

```typescript
import { createUI } from 'wyreframe';

const result = createUI(wireframe, {
  device: 'mobile',
  onSceneChange: (from, to) => console.log(`${from} -> ${to}`)
});

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
}
```

---

### `createUIOrThrow(text: string, options?: RenderOptions): RenderResult & { ast: AST }`

Parse and render, throwing on error.

**Parameters:**
- `text` (string): Text containing ASCII wireframe and/or interaction DSL
- `options` (RenderOptions, optional): Render configuration

**Returns:**
```typescript
interface {
  root: HTMLElement;
  sceneManager: SceneManager;
  ast: AST;
}
```

**Throws:**
- `Error`: If parsing fails

---

## Render Options

```typescript
interface RenderOptions {
  /** Additional CSS class for container */
  containerClass?: string;

  /** Inject default styles (default: true) */
  injectStyles?: boolean;

  /**
   * Override the device type for all scenes.
   * Overrides the @device directive in scene definitions.
   */
  device?: DeviceType;

  /**
   * Callback fired when navigating between scenes.
   * @param fromScene - Scene ID navigating from (undefined if initial)
   * @param toScene - Scene ID navigating to
   */
  onSceneChange?: (fromScene: string | undefined, toScene: string) => void;

  /**
   * Callback fired when a button or link without a navigation target is clicked.
   * Useful for handling dead-end interactions, showing modals, etc.
   * @param info - Information about the clicked element
   */
  onDeadEndClick?: (info: DeadEndClickInfo) => void;
}

type DeviceType =
  | 'desktop'      // 1440x900
  | 'laptop'       // 1280x800
  | 'tablet'       // 768x1024
  | 'tablet-landscape'  // 1024x768
  | 'mobile'       // 375x812
  | 'mobile-landscape'; // 812x375

interface DeadEndClickInfo {
  sceneId: string;
  elementId: string;
  elementText: string;
  elementType: 'button' | 'link';
}
```

**Example:**

```typescript
const result = createUI(wireframe, {
  containerClass: 'my-app',
  device: 'mobile',

  onSceneChange: (from, to) => {
    console.log(`Navigated: ${from ?? 'initial'} -> ${to}`);
    analytics.track('scene_view', { scene: to });
  },

  onDeadEndClick: (info) => {
    console.log(`Dead-end click: ${info.elementText}`);
    if (info.elementId === 'help') {
      showHelpModal();
    }
  }
});
```

---

## Scene Manager

The SceneManager provides programmatic control over scene navigation.

```typescript
interface SceneManager {
  /** Navigate to a scene by ID */
  goto(sceneId: string, transition?: TransitionType): void;

  /** Navigate back in history */
  back(): void;

  /** Navigate forward in history */
  forward(): void;

  /** Get the current scene ID */
  getCurrentScene(): string | undefined;

  /** Get all available scene IDs */
  getSceneIds(): string[];
}

type TransitionType = 'fade' | 'slide-left' | 'slide-right' | 'zoom';
```

**Example:**

```typescript
const { sceneManager } = result;

// Navigate to a scene
sceneManager.goto('dashboard');

// Navigate with transition
sceneManager.goto('settings', 'slide-left');

// Navigation history
sceneManager.back();
sceneManager.forward();

// Query state
console.log('Current:', sceneManager.getCurrentScene());
console.log('All scenes:', sceneManager.getSceneIds());
```

---

## Auto-Fix API

Wyreframe can automatically fix common wireframe formatting issues.

### `fix(text: string): FixResult`

Attempt to auto-fix errors and warnings in the wireframe text.

**Parameters:**
- `text` (string): The wireframe markdown text

**Returns:**
```typescript
type FixResult =
  | { success: true; text: string; fixed: FixedIssue[]; remaining: ParseError[] }
  | { success: false; errors: ParseError[] };

interface FixedIssue {
  original: ParseError;
  description: string;
  line: number;
  column: number;
}
```

**Fixable Issues:**
- `MisalignedPipe`: Adjusts pipe positions to correct columns
- `MisalignedClosingBorder`: Fixes closing border alignment
- `UnusualSpacing`: Replaces tabs with spaces
- `UnclosedBracket`: Adds missing closing brackets
- `MismatchedWidth`: Extends shorter borders to match

**Example:**

```typescript
import { fix, parse } from 'wyreframe';

const messyWireframe = `
+----------+
| Button  |
+---------+
`;

const result = fix(messyWireframe);

if (result.success) {
  console.log(`Fixed ${result.fixed.length} issues`);

  result.fixed.forEach(issue => {
    console.log(`- ${issue.description} at line ${issue.line}`);
  });

  if (result.remaining.length > 0) {
    console.warn('Manual fixes needed:', result.remaining);
  }

  // Use the fixed text
  const parsed = parse(result.text);
}
```

---

### `fixOnly(text: string): string`

Convenience function - fix and return just the fixed text.

**Parameters:**
- `text` (string): The wireframe markdown text

**Returns:**
- `string`: The fixed text (or original if no fixes applied)

**Example:**

```typescript
import { fixOnly, parse } from 'wyreframe';

const cleanText = fixOnly(rawWireframe);
const result = parse(cleanText);
```

---

## Error Handling

### Error Structure

```typescript
interface ParseError {
  message: string;
  line?: number;
  column?: number;
  source?: string;
}
```

### Error Codes

| Code | Severity | Description |
|------|----------|-------------|
| `UnclosedBox` | Error | Box missing closing border |
| `MismatchedWidth` | Error | Top and bottom edges have different widths |
| `MisalignedPipe` | Error | Vertical border not aligned |
| `OverlappingBoxes` | Error | Boxes overlap incorrectly |
| `InvalidElement` | Error | Unknown element syntax |
| `UnclosedBracket` | Error | Bracket not closed |
| `EmptyButton` | Error | Button has no text |
| `InvalidInteractionDSL` | Error | DSL parsing failed |
| `UnusualSpacing` | Warning | Tabs instead of spaces detected |
| `DeepNesting` | Warning | Nesting depth exceeds 4 levels |

### Handling Errors

```typescript
import { parse } from 'wyreframe';

const result = parse(wireframe);

if (!result.success) {
  result.errors.forEach(error => {
    console.error(`Error at line ${error.line}: ${error.message}`);
  });
} else if (result.warnings.length > 0) {
  result.warnings.forEach(warning => {
    console.warn(`Warning: ${warning.message}`);
  });
}
```

---

## TypeScript Integration

### Type Definitions

```typescript
import type {
  AST,
  Scene,
  Element,
  BoxElement,
  ButtonElement,
  InputElement,
  LinkElement,
  TextElement,
  CheckboxElement,
  DividerElement,
  RowElement,
  SectionElement,
  ParseError,
  ParseResult,
  RenderResult,
  RenderOptions,
  SceneManager,
  DeviceType,
  TransitionType,
  Alignment,
  ButtonVariant,
  Action,
  GotoAction,
  DeadEndClickInfo,
  OnSceneChangeCallback,
  OnDeadEndClickCallback,
  FixResult,
  FixedIssue,
} from 'wyreframe';
```

### Type Guards

```typescript
import type { Element } from 'wyreframe';

function isButton(element: Element): element is ButtonElement {
  return element.TAG === 'Button';
}

function isInput(element: Element): element is InputElement {
  return element.TAG === 'Input';
}

// Usage
function processElements(elements: Element[]) {
  elements.forEach(element => {
    switch (element.TAG) {
      case 'Button':
        console.log(`Button: ${element.text}`);
        break;
      case 'Input':
        console.log(`Input: ${element.id}`);
        break;
      case 'Link':
        console.log(`Link: ${element.text}`);
        break;
      case 'Text':
        console.log(`Text: ${element.content}`);
        break;
      case 'Box':
        console.log(`Box with ${element.children.length} children`);
        processElements(element.children);
        break;
    }
  });
}
```

---

## ReScript API

### Basic Usage

```rescript
open Renderer

let wireframe = `
@scene: login

+---------------------------+
|       'Login'             |
|  #email                   |
|       [ Submit ]          |
+---------------------------+
`

switch createUI(wireframe, None) {
| Ok({root, sceneManager, _}) =>
    sceneManager.goto("login")
| Error(errors) =>
    errors->Array.forEach(e => Console.error(e))
}
```

### With Options

```rescript
open Renderer

let options: renderOptions = {
  device: Some(#mobile),
  containerClass: Some("my-app"),
  injectStyles: Some(true),
  onSceneChange: Some((from, to) => {
    Console.log2("Scene change:", (from, to))
  }),
  onDeadEndClick: Some(info => {
    Console.log2("Dead-end click:", info.elementId)
  }),
}

switch createUI(wireframe, Some(options)) {
| Ok({root, sceneManager, ast}) =>
    Console.log2("Parsed scenes:", ast.scenes->Array.length)
    sceneManager.goto("login")
| Error(errors) =>
    Console.error(errors)
}
```

### Scene Manager in ReScript

```rescript
let {sceneManager} = result

// Navigate
sceneManager.goto("dashboard")

// With transition (if supported)
sceneManager.goto("settings")

// History
sceneManager.back()
sceneManager.forward()

// Query
switch sceneManager.getCurrentScene() {
| Some(scene) => Console.log2("Current:", scene)
| None => Console.log("No scene")
}

let scenes = sceneManager.getSceneIds()
Console.log2("All scenes:", scenes)
```

---

## API Reference Summary

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `parse` | `text: string` | `ParseResult` | Parse mixed content |
| `parseOrThrow` | `text: string` | `AST` | Parse or throw |
| `parseWireframe` | `wireframe: string` | `ParseResult` | Parse wireframe only |
| `parseInteractions` | `dsl: string` | `InteractionResult` | Parse interactions only |
| `render` | `ast: AST, options?: RenderOptions` | `RenderResult` | Render AST to DOM |
| `createUI` | `text: string, options?: RenderOptions` | `CreateUIResult` | Parse + render combined |
| `createUIOrThrow` | `text: string, options?: RenderOptions` | `RenderResult & { ast }` | Parse + render or throw |
| `fix` | `text: string` | `FixResult` | Auto-fix wireframe issues |
| `fixOnly` | `text: string` | `string` | Fix and return text only |
| `version` | - | `string` | Library version |
| `implementation` | - | `string` | Implementation type ("rescript") |

---

## See Also

- [Type Definitions](./types.md) - Complete type reference
- [Examples](./examples.md) - Comprehensive usage examples
- [Developer Guide](./developer-guide.md) - Extending the parser

---

## Support

- **Issues**: [GitHub Issues](https://github.com/wickedev/wyreframe/issues)
- **Repository**: [GitHub](https://github.com/wickedev/wyreframe)

---

**Version**: 0.4.3
**Last Updated**: 2025-12-27
**License**: GPL-3.0
