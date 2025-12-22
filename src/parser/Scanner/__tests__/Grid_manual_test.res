// Grid_manual_test.res
// Manual test file for Grid data structure (without Jest)
// Run with: node src/parser/Scanner/__tests__/Grid_manual_test.mjs

open Types

// Test helper
let assert = (condition: bool, message: string): unit => {
  if condition {
    Console.log("✓ PASS: " ++ message)
  } else {
    Console.error("✗ FAIL: " ++ message)
  }
}

let assertEqual = (actual: 'a, expected: 'a, message: string): unit => {
  if actual == expected {
    Console.log("✓ PASS: " ++ message)
  } else {
    Console.error("✗ FAIL: " ++ message)
    Console.error("  Expected: " ++ Any.toString(expected))
    Console.error("  Actual:   " ++ Any.toString(actual))
  }
}

Console.log("\n=== Grid Construction Tests ===\n")

// Test 1: Basic grid construction
let lines1 = ["abc", "def", "ghi"]
let grid1 = Grid.fromLines(lines1)
assertEqual(grid1.width, 3, "Grid width for uniform lines")
assertEqual(grid1.height, 3, "Grid height for uniform lines")

// Test 2: Normalization of varying length lines
let lines2 = ["abc", "de", "f"]
let grid2 = Grid.fromLines(lines2)
assertEqual(grid2.width, 3, "Grid width after normalization")
assertEqual(grid2.height, 3, "Grid height after normalization")

// Test 3: Character indices
let lines3 = ["+--+", "|  |", "+--+"]
let grid3 = Grid.fromLines(lines3)
assertEqual(Array.length(grid3.cornerIndex), 4, "Corner index count")
assertEqual(Array.length(grid3.hLineIndex), 4, "HLine index count")
assertEqual(Array.length(grid3.vLineIndex), 4, "VLine index count")

Console.log("\n=== Character Access Tests ===\n")

// Test 4: Get character at position
switch Grid.get(grid3, Position.make(0, 0)) {
| Some(Corner) => Console.log("✓ PASS: Get character at (0,0) returns Corner")
| _ => Console.error("✗ FAIL: Get character at (0,0) should return Corner")
}

// Test 5: Get out of bounds
switch Grid.get(grid3, Position.make(10, 10)) {
| None => Console.log("✓ PASS: Get character out of bounds returns None")
| _ => Console.error("✗ FAIL: Get character out of bounds should return None")
}

// Test 6: Get line
switch Grid.getLine(grid3, 0) {
| Some(line) => assertEqual(Array.length(line), 4, "Get line returns correct length")
| None => Console.error("✗ FAIL: Get line should return Some")
}

Console.log("\n=== Directional Scanning Tests ===\n")

// Test 7: Scan right
let scanResults = Grid.scanRight(grid3, Position.make(0, 0), cell => {
  switch cell {
  | Corner | HLine => true
  | _ => false
  }
})
assertEqual(Array.length(scanResults), 4, "Scan right collects correct number of characters")

// Test 8: Scan down
let scanDownResults = Grid.scanDown(grid3, Position.make(0, 0), cell => {
  switch cell {
  | Corner | VLine => true
  | _ => false
  }
})
assertEqual(Array.length(scanDownResults), 3, "Scan down collects correct number of characters")

Console.log("\n=== Search Operations Tests ===\n")

// Test 9: Find all corners
let allCorners = Grid.findAll(grid3, Corner)
assertEqual(Array.length(allCorners), 4, "Find all corners returns 4 positions")

// Test 10: Find in range
switch Bounds.make(~top=0, ~left=0, ~bottom=1, ~right=2) {
| Some(bounds) => {
    let cornersInRange = Grid.findInRange(grid3, Corner, bounds)
    assertEqual(
      Array.length(cornersInRange),
      2,
      "Find in range returns corners within bounds",
    )
  }
| None => Console.error("✗ FAIL: Bounds creation failed")
}

Console.log("\n=== Performance Tests ===\n")

// Test 11: Large grid performance
let largeLines = Array.make(1000, "+"->String.repeat(100))
let startTime = Date.now()
let largeGrid = Grid.fromLines(largeLines)
let endTime = Date.now()
let duration = endTime -. startTime

assertEqual(largeGrid.height, 1000, "Large grid has correct height")
assertEqual(largeGrid.width, 100, "Large grid has correct width")
assert(duration < 10.0, `Grid construction <10ms (actual: ${Float.toString(duration)}ms)`)

// Test 12: Index lookup performance
let findStartTime = Date.now()
let _corners = Grid.findAll(largeGrid, Corner)
let findEndTime = Date.now()
let findDuration = findEndTime -. findStartTime

assert(
  findDuration < 5.0,
  `Finding all corners using index <5ms (actual: ${Float.toString(findDuration)}ms)`,
)

Console.log("\n=== Utility Functions Tests ===\n")

// Test 13: toString
let gridString = Grid.toString(grid3)
let expectedString = lines3->Array.join("\n")
assertEqual(gridString, expectedString, "toString reconstructs original grid")

// Test 14: getStats
let stats = Grid.getStats(grid3)
assert(String.includes(stats, "Width: 4"), "getStats includes width")
assert(String.includes(stats, "Height: 3"), "getStats includes height")
assert(String.includes(stats, "Corners: 4"), "getStats includes corner count")

Console.log("\n=== Edge Cases Tests ===\n")

// Test 15: Single character grid
let singleCharLines = ["+"]
let singleCharGrid = Grid.fromLines(singleCharLines)
assertEqual(singleCharGrid.width, 1, "Single character grid width")
assertEqual(singleCharGrid.height, 1, "Single character grid height")

// Test 16: Empty lines
let emptyLines = ["", "", ""]
let emptyGrid = Grid.fromLines(emptyLines)
assertEqual(emptyGrid.width, 0, "Empty lines grid width is 0")
assertEqual(emptyGrid.height, 3, "Empty lines grid height is 3")

Console.log("\n=== All Tests Complete ===\n")
