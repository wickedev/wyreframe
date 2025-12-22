# Testing Guide for Wyreframe Parser

This document explains the testing setup for the ReScript-based Wyreframe parser.

## Testing Approach

Due to compatibility issues between `@glennsl/rescript-jest` and ReScript v11+, we use a **hybrid testing approach**:

1. **ReScript code** (.res files) is compiled to JavaScript (.mjs files)
2. **Jest tests** are written in JavaScript and import the compiled modules
3. This provides full Jest functionality without binding compatibility issues

## Test Structure

```
src/parser/
├── Core/
│   └── __tests__/           # Tests for Core modules
├── Scanner/
│   └── __tests__/           # Tests for Scanner modules
├── Detector/
│   └── __tests__/           # Tests for Detector modules
│       └── Sample_test.test.mjs  # Example test file
├── Semantic/
│   └── __tests__/           # Tests for Semantic Parser
└── Interactions/
    └── __tests__/           # Tests for Interaction Parser
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
npm test -- path/to/test.test.mjs
```

## Writing Tests

### Step 1: Write ReScript Code

Create your ReScript module with testable functions:

```rescript
// src/parser/Core/Math.res
let add = (a: int, b: int): int => a + b
let multiply = (a: int, b: int): int => a * b
```

### Step 2: Compile ReScript

```bash
npm run res:build
```

This generates `Math.mjs` in the same directory.

### Step 3: Write Jest Test

Create a test file (`.test.mjs` extension):

```javascript
// src/parser/Core/__tests__/Math.test.mjs
import { describe, test, expect } from '@jest/globals';
import { add, multiply } from '../Math.mjs';

describe('Math Module', () => {
  test('add function', () => {
    expect(add(2, 3)).toBe(5);
    expect(add(-1, 1)).toBe(0);
  });

  test('multiply function', () => {
    expect(multiply(2, 3)).toBe(6);
    expect(multiply(0, 5)).toBe(0);
  });
});
```

### Step 4: Run Tests

```bash
npm test
```

## Coverage Requirements

The project enforces **90% coverage** for:
- Branches
- Functions
- Lines
- Statements

Coverage configuration is in `jest.config.js`:

```javascript
coverageThreshold: {
  global: {
    branches: 90,
    functions: 90,
    lines: 90,
    statements: 90
  }
}
```

## Coverage Reports

After running `npm run test:coverage`, view the HTML report:

```bash
open coverage/index.html
```

## Testing ReScript Types

### Option Types

```rescript
// ReScript
let safeDivide = (a: float, b: float): option<float> => {
  if b == 0.0 { None } else { Some(a /. b) }
}
```

```javascript
// Jest test
import { safeDivide } from '../Math.mjs';

test('safeDivide handles division by zero', () => {
  expect(safeDivide(10.0, 2.0)).toBe(5.0);  // Some(5.0) unwrapped
  expect(safeDivide(10.0, 0.0)).toBeUndefined();  // None becomes undefined
});
```

### Result Types

```rescript
// ReScript
type result<'ok, 'err> = Ok('ok) | Error('err)

let parse = (input: string): result<int, string> => {
  switch Belt.Int.fromString(input) {
  | Some(n) => Ok(n)
  | None => Error("Invalid number")
  }
}
```

```javascript
// Jest test
import { parse } from '../Parser.mjs';

test('parse returns Result', () => {
  const okResult = parse("42");
  expect(okResult.TAG).toBe(0);  // Ok variant
  expect(okResult._0).toBe(42);  // Ok value

  const errResult = parse("abc");
  expect(errResult.TAG).toBe(1);  // Error variant
  expect(errResult._0).toBe("Invalid number");  // Error value
});
```

### Variant Types

```rescript
// ReScript
type shape =
  | Circle(float)
  | Rectangle(float, float)

let area = (shape: shape): float => {
  switch shape {
  | Circle(r) => 3.14159 *. r *. r
  | Rectangle(w, h) => w *. h
  }
}
```

```javascript
// Jest test
import { Circle, Rectangle, area } from '../Geometry.mjs';

test('area calculation', () => {
  const circle = Circle(5.0);
  expect(area(circle)).toBeCloseTo(78.54, 2);

  const rect = Rectangle(4.0, 5.0);
  expect(area(rect)).toBe(20.0);
});
```

## Best Practices

1. **One test file per module**: `Module.res` → `Module.test.mjs`
2. **Use descriptive test names**: Explain what's being tested
3. **Test edge cases**: Empty inputs, boundary values, error conditions
4. **Group related tests**: Use `describe` blocks for organization
5. **Keep tests focused**: One assertion per test when possible
6. **Use beforeEach/afterEach**: For setup and teardown
7. **Mock external dependencies**: Use `jest.mock()` when needed

## CI/CD Integration

Tests run automatically in CI with coverage enforcement:

```bash
npm test -- --ci --coverage --maxWorkers=2
```

The build fails if coverage drops below 90%.

## Troubleshooting

### Tests not found
- Ensure test files have `.test.mjs` extension
- Check `testMatch` patterns in `jest.config.js`

### Import errors
- Run `npm run res:build` before testing
- Verify .mjs files exist next to .res files
- Check import paths match compiled output

### Coverage too low
- Add more test cases
- Remove dead code
- Test error paths and edge cases

### Type mismatches
- Remember: ReScript types compile to JavaScript runtime values
- Use `.TAG` to check variant discriminators
- Use `._0`, `._1` etc. for variant payloads
- `None` becomes `undefined`, `Some(x)` becomes `x`

## Example: Complete Test Suite

```javascript
import { describe, test, expect, beforeEach } from '@jest/globals';
import { Grid } from '../Grid.mjs';

describe('Grid Module', () => {
  let grid;

  beforeEach(() => {
    const lines = ['+---+', '|   |', '+---+'];
    grid = Grid.fromLines(lines);
  });

  describe('fromLines', () => {
    test('creates grid with correct dimensions', () => {
      expect(grid.width).toBe(5);
      expect(grid.height).toBe(3);
    });

    test('handles empty input', () => {
      const emptyGrid = Grid.fromLines([]);
      expect(emptyGrid.height).toBe(0);
    });
  });

  describe('get', () => {
    test('retrieves character at position', () => {
      const char = Grid.get(grid, { row: 0, col: 0 });
      expect(char).toBeDefined();
    });

    test('returns undefined for out-of-bounds', () => {
      const char = Grid.get(grid, { row: 10, col: 10 });
      expect(char).toBeUndefined();
    });
  });
});
```

## Additional Resources

- [Jest Documentation](https://jestjs.io/)
- [ReScript Documentation](https://rescript-lang.org/)
- [ReScript-JavaScript Interop](https://rescript-lang.org/docs/manual/latest/bind-to-js-function)
