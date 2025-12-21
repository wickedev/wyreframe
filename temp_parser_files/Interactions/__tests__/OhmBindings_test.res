// Tests for OhmBindings module
// Validates that ohm-js integration works correctly

open OhmBindings

// Test 1: Load a simple grammar
let testLoadSimpleGrammar = () => {
  let grammarString = `
    SimpleGrammar {
      Start = letter+
    }
  `

  switch loadGrammar(grammarString) {
  | Ok(_) => Js.Console.log("✓ Test 1 passed: Successfully loaded simple grammar")
  | Error(msg) => Js.Console.error(`✗ Test 1 failed: ${msg}`)
  }
}

// Test 2: Load the interaction DSL grammar (placeholder)
let testLoadInteractionGrammar = () => {
  // Read the interaction.ohm file
  let grammarString = `
    InteractionDSL {
      Document = any*
    }
  `

  switch loadGrammar(grammarString) {
  | Ok(_) => Js.Console.log("✓ Test 2 passed: Successfully loaded interaction DSL grammar")
  | Error(msg) => Js.Console.error(`✗ Test 2 failed: ${msg}`)
  }
}

// Test 3: Parse a string with a grammar
let testParseWithGrammar = () => {
  let grammarString = `
    DigitGrammar {
      Start = digit+
    }
  `

  switch loadGrammar(grammarString) {
  | Ok(grammar) => {
      switch parseString(grammar, "12345") {
      | Ok(_) => Js.Console.log("✓ Test 3 passed: Successfully parsed valid input")
      | Error(msg) => Js.Console.error(`✗ Test 3 failed: ${msg}`)
      }
    }
  | Error(msg) => Js.Console.error(`✗ Test 3 failed to load grammar: ${msg}`)
  }
}

// Test 4: Reject invalid input
let testRejectInvalidInput = () => {
  let grammarString = `
    DigitGrammar {
      Start = digit+
    }
  `

  switch loadGrammar(grammarString) {
  | Ok(grammar) => {
      switch parseString(grammar, "abc") {
      | Ok(_) => Js.Console.error("✗ Test 4 failed: Should have rejected invalid input")
      | Error(_) => Js.Console.log("✓ Test 4 passed: Correctly rejected invalid input")
      }
    }
  | Error(msg) => Js.Console.error(`✗ Test 4 failed to load grammar: ${msg}`)
  }
}

// Test 5: Handle malformed grammar
let testMalformedGrammar = () => {
  let malformedGrammar = `
    MalformedGrammar {
      Start = this is not valid
    }
  `

  switch loadGrammar(malformedGrammar) {
  | Ok(_) => Js.Console.error("✗ Test 5 failed: Should have rejected malformed grammar")
  | Error(_) => Js.Console.log("✓ Test 5 passed: Correctly rejected malformed grammar")
  }
}

// Run all tests
let runTests = () => {
  Js.Console.log("\n=== Running OhmBindings Tests ===\n")

  testLoadSimpleGrammar()
  testLoadInteractionGrammar()
  testParseWithGrammar()
  testRejectInvalidInput()
  testMalformedGrammar()

  Js.Console.log("\n=== OhmBindings Tests Complete ===\n")
}

// Export for test runner
let tests = runTests
