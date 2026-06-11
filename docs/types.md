# Wyreframe Type Reference

**Version**: 0.4.3
**Language**: ReScript (compiled to JavaScript/TypeScript)
**Last Updated**: 2026-06-11

This reference covers the **V2 parser types** (`wyreframe/parser/v2`, declared in `src/parser/v2/V2Parser.d.ts`). Legacy V1 types are summarized [at the end](#legacy-v1-types).

## Table of Contents

- [Encoding Conventions](#encoding-conventions)
- [Positions and Locations](#positions-and-locations)
- [Enumerations](#enumerations)
- [Layout Types](#layout-types)
- [AST Node Types](#ast-node-types)
- [Error and Warning Types](#error-and-warning-types)
- [Options Types](#options-types)
- [Result Type](#result-type)
- [Legacy V1 Types](#legacy-v1-types)

---

## Encoding Conventions

V2 AST values are ReScript variants exposed to JavaScript as tagged objects:

```typescript
{ TAG: 'ButtonNode', _0: { location, id, text } }
```

- Narrow unions on the `TAG` field; the payload is always `_0`.
- Some field names carry a trailing underscore to avoid ReScript keywords: `end_` (location end), `Center_` (distribution).
- All AST records are **immutable** — the parser never mutates them after construction; treat them as read-only.
- All positions are **0-based**. Columns are *visual columns* (Unicode wide chars = 2, tabs expanded by `tabSize`).

---

## Positions and Locations

### Position

```typescript
interface Position {
  row: number;     // 0-based line index
  col: number;     // 0-based visual column (Unicode + tab-aware)
  offset: number;  // 0-based offset into the source
}
```

### SourceLocation

```typescript
interface SourceLocation {
  start: Position;
  end_: Position;   // exclusive
}
```

Every AST node, error, and warning carries a `SourceLocation`.

### Bounds

Pixel-free rectangle of a container in grid coordinates:

```typescript
interface Bounds {
  x: number;       // left col
  y: number;       // top row
  width: number;
  height: number;
}
```

---

## Enumerations

```typescript
type DeviceType      = 'Mobile' | 'Tablet' | 'Desktop';
type Alignment       = 'Left' | 'Center' | 'Right';
type DividerStyle    = 'Normal' | 'Bold';
type LayoutDirection = 'Row' | 'Column' | 'Mixed';
type Distribution    = 'Equal' | 'SpaceBetween' | 'SpaceAround' | 'Start' | 'End' | 'Center_';
```

---

## Layout Types

Layout never duplicates nodes — groups address children **by index range** into the parent's `children` array (single source of truth).

### ElementGroup

```typescript
interface ElementGroup {
  direction: LayoutDirection;
  start: number;     // inclusive index into parent.children
  end_: number;      // exclusive index
  startRow: number;  // visual row the group starts on
}
```

### LayoutInfo

```typescript
interface LayoutInfo {
  direction: LayoutDirection;   // overall direction (Mixed if groups differ)
  groups: ElementGroup[];
  distribution?: Distribution;  // optional spacing hint
}
```

Present on `SceneNode`, `ComponentNode`, and `ContainerNode`.

---

## AST Node Types

### AstNode (union)

```typescript
type AstNode =
  | SceneNode | ComponentNode | ContainerNode
  | TextNode | ButtonNode | LinkNode | InputNode | SelectNode
  | CheckboxNode | RadioNode | DividerNode
  | StringNode | EmojiNode | PropPlaceholderNode
  | ErrorNode;
```

### BlockNode (root union)

A parse result's roots — each top-level `@scene:` / `@component:`:

```typescript
type BlockNode =
  | { TAG: 'SceneBlock';     _0: SceneNode['_0'] }
  | { TAG: 'ComponentBlock'; _0: ComponentNode['_0'] };
```

### SceneNode

```typescript
{
  TAG: 'SceneNode',
  _0: {
    location: SourceLocation;
    slug: string;            // from @scene: <slug>
    title?: string;          // from @title:
    device?: DeviceType;     // from @device:
    transition?: string;     // from @transition:
    children: AstNode[];
    layout: LayoutInfo;
  }
}
```

### ComponentNode

```typescript
{
  TAG: 'ComponentNode',
  _0: {
    location: SourceLocation;
    slug: string;            // from @component: <slug>
    props: PropDefinition[]; // from @props:
    children: AstNode[];
    layout: LayoutInfo;
  }
}

interface PropDefinition {
  name: string;
  optional: boolean;       // true for `name?`
  defaultValue?: string;
}
```

### ContainerNode

```typescript
{
  TAG: 'ContainerNode',
  _0: {
    location: SourceLocation;
    id?: string;                    // from +--#id--+ or | #id |
    name?: string;                  // from +--name--+
    children: AstNode[];
    layout: LayoutInfo;
    bounds: Bounds;                 // grid rectangle of the box
    containsErrorRecovery: boolean; // true if recovery occurred inside
  }
}
```

### Leaf Elements

```typescript
// Plain text (fallback element)
{ TAG: 'TextNode',     _0: { location, content: string, align: Alignment } }

// [ Label ]
{ TAG: 'ButtonNode',   _0: { location, id: string, text: string } }   // id auto-slugged

// < Label >
{ TAG: 'LinkNode',     _0: { location, id: string, text: string } }   // id auto-slugged

// [__placeholder__]
{ TAG: 'InputNode',    _0: { location, placeholder: string } }

// [v: placeholder]
{ TAG: 'SelectNode',   _0: { location, id: string, placeholder: string } }

// [x] Label / [ ] Label
{ TAG: 'CheckboxNode', _0: { location, checked: boolean, label: string } }

// (*) Label / ( ) Label
{ TAG: 'RadioNode',    _0: { location, selected: boolean, label: string, group?: string } }

// --- / === / --- label --- / -#id-
{ TAG: 'DividerNode',  _0: { location, style: DividerStyle, id?: string, label?: string } }
```

Radio `group` is assigned automatically by the grouping heuristics (vertical run, same-row, same-container).

### StringNode

`"text"` literal with interpolation parts:

```typescript
{
  TAG: 'StringNode',
  _0: {
    location: SourceLocation;
    content: string;                       // resolved text content
    interpolations: InterpolationContent[];
    multiline: boolean;
  }
}

type InterpolationContent =
  | { TAG: 'Literal';  _0: string }
  | { TAG: 'PropRef';  _0: PropPlaceholderNode['_0'] }
  | { TAG: 'EmojiRef'; _0: EmojiNode['_0'] };
```

### EmojiNode

```typescript
{ TAG: 'EmojiNode', _0: { location, shortcode: string, emoji: string } }
```

### PropPlaceholderNode

```typescript
{
  TAG: 'PropPlaceholderNode',
  _0: {
    location: SourceLocation;
    name: string;
    required: boolean;       // false for ${name?} and ${name:default}
    defaultValue?: string;   // from ${name:default}
  }
}
```

### ErrorNode

Inserted during error recovery where an element failed to parse:

```typescript
{ TAG: 'ErrorNode', _0: { location, message: string, recoveredContent?: string } }
```

---

## Error and Warning Types

### ErrorCode

```typescript
type ErrorCode =
  | 'InvalidIdFormat'
  | 'MultipleIdDeclarations'
  | 'UnclosedInput'
  | 'UnclosedString'
  | 'UnclosedContainer'
  | 'MissingBlockDeclaration'
  | 'NestedBlockDeclaration'
  | 'MaxDepthExceeded';
```

### WarningCode

Plain-string codes for parameterless warnings; `{ TAG, _0 }` variants for codes carrying a payload:

```typescript
type WarningCode =
  | 'PropOutsideComponent'
  | 'MixedDividerLabelId'
  | 'MissingCheckboxLabel'
  | 'MissingRadioLabel'
  | 'MisalignedContainerCorner'
  | 'MisalignedContainerWall'
  | 'InconsistentContainerWidth'
  | 'RadioGroupAmbiguous'
  | 'LooksLikeButton' | 'LooksLikeInput' | 'LooksLikeCheckbox' | 'LooksLikeRadio'
  | { TAG: 'UnknownEmoji';          _0: string }   // shortcode name
  | { TAG: 'DuplicatePropName';     _0: string }
  | { TAG: 'DuplicateContainerId';  _0: string }
  | { TAG: 'UnknownPropReference';  _0: string }
  | { TAG: 'MultipleRadiosSelected'; _0: string }; // group name
```

### ParseError / ParseWarning

```typescript
interface ParseError {
  code: ErrorCode;
  message: string;
  location: SourceLocation;
  recoverable: boolean;     // false in strict mode or for fatal errors
}

interface ParseWarning {
  code: WarningCode;
  message: string;
  location: SourceLocation;
  ruleId?: string;          // heuristic-driven warnings only, e.g. 'container.wallAlignment'
}
```

---

## Options Types

### ParseOptions

```typescript
interface ParseOptions {
  strict?: boolean;                       // default false
  tabSize?: number;                       // default 4
  maxDepth?: number;                      // default 10
  heuristics?: HeuristicsPartial;
  emojiRegistry?: Record<string, string>; // shortcode -> emoji
}
```

### HeuristicsPartial

```typescript
interface HeuristicsPartial {
  containerColumnTolerance?: number;      // default 1
  containerWidthTolerance?: number;       // default 2
  radioHorizontalGap?: number;            // default 6
  radioVerticalColumnTolerance?: number;  // default 1
  radioMaxBlankRows?: number;             // default 0
  centerSymmetryThreshold?: number;       // default 0.15
  rightAlignThreshold?: number;           // default 0.10
  dividerMinRun?: number;                 // default 3
  nearMissTokenDistance?: number;         // default 1
}
```

---

## Result Type

```typescript
interface ParseResult {
  ast?: BlockNode;          // first block (=== blocks[0]); absent when blocks is empty
  blocks: BlockNode[];      // all top-level blocks in declaration order
  errors: ParseError[];
  warnings: ParseWarning[];
  success: boolean;         // errors.length === 0
}
```

---

## Type Narrowing Example

```typescript
import { parse, type AstNode } from 'wyreframe/parser/v2';

function collectInputs(node: AstNode, out: string[] = []): string[] {
  switch (node.TAG) {
    case 'InputNode':
      out.push(node._0.placeholder);
      break;
    case 'SceneNode':
    case 'ComponentNode':
    case 'ContainerNode':
      node._0.children.forEach(c => collectInputs(c, out));
      break;
  }
  return out;
}
```

---

## Legacy V1 Types

> Exported from the `wyreframe` main package. These describe the V1 parser/renderer surface (V1 syntax) and will be removed when V1 is retired.

| Category | Types |
|----------|-------|
| Core | `Position` (row/col only), `Bounds` (top/left/bottom/right), `Alignment` |
| Grid | `CellChar`, `Grid` |
| Elements | `Element`, `BoxElement`, `ButtonElement`, `InputElement`, `LinkElement`, `CheckboxElement`, `TextElement`, `DividerElement`, `RowElement`, `SectionElement` |
| Scenes | `Scene`, `AST` |
| Device | `DeviceType` (6 values incl. `laptop`, `*-landscape`), `DeviceDimensions`, `parseDeviceType` |
| Interactions | `InteractionVariant`, `InteractionAction`, `GotoAction`, `BackAction`, `ForwardAction`, `ValidateAction`, `CallAction`, `Interaction`, `SceneInteractions` |
| Errors | `ParseError` (message/line/column), `ErrorCode`, per-code error types, `ErrorContext` |
| Rendering | `RenderOptions`, `RenderResult`, `SceneManager`, `TransitionType`, `DeadEndClickInfo` |
| Utility | `Result`, `Option` |

Key differences from V2:

- V1 `Position` has no `offset` and counts code units, not visual columns.
- V1 elements use `Box`/`Row`/`Section` wrappers; V2 expresses grouping via `LayoutInfo` index ranges.
- V1 `ParseError` has optional `line`/`column`; V2 always provides a full `SourceLocation` and a machine-readable `code`.
- V1 `DeviceType` is lowercase with 6 values; V2 `DeviceType` is `'Mobile' | 'Tablet' | 'Desktop'`.

See [api.md → Legacy V1 API](api.md#legacy-v1-api) for usage.

---

## See Also

- [Syntax v2.3 Reference](./syntax-v2.md)
- [API Reference](./api.md)
- [Examples](./examples.md)
- [Developer Guide](./developer-guide.md)

---

**Version**: 0.4.3
**Last Updated**: 2026-06-11
**License**: GPL-3.0
