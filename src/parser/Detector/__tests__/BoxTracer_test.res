// BoxTracer_test.res
// Unit tests for BoxTracer width validation and box tracing

open Jest
open Expect

describe("BoxTracer - Width Validation (Task 12)", () => {
  test("should detect mismatched width between top and bottom edges", () => {
    // Create a malformed box with different top and bottom widths
    let input = [
      "+-----+",  // Top: 7 chars wide (5 dashes + 2 corners)
      "|     |",
      "+-------+", // Bottom: 9 chars wide (7 dashes + 2 corners) - MISMATCH!
    ]
    
    let grid = Grid.fromLines(input)
    let topLeft = Position.make(0, 0)
    
    let result = BoxTracer.traceBox(grid, topLeft)
    
    switch result {
    | Error(err) => {
        // Verify we get a MismatchedWidth error
        switch err.code {
        | ErrorTypes.MismatchedWidth({topWidth, bottomWidth, topLeft: pos}) => {
            expect(topWidth)->toBe(6)  // 0 to 6 = 6 chars
            expect(bottomWidth)->toBe(8) // 0 to 8 = 8 chars
            expect(pos.row)->toBe(0)
            expect(pos.col)->toBe(0)
          }
        | _ => fail("Expected MismatchedWidth error")
        }
      }
    | Ok(_) => fail("Expected error for mismatched width, but got Ok")
    }
  })
  
  test("should successfully trace box with matching widths", () => {
    // Create a well-formed box with matching top and bottom widths
    let input = [
      "+-----+",
      "|     |",
      "+-----+", // Same width as top
    ]
    
    let grid = Grid.fromLines(input)
    let topLeft = Position.make(0, 0)
    
    let result = BoxTracer.traceBox(grid, topLeft)
    
    switch result {
    | Ok(box) => {
        // Verify box bounds are correct
        expect(box.bounds.top)->toBe(0)
        expect(box.bounds.left)->toBe(0)
        expect(box.bounds.bottom)->toBe(2)
        expect(box.bounds.right)->toBe(6)
        
        // Verify no name (unnamed box)
        expect(box.name)->toBe(None)
      }
    | Error(err) => {
        Console.log(err)
        fail("Expected successful box trace for matching widths")
      }
    }
  })
  
  test("should extract box name and validate width", () => {
    let input = [
      "+--Login--+",
      "|         |",
      "+--Login--+",
    ]
    
    let grid = Grid.fromLines(input)
    let topLeft = Position.make(0, 0)
    
    let result = BoxTracer.traceBox(grid, topLeft)
    
    switch result {
    | Ok(box) => {
        // Verify box name extraction
        expect(box.name)->toBe(Some("Login"))
        
        // Verify bounds
        expect(Bounds.width(box.bounds))->toBe(10)
        expect(Bounds.height(box.bounds))->toBe(2)
      }
    | Error(_) => fail("Expected successful trace for named box")
    }
  })
})
