// AlignmentCalc_test.res
// Unit tests for AlignmentCalc module - Alignment calculation from element position within boxes
//
// Tests the core alignment detection algorithm that determines Left/Center/Right alignment
// based on an element's position within a bounding box.

open Vitest

describe("AlignmentCalc", () => {
  describe("calculate", () => {
    // Test fixture: Box spanning columns 0-40 (width 41)
    // Interior spans columns 1-39 (width 38 chars)
    let testBounds: Types.Bounds.t = {
      top: 0,
      left: 0,
      bottom: 10,
      right: 40,
    }

    test("detects left-aligned content (close to left edge)", t => {
      // Content "[ Button ]" at column 2 (interior starts at 1)
      // Left space: 2 - 1 = 1, Right space: 39 - 12 + 1 = 28
      let position = Types.Position.make(5, 2)
      let result = AlignmentCalc.calculate("[ Button ]", position, testBounds)
      t->expect(result)->Expect.toEqual(Types.Left)
    })

    test("detects right-aligned content (close to right edge)", t => {
      // Content "[ Button ]" at column 29 (ends at 39)
      // Left space: 29 - 1 = 28, Right space: 39 - 39 + 1 = 1
      let position = Types.Position.make(5, 29)
      let result = AlignmentCalc.calculate("[ Button ]", position, testBounds)
      t->expect(result)->Expect.toEqual(Types.Right)
    })

    test("detects center-aligned content (equal margins)", t => {
      // Content "[ Button ]" (10 chars) centered in 38-char interior
      // Position at column 15: Left space = 14, Right space = 39 - 25 + 1 = 15
      let position = Types.Position.make(5, 15)
      let result = AlignmentCalc.calculate("[ Button ]", position, testBounds)
      t->expect(result)->Expect.toEqual(Types.Center)
    })

    test("handles issue #12: similar buttons should both be centered", t => {
      // Reproduces the bug from GitHub issue #12
      // Two buttons that appear similarly positioned should both be centered

      // Simulating: |          [ Continue with Google ]     |
      // Box width = 41 (columns 0-40), interior = 38 chars (columns 1-39)
      // Button "[ Continue with Google ]" = 24 chars
      // Position at column 11 (10 leading spaces + 1 for interior start)
      // Left space = 11 - 1 = 10
      // Right space = 39 - 35 + 1 = 5 (contentEnd = 11 + 24 = 35)
      let googlePosition = Types.Position.make(5, 11)
      let googleResult = AlignmentCalc.calculate(
        "[ Continue with Google ]",
        googlePosition,
        testBounds,
      )

      // Simulating: |         [ Continue with GitHub ]      |
      // Button "[ Continue with GitHub ]" = 24 chars
      // Position at column 10 (9 leading spaces + 1 for interior start)
      // Left space = 10 - 1 = 9
      // Right space = 39 - 34 + 1 = 6 (contentEnd = 10 + 24 = 34)
      let githubPosition = Types.Position.make(5, 10)
      let githubResult = AlignmentCalc.calculate(
        "[ Continue with GitHub ]",
        githubPosition,
        testBounds,
      )

      // Both buttons should be center-aligned since they're roughly centered
      t->expect(googleResult)->Expect.toEqual(Types.Center)
      t->expect(githubResult)->Expect.toEqual(Types.Center)
    })

    test("correctly calculates right margin for content at various positions", t => {
      // This test verifies the off-by-one fix for rightSpace calculation
      // Content "[ X ]" (5 chars) at different positions

      // Position 1: extreme left (column 1)
      // Left space = 0, Right space = 39 - 6 + 1 = 34
      let leftResult = AlignmentCalc.calculate("[ X ]", Types.Position.make(5, 1), testBounds)
      t->expect(leftResult)->Expect.toEqual(Types.Left)

      // Position 2: extreme right (column 35, ends at 40)
      // Left space = 34, Right space = 39 - 40 + 1 = 0
      // Note: contentEnd = 35 + 5 = 40 which goes past boxRight (39)
      let rightResult = AlignmentCalc.calculate("[ X ]", Types.Position.make(5, 35), testBounds)
      t->expect(rightResult)->Expect.toEqual(Types.Right)

      // Position 3: exact center (column 18 for 5-char content in 38-char interior)
      // Center position: (38 - 5) / 2 + 1 = 17.5 -> column 18
      // Left space = 17, Right space = 39 - 23 + 1 = 17
      let centerResult = AlignmentCalc.calculate("[ X ]", Types.Position.make(5, 18), testBounds)
      t->expect(centerResult)->Expect.toEqual(Types.Center)
    })

    test("defaults to Left when alignment is ambiguous", t => {
      // Content positioned such that it doesn't clearly fit any category
      // This tests the fallback behavior
      let bounds: Types.Bounds.t = {
        top: 0,
        left: 0,
        bottom: 10,
        right: 100,
      }
      // Very wide box with content slightly off-center
      let position = Types.Position.make(5, 10)
      let result = AlignmentCalc.calculate("[ Test ]", position, bounds)
      // Should be Left because leftRatio < centerTolerance threshold
      t->expect(result)->Expect.toEqual(Types.Left)
    })

    test("handles narrow boxes gracefully", t => {
      let narrowBounds: Types.Bounds.t = {
        top: 0,
        left: 0,
        bottom: 10,
        right: 2, // Very narrow: interior width = 0
      }
      let position = Types.Position.make(5, 1)
      let result = AlignmentCalc.calculate("X", position, narrowBounds)
      // Should default to Left for zero-width boxes
      t->expect(result)->Expect.toEqual(Types.Left)
    })

    test("handles issue #22: Sign In button should be Center-aligned", t => {
      // Reproduces the bug from GitHub issue #22
      // The button "[ Sign In ]" at column 12 in a 41-column box
      // appeared centered visually but was detected as Left-aligned.
      //
      // Box: columns 0-40 (width 41), interior: columns 1-39 (38 chars)
      // Content: "[ Sign In ]" = 11 characters at column 12
      // leftSpace = 12 - 1 = 11
      // rightSpace = 39 - 23 + 1 = 17 (contentEnd = 12 + 11 = 23)
      // leftRatio = 11/38 = 0.289
      // rightRatio = 17/38 = 0.447
      // abs(leftRatio - rightRatio) = 0.158 (was just above 0.15 tolerance)
      let bounds: Types.Bounds.t = {
        top: 0,
        left: 0,
        bottom: 20,
        right: 40,
      }
      let signInPosition = Types.Position.make(15, 12)
      let result = AlignmentCalc.calculate("[ Sign In ]", signInPosition, bounds)

      // The button should be detected as Center, not Left
      t->expect(result)->Expect.toEqual(Types.Center)
    })
  })

  describe("calculateWithStrategy", () => {
    let testBounds: Types.Bounds.t = {
      top: 0,
      left: 0,
      bottom: 10,
      right: 40,
    }
    let centerPosition = Types.Position.make(5, 15)

    test("RespectPosition strategy calculates alignment normally", t => {
      let result = AlignmentCalc.calculateWithStrategy(
        "[ Button ]",
        centerPosition,
        testBounds,
        AlignmentCalc.RespectPosition,
      )
      t->expect(result)->Expect.toEqual(Types.Center)
    })

    test("AlwaysLeft strategy always returns Left", t => {
      let result = AlignmentCalc.calculateWithStrategy(
        "[ Button ]",
        centerPosition,
        testBounds,
        AlignmentCalc.AlwaysLeft,
      )
      t->expect(result)->Expect.toEqual(Types.Left)
    })

    test("AlwaysLeft ignores position and bounds", t => {
      // Even with right-aligned position, should return Left
      let rightPosition = Types.Position.make(5, 30)
      let result = AlignmentCalc.calculateWithStrategy(
        "[ Button ]",
        rightPosition,
        testBounds,
        AlignmentCalc.AlwaysLeft,
      )
      t->expect(result)->Expect.toEqual(Types.Left)
    })
  })
})
