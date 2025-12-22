// HierarchyBuilder_test.res
// Tests for hierarchy building functionality

open Vitest
open Types

describe("HierarchyBuilder - Containment Detection", () => {
  test("contains returns true when outer completely contains inner", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
    let inner = Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)
    t->expect(HierarchyBuilder.contains(outer, inner))->Expect.toBe(true)
  })

  test("contains returns false when boxes are equal", t => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
    t->expect(HierarchyBuilder.contains(bounds, bounds))->Expect.toBe(false)
  })

  test("contains returns false when boxes are disjoint", t => {
    let box1 = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)
    let box2 = Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)
    t->expect(HierarchyBuilder.contains(box1, box2))->Expect.toBe(false)
  })

  test("contains returns false when boxes partially overlap", t => {
    let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
    let box2 = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)
    t->expect(HierarchyBuilder.contains(box1, box2))->Expect.toBe(false)
  })

  test("contains returns false when inner touches outer's edge", t => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)
    let inner = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)
    // Inner touches outer's top-left edge, so not strict containment
    t->expect(HierarchyBuilder.contains(outer, inner))->Expect.toBe(false)
  })
})

describe("HierarchyBuilder - findParent", () => {
  test("findParent returns None for root box (no container)", t => {
    let box = HierarchyBuilder.makeBox(
      ~name="Root",
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
    )

    let candidates = [box]

    t->expect(HierarchyBuilder.findParent(box, candidates))->Expect.toEqual(None)
  })

  test("findParent returns immediate parent (smallest containing box)", t => {
    let grandparent = HierarchyBuilder.makeBox(
      ~name="Grandparent",
      Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20),
    )

    let parent = HierarchyBuilder.makeBox(
      ~name="Parent",
      Bounds.make(~top=2, ~left=2, ~bottom=18, ~right=18),
    )

    let child = HierarchyBuilder.makeBox(
      ~name="Child",
      Bounds.make(~top=4, ~left=4, ~bottom=16, ~right=16),
    )

    let candidates = [grandparent, parent, child]

    // Child's immediate parent should be parent, not grandparent
    t->expect(HierarchyBuilder.findParent(child, candidates))->Expect.toEqual(Some(parent))
  })

  test("findParent ignores boxes that don't contain the target", t => {
    let box1 = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5),
    )

    let box2 = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15),
    )

    let candidates = [box1, box2]

    t->expect(HierarchyBuilder.findParent(box2, candidates))->Expect.toEqual(None)
  })
})

describe("HierarchyBuilder - buildHierarchy - 2-level nesting", () => {
  test("builds hierarchy with one root and one child", t => {
    let parent = HierarchyBuilder.makeBox(
      ~name="Parent",
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
    )

    let child = HierarchyBuilder.makeBox(
      ~name="Child",
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8),
    )

    let boxes = [parent, child]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root (parent)
        t->expect(Array.length(roots))->Expect.toBe(1)

        switch roots[0] {
        | Some(root) => {
            t->expect(root.name)->Expect.toEqual(Some("Parent"))
            // Parent should have 1 child
            t->expect(Array.length(root.children))->Expect.toBe(1)

            switch root.children[0] {
            | Some(childBox) => t->expect(childBox.name)->Expect.toEqual(Some("Child"))
            | None => t->expect(true)->Expect.toBe(false) // fail: Expected child to exist
            }
          }
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected root to exist
        }
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result
    }
  })

  test("builds hierarchy with one root and multiple children", t => {
    let parent = HierarchyBuilder.makeBox(
      ~name="Parent",
      Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20),
    )

    let child1 = HierarchyBuilder.makeBox(
      ~name="Child1",
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8),
    )

    let child2 = HierarchyBuilder.makeBox(
      ~name="Child2",
      Bounds.make(~top=12, ~left=12, ~bottom=18, ~right=18),
    )

    let boxes = [parent, child1, child2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        t->expect(Array.length(roots))->Expect.toBe(1)

        switch roots[0] {
        | Some(root) => {
            t->expect(root.name)->Expect.toEqual(Some("Parent"))
            // Parent should have 2 children
            t->expect(Array.length(root.children))->Expect.toBe(2)
          }
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected root to exist
        }
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result
    }
  })
})

describe("HierarchyBuilder - buildHierarchy - 3-level nesting", () => {
  test("builds hierarchy with 3 levels: root -> child -> grandchild", t => {
    let root = HierarchyBuilder.makeBox(
      ~name="Root",
      Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30),
    )

    let child = HierarchyBuilder.makeBox(
      ~name="Child",
      Bounds.make(~top=5, ~left=5, ~bottom=25, ~right=25),
    )

    let grandchild = HierarchyBuilder.makeBox(
      ~name="Grandchild",
      Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20),
    )

    let boxes = [root, child, grandchild]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root
        t->expect(Array.length(roots))->Expect.toBe(1)

        switch roots[0] {
        | Some(rootBox) => {
            t->expect(rootBox.name)->Expect.toEqual(Some("Root"))
            // Root should have 1 child
            t->expect(Array.length(rootBox.children))->Expect.toBe(1)

            switch rootBox.children[0] {
            | Some(childBox) => {
                t->expect(childBox.name)->Expect.toEqual(Some("Child"))
                // Child should have 1 grandchild
                t->expect(Array.length(childBox.children))->Expect.toBe(1)

                switch childBox.children[0] {
                | Some(grandchildBox) => t->expect(grandchildBox.name)->Expect.toEqual(Some("Grandchild"))
                | None => t->expect(true)->Expect.toBe(false) // fail: Expected grandchild to exist
                }
              }
            | None => t->expect(true)->Expect.toBe(false) // fail: Expected child to exist
            }
          }
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected root to exist
        }
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result
    }
  })

  test("getDepth correctly calculates depth for 3-level hierarchy", t => {
    let root = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30),
    )

    let child = HierarchyBuilder.makeBox(
      Bounds.make(~top=5, ~left=5, ~bottom=25, ~right=25),
    )

    let grandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20),
    )

    let allBoxes = [root, child, grandchild]

    t->expect(HierarchyBuilder.getDepth(root, allBoxes))->Expect.toBe(0)
    t->expect(HierarchyBuilder.getDepth(child, allBoxes))->Expect.toBe(1)
    t->expect(HierarchyBuilder.getDepth(grandchild, allBoxes))->Expect.toBe(2)
  })
})

describe("HierarchyBuilder - buildHierarchy - 4-level nesting", () => {
  test("builds hierarchy with 4 levels: root -> child -> grandchild -> great-grandchild", t => {
    let root = HierarchyBuilder.makeBox(
      ~name="Root",
      Bounds.make(~top=0, ~left=0, ~bottom=40, ~right=40),
    )

    let child = HierarchyBuilder.makeBox(
      ~name="Child",
      Bounds.make(~top=5, ~left=5, ~bottom=35, ~right=35),
    )

    let grandchild = HierarchyBuilder.makeBox(
      ~name="Grandchild",
      Bounds.make(~top=10, ~left=10, ~bottom=30, ~right=30),
    )

    let greatGrandchild = HierarchyBuilder.makeBox(
      ~name="GreatGrandchild",
      Bounds.make(~top=15, ~left=15, ~bottom=25, ~right=25),
    )

    let boxes = [root, child, grandchild, greatGrandchild]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root
        t->expect(Array.length(roots))->Expect.toBe(1)

        switch roots[0] {
        | Some(rootBox) => {
            t->expect(rootBox.name)->Expect.toEqual(Some("Root"))
            t->expect(Array.length(rootBox.children))->Expect.toBe(1)

            switch rootBox.children[0] {
            | Some(childBox) => {
                t->expect(childBox.name)->Expect.toEqual(Some("Child"))
                t->expect(Array.length(childBox.children))->Expect.toBe(1)

                switch childBox.children[0] {
                | Some(grandchildBox) => {
                    t->expect(grandchildBox.name)->Expect.toEqual(Some("Grandchild"))
                    t->expect(Array.length(grandchildBox.children))->Expect.toBe(1)

                    switch grandchildBox.children[0] {
                    | Some(greatGrandchildBox) =>
                      t->expect(greatGrandchildBox.name)->Expect.toEqual(Some("GreatGrandchild"))
                    | None => t->expect(true)->Expect.toBe(false) // fail: Expected great-grandchild to exist
                    }
                  }
                | None => t->expect(true)->Expect.toBe(false) // fail: Expected grandchild to exist
                }
              }
            | None => t->expect(true)->Expect.toBe(false) // fail: Expected child to exist
            }
          }
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected root to exist
        }
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result
    }
  })

  test("getDepth correctly calculates depth for 4-level hierarchy", t => {
    let root = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=40, ~right=40),
    )

    let child = HierarchyBuilder.makeBox(
      Bounds.make(~top=5, ~left=5, ~bottom=35, ~right=35),
    )

    let grandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=30, ~right=30),
    )

    let greatGrandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=15, ~left=15, ~bottom=25, ~right=25),
    )

    let allBoxes = [root, child, grandchild, greatGrandchild]

    t->expect(HierarchyBuilder.getDepth(root, allBoxes))->Expect.toBe(0)
    t->expect(HierarchyBuilder.getDepth(child, allBoxes))->Expect.toBe(1)
    t->expect(HierarchyBuilder.getDepth(grandchild, allBoxes))->Expect.toBe(2)
    t->expect(HierarchyBuilder.getDepth(greatGrandchild, allBoxes))->Expect.toBe(3)
  })
})

describe("HierarchyBuilder - buildHierarchy - Multiple roots", () => {
  test("handles multiple root boxes with children", t => {
    let root1 = HierarchyBuilder.makeBox(
      ~name="Root1",
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
    )

    let root1Child = HierarchyBuilder.makeBox(
      ~name="Root1Child",
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8),
    )

    let root2 = HierarchyBuilder.makeBox(
      ~name="Root2",
      Bounds.make(~top=20, ~left=20, ~bottom=30, ~right=30),
    )

    let root2Child = HierarchyBuilder.makeBox(
      ~name="Root2Child",
      Bounds.make(~top=22, ~left=22, ~bottom=28, ~right=28),
    )

    let boxes = [root1, root1Child, root2, root2Child]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 2 roots
        t->expect(Array.length(roots))->Expect.toBe(2)

        // Each root should have 1 child
        roots->Array.forEach(root => {
          t->expect(Array.length(root.children))->Expect.toBe(1)
        })
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result
    }
  })
})

describe("HierarchyBuilder - buildHierarchy - Error cases", () => {
  test("detects overlapping boxes (invalid partial overlap)", t => {
    let box1 = HierarchyBuilder.makeBox(
      ~name="Box1",
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
    )

    let box2 = HierarchyBuilder.makeBox(
      ~name="Box2",
      // Overlaps with box1 but doesn't contain or is contained by it
      Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15),
    )

    let boxes = [box1, box2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Error for overlapping boxes
    | Error(HierarchyBuilder.OverlappingBoxes({box1: b1, box2: b2})) => {
        // Verify the error contains the overlapping boxes
        t->expect(b1 === box1 || b1 === box2)->Expect.toBe(true)
        t->expect(b2 === box1 || b2 === box2)->Expect.toBe(true)
        t->expect(b1 !== b2)->Expect.toBe(true)
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected OverlappingBoxes error
    }
  })

  test("allows disjoint boxes (no overlap)", t => {
    let box1 = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5),
    )

    let box2 = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15),
    )

    let boxes = [box1, box2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 2 roots (both boxes are disjoint)
        t->expect(Array.length(roots))->Expect.toBe(2)
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result for disjoint boxes
    }
  })

  test("allows nested boxes (one contains the other)", t => {
    let outer = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
    )

    let inner = HierarchyBuilder.makeBox(
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8),
    )

    let boxes = [outer, inner]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 1 root with 1 child
        t->expect(Array.length(roots))->Expect.toBe(1)

        switch roots[0] {
        | Some(root) => t->expect(Array.length(root.children))->Expect.toBe(1)
        | None => t->expect(true)->Expect.toBe(false) // fail: Expected root to exist
        }
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected Ok result for nested boxes
    }
  })
})

// ============================================================================
// Deep Nesting Warning Detection Tests
// ============================================================================

describe("HierarchyBuilder - Deep Nesting Detection", () => {
  describe("collectDeepNestingWarnings", () => {
    test("should not warn for boxes at or below threshold (depth 0-4)", t => {
      // Create a simple root box (depth 0)
      let root = HierarchyBuilder.makeBox(
        ~name="Root",
        Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
      )

      // Should not generate warnings at depth 0-4
      let warnings0 = HierarchyBuilder.collectDeepNestingWarnings(root, 0, ~threshold=4)
      t->expect(Array.length(warnings0))->Expect.toBe(0)

      let warnings4 = HierarchyBuilder.collectDeepNestingWarnings(root, 4, ~threshold=4)
      t->expect(Array.length(warnings4))->Expect.toBe(0)
    })

    test("should warn when depth exceeds threshold of 4", t => {
      // Create a deeply nested box at depth 5
      let deepBox = HierarchyBuilder.makeBox(
        ~name="DeepBox",
        Bounds.make(~top=5, ~left=5, ~bottom=8, ~right=8),
      )

      // Should generate warning at depth 5 (threshold is 4)
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(deepBox, 5, ~threshold=4)

      t->expect(Array.length(warnings))->Expect.toBe(1)

      // Verify warning details
      let warning = Array.getUnsafe(warnings, 0)
      t->expect(warning.severity)->Expect.toEqual(ErrorTypes.Warning)

      switch warning.code {
      | DeepNesting({depth, position}) => {
          t->expect(depth)->Expect.toBe(5)
          t->expect(position.row)->Expect.toBe(5)
          t->expect(position.col)->Expect.toBe(5)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected DeepNesting warning
      }
    })

    test("should collect warnings from all children recursively", t => {
      // Create parent box (depth 4)
      let parent = HierarchyBuilder.makeBox(
        ~name="Parent",
        Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20),
      )

      // Create two children (depth 5 - both should warn)
      let child1 = HierarchyBuilder.makeBox(
        ~name="Child1",
        Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8),
      )
      let child2 = HierarchyBuilder.makeBox(
        ~name="Child2",
        Bounds.make(~top=12, ~left=12, ~bottom=18, ~right=18),
      )

      // Add children to parent
      parent.children->Array.push(child1)->ignore
      parent.children->Array.push(child2)->ignore

      // Collect warnings starting at depth 4 (so children will be at depth 5)
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(parent, 4, ~threshold=4)

      // Should have 2 warnings (one for each child)
      t->expect(Array.length(warnings))->Expect.toBe(2)
    })

    test("should handle custom threshold", t => {
      let box = HierarchyBuilder.makeBox(
        ~name="Box",
        Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5),
      )

      // With threshold 2, depth 3 should warn
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(box, 3, ~threshold=2)
      t->expect(Array.length(warnings))->Expect.toBe(1)

      // With threshold 5, depth 3 should not warn
      let warnings2 = HierarchyBuilder.collectDeepNestingWarnings(box, 3, ~threshold=5)
      t->expect(Array.length(warnings2))->Expect.toBe(0)
    })
  })

  describe("detectDeepNesting", () => {
    test("should detect deep nesting in complete hierarchy", t => {
      // Create a 5-level deep hierarchy
      let root = HierarchyBuilder.makeBox(
        ~name="Root",
        Bounds.make(~top=0, ~left=0, ~bottom=50, ~right=50),
      )
      let level1 = HierarchyBuilder.makeBox(
        ~name="Level1",
        Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48),
      )
      let level2 = HierarchyBuilder.makeBox(
        ~name="Level2",
        Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46),
      )
      let level3 = HierarchyBuilder.makeBox(
        ~name="Level3",
        Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44),
      )
      let level4 = HierarchyBuilder.makeBox(
        ~name="Level4",
        Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42),
      )
      let level5 = HierarchyBuilder.makeBox(
        ~name="Level5",
        Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40),
      )

      // Build hierarchy
      root.children->Array.push(level1)->ignore
      level1.children->Array.push(level2)->ignore
      level2.children->Array.push(level3)->ignore
      level3.children->Array.push(level4)->ignore
      level4.children->Array.push(level5)->ignore

      // Detect warnings
      let warnings = HierarchyBuilder.detectDeepNesting([root], ~threshold=4)

      // Should warn for level5 (depth 5)
      t->expect(Array.length(warnings))->Expect.toBe(1)

      switch warnings[0] {
      | Some(warning) =>
        switch warning.code {
        | DeepNesting({depth, position}) => {
            t->expect(depth)->Expect.toBe(5)
            t->expect(position.row)->Expect.toBe(10)
            t->expect(position.col)->Expect.toBe(10)
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected DeepNesting warning
        }
      | None => t->expect(true)->Expect.toBe(false) // fail: Expected warning to exist
      }
    })

    test("should detect multiple deep boxes in different branches", t => {
      // Create root with two branches
      let root = HierarchyBuilder.makeBox(
        ~name="Root",
        Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=100),
      )

      // Branch 1: 5 levels deep
      let b1_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48),
      )
      let b1_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46),
      )
      let b1_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44),
      )
      let b1_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42),
      )
      let b1_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40),
      )

      // Branch 2: 6 levels deep
      let b2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=52, ~left=52, ~bottom=98, ~right=98),
      )
      let b2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=54, ~left=54, ~bottom=96, ~right=96),
      )
      let b2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=56, ~left=56, ~bottom=94, ~right=94),
      )
      let b2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=58, ~left=58, ~bottom=92, ~right=92),
      )
      let b2_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=60, ~left=60, ~bottom=90, ~right=90),
      )
      let b2_l6 = HierarchyBuilder.makeBox(
        Bounds.make(~top=62, ~left=62, ~bottom=88, ~right=88),
      )

      // Build hierarchies
      root.children->Array.push(b1_l1)->ignore
      root.children->Array.push(b2_l1)->ignore

      b1_l1.children->Array.push(b1_l2)->ignore
      b1_l2.children->Array.push(b1_l3)->ignore
      b1_l3.children->Array.push(b1_l4)->ignore
      b1_l4.children->Array.push(b1_l5)->ignore

      b2_l1.children->Array.push(b2_l2)->ignore
      b2_l2.children->Array.push(b2_l3)->ignore
      b2_l3.children->Array.push(b2_l4)->ignore
      b2_l4.children->Array.push(b2_l5)->ignore
      b2_l5.children->Array.push(b2_l6)->ignore

      // Detect warnings
      let warnings = HierarchyBuilder.detectDeepNesting([root], ~threshold=4)

      // Should warn for b1_l5 (depth 5), b2_l5 (depth 5), and b2_l6 (depth 6)
      t->expect(Array.length(warnings))->Expect.toBe(3)
    })

    test("should handle multiple root boxes", t => {
      // Create two separate root hierarchies
      let root1 = HierarchyBuilder.makeBox(
        ~name="Root1",
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30),
      )
      let root1_child = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=28, ~right=28),
      )

      let root2 = HierarchyBuilder.makeBox(
        ~name="Root2",
        Bounds.make(~top=40, ~left=40, ~bottom=90, ~right=90),
      )
      let root2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=42, ~left=42, ~bottom=88, ~right=88),
      )
      let root2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=44, ~left=44, ~bottom=86, ~right=86),
      )
      let root2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=46, ~left=46, ~bottom=84, ~right=84),
      )
      let root2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=48, ~left=48, ~bottom=82, ~right=82),
      )
      let root2_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=50, ~left=50, ~bottom=80, ~right=80),
      )

      // Build hierarchies
      root1.children->Array.push(root1_child)->ignore

      root2.children->Array.push(root2_l1)->ignore
      root2_l1.children->Array.push(root2_l2)->ignore
      root2_l2.children->Array.push(root2_l3)->ignore
      root2_l3.children->Array.push(root2_l4)->ignore
      root2_l4.children->Array.push(root2_l5)->ignore

      // Detect warnings
      let warnings = HierarchyBuilder.detectDeepNesting([root1, root2], ~threshold=4)

      // Should warn only for root2_l5 (depth 5)
      t->expect(Array.length(warnings))->Expect.toBe(1)
    })

    test("should return empty array when no deep nesting", t => {
      // Create shallow hierarchy (max depth 2)
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30),
      )
      let child1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=14, ~right=14),
      )
      let child2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=16, ~left=16, ~bottom=28, ~right=28),
      )

      root.children->Array.push(child1)->ignore
      root.children->Array.push(child2)->ignore

      // Detect warnings
      let warnings = HierarchyBuilder.detectDeepNesting([root], ~threshold=4)

      t->expect(Array.length(warnings))->Expect.toBe(0)
    })
  })

  describe("getMaxDepth", () => {
    test("should return 0 for empty array", t => {
      let maxDepth = HierarchyBuilder.getMaxDepth([])
      t->expect(maxDepth)->Expect.toBe(0)
    })

    test("should return 0 for single root box with no children", t => {
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10),
      )
      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      t->expect(maxDepth)->Expect.toBe(0)
    })

    test("should calculate max depth for single branch", t => {
      // Create 3-level hierarchy
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30),
      )
      let level1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=28, ~right=28),
      )
      let level2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=26, ~right=26),
      )

      root.children->Array.push(level1)->ignore
      level1.children->Array.push(level2)->ignore

      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      t->expect(maxDepth)->Expect.toBe(2)
    })

    test("should find max depth across multiple branches", t => {
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=100),
      )

      // Branch 1: depth 2
      let b1_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=20, ~right=20),
      )
      let b1_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=18, ~right=18),
      )

      // Branch 2: depth 4 (this is the max)
      let b2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=30, ~left=30, ~bottom=98, ~right=98),
      )
      let b2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=32, ~left=32, ~bottom=96, ~right=96),
      )
      let b2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=34, ~left=34, ~bottom=94, ~right=94),
      )
      let b2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=36, ~left=36, ~bottom=92, ~right=92),
      )

      // Build hierarchies
      root.children->Array.push(b1_l1)->ignore
      root.children->Array.push(b2_l1)->ignore

      b1_l1.children->Array.push(b1_l2)->ignore

      b2_l1.children->Array.push(b2_l2)->ignore
      b2_l2.children->Array.push(b2_l3)->ignore
      b2_l3.children->Array.push(b2_l4)->ignore

      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      t->expect(maxDepth)->Expect.toBe(4)
    })
  })

  describe("Integration with buildHierarchy", () => {
    test("should detect deep nesting after building hierarchy from flat array", t => {
      // Create flat array of boxes representing 5-level nesting
      let boxes = [
        HierarchyBuilder.makeBox(
          ~name="Root",
          Bounds.make(~top=0, ~left=0, ~bottom=50, ~right=50),
        ),
        HierarchyBuilder.makeBox(
          ~name="L1",
          Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48),
        ),
        HierarchyBuilder.makeBox(
          ~name="L2",
          Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46),
        ),
        HierarchyBuilder.makeBox(
          ~name="L3",
          Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44),
        ),
        HierarchyBuilder.makeBox(
          ~name="L4",
          Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42),
        ),
        HierarchyBuilder.makeBox(
          ~name="L5",
          Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40),
        ),
      ]

      // Build hierarchy
      let result = HierarchyBuilder.buildHierarchy(boxes)

      switch result {
      | Ok(roots) => {
          // Should have 1 root
          t->expect(Array.length(roots))->Expect.toBe(1)

          // Detect deep nesting
          let warnings = HierarchyBuilder.detectDeepNesting(roots, ~threshold=4)

          // Should warn for L5 (depth 5)
          t->expect(Array.length(warnings))->Expect.toBe(1)

          // Verify max depth
          let maxDepth = HierarchyBuilder.getMaxDepth(roots)
          t->expect(maxDepth)->Expect.toBe(5)
        }
      | Error(_) => t->expect(true)->Expect.toBe(false) // fail: buildHierarchy should succeed
      }
    })
  })
})
