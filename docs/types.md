# Wyreframe Parser Type Reference

**Version**: 0.1.0
**Language**: ReScript (compiled to JavaScript/TypeScript)
**Last Updated**: 2025-12-22

## Table of Contents

- [Core Types](#core-types)
- [Grid Types](#grid-types)
- [Element Types](#element-types)
- [Scene Types](#scene-types)
- [Device Types](#device-types)
- [Interaction Types](#interaction-types)
- [Error Types](#error-types)
- [Utility Types](#utility-types)

---

## Core Types

### Position

Represents a position in the 2D grid with row and column coordinates.

```typescript
interface Position {
  row: number;
  col: number;
}
```

**Properties:**

- `row` (number): Zero-based row index
- `col` (number): Zero-based column index

**Methods:**

```typescript
// Create a position
function makePosition(row: number, col: number): Position;

// Navigate in cardinal directions
function right(pos: Position, n?: number): Position;
function down(pos: Position, n?: number): Position;
function left(pos: Position, n?: number): Position;
function up(pos: Position, n?: number): Position;

// Utilities
function equals(pos1: Position, pos2: Position): boolean;
function isWithin(pos: Position, bounds: Bounds): boolean;
function toString(pos: Position): string;
```

**Example:**

```typescript
const pos = makePosition(5, 10);
const nextPos = right(pos, 3); // { row: 5, col: 13 }
const below = down(pos);       // { row: 6, col: 10 }
```

---

### Bounds

Represents a rectangular bounding box.

```typescript
interface Bounds {
  top: number;
  left: number;
  bottom: number;
  right: number;
}
```

**Properties:**

- `top` (number): Top edge row index (inclusive)
- `left` (number): Left edge column index (inclusive)
- `bottom` (number): Bottom edge row index (inclusive)
- `right` (number): Right edge column index (inclusive)

**Methods:**

```typescript
// Create bounds
function makeBounds(
  top: number,
  left: number,
  bottom: number,
  right: number
): Bounds;

// Dimensions
function width(bounds: Bounds): number;
function height(bounds: Bounds): number;
function area(bounds: Bounds): number;

// Relationships
function contains(outer: Bounds, inner: Bounds): boolean;
function overlaps(bounds1: Bounds, bounds2: Bounds): boolean;
```

**Example:**

```typescript
const bounds = makeBounds(0, 0, 10, 20);
const w = width(bounds);  // 21 (0-20 inclusive)
const h = height(bounds); // 11 (0-10 inclusive)
const a = area(bounds);   // 231
```

---

### Alignment

Text alignment within a box.

```typescript
type Alignment = 'Left' | 'Center' | 'Right';
```

**Values:**

- `Left`: Left-aligned content
- `Center`: Center-aligned content
- `Right`: Right-aligned content

**Example:**

```typescript
const align: Alignment = 'Center';
```

---

## Grid Types

### CellChar

Represents a character in the grid with semantic meaning.

```typescript
type CellChar =
  | { TAG: 'Corner' }      // '+'
  | { TAG: 'HLine' }       // '-'
  | { TAG: 'VLine' }       // '|'
  | { TAG: 'Divider' }     // '='
  | { TAG: 'Space' }       // ' '
  | { TAG: 'Char'; _0: string }; // Any other character
```

**Example:**

```typescript
const corner: CellChar = { TAG: 'Corner' };
const letter: CellChar = { TAG: 'Char', _0: 'A' };
```

---

### Grid

Internal 2D character grid structure (not typically exposed in public API).

```typescript
interface Grid {
  cells: CellChar[][];
  width: number;
  height: number;
  cornerIndex: Position[];
  hLineIndex: Position[];
  vLineIndex: Position[];
  dividerIndex: Position[];
}
```

**Properties:**

- `cells` (CellChar[][]): 2D array of cell characters
- `width` (number): Grid width in characters
- `height` (number): Grid height in lines
- `cornerIndex` (Position[]): Index of all '+' positions
- `hLineIndex` (Position[]): Index of all '-' positions
- `vLineIndex` (Position[]): Index of all '|' positions
- `dividerIndex` (Position[]): Index of all '=' positions

---

## Element Types

### Element

Base union type for all UI elements.

```typescript
type Element =
  | BoxElement
  | ButtonElement
  | InputElement
  | LinkElement
  | CheckboxElement
  | TextElement
  | DividerElement
  | RowElement
  | SectionElement;
```

---

### BoxElement

Represents a rectangular box container.

```typescript
interface BoxElement {
  TAG: 'Box';
  name?: string;
  bounds: Bounds;
  children: Element[];
}
```

**Properties:**

- `name` (string, optional): Box name extracted from top border (e.g., "+--Login--+")
- `bounds` (Bounds): Bounding box coordinates
- `children` (Element[]): Nested elements within the box

**Example:**

```typescript
const box: BoxElement = {
  TAG: 'Box',
  name: 'Login',
  bounds: { top: 0, left: 0, bottom: 10, right: 30 },
  children: [
    // ... child elements
  ]
};
```

---

### ButtonElement

Represents a button element.

```typescript
interface ButtonElement {
  TAG: 'Button';
  id: string;
  text: string;
  position: Position;
  align: Alignment;
}
```

**Properties:**

- `id` (string): Slugified button text for identification
- `text` (string): Button label text
- `position` (Position): Grid position where button appears
- `align` (Alignment): Horizontal alignment within container

**Syntax:**

```
[ Button Text ]
```

**Example:**

```typescript
const button: ButtonElement = {
  TAG: 'Button',
  id: 'submit',
  text: 'Submit',
  position: { row: 5, col: 10 },
  align: 'Center'
};
```

---

### InputElement

Represents an input field.

```typescript
interface InputElement {
  TAG: 'Input';
  id: string;
  placeholder?: string;
  position: Position;
}
```

**Properties:**

- `id` (string): Input field identifier
- `placeholder` (string, optional): Placeholder text (from interactions)
- `position` (Position): Grid position

**Syntax:**

```
#fieldname
```

**Example:**

```typescript
const input: InputElement = {
  TAG: 'Input',
  id: 'email',
  placeholder: 'Enter your email',
  position: { row: 3, col: 5 }
};
```

---

### LinkElement

Represents a clickable link.

```typescript
interface LinkElement {
  TAG: 'Link';
  id: string;
  text: string;
  position: Position;
  align: Alignment;
}
```

**Properties:**

- `id` (string): Slugified link text
- `text` (string): Link display text
- `position` (Position): Grid position
- `align` (Alignment): Horizontal alignment

**Syntax:**

```
"Link Text"
```

**Example:**

```typescript
const link: LinkElement = {
  TAG: 'Link',
  id: 'forgot-password',
  text: 'Forgot Password',
  position: { row: 8, col: 12 },
  align: 'Right'
};
```

---

### CheckboxElement

Represents a checkbox with optional label.

```typescript
interface CheckboxElement {
  TAG: 'Checkbox';
  checked: boolean;
  label: string;
  position: Position;
}
```

**Properties:**

- `checked` (boolean): Checkbox state
- `label` (string): Label text following checkbox
- `position` (Position): Grid position

**Syntax:**

```
[x] Checked checkbox
[ ] Unchecked checkbox
```

**Example:**

```typescript
const checkbox: CheckboxElement = {
  TAG: 'Checkbox',
  checked: true,
  label: 'Remember me',
  position: { row: 6, col: 5 }
};
```

---

### TextElement

Represents plain or emphasized text.

```typescript
interface TextElement {
  TAG: 'Text';
  content: string;
  emphasis: boolean;
  position: Position;
  align: Alignment;
}
```

**Properties:**

- `content` (string): Text content
- `emphasis` (boolean): Whether text is emphasized (starts with `*`)
- `position` (Position): Grid position
- `align` (Alignment): Horizontal alignment

**Syntax:**

```
Plain text
* Emphasized text
```

**Example:**

```typescript
const text: TextElement = {
  TAG: 'Text',
  content: 'Welcome',
  emphasis: true,
  position: { row: 2, col: 8 },
  align: 'Center'
};
```

---

### DividerElement

Represents a horizontal divider line.

```typescript
interface DividerElement {
  TAG: 'Divider';
  position: Position;
}
```

**Properties:**

- `position` (Position): Grid position (row of divider)

**Syntax:**

```
+---------------------------+
|  Content above            |
|===========================|  <- Divider
|  Content below            |
+---------------------------+
```

**Example:**

```typescript
const divider: DividerElement = {
  TAG: 'Divider',
  position: { row: 4, col: 0 }
};
```

---

### RowElement

Represents a horizontal grouping of elements.

```typescript
interface RowElement {
  TAG: 'Row';
  children: Element[];
  align: Alignment;
}
```

**Properties:**

- `children` (Element[]): Elements in the row
- `align` (Alignment): Row alignment

**Example:**

```typescript
const row: RowElement = {
  TAG: 'Row',
  children: [
    { TAG: 'Button', id: 'cancel', text: 'Cancel', /* ... */ },
    { TAG: 'Button', id: 'submit', text: 'Submit', /* ... */ }
  ],
  align: 'Right'
};
```

---

### SectionElement

Represents a named section within a box (separated by dividers).

```typescript
interface SectionElement {
  TAG: 'Section';
  name: string;
  children: Element[];
}
```

**Properties:**

- `name` (string): Section name/identifier
- `children` (Element[]): Elements in the section

**Example:**

```typescript
const section: SectionElement = {
  TAG: 'Section',
  name: 'header',
  children: [
    { TAG: 'Text', content: 'Header', /* ... */ }
  ]
};
```

---

## Scene Types

### Scene

Represents a single screen or page in the wireframe.

```typescript
interface Scene {
  id: string;
  title: string;
  transition: string;
  device: DeviceType;
  elements: Element[];
}
```

**Properties:**

- `id` (string): Unique scene identifier
- `title` (string): Scene title for display
- `transition` (string): Transition effect when navigating to this scene
- `device` (DeviceType): Target device for responsive rendering
- `elements` (Element[]): All elements in the scene

**Directives:**

```
@scene: scene-id
@title: Scene Title
@transition: slide-left
@device: mobile
```

**Example:**

```typescript
const scene: Scene = {
  id: 'login',
  title: 'Login Screen',
  transition: 'fade',
  elements: [
    // ... elements
  ]
};
```

---

### AST

The complete Abstract Syntax Tree representing the parsed wireframe.

```typescript
interface AST {
  scenes: Scene[];
}
```

**Properties:**

- `scenes` (Scene[]): Array of all scenes in the wireframe

**Example:**

```typescript
const ast: AST = {
  scenes: [
    {
      id: 'login',
      title: 'Login',
      transition: 'fade',
      device: 'Mobile',
      elements: [/* ... */]
    },
    {
      id: 'dashboard',
      title: 'Dashboard',
      transition: 'slide-left',
      device: 'Desktop',
      elements: [/* ... */]
    }
  ]
};
```

---

## Device Types

### DeviceType

Target device type for responsive wireframes.

```typescript
type DeviceType =
  | 'Desktop'          // 1440x900 (16:10)
  | 'Laptop'           // 1280x800 (16:10)
  | 'Tablet'           // 768x1024 (3:4)
  | 'TabletLandscape'  // 1024x768 (4:3)
  | 'Mobile'           // 375x812 (iPhone X ratio)
  | 'MobileLandscape'  // 812x375
  | { TAG: 'Custom'; width: number; height: number };
```

**Preset Values:**

| Device | Width | Height | Aspect Ratio |
|--------|-------|--------|--------------|
| Desktop | 1440 | 900 | 16:10 |
| Laptop | 1280 | 800 | 16:10 |
| Tablet | 768 | 1024 | 3:4 |
| TabletLandscape | 1024 | 768 | 4:3 |
| Mobile | 375 | 812 | ~9:19.5 |
| MobileLandscape | 812 | 375 | ~19.5:9 |

**Directive Syntax:**

```
@device: desktop
@device: mobile
@device: tablet
@device: 1920x1080
```

---

### DeviceDimensions

Computed dimensions for a device type.

```typescript
interface DeviceDimensions {
  width: number;
  height: number;
  ratio: number;
  name: string;
}
```

**Properties:**

- `width` (number): Device width in pixels
- `height` (number): Device height in pixels
- `ratio` (number): Aspect ratio (width / height)
- `name` (string): Device name identifier

**Example:**

```typescript
const mobileDimensions: DeviceDimensions = {
  width: 375,
  height: 812,
  ratio: 0.462,
  name: 'mobile'
};
```

---

### parseDeviceType

Parse a device type string into a DeviceType.

```typescript
function parseDeviceType(str: string): DeviceType | undefined;
```

**Supported Formats:**

- Preset names: `"desktop"`, `"mobile"`, `"tablet"`, etc.
- Custom dimensions: `"1920x1080"`, `"800 x 600"`

**Example:**

```typescript
parseDeviceType("mobile");      // 'Mobile'
parseDeviceType("1920x1080");   // { TAG: 'Custom', width: 1920, height: 1080 }
parseDeviceType("invalid");     // undefined
```

---

## Interaction Types

### InteractionVariant

Button style variants.

```typescript
type InteractionVariant = 'Primary' | 'Secondary' | 'Ghost';
```

**Values:**

- `Primary`: Primary button style
- `Secondary`: Secondary button style
- `Ghost`: Ghost/transparent button style

---

### InteractionAction

Actions that can be triggered by interactions.

```typescript
type InteractionAction =
  | GotoAction
  | BackAction
  | ForwardAction
  | ValidateAction
  | CallAction;
```

---

### GotoAction

Navigate to another scene.

```typescript
interface GotoAction {
  TAG: 'Goto';
  target: string;
  transition: string;
  condition?: string;
}
```

**Properties:**

- `target` (string): Target scene ID
- `transition` (string): Transition effect
- `condition` (string, optional): Conditional expression

**Syntax:**

```
@click -> goto(dashboard, slide-left)
@click -> goto(success) if validated
```

**Example:**

```typescript
const gotoAction: GotoAction = {
  TAG: 'Goto',
  target: 'dashboard',
  transition: 'slide-left',
  condition: undefined
};
```

---

### BackAction

Navigate to previous scene.

```typescript
interface BackAction {
  TAG: 'Back';
}
```

**Syntax:**

```
@click -> back()
```

---

### ForwardAction

Navigate to next scene in history.

```typescript
interface ForwardAction {
  TAG: 'Forward';
}
```

**Syntax:**

```
@click -> forward()
```

---

### ValidateAction

Validate form fields.

```typescript
interface ValidateAction {
  TAG: 'Validate';
  fields: string[];
}
```

**Properties:**

- `fields` (string[]): Array of field IDs to validate

**Syntax:**

```
@click -> validate(email, password)
```

**Example:**

```typescript
const validateAction: ValidateAction = {
  TAG: 'Validate',
  fields: ['email', 'password']
};
```

---

### CallAction

Call a custom function.

```typescript
interface CallAction {
  TAG: 'Call';
  function: string;
  args: string[];
  condition?: string;
}
```

**Properties:**

- `function` (string): Function name to call
- `args` (string[]): Function arguments
- `condition` (string, optional): Conditional expression

**Syntax:**

```
@click -> submitForm(email, password)
@change -> updatePreview() if enabled
```

**Example:**

```typescript
const callAction: CallAction = {
  TAG: 'Call',
  function: 'submitForm',
  args: ['email', 'password'],
  condition: undefined
};
```

---

### Interaction

Associates properties and actions with an element.

```typescript
interface Interaction {
  elementId: string;
  properties: Record<string, unknown>;
  actions: InteractionAction[];
}
```

**Properties:**

- `elementId` (string): ID of target element
- `properties` (Record<string, unknown>): Custom properties (variant, placeholder, etc.)
- `actions` (InteractionAction[]): Event-triggered actions

**Example:**

```typescript
const interaction: Interaction = {
  elementId: 'login-button',
  properties: {
    variant: 'primary',
    disabled: false
  },
  actions: [
    {
      TAG: 'Goto',
      target: 'dashboard',
      transition: 'slide-left'
    }
  ]
};
```

---

### SceneInteractions

Groups all interactions for a scene.

```typescript
interface SceneInteractions {
  sceneId: string;
  interactions: Interaction[];
}
```

**Properties:**

- `sceneId` (string): Scene identifier
- `interactions` (Interaction[]): All interactions in the scene

**Example:**

```typescript
const sceneInteractions: SceneInteractions = {
  sceneId: 'login',
  interactions: [
    {
      elementId: 'email',
      properties: { placeholder: 'Email' },
      actions: []
    },
    {
      elementId: 'login-button',
      properties: { variant: 'primary' },
      actions: [
        { TAG: 'Goto', target: 'dashboard', transition: 'fade' }
      ]
    }
  ]
};
```

---

## Error Types

### ParseError

Represents a parsing error or warning.

```typescript
interface ParseError {
  code: ErrorCode;
  severity: 'Error' | 'Warning';
  context: ErrorContext;
}
```

**Properties:**

- `code` (ErrorCode): Specific error code with details
- `severity` ('Error' | 'Warning'): Error severity level
- `context` (ErrorContext): Contextual information

---

### ErrorCode

Discriminated union of all possible error codes.

```typescript
type ErrorCode =
  | UncloseBoxError
  | MismatchedWidthError
  | MisalignedPipeError
  | OverlappingBoxesError
  | InvalidElementError
  | UnclosedBracketError
  | EmptyButtonError
  | InvalidInteractionDSLError
  | UnusualSpacingWarning
  | DeepNestingWarning;
```

---

### UncloseBoxError

Box is missing a closing border.

```typescript
interface UncloseBoxError {
  TAG: 'UncloseBox';
  corner: Position;
  direction: string;
}
```

**Properties:**

- `corner` (Position): Opening corner position
- `direction` (string): Which side is unclosed ('top', 'right', 'bottom', 'left')

---

### MismatchedWidthError

Box top and bottom edges have different widths.

```typescript
interface MismatchedWidthError {
  TAG: 'MismatchedWidth';
  topLeft: Position;
  topWidth: number;
  bottomWidth: number;
}
```

**Properties:**

- `topLeft` (Position): Top-left corner position
- `topWidth` (number): Width of top edge
- `bottomWidth` (number): Width of bottom edge

---

### MisalignedPipeError

Vertical border character is not aligned.

```typescript
interface MisalignedPipeError {
  TAG: 'MisalignedPipe';
  position: Position;
  expected: number;
  actual: number;
}
```

**Properties:**

- `position` (Position): Position of misaligned pipe
- `expected` (number): Expected column position
- `actual` (number): Actual column position

---

### OverlappingBoxesError

Two boxes overlap incorrectly.

```typescript
interface OverlappingBoxesError {
  TAG: 'OverlappingBoxes';
  box1Name?: string;
  box2Name?: string;
  position: Position;
}
```

**Properties:**

- `box1Name` (string, optional): First box name
- `box2Name` (string, optional): Second box name
- `position` (Position): Overlap position

---

### InvalidElementError

Unknown or invalid element syntax.

```typescript
interface InvalidElementError {
  TAG: 'InvalidElement';
  content: string;
  position: Position;
}
```

**Properties:**

- `content` (string): Invalid element text
- `position` (Position): Position in grid

---

### EmptyButtonError

Button has no text content.

```typescript
interface EmptyButtonError {
  TAG: 'EmptyButton';
  position: Position;
}
```

**Properties:**

- `position` (Position): Button position

---

### InvalidInteractionDSLError

Interaction DSL parsing failed.

```typescript
interface InvalidInteractionDSLError {
  TAG: 'InvalidInteractionDSL';
  message: string;
  position?: Position;
}
```

**Properties:**

- `message` (string): Error description
- `position` (Position, optional): Error position if available

---

### UnusualSpacingWarning

Unusual spacing detected (e.g., tabs instead of spaces).

```typescript
interface UnusualSpacingWarning {
  TAG: 'UnusualSpacing';
  position: Position;
  issue: string;
}
```

**Properties:**

- `position` (Position): Warning position
- `issue` (string): Description of spacing issue

---

### DeepNestingWarning

Nesting depth exceeds recommended limit.

```typescript
interface DeepNestingWarning {
  TAG: 'DeepNesting';
  depth: number;
  position: Position;
}
```

**Properties:**

- `depth` (number): Actual nesting depth
- `position` (Position): Position of deeply nested box

---

### ErrorContext

Contextual information for an error.

```typescript
interface ErrorContext {
  codeSnippet?: string;
  linesBefore: number;
  linesAfter: number;
}
```

**Properties:**

- `codeSnippet` (string, optional): Formatted code snippet with error indicator
- `linesBefore` (number): Number of lines shown before error
- `linesAfter` (number): Number of lines shown after error

---

## Utility Types

### Result

ReScript-style Result type for error handling.

```typescript
type Result<T, E> =
  | { TAG: 'Ok'; _0: T }
  | { TAG: 'Error'; _0: E };
```

**Usage:**

```typescript
function handleResult<T>(result: Result<T, ParseError[]>) {
  if (result.TAG === 'Ok') {
    const value = result._0;
    // Process success case
  } else {
    const errors = result._0;
    // Handle errors
  }
}
```

---

### Option

ReScript-style Option type for nullable values.

```typescript
type Option<T> =
  | { TAG: 'Some'; _0: T }
  | { TAG: 'None' };
```

**Usage:**

```typescript
function handleOption<T>(option: Option<T>) {
  if (option.TAG === 'Some') {
    const value = option._0;
    // Use value
  } else {
    // Handle absence
  }
}
```

---

## Type Summary

### Core Types

- `Position` - Grid coordinates
- `Bounds` - Rectangular bounds
- `Alignment` - Text alignment

### Element Types

- `Element` - Union of all element types
- `BoxElement` - Container box
- `ButtonElement` - Button
- `InputElement` - Input field
- `LinkElement` - Clickable link
- `CheckboxElement` - Checkbox
- `TextElement` - Text content
- `DividerElement` - Horizontal divider
- `RowElement` - Element row
- `SectionElement` - Named section

### Scene Types

- `Scene` - Single screen/page
- `AST` - Complete wireframe AST

### Device Types

- `DeviceType` - Target device (Desktop, Mobile, etc.)
- `DeviceDimensions` - Computed device dimensions
- `parseDeviceType` - Parse device string to type

### Interaction Types

- `Interaction` - Element interaction
- `InteractionAction` - Action to perform
- `SceneInteractions` - Scene's interactions

### Error Types

- `ParseError` - Parse error/warning
- `ErrorCode` - Specific error variant
- `ErrorContext` - Error context

---

## See Also

- [API Documentation](./api.md) - Complete API reference
- [Examples](./examples.md) - Usage examples
- [Developer Guide](./developer-guide.md) - Parser development

---

**Version**: 0.1.0
**Last Updated**: 2025-12-22
**License**: MIT
