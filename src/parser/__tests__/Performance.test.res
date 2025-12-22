// Performance.test.res
// Performance benchmarks for WyreframeParser
// Requirements: REQ-22 (Parsing Speed), REQ-23 (Memory Efficiency)

open Vitest

let pass = ()

// Helper to measure execution time
let measureTime = (fn: unit => 'a): (float, 'a) => {
  let start = Date.now()
  let result = fn()
  let end = Date.now()
  let duration = end -. start
  (duration, result)
}

// Helper to get memory usage in MB
let getMemoryUsageMB = (): float => {
  // Node.js specific - process.memoryUsage().heapUsed
  %raw(`typeof process !== 'undefined' && process.memoryUsage ? process.memoryUsage().heapUsed / 1024 / 1024 : 0`)
}

// Helper to force garbage collection if available
let forceGC = (): unit => {
  %raw(`typeof global !== 'undefined' && global.gc ? global.gc() : undefined`)
}

describe("Performance Benchmarks", t => {
  // PERF-01: Small wireframe parsing (100 lines) - ≤50ms
  test("parses 100-line wireframe in ≤50ms", t => {
    let wireframe = PerformanceFixtures.generateWireframe(100)

    let (duration, result) = measureTime(() => {
      Parser.parse(wireframe)
    })

    // Verify parse succeeded
    switch result {
    | Ok(ast) => {
        t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
      }
    | Error(errors) => {
        // Log errors for debugging
        Console.error("Parse errors:")
        Console.error(errors)
        t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
      }
    }

    // Verify performance requirement
    Console.log(`100-line wireframe parsed in ${Float.toString(duration)}ms`)
    t->expect(duration)->Expect.Float.toBeLessThanOrEqual(50.0)
  })

  // PERF-02: Medium wireframe parsing (500 lines) - ≤200ms
  test("parses 500-line wireframe in ≤200ms", t => {
    let wireframe = PerformanceFixtures.generateWireframe(500)

    let (duration, result) = measureTime(() => {
      Parser.parse(wireframe)
    })

    // Verify parse succeeded
    switch result {
    | Ok(ast) => {
        t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
      }
    | Error(errors) => {
        Console.error("Parse errors:")
        Console.error(errors)
        t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
      }
    }

    // Verify performance requirement
    Console.log(`500-line wireframe parsed in ${Float.toString(duration)}ms`)
    t->expect(duration)->Expect.Float.toBeLessThanOrEqual(200.0)
  })

  // PERF-03: Large wireframe parsing (2000 lines) - ≤1000ms
  test("parses 2000-line wireframe in ≤1000ms", t => {
    let wireframe = PerformanceFixtures.generateWireframe(2000)

    let (duration, result) = measureTime(() => {
      Parser.parse(wireframe)
    })

    // Verify parse succeeded
    switch result {
    | Ok(ast) => {
        t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
      }
    | Error(errors) => {
        Console.error("Parse errors:")
        Console.error(errors)
        t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
      }
    }

    // Verify performance requirement
    Console.log(`2000-line wireframe parsed in ${Float.toString(duration)}ms`)
    t->expect(duration)->Expect.Float.toBeLessThanOrEqual(1000.0)
  })

  // PERF-04: Memory usage test - <50MB for 2000 lines
  test("memory usage <50MB for 2000-line wireframe", t => {
    let wireframe = PerformanceFixtures.generateWireframe(2000)

    // Force garbage collection to get clean baseline
    forceGC()

    // Record initial memory
    let initialMemory = getMemoryUsageMB()

    // Parse wireframe
    let result = Parser.parse(wireframe)

    // Record final memory
    let finalMemory = getMemoryUsageMB()

    // Calculate delta
    let memoryDelta = finalMemory -. initialMemory

    // Verify parse succeeded
    switch result {
    | Ok(ast) => {
        t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
      }
    | Error(errors) => {
        Console.error("Parse errors:")
        Console.error(errors)
        t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
      }
    }

    // Log memory usage
    Console.log(`Initial memory: ${Float.toString(initialMemory)}MB`)
    Console.log(`Final memory: ${Float.toString(finalMemory)}MB`)
    Console.log(`Memory delta: ${Float.toString(memoryDelta)}MB`)

    // Verify memory requirement
    // Note: This test may be skipped if gc is not exposed
    if memoryDelta > 0.0 {
      t->expect(memoryDelta)->Expect.Float.toBeLessThan(50.0)
    } else {
      Console.warn("Memory test skipped: gc not exposed or memory delta is zero")
      pass
    }
  })

  // PERF-05: Fixture generation validation
  describe("Fixture Generation Validation", t => {
    let testSizes = [50, 100, 200, 500, 1000, 2000]

    testSizes->Array.forEach(targetSize => {
      test(`generates valid ${Int.toString(targetSize)}-line wireframe`, t => {
        let wireframe = PerformanceFixtures.generateWireframe(targetSize)

        // Check line count is approximately correct (±30% tolerance for all sizes)
        let actualLines = PerformanceFixtures.getLineCount(wireframe)
        let tolerance = 0.30 // 30% tolerance - fixture generation is approximate
        let minLines = Float.toInt(Float.fromInt(targetSize) *. (1.0 -. tolerance))
        let maxLines = Float.toInt(Float.fromInt(targetSize) *. (1.0 +. tolerance))

        Console.log(
          `Target: ${Int.toString(targetSize)} lines, Actual: ${Int.toString(actualLines)} lines`,
        )

        t->expect(actualLines)->Expect.Int.toBeGreaterThanOrEqual(minLines)
        t->expect(actualLines)->Expect.Int.toBeLessThanOrEqual(maxLines)

        // Verify basic syntactic correctness
        t->expect(PerformanceFixtures.validateWireframe(wireframe))->Expect.toBe(true)

        // Verify it parses without errors
        let result = Parser.parse(wireframe)
        switch result {
        | Ok(ast) => {
            t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
          }
        | Error(errors) => {
            Console.error(`Parse errors for ${Int.toString(targetSize)}-line wireframe:`)
            Console.error(errors)
            t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
          }
        }
      })
    })
  })

  // PERF-06: Multiple parse iterations consistency
  test("parsing is consistent across multiple iterations", t => {
    let wireframe = PerformanceFixtures.generateWireframe(500)
    let iterations = 10
    let durations = []

    // Warm-up iteration (JIT compilation)
    let _ = Parser.parse(wireframe)

    // Measured iterations
    for _ in 0 to iterations - 1 {
      let (duration, result) = measureTime(() => {
        Parser.parse(wireframe)
      })

      durations->Array.push(duration)->ignore

      // Verify each parse succeeds
      switch result {
      | Ok(ast) => {
          t->expect(Array.length(ast.scenes))->Expect.Int.toBeGreaterThan(0)
        }
      | Error(_) => {
          t->expect(true)->Expect.toBe(false) // fail: Expected successful parse on all iterations
        }
      }
    }

    // Calculate statistics
    let sum = durations->Array.reduce(0.0, (acc, d) => acc +. d)
    let average = sum /. Float.fromInt(iterations)

    // Calculate standard deviation
    let variance =
      durations->Array.reduce(0.0, (acc, d) => {
        let diff = d -. average
        acc +. diff *. diff
      }) /. Float.fromInt(iterations)
    let stdDev = Math.sqrt(variance)

    let min = durations->Array.reduce(Float.Constants.positiveInfinity, (acc, d) => Math.min(acc, d))
    let max = durations->Array.reduce(Float.Constants.negativeInfinity, (acc, d) => Math.max(acc, d))

    // Log statistics
    Console.log(`\nPerformance Statistics (${Int.toString(iterations)} iterations):`)
    Console.log(`  Average: ${Float.toString(average)}ms`)
    Console.log(`  Std Dev: ${Float.toString(stdDev)}ms`)
    Console.log(`  Min: ${Float.toString(min)}ms`)
    Console.log(`  Max: ${Float.toString(max)}ms`)
    Console.log(`  Coefficient of Variation: ${Float.toString(stdDev /. average *. 100.0)}%`)

    // Verify all iterations meet performance target
    t->expect(max)->Expect.Float.toBeLessThanOrEqual(200.0)

    // Verify consistency (standard deviation < 50% of average)
    // Note: Skip CV check for very fast operations (< 10ms average)
    // because sub-millisecond timing has inherently high variance
    if average >= 10.0 {
      let coefficientOfVariation = stdDev /. average
      t->expect(coefficientOfVariation)->Expect.Float.toBeLessThan(0.5)
    } else {
      // For fast operations, just verify max is reasonable
      Console.log("  CV check skipped: average too small for meaningful variance measurement")
      pass
    }
  })

  // Additional test: Verify linear scaling
  test("performance scales linearly with wireframe size", t => {
    let sizes = [100, 200, 400, 800]
    let measurements = []

    sizes->Array.forEach(size => {
      let wireframe = PerformanceFixtures.generateWireframe(size)

      let (duration, result) = measureTime(() => {
        Parser.parse(wireframe)
      })

      // Verify parse succeeded
      switch result {
      | Ok(_) => {
          measurements->Array.push((size, duration))->ignore
        }
      | Error(_) => {
          t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
        }
      }
    })

    // Log measurements
    Console.log("\nLinear Scaling Analysis:")
    measurements->Array.forEach(((size, duration)) => {
      Console.log(`  ${Int.toString(size)} lines: ${Float.toString(duration)}ms`)
    })

    // Verify approximate linear relationship
    // For each doubling of size, duration should roughly double (±50% tolerance)
    for i in 0 to Array.length(measurements) - 2 {
      let (size1, duration1) = measurements->Array.getUnsafe(i)
      let (size2, duration2) = measurements->Array.getUnsafe(i + 1)

      let sizeRatio = Float.fromInt(size2) /. Float.fromInt(size1)

      // Skip ratio comparison if durations are too small (< 10ms)
      // Small durations have too much variance for meaningful ratio comparison
      if duration1 >= 10.0 && duration2 >= 10.0 {
        let durationRatio = duration2 /. duration1

        Console.log(
          `  Size ratio: ${Float.toString(sizeRatio)}x, Duration ratio: ${Float.toString(
              durationRatio,
            )}x`,
        )

        // Duration ratio should be within 0.5x to 2.5x of size ratio
        // (allowing for variance due to fixed overhead and JIT optimization)
        t->expect(durationRatio)->Expect.Float.toBeLessThan(sizeRatio *. 2.5)
      } else {
        Console.log(
          `  Size ratio: ${Float.toString(sizeRatio)}x, Duration ratio: N/A (durations too small)`,
        )
        // If durations are small, parsing is extremely fast which is good
        pass
      }
    }
  })
})

// Nested boxes performance test
describe("Nested Boxes Performance", t => {
  test("handles deep nesting efficiently", t => {
    // Test nesting depths 1-4
    let depths = [1, 2, 3, 4]

    depths->Array.forEach(depth => {
      let wireframe = PerformanceFixtures.generateNestedBoxes(depth)

      let (duration, result) = measureTime(() => {
        Parser.parse(wireframe)
      })

      Console.log(`Nesting depth ${Int.toString(depth)}: ${Float.toString(duration)}ms`)

      // Verify parse succeeded
      switch result {
      | Ok(_) => pass
      | Error(errors) => {
          Console.error(`Parse errors at depth ${Int.toString(depth)}:`)
          Console.error(errors)
          t->expect(true)->Expect.toBe(false) // fail: Expected successful parse
        }
      }

      // Even deep nesting should be fast (<100ms for simple structures)
      t->expect(duration)->Expect.Float.toBeLessThan(100.0)
    })
  })
})

// Simple box generation test
describe("Simple Box Generation", t => {
  test("generates and parses simple boxes", t => {
    let box1 = PerformanceFixtures.generateSimpleBox()
    let box2 = PerformanceFixtures.generateSimpleBox(~width=30, ~height=5, ~name=Some("TestBox"))

    // Verify both boxes are valid
    t->expect(PerformanceFixtures.validateWireframe(box1))->Expect.toBe(true)
    t->expect(PerformanceFixtures.validateWireframe(box2))->Expect.toBe(true)

    // Parse both
    let result1 = Parser.parse(box1)
    let result2 = Parser.parse(box2)

    switch (result1, result2) {
    | (Ok(_), Ok(_)) => pass
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected successful parse for simple boxes
    }
  })
})
