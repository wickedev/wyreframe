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
