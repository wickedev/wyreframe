// InputParser_test.res
// Unit tests for InputParser module
//
// Tests cover:
// - Valid input syntax recognition
// - Invalid syntax rejection
// - Identifier extraction
// - Edge cases (special characters, empty strings, etc.)

open Vitest

// Helper to create a test position
let testPosition = Types.Position.make(5, 10)

// Helper to create test bounds
let testBounds: Types.Bounds.t = {
  top: 0,
  left: 0,
  bottom: 10,
  right: 20,
}

describe("InputParser - canParse", () => {
  test("recognizes valid input field '#email'", t => {
    let result = InputParser.canParse("#email")
    t->expect(result)->Expect.toBe(true)
  })

  test("recognizes valid input field '#password'", t => {
    let result = InputParser.canParse("#password")
    t->expect(result)->Expect.toBe(true)
  })

  test("recognizes valid input field with numbers '#password123'", t => {
    let result = InputParser.canParse("#password123")
    t->expect(result)->Expect.toBe(true)
  })

  test("recognizes valid input field with underscores '#user_name'", t => {
    let result = InputParser.canParse("#user_name")
    t->expect(result)->Expect.toBe(true)
  })

  test("recognizes valid input field with leading/trailing spaces '  #email  '", t => {
    let result = InputParser.canParse("  #email  ")
    t->expect(result)->Expect.toBe(true)
  })

  test("rejects input with hyphen '#first-name'", t => {
    let result = InputParser.canParse("#first-name")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects input with space after hash '# email'", t => {
    let result = InputParser.canParse("# email")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects input without hash 'email'", t => {
    let result = InputParser.canParse("email")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects empty string", t => {
    let result = InputParser.canParse("")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects hash only '#'", t => {
    let result = InputParser.canParse("#")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects input with special characters '#email@domain'", t => {
    let result = InputParser.canParse("#email@domain")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects input with dots '#email.address'", t => {
    let result = InputParser.canParse("#email.address")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects button syntax '[ Submit ]'", t => {
    let result = InputParser.canParse("[ Submit ]")
    t->expect(result)->Expect.toBe(false)
  })

  test("rejects link syntax '\"Click Here\"'", t => {
    let result = InputParser.canParse("\"Click Here\"")
    t->expect(result)->Expect.toBe(false)
  })
})

describe("InputParser - parse", () => {
  test("parses valid input '#email' and extracts identifier", t => {
    let result = InputParser.parse("#email", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id, placeholder, position})) => {
        t->expect(id)->Expect.toBe("email")
        t->expect(placeholder)->Expect.toBe(None)
        t->expect(position.row)->Expect.toBe(5)
        t->expect(position.col)->Expect.toBe(10)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("parses valid input '#password' and extracts identifier", t => {
    let result = InputParser.parse("#password", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("password")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("parses input with numbers '#password123'", t => {
    let result = InputParser.parse("#password123", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("password123")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("parses input with underscores '#user_name'", t => {
    let result = InputParser.parse("#user_name", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("user_name")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("handles leading/trailing whitespace '  #email  '", t => {
    let result = InputParser.parse("  #email  ", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("email")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("returns None for invalid input '#first-name' (contains hyphen)", t => {
    let result = InputParser.parse("#first-name", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for invalid input '# email' (space after hash)", t => {
    let result = InputParser.parse("# email", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for text without hash 'email'", t => {
    let result = InputParser.parse("email", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for empty string", t => {
    let result = InputParser.parse("", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for hash only '#'", t => {
    let result = InputParser.parse("#", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for input with special characters '#email@domain'", t => {
    let result = InputParser.parse("#email@domain", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("returns None for input with dots '#email.address'", t => {
    let result = InputParser.parse("#email.address", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("preserves position information correctly", t => {
    let customPosition = Types.Position.make(15, 25)
    let result = InputParser.parse("#test", customPosition, testBounds)

    switch result {
    | Some(Types.Input({position})) => {
        t->expect(position.row)->Expect.toBe(15)
        t->expect(position.col)->Expect.toBe(25)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("placeholder is always None", t => {
    let result = InputParser.parse("#email", testPosition, testBounds)

    switch result {
    | Some(Types.Input({placeholder})) => {
        t->expect(placeholder)->Expect.toBe(None)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })
})

describe("InputParser - make", () => {
  test("creates parser with priority 90", t => {
    let parser = InputParser.make()
    t->expect(parser.priority)->Expect.toBe(90)
  })

  test("created parser canParse matches standalone canParse", t => {
    let parser = InputParser.make()
    let testCases = ["#email", "#password", "invalid", "# test", "#test-123"]

    testCases->Array.forEach(testCase => {
      let expected = InputParser.canParse(testCase)
      let actual = parser.canParse(testCase)
      t->expect(actual)->Expect.toBe(expected)
    })
  })

  test("created parser parse matches standalone parse", t => {
    let parser = InputParser.make()

    let result1 = InputParser.parse("#email", testPosition, testBounds)
    let result2 = parser.parse("#email", testPosition, testBounds)

    switch (result1, result2) {
    | (Some(Types.Input({id: id1})), Some(Types.Input({id: id2}))) => {
        t->expect(id1)->Expect.toBe(id2)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Both should return Input elements
    }
  })
})

describe("InputParser - edge cases", () => {
  test("handles very long identifier", t => {
    let longId = "a"->String.repeat(100)
    let input = "#" ++ longId
    let result = InputParser.parse(input, testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe(longId)
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("handles single character identifier '#x'", t => {
    let result = InputParser.parse("#x", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("x")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("handles identifier starting with digit '#1password'", t => {
    // Note: \w includes digits, so this should be valid
    let result = InputParser.parse("#1password", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("1password")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("rejects input with only underscores '#___'", t => {
    // This should actually be valid as underscores are word characters
    let result = InputParser.parse("#___", testPosition, testBounds)

    switch result {
    | Some(Types.Input({id})) => {
        t->expect(id)->Expect.toBe("___")
      }
    | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
    }
  })

  test("rejects multiple hashes '##email'", t => {
    let result = InputParser.parse("##email", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })

  test("rejects hash at end 'email#'", t => {
    let result = InputParser.parse("email#", testPosition, testBounds)
    t->expect(result)->Expect.toBe(None)
  })
})
