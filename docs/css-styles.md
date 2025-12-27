# Wyreframe CSS Styles Reference

**Version**: 0.7.11
**Date**: 2025-12-27

---

## Table of Contents

1. [Overview](#overview)
2. [Naming Convention](#naming-convention)
3. [Core Classes](#core-classes)
4. [Device Classes](#device-classes)
5. [Element Classes](#element-classes)
6. [Layout Classes](#layout-classes)
7. [Alignment Classes](#alignment-classes)
8. [Customization](#customization)

---

## Overview

Wyreframe uses a set of CSS classes prefixed with `wf-` to style rendered wireframe elements. All classes follow a consistent naming convention to avoid conflicts with existing stylesheets.

The default styles are injected automatically when `injectStyles: true` (default) is set in render options.

---

## Naming Convention

All Wyreframe CSS classes use the `wf-` prefix:

| Pattern | Example | Description |
|---------|---------|-------------|
| `wf-{element}` | `wf-button` | Element type |
| `wf-{element}.{variant}` | `wf-button.secondary` | Element variant |
| `wf-{element}.wf-{modifier}` | `wf-row.wf-distribute` | Element modifier |
| `wf-device-{type}` | `wf-device-mobile` | Device viewport |
| `wf-align-{direction}` | `wf-align-center` | Alignment modifier |

---

## Core Classes

### `.wf-app`

The root container for the entire wireframe application.

```css
.wf-app {
  font-family: monospace;
  position: relative;
  overflow: hidden;
  background: #fff;
  color: #333;
  font-size: 14px;
  margin: 0 auto;
}
```

### `.wf-scene`

Container for each scene (page/screen) in the wireframe.

```css
.wf-scene {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  padding: 16px;
  box-sizing: border-box;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.3s ease, transform 0.3s ease;
  overflow-y: auto;
}

.wf-scene.active {
  opacity: 1;
  pointer-events: auto;
}
```

---

## Device Classes

Device classes control the viewport dimensions. Apply these to `.wf-app`.

| Class | Dimensions | Aspect Ratio |
|-------|------------|--------------|
| `.wf-device-desktop` | 1440 x 900 | 16:10 |
| `.wf-device-laptop` | 1280 x 773 | 16:10 |
| `.wf-device-tablet` | 768 x 1064 | 3:4 (portrait) |
| `.wf-device-tablet-landscape` | 1024 x 768 | 4:3 |
| `.wf-device-mobile` | 375 x 812 | iPhone X ratio |
| `.wf-device-mobile-landscape` | 812 x 375 | iPhone X landscape |

### Example

```html
<div class="wf-app wf-device-mobile">
  <!-- Mobile viewport wireframe -->
</div>
```

---

## Element Classes

### `.wf-box`

Container element with border.

```css
.wf-box {
  border: 1px solid #333;
  padding: 12px;
  margin: 8px 0;
  background: #fff;
}
```

#### Named Box

Boxes with names display a label above the border:

```css
.wf-box-named {
  position: relative;
  margin-top: 16px;
}

.wf-box-named::before {
  content: attr(data-name);
  position: absolute;
  top: -10px;
  left: 8px;
  background: #fff;
  padding: 0 4px;
  font-size: 12px;
  color: #666;
}
```

### `.wf-button`

Button element.

```css
.wf-button {
  display: block;
  width: fit-content;
  padding: 8px 16px;
  background: #fff;
  color: #333;
  border: 1px solid #333;
  font: inherit;
  cursor: pointer;
  margin: 4px 0;
}
```

#### Button Variants

| Class | Description |
|-------|-------------|
| `.wf-button` | Default button with solid border |
| `.wf-button.secondary` | Gray background (`#eee`) |
| `.wf-button.ghost` | Transparent with dashed border |

```css
.wf-button.secondary { background: #eee; }
.wf-button.ghost { background: transparent; border: 1px dashed #999; color: #666; }
```

### `.wf-input`

Text input field.

```css
.wf-input {
  width: 100%;
  padding: 8px;
  border: 1px solid #333;
  font: inherit;
  box-sizing: border-box;
  margin: 4px 0;
}
```

### `.wf-link`

Clickable link element.

```css
.wf-link {
  display: block;
  color: #333;
  text-decoration: underline;
  cursor: pointer;
  margin: 4px 0;
}
```

### `.wf-text`

Plain text element.

```css
.wf-text {
  margin: 4px 0;
  line-height: 1.4;
}

.wf-text.emphasis {
  font-weight: bold;
}
```

### `.wf-checkbox`

Checkbox element with label.

```css
.wf-checkbox {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 4px 0;
  cursor: pointer;
}
```

### `.wf-divider`

Horizontal divider line.

```css
.wf-divider {
  border: none;
  border-top: 1px solid #333;
  margin: 12px 0;
}
```

### `.wf-spacer`

Empty space placeholder.

```css
.wf-spacer {
  min-height: 1em;
}
```

### `.wf-section`

Section container with header.

```css
.wf-section {
  border: 1px solid #333;
  margin: 8px 0;
}

.wf-section-header {
  background: #fff;
  padding: 4px 8px;
  font-size: 12px;
  color: #666;
  border-bottom: 1px solid #333;
}

.wf-section-content {
  padding: 8px;
}
```

---

## Layout Classes

### `.wf-row`

Horizontal flex container for arranging elements in a row.

```css
.wf-row {
  display: flex;
  gap: 12px;
  align-items: center;
  margin: 4px 0;
}

/* Elements inside rows have adjusted display */
.wf-row .wf-button { display: inline-block; margin: 0; }
.wf-row .wf-link { display: inline; margin: 0 8px; }
```

### `.wf-column`

Vertical flex container.

```css
.wf-column {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
```

---

## Alignment Classes

### Text Alignment

| Class | Property |
|-------|----------|
| `.wf-align-center` | `text-align: center` |
| `.wf-align-right` | `text-align: right` |

### Row Alignment (justify-content)

| Class | Property | Use Case |
|-------|----------|----------|
| `.wf-row.wf-align-center` | `justify-content: center` | Center all items |
| `.wf-row.wf-align-right` | `justify-content: flex-end` | Align items to right |
| `.wf-row.wf-distribute` | `justify-content: space-evenly` | Equal spacing between and around items |

### Button/Link Alignment

| Class | Effect |
|-------|--------|
| `.wf-button.wf-align-center` | Centers button using auto margins |
| `.wf-button.wf-align-right` | Right-aligns button using auto left margin |
| `.wf-link.wf-align-center` | Centers link using auto margins |
| `.wf-link.wf-align-right` | Right-aligns link using auto left margin |

### Distribution Example

The `.wf-distribute` class is automatically applied to rows with mixed alignments (e.g., buttons positioned at left, center, and right):

```
|   [ Google ]  [ Apple ]  [ GitHub ]   |
```

This renders with `justify-content: space-evenly` for equal visual spacing.

---

## Customization

### Overriding Styles

To customize styles, either:

1. **Override with CSS specificity**:
```css
.my-theme .wf-button {
  background: #007bff;
  color: white;
  border-radius: 4px;
}
```

2. **Disable style injection and provide your own**:
```javascript
render(ast, container, { injectStyles: false });
```

### Theme Example

```css
/* Dark theme */
.wf-app.dark-theme {
  background: #1a1a1a;
  color: #e0e0e0;
}

.dark-theme .wf-box {
  border-color: #444;
  background: #2a2a2a;
}

.dark-theme .wf-button {
  background: #333;
  color: #e0e0e0;
  border-color: #555;
}

.dark-theme .wf-input {
  background: #2a2a2a;
  color: #e0e0e0;
  border-color: #444;
}
```

---

## Full CSS Reference

```css
/* Core */
.wf-app { font-family: monospace; position: relative; overflow: hidden; background: #fff; color: #333; font-size: 14px; margin: 0 auto; }

/* Devices */
.wf-app.wf-device-desktop { width: 1440px; height: 900px; max-width: 100%; aspect-ratio: 16/10; }
.wf-app.wf-device-laptop { width: 1280px; height: 773px; max-width: 100%; aspect-ratio: 16/10; }
.wf-app.wf-device-tablet { width: 768px; height: 1064px; max-width: 100%; aspect-ratio: 3/4; }
.wf-app.wf-device-tablet-landscape { width: 1024px; height: 768px; max-width: 100%; aspect-ratio: 4/3; }
.wf-app.wf-device-mobile { width: 375px; height: 812px; max-width: 100%; aspect-ratio: 375/812; }
.wf-app.wf-device-mobile-landscape { width: 812px; height: 375px; max-width: 100%; aspect-ratio: 812/375; }

/* Scene */
.wf-scene { position: absolute; top: 0; left: 0; width: 100%; height: 100%; padding: 16px; box-sizing: border-box; opacity: 0; pointer-events: none; transition: opacity 0.3s ease, transform 0.3s ease; overflow-y: auto; }
.wf-scene.active { opacity: 1; pointer-events: auto; }

/* Elements */
.wf-box { border: 1px solid #333; padding: 12px; margin: 8px 0; background: #fff; }
.wf-box-named { position: relative; margin-top: 16px; }
.wf-box-named::before { content: attr(data-name); position: absolute; top: -10px; left: 8px; background: #fff; padding: 0 4px; font-size: 12px; color: #666; }
.wf-button { display: block; width: fit-content; padding: 8px 16px; background: #fff; color: #333; border: 1px solid #333; font: inherit; cursor: pointer; margin: 4px 0; }
.wf-button.secondary { background: #eee; }
.wf-button.ghost { background: transparent; border: 1px dashed #999; color: #666; }
.wf-input { width: 100%; padding: 8px; border: 1px solid #333; font: inherit; box-sizing: border-box; margin: 4px 0; }
.wf-link { display: block; color: #333; text-decoration: underline; cursor: pointer; margin: 4px 0; }
.wf-text { margin: 4px 0; line-height: 1.4; }
.wf-text.emphasis { font-weight: bold; }
.wf-checkbox { display: flex; align-items: center; gap: 8px; margin: 4px 0; cursor: pointer; }
.wf-divider { border: none; border-top: 1px solid #333; margin: 12px 0; }
.wf-spacer { min-height: 1em; }
.wf-section { border: 1px solid #333; margin: 8px 0; }
.wf-section-header { background: #fff; padding: 4px 8px; font-size: 12px; color: #666; border-bottom: 1px solid #333; }
.wf-section-content { padding: 8px; }

/* Layout */
.wf-row { display: flex; gap: 12px; align-items: center; margin: 4px 0; }
.wf-column { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.wf-row .wf-button { display: inline-block; margin: 0; }
.wf-row .wf-link { display: inline; margin: 0 8px; }

/* Alignment */
.wf-align-center { text-align: center; }
.wf-align-right { text-align: right; }
.wf-row.wf-align-center { justify-content: center; }
.wf-row.wf-align-right { justify-content: flex-end; }
.wf-row.wf-distribute { justify-content: space-evenly; }
.wf-button.wf-align-center, .wf-link.wf-align-center { margin-left: auto; margin-right: auto; }
.wf-button.wf-align-right, .wf-link.wf-align-right { margin-left: auto; margin-right: 0; }
```
