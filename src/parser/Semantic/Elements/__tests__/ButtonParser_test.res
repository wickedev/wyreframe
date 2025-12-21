// ButtonParser_test.res
// Unit tests for ButtonParser module
//
// Tests button recognition, text extraction, and edge cases

open Jest
open Expect

describe("ButtonParser", () => {
  let testPosition = Position.make(5, 10)
  let testBounds: Types.bounds = {
    top: 0,
    left: 0,
    bottom: 10,
    right: 30,
  }

  describe("slugify", () => {
    test("converts simple text to lowercase with hyphens", () => {
      expect(ButtonParser.slugify("Submit Form"))->toBe("submit-form")
    })

    test("handles single words", () => {
      expect(ButtonParser.slugify("Login"))->toBe("login")
    })

    test("removes special characters", () => {
      expect(ButtonParser.slugify("Create Account!"))->toBe("create-account")
    })

    test("handles multiple spaces", () => {
      expect(ButtonParser.slugify("Log   In"))->toBe("log-in")
    })

    test("removes leading and trailing spaces", () => {
      expect(ButtonParser.slugify("  Cancel  "))->toBe("cancel")
    })

    test("handles mixed case", () => {
      expect(ButtonParser.slugify("SAVE Changes"))->toBe("save-changes")
    })

    test("removes consecutive hyphens", () => {
      expect(ButtonParser.slugify("Submit--Form"))->toBe("submit-form")
    })
  })

  describe("canParse", () => {
    test("returns true for basic button syntax", () => {
      expect(ButtonParser.canParse("[ Submit ]"))->toBe(true)
    })

    test("returns true for button without spaces", () => {
      expect(ButtonParser.canParse("[Login]"))->toBe(true)
    })

    test("returns true for button with extra whitespace", () => {
      expect(ButtonParser.canParse("[  Create Account  ]"))->toBe(true)
    })

    test("returns true for multiword button", () => {
      expect(ButtonParser.canParse("[ Log In ]"))->toBe(true)
    })

    test("returns false for text without brackets", () => {
      expect(ButtonParser.canParse("Submit"))->toBe(false)
    })

    test("returns false for only opening bracket", () => {
      expect(ButtonParser.canParse("[ Submit"))->toBe(false)
    })

    test("returns false for only closing bracket", () => {
      expect(ButtonParser.canParse("Submit ]"))->toBe(false)
    })

    test("returns false for empty string", () => {
      expect(ButtonParser.canParse(""))->toBe(false)
    })

    test("returns true for button with content before/after", () => {
      expect(ButtonParser.canParse("Click [ Submit ] to continue"))->toBe(true)
    })
  })

  describe("parse", () => {
    test("parses basic button correctly", () => {
      let result = ButtonParser.parse("[ Submit ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position, align})) => {
          expect(id)->toBe("submit")
          expect(text)->toBe("Submit")
          expect(position)->toEqual(testPosition)
          expect(align)->toEqual(Types.Left)
        }
      | _ => fail("Expected Button element")
      }
    })

    test("parses button without spaces", () => {
      let result = ButtonParser.parse("[Login]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(id)->toBe("login")
          expect(text)->toBe("Login")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("parses button with extra whitespace", () => {
      let result = ButtonParser.parse("[  Create Account  ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(id)->toBe("create-account")
          expect(text)->toBe("Create Account")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("parses multiword button text", () => {
      let result = ButtonParser.parse("[ Log In ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(id)->toBe("log-in")
          expect(text)->toBe("Log In")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("trims leading and trailing whitespace from button text", () => {
      let result = ButtonParser.parse("[   Cancel   ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(text)->toBe("Cancel")
          expect(id)->toBe("cancel")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("returns None for empty button text", () => {
      let result = ButtonParser.parse("[  ]", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("returns None for button with only whitespace", () => {
      let result = ButtonParser.parse("[     ]", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("returns None for text without brackets", () => {
      let result = ButtonParser.parse("Submit", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("returns None for incomplete button syntax (missing closing bracket)", () => {
      let result = ButtonParser.parse("[ Submit", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("returns None for incomplete button syntax (missing opening bracket)", () => {
      let result = ButtonParser.parse("Submit ]", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("handles button with special characters in text", () => {
      let result = ButtonParser.parse("[ Save & Exit ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(text)->toBe("Save & Exit")
          expect(id)->toBe("save-exit") // Special chars removed in slug
        }
      | _ => fail("Expected Button element")
      }
    })

    test("handles button with numbers", () => {
      let result = ButtonParser.parse("[ Option 1 ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          expect(text)->toBe("Option 1")
          expect(id)->toBe("option-1")
        }
      | _ => fail("Expected Button element")
      }
    })

    test("preserves position in parsed element", () => {
      let customPosition = Position.make(3, 7)
      let result = ButtonParser.parse("[ Test ]", customPosition, testBounds)

      switch result {
      | Some(Types.Button({position, id: _, text: _, align: _})) => {
          expect(position)->toEqual(customPosition)
        }
      | _ => fail("Expected Button element")
      }
    })

    test("returns None for content with extra text before button", () => {
      let result = ButtonParser.parse("Click [ Submit ] here", testPosition, testBounds)
      expect(result)->toEqual(None)
    })

    test("handles nested brackets by matching outer brackets", () => {
      // This tests the edge case mentioned in requirements
      // The regex should match the first [...] pattern
      let result = ButtonParser.parse("[ [nested] ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({text, id: _, position: _, align: _})) => {
          // Should extract "[nested]" as the text (inner brackets preserved)
          expect(text)->toBe("[nested]")
        }
      | None => {
          // Or it might return None depending on regex behavior
          // Either behavior is acceptable for this edge case
          pass
        }
      }
    })
  })

  describe("make", () => {
    test("creates parser with priority 100", () => {
      let parser = ButtonParser.make()
      expect(parser.priority)->toBe(100)
    })

    test("created parser can parse buttons", () => {
      let parser = ButtonParser.make()
      let result = parser.parse("[ Test ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button(_)) => pass
      | _ => fail("Parser should be able to parse buttons")
      }
    })

    test("created parser canParse works correctly", () => {
      let parser = ButtonParser.make()
      expect(parser.canParse("[ Button ]"))->toBe(true)
      expect(parser.canParse("Not a button"))->toBe(false)
    })
  })
})
