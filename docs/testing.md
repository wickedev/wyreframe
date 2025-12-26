# Wyreframe Testing Guide

**Version**: 0.4.3
**Last Updated**: 2025-12-27

This document explains the testing setup for the Wyreframe library.

## Testing Framework

Wyreframe uses **Vitest** for testing, with **rescript-vitest** for ReScript integration.

### Why Vitest?

- Fast execution with native ESM support
- Jest-compatible API
- Built-in TypeScript support
- Excellent HMR for watch mode
- V8 coverage provider

## Test Structure

```
src/
├── parser/
│   ├── Core/
│   │   └── __tests__/           # Core module tests
│   ├── Detector/
│   │   └── __tests__/           # Shape detector tests
│   ├── Semantic/
│   │   └── __tests__/           # Semantic parser tests
│   │   └── Elements/
│   │       └── __tests__/       # Element parser tests
│   ├── Interactions/
│   │   └── __tests__/           # Interaction parser tests
│   ├── Fixer/
│   │   └── __tests__/           # Auto-fix tests
│   └── __tests__/               # Integration tests
├── renderer/
│   └── __tests__/               # Renderer tests
├── index.ts                     # TypeScript API
└── index.test.ts                # TypeScript API tests
```

## Running Tests

### Run all tests
```bash
npm test
```

### Run tests in watch mode
```bash
npm run test:watch
```

### Run tests with coverage
```bash
npm run test:coverage
```

### Run specific test file
```bash
npm test -- path/to/test.mjs
```

### Run tests matching pattern
```bash
npm test -- --grep "Button"
```

## Writing Tests

### ReScript Tests

Use `rescript-vitest` for writing tests in ReScript:

```rescript
// src/parser/Core/__tests__/Position_test.res
open RescriptVitest

describe("Position", () => {
  test("creates position", () => {
    let pos = Position.make(5, 10)
    expect(pos.row)->toEqual(5)
    expect(pos.col)->toEqual(10)
  })

  test("moves right", () => {
    let pos = Position.make(0, 0)
    let moved = Position.right(pos, 3)
    expect(moved.col)->toEqual(3)
  })
})
```

### TypeScript Tests

For TypeScript API tests:

```typescript
// src/index.test.ts
import { describe, test, expect } from 'vitest';
import { parse, createUI } from './index';

describe('Wyreframe API', () => {
  test('parse returns success for valid wireframe', () => {
    const wireframe = `
      +--------+
      | Hello  |
      +--------+
    `;

    const result = parse(wireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.ast.scenes.length).toBe(1);
    }
  });

  test('createUI renders successfully', () => {
    const wireframe = `
      @scene: test
      +--------+
      | Hello  |
      +--------+
    `;

    const result = createUI(wireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.root).toBeInstanceOf(HTMLElement);
      expect(result.sceneManager).toBeDefined();
    }
  });
});
```

## Test Configuration

Configuration is in `vitest.config.js`:

```javascript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: [
      'src/**/*_test.mjs',
      'src/**/*.test.mjs',
      'src/**/*.test.ts'
    ],
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
    },
  },
});
```

## Coverage Reports

After running `npm run test:coverage`, view the HTML report:

```bash
open coverage/index.html
```

Coverage reports are also uploaded to Codecov in CI.

## Testing Patterns

### Testing Parse Results

```typescript
import { parse } from 'wyreframe';

test('handles button elements', () => {
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
      }
    }
  }
});
```

### Testing Error Cases

```typescript
test('returns error for unclosed box', () => {
  const wireframe = `
    +--------+
    | Hello  |
    +-------
  `;

  const result = parse(wireframe);

  expect(result.success).toBe(false);
  if (!result.success) {
    expect(result.errors.length).toBeGreaterThan(0);
  }
});
```

### Testing SceneManager

```typescript
test('sceneManager navigates between scenes', () => {
  const wireframe = `
    @scene: page1
    +--------+
    | Page 1 |
    +--------+
    ---
    @scene: page2
    +--------+
    | Page 2 |
    +--------+
  `;

  const result = createUI(wireframe);

  if (result.success) {
    const { sceneManager } = result;

    sceneManager.goto('page1');
    expect(sceneManager.getCurrentScene()).toBe('page1');

    sceneManager.goto('page2');
    expect(sceneManager.getCurrentScene()).toBe('page2');

    sceneManager.back();
    expect(sceneManager.getCurrentScene()).toBe('page1');
  }
});
```

### Testing Auto-Fix

```typescript
import { fix, fixOnly } from 'wyreframe';

test('fix corrects misaligned pipes', () => {
  const messy = `
+----------+
| Button  |
+---------+
`;

  const result = fix(messy);

  expect(result.success).toBe(true);
  if (result.success) {
    expect(result.fixed.length).toBeGreaterThan(0);
  }
});
```

## Best Practices

1. **One test file per module**: `Module.res` → `Module_test.res`
2. **Use descriptive test names**: Explain what's being tested
3. **Test edge cases**: Empty inputs, boundary values, error conditions
4. **Group related tests**: Use `describe` blocks for organization
5. **Keep tests focused**: One logical assertion per test
6. **Build before testing**: Run `npm run res:build` before tests

## CI/CD Integration

Tests run automatically on every push and pull request:

```yaml
# .github/workflows/ci.yml
- name: Run tests
  run: npm test

- name: Upload coverage
  uses: codecov/codecov-action@v4
```

## Troubleshooting

### Tests not found
- Ensure test files match patterns in `vitest.config.js`
- Check file extensions (`.test.ts`, `.test.mjs`, `_test.mjs`)

### Import errors
- Run `npm run res:build` before testing
- Verify .mjs files exist next to .res files

### DOM not available
- Ensure `environment: 'jsdom'` in vitest config
- Import JSDOM globals if needed

### Coverage too low
- Add more test cases
- Test error paths and edge cases
- Remove dead code

## Additional Resources

- [Vitest Documentation](https://vitest.dev/)
- [ReScript-Vitest](https://github.com/mununki/rescript-vitest)
- [ReScript Documentation](https://rescript-lang.org/)

---

**Version**: 0.4.3
**Last Updated**: 2025-12-27
**License**: GPL-3.0
