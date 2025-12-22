// HierarchyBuilder_test.res
// Tests for hierarchy building functionality
// Task 16: Test 2-level, 3-level, 4-level nesting

open Test

describe("HierarchyBuilder - Task 15: Containment Detection", () => {
  test("contains returns true when outer completely contains inner", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn
    let inner = Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn

    expect(HierarchyBuilder.contains(outer, inner))->toBe(true)
  })

  test("contains returns false when boxes are equal", () => {
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn

    expect(HierarchyBuilder.contains(bounds, bounds))->toBe(false)
  })

  test("contains returns false when boxes are disjoint", () => {
    let box1 = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Belt.Option.getExn
    let box2 = Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)->Belt.Option.getExn

    expect(HierarchyBuilder.contains(box1, box2))->toBe(false)
  })

  test("contains returns false when boxes partially overlap", () => {
    let box1 = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn
    let box2 = Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Belt.Option.getExn

    expect(HierarchyBuilder.contains(box1, box2))->toBe(false)
  })

  test("contains returns false when inner touches outer's edge", () => {
    let outer = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn
    let inner = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Belt.Option.getExn

    // Inner touches outer's top-left edge, so not strict containment
    expect(HierarchyBuilder.contains(outer, inner))->toBe(false)
  })
})

describe("HierarchyBuilder - Task 16: findParent", () => {
  test("findParent returns None for root box (no container)", () => {
    let box = HierarchyBuilder.makeBox(
      ~name=Some("Root"),
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
    )

    let candidates = [box]

    expect(HierarchyBuilder.findParent(box, candidates))->toEqual(None)
  })

  test("findParent returns immediate parent (smallest containing box)", () => {
    let grandparent = HierarchyBuilder.makeBox(
      ~name=Some("Grandparent"),
      Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Belt.Option.getExn,
    )

    let parent = HierarchyBuilder.makeBox(
      ~name=Some("Parent"),
      Bounds.make(~top=2, ~left=2, ~bottom=18, ~right=18)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      ~name=Some("Child"),
      Bounds.make(~top=4, ~left=4, ~bottom=16, ~right=16)->Belt.Option.getExn,
    )

    let candidates = [grandparent, parent, child]

    // Child's immediate parent should be parent, not grandparent
    expect(HierarchyBuilder.findParent(child, candidates))->toEqual(Some(parent))
  })

  test("findParent ignores boxes that don't contain the target", () => {
    let box1 = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Belt.Option.getExn,
    )

    let box2 = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)->Belt.Option.getExn,
    )

    let candidates = [box1, box2]

    expect(HierarchyBuilder.findParent(box2, candidates))->toEqual(None)
  })
})

describe("HierarchyBuilder - Task 16: buildHierarchy - 2-level nesting", () => {
  test("builds hierarchy with one root and one child", () => {
    let parent = HierarchyBuilder.makeBox(
      ~name=Some("Parent"),
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      ~name=Some("Child"),
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn,
    )

    let boxes = [parent, child]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root (parent)
        expect(Array.length(roots))->toBe(1)

        switch roots[0] {
        | Some(root) => {
            expect(root.name)->toEqual(Some("Parent"))
            // Parent should have 1 child
            expect(Array.length(root.children))->toBe(1)

            switch root.children[0] {
            | Some(childBox) => expect(childBox.name)->toEqual(Some("Child"))
            | None => fail("Expected child to exist")
            }
          }
        | None => fail("Expected root to exist")
        }
      }
    | Error(_) => fail("Expected Ok result")
    }
  })

  test("builds hierarchy with one root and multiple children", () => {
    let parent = HierarchyBuilder.makeBox(
      ~name=Some("Parent"),
      Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Belt.Option.getExn,
    )

    let child1 = HierarchyBuilder.makeBox(
      ~name=Some("Child1"),
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn,
    )

    let child2 = HierarchyBuilder.makeBox(
      ~name=Some("Child2"),
      Bounds.make(~top=12, ~left=12, ~bottom=18, ~right=18)->Belt.Option.getExn,
    )

    let boxes = [parent, child1, child2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        expect(Array.length(roots))->toBe(1)

        switch roots[0] {
        | Some(root) => {
            expect(root.name)->toEqual(Some("Parent"))
            // Parent should have 2 children
            expect(Array.length(root.children))->toBe(2)
          }
        | None => fail("Expected root to exist")
        }
      }
    | Error(_) => fail("Expected Ok result")
    }
  })
})

describe("HierarchyBuilder - Task 16: buildHierarchy - 3-level nesting", () => {
  test("builds hierarchy with 3 levels: root -> child -> grandchild", () => {
    let root = HierarchyBuilder.makeBox(
      ~name=Some("Root"),
      Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      ~name=Some("Child"),
      Bounds.make(~top=5, ~left=5, ~bottom=25, ~right=25)->Belt.Option.getExn,
    )

    let grandchild = HierarchyBuilder.makeBox(
      ~name=Some("Grandchild"),
      Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Belt.Option.getExn,
    )

    let boxes = [root, child, grandchild]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root
        expect(Array.length(roots))->toBe(1)

        switch roots[0] {
        | Some(rootBox) => {
            expect(rootBox.name)->toEqual(Some("Root"))
            // Root should have 1 child
            expect(Array.length(rootBox.children))->toBe(1)

            switch rootBox.children[0] {
            | Some(childBox) => {
                expect(childBox.name)->toEqual(Some("Child"))
                // Child should have 1 grandchild
                expect(Array.length(childBox.children))->toBe(1)

                switch childBox.children[0] {
                | Some(grandchildBox) => expect(grandchildBox.name)->toEqual(Some("Grandchild"))
                | None => fail("Expected grandchild to exist")
                }
              }
            | None => fail("Expected child to exist")
            }
          }
        | None => fail("Expected root to exist")
        }
      }
    | Error(_) => fail("Expected Ok result")
    }
  })

  test("getDepth correctly calculates depth for 3-level hierarchy", () => {
    let root = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      Bounds.make(~top=5, ~left=5, ~bottom=25, ~right=25)->Belt.Option.getExn,
    )

    let grandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=20, ~right=20)->Belt.Option.getExn,
    )

    let allBoxes = [root, child, grandchild]

    expect(HierarchyBuilder.getDepth(root, allBoxes))->toBe(0)
    expect(HierarchyBuilder.getDepth(child, allBoxes))->toBe(1)
    expect(HierarchyBuilder.getDepth(grandchild, allBoxes))->toBe(2)
  })
})

describe("HierarchyBuilder - Task 16: buildHierarchy - 4-level nesting", () => {
  test("builds hierarchy with 4 levels: root -> child -> grandchild -> great-grandchild", () => {
    let root = HierarchyBuilder.makeBox(
      ~name=Some("Root"),
      Bounds.make(~top=0, ~left=0, ~bottom=40, ~right=40)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      ~name=Some("Child"),
      Bounds.make(~top=5, ~left=5, ~bottom=35, ~right=35)->Belt.Option.getExn,
    )

    let grandchild = HierarchyBuilder.makeBox(
      ~name=Some("Grandchild"),
      Bounds.make(~top=10, ~left=10, ~bottom=30, ~right=30)->Belt.Option.getExn,
    )

    let greatGrandchild = HierarchyBuilder.makeBox(
      ~name=Some("GreatGrandchild"),
      Bounds.make(~top=15, ~left=15, ~bottom=25, ~right=25)->Belt.Option.getExn,
    )

    let boxes = [root, child, grandchild, greatGrandchild]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return only the root
        expect(Array.length(roots))->toBe(1)

        switch roots[0] {
        | Some(rootBox) => {
            expect(rootBox.name)->toEqual(Some("Root"))
            expect(Array.length(rootBox.children))->toBe(1)

            switch rootBox.children[0] {
            | Some(childBox) => {
                expect(childBox.name)->toEqual(Some("Child"))
                expect(Array.length(childBox.children))->toBe(1)

                switch childBox.children[0] {
                | Some(grandchildBox) => {
                    expect(grandchildBox.name)->toEqual(Some("Grandchild"))
                    expect(Array.length(grandchildBox.children))->toBe(1)

                    switch grandchildBox.children[0] {
                    | Some(greatGrandchildBox) =>
                      expect(greatGrandchildBox.name)->toEqual(Some("GreatGrandchild"))
                    | None => fail("Expected great-grandchild to exist")
                    }
                  }
                | None => fail("Expected grandchild to exist")
                }
              }
            | None => fail("Expected child to exist")
            }
          }
        | None => fail("Expected root to exist")
        }
      }
    | Error(_) => fail("Expected Ok result")
    }
  })

  test("getDepth correctly calculates depth for 4-level hierarchy", () => {
    let root = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=40, ~right=40)->Belt.Option.getExn,
    )

    let child = HierarchyBuilder.makeBox(
      Bounds.make(~top=5, ~left=5, ~bottom=35, ~right=35)->Belt.Option.getExn,
    )

    let grandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=30, ~right=30)->Belt.Option.getExn,
    )

    let greatGrandchild = HierarchyBuilder.makeBox(
      Bounds.make(~top=15, ~left=15, ~bottom=25, ~right=25)->Belt.Option.getExn,
    )

    let allBoxes = [root, child, grandchild, greatGrandchild]

    expect(HierarchyBuilder.getDepth(root, allBoxes))->toBe(0)
    expect(HierarchyBuilder.getDepth(child, allBoxes))->toBe(1)
    expect(HierarchyBuilder.getDepth(grandchild, allBoxes))->toBe(2)
    expect(HierarchyBuilder.getDepth(greatGrandchild, allBoxes))->toBe(3)
  })
})

describe("HierarchyBuilder - Task 16: buildHierarchy - Multiple roots", () => {
  test("handles multiple root boxes with children", () => {
    let root1 = HierarchyBuilder.makeBox(
      ~name=Some("Root1"),
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
    )

    let root1Child = HierarchyBuilder.makeBox(
      ~name=Some("Root1Child"),
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn,
    )

    let root2 = HierarchyBuilder.makeBox(
      ~name=Some("Root2"),
      Bounds.make(~top=20, ~left=20, ~bottom=30, ~right=30)->Belt.Option.getExn,
    )

    let root2Child = HierarchyBuilder.makeBox(
      ~name=Some("Root2Child"),
      Bounds.make(~top=22, ~left=22, ~bottom=28, ~right=28)->Belt.Option.getExn,
    )

    let boxes = [root1, root1Child, root2, root2Child]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 2 roots
        expect(Array.length(roots))->toBe(2)

        // Each root should have 1 child
        roots->Array.forEach(root => {
          expect(Array.length(root.children))->toBe(1)
        })
      }
    | Error(_) => fail("Expected Ok result")
    }
  })
})

describe("HierarchyBuilder - Task 16: buildHierarchy - Error cases", () => {
  test("detects overlapping boxes (invalid partial overlap)", () => {
    let box1 = HierarchyBuilder.makeBox(
      ~name=Some("Box1"),
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
    )

    let box2 = HierarchyBuilder.makeBox(
      ~name=Some("Box2"),
      // Overlaps with box1 but doesn't contain or is contained by it
      Bounds.make(~top=5, ~left=5, ~bottom=15, ~right=15)->Belt.Option.getExn,
    )

    let boxes = [box1, box2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(_) => fail("Expected Error for overlapping boxes")
    | Error(HierarchyBuilder.OverlappingBoxes({box1: b1, box2: b2})) => {
        // Verify the error contains the overlapping boxes
        expect(b1 === box1 || b1 === box2)->toBe(true)
        expect(b2 === box1 || b2 === box2)->toBe(true)
        expect(b1 !== b2)->toBe(true)
      }
    | Error(_) => fail("Expected OverlappingBoxes error")
    }
  })

  test("allows disjoint boxes (no overlap)", () => {
    let box1 = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Belt.Option.getExn,
    )

    let box2 = HierarchyBuilder.makeBox(
      Bounds.make(~top=10, ~left=10, ~bottom=15, ~right=15)->Belt.Option.getExn,
    )

    let boxes = [box1, box2]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 2 roots (both boxes are disjoint)
        expect(Array.length(roots))->toBe(2)
      }
    | Error(_) => fail("Expected Ok result for disjoint boxes")
    }
  })

  test("allows nested boxes (one contains the other)", () => {
    let outer = HierarchyBuilder.makeBox(
      Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
    )

    let inner = HierarchyBuilder.makeBox(
      Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn,
    )

    let boxes = [outer, inner]
    let result = HierarchyBuilder.buildHierarchy(boxes)

    switch result {
    | Ok(roots) => {
        // Should return 1 root with 1 child
        expect(Array.length(roots))->toBe(1)

        switch roots[0] {
        | Some(root) => expect(Array.length(root.children))->toBe(1)
        | None => fail("Expected root to exist")
        }
      }
    | Error(_) => fail("Expected Ok result for nested boxes")
    }
  })
})

// ============================================================================
// Task 42: Deep Nesting Warning Detection Tests
// ============================================================================

describe("HierarchyBuilder - Task 42: Deep Nesting Detection", () => {
  describe("collectDeepNestingWarnings", () => {
    test("should not warn for boxes at or below threshold (depth 0-4)", () => {
      // Create a simple root box (depth 0)
      let root = HierarchyBuilder.makeBox(
        ~name=Some("Root"),
        Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
      )

      // Should not generate warnings at depth 0-4
      let warnings0 = HierarchyBuilder.collectDeepNestingWarnings(root, 0, ~threshold=4)
      expect(Array.length(warnings0))->toBe(0)

      let warnings4 = HierarchyBuilder.collectDeepNestingWarnings(root, 4, ~threshold=4)
      expect(Array.length(warnings4))->toBe(0)
    })

    test("should warn when depth exceeds threshold of 4", () => {
      // Create a deeply nested box at depth 5
      let deepBox = HierarchyBuilder.makeBox(
        ~name=Some("DeepBox"),
        Bounds.make(~top=5, ~left=5, ~bottom=8, ~right=8)->Belt.Option.getExn,
      )

      // Should generate warning at depth 5 (threshold is 4)
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(deepBox, 5, ~threshold=4)

      expect(Array.length(warnings))->toBe(1)

      // Verify warning details
      let warning = warnings[0]->Belt.Option.getExn
      expect(warning.severity)->toEqual(ErrorTypes.Warning)

      switch warning.code {
      | DeepNesting({depth, position}) => {
          expect(depth)->toBe(5)
          expect(position.row)->toBe(5)
          expect(position.col)->toBe(5)
        }
      | _ => fail("Expected DeepNesting warning")
      }
    })

    test("should collect warnings from all children recursively", () => {
      // Create parent box (depth 4)
      let parent = HierarchyBuilder.makeBox(
        ~name=Some("Parent"),
        Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=20)->Belt.Option.getExn,
      )

      // Create two children (depth 5 - both should warn)
      let child1 = HierarchyBuilder.makeBox(
        ~name=Some("Child1"),
        Bounds.make(~top=2, ~left=2, ~bottom=8, ~right=8)->Belt.Option.getExn,
      )
      let child2 = HierarchyBuilder.makeBox(
        ~name=Some("Child2"),
        Bounds.make(~top=12, ~left=12, ~bottom=18, ~right=18)->Belt.Option.getExn,
      )

      // Add children to parent
      parent.children->Array.push(child1)->ignore
      parent.children->Array.push(child2)->ignore

      // Collect warnings starting at depth 4 (so children will be at depth 5)
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(parent, 4, ~threshold=4)

      // Should have 2 warnings (one for each child)
      expect(Array.length(warnings))->toBe(2)
    })

    test("should handle custom threshold", () => {
      let box = HierarchyBuilder.makeBox(
        ~name=Some("Box"),
        Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=5)->Belt.Option.getExn,
      )

      // With threshold 2, depth 3 should warn
      let warnings = HierarchyBuilder.collectDeepNestingWarnings(box, 3, ~threshold=2)
      expect(Array.length(warnings))->toBe(1)

      // With threshold 5, depth 3 should not warn
      let warnings2 = HierarchyBuilder.collectDeepNestingWarnings(box, 3, ~threshold=5)
      expect(Array.length(warnings2))->toBe(0)
    })
  })

  describe("detectDeepNesting", () => {
    test("should detect deep nesting in complete hierarchy", () => {
      // Create a 5-level deep hierarchy
      let root = HierarchyBuilder.makeBox(
        ~name=Some("Root"),
        Bounds.make(~top=0, ~left=0, ~bottom=50, ~right=50)->Belt.Option.getExn,
      )
      let level1 = HierarchyBuilder.makeBox(
        ~name=Some("Level1"),
        Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48)->Belt.Option.getExn,
      )
      let level2 = HierarchyBuilder.makeBox(
        ~name=Some("Level2"),
        Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46)->Belt.Option.getExn,
      )
      let level3 = HierarchyBuilder.makeBox(
        ~name=Some("Level3"),
        Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44)->Belt.Option.getExn,
      )
      let level4 = HierarchyBuilder.makeBox(
        ~name=Some("Level4"),
        Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42)->Belt.Option.getExn,
      )
      let level5 = HierarchyBuilder.makeBox(
        ~name=Some("Level5"),
        Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40)->Belt.Option.getExn,
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
      expect(Array.length(warnings))->toBe(1)

      switch warnings[0] {
      | Some(warning) =>
        switch warning.code {
        | DeepNesting({depth, position}) => {
            expect(depth)->toBe(5)
            expect(position.row)->toBe(10)
            expect(position.col)->toBe(10)
          }
        | _ => fail("Expected DeepNesting warning")
        }
      | None => fail("Expected warning to exist")
      }
    })

    test("should detect multiple deep boxes in different branches", () => {
      // Create root with two branches
      let root = HierarchyBuilder.makeBox(
        ~name=Some("Root"),
        Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=100)->Belt.Option.getExn,
      )

      // Branch 1: 5 levels deep
      let b1_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48)->Belt.Option.getExn,
      )
      let b1_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46)->Belt.Option.getExn,
      )
      let b1_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44)->Belt.Option.getExn,
      )
      let b1_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42)->Belt.Option.getExn,
      )
      let b1_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40)->Belt.Option.getExn,
      )

      // Branch 2: 6 levels deep
      let b2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=52, ~left=52, ~bottom=98, ~right=98)->Belt.Option.getExn,
      )
      let b2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=54, ~left=54, ~bottom=96, ~right=96)->Belt.Option.getExn,
      )
      let b2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=56, ~left=56, ~bottom=94, ~right=94)->Belt.Option.getExn,
      )
      let b2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=58, ~left=58, ~bottom=92, ~right=92)->Belt.Option.getExn,
      )
      let b2_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=60, ~left=60, ~bottom=90, ~right=90)->Belt.Option.getExn,
      )
      let b2_l6 = HierarchyBuilder.makeBox(
        Bounds.make(~top=62, ~left=62, ~bottom=88, ~right=88)->Belt.Option.getExn,
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
      expect(Array.length(warnings))->toBe(3)
    })

    test("should handle multiple root boxes", () => {
      // Create two separate root hierarchies
      let root1 = HierarchyBuilder.makeBox(
        ~name=Some("Root1"),
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30)->Belt.Option.getExn,
      )
      let root1_child = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=28, ~right=28)->Belt.Option.getExn,
      )

      let root2 = HierarchyBuilder.makeBox(
        ~name=Some("Root2"),
        Bounds.make(~top=40, ~left=40, ~bottom=90, ~right=90)->Belt.Option.getExn,
      )
      let root2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=42, ~left=42, ~bottom=88, ~right=88)->Belt.Option.getExn,
      )
      let root2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=44, ~left=44, ~bottom=86, ~right=86)->Belt.Option.getExn,
      )
      let root2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=46, ~left=46, ~bottom=84, ~right=84)->Belt.Option.getExn,
      )
      let root2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=48, ~left=48, ~bottom=82, ~right=82)->Belt.Option.getExn,
      )
      let root2_l5 = HierarchyBuilder.makeBox(
        Bounds.make(~top=50, ~left=50, ~bottom=80, ~right=80)->Belt.Option.getExn,
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
      expect(Array.length(warnings))->toBe(1)
    })

    test("should return empty array when no deep nesting", () => {
      // Create shallow hierarchy (max depth 2)
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30)->Belt.Option.getExn,
      )
      let child1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=14, ~right=14)->Belt.Option.getExn,
      )
      let child2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=16, ~left=16, ~bottom=28, ~right=28)->Belt.Option.getExn,
      )

      root.children->Array.push(child1)->ignore
      root.children->Array.push(child2)->ignore

      // Detect warnings
      let warnings = HierarchyBuilder.detectDeepNesting([root], ~threshold=4)

      expect(Array.length(warnings))->toBe(0)
    })
  })

  describe("getMaxDepth", () => {
    test("should return 0 for empty array", () => {
      let maxDepth = HierarchyBuilder.getMaxDepth([])
      expect(maxDepth)->toBe(0)
    })

    test("should return 0 for single root box with no children", () => {
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Belt.Option.getExn,
      )
      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      expect(maxDepth)->toBe(0)
    })

    test("should calculate max depth for single branch", () => {
      // Create 3-level hierarchy
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=30, ~right=30)->Belt.Option.getExn,
      )
      let level1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=28, ~right=28)->Belt.Option.getExn,
      )
      let level2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=26, ~right=26)->Belt.Option.getExn,
      )

      root.children->Array.push(level1)->ignore
      level1.children->Array.push(level2)->ignore

      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      expect(maxDepth)->toBe(2)
    })

    test("should find max depth across multiple branches", () => {
      let root = HierarchyBuilder.makeBox(
        Bounds.make(~top=0, ~left=0, ~bottom=100, ~right=100)->Belt.Option.getExn,
      )

      // Branch 1: depth 2
      let b1_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=2, ~left=2, ~bottom=20, ~right=20)->Belt.Option.getExn,
      )
      let b1_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=4, ~left=4, ~bottom=18, ~right=18)->Belt.Option.getExn,
      )

      // Branch 2: depth 4 (this is the max)
      let b2_l1 = HierarchyBuilder.makeBox(
        Bounds.make(~top=30, ~left=30, ~bottom=98, ~right=98)->Belt.Option.getExn,
      )
      let b2_l2 = HierarchyBuilder.makeBox(
        Bounds.make(~top=32, ~left=32, ~bottom=96, ~right=96)->Belt.Option.getExn,
      )
      let b2_l3 = HierarchyBuilder.makeBox(
        Bounds.make(~top=34, ~left=34, ~bottom=94, ~right=94)->Belt.Option.getExn,
      )
      let b2_l4 = HierarchyBuilder.makeBox(
        Bounds.make(~top=36, ~left=36, ~bottom=92, ~right=92)->Belt.Option.getExn,
      )

      // Build hierarchies
      root.children->Array.push(b1_l1)->ignore
      root.children->Array.push(b2_l1)->ignore

      b1_l1.children->Array.push(b1_l2)->ignore

      b2_l1.children->Array.push(b2_l2)->ignore
      b2_l2.children->Array.push(b2_l3)->ignore
      b2_l3.children->Array.push(b2_l4)->ignore

      let maxDepth = HierarchyBuilder.getMaxDepth([root])
      expect(maxDepth)->toBe(4)
    })
  })

  describe("Integration with buildHierarchy", () => {
    test("should detect deep nesting after building hierarchy from flat array", () => {
      // Create flat array of boxes representing 5-level nesting
      let boxes = [
        HierarchyBuilder.makeBox(
          ~name=Some("Root"),
          Bounds.make(~top=0, ~left=0, ~bottom=50, ~right=50)->Belt.Option.getExn,
        ),
        HierarchyBuilder.makeBox(
          ~name=Some("L1"),
          Bounds.make(~top=2, ~left=2, ~bottom=48, ~right=48)->Belt.Option.getExn,
        ),
        HierarchyBuilder.makeBox(
          ~name=Some("L2"),
          Bounds.make(~top=4, ~left=4, ~bottom=46, ~right=46)->Belt.Option.getExn,
        ),
        HierarchyBuilder.makeBox(
          ~name=Some("L3"),
          Bounds.make(~top=6, ~left=6, ~bottom=44, ~right=44)->Belt.Option.getExn,
        ),
        HierarchyBuilder.makeBox(
          ~name=Some("L4"),
          Bounds.make(~top=8, ~left=8, ~bottom=42, ~right=42)->Belt.Option.getExn,
        ),
        HierarchyBuilder.makeBox(
          ~name=Some("L5"),
          Bounds.make(~top=10, ~left=10, ~bottom=40, ~right=40)->Belt.Option.getExn,
        ),
      ]

      // Build hierarchy
      let result = HierarchyBuilder.buildHierarchy(boxes)

      switch result {
      | Ok(roots) => {
          // Should have 1 root
          expect(Array.length(roots))->toBe(1)

          // Detect deep nesting
          let warnings = HierarchyBuilder.detectDeepNesting(roots, ~threshold=4)

          // Should warn for L5 (depth 5)
          expect(Array.length(warnings))->toBe(1)

          // Verify max depth
          let maxDepth = HierarchyBuilder.getMaxDepth(roots)
          expect(maxDepth)->toBe(5)
        }
      | Error(_) => fail("buildHierarchy should succeed")
      }
    })
  })
})
