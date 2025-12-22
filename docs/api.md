# Wyreframe Parser API Documentation

**Version**: 0.1.0
**Language**: ReScript (compiled to JavaScript/TypeScript)
**Last Updated**: 2025-12-22

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core API](#core-api)
- [Parser Configuration](#parser-configuration)
- [Error Handling](#error-handling)
- [Advanced Usage](#advanced-usage)
- [TypeScript Integration](#typescript-integration)

---

## Overview

The Wyreframe Parser is a type-safe, 3-stage parser for converting ASCII wireframes into structured Abstract Syntax Trees (AST). The parser implements a systematic pipeline:

1. **Grid Scanner**: Converts ASCII text to a 2D character grid
2. **Shape Detector**: Identifies boxes, dividers, and nesting relationships
3. **Semantic Parser**: Recognizes UI elements and generates AST

### Key Features

- **Type Safety**: Built with ReScript, compiled to TypeScript-friendly JavaScript
- **Comprehensive Error Messages**: Natural language errors with code snippets and solutions
- **Extensible**: Plugin-based element parser system
- **Performance**: O(n) complexity, handles large wireframes efficiently
- **Backward Compatible**: Drop-in replacement for legacy parser

---

## Installation

```bash
npm install wyreframe-parser
# or
yarn add wyreframe-parser
```

---

## Quick Start

### Basic Usage

```typescript
import { parse } from 'wyreframe-parser';

const wireframe = `
@scene: login
@title: Login Screen

+---------------------------+
|      * Welcome            |
|                           |
|  #email                   |
|  #password                |
|                           |
|     [ Login ]             |
+---------------------------+
`;

// Parse wireframe only (no interactions)
const result = parse(wireframe);

if (result.TAG === 'Ok') {
  const ast = result._0;
  console.log('Parsed successfully:', ast);
  console.log('Number of scenes:', ast.scenes.length);
} else {
  const errors = result._0;
  console.error('Parsing errors:', errors);
}
```

### With Interactions (Mixed Content)

The parser intelligently extracts wireframe and interaction content from mixed text:

```typescript
import { parse } from 'wyreframe-parser';

const mixedContent = `
@scene: login

+---------------------------+
|     [ Login ]             |
+---------------------------+

[Login]:
  variant: primary
  @click -> goto(dashboard, slide-left)
`;

const result = parse(mixedContent);
```

---

## Core API

### `parse(text: string): Result<AST, ParseError[]>`

Main parsing function that processes mixed text containing wireframe and/or interactions.

The parser automatically extracts:
- ASCII wireframe structure (boxes with `+---+`, `| |`, etc.)
- Interaction DSL (`#id:`, `[Button]:`, `"Link":` with properties)
- Ignores markdown, comments, or other noise

**Parameters:**

- `text` (string, required): Mixed text containing wireframe and/or interactions

**Returns:**

- `Result<AST, ParseError[]>`: Either success with AST or errors array

**Example:**

```typescript
import { parse } from 'wyreframe-parser';

const wireframe = `
+--------+
| Button |
+--------+
`;

const result = parse(wireframe);

if (result.TAG === 'Ok') {
  // Success case
  const ast = result._0;
  processAST(ast);
} else {
  // Error case
  const errors = result._0;
  errors.forEach(error => {
    console.error(formatError(error));
  });
}
```

---

### `parseWireframe(wireframe: string): Result<AST, ParseError[]>`

Parse only the wireframe portion, ignoring interactions.

**Parameters:**

- `wireframe` (string): ASCII wireframe text

**Returns:**

- `Result<AST, ParseError[]>`: Either success with AST or errors array

**Example:**

```typescript
import { parseWireframe } from 'wyreframe-parser';

const ast = parseWireframe(`
@scene: home

+---------------------------+
|      * Homepage           |
+---------------------------+
`);
```

---

### `parseInteractions(dsl: string): Result<SceneInteractions[], ParseError[]>`

Parse only the interaction DSL, returning structured interaction data.

**Parameters:**

- `dsl` (string): Interaction DSL text

**Returns:**

- `Result<SceneInteractions[], ParseError[]>`: Either success with interactions or errors

**Example:**

```typescript
import { parseInteractions } from 'wyreframe-parser';

const interactions = `
@scene: login

#email:
  placeholder: "Enter your email"
  @change -> validate(email)

[ Login ]:
  variant: primary
  @click -> goto(dashboard)
`;

const result = parseInteractions(interactions);

if (result.TAG === 'Ok') {
  const sceneInteractions = result._0;
  sceneInteractions.forEach(scene => {
    console.log(`Scene: ${scene.sceneId}`);
    scene.interactions.forEach(interaction => {
      console.log(`  Element: ${interaction.elementId}`);
    });
  });
}
```

---

### `mergeInteractions(ast: AST, interactions: SceneInteractions[]): AST`

Merge parsed interactions into an AST, attaching properties and actions to elements.

**Parameters:**

- `ast` (AST): Parsed wireframe AST
- `interactions` (SceneInteractions[]): Parsed interactions

**Returns:**

- `AST`: New AST with interactions merged

**Example:**

```typescript
import { parseWireframe, parseInteractions, mergeInteractions } from 'wyreframe-parser';

const wireframeResult = parseWireframe(wireframeText);
const interactionsResult = parseInteractions(interactionText);

if (wireframeResult.TAG === 'Ok' && interactionsResult.TAG === 'Ok') {
  const mergedAST = mergeInteractions(
    wireframeResult._0,
    interactionsResult._0
  );

  // AST now contains elements with attached interactions
  console.log(mergedAST);
}
```

---

## Parser Configuration

### Custom Element Parsers

The parser supports custom element types through the plugin system.

```typescript
import { ParserRegistry, ElementParser } from 'wyreframe-parser';

// Define a custom element parser
const customParser: ElementParser = {
  priority: 95,
  canParse: (content: string) => {
    return /^\$\w+$/.test(content.trim());
  },
  parse: (content: string, position: Position, bounds: Bounds) => {
    const match = content.match(/^\$(\w+)$/);
    if (match) {
      return {
        TAG: 'Custom',
        id: match[1],
        position: position,
      };
    }
    return null;
  }
};

// Create a registry with custom parser
const registry = ParserRegistry.make();
registry.register(customParser);

// Use custom registry in parsing
// (Note: This requires access to lower-level API)
```

---

## Error Handling

### Error Structure

All parsing errors follow a consistent structure:

```typescript
interface ParseError {
  code: ErrorCode;
  severity: 'Error' | 'Warning';
  context: ErrorContext;
}

interface ErrorContext {
  codeSnippet?: string;
  linesBefore: number;
  linesAfter: number;
}
```

### Error Codes

| Code | Severity | Description |
|------|----------|-------------|
| `UncloseBox` | Error | Box missing closing border |
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
import { parse, formatError } from 'wyreframe-parser';

const result = parse(wireframe);

if (result.TAG === 'Error') {
  const errors = result._0;

  // Separate errors and warnings
  const criticalErrors = errors.filter(e => e.severity === 'Error');
  const warnings = errors.filter(e => e.severity === 'Warning');

  if (criticalErrors.length > 0) {
    console.error('Critical errors found:');
    criticalErrors.forEach(error => {
      console.error(formatError(error));
    });
  }

  if (warnings.length > 0) {
    console.warn('Warnings:');
    warnings.forEach(warning => {
      console.warn(formatError(warning));
    });
  }
}
```

### Error Messages

Error messages include:

1. **Title**: Brief description of the error
2. **Message**: Detailed explanation with position information
3. **Code Snippet**: Surrounding lines with visual indicator
4. **Solution**: Actionable steps to fix the error

**Example Error Output:**

```
❌ Box is not closed

Box opened at row 5, column 1 but never closed on the right side.

   4 │ +--Login--+
 → 5 │ |  #email |
      │          ^
   6 │ +----------

💡 Solution: Add the closing border with matching width using '+' corners and '-' edges.
```

---

## Advanced Usage

### Streaming Parsing (Large Wireframes)

For very large wireframes, consider processing in chunks:

```typescript
import { parse } from 'wyreframe-parser';

async function parseInChunks(wireframeText: string) {
  // Split by scene separators
  const scenes = wireframeText.split(/\n---\n/);

  const results = [];

  for (const sceneText of scenes) {
    const result = parse(sceneText);

    if (result.TAG === 'Ok') {
      results.push(result._0);
    } else {
      console.error('Scene parsing failed:', result._0);
    }

    // Allow event loop to breathe
    await new Promise(resolve => setTimeout(resolve, 0));
  }

  return results;
}
```

### Performance Monitoring

```typescript
import { parse } from 'wyreframe-parser';

function parseWithMetrics(wireframe: string) {
  const startTime = performance.now();
  const startMemory = performance.memory?.usedJSHeapSize || 0;

  const result = parse(wireframe);

  const endTime = performance.now();
  const endMemory = performance.memory?.usedJSHeapSize || 0;

  const metrics = {
    duration: endTime - startTime,
    memoryDelta: endMemory - startMemory,
    lineCount: wireframe.split('\n').length,
  };

  console.log('Parsing metrics:', metrics);

  return { result, metrics };
}
```

### Validation Only

To check wireframe syntax without generating AST:

```typescript
import { parse } from 'wyreframe-parser';

function validateWireframe(wireframe: string): boolean {
  const result = parse(wireframe);

  if (result.TAG === 'Error') {
    const criticalErrors = result._0.filter(e => e.severity === 'Error');
    return criticalErrors.length === 0;
  }

  return true;
}
```

---

## TypeScript Integration

### Type Definitions

The parser exports comprehensive TypeScript definitions:

```typescript
import type {
  AST,
  Scene,
  Element,
  Position,
  Bounds,
  Alignment,
  ParseError,
  ErrorCode,
  SceneInteractions,
  Interaction,
  InteractionAction,
} from 'wyreframe-parser';

// Use types in your application
function processScene(scene: Scene) {
  console.log(`Processing scene: ${scene.id}`);

  scene.elements.forEach((element: Element) => {
    if (element.TAG === 'Button') {
      console.log(`Button: ${element.text}`);
    } else if (element.TAG === 'Input') {
      console.log(`Input: ${element.id}`);
    }
  });
}
```

### Type Guards

```typescript
import type { Element } from 'wyreframe-parser';

function isButton(element: Element): element is Extract<Element, { TAG: 'Button' }> {
  return element.TAG === 'Button';
}

function isInput(element: Element): element is Extract<Element, { TAG: 'Input' }> {
  return element.TAG === 'Input';
}

// Usage
function processElements(elements: Element[]) {
  elements.forEach(element => {
    if (isButton(element)) {
      // TypeScript knows element is Button here
      console.log(element.text);
    } else if (isInput(element)) {
      // TypeScript knows element is Input here
      console.log(element.id);
    }
  });
}
```

### Generic Utilities

```typescript
import type { AST, Element } from 'wyreframe-parser';

// Find all elements of a specific type
function findElementsByType<T extends Element['TAG']>(
  ast: AST,
  type: T
): Extract<Element, { TAG: T }>[] {
  const results: Extract<Element, { TAG: T }>[] = [];

  ast.scenes.forEach(scene => {
    scene.elements.forEach(element => {
      if (element.TAG === type) {
        results.push(element as Extract<Element, { TAG: T }>);
      }
    });
  });

  return results;
}

// Usage
const allButtons = findElementsByType(ast, 'Button');
const allInputs = findElementsByType(ast, 'Input');
```

---

## Best Practices

### 1. Always Handle Errors

```typescript
// ✅ Good
const result = parse(wireframe);
if (result.TAG === 'Ok') {
  processAST(result._0);
} else {
  handleErrors(result._0);
}

// ❌ Bad
const result = parse(wireframe);
const ast = result._0; // May be errors!
```

### 2. Validate Input Before Parsing

```typescript
function parseWithValidation(wireframe: string) {
  // Check for empty input
  if (!wireframe || wireframe.trim().length === 0) {
    throw new Error('Wireframe cannot be empty');
  }

  // Check for reasonable size
  const lines = wireframe.split('\n');
  if (lines.length > 10000) {
    console.warn('Very large wireframe detected, may impact performance');
  }

  return parse(wireframe);
}
```

### 3. Use Type Guards for Element Processing

```typescript
function renderElement(element: Element) {
  switch (element.TAG) {
    case 'Button':
      return renderButton(element);
    case 'Input':
      return renderInput(element);
    case 'Link':
      return renderLink(element);
    case 'Text':
      return renderText(element);
    // ... handle all cases
    default:
      // TypeScript ensures exhaustiveness
      const _exhaustive: never = element;
      throw new Error('Unhandled element type');
  }
}
```

### 4. Cache Parsed Results

```typescript
const parseCache = new Map<string, AST>();

function cachedParse(wireframe: string): AST {
  const cacheKey = wireframe; // Or use hash for large inputs

  if (parseCache.has(cacheKey)) {
    return parseCache.get(cacheKey)!;
  }

  const result = parse(wireframe);

  if (result.TAG === 'Ok') {
    parseCache.set(cacheKey, result._0);
    return result._0;
  } else {
    throw new Error('Parse failed: ' + result._0.map(formatError).join('\n'));
  }
}
```

---

## API Reference Summary

| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `parse` | `text: string` | `Result<AST, ParseError[]>` | Main parsing function (mixed content) |
| `parseWireframe` | `wireframe: string` | `Result<AST, ParseError[]>` | Parse wireframe only |
| `parseInteractions` | `dsl: string` | `Result<SceneInteractions[], ParseError[]>` | Parse interactions only |
| `mergeInteractions` | `ast: AST, interactions: SceneInteractions[]` | `AST` | Merge interactions into AST |
| `version` | - | `string` | Parser version (`"0.1.0"`) |
| `implementation` | - | `string` | Implementation type (`"rescript"`) |

---

## See Also

- [Type Definitions](./types.md) - Complete type reference
- [Examples](./examples.md) - Comprehensive usage examples
- [Developer Guide](./developer-guide.md) - Extending the parser

---

## Support

- **Issues**: [GitHub Issues](https://github.com/anthropics/wyreframe/issues)

---

**Version**: 0.1.0
**Last Updated**: 2025-12-22
**License**: MIT
