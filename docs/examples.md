# Wyreframe Examples

**Version**: 0.4.3
**Language**: TypeScript/ReScript
**Last Updated**: 2025-12-27

> **Note**: This document uses the TypeScript-friendly API with `result.success` pattern.
> For ReScript, use the pattern matching syntax shown in [API Documentation](./api.md#rescript-api).

## Table of Contents

- [Basic Examples](#basic-examples)
- [Element Types](#element-types)
- [Scene Management](#scene-management)
- [Interactions](#interactions)
- [Error Handling](#error-handling)
- [Advanced Patterns](#advanced-patterns)
- [Real-World Examples](#real-world-examples)

---

## Basic Examples

### Simple Box

The most basic wireframe with a single box.

```typescript
import { parse } from 'wyreframe';

const wireframe = `
+--------+
|  Box   |
+--------+
`;

const result = parse(wireframe);

if (result.success) {
  console.log('Scenes:', result.ast.scenes.length); // 1
  console.log('Elements:', result.ast.scenes[0].elements); // Box with text
}
```

**Output AST:**

```json
{
  "scenes": [
    {
      "id": "default",
      "title": "",
      "transition": "none",
      "elements": [
        {
          "TAG": "Box",
          "name": null,
          "bounds": { "top": 0, "left": 0, "bottom": 2, "right": 9 },
          "children": [
            {
              "TAG": "Text",
              "content": "Box",
              "emphasis": false,
              "position": { "row": 1, "col": 2 },
              "align": "Center"
            }
          ]
        }
      ]
    }
  ]
}
```

---

### Named Box

Box with a name in the top border.

```typescript
const wireframe = `
+--Login--+
|         |
+----------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    console.log('Box name:', box.name); // "Login"
  }
}
```

---

### Nested Boxes

Boxes containing other boxes.

```typescript
const wireframe = `
+--Outer-----------+
|                  |
|  +--Inner--+     |
|  |         |     |
|  +---------+     |
|                  |
+------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const outer = result.ast.scenes[0].elements[0];
  if (outer.TAG === 'Box') {
    console.log('Outer box name:', outer.name); // "Outer"
    console.log('Children:', outer.children.length); // 1

    const inner = outer.children[0];
    if (inner.TAG === 'Box') {
      console.log('Inner box name:', inner.name); // "Inner"
    }
  }
}
```

---

## Element Types

### Buttons

Buttons are defined with square brackets.

```typescript
const wireframe = `
+---------------------------+
|     [ Submit ]            |
|     [ Cancel ]            |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    box.children.forEach(element => {
      if (element.TAG === 'Button') {
        console.log(`Button: ${element.text} (${element.align})`);
        // Button: Submit (Center)
        // Button: Cancel (Center)
      }
    });
  }
}
```

**Alignment Examples:**

```typescript
const wireframe = `
+---------------------------+
| [ Left ]                  |  <- Left aligned
|       [ Center ]          |  <- Center aligned
|              [ Right ]    |  <- Right aligned
+---------------------------+
`;
```

---

### Input Fields

Input fields are defined with hash prefix.

```typescript
const wireframe = `
+---------------------------+
| #username                 |
| #password                 |
| #email                    |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    box.children.forEach(element => {
      if (element.TAG === 'Input') {
        console.log(`Input: ${element.id}`);
        // Input: username
        // Input: password
        // Input: email
      }
    });
  }
}
```

---

### Links

Links are defined with double quotes.

```typescript
const wireframe = `
+---------------------------+
| "Forgot Password"         |
| "Create Account"          |
| "Help Center"             |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    box.children.forEach(element => {
      if (element.TAG === 'Link') {
        console.log(`Link: ${element.text} -> ${element.id}`);
        // Link: Forgot Password -> forgot-password
        // Link: Create Account -> create-account
        // Link: Help Center -> help-center
      }
    });
  }
}
```

---

### Checkboxes

Checkboxes with checked/unchecked state.

```typescript
const wireframe = `
+---------------------------+
| [x] Remember me           |
| [ ] Subscribe to updates  |
| [x] Agree to terms        |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    box.children.forEach(element => {
      if (element.TAG === 'Checkbox') {
        const status = element.checked ? 'checked' : 'unchecked';
        console.log(`Checkbox: ${element.label} (${status})`);
        // Checkbox: Remember me (checked)
        // Checkbox: Subscribe to updates (unchecked)
        // Checkbox: Agree to terms (checked)
      }
    });
  }
}
```

---

### Text and Emphasis

Plain and emphasized text.

```typescript
const wireframe = `
+---------------------------+
| * Welcome to Wyreframe    |
| Please sign in below      |
| * Important Note          |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    box.children.forEach(element => {
      if (element.TAG === 'Text') {
        const style = element.emphasis ? 'emphasized' : 'normal';
        console.log(`Text: "${element.content}" (${style})`);
        // Text: "Welcome to Wyreframe" (emphasized)
        // Text: "Please sign in below" (normal)
        // Text: "Important Note" (emphasized)
      }
    });
  }
}
```

---

### Dividers

Horizontal divider lines separate sections.

```typescript
const wireframe = `
+---------------------------+
| Header Section            |
|===========================|
| Body Section              |
|===========================|
| Footer Section            |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const box = result.ast.scenes[0].elements[0];
  if (box.TAG === 'Box') {
    // Dividers create Section elements
    box.children.forEach(element => {
      if (element.TAG === 'Section') {
        console.log(`Section: ${element.name}`);
        console.log(`  Children: ${element.children.length}`);
      }
    });
  }
}
```

---

## Scene Management

### Single Scene

Define a scene with metadata.

```typescript
const wireframe = `
@scene: login
@title: Login Screen
@transition: fade

+---------------------------+
| * Login                   |
|                           |
| #email                    |
| #password                 |
|                           |
|     [ Sign In ]           |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const scene = result.ast.scenes[0];
  console.log('Scene ID:', scene.id);           // "login"
  console.log('Scene Title:', scene.title);     // "Login Screen"
  console.log('Transition:', scene.transition); // "fade"
}
```

---

### Device Types

Define target device for responsive rendering.

```typescript
const wireframe = `
@scene: mobile-login
@title: Mobile Login
@device: mobile

+---------------------------+
| * Login                   |
|                           |
| #email                    |
| #password                 |
|                           |
|     [ Sign In ]           |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const scene = result.ast.scenes[0];
  console.log('Device:', scene.device); // "Mobile"
}
```

**Supported Device Types:**

```typescript
// Preset devices
@device: desktop        // 1440x900
@device: laptop         // 1280x800
@device: tablet         // 768x1024
@device: tablet-landscape // 1024x768
@device: mobile         // 375x812
@device: mobile-landscape // 812x375

// Custom dimensions
@device: 1920x1080      // Custom size
```

---

### Multiple Scenes

Separate scenes with `---`.

```typescript
const wireframe = `
@scene: login
@title: Login

+---------------------------+
|     [ Login ]             |
+---------------------------+

---

@scene: dashboard
@title: Dashboard
@transition: slide-left

+---------------------------+
|   * Dashboard             |
|                           |
|   Welcome back!           |
+---------------------------+
`;

const result = parse(wireframe);

if (result.success) {
  const ast = result.ast;
  console.log('Number of scenes:', ast.scenes.length); // 2

  ast.scenes.forEach(scene => {
    console.log(`Scene: ${scene.id} - ${scene.title}`);
    // Scene: login - Login
    // Scene: dashboard - Dashboard
  });
}
```

---

## Interactions

### Button with Navigation

```typescript
const wireframe = `
@scene: login

+---------------------------+
|     [ Login ]             |
+---------------------------+
`;

const interactions = `
@scene: login

[ Login ]:
  variant: primary
  @click -> goto(dashboard, slide-left)
`;

const result = parse(wireframe, interactions);

if (result.success) {
  const ast = result.ast;
  const scene = ast.scenes[0];
  const button = scene.elements[0];

  if (button.TAG === 'Button') {
    console.log('Button ID:', button.id);
    // Properties and actions are merged into the element
  }
}
```

---

### Input with Validation

```typescript
const wireframe = `
@scene: registration

+---------------------------+
| #email                    |
| #password                 |
|     [ Register ]          |
+---------------------------+
`;

const interactions = `
@scene: registration

#email:
  placeholder: "Enter your email"
  @change -> validate(email)

#password:
  placeholder: "Enter password"
  type: password
  @change -> validate(password)

[ Register ]:
  variant: primary
  @click -> submitForm(email, password)
`;

const result = parse(wireframe, interactions);

if (result.success) {
  console.log('Wireframe with interactions parsed successfully');
  // Elements now have merged properties and actions
}
```

---

### Conditional Actions

```typescript
const interactions = `
@scene: checkout

[ Proceed ]:
  variant: primary
  @click -> goto(payment) if validated
  @click -> showError() if !validated

[ Cancel ]:
  variant: secondary
  @click -> back()
`;
```

---

## Error Handling

### Handling Parse Errors

```typescript
import { parse, formatError } from 'wyreframe';

const wireframe = `
+--Unclosed--+
|            |
+----------
`;  // Missing closing corner

const result = parse(wireframe);

if (!result.success) {
  const errors = result.errors;

  console.log(`Found ${errors.length} error(s):`);

  errors.forEach((error, index) => {
    console.log(`\nError ${index + 1}:`);
    console.log(formatError(error));
  });
}
```

**Output:**

```
Found 1 error(s):

Error 1:
❌ Box is not closed

Box opened at row 1, column 0 but never closed on the bottom side.

   1 │ +--Unclosed--+
 → 2 │ |            |
      │             ^
   3 │ +----------

💡 Solution: Add the closing corner '+' at the end of the bottom border to match the width of the top border.
```

---

### Separating Errors and Warnings

```typescript
const result = parse(wireframe);

if (!result.success) {
  const errors = result.errors;

  const criticalErrors = errors.filter(e => e.severity === 'Error');
  const warnings = errors.filter(e => e.severity === 'Warning');

  if (criticalErrors.length > 0) {
    console.error('Critical errors that prevent parsing:');
    criticalErrors.forEach(error => console.error(formatError(error)));
  }

  if (warnings.length > 0) {
    console.warn('Warnings (parsing can continue):');
    warnings.forEach(warning => console.warn(formatError(warning)));
  }

  // Decide whether to proceed based on error severity
  if (criticalErrors.length === 0) {
    console.log('Proceeding with warnings...');
    // Can use partial AST
  }
}
```

---

### Validation Without Parsing

```typescript
function isValidWireframe(wireframe: string): boolean {
  const result = parse(wireframe);

  if (!result.success) {
    const criticalErrors = result.ast.filter(e => e.severity === 'Error');
    return criticalErrors.length === 0;
  }

  return true;
}

// Usage
if (isValidWireframe(userInput)) {
  console.log('Wireframe is valid');
} else {
  console.log('Wireframe has errors');
}
```

---

## Advanced Patterns

### Traversing the AST

```typescript
function traverseElements(
  elements: Element[],
  callback: (element: Element, depth: number) => void,
  depth: number = 0
): void {
  elements.forEach(element => {
    callback(element, depth);

    if (element.TAG === 'Box') {
      traverseElements(element.children, callback, depth + 1);
    } else if (element.TAG === 'Section') {
      traverseElements(element.children, callback, depth + 1);
    } else if (element.TAG === 'Row') {
      traverseElements(element.children, callback, depth + 1);
    }
  });
}

// Usage
const result = parse(wireframe);
if (result.success) {
  const ast = result.ast;

  ast.scenes.forEach(scene => {
    console.log(`\nScene: ${scene.id}`);
    traverseElements(scene.elements, (element, depth) => {
      const indent = '  '.repeat(depth);
      console.log(`${indent}- ${element.TAG}`);
    });
  });
}
```

---

### Finding Elements by Type

```typescript
function findElementsByType<T extends Element['TAG']>(
  ast: AST,
  type: T
): Extract<Element, { TAG: T }>[] {
  const results: Extract<Element, { TAG: T }>[] = [];

  function search(elements: Element[]): void {
    elements.forEach(element => {
      if (element.TAG === type) {
        results.push(element as Extract<Element, { TAG: T }>);
      }

      if (element.TAG === 'Box') {
        search(element.children);
      } else if (element.TAG === 'Section') {
        search(element.children);
      } else if (element.TAG === 'Row') {
        search(element.children);
      }
    });
  }

  ast.scenes.forEach(scene => search(scene.elements));
  return results;
}

// Usage
const result = parse(wireframe);
if (result.success) {
  const allButtons = findElementsByType(result.ast, 'Button');
  const allInputs = findElementsByType(result.ast, 'Input');

  console.log(`Found ${allButtons.length} buttons`);
  console.log(`Found ${allInputs.length} inputs`);
}
```

---

### Converting AST to HTML

```typescript
function elementToHTML(element: Element): string {
  switch (element.TAG) {
    case 'Button':
      return `<button id="${element.id}" class="align-${element.align.toLowerCase()}">${element.text}</button>`;

    case 'Input':
      return `<input id="${element.id}" placeholder="${element.placeholder || ''}" />`;

    case 'Link':
      return `<a id="${element.id}" class="align-${element.align.toLowerCase()}">${element.text}</a>`;

    case 'Checkbox':
      const checked = element.checked ? 'checked' : '';
      return `<label><input type="checkbox" ${checked} /> ${element.label}</label>`;

    case 'Text':
      const tag = element.emphasis ? 'strong' : 'span';
      return `<${tag} class="align-${element.align.toLowerCase()}">${element.content}</${tag}>`;

    case 'Divider':
      return '<hr />';

    case 'Box':
      const childHTML = element.children.map(elementToHTML).join('\n');
      const className = element.name ? `box-${element.name.toLowerCase()}` : 'box';
      return `<div class="${className}">\n${childHTML}\n</div>`;

    case 'Section':
      const sectionHTML = element.children.map(elementToHTML).join('\n');
      return `<section class="${element.name}">\n${sectionHTML}\n</section>`;

    case 'Row':
      const rowHTML = element.children.map(elementToHTML).join('\n');
      return `<div class="row align-${element.align.toLowerCase()}">\n${rowHTML}\n</div>`;

    default:
      return '';
  }
}

function astToHTML(ast: AST): string {
  return ast.scenes.map(scene => {
    const elementsHTML = scene.elements.map(elementToHTML).join('\n');
    return `
      <div id="${scene.id}" class="scene" data-transition="${scene.transition}">
        <h1>${scene.title}</h1>
        ${elementsHTML}
      </div>
    `;
  }).join('\n');
}

// Usage
const result = parse(wireframe);
if (result.success) {
  const html = astToHTML(result.ast);
  console.log(html);
}
```

---

## Real-World Examples

### Login Form

Complete login form with validation and navigation.

```typescript
const loginWireframe = `
@scene: login
@title: Login to Your Account
@transition: fade

+---------------------------+
|   * Login to Your Account |
|                           |
|   Email                   |
|   #email                  |
|                           |
|   Password                |
|   #password               |
|                           |
|   [x] Remember me         |
|                           |
|      [ Sign In ]          |
|                           |
|   "Forgot password?"      |
|   "Create an account"     |
+---------------------------+
`;

const loginInteractions = `
@scene: login

#email:
  placeholder: "Enter your email"
  type: email
  @change -> validate(email)

#password:
  placeholder: "Enter password"
  type: password
  @change -> validate(password)

[ Sign In ]:
  variant: primary
  @click -> validate(email, password)
  @click -> goto(dashboard, slide-left) if validated

"Forgot password?":
  @click -> goto(forgot-password, fade)

"Create an account":
  @click -> goto(register, slide-up)
`;

const result = parse(loginWireframe, loginInteractions);

if (result.success) {
  console.log('Login form parsed successfully');
  const html = astToHTML(result.ast);
  // Render to DOM or save to file
}
```

---

### Dashboard with Sections

Multi-section dashboard layout.

```typescript
const dashboardWireframe = `
@scene: dashboard
@title: Dashboard
@transition: slide-left

+---------------------------+
|   * Dashboard             |
|===========================|
|   Statistics              |
|                           |
|   +--Stats--+  +--Stats--+|
|   | 1,234   |  | 5,678   ||
|   | Users   |  | Sales   ||
|   +---------+  +---------+|
|===========================|
|   Recent Activity         |
|                           |
|   User logged in          |
|   Order #123 shipped      |
|   New message received    |
|===========================|
|     [ View Reports ]      |
|     [ Settings ]          |
+---------------------------+
`;

const result = parse(dashboardWireframe);

if (result.success) {
  const scene = result.ast.scenes[0];

  // Find all sections
  traverseElements(scene.elements, (element, depth) => {
    if (element.TAG === 'Section') {
      console.log(`Section: ${element.name}`);
      console.log(`  Children: ${element.children.length}`);
    }
  });
}
```

---

### Multi-Step Form

Wizard-style multi-step form.

```typescript
const wizardWireframe = `
@scene: step1
@title: Step 1: Personal Info

+---------------------------+
|   * Step 1 of 3           |
|===========================|
|   Personal Information    |
|                           |
|   #firstName              |
|   #lastName               |
|   #birthdate              |
|                           |
|            [ Next ]       |
+---------------------------+

---

@scene: step2
@title: Step 2: Contact Info
@transition: slide-left

+---------------------------+
|   * Step 2 of 3           |
|===========================|
|   Contact Information     |
|                           |
|   #email                  |
|   #phone                  |
|                           |
|   [ Back ]    [ Next ]    |
+---------------------------+

---

@scene: step3
@title: Step 3: Confirmation
@transition: slide-left

+---------------------------+
|   * Step 3 of 3           |
|===========================|
|   Review Your Information |
|                           |
|   [ Back ]    [ Submit ]  |
+---------------------------+
`;

const wizardInteractions = `
@scene: step1

[ Next ]:
  variant: primary
  @click -> goto(step2, slide-left)

---

@scene: step2

[ Back ]:
  variant: secondary
  @click -> back()

[ Next ]:
  variant: primary
  @click -> goto(step3, slide-left)

---

@scene: step3

[ Back ]:
  variant: secondary
  @click -> back()

[ Submit ]:
  variant: primary
  @click -> submitForm()
  @click -> goto(success, fade)
`;

const result = parse(wizardWireframe, wizardInteractions);

if (result.success) {
  console.log(`Wizard has ${result.ast.scenes.length} steps`);

  result.ast.scenes.forEach((scene, index) => {
    console.log(`Step ${index + 1}: ${scene.title}`);
  });
}
```

---

### Settings Page

Complex settings page with multiple sections and controls.

```typescript
const settingsWireframe = `
@scene: settings
@title: Settings

+---------------------------+
|   * Settings              |
|===========================|
|   Account                 |
|                           |
|   Email                   |
|   #account-email          |
|                           |
|   Password                |
|   #account-password       |
|                           |
|     [ Update Account ]    |
|===========================|
|   Preferences             |
|                           |
|   [x] Email notifications |
|   [ ] SMS notifications   |
|   [x] Dark mode           |
|===========================|
|   Privacy                 |
|                           |
|   [ ] Public profile      |
|   [x] Show online status  |
|===========================|
|   [ Cancel ]  [ Save ]    |
+---------------------------+
`;

const result = parse(settingsWireframe);

if (result.success) {
  const scene = result.ast.scenes[0];

  // Count different element types
  const buttons = findElementsByType(result.ast, 'Button');
  const inputs = findElementsByType(result.ast, 'Input');
  const checkboxes = findElementsByType(result.ast, 'Checkbox');

  console.log('Settings page elements:');
  console.log(`  ${buttons.length} buttons`);
  console.log(`  ${inputs.length} inputs`);
  console.log(`  ${checkboxes.length} checkboxes`);
}
```

---

## Testing Examples

### Unit Test Example

```typescript
import { describe, it, expect } from '@jest/globals';
import { parse } from 'wyreframe';

describe('Wyreframe Parser', () => {
  it('should parse a simple button', () => {
    const wireframe = `
      +------------------+
      |   [ Click Me ]   |
      +------------------+
    `;

    const result = parse(wireframe);

    expect(result.success).toBe(true);

    if (result.success) {
      const box = result.ast.scenes[0].elements[0];
      expect(box.TAG).toBe('Box');

      if (box.TAG === 'Box') {
        const button = box.children[0];
        expect(button.TAG).toBe('Button');

        if (button.TAG === 'Button') {
          expect(button.text).toBe('Click Me');
          expect(button.id).toBe('click-me');
          expect(button.align).toBe('Center');
        }
      }
    }
  });

  it('should detect unclosed boxes', () => {
    const wireframe = `
      +------------------+
      |                  |
      +------------------
    `;

    const result = parse(wireframe);

    expect(result.success).toBe(false);

    if (!result.success) {
      expect(result.errors.length).toBeGreaterThan(0);
      // Error has message property with error details
    }
  });

  it('should parse nested boxes', () => {
    const wireframe = `
      +--Outer-----------+
      |  +--Inner--+     |
      |  |         |     |
      |  +---------+     |
      +------------------+
    `;

    const result = parse(wireframe);

    expect(result.success).toBe(true);

    if (result.success) {
      const outer = result.ast.scenes[0].elements[0];
      expect(outer.TAG).toBe('Box');

      if (outer.TAG === 'Box') {
        expect(outer.name).toBe('Outer');
        expect(outer.children.length).toBe(1);

        const inner = outer.children[0];
        expect(inner.TAG).toBe('Box');

        if (inner.TAG === 'Box') {
          expect(inner.name).toBe('Inner');
        }
      }
    }
  });
});
```

---

## Performance Examples

### Benchmarking

```typescript
function benchmark(wireframe: string, iterations: number = 100): void {
  const times: number[] = [];

  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    parse(wireframe);
    const end = performance.now();
    times.push(end - start);
  }

  const avg = times.reduce((a, b) => a + b, 0) / times.length;
  const min = Math.min(...times);
  const max = Math.max(...times);

  console.log(`Benchmark Results (${iterations} iterations):`);
  console.log(`  Average: ${avg.toFixed(2)}ms`);
  console.log(`  Min: ${min.toFixed(2)}ms`);
  console.log(`  Max: ${max.toFixed(2)}ms`);
}

// Usage
const largeWireframe = generateLargeWireframe(500); // 500 lines
benchmark(largeWireframe, 50);
```

---

## See Also

- [API Documentation](./api.md) - Complete API reference
- [Type Reference](./types.md) - All type definitions
- [Developer Guide](./developer-guide.md) - Extending the parser

---

**Version**: 0.4.3
**Last Updated**: 2025-12-27
**License**: GPL-3.0
