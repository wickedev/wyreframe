// Bounds_test.res
// Comprehensive unit tests for Bounds module covering all functions and edge cases

open Vitest

describe("Bounds.make", () => {
  test("creates valid bounds when top < bottom and left < right", t => {
    let result = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

    switch result {
    | Some(bounds) => {
        t->expect(bounds.top)->Expect.toBe(0)
        t->expect(bounds.left)->Expect.toBe(0)
        t->expect(bounds.bottom)->Expect.toBe(10)
        t->expect(bounds.right)->Expect.toBe(10)
      }
    | None => t->expect(true)->Expect.toBe(false) // fail
    }
  })

  test("returns None when top >= bottom", t => {
    let result = Bounds.make(~top=10, ~left=0, ~bottom=10, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None when top > bottom", t => {
    let result = Bounds.make(~top=15, ~left=0, ~bottom=10, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None when left >= right", t => {
    let result = Bounds.make(~top=0, ~left=10, ~bottom=10, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None when left > right", t => {
    let result = Bounds.make(~top=0, ~left=15, ~bottom=10, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("handles negative coordinates", t => {
    let result = Bounds.make(~top=-10, ~left=-10, ~bottom=0, ~right=0)

    switch result {
    | Some(bounds) => {
        t->expect(bounds.top)->Expect.toBe(-10)
        t->expect(bounds.left)->Expect.toBe(-10)
        t->expect(bounds.bottom)->Expect.toBe(0)
        t->expect(bounds.right)->Expect.toBe(0)
      }
    | None => t->expect(true)->Expect.toBe(false) // fail
    }
  })

  test("creates minimal 1x1 bounds", t => {
    let result = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=1)

    switch result {
    | Some(bounds) => {
        t->expect(Bounds.width(bounds))->Expect.toBe(1)
        t->expect(Bounds.height(bounds))->Expect.toBe(1)
      }
    | None => t->expect(true)->Expect.toBe(false) // fail
    }
  })
})

describe("Bounds.width", () => {
  test("calculates width correctly", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(20)
  })

  test("calculates width for single column", t => {
    let bounds = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=6)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(1)
  })

  test("handles negative coordinates", t => {
    let bounds = Bounds.make(~top=0, ~left=-5, ~bottom=10, ~right=5)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(10)
  })

  test("calculates width for large bounds", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=1000)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(1000)
  })
})

describe("Bounds.height", () => {
  test("calculates height correctly", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=10)->Option.getExn
    t->expect(Bounds.height(bounds))->Expect.toBe(15)
  })

  test("calculates height for single row", t => {
    let bounds = Bounds.make(~top=5, ~left=0, ~bottom=6, ~right=10)->Option.getExn
    t->expect(Bounds.height(bounds))->Expect.toBe(1)
  })

  test("handles negative coordinates", t => {
    let bounds = Bounds.make(~top=-5, ~left=0, ~bottom=5, ~right=10)->Option.getExn
    t->expect(Bounds.height(bounds))->Expect.toBe(10)
  })

  test("calculates height for tall bounds", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1000, ~right=10)->Option.getExn
    t->expect(Bounds.height(bounds))->Expect.toBe(1000)
  })
})

describe("Bounds.area", () => {
  test("calculates area correctly", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=20)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(200)
  })

  test("calculates area for 1x1 box", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=1)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(1)
  })

  test("calculates area for narrow box", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=1)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(100)
  })

  test("calculates area for wide box", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=100)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(100)
  })

  test("calculates area with negative coordinates", t => {
    let bounds = Bounds.make(~top=-10, ~left=-20, ~bottom=10, ~right=20)->Option.getExn
    // width = 20 - (-20) = 40, height = 10 - (-10) = 20
    t->expect(Bounds.area(bounds))->Expect.toBe(800)
  })

  test("calculates area for very large bounds", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1000, ~right=1000)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(1000000)
  })
})

describe("Bounds.contains", () => {
  test("returns true when outer completely contains inner", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(true)
  })

  test("returns false when boxes are equal", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    t->expect(Bounds.contains(a, b))->Expect.toBe(false)
  })

  test("returns false when inner top edge touches outer top edge", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=0, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(false)
  })

  test("returns false when inner left edge touches outer left edge", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=0, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(false)
  })

  test("returns false when inner bottom edge touches outer bottom edge", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=20, ~right=15)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(false)
  })

  test("returns false when inner right edge touches outer right edge", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=20)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(false)
  })

  test("returns false when boxes are disjoint", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=20, ~left=20, ~bottom=30, ~right=30)->Option.getExn

    t->expect(Bounds.contains(a, b))->Expect.toBe(false)
  })

  test("returns false when inner is larger than outer", t => {
    let outer = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn
    let inner = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(false)
  })

  test("returns false when boxes partially overlap", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=15)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    t->expect(Bounds.contains(a, b))->Expect.toBe(false)
  })

  test("handles negative coordinates correctly", t => {
    let outer = Bounds.make(~top=-20, ~left=-20, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=-5, ~left=-5, ~bottom=5, ~right=5)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(true)
  })

  test("returns true when inner is minimal 1-pixel margin inside outer", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let inner = Bounds.make(~top=1, ~left=1, ~bottom=9, ~right=9)->Option.getExn

    t->expect(Bounds.contains(outer, inner))->Expect.toBe(true)
  })
})

describe("Bounds.overlaps", () => {
  test("returns true when boxes partially overlap", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=15)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("returns true when one box completely contains another", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Option.getExn
    let inner = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.overlaps(outer, inner))->Expect.toBe(true)
    t->expect(Bounds.overlaps(inner, outer))->Expect.toBe(true)
  })

  test("returns true when boxes are equal", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("returns false when boxes are disjoint horizontally", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=20, ~bottom=10, ~right=30)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("returns false when boxes are disjoint vertically", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=20, ~left=0, ~bottom=30, ~right=10)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("returns false when boxes touch at edges horizontally", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=10, ~bottom=10, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("returns false when boxes touch at edges vertically", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=10, ~left=0, ~bottom=20, ~right=10)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("returns false when boxes are completely separated", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("returns true when boxes overlap at corner", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=11, ~right=11)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("returns true for L-shaped overlap", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=15, ~right=10)->Option.getExn
    let b = Bounds.make(~top=5, ~left=5, ~bottom=10, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("returns true for T-shaped overlap", t => {
    let a = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=15)->Option.getExn
    let b = Bounds.make(~top=5, ~left=0, ~bottom=15, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("handles negative coordinates correctly", t => {
    let a = Bounds.make(~top=-10, ~left=-10, ~bottom=0, ~right=0)->Option.getExn
    let b = Bounds.make(~top=-5, ~left=-5, ~bottom=5, ~right=5)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(true)
  })

  test("returns false for disjoint bounds with negative coordinates", t => {
    let a = Bounds.make(~top=-20, ~left=-20, ~bottom=-10, ~right=-10)->Option.getExn
    let b = Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(false)
  })

  test("is symmetric (order doesn't matter)", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Option.getExn

    t->expect(Bounds.overlaps(a, b))->Expect.toBe(Bounds.overlaps(b, a))
  })
})

describe("Bounds.toString", () => {
  test("formats bounds as string correctly", t => {
    let bounds = Bounds.make(~top=1, ~left=2, ~bottom=10, ~right=20)->Option.getExn
    let str = Bounds.toString(bounds)

    t->expect(str)->Expect.toBe("Bounds{top: 1, left: 2, bottom: 10, right: 20}")
  })

  test("handles negative coordinates in string", t => {
    let bounds = Bounds.make(~top=-5, ~left=-10, ~bottom=5, ~right=10)->Option.getExn
    let str = Bounds.toString(bounds)

    t->expect(str)->Expect.toBe("Bounds{top: -5, left: -10, bottom: 5, right: 10}")
  })
})

describe("Bounds.equals", () => {
  test("returns true for equal bounds", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    t->expect(Bounds.equals(a, b))->Expect.toBe(true)
  })

  test("returns false for different bounds", t => {
    let a = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    let b = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=11)->Option.getExn

    t->expect(Bounds.equals(a, b))->Expect.toBe(false)
  })

  test("returns false when only one field differs", t => {
    let base = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    let diffTop = Bounds.make(~top=1, ~left=0, ~bottom=10, ~right=10)->Option.getExn
    t->expect(Bounds.equals(base, diffTop))->Expect.toBe(false)

    let diffLeft = Bounds.make(~top=0, ~left=1, ~bottom=10, ~right=10)->Option.getExn
    t->expect(Bounds.equals(base, diffLeft))->Expect.toBe(false)

    let diffBottom = Bounds.make(~top=0, ~left=0, ~bottom=11, ~right=10)->Option.getExn
    t->expect(Bounds.equals(base, diffBottom))->Expect.toBe(false)

    let diffRight = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=11)->Option.getExn
    t->expect(Bounds.equals(base, diffRight))->Expect.toBe(false)
  })
})

describe("Bounds edge cases", () => {
  test("handles zero-width bounds validation", t => {
    let result = Bounds.make(~top=0, ~left=5, ~bottom=10, ~right=5)
    t->expect(result)->Expect.toBe(None)
  })

  test("handles zero-height bounds validation", t => {
    let result = Bounds.make(~top=5, ~left=0, ~bottom=5, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("handles inverted bounds", t => {
    let result = Bounds.make(~top=10, ~left=0, ~bottom=5, ~right=10)
    t->expect(result)->Expect.toBe(None)
  })

  test("handles very large coordinate values", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1000000, ~right=1000000)->Option.getExn
    t->expect(Bounds.area(bounds))->Expect.toBe(1000000000000)
  })

  test("handles single pixel bounds", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=1)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(1)
    t->expect(Bounds.height(bounds))->Expect.toBe(1)
    t->expect(Bounds.area(bounds))->Expect.toBe(1)
  })

  test("handles thin horizontal line", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=100)->Option.getExn
    t->expect(Bounds.height(bounds))->Expect.toBe(1)
    t->expect(Bounds.area(bounds))->Expect.toBe(100)
  })

  test("handles thin vertical line", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=1)->Option.getExn
    t->expect(Bounds.width(bounds))->Expect.toBe(1)
    t->expect(Bounds.area(bounds))->Expect.toBe(100)
  })
})
