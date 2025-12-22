# Test Plan: Wyreframe Parser Refactoring

**Project**: Wyreframe - ASCII Wireframe to HTML Converter
**Component**: Parser Architecture Refactoring to ReScript
**Version**: 0.1.0
**Date**: 2025-12-22
**Status**: In Progress

---

## Table of Contents

1. [Testing Philosophy](#1-testing-philosophy)
2. [Test Strategy](#2-test-strategy)
3. [Unit Test Specifications](#3-unit-test-specifications)
4. [Integration Test Specifications](#4-integration-test-specifications)
5. [Performance Test Specifications](#5-performance-test-specifications)
6. [Migration Validation Tests](#6-migration-validation-tests)
7. [Test Data Management](#7-test-data-management)
8. [Test Coverage Goals](#8-test-coverage-goals)
9. [Continuous Testing](#9-continuous-testing)
10. [Test Code Examples](#10-test-code-examples)

---

## 1. Testing Philosophy

### 1.1 Core Principles

**Test-Driven Development (TDD) Approach:**
- Write tests before implementation
- Red-Green-Refactor cycle
- Tests as living documentation

**Pyramid Testing Strategy:**
```
          ╱╲
         ╱E2E╲          ← Few, slow, expensive
        ╱─────╲
       ╱ Integ ╲        ← Some, moderate
      ╱─────────╲
     ╱   Unit    ╲      ← Many, fast, cheap
    ╱─────────────╲
```

**Key Testing Values:**
1. **Fast Feedback**: Unit tests run in milliseconds
2. **Isolated**: Each test is independent
3. **Repeatable**: Same input → same output
4. **Self-Validating**: Pass/fail without manual inspection
5. **Timely**: Written alongside code

### 1.2 Testing Framework

**Technology Stack:**
- **Test Framework**: Jest with `@glennsl/rescript-jest`
- **Coverage Tool**: Istanbul/Jest coverage
- **Performance**: Jest benchmarks + custom timing
- **Property Testing**: `fast-check` (when applicable)
- **Test Data**: Fixtures in `__tests__/fixtures/`

**ReScript Testing Benefits:**
- Type-safe test code
- Pattern matching for assertions
- Compile-time test validation
- Zero runtime type errors

---

## 2. Test Strategy

### 2.1 Test Levels

| Level | Scope | Tools | Coverage Target |
|-------|-------|-------|-----------------|
| **Unit** | Single function/module | Jest | ≥90% line coverage |
| **Integration** | Multiple modules | Jest | All critical paths |
| **End-to-End** | Full pipeline | Jest + Fixtures | All user scenarios |
| **Performance** | Speed/memory | Custom benchmarks | Meet requirements |
| **Regression** | Legacy compatibility | Comparison tool | 100% existing features |

### 2.2 Test Organization

```
src/parser/
├── Core/
│   ├── Position.res
│   └── __tests__/
│       ├── Position_test.res              # Unit tests
│       └── Position_property_test.res     # Property-based tests
│
├── Scanner/
│   ├── GridScanner.res
│   └── __tests__/
│       ├── GridScanner_test.res
│       └── GridScanner_integration_test.res
│
├── Detector/
│   ├── BoxTracer.res
│   └── __tests__/
│       ├── BoxTracer_test.res
│       ├── BoxTracer_error_test.res
│       └── ShapeDetector_integration_test.res
│
└── __tests__/
    ├── fixtures/
    │   ├── simple_box.txt
    │   ├── nested_boxes.txt
    │   ├── login_scene.txt
    │   └── complex_wireframe.txt
    │
    ├── e2e/
    │   ├── FullPipeline_test.res
    │   └── ErrorRecovery_test.res
    │
    └── performance/
        ├── ParsingSpeed_bench.res
        └── MemoryUsage_bench.res
```

### 2.3 Test Naming Convention

```rescript
// Pattern: test("{module}_{function}_{scenario}_{expected}")

describe("Position", () => {
  describe("right", () => {
    test("right_with_default_distance_moves_one_column", () => {
      // ...
    })

    test("right_with_custom_distance_moves_n_columns", () => {
      // ...
    })

    test("right_at_grid_boundary_stays_valid", () => {
      // ...
    })
  })
})
```

### 2.4 AAA Pattern (Arrange-Act-Assert)

All tests follow the AAA structure:

```rescript
test("grid_get_with_valid_position_returns_character", () => {
  // Arrange: Setup test data
  let lines = ["abc", "def"]
  let grid = Grid.fromLines(lines)
  let position = Position.make(0, 1)

  // Act: Execute the function under test
  let result = Grid.get(grid, position)

  // Assert: Verify the result
  expect(result)->toBe(Some(Char("b")))
})
```

---

## 3. Unit Test Specifications

### 3.1 Core Module Tests

#### 3.1.1 Position Module Tests

**Test File**: `src/parser/Core/__tests__/Position_test.res`

| Test ID | Description | Test Data | Expected Result | Edge Cases |
|---------|-------------|-----------|-----------------|------------|
| POS-01 | Create position with valid coordinates | `(0, 0)` | `{row: 0, col: 0}` | Negative values |
| POS-02 | Move right by default distance | `(5, 3).right()` | `{row: 5, col: 4}` | Boundary check |
| POS-03 | Move down with custom distance | `(2, 4).down(~n=3)` | `{row: 5, col: 4}` | Large distances |
| POS-04 | Move left without going negative | `(0, 0).left()` | `{row: 0, col: -1}` | Negative columns |
| POS-05 | Move up without going negative | `(0, 5).up()` | `{row: -1, col: 5}` | Negative rows |
| POS-06 | Compare positions for equality | `(1, 2)` vs `(1, 2)` | `true` | Different positions |
| POS-07 | Check position within bounds | `(5, 10)` in `{0-9, 0-19}` | `true` | Edge boundaries |
| POS-08 | Format position as string | `(3, 7)` | `"(3, 7)"` | Large numbers |

**Test Cases:**

```rescript
// POS-01: Create position with valid coordinates
describe("Position.make", () => {
  test("creates_position_with_positive_coordinates", () => {
    let pos = Position.make(5, 10)

    expect(pos.row)->toBe(5)
    expect(pos.col)->toBe(10)
  })

  test("allows_zero_coordinates", () => {
    let pos = Position.make(0, 0)

    expect(pos.row)->toBe(0)
    expect(pos.col)->toBe(0)
  })

  test("allows_negative_coordinates", () => {
    let pos = Position.make(-1, -5)

    expect(pos.row)->toBe(-1)
    expect(pos.col)->toBe(-5)
  })
})

// POS-02: Movement functions
describe("Position.right", () => {
  test("moves_one_column_right_by_default", () => {
    let pos = Position.make(5, 3)
    let moved = Position.right(pos)

    expect(moved)->toEqual(Position.make(5, 4))
  })

  test("moves_n_columns_right_with_parameter", () => {
    let pos = Position.make(2, 5)
    let moved = Position.right(pos, ~n=3)

    expect(moved)->toEqual(Position.make(2, 8))
  })
})

// POS-07: Boundary checking
describe("Position.isWithin", () => {
  test("returns_true_for_position_inside_bounds", () => {
    let pos = Position.make(5, 10)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

    expect(Position.isWithin(pos, bounds))->toBe(true)
  })

  test("returns_false_for_position_outside_bounds", () => {
    let pos = Position.make(15, 10)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

    expect(Position.isWithin(pos, bounds))->toBe(false)
  })

  test("returns_true_for_position_on_boundary", () => {
    let pos = Position.make(10, 20)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

    expect(Position.isWithin(pos, bounds))->toBe(true)
  })
})
```

#### 3.1.2 Bounds Module Tests

**Test File**: `src/parser/Core/__tests__/Bounds_test.res`

| Test ID | Description | Test Data | Expected Result | Edge Cases |
|---------|-------------|-----------|-----------------|------------|
| BND-01 | Create valid bounds | `top=0, left=0, bottom=5, right=10` | Valid bounds object | Invalid ordering |
| BND-02 | Calculate width | `left=5, right=15` | `10` | Zero width |
| BND-03 | Calculate height | `top=2, bottom=8` | `6` | Zero height |
| BND-04 | Calculate area | `5x10 box` | `50` | Zero area |
| BND-05 | Check complete containment | Box A contains Box B | `true` | Partial overlap |
| BND-06 | Check no containment | Disjoint boxes | `false` | Same bounds |
| BND-07 | Detect overlap | Overlapping boxes | `true` | Edge touching |
| BND-08 | Detect no overlap | Separate boxes | `false` | Adjacent boxes |

**Test Cases:**

```rescript
describe("Bounds", () => {
  describe("make", () => {
    test("creates_valid_bounds_with_correct_ordering", () => {
      let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=10)

      expect(bounds.top)->toBe(0)
      expect(bounds.left)->toBe(0)
      expect(bounds.bottom)->toBe(5)
      expect(bounds.right)->toBe(10)
    })

    test("allows_single_line_bounds", () => {
      let bounds = Bounds.make(~top=5, ~left=0, ~bottom=5, ~right=10)

      expect(Bounds.height(bounds))->toBe(0)
    })
  })

  describe("contains", () => {
    test("returns_true_when_outer_completely_contains_inner", () => {
      let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)
      let inner = Bounds.make(~top=2, ~left=5, ~bottom=8, ~right=15)

      expect(Bounds.contains(outer, inner))->toBe(true)
    })

    test("returns_false_for_partial_overlap", () => {
      let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=15)
      let box2 = Bounds.make(~top=5, ~left=10, ~bottom=15, ~right=25)

      expect(Bounds.contains(box1, box2))->toBe(false)
    })

    test("returns_false_for_identical_bounds", () => {
      let bounds1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)
      let bounds2 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)

      expect(Bounds.contains(bounds1, bounds2))->toBe(false)
    })
  })

  describe("overlaps", () => {
    test("returns_true_for_overlapping_boxes", () => {
      let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
      let box2 = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)

      expect(Bounds.overlaps(box1, box2))->toBe(true)
    })

    test("returns_false_for_adjacent_boxes", () => {
      let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
      let box2 = Bounds.make(~top=0, ~left=11, ~bottom=10, ~right=20)

      expect(Bounds.overlaps(box1, box2))->toBe(false)
    })
  })
})
```

#### 3.1.3 Grid Module Tests

**Test File**: `src/parser/Core/__tests__/Grid_test.res`

| Test ID | Description | Test Data | Expected Result | Edge Cases |
|---------|-------------|-----------|-----------------|------------|
| GRD-01 | Create grid from lines | `["abc", "def"]` | `3x2 grid` | Empty lines |
| GRD-02 | Normalize uneven line lengths | `["ab", "defg", "h"]` | All lines padded to 4 | Single char |
| GRD-03 | Get character at valid position | `grid[(1, 2)]` | `Some('f')` | Boundary |
| GRD-04 | Get character at invalid position | `grid[(-1, 5)]` | `None` | Out of bounds |
| GRD-05 | Get full line | `grid.getLine(1)` | `['d', 'e', 'f']` | Last line |
| GRD-06 | Get range within line | `grid.getRange(0, 1, 2)` | `['b', 'c']` | Full line |
| GRD-07 | Scan right with predicate | `scanRight` from (0, 0) | Array of positions | Hit boundary |
| GRD-08 | Scan down with predicate | `scanDown` from (0, 0) | Array of positions | Hit boundary |
| GRD-09 | Find all corners | `findAll(Corner)` | All '+' positions | No corners |
| GRD-10 | Build character index | Grid creation | Populated indices | Large grid |

**Test Cases:**

```rescript
describe("Grid", () => {
  describe("fromLines", () => {
    test("creates_grid_with_correct_dimensions", () => {
      let lines = ["abc", "def", "ghi"]
      let grid = Grid.fromLines(lines)

      expect(grid.width)->toBe(3)
      expect(grid.height)->toBe(3)
    })

    test("normalizes_uneven_line_lengths", () => {
      let lines = ["ab", "defg", "h"]
      let grid = Grid.fromLines(lines)

      expect(grid.width)->toBe(4)

      // Check padding
      switch Grid.get(grid, Position.make(0, 3)) {
      | Some(Space) => pass
      | _ => fail("Expected space padding")
      }
    })

    test("handles_empty_input", () => {
      let lines = []
      let grid = Grid.fromLines(lines)

      expect(grid.width)->toBe(0)
      expect(grid.height)->toBe(0)
    })
  })

  describe("get", () => {
    test("returns_character_at_valid_position", () => {
      let lines = ["abc", "def"]
      let grid = Grid.fromLines(lines)
      let pos = Position.make(1, 2)

      switch Grid.get(grid, pos) {
      | Some(Char("f")) => pass
      | _ => fail("Expected 'f'")
      }
    })

    test("returns_none_for_invalid_position", () => {
      let lines = ["abc"]
      let grid = Grid.fromLines(lines)
      let pos = Position.make(5, 10)

      expect(Grid.get(grid, pos))->toBe(None)
    })
  })

  describe("scanRight", () => {
    test("scans_until_predicate_fails", () => {
      let lines = ["+----+"]
      let grid = Grid.fromLines(lines)
      let start = Position.make(0, 0)

      let results = Grid.scanRight(grid, start, cell => {
        switch cell {
        | Corner | HLine => true
        | _ => false
        }
      })

      expect(Belt.Array.length(results))->toBe(6) // +, 4x-, +
    })

    test("stops_at_grid_boundary", () => {
      let lines = ["abcdef"]
      let grid = Grid.fromLines(lines)
      let start = Position.make(0, 0)

      let results = Grid.scanRight(grid, start, _ => true)

      expect(Belt.Array.length(results))->toBe(6)
    })
  })

  describe("findAll", () => {
    test("finds_all_corner_characters", () => {
      let lines = [
        "+----+",
        "|    |",
        "+----+"
      ]
      let grid = Grid.fromLines(lines)

      let corners = Grid.findAll(grid, Corner)

      expect(Belt.Array.length(corners))->toBe(4)
    })

    test("returns_empty_array_when_no_matches", () => {
      let lines = ["abc", "def"]
      let grid = Grid.fromLines(lines)

      let corners = Grid.findAll(grid, Corner)

      expect(Belt.Array.length(corners))->toBe(0)
    })
  })
})
```

### 3.2 Shape Detector Tests

#### 3.2.1 BoxTracer Module Tests

**Test File**: `src/parser/Detector/__tests__/BoxTracer_test.res`

| Test ID | Description | ASCII Input | Expected Result | Error Case |
|---------|-------------|-------------|-----------------|------------|
| BOX-01 | Trace simple rectangular box | `+---+\n\|   \|\n+---+` | Valid box with bounds | - |
| BOX-02 | Extract box name from top border | `+--Login--+` | name = "Login" | - |
| BOX-03 | Detect unclosed box (missing right) | `+---+\n\|   \|` | `UncloseBoxRight` error | Missing corner |
| BOX-04 | Detect unclosed box (missing bottom) | `+---+\n\|   \|` | `UncloseBoxBottom` error | Missing bottom |
| BOX-05 | Validate width mismatch | Top 5, Bottom 7 | `MismatchedWidth` error | Width diff |
| BOX-06 | Validate pipe alignment | Misaligned \| | `MisalignedPipe` error | Wrong column |
| BOX-07 | Trace box with divider bottom | `+=====+` | Valid box | - |
| BOX-08 | Handle nested box corners | Multiple + | Correct boundary | Ambiguity |

**Test Cases:**

```rescript
describe("BoxTracer", () => {
  describe("traceBox", () => {
    test("traces_simple_rectangular_box", () => {
      let input = `
+----+
|    |
+----+
`
      let grid = Grid.fromLines(Js.String2.split(input, "\n"))
      let topLeft = Position.make(1, 0) // Skip first empty line

      switch BoxTracer.traceBox(grid, topLeft) {
      | Ok(box) => {
          expect(box.bounds.top)->toBe(1)
          expect(box.bounds.left)->toBe(0)
          expect(box.bounds.bottom)->toBe(3)
          expect(box.bounds.right)->toBe(5)
        }
      | Error(_) => fail("Expected successful box trace")
      }
    })

    test("extracts_box_name_from_top_border", () => {
      let input = `
+--Login--+
|         |
+=========+
`
      let grid = Grid.fromLines(Js.String2.split(input, "\n"))
      let topLeft = Position.make(1, 0)

      switch BoxTracer.traceBox(grid, topLeft) {
      | Ok(box) => {
          expect(box.name)->toBe(Some("Login"))
        }
      | Error(_) => fail("Expected successful box trace")
      }
    })

    test("detects_unclosed_box_missing_right_corner", () => {
      let input = `
+----+
|    |
+----
`
      let grid = Grid.fromLines(Js.String2.split(input, "\n"))
      let topLeft = Position.make(1, 0)

      switch BoxTracer.traceBox(grid, topLeft) {
      | Error(UncloseBoxBottom(_)) => pass
      | _ => fail("Expected UncloseBoxBottom error")
      }
    })

    test("detects_width_mismatch", () => {
      let input = `
+----+
|    |
+------+
`
      let grid = Grid.fromLines(Js.String2.split(input, "\n"))
      let topLeft = Position.make(1, 0)

      switch BoxTracer.traceBox(grid, topLeft) {
      | Error(MismatchedWidth({topWidth, bottomWidth})) => {
          expect(topWidth)->toBe(5)
          expect(bottomWidth)->toBe(7)
        }
      | _ => fail("Expected MismatchedWidth error")
      }
    })
  })
})
```

#### 3.2.2 HierarchyBuilder Module Tests

**Test File**: `src/parser/Detector/__tests__/HierarchyBuilder_test.res`

| Test ID | Description | Box Configuration | Expected Hierarchy | Error Case |
|---------|-------------|-------------------|-------------------|------------|
| HIE-01 | Build 2-level nesting | Outer contains Inner | Inner is child of Outer | - |
| HIE-02 | Build 3-level nesting | A > B > C | C child of B, B child of A | - |
| HIE-03 | Handle sibling boxes | A, B both in root | Both have no parent | - |
| HIE-04 | Detect overlapping boxes | A overlaps B partially | `OverlappingBoxes` error | Partial overlap |
| HIE-05 | Find smallest parent | Multiple containers | Immediate parent chosen | - |
| HIE-06 | Handle identical bounds | Same coordinates | Error or special handling | Edge case |

**Test Cases:**

```rescript
describe("HierarchyBuilder", () => {
  describe("buildHierarchy", () => {
    test("builds_simple_parent_child_relationship", () => {
      let outer = {
        name: Some("Outer"),
        bounds: Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20),
        children: []
      }

      let inner = {
        name: Some("Inner"),
        bounds: Bounds.make(~top=2, ~left=5, ~bottom=8, ~right=15),
        children: []
      }

      let boxes = [outer, inner]

      switch HierarchyBuilder.buildHierarchy(boxes) {
      | Ok(roots) => {
          expect(Belt.Array.length(roots))->toBe(1)
          expect(Belt.Array.length(roots[0].children))->toBe(1)
          expect(roots[0].children[0].name)->toBe(Some("Inner"))
        }
      | Error(_) => fail("Expected successful hierarchy build")
      }
    })

    test("handles_three_level_nesting", () => {
      let grandparent = {
        name: Some("A"),
        bounds: Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=30),
        children: []
      }

      let parent = {
        name: Some("B"),
        bounds: Bounds.make(~top=2, ~left=2, ~bottom=18, ~right=28),
        children: []
      }

      let child = {
        name: Some("C"),
        bounds: Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=25),
        children: []
      }

      let boxes = [grandparent, parent, child]

      switch HierarchyBuilder.buildHierarchy(boxes) {
      | Ok(roots) => {
          expect(Belt.Array.length(roots))->toBe(1)
          expect(roots[0].name)->toBe(Some("A"))
          expect(Belt.Array.length(roots[0].children))->toBe(1)
          expect(roots[0].children[0].name)->toBe(Some("B"))
          expect(Belt.Array.length(roots[0].children[0].children))->toBe(1)
          expect(roots[0].children[0].children[0].name)->toBe(Some("C"))
        }
      | Error(_) => fail("Expected successful hierarchy build")
      }
    })

    test("detects_overlapping_boxes", () => {
      let box1 = {
        name: Some("Box1"),
        bounds: Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=15),
        children: []
      }

      let box2 = {
        name: Some("Box2"),
        bounds: Bounds.make(~top=5, ~left=10, ~bottom=15, ~right=25),
        children: []
      }

      let boxes = [box1, box2]

      switch HierarchyBuilder.buildHierarchy(boxes) {
      | Error(OverlappingBoxes(_)) => pass
      | _ => fail("Expected OverlappingBoxes error")
      }
    })
  })
})
```

### 3.3 Semantic Parser Tests

#### 3.3.1 Element Parser Tests

**Test File**: `src/parser/Semantic/Elements/__tests__/ButtonParser_test.res`

| Test ID | Description | Input Text | Expected Element | Error Case |
|---------|-------------|------------|------------------|------------|
| BTN-01 | Parse standard button | `[ Submit ]` | Button with text "Submit" | - |
| BTN-02 | Parse button with extra spaces | `[  OK  ]` | Button with text "OK" | - |
| BTN-03 | Generate slugified ID | `[ Sign Up ]` | id = "sign-up" | - |
| BTN-04 | Reject empty button text | `[    ]` | None or error | Empty text |
| BTN-05 | Handle nested brackets | `[[ Test ]]` | Correct parsing | Ambiguity |

**Test Cases:**

```rescript
describe("ButtonParser", () => {
  let parser = ParserRegistry.makeButtonParser()

  describe("canParse", () => {
    test("recognizes_valid_button_syntax", () => {
      expect(parser.canParse("[ Submit ]"))->toBe(true)
    })

    test("rejects_non_button_text", () => {
      expect(parser.canParse("#email"))->toBe(false)
      expect(parser.canParse("plain text"))->toBe(false)
    })
  })

  describe("parse", () => {
    test("extracts_button_text", () => {
      let position = Position.make(5, 10)
      let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

      switch parser.parse("  [ Login ]  ", position, bounds) {
      | Some(Button({text, id})) => {
          expect(text)->toBe("Login")
          expect(id)->toBe("login")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("trims_whitespace_from_button_text", () => {
      let position = Position.make(0, 0)
      let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

      switch parser.parse("[  Sign Up  ]", position, bounds) {
      | Some(Button({text})) => {
          expect(text)->toBe("Sign Up")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("returns_none_for_empty_button", () => {
      let position = Position.make(0, 0)
      let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

      let result = parser.parse("[     ]", position, bounds)

      expect(result)->toBe(None)
    })
  })
})
```

Similar test specifications for:
- **InputParser_test.res** (5 test cases)
- **LinkParser_test.res** (5 test cases)
- **CheckboxParser_test.res** (6 test cases)
- **EmphasisParser_test.res** (4 test cases)
- **TextParser_test.res** (3 test cases - fallback)

#### 3.3.2 AlignmentCalc Tests

**Test File**: `src/parser/Semantic/__tests__/AlignmentCalc_test.res`

| Test ID | Description | Content Position | Box Bounds | Expected Alignment |
|---------|-------------|------------------|------------|-------------------|
| ALN-01 | Left-aligned content | Near left edge | Standard box | Left |
| ALN-02 | Right-aligned content | Near right edge | Standard box | Right |
| ALN-03 | Center-aligned content | Middle | Standard box | Center |
| ALN-04 | Edge case: exact center | Perfect center | Standard box | Center |
| ALN-05 | Default alignment | Ambiguous position | Standard box | Left (default) |
| ALN-06 | Narrow box handling | Any position | Width < 5 | Left |

**Test Cases:**

```rescript
describe("AlignmentCalc", () => {
  describe("calculate", () => {
    test("returns_left_for_content_near_left_edge", () => {
      let content = "Hello"
      let position = Position.make(5, 2) // Close to left
      let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

      let alignment = AlignmentCalc.calculate(content, position, boxBounds)

      expect(alignment)->toBe(Left)
    })

    test("returns_right_for_content_near_right_edge", () => {
      let content = "Hello"
      let position = Position.make(5, 24) // Close to right
      let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

      let alignment = AlignmentCalc.calculate(content, position, boxBounds)

      expect(alignment)->toBe(Right)
    })

    test("returns_center_for_content_in_middle", () => {
      let content = "Hello"
      let position = Position.make(5, 12) // Center
      let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

      let alignment = AlignmentCalc.calculate(content, position, boxBounds)

      expect(alignment)->toBe(Center)
    })

    test("defaults_to_left_for_ambiguous_positioning", () => {
      let content = "Hello"
      let position = Position.make(5, 10)
      let boxBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

      let alignment = AlignmentCalc.calculate(content, position, boxBounds)

      // Should default to Left if ratios are not clear
      expect(alignment)->toBe(Left)
    })
  })
})
```

### 3.4 Error System Tests

#### 3.4.1 Error Types Tests

**Test File**: `src/parser/Errors/__tests__/ErrorTypes_test.res`

| Test ID | Description | Error Code | Expected Severity | Context Data |
|---------|-------------|------------|-------------------|--------------|
| ERR-01 | Create UncloseBox error | `UncloseBox` | Error | Position, direction |
| ERR-02 | Create MismatchedWidth error | `MismatchedWidth` | Error | Widths, position |
| ERR-03 | Create UnusualSpacing warning | `UnusualSpacing` | Warning | Position, issue |
| ERR-04 | Auto-determine severity | Any error code | Correct | - |
| ERR-05 | Include position in all errors | All codes | Position present | - |

**Test Cases:**

```rescript
describe("ErrorTypes", () => {
  describe("getSeverity", () => {
    test("returns_error_for_structural_errors", () => {
      let code = UncloseBox({corner: Position.make(0, 0), direction: "top"})

      expect(ErrorTypes.getSeverity(code))->toBe(Error)
    })

    test("returns_warning_for_style_issues", () => {
      let code = UnusualSpacing({position: Position.make(5, 10), issue: "tab character"})

      expect(ErrorTypes.getSeverity(code))->toBe(Warning)
    })
  })

  describe("make", () => {
    test("creates_error_with_all_fields", () => {
      let code = MismatchedWidth({
        topLeft: Position.make(0, 0),
        topWidth: 10,
        bottomWidth: 12
      })
      let grid = Grid.fromLines(["test"])

      let error = ErrorTypes.make(code, grid)

      expect(error.code)->toBe(code)
      expect(error.severity)->toBe(Error)
    })
  })
})
```

#### 3.4.2 Error Message Templates Tests

**Test File**: `src/parser/Errors/__tests__/ErrorMessages_test.res`

| Test ID | Description | Error Type | Template Content | Verification |
|---------|-------------|------------|------------------|--------------|
| MSG-01 | Natural language for UncloseBox | `UncloseBox` | Clear Korean message | Readability |
| MSG-02 | Include solution section | All errors | "💡 Solution" present | Format |
| MSG-03 | Interpolate position data | Position errors | Row/col numbers | Accuracy |
| MSG-04 | Format code snippets | All errors | Line numbers, arrows | Visual clarity |
| MSG-05 | Use appropriate emoji | Errors vs warnings | ❌ vs ⚠️ | Consistency |

**Test Cases:**

```rescript
describe("ErrorMessages", () => {
  describe("getTemplate", () => {
    test("provides_clear_message_for_unclosed_box", () => {
      let code = UncloseBox({corner: Position.make(2, 0), direction: "right"})

      let template = ErrorMessages.getTemplate(code)

      expect(Js.String2.includes(template.title, "Unclosed"))->toBe(true)
      expect(Js.String2.includes(template.solution, "💡"))->toBe(true)
    })

    test("includes_both_widths_for_mismatch_error", () => {
      let code = MismatchedWidth({
        topLeft: Position.make(0, 0),
        topWidth: 10,
        bottomWidth: 12
      })

      let template = ErrorMessages.getTemplate(code)

      expect(Js.String2.includes(template.message, "10"))->toBe(true)
      expect(Js.String2.includes(template.message, "12"))->toBe(true)
    })
  })

  describe("format", () => {
    test("produces_complete_formatted_error_message", () => {
      let code = MisalignedPipe({
        position: Position.make(5, 10),
        expected: 8,
        actual: 10
      })
      let grid = Grid.fromLines([
        "+--------+",
        "|        |",
        "|      Wrong|",
        "+--------+"
      ])
      let error = ErrorTypes.make(code, grid)

      let formatted = ErrorMessages.format(error)

      expect(Js.String2.includes(formatted, "❌"))->toBe(true) // Error emoji
      expect(Js.String2.includes(formatted, "→"))->toBe(true) // Line indicator
      expect(Js.String2.includes(formatted, "💡"))->toBe(true) // Solution
    })
  })
})
```

---

## 4. Integration Test Specifications

### 4.1 Shape Detection Pipeline Tests

**Test File**: `src/parser/Detector/__tests__/ShapeDetector_integration_test.res`

**Test Scenarios:**

| Scenario | Input Wireframe | Expected Shapes | Validation Points |
|----------|----------------|-----------------|-------------------|
| Simple single box | 3x3 box | 1 box, no children | Bounds, name |
| Two sibling boxes | Side-by-side boxes | 2 boxes, no parent | Both at root level |
| Nested boxes (2 levels) | Box within box | 2 boxes, 1 child | Parent-child link |
| Nested boxes (3 levels) | A > B > C | 3 boxes, chain | Full hierarchy |
| Box with dividers | Box with === lines | 1 box, 2 dividers | Divider positions |
| Named boxes | +--Name--+ | Names extracted | All names present |
| Malformed box | Missing corner | Error detected | Specific error type |

**Test Cases:**

```rescript
describe("ShapeDetector Integration", () => {
  test("detects_simple_single_box", () => {
    let wireframe = `
+-------+
| Hello |
+-------+
`
    let grid = Grid.fromLines(Js.String2.split(wireframe, "\n"))

    switch ShapeDetector.detect(grid) {
    | Ok(shapes) => {
        expect(Belt.Array.length(shapes))->toBe(1)
        expect(shapes[0].name)->toBe(None)
        expect(Belt.Array.length(shapes[0].children))->toBe(0)
      }
    | Error(_) => fail("Expected successful detection")
    }
  })

  test("detects_nested_boxes_with_correct_hierarchy", () => {
    let wireframe = `
+--Outer-------+
|              |
| +--Inner--+  |
| |         |  |
| +---------+  |
|              |
+--------------+
`
    let grid = Grid.fromLines(Js.String2.split(wireframe, "\n"))

    switch ShapeDetector.detect(grid) {
    | Ok(shapes) => {
        expect(Belt.Array.length(shapes))->toBe(1) // Root level
        expect(shapes[0].name)->toBe(Some("Outer"))
        expect(Belt.Array.length(shapes[0].children))->toBe(1)
        expect(shapes[0].children[0].name)->toBe(Some("Inner"))
      }
    | Error(_) => fail("Expected successful detection")
    }
  })

  test("detects_multiple_sibling_boxes", () => {
    let wireframe = `
+--Box1--+    +--Box2--+
|        |    |        |
+--------+    +--------+
`
    let grid = Grid.fromLines(Js.String2.split(wireframe, "\n"))

    switch ShapeDetector.detect(grid) {
    | Ok(shapes) => {
        expect(Belt.Array.length(shapes))->toBe(2)
        expect(shapes[0].name)->toBe(Some("Box1"))
        expect(shapes[1].name)->toBe(Some("Box2"))
      }
    | Error(_) => fail("Expected successful detection")
    }
  })
})
```

### 4.2 End-to-End Parsing Tests

**Test File**: `src/parser/__tests__/e2e/FullPipeline_test.res`

**Test Scenarios:**

| Scenario | Complete Wireframe | Expected AST | Validation |
|----------|-------------------|--------------|------------|
| Login scene | Email input + button | 1 scene, 2 elements | Element types correct |
| Multi-scene wireframe | 3 scenes with separator | 3 scenes | Scene IDs, transitions |
| Nested elements | Buttons in sections | Hierarchical elements | Nesting preserved |
| All element types | Button, input, link, checkbox, emphasis | All parsed | Type variety |
| With interactions | Wireframe + DSL | Merged AST | Properties attached |
| With errors | Malformed input | Partial AST + errors | Error collection |

**Test Cases:**

```rescript
describe("End-to-End Parsing", () => {
  test("parses_complete_login_scene", () => {
    let wireframe = `
@scene: login
@title: Login Page

+--Login----------------+
|                       |
|  * Welcome            |
|                       |
|  Email: #email        |
|                       |
|  Password: #password  |
|                       |
|     [ Login ]         |
|                       |
+-----------------------+
`

    switch WyreframeParser.parse(wireframe, None) {
    | Ok(ast) => {
        expect(Belt.Array.length(ast.scenes))->toBe(1)

        let scene = ast.scenes[0]
        expect(scene.id)->toBe("login")
        expect(scene.title)->toBe("Login Page")

        // Check elements
        let elements = scene.elements
        let hasEmphasis = Belt.Array.some(elements, el => {
          switch el {
          | Text({emphasis: true}) => true
          | _ => false
          }
        })
        let hasInputs = Belt.Array.some(elements, el => {
          switch el {
          | Input({id}) => id == "email" || id == "password"
          | _ => false
          }
        })
        let hasButton = Belt.Array.some(elements, el => {
          switch el {
          | Button({text}) => text == "Login"
          | _ => false
          }
        })

        expect(hasEmphasis)->toBe(true)
        expect(hasInputs)->toBe(true)
        expect(hasButton)->toBe(true)
      }
    | Error(errors) => {
        Js.Console.error(errors)
        fail("Expected successful parse")
      }
    }
  })

  test("parses_multi_scene_wireframe", () => {
    let wireframe = `
@scene: home
+--------+
| Home   |
+--------+

---

@scene: settings
+--------+
| Config |
+--------+
`

    switch WyreframeParser.parse(wireframe, None) {
    | Ok(ast) => {
        expect(Belt.Array.length(ast.scenes))->toBe(2)
        expect(ast.scenes[0].id)->toBe("home")
        expect(ast.scenes[1].id)->toBe("settings")
      }
    | Error(_) => fail("Expected successful parse")
    }
  })

  test("handles_errors_gracefully_and_continues_parsing", () => {
    let wireframe = `
@scene: test

+--Good Box--+
|            |
+------------+

+--Bad Box---+
|            |
+----------    <- Missing corner

+--Another Good--+
|                |
+----------------+
`

    switch WyreframeParser.parse(wireframe, None) {
    | Ok(ast) => {
        // Should have partial AST with good boxes
        expect(Belt.Array.length(ast.scenes))->toBe(1)
      }
    | Error(errors) => {
        // Should collect errors but not crash
        expect(Belt.Array.length(errors))->toBeGreaterThan(0)
      }
    }
  })
})
```

### 4.3 Error Recovery Tests

**Test File**: `src/parser/__tests__/e2e/ErrorRecovery_test.res`

**Test Scenarios:**

| Scenario | Error Type | Expected Behavior | Validation |
|----------|-----------|-------------------|------------|
| Single unclosed box | Structural | Report error, continue | Error + partial AST |
| Multiple errors | Mixed | Collect all errors | Error list |
| Error in nested box | Structural | Skip problematic box | Outer box OK |
| Invalid element syntax | Semantic | Treat as text | Fallback parsing |
| Warning + error | Mixed severity | Both reported | Severity correct |

---

## 5. Performance Test Specifications

### 5.1 Parsing Speed Benchmarks

**Test File**: `src/parser/__tests__/performance/ParsingSpeed_bench.res`

**Benchmark Requirements:**

| Wireframe Size | Lines | Characters | Max Time | Target Time |
|----------------|-------|------------|----------|-------------|
| Small | 10-50 | 500-2500 | 10ms | 5ms |
| Medium | 100-500 | 5K-25K | 50ms | 30ms |
| Large | 500-2000 | 25K-100K | 200ms | 150ms |
| Very Large | 2000-5000 | 100K-250K | 1000ms | 700ms |

**Test Cases:**

```rescript
describe("Parsing Speed Benchmarks", () => {
  test("parses_small_wireframe_under_10ms", () => {
    let wireframe = generateWireframe(~boxes=5, ~elementsPerBox=3)

    let start = Js.Date.now()
    let _ = WyreframeParser.parse(wireframe, None)
    let duration = Js.Date.now() -. start

    expect(duration)->toBeLessThan(10.0)
  })

  test("parses_medium_wireframe_under_50ms", () => {
    let wireframe = generateWireframe(~boxes=20, ~elementsPerBox=8)

    let start = Js.Date.now()
    let _ = WyreframeParser.parse(wireframe, None)
    let duration = Js.Date.now() -. start

    expect(duration)->toBeLessThan(50.0)
  })

  test("parses_large_wireframe_under_200ms", () => {
    let wireframe = generateWireframe(~boxes=100, ~elementsPerBox=10)

    let start = Js.Date.now()
    let _ = WyreframeParser.parse(wireframe, None)
    let duration = Js.Date.now() -. start

    expect(duration)->toBeLessThan(200.0)
  })

  test("maintains_linear_time_complexity", () => {
    let sizes = [100, 200, 400, 800]
    let times = []

    Belt.Array.forEach(sizes, size => {
      let wireframe = generateWireframe(~boxes=size / 10, ~elementsPerBox=5)

      let start = Js.Date.now()
      let _ = WyreframeParser.parse(wireframe, None)
      let duration = Js.Date.now() -. start

      times->Js.Array2.push(duration)->ignore
    })

    // Check that doubling size roughly doubles time (±30% tolerance)
    for i in 0 to Belt.Array.length(times) - 2 {
      let ratio = times[i + 1] /. times[i]
      expect(ratio)->toBeGreaterThan(1.4) // At least 1.4x slower
      expect(ratio)->toBeLessThan(2.6) // At most 2.6x slower
    }
  })
})
```

### 5.2 Memory Usage Tests

**Test File**: `src/parser/__tests__/performance/MemoryUsage_bench.res`

**Memory Requirements:**

| Wireframe Size | Lines | Max Heap | Target Heap |
|----------------|-------|----------|-------------|
| Small | 100 | 5MB | 2MB |
| Medium | 500 | 15MB | 10MB |
| Large | 2000 | 50MB | 35MB |

**Test Cases:**

```rescript
describe("Memory Usage Benchmarks", () => {
  test("stays_under_50MB_for_large_wireframes", () => {
    let wireframe = generateWireframe(~boxes=100, ~elementsPerBox=15)

    // Measure heap before
    let heapBefore = Js.Global.process["memoryUsage"]()["heapUsed"]

    let _ = WyreframeParser.parse(wireframe, None)

    // Measure heap after
    let heapAfter = Js.Global.process["memoryUsage"]()["heapUsed"]

    let heapDelta = (heapAfter - heapBefore) / 1024.0 / 1024.0 // MB

    expect(heapDelta)->toBeLessThan(50.0)
  })

  test("releases_memory_after_parsing", () => {
    let wireframe = generateWireframe(~boxes=50, ~elementsPerBox=10)

    // Parse multiple times
    for _ in 1 to 10 {
      let _ = WyreframeParser.parse(wireframe, None)
    }

    // Force GC if available
    if %external(global.gc) {
      %external(global.gc)()
    }

    let finalHeap = Js.Global.process["memoryUsage"]()["heapUsed"]

    // Memory should not grow unbounded
    expect(finalHeap)->toBeLessThan(100_000_000) // 100MB
  })
})
```

---

## 6. Migration Validation Tests

### 6.1 Compatibility Tests

**Test File**: `src/parser/__tests__/ParserComparison_test.res`

**Test Strategy:**
Run both legacy and new parser on the same inputs and compare outputs.

**Comparison Dimensions:**
- Scene count
- Element count by type
- Element IDs
- Element positions
- Alignment values
- Error count and types

**Test Cases:**

```rescript
describe("Parser Compatibility", () => {
  test("produces_same_scene_count_as_legacy", () => {
    let wireframe = loadFixture("fixtures/login_scene.txt")

    let legacyResult = LegacyParserInterop.parseLegacy(wireframe, None)
    let newResult = WyreframeParser.parse(wireframe, None)

    switch (legacyResult, newResult) {
    | (Ok(legacyAst), Ok(newAst)) => {
        expect(Belt.Array.length(legacyAst.scenes))
          ->toBe(Belt.Array.length(newAst.scenes))
      }
    | _ => fail("Both parsers should succeed on valid input")
    }
  })

  test("detects_same_elements_as_legacy", () => {
    let wireframe = loadFixture("fixtures/complex_form.txt")

    let legacyResult = LegacyParserInterop.parseLegacy(wireframe, None)
    let newResult = WyreframeParser.parse(wireframe, None)

    switch (legacyResult, newResult) {
    | (Ok(legacyAst), Ok(newAst)) => {
        let legacyElements = flattenElements(legacyAst.scenes[0].elements)
        let newElements = flattenElements(newAst.scenes[0].elements)

        expect(Belt.Array.length(legacyElements))
          ->toBe(Belt.Array.length(newElements))
      }
    | _ => fail("Both parsers should succeed")
    }
  })

  test("provides_better_error_messages_than_legacy", () => {
    let wireframe = `
+--Malformed--+
|             |
+----------     <- Missing corner
`

    let legacyResult = LegacyParserInterop.parseLegacy(wireframe, None)
    let newResult = WyreframeParser.parse(wireframe, None)

    switch (legacyResult, newResult) {
    | (Error(legacyErrors), Error(newErrors)) => {
        // New parser should provide more detailed error
        let newErrorMessage = ErrorMessages.format(newErrors[0])
        let legacyErrorMessage = legacyErrors[0].message

        expect(Js.String2.length(newErrorMessage))
          ->toBeGreaterThan(Js.String2.length(legacyErrorMessage))
      }
    | _ => ()
    }
  })
})
```

### 6.2 Regression Test Suite

**Test File**: `src/parser/__tests__/regression/RegressionTests_test.res`

**Approach:**
- Collect all existing test wireframes from legacy codebase
- Run new parser on each
- Verify no regressions (equal or better results)

**Test Coverage:**
- All element types
- All nesting levels (1-4)
- All alignment cases
- All scene directives
- Error cases

---

## 7. Test Data Management

### 7.1 Fixture Organization

```
src/parser/__tests__/fixtures/
├── simple/
│   ├── single_box.txt
│   ├── single_box_with_name.txt
│   ├── empty_box.txt
│   └── box_with_divider.txt
│
├── nested/
│   ├── two_level_nesting.txt
│   ├── three_level_nesting.txt
│   ├── siblings_with_parent.txt
│   └── complex_hierarchy.txt
│
├── elements/
│   ├── all_buttons.txt
│   ├── all_inputs.txt
│   ├── mixed_elements.txt
│   └── emphasis_text.txt
│
├── scenes/
│   ├── single_scene.txt
│   ├── multi_scene.txt
│   ├── scene_with_transitions.txt
│   └── complex_flow.txt
│
├── errors/
│   ├── unclosed_box.txt
│   ├── mismatched_width.txt
│   ├── misaligned_pipes.txt
│   └── overlapping_boxes.txt
│
└── real_world/
    ├── login_form.txt
    ├── dashboard.txt
    ├── settings_page.txt
    └── wizard_flow.txt
```

### 7.2 Fixture Loader Utility

```rescript
module FixtureLoader = {
  let loadFixture = (path: string): string => {
    let fullPath = `__tests__/fixtures/${path}`
    Node.Fs.readFileAsUtf8Sync(fullPath)
  }

  let loadExpectedAST = (path: string): ast => {
    let fullPath = `__tests__/fixtures/expected/${path}.json`
    let json = Node.Fs.readFileAsUtf8Sync(fullPath)
    parseASTFromJSON(json)
  }
}
```

### 7.3 Test Data Generation

```rescript
module TestDataGenerator = {
  type boxConfig = {
    width: int,
    height: int,
    name: option<string>,
    elements: array<string>,
    children: array<boxConfig>,
  }

  let generateBox = (config: boxConfig): string => {
    // Generate ASCII box from config
    // ...
  }

  let generateWireframe = (
    ~boxes: int,
    ~elementsPerBox: int,
    ~nestingDepth: int=1,
  ): string => {
    // Generate random valid wireframe
    // ...
  }

  let generateInvalidWireframe = (
    ~errorType: errorCode
  ): string => {
    // Generate wireframe with specific error
    // ...
  }
}
```

---

## 8. Test Coverage Goals

### 8.1 Coverage Targets

| Component | Line Coverage | Branch Coverage | Function Coverage |
|-----------|---------------|-----------------|-------------------|
| **Core Modules** | ≥95% | ≥90% | 100% |
| **Grid Scanner** | ≥95% | ≥90% | 100% |
| **Shape Detector** | ≥90% | ≥85% | 100% |
| **Semantic Parser** | ≥90% | ≥85% | 100% |
| **Error System** | ≥95% | ≥90% | 100% |
| **Interaction DSL** | ≥85% | ≥80% | 95% |
| **Overall** | ≥90% | ≥85% | ≥98% |

### 8.2 Coverage Tools Configuration

```json
// jest.config.js
{
  "collectCoverageFrom": [
    "src/parser/**/*.res",
    "!src/parser/**/__tests__/**",
    "!src/parser/**/*.test.res"
  ],
  "coverageThresholds": {
    "global": {
      "branches": 85,
      "functions": 98,
      "lines": 90,
      "statements": 90
    }
  },
  "coverageReporters": ["text", "html", "lcov"]
}
```

### 8.3 Coverage Reporting

- **Local Development**: `npm run test:coverage`
- **CI/CD**: Automated coverage reports on every PR
- **Coverage Badge**: Display in README
- **Trend Tracking**: Monitor coverage over time

---

## 9. Continuous Testing

### 9.1 Test Automation

**Pre-commit Hooks:**
```bash
# .husky/pre-commit
#!/bin/sh
npm run test:unit
```

**CI/CD Pipeline:**
```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
      - run: npm install
      - run: npm run res:build
      - run: npm run test:all
      - run: npm run test:coverage
      - uses: codecov/codecov-action@v2
```

### 9.2 Test Execution Strategy

| Stage | Tests Run | Frequency | Duration |
|-------|-----------|-----------|----------|
| **Development** | Unit tests for changed files | On save | <1s |
| **Pre-commit** | All unit tests | Before commit | <10s |
| **PR Build** | All tests + coverage | On push | <5min |
| **Nightly** | All tests + performance + regression | Daily | <30min |

### 9.3 Test Parallelization

```json
// jest.config.js
{
  "maxWorkers": "50%",
  "testPathIgnorePatterns": [
    "/node_modules/",
    "/lib/"
  ]
}
```

---

## 10. Test Code Examples

See `test-examples.test.res` for complete, runnable ReScript test code examples covering:

1. **Unit Tests**: Position, Bounds, Grid, BoxTracer
2. **Integration Tests**: Full pipeline parsing
3. **Property-Based Tests**: Grid normalization
4. **Performance Tests**: Parsing speed benchmarks

---

## Appendix A: Test Utilities

### A.1 Custom Matchers

```rescript
module CustomMatchers = {
  let toHaveLength = (array, expected) => {
    Belt.Array.length(array) == expected
  }

  let toContainElement = (array, element) => {
    Belt.Array.some(array, x => x == element)
  }

  let toMatchBounds = (bounds, expected) => {
    bounds.top == expected.top &&
    bounds.left == expected.left &&
    bounds.bottom == expected.bottom &&
    bounds.right == expected.right
  }
}
```

### A.2 Test Helpers

```rescript
module TestHelpers = {
  let makeSimpleGrid = (lines: array<string>): Grid.t => {
    Grid.fromLines(lines)
  }

  let makeSimpleBox = (
    ~top: int,
    ~left: int,
    ~bottom: int,
    ~right: int,
    ~name: option<string>=None
  ): box => {
    {
      name,
      bounds: Bounds.make(~top, ~left, ~bottom, ~right),
      children: []
    }
  }

  let extractElementTypes = (elements: array<element>): array<string> => {
    Belt.Array.map(elements, el => {
      switch el {
      | Box(_) => "box"
      | Button(_) => "button"
      | Input(_) => "input"
      | Link(_) => "link"
      | Checkbox(_) => "checkbox"
      | Text(_) => "text"
      | Divider(_) => "divider"
      | Row(_) => "row"
      | Section(_) => "section"
      }
    })
  }
}
```

---

## Appendix B: Testing Best Practices

1. **Test Naming**: Use descriptive names that explain the scenario
2. **Test Independence**: Each test should run in isolation
3. **Test Data**: Use realistic, meaningful test data
4. **Assertions**: One logical assertion per test
5. **Test Organization**: Group related tests with `describe` blocks
6. **Error Messages**: Provide helpful failure messages
7. **Test Coverage**: Aim for edge cases, not just happy paths
8. **Performance**: Keep unit tests fast (<100ms each)
9. **Maintenance**: Update tests when requirements change
10. **Documentation**: Comment complex test logic

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| **AAA Pattern** | Arrange-Act-Assert test structure |
| **Fixture** | Predefined test data |
| **Mock** | Simulated object for testing |
| **Stub** | Simplified implementation for testing |
| **Coverage** | Percentage of code exercised by tests |
| **Regression** | Previously working feature breaks |
| **Integration Test** | Test combining multiple components |
| **E2E Test** | Test simulating complete user workflow |
| **Property Test** | Test with randomly generated inputs |
| **Benchmark** | Performance measurement test |

---

## Appendix D: SemanticParser Test Cases

This appendix contains detailed test cases for the SemanticParser module.

### Test Cases Overview

| Case ID | Feature Description | Test Type |
|---------|---------------------|-----------|
| SP-01 | Simple Login Scene Parsing | Positive Test |
| SP-02 | Multiple Scenes Parsing | Positive Test |
| SP-03 | Nested Boxes Structure | Positive Test |
| SP-04 | Horizontal Dividers | Positive Test |
| SP-05 | All Element Types Recognition | Positive Test |
| SP-06 | Element Alignment Calculation | Positive Test |
| SP-07 | Button Element Parsing | Positive Test |
| SP-08 | Input Field Parsing | Positive Test |
| SP-09 | Link Element Parsing | Positive Test |
| SP-10 | Checkbox Element Parsing | Positive Test |
| SP-11 | Emphasis Text Parsing | Positive Test |
| SP-12 | Mixed Content Scene | Integration Test |
| SP-13 | Complex Nested Structure | Integration Test |
| SP-14 | Scene Directives Parsing | Positive Test |
| SP-15 | Empty Scene Handling | Edge Case Test |

### SP-01: Simple Login Scene Parsing

**Test Data:**
```
@scene: login
@title: Login Page

+--Login----------------+
|                       |
|  * Welcome            |
|                       |
|  Email: #email        |
|                       |
|  Password: #password  |
|                       |
|     [ Login ]         |
|                       |
+-----------------------+
```

**Expected Results:**
- AST contains exactly 1 scene
- Scene ID is "login", title is "Login Page"
- Scene contains emphasis text, 2 inputs, 1 button

### SP-03: Nested Boxes Structure

**Test Data:**
```
@scene: nested

+--Outer--------------+
|                     |
|  +--Inner-------+  |
|  |              |  |
|  |  [ Button ]  |  |
|  |              |  |
|  +--------------+  |
|                     |
+---------------------+
```

**Expected Results:**
- Outer box contains inner box in children array
- Inner box contains button element
- Box names are extracted ("Outer", "Inner")

### SP-06: Element Alignment Calculation

**Test Data:**
```
@scene: alignment

+---------------------------+
|  [ Left ]                 |
|                           |
|       [ Center ]          |
|                           |
|                 [ Right ] |
+---------------------------+
```

**Expected Results:**
- First button has align=Left
- Second button has align=Center
- Third button has align=Right

---

## Appendix E: ShapeDetector Test Cases

This appendix contains detailed test cases for the ShapeDetector module.

### Test Cases Overview

| Case ID | Feature Description | Test Type |
|---------|---------------------|-----------|
| SD-01 | Single box detection | Positive Test |
| SD-02 | Nested boxes - 2 levels | Positive Test |
| SD-03 | Nested boxes - 3 levels | Positive Test |
| SD-04 | Sibling boxes (non-nested) | Positive Test |
| SD-05 | Box with single divider | Positive Test |
| SD-06 | Box with multiple dividers | Positive Test |
| SD-07 | Box with name extraction | Positive Test |
| SD-08 | Multiple named boxes | Positive Test |
| SD-09 | Unclosed box - missing top corner | Error Test |
| SD-10 | Unclosed box - missing bottom corner | Error Test |
| SD-11 | Mismatched width | Error Test |
| SD-12 | Misaligned vertical pipes | Error Test |
| SD-13 | Overlapping boxes (invalid) | Error Test |
| SD-14 | Empty grid (no boxes) | Edge Case |
| SD-15 | Complex nested structure | Integration Test |
| SD-16 | Deduplication of boxes | Positive Test |
| SD-17 | Error collection without early stopping | Error Recovery Test |
| SD-18 | Helper functions | Utility Function Test |

### SD-01: Single Box Detection

**Test Data:**
```
+-----+
|     |
+-----+
```

**Expected Results:**
- Result.Ok with array of 1 box
- Box bounds match grid coordinates (top=1, left=0, bottom=3, right=6)
- No children, no name

### SD-09: Unclosed Box - Missing Top Corner

**Test Data:**
```
+-----
|     |
+-----+
```

**Expected Results:**
- Error result with UncloseBox error
- Error contains position information

### SD-11: Mismatched Width

**Test Data:**
```
+-----+
|     |
+-------+
```

**Expected Results:**
- Error result with MismatchedWidth
- Error shows expected vs actual widths

### SD-15: Complex Nested Structure

**Test Data:**
```
+--Container--+
| +--Header--+ |
| |          | |
| +----------+ |
| +==========+ |
| +--Body----+ |
| |  +-----+ | |
| |  |     | | |
| |  +-----+ | |
| +----------+ |
+--------------+
```

**Expected Results:**
- Correct hierarchy: 1 root (Container), 2 children (Header, Body), 1 grandchild
- All boxes named correctly
- Divider detected between Header and Body

---

**Document Version**: 1.0
**Last Updated**: 2025-12-22
**Next Review**: After Phase 1 implementation

**Prepared by**: Claude Code
**Approved by**: [Pending]
