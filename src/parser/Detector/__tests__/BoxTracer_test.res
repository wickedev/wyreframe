// BoxTracer_test.res
// Unit tests for BoxTracer width validation and box tracing

open Vitest

describe("BoxTracer - Width Validation", () => {
  test("should detect mismatched width between top and bottom edges", t => {
    // Create a malformed box with different top and bottom widths
    let input = [
      "+-----+",  // Top: 7 chars wide (5 dashes + 2 corners)
      "|     |",
      "+-------+", // Bottom: 9 chars wide (7 dashes + 2 corners) - MISMATCH!
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Error(err) => {
        // Verify we get a MismatchedWidth error
        switch err.code {
        | ErrorTypes.MismatchedWidth({topWidth, bottomWidth, topLeft: pos}) => {
            t->expect(topWidth)->Expect.toBe(6)  // 0 to 6 = 6 chars
            t->expect(bottomWidth)->Expect.toBe(8) // 0 to 8 = 8 chars
            t->expect(pos.row)->Expect.toBe(0)
            t->expect(pos.col)->Expect.toBe(0)
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected MismatchedWidth error
        }
      }
    | Ok(_) => t->expect(true)->Expect.toBe(false) // fail: Expected error for mismatched width, but got Ok
    }
  })

  test("should successfully trace box with matching widths", t => {
    // Create a well-formed box with matching top and bottom widths
    let input = [
      "+-----+",
      "|     |",
      "+-----+", // Same width as top
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Ok(box) => {
        // Verify box bounds are correct
        t->expect(box.bounds.top)->Expect.toBe(0)
        t->expect(box.bounds.left)->Expect.toBe(0)
        t->expect(box.bounds.bottom)->Expect.toBe(2)
        t->expect(box.bounds.right)->Expect.toBe(6)

        // Verify no name (unnamed box)
        t->expect(box.name)->Expect.toBe(None)
      }
    | Error(err) => {
        Console.log(err)
        t->expect(true)->Expect.toBe(false) // fail: Expected successful box trace for matching widths
      }
    }
  })

  test("should extract box name and validate width", t => {
    let input = [
      "+--Login--+",
      "|         |",
      "+--Login--+",
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Ok(box) => {
        // Verify box name extraction
        t->expect(box.name)->Expect.toBe(Some("Login"))

        // Verify bounds
        t->expect(Types.Bounds.width(box.bounds))->Expect.toBe(10)
        t->expect(Types.Bounds.height(box.bounds))->Expect.toBe(2)
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Expected successful trace for named box
    }
  })
})

describe("BoxTracer - Misaligned Closing Border Detection (Issue #4)", () => {
  test("should detect misaligned closing border and generate warning", t => {
    // Issue #4: Wireframe with misaligned closing '|' should parse successfully
    // but generate a warning
    let input = [
      "+---------------------------+",
      "|       'WYREFRAME'          |", // Row 1: closing '|' at col 29 (1 char too far right)
      "|                           |",
      "|  +---------------------+  |",
      "|  | #email              |  |",
      "|  +---------------------+  |",
      "|                           |",
      "|       [ Login ]           |",
      "|                           |",
      "+---------------------------+",
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    // First, verify the box traces successfully
    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Ok(box) => {
        // Box should be traced successfully
        t->expect(box.bounds.top)->Expect.toBe(0)
        t->expect(box.bounds.right)->Expect.toBe(28)

        // Now validate interior alignment - this should find the misalignment
        let warnings = BoxTracer.validateInteriorAlignment(grid, box.bounds)

        // Should have at least one warning for row 1
        t->expect(Array.length(warnings) > 0)->Expect.toBe(true)

        // Check the first warning is for misaligned closing border
        if Array.length(warnings) > 0 {
          let firstWarning = warnings[0]
          switch firstWarning {
          | Some(w) => {
              switch w.code {
              | ErrorTypes.MisalignedClosingBorder({expectedCol, actualCol, _}) => {
                  t->expect(expectedCol)->Expect.toBe(28) // Expected closing at col 28
                  t->expect(actualCol)->Expect.toBe(29)   // But found at col 29
                }
              | _ => t->expect(true)->Expect.toBe(false) // fail: Expected MisalignedClosingBorder warning
              }
            }
          | None => t->expect(true)->Expect.toBe(false) // fail: Warning array empty
          }
        }
      }
    | Error(err) => {
        Console.log(err)
        t->expect(true)->Expect.toBe(false) // fail: Box should trace successfully even with misaligned border
      }
    }
  })

  test("should not generate warning for properly aligned box", t => {
    let input = [
      "+---------------------------+",
      "|       'WYREFRAME'         |", // Properly aligned
      "|                           |",
      "+---------------------------+",
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Ok(box) => {
        // Validate interior alignment - should have no warnings
        let warnings = BoxTracer.validateInteriorAlignment(grid, box.bounds)
        t->expect(Array.length(warnings))->Expect.toBe(0)
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Well-formed box should trace successfully
    }
  })

  test("should detect multiple misaligned rows", t => {
    let input = [
      "+---------------+",
      "| Line 1       |", // Missing a space, but pipe is at expected position
      "| Line 2        |", // Extra space, pipe is 1 char too far right
      "| Line 3         |", // Even more spaces, pipe is 2 chars too far right
      "+---------------+",
    ]

    let grid = Grid.fromLines(input)
    let topLeft = Types.Position.make(0, 0)

    let result = BoxTracer.traceBox(grid, topLeft)

    switch result {
    | Ok(box) => {
        let warnings = BoxTracer.validateInteriorAlignment(grid, box.bounds)

        // Should detect warnings for rows with misaligned pipes
        // Row 2 (index 2) and Row 3 (index 3) have misaligned closing '|'
        t->expect(Array.length(warnings) >= 2)->Expect.toBe(true)
      }
    | Error(_) => t->expect(true)->Expect.toBe(false) // fail: Box should trace successfully
    }
  })
})
