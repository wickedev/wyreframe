// Position_test.res
// Comprehensive unit tests for Position module

open Jest
open Expect

describe("Position", () => {
  describe("make", () => {
    test("creates position with given row and col", () => {
      let pos = Position.make(5, 10)

      expect(pos.row)->toBe(5)
      expect(pos.col)->toBe(10)
    })

    test("creates position with zero coordinates", () => {
      let pos = Position.make(0, 0)

      expect(pos.row)->toBe(0)
      expect(pos.col)->toBe(0)
    })

    test("creates position with negative coordinates", () => {
      let pos = Position.make(-3, -7)

      expect(pos.row)->toBe(-3)
      expect(pos.col)->toBe(-7)
    })
  })

  describe("right", () => {
    test("moves right by 1 column by default", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.right(pos)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(11)
    })

    test("moves right by specified distance", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.right(pos, ~n=5)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(15)
    })

    test("moves right by 0 (no change)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.right(pos, ~n=0)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(10)
    })

    test("moves right with negative distance (moves left)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.right(pos, ~n=-3)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(7)
    })

    test("does not modify original position", () => {
      let pos = Position.make(5, 10)
      let _ = Position.right(pos, ~n=5)

      expect(pos.row)->toBe(5)
      expect(pos.col)->toBe(10)
    })
  })

  describe("down", () => {
    test("moves down by 1 row by default", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.down(pos)

      expect(newPos.row)->toBe(6)
      expect(newPos.col)->toBe(10)
    })

    test("moves down by specified distance", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.down(pos, ~n=3)

      expect(newPos.row)->toBe(8)
      expect(newPos.col)->toBe(10)
    })

    test("moves down by 0 (no change)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.down(pos, ~n=0)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(10)
    })

    test("moves down with negative distance (moves up)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.down(pos, ~n=-2)

      expect(newPos.row)->toBe(3)
      expect(newPos.col)->toBe(10)
    })

    test("does not modify original position", () => {
      let pos = Position.make(5, 10)
      let _ = Position.down(pos, ~n=3)

      expect(pos.row)->toBe(5)
      expect(pos.col)->toBe(10)
    })
  })

  describe("left", () => {
    test("moves left by 1 column by default", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.left(pos)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(9)
    })

    test("moves left by specified distance", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.left(pos, ~n=4)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(6)
    })

    test("moves left by 0 (no change)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.left(pos, ~n=0)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(10)
    })

    test("moves left with negative distance (moves right)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.left(pos, ~n=-5)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(15)
    })

    test("does not modify original position", () => {
      let pos = Position.make(5, 10)
      let _ = Position.left(pos, ~n=4)

      expect(pos.row)->toBe(5)
      expect(pos.col)->toBe(10)
    })
  })

  describe("up", () => {
    test("moves up by 1 row by default", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.up(pos)

      expect(newPos.row)->toBe(4)
      expect(newPos.col)->toBe(10)
    })

    test("moves up by specified distance", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.up(pos, ~n=3)

      expect(newPos.row)->toBe(2)
      expect(newPos.col)->toBe(10)
    })

    test("moves up by 0 (no change)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.up(pos, ~n=0)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(10)
    })

    test("moves up with negative distance (moves down)", () => {
      let pos = Position.make(5, 10)
      let newPos = Position.up(pos, ~n=-3)

      expect(newPos.row)->toBe(8)
      expect(newPos.col)->toBe(10)
    })

    test("does not modify original position", () => {
      let pos = Position.make(5, 10)
      let _ = Position.up(pos, ~n=3)

      expect(pos.row)->toBe(5)
      expect(pos.col)->toBe(10)
    })
  })

  describe("equals", () => {
    test("returns true for identical positions", () => {
      let pos1 = Position.make(5, 10)
      let pos2 = Position.make(5, 10)

      expect(Position.equals(pos1, pos2))->toBe(true)
    })

    test("returns true when comparing position to itself", () => {
      let pos = Position.make(5, 10)

      expect(Position.equals(pos, pos))->toBe(true)
    })

    test("returns false for positions with different rows", () => {
      let pos1 = Position.make(5, 10)
      let pos2 = Position.make(6, 10)

      expect(Position.equals(pos1, pos2))->toBe(false)
    })

    test("returns false for positions with different columns", () => {
      let pos1 = Position.make(5, 10)
      let pos2 = Position.make(5, 11)

      expect(Position.equals(pos1, pos2))->toBe(false)
    })

    test("returns false for positions with both different row and column", () => {
      let pos1 = Position.make(5, 10)
      let pos2 = Position.make(6, 11)

      expect(Position.equals(pos1, pos2))->toBe(false)
    })

    test("returns true for zero positions", () => {
      let pos1 = Position.make(0, 0)
      let pos2 = Position.make(0, 0)

      expect(Position.equals(pos1, pos2))->toBe(true)
    })

    test("returns true for negative positions", () => {
      let pos1 = Position.make(-5, -10)
      let pos2 = Position.make(-5, -10)

      expect(Position.equals(pos1, pos2))->toBe(true)
    })
  })

  describe("toString", () => {
    test("formats positive coordinates correctly", () => {
      let pos = Position.make(5, 10)

      expect(Position.toString(pos))->toBe("(5, 10)")
    })

    test("formats zero coordinates correctly", () => {
      let pos = Position.make(0, 0)

      expect(Position.toString(pos))->toBe("(0, 0)")
    })

    test("formats negative coordinates correctly", () => {
      let pos = Position.make(-3, -7)

      expect(Position.toString(pos))->toBe("(-3, -7)")
    })

    test("formats mixed positive and negative coordinates correctly", () => {
      let pos = Position.make(-5, 10)

      expect(Position.toString(pos))->toBe("(-5, 10)")
    })

    test("formats large coordinates correctly", () => {
      let pos = Position.make(999, 1234)

      expect(Position.toString(pos))->toBe("(999, 1234)")
    })
  })

  describe("navigation chaining", () => {
    test("can chain multiple navigation operations", () => {
      let pos = Position.make(10, 10)
      let newPos = pos
        ->Position.right(~n=5)
        ->Position.down(~n=3)
        ->Position.left(~n=2)
        ->Position.up(~n=1)

      expect(newPos.row)->toBe(12)
      expect(newPos.col)->toBe(13)
    })

    test("chaining preserves immutability", () => {
      let original = Position.make(10, 10)
      let _ = original
        ->Position.right(~n=5)
        ->Position.down(~n=3)

      expect(original.row)->toBe(10)
      expect(original.col)->toBe(10)
    })

    test("complex navigation pattern", () => {
      let start = Position.make(0, 0)
      let end = start
        ->Position.right(~n=10)
        ->Position.down(~n=5)
        ->Position.left(~n=3)
        ->Position.up(~n=2)

      expect(end.row)->toBe(3)
      expect(end.col)->toBe(7)
    })
  })

  describe("edge cases", () => {
    test("large positive coordinates", () => {
      let pos = Position.make(1000000, 2000000)
      let newPos = Position.right(pos, ~n=500000)

      expect(newPos.row)->toBe(1000000)
      expect(newPos.col)->toBe(2500000)
    })

    test("navigation from negative to positive coordinates", () => {
      let pos = Position.make(-5, -5)
      let newPos = pos
        ->Position.right(~n=10)
        ->Position.down(~n=10)

      expect(newPos.row)->toBe(5)
      expect(newPos.col)->toBe(5)
    })

    test("navigation resulting in negative coordinates", () => {
      let pos = Position.make(3, 3)
      let newPos = pos
        ->Position.left(~n=5)
        ->Position.up(~n=5)

      expect(newPos.row)->toBe(-2)
      expect(newPos.col)->toBe(-2)
    })
  })
})
