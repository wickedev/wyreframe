// Bounds_test.res
// Unit tests for Bounds module

open RescriptCore

@@directive("@@warning(\"-44\")") // Suppress unused open warning

describe("Bounds.make", () => {
  test("creates valid bounds when top < bottom and left < right", () => {
    let result = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

    switch result {
    | Some(bounds) => {
        expect(bounds.top)->toBe(0)
        expect(bounds.left)->toBe(0)
        expect(bounds.bottom)->toBe(10)
        expect(bounds.right)->toBe(10)
      }
    | None => failWith("Expected Some(bounds), got None")
    }
  })

  test("returns None when top >= bottom", () => {
    let result = Bounds.make(~top=10, ~left=0, ~bottom=10, ~right=10)
    expect(result)->toBe(None)
  })

  test("returns None when top > bottom", () => {
    let result = Bounds.make(~top=15, ~left=0, ~bottom=10, ~right=10)
    expect(result)->toBe(None)
  })

  test("returns None when left >= right", () => {
    let result = Bounds.make(~top=0, ~left=10, ~bottom=10, ~right=10)
    expect(result)->toBe(None)
  })

  test("returns None when left > right", () => {
    let result = Bounds.make(~top=0, ~left=15, ~bottom=10, ~right=10)
    expect(result)->toBe(None)
  })

  test("handles negative coordinates", () => {
    let result = Bounds.make(~top=-10, ~left=-10, ~bottom=0, ~right=0)

    switch result {
    | Some(bounds) => {
        expect(bounds.top)->toBe(-10)
        expect(bounds.left)->toBe(-10)
      }
    | None => failWith("Expected Some(bounds), got None")
    }
  })
})

describe("Bounds.width", () => {
  test("calculates width correctly", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)->Option.getExn
    expect(Bounds.width(bounds))->toBe(20)
  })

  test("calculates width for single column", () => {
    let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=6)->Option.getExn
    expect(Bounds.width(bounds))->toBe(1)
  })

  test("handles negative coordinates", () => {
    let bounds = Bounds.make(~top=0, ~left=-5, ~bottom=10, ~right=5)->Option.getExn
    expect(Bounds.width(bounds))->toBe(10)
  })
})

describe("Bounds.height", () => {
  test("calculates height correctly", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=10)->Option.getExn
    expect(Bounds.height(bounds))->toBe(15)
  })

  test("calculates height for single row", () => {
    let bounds = Bounds.make(~top=5, ~left=0, ~bottom=6, ~right=10)->Option.getExn
    expect(Bounds.height(bounds))->toBe(1)
  })

  test("handles negative coordinates", () => {
    let bounds = Bounds.make(~top=-5, ~left=0, ~bottom=5, ~right=10)->Option.getExn
    expect(Bounds.height(bounds))->toBe(10)
  })
})

describe("Bounds.area", () => {
  test("calculates area correctly", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)->Option.getExn
    expect(Bounds.area(bounds))->toBe(200)
  })

  test("calculates area for 1x1 box", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=1)->Option.getExn
    expect(Bounds.area(bounds))->toBe(1)
  })

  test("calculates area for narrow box", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=1)->Option.getExn
    expect(Bounds.area(bounds))->toBe(100)
  })

  test("calculates area for wide box", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=100)->Option.getExn
    expect(Bounds.area(bounds))->toBe(100)
  })
})

describe("Bounds.contains", () => {
  test("returns true when outer completely contains inner", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(true)
  })

  test("returns false when boxes are equal", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    expect(Bounds.contains(a, b))->toBe(false)
  })

  test("returns false when inner top edge touches outer top edge", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=0, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(false)
  })

  test("returns false when inner left edge touches outer left edge", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=0, ~bottom=15, ~right=15)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(false)
  })

  test("returns false when inner bottom edge touches outer bottom edge", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=20, ~right=15)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(false)
  })

  test("returns false when inner right edge touches outer right edge", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=20)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(false)
  })

  test("returns false when boxes are disjoint", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=20, ~left=20, ~bottom=30, ~right=30)->Option.getExn

    expect(Bounds.contains(a, b))->toBe(false)
  })

  test("returns false when inner is larger than outer", () => {
    let outer = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn
    let inner = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn

    expect(Bounds.contains(outer, inner))->toBe(false)
  })

  test("returns false when boxes partially overlap", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=15)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    expect(Bounds.contains(a, b))->toBe(false)
  })
})

describe("Bounds.overlaps", () => {
  test("returns true when boxes partially overlap", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=15)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(true)
  })

  test("returns true when one box completely contains another", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    expect(Bounds.overlaps(outer, inner))->toBe(true)
  })

  test("returns true when boxes are equal", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(true)
  })

  test("returns false when boxes are disjoint horizontally", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=20, ~bottom=10, ~right=30)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(false)
  })

  test("returns false when boxes are disjoint vertically", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=20, ~left=0, ~bottom=30, ~right=10)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(false)
  })

  test("returns false when boxes touch at edges horizontally", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=10, ~bottom=10, ~right=20)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(false)
  })

  test("returns false when boxes touch at edges vertically", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=10, ~left=0, ~bottom=20, ~right=10)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(false)
  })

  test("returns false when boxes are completely separated", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(false)
  })

  test("returns true when boxes overlap at corner", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=11, ~right=11)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    expect(Bounds.overlaps(a, b))->toBe(true)
  })
})

describe("Bounds.toString", () => {
  test("formats bounds as string", () => {
    let bounds = Bounds.make(~top=1, ~left=2, ~bottom=10, ~right=20)->Option.getExn
    let str = Bounds.toString(bounds)

    expect(str)->toBe("Bounds{top: 1, left: 2, bottom: 10, right: 20}")
  })
})

describe("Bounds.equals", () => {
  test("returns true for equal bounds", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    expect(Bounds.equals(a, b))->toBe(true)
  })

  test("returns false for different bounds", () => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=11)->Option.getExn

    expect(Bounds.equals(a, b))->toBe(false)
  })
})

describe("Bounds edge cases", () => {
  test("handles zero-width bounds validation", () => {
    let result = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=5)
    expect(result)->toBe(None)
  })

  test("handles zero-height bounds validation", () => {
    let result = Bounds.make(~top=5, ~left=0, ~bottom=5, ~right=10)
    expect(result)->toBe(None)
  })

  test("handles negative bounds", () => {
    let result = Bounds.make(~top=10, ~left=0, ~bottom=5, ~right=10)
    expect(result)->toBe(None)
  })

  test("handles large coordinate values", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1000000, ~right=1000000)->Option.getExn
    expect(Bounds.area(bounds))->toBe(1000000000000)
  })
})
