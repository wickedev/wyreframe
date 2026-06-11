# Wyreframe Examples

**Version**: 0.4.3
**Syntax**: v2.3 (`wyreframe/parser/v2`)
**Last Updated**: 2026-06-11

Examples use the **V2 parser**. For HTML rendering (currently V1-only), see [Legacy V1 Rendering Examples](#legacy-v1-rendering-examples).

## Table of Contents

- [Basic Examples](#basic-examples)
- [Element Examples](#element-examples)
- [Components and Props](#components-and-props)
- [Implicit Layout](#implicit-layout)
- [Multiple Blocks](#multiple-blocks)
- [Error Handling](#error-handling)
- [Parse Options](#parse-options)
- [Advanced Patterns](#advanced-patterns)
- [Real-World Examples](#real-world-examples)
- [Testing Examples](#testing-examples)
- [Legacy V1 Rendering Examples](#legacy-v1-rendering-examples)

---

## Basic Examples

### Simple Container

```javascript
import { parse } from 'wyreframe/parser/v2';

const result = parse(`
@scene: hello

+---------------------+
|  Hello, Wyreframe!  |
+---------------------+
`);

console.log(result.success);            // true
const scene = result.blocks[0];
console.log(scene.TAG);                 // 'SceneBlock'
console.log(scene._0.slug);             // 'hello'
console.log(scene._0.children[0].TAG);  // 'ContainerNode'
```

### Named Container

The text in the top border becomes the container's `name`:

```
@scene: profile

+--Header------------------+
|  "My Profile"            |
+--------------------------+
```

```javascript
const container = result.blocks[0]._0.children[0];
console.log(container._0.name);  // 'Header'
```

### Container with ID

```
@scene: form

+--#login-form-------------+
|  [__email__]             |
|  [ Submit ]              |
+--------------------------+
```

```javascript
console.log(container._0.id);  // 'login-form'
```

Or with a standalone ID line (Format 2):

```
+--------------------------+
| #login-form              |
|  [ Submit ]              |
+--------------------------+
```

### Nested Containers

```
@scene: layout

+--Outer----------------------------+
|  +--Sidebar--+  +--Content-----+  |
|  | < Home >  |  |  "Welcome"   |  |
|  | < About > |  |              |  |
|  +-----------+  +--------------+  |
+-----------------------------------+
```

The two inner containers start on the same row, so the outer container's `layout.direction` is `'Row'`.

---

## Element Examples

### Buttons

```
[ Login ]
[ Sign Up ]
```

```javascript
// { TAG: 'ButtonNode', _0: { id: 'login', text: 'Login', ... } }
// { TAG: 'ButtonNode', _0: { id: 'sign-up', text: 'Sign Up', ... } }
```

### Links

```
< Forgot password >
< Back to home >
```

```javascript
// { TAG: 'LinkNode', _0: { id: 'forgot-password', text: 'Forgot password', ... } }
```

### Inputs

```
[__email__]
[__password______________]
[____________]
```

```javascript
// { TAG: 'InputNode', _0: { placeholder: 'email', ... } }
// { TAG: 'InputNode', _0: { placeholder: 'password', ... } }
// { TAG: 'InputNode', _0: { placeholder: '', ... } }
```

### Select

```
[v: Choose a country]
```

```javascript
// { TAG: 'SelectNode', _0: { id: 'choose-a-country', placeholder: 'Choose a country', ... } }
```

### Checkboxes

```
[x] Remember me
[ ] Subscribe to newsletter
```

```javascript
// { TAG: 'CheckboxNode', _0: { checked: true,  label: 'Remember me', ... } }
// { TAG: 'CheckboxNode', _0: { checked: false, label: 'Subscribe to newsletter', ... } }
```

### Radios

Vertically consecutive radios (or radios in the same container) share a group:

```
(*) Credit card
( ) Bank transfer
( ) Crypto
```

```javascript
// All three RadioNodes get the same _0.group; only the first has selected: true
```

### Dividers

```
---
===
--- Section ---
=== Payment ===
---#section-1---
```

```javascript
// { TAG: 'DividerNode', _0: { style: 'Normal', ... } }
// { TAG: 'DividerNode', _0: { style: 'Bold', ... } }
// { TAG: 'DividerNode', _0: { style: 'Normal', label: 'Section', ... } }
// { TAG: 'DividerNode', _0: { style: 'Bold', label: 'Payment', ... } }
// { TAG: 'DividerNode', _0: { style: 'Normal', id: 'section-1', ... } }
```

### String Literals

Inner syntax is disabled inside strings:

```
"Click [ here ] for details"
"He said \"hello\""
```

```javascript
// { TAG: 'StringNode', _0: { content: 'Click [ here ] for details', multiline: false, ... } }
```

### Emoji Shortcodes

```
:check: Task complete
:warning: Low disk space
```

```javascript
// { TAG: 'EmojiNode', _0: { shortcode: 'check', emoji: '✔', ... } }
// followed by a TextNode for the rest of the line
```

---

## Components and Props

Source:

```
@component: user-card
@props: name, role?, avatar

+--------------------------+
|  ${avatar}               |
|  "Hello, ${name}!"       |
|  ${role:Member}          |
+--------------------------+
```

```javascript
const comp = result.blocks[0];
console.log(comp.TAG);       // 'ComponentBlock'
console.log(comp._0.props);
// [ { name: 'name', optional: false },
//   { name: 'role', optional: true },
//   { name: 'avatar', optional: false } ]
```

- `${name}` inside the string literal becomes a `PropRef` interpolation on the `StringNode`.
- `${role:Member}` produces `defaultValue: 'Member'` (colons are allowed inside the default).
- A `${prop}` in a `@scene` block emits a `PropOutsideComponent` warning and stays literal.
- A `${typo}` not declared in `@props` emits `UnknownPropReference`.

---

## Implicit Layout

```javascript
const result = parse(`
@scene: dialog

+--------------------------------+
|  "Delete this file?"           |
|                                |
|  [ Cancel ]      [ Confirm ]   |
+--------------------------------+
`);

const container = result.blocks[0]._0.children[0];
console.log(container._0.layout);
// {
//   direction: 'Mixed',
//   groups: [
//     { direction: 'Column', start: 0, end_: 1, startRow: ... },  // the string
//     { direction: 'Row',    start: 1, end_: 3, startRow: ... },  // the two buttons
//   ]
// }
```

Groups address children by **index range** — `children[start..end_)` — never by copying nodes.

---

## Multiple Blocks

One source can declare several scenes/components:

```javascript
const result = parse(`
@scene: login
+----------------+
| [ Sign In ]    |
+----------------+

@scene: dashboard
+----------------+
| "Welcome back" |
+----------------+

@component: footer
+----------------+
| "(c) 2026"     |
+----------------+
`);

console.log(result.blocks.length);  // 3
const scenes = result.blocks.filter(b => b.TAG === 'SceneBlock');
const components = result.blocks.filter(b => b.TAG === 'ComponentBlock');
```

Blocks cannot be nested — an `@scene:` inside a container body emits `NestedBlockDeclaration` and starts a new top-level block (recovery).

---

## Error Handling

### Collecting Errors

```javascript
const result = parse(`
@scene: broken

+----------------+
|  [ Unclosed    |
`);

console.log(result.success);  // false
for (const err of result.errors) {
  const { row, col } = err.location.start;
  console.error(`${err.code} @ ${row + 1}:${col + 1} — ${err.message}`);
}
// UnclosedContainer @ ... — Error: Unclosed container - missing bottom border
```

### Warnings with Rule IDs

```javascript
const result = parse(`
@scene: sloppy

+----------------+
|  [ OK ]         |
+-----------------+
`);

for (const w of result.warnings) {
  console.warn(w.message, w.ruleId);
  // e.g. 'Warning: ...' 'container.widthConsistency'
}
```

### Strict Mode

```javascript
const result = parse(source, { strict: true });
// Parsing halts at the first erroring block; every error has recoverable: false
if (!result.success) throw new Error(result.errors[0].message);
```

### Error Recovery Markers

After recovery the AST still exists — recovered regions appear as `ErrorNode`s, and containers that recovered internally are flagged:

```javascript
function hasRecovery(node) {
  return node.TAG === 'ContainerNode' && node._0.containsErrorRecovery;
}
```

---

## Parse Options

### Tuning Heuristics

```javascript
// Require pixel-perfect container walls (no tolerance)
const strictGrid = parse(source, {
  heuristics: { containerColumnTolerance: 0, containerWidthTolerance: 0 },
});

// Allow radios with one blank row between them to group together
const looseRadios = parse(source, {
  heuristics: { radioMaxBlankRows: 1 },
});
```

### Custom Emoji

```javascript
const result = parse(`
@scene: launch
:rocket: "Launching soon"
`, {
  emojiRegistry: { rocket: '🚀' },
});
```

### Tabs and Depth

```javascript
const result = parse(source, {
  tabSize: 2,    // tabs expand to 2 visual columns
  maxDepth: 4,   // nesting beyond 4 emits MaxDepthExceeded
});
```

---

## Advanced Patterns

### Traversing the AST

```javascript
function walkChildren(payload, visit, depth = 0) {
  for (const child of payload.children ?? []) {
    visit(child, depth);
    if (child._0.children) walkChildren(child._0, visit, depth + 1);
  }
}

const result = parse(source);
for (const block of result.blocks) {
  console.log(block.TAG, block._0.slug);
  walkChildren(block._0, (node, depth) =>
    console.log('  '.repeat(depth + 1) + node.TAG));
}
```

### Finding Elements by Type

```javascript
function findAll(payload, tag, out = []) {
  for (const child of payload.children ?? []) {
    if (child.TAG === tag) out.push(child);
    if (child._0.children) findAll(child._0, tag, out);
  }
  return out;
}

const buttons = result.blocks.flatMap(b => findAll(b._0, 'ButtonNode'));
buttons.forEach(b => console.log(b._0.id, b._0.text));
```

### Using Source Locations

Map AST nodes back to the original text (e.g. for editor tooling):

```javascript
function sourceSlice(source, node) {
  const { start, end_ } = node._0.location;
  return source.slice(start.offset, end_.offset);
}
```

---

## Real-World Examples

### Login Form

```
@scene: login
@title: Login
@device: mobile

+--#login-form-------------------+
|                                |
|         "Welcome Back"         |
|                                |
|  [__email_________________]    |
|  [__password______________]    |
|                                |
|  [x] Remember me               |
|                                |
|         [ Sign In ]            |
|                                |
|      < Forgot password? >      |
|      < Create account >        |
|                                |
+--------------------------------+
```

### Settings Page

```
@scene: settings
@title: Settings
@device: desktop

+--Settings----------------------------------+
|                                            |
|  === Account ===                           |
|  [__display-name__]                        |
|  [v: Language]                             |
|                                            |
|  === Notifications ===                     |
|  [x] :mail: Email notifications            |
|  [ ] :bell: Push notifications             |
|                                            |
|  === Theme ===                             |
|  (*) Light                                 |
|  ( ) Dark                                  |
|  ( ) System                                |
|                                            |
|  ---                                       |
|  [ Save Changes ]    [ Cancel ]            |
|                                            |
+--------------------------------------------+
```

### Reusable Component

```
@component: product-card
@props: title, price, badge?

+--#product-card-----------+
|  ${badge?}               |
|  "${title}"              |
|  "${price}"              |
|  [ Add to Cart ]         |
+--------------------------+
```

---

## Testing Examples

### Vitest (JavaScript)

```javascript
import { describe, it, expect } from 'vitest';
import { parse } from 'wyreframe/parser/v2';

describe('login scene', () => {
  it('parses inputs and button', () => {
    const result = parse(`
@scene: login
+----------------------+
|  [__email__]         |
|  [ Sign In ]         |
+----------------------+
`);
    expect(result.success).toBe(true);
    const children = result.blocks[0]._0.children[0]._0.children;
    expect(children[0].TAG).toBe('InputNode');
    expect(children[1].TAG).toBe('ButtonNode');
  });

  it('reports unclosed container', () => {
    const result = parse(`
@scene: broken
+----------------------+
|  text
`);
    expect(result.success).toBe(false);
    expect(result.errors.map(e => e.code)).toContain('UnclosedContainer');
  });
});
```

### rescript-vitest (ReScript)

```rescript
open Vitest

describe("V2Parser", () => {
  test("parses a scene", t => {
    let result = V2Parser.parse("@scene: home\n+--+\n|  |\n+--+", ())
    t->expect(result.success)->Expect.toBe(true)
  })
})
```

---

## Legacy V1 Rendering Examples

> Rendering, scene transitions, and the Interaction DSL run on the **V1 parser with V1 syntax** (`#id` inputs, `"text"` links, `'text'` emphasis). See [api.md → Legacy V1 API](api.md#legacy-v1-api).

```javascript
import { createUI } from 'wyreframe';

const app = `
@scene: login
@device: mobile

+---------------------------+
|         'Login'           |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|       [ Sign In ]         |
|    "Create Account"       |
+---------------------------+

@scene: signup
@device: mobile

+---------------------------+
|       'Sign Up'           |
|  +---------------------+  |
|  | #name               |  |
|  +---------------------+  |
|       [ Register ]        |
|    "Back to Login"        |
+---------------------------+

#email:
  placeholder: "Email"
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
  onSceneChange: (from, to) => console.log(`Scene: ${from} -> ${to}`),
});

if (result.success) {
  document.getElementById('app').appendChild(result.root);
  result.sceneManager.goto('login');
}
```

---

## See Also

- [Syntax v2.3 Reference](./syntax-v2.md)
- [API Reference](./api.md)
- [Type Definitions](./types.md)
- [Developer Guide](./developer-guide.md)
- [Live Demo](https://wyreframe.studio/)

---

**Version**: 0.4.3
**Last Updated**: 2026-06-11
**License**: GPL-3.0
