// InputParser_test.res
// Unit tests for InputParser module
//
// Tests cover:
// - Valid input syntax recognition
// - Invalid syntax rejection
// - Identifier extraction
// - Edge cases (special characters, empty strings, etc.)

open RescriptCore.Test

// Helper to create a test position
let testPosition = Position.make(5, 10)

// Helper to create test bounds
let testBounds: Types.bounds = {
  top: 0,
  left: 0,
  bottom: 10,
  right: 20,
}

describe("InputParser - canParse", () => {
  test("recognizes valid input field '#email'", () => {
    let result = InputParser.canParse("#email")
    Assert.deepEqual(result, true)
  })

  test("recognizes valid input field '#password'", () => {
    let result = InputParser.canParse("#password")
    Assert.deepEqual(result, true)
  })

  test("recognizes valid input field with numbers '#password123'", () => {
    let result = InputParser.canParse("#password123")
    Assert.deepEqual(result, true)
  })

  test("recognizes valid input field with underscores '#user_name'", () => {
    let result = InputParser.canParse("#user_name")
    Assert.deepEqual(result, true)
  })

  test("recognizes valid input field with leading/trailing spaces '  #email  '", () => {
    let result = InputParser.canParse("  #email  ")
    Assert.deepEqual(result, true)
  })

  test("rejects input with hyphen '#first-name'", () => {
    let result = InputParser.canParse("#first-name")
    Assert.deepEqual(result, false)
  })

  test("rejects input with space after hash '# email'", () => {
    let result = InputParser.canParse("# email")
    Assert.deepEqual(result, false)
  })

  test("rejects input without hash 'email'", () => {
    let result = InputParser.canParse("email")
    Assert.deepEqual(result, false)
  })

  test("rejects empty string", () => {
    let result = InputParser.canParse("")
    Assert.deepEqual(result, false)
  })

  test("rejects hash only '#'", () => {
    let result = InputParser.canParse("#")
    Assert.deepEqual(result, false)
  })

  test("rejects input with special characters '#email@domain'", () => {
    let result = InputParser.canParse("#email@domain")
    Assert.deepEqual(result, false)
  })

  test("rejects input with dots '#email.address'", () => {
    let result = InputParser.canParse("#email.address")
    Assert.deepEqual(result, false)
  })

  test("rejects button syntax '[ Submit ]'", () => {
    let result = InputParser.canParse("[ Submit ]")
    Assert.deepEqual(result, false)
  })

  test("rejects link syntax '\"Click Here\"'", () => {
    let result = InputParser.canParse("\"Click Here\"")
    Assert.deepEqual(result, false)
  })
})

describe("InputParser - parse", () => {
  test("parses valid input '#email' and extracts identifier", () => {
    let result = InputParser.parse("#email", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id, placeholder, position})) => {
        Assert.deepEqual(id, "email")
        Assert.deepEqual(placeholder, None)
        Assert.deepEqual(position.row, 5)
        Assert.deepEqual(position.col, 10)
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("parses valid input '#password' and extracts identifier", () => {
    let result = InputParser.parse("#password", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "password")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("parses input with numbers '#password123'", () => {
    let result = InputParser.parse("#password123", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "password123")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("parses input with underscores '#user_name'", () => {
    let result = InputParser.parse("#user_name", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "user_name")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("handles leading/trailing whitespace '  #email  '", () => {
    let result = InputParser.parse("  #email  ", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "email")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("returns None for invalid input '#first-name' (contains hyphen)", () => {
    let result = InputParser.parse("#first-name", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for invalid input '# email' (space after hash)", () => {
    let result = InputParser.parse("# email", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for text without hash 'email'", () => {
    let result = InputParser.parse("email", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for empty string", () => {
    let result = InputParser.parse("", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for hash only '#'", () => {
    let result = InputParser.parse("#", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for input with special characters '#email@domain'", () => {
    let result = InputParser.parse("#email@domain", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("returns None for input with dots '#email.address'", () => {
    let result = InputParser.parse("#email.address", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("preserves position information correctly", () => {
    let customPosition = Position.make(15, 25)
    let result = InputParser.parse("#test", customPosition, testBounds)

    switch result {
    | Some(Types.Input({position})) => {
        Assert.deepEqual(position.row, 15)
        Assert.deepEqual(position.col, 25)
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("placeholder is always None", () => {
    let result = InputParser.parse("#email", testPosition, testBounds)

    switch result {
    | Some(Types.Input({placeholder})) => {
        Assert.deepEqual(placeholder, None)
      }
    | _ => Assert.fail("Expected Input element")
    }
  })
})

describe("InputParser - make", () => {
  test("creates parser with priority 90", () => {
    let parser = InputParser.make()
    Assert.deepEqual(parser.priority, 90)
  })

  test("created parser canParse matches standalone canParse", () => {
    let parser = InputParser.make()
    let testCases = ["#email", "#password", "invalid", "# test", "#test-123"]

    testCases->Array.forEach(testCase => {
      let expected = InputParser.canParse(testCase)
      let actual = parser.canParse(testCase)
      Assert.deepEqual(actual, expected)
    })
  })

  test("created parser parse matches standalone parse", () => {
    let parser = InputParser.make()

    let result1 = InputParser.parse("#email", testPosition, testBounds)
    let result2 = parser.parse("#email", testPosition, testBounds)

    switch (result1, result2) {
    | (Some(Types.Input({id: id1})), Some(Types.Input({id: id2}))) => {
        Assert.deepEqual(id1, id2)
      }
    | _ => Assert.fail("Both should return Input elements")
    }
  })
})

describe("InputParser - edge cases", () => {
  test("handles very long identifier", () => {
    let longId = "a"->String.repeat(100)
    let input = "#" ++ longId
    let result = InputParser.parse(input, testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, longId)
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("handles single character identifier '#x'", () => {
    let result = InputParser.parse("#x", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "x")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("handles identifier starting with digit '#1password'", () => {
    // Note: \w includes digits, so this should be valid
    let result = InputParser.parse("#1password", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "1password")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("rejects input with only underscores '#___'", () => {
    // This should actually be valid as underscores are word characters
    let result = InputParser.parse("#___", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        Assert.deepEqual(id, "___")
      }
    | _ => Assert.fail("Expected Input element")
    }
  })

  test("rejects multiple hashes '##email'", () => {
    let result = InputParser.parse("##email", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })

  test("rejects hash at end 'email#'", () => {
    let result = InputParser.parse("email#", testPosition, testBounds)
    Assert.deepEqual(result, None)
  })
})
