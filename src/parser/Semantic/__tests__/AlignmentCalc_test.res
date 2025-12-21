// AlignmentCalc_test.res
// Unit tests for AlignmentCalc module

open RescriptMocha
open Chai

describe("AlignmentCalc", () => {
  // Helper to create test bounds for a box
  // Box structure: | <interior> |
  // So if left=0 and right=20, interior goes from col 1 to col 19 (width = 18)
  let makeTestBounds = (left: int, right: int): Types.bounds => {
    top: 0,
    left: left,
    bottom: 5,
    right: right,
  }

  describe("calculate - Left alignment", () => {
    it("should return Left when element is at the left edge", () => {
      // Box: |Text                |
      //       ^1   ^19
      // leftSpace = 1-1 = 0, rightSpace = 19-5 = 14
      // leftRatio = 0/18 = 0.0, rightRatio = 14/18 = 0.78
      // 0.0 < 0.2 && 0.78 > 0.3 => Left
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 1) // Start at column 1 (just after left border)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left)
    })

    it("should return Left when element is close to left edge (< 20% from left)", () => {
      // Box width interior = 18, 20% = 3.6
      // Element at col 3 (2 spaces from left edge)
      // leftSpace = 3-1 = 2, rightSpace = 19-7 = 12
      // leftRatio = 2/18 = 0.11, rightRatio = 12/18 = 0.67
      // 0.11 < 0.2 && 0.67 > 0.3 => Left
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 3)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left)
    })

    it("should return Left as default when no specific alignment conditions match", () => {
      // Element in the middle-left area but not centered
      // leftRatio = ~0.3, rightRatio = ~0.4
      // Not left (0.3 >= 0.2), not right, not center (diff > 0.15)
      let bounds = makeTestBounds(0, 30)
      let position = Position.make(2, 10)
      let content = "Test"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left)
    })
  })

  describe("calculate - Right alignment", () => {
    it("should return Right when element is at the right edge", () => {
      // Box: |                Text|
      //       ^1              ^15 ^19
      // leftSpace = 15-1 = 14, rightSpace = 19-19 = 0
      // leftRatio = 14/18 = 0.78, rightRatio = 0/18 = 0.0
      // 0.0 < 0.2 && 0.78 > 0.3 => Right
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 15)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Right)
    })

    it("should return Right when element is close to right edge (< 20% from right)", () => {
      // Box width interior = 18, 20% = 3.6
      // Element at col 14 (3 spaces from right edge including content length)
      // Content "Text" (4 chars) ends at col 18
      // leftSpace = 14-1 = 13, rightSpace = 19-18 = 1
      // leftRatio = 13/18 = 0.72, rightRatio = 1/18 = 0.056
      // 0.056 < 0.2 && 0.72 > 0.3 => Right
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 14)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Right)
    })
  })

  describe("calculate - Center alignment", () => {
    it("should return Center when element is perfectly centered", () => {
      // Box width interior = 18, center = col 10
      // Content "Text" (4 chars) centered at 8-12
      // leftSpace = 8-1 = 7, rightSpace = 19-12 = 7
      // leftRatio = 7/18 = 0.39, rightRatio = 7/18 = 0.39
      // abs(0.39 - 0.39) = 0.0 < 0.15 => Center
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 8)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Center)
    })

    it("should return Center when element is roughly centered (within 15% tolerance)", () => {
      // Element slightly off-center but within tolerance
      // leftSpace = 6, rightSpace = 8 (18 - 4 - 6)
      // leftRatio = 6/18 = 0.33, rightRatio = 8/18 = 0.44
      // abs(0.33 - 0.44) = 0.11 < 0.15 => Center
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 7)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Center)
    })

    it("should return Center for longer centered text", () => {
      // Box width interior = 28, content "Hello World" (11 chars)
      // Centered at col 10-21
      // leftSpace = 10-1 = 9, rightSpace = 29-21 = 8
      // leftRatio = 9/28 = 0.32, rightRatio = 8/28 = 0.29
      // abs(0.32 - 0.29) = 0.03 < 0.15 => Center
      let bounds = makeTestBounds(0, 30)
      let position = Position.make(2, 10)
      let content = "Hello World"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Center)
    })
  })

  describe("calculate - Edge cases", () => {
    it("should handle zero-width box gracefully", () => {
      // Box where interior width is 0 or negative
      let bounds: Types.bounds = {
        top: 0,
        left: 10,
        bottom: 5,
        right: 10, // Same as left, interior width = 10-10-2 = -2
      }
      let position = Position.make(2, 5)
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left) // Should default to Left
    })

    it("should handle very narrow box (width = 1)", () => {
      // Box: ||  (just two borders, no interior space)
      let bounds: Types.bounds = {
        top: 0,
        left: 0,
        bottom: 5,
        right: 1,
      }
      let position = Position.make(2, 1)
      let content = "X"

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left) // Width <= 0 should default to Left
    })

    it("should handle empty content", () => {
      // Empty string should still calculate based on position
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 1)
      let content = ""

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left)
    })

    it("should handle whitespace-only content by trimming", () => {
      // Whitespace should be trimmed, resulting in 0-length content
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 8)
      let content = "    " // 4 spaces

      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Center) // Position 8 should still be evaluated as center
    })

    it("should handle content that exactly fills the box interior", () => {
      // Content fills the entire box width
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 1)
      let content = "123456789012345678" // 18 chars, fills width exactly

      let result = AlignmentCalc.calculate(content, position, bounds)

      // leftSpace = 0, rightSpace = 0
      // leftRatio = 0.0, rightRatio = 0.0
      // abs(0.0 - 0.0) = 0.0 < 0.15 => Center
      expect(result)->to_be(Center)
    })
  })

  describe("calculate - Boundary conditions", () => {
    it("should handle element at exactly 20% from left (boundary case)", () => {
      // Box width = 20, 20% = 4
      // Element at col 5 (4 spaces from left edge)
      let bounds = makeTestBounds(0, 22)
      let position = Position.make(2, 5)
      let content = "Text"

      // leftSpace = 4, rightSpace = 21-9 = 12
      // leftRatio = 4/20 = 0.2, rightRatio = 12/20 = 0.6
      // 0.2 is NOT < 0.2, so this won't match left condition
      // Should fall through to default Left
      let result = AlignmentCalc.calculate(content, position, bounds)

      expect(result)->to_be(Left)
    })

    it("should handle element at exactly 15% difference (center boundary)", () => {
      // Create a scenario where abs(leftRatio - rightRatio) = exactly 0.15
      // Box width = 20, leftSpace = 6, rightSpace = 20 - 6 - 4 = 10
      // leftRatio = 6/20 = 0.3, rightRatio = 10/20 = 0.5
      // abs(0.3 - 0.5) = 0.2 > 0.15, so not center
      let bounds = makeTestBounds(0, 22)
      let position = Position.make(2, 7) // col 1 + 6 spaces
      let content = "Text"

      let result = AlignmentCalc.calculate(content, position, bounds)

      // Should not be Center, will default to Left
      expect(result)->to_be(Left)
    })
  })

  describe("calculateWithStrategy", () => {
    it("should respect position when using RespectPosition strategy", () => {
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 8)
      let content = "Text"

      let result = AlignmentCalc.calculateWithStrategy(
        content,
        position,
        bounds,
        RespectPosition,
      )

      expect(result)->to_be(Center)
    })

    it("should always return Left when using AlwaysLeft strategy", () => {
      // Even with centered position, should return Left
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 8)
      let content = "Text"

      let result = AlignmentCalc.calculateWithStrategy(content, position, bounds, AlwaysLeft)

      expect(result)->to_be(Left)
    })

    it("should always return Left for right-aligned position with AlwaysLeft strategy", () => {
      let bounds = makeTestBounds(0, 20)
      let position = Position.make(2, 15)
      let content = "Text"

      let result = AlignmentCalc.calculateWithStrategy(content, position, bounds, AlwaysLeft)

      expect(result)->to_be(Left)
    })
  })
})
