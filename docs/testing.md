# Wyreframe Testing Guide

**Version**: 0.4.3
**Last Updated**: 2026-06-11

This document explains the testing setup for the Wyreframe library, covering both the V2 parser suite and the legacy V1 suites.

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
│   ├── Core/__tests__/              # V1 core module tests
│   ├── Detector/__tests__/          # V1 shape detector tests
│   ├── Semantic/__tests__/          # V1 semantic parser tests
│   ├── Interactions/__tests__/      # V1 interaction parser tests
│   ├── Fixer/__tests__/             # V1 auto-fix tests
│   ├── __tests__/                   # V1 integration tests
│   └── v2/__tests__/                # V2 parser test suite
│       ├── lexer/                   # Scanner/Lexer/TokenStream/GridIndex tests
│       ├── elements/                # Per-element parser tests
│       ├── heuristics/              # Threshold boundary tests
│       ├── integration/             # End-to-end parses + Regressions*_test.res
│       │   └── PackageJson.test.ts  # Export map / .d.ts regression tests
│       └── perf/                    # Performance budget tests (REQ-19)
├── renderer/__tests__/              # V1 renderer tests
├── index.ts                         # TypeScript API
└── index.test.ts                    # TypeScript API tests
```

The V2 `integration/Regressions*_test.res` files lock in fixes from automated review rounds — when fixing a V2 parser bug, add a regression test there.

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
npm test -- src/parser/v2/__tests__/integration/Regressions_test.mjs
```

### Run tests matching pattern
```bash
npm test -- --grep "Container"
```

> ReScript tests run from compiled `.mjs` output — run `npm run res:build` (or `res:watch`) before testing parser changes.

## Writing Tests

### ReScript Tests (V2)

Use `rescript-vitest`. The suite convention: `Module.res` → `Module_test.res`, assertions through the test context `t`:

```rescript
// src/parser/v2/__tests__/elements/V2ButtonParser_test.res
open Vitest

describe("V2ButtonParser", () => {
  test("parses a simple button", t => {
    let result = V2Parser.parse("@scene: s\n[ Login ]", ())
    t->expect(result.success)->Expect.toBe(true)
  })

  test("reports unclosed container", t => {
    let result = V2Parser.parse("@scene: s\n+--+\n| x", ())
    t->expect(result.success)->Expect.toBe(false)
  })
})
```

### TypeScript Tests

For the public JS surface (exports, `.d.ts` shape, options normalization):

```typescript
// src/parser/v2/__tests__/integration/PackageJson.test.ts style
import { describe, test, expect } from 'vitest';
import { parse, version } from 'wyreframe/parser/v2';

describe('V2 public API', () => {
  test('parse returns blocks for valid wireframe', () => {
    const result = parse('@scene: s\n+--+\n|  |\n+--+');
    expect(result.success).toBe(true);
    expect(result.blocks).toHaveLength(1);
    expect(version).toBe('2.3.0');
  });

  test('partial options are normalized', () => {
    const result = parse('@scene: s\n[ OK ]', { strict: true });
    expect(result.success).toBe(true);
  });
});
```

## Test Configuration

Configuration is in `vitest.config.js`:

```javascript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/**/*_test.mjs", "src/**/*.test.mjs", "src/**/*.test.ts"],
    globals: false,
  },
});
```

Performance thresholds (REQ-19) may be adjusted per-machine in `vitest.config` only with a comment linking back to the requirement — never silently relaxed.

## Coverage Reports

After running `npm run test:coverage`, view the HTML report:

```bash
open coverage/index.html
```

Coverage reports are also uploaded to Codecov in CI.

## Testing Patterns

### V2: Asserting AST Shape

```typescript
import { parse } from 'wyreframe/parser/v2';

test('parses button inside container', () => {
  const result = parse(`
@scene: s
+------------------+
|   [ Click Me ]   |
+------------------+
`);
  expect(result.success).toBe(true);
  const container = result.blocks[0]._0.children[0];
  expect(container.TAG).toBe('ContainerNode');
  const button = container._0.children[0];
  expect(button.TAG).toBe('ButtonNode');
  expect(button._0.text).toBe('Click Me');
});
```

### V2: Asserting Errors and Warnings

```typescript
test('unclosed container is recoverable', () => {
  const result = parse('@scene: s\n+----+\n| x');
  expect(result.success).toBe(false);
  const err = result.errors.find(e => e.code === 'UnclosedContainer');
  expect(err?.recoverable).toBe(true);
});

test('heuristic warnings carry ruleId', () => {
  const result = parse(misalignedSource);
  const warn = result.warnings.find(w => w.code === 'MisalignedContainerWall');
  expect(warn?.ruleId).toBe('container.wallAlignment');
});
```

### V2: Heuristic Boundary Tests

Every numeric threshold needs three fixtures — just-inside, exact, just-outside (REQ-23.4):

```rescript
describe("containerColumnTolerance boundary", () => {
  test("drift of 1 col parses with warning", t => { /* just-inside */ })
  test("drift of 2 cols fails wall detection", t => { /* just-outside */ })
})
```

### V1 (Legacy): SceneManager / Auto-Fix

```typescript
import { createUI, fix } from 'wyreframe';

test('sceneManager navigates between scenes', () => {
  const result = createUI(v1Wireframe);
  if (result.success) {
    result.sceneManager.goto('page2');
    expect(result.sceneManager.getCurrentScene()).toBe('page2');
  }
});

test('fix corrects misaligned pipes', () => {
  const result = fix(messyV1Wireframe);
  expect(result.success).toBe(true);
});
```

## Best Practices

1. **One test file per module**: `Module.res` → `Module_test.res`
2. **Use descriptive test names**: Explain what's being tested
3. **Test edge cases**: Empty inputs, boundary values, error conditions
4. **Group related tests**: Use `describe` blocks for organization
5. **Keep tests focused**: One logical assertion per test
6. **Build before testing**: Run `npm run res:build` before tests
7. **Regression-first bug fixes**: Reproduce in a `Regressions*_test.res` before fixing
8. **Update golden fixtures with threshold changes**: Changing a heuristic default requires updating its boundary fixtures in the same change

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

### TypeScript declaration drift
- `npm run ts:check` validates the hand-rolled `V2Parser.d.ts` against consumers
- `PackageJson.test.ts` guards the export map — update it when changing `package.json` exports

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
**Last Updated**: 2026-06-11
**License**: GPL-3.0
