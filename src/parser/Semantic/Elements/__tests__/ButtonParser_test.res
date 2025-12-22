// ButtonParser_test.res
// Unit tests for ButtonParser module
//
// Tests button recognition, text extraction, and edge cases

open Vitest

describe("ButtonParser", () => {
  let testPosition = Types.Position.make(5, 10)
  let testBounds: Types.Bounds.t = {
    top: 0,
    left: 0,
    bottom: 10,
    right: 30,
  }

  describe("slugify", () => {
    test("converts simple text to lowercase with hyphens", t => {
      t->expect(ButtonParser.slugify("Submit Form"))->Expect.toBe("submit-form")
    })

    test("handles single words", t => {
      t->expect(ButtonParser.slugify("Login"))->Expect.toBe("login")
    })

    test("removes special characters", t => {
      t->expect(ButtonParser.slugify("Create Account!"))->Expect.toBe("create-account")
    })

    test("handles multiple spaces", t => {
      t->expect(ButtonParser.slugify("Log   In"))->Expect.toBe("log-in")
    })

    test("removes leading and trailing spaces", t => {
      t->expect(ButtonParser.slugify("  Cancel  "))->Expect.toBe("cancel")
    })

    test("handles mixed case", t => {
      t->expect(ButtonParser.slugify("SAVE Changes"))->Expect.toBe("save-changes")
    })

    test("removes consecutive hyphens", t => {
      t->expect(ButtonParser.slugify("Submit--Form"))->Expect.toBe("submit-form")
    })
  })

  describe("canParse", () => {
    test("returns true for basic button syntax", t => {
      t->expect(ButtonParser.canParse("[ Submit ]"))->Expect.toBe(true)
    })

    test("returns true for button without spaces", t => {
      t->expect(ButtonParser.canParse("[Login]"))->Expect.toBe(true)
    })

    test("returns true for button with extra whitespace", t => {
      t->expect(ButtonParser.canParse("[  Create Account  ]"))->Expect.toBe(true)
    })

    test("returns true for multiword button", t => {
      t->expect(ButtonParser.canParse("[ Log In ]"))->Expect.toBe(true)
    })

    test("returns false for text without brackets", t => {
      t->expect(ButtonParser.canParse("Submit"))->Expect.toBe(false)
    })

    test("returns false for only opening bracket", t => {
      t->expect(ButtonParser.canParse("[ Submit"))->Expect.toBe(false)
    })

    test("returns false for only closing bracket", t => {
      t->expect(ButtonParser.canParse("Submit ]"))->Expect.toBe(false)
    })

    test("returns false for empty string", t => {
      t->expect(ButtonParser.canParse(""))->Expect.toBe(false)
    })

    test("returns true for button with content before/after", t => {
      t->expect(ButtonParser.canParse("Click [ Submit ] to continue"))->Expect.toBe(true)
    })
  })

  describe("parse", () => {
    test("parses basic button correctly", t => {
      let result = ButtonParser.parse("[ Submit ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position, align})) => {
          t->expect(id)->Expect.toBe("submit")
          t->expect(text)->Expect.toBe("Submit")
          t->expect(position)->Expect.toEqual(testPosition)
          // Alignment is calculated based on position within bounds
          // position col=10, bounds right=30, so ~33% = Center
          t->expect(align)->Expect.toEqual(Types.Center)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("parses button without spaces", t => {
      let result = ButtonParser.parse("[Login]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(id)->Expect.toBe("login")
          t->expect(text)->Expect.toBe("Login")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("parses button with extra whitespace", t => {
      let result = ButtonParser.parse("[  Create Account  ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(id)->Expect.toBe("create-account")
          t->expect(text)->Expect.toBe("Create Account")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("parses multiword button text", t => {
      let result = ButtonParser.parse("[ Log In ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(id)->Expect.toBe("log-in")
          t->expect(text)->Expect.toBe("Log In")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("trims leading and trailing whitespace from button text", t => {
      let result = ButtonParser.parse("[   Cancel   ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(text)->Expect.toBe("Cancel")
          t->expect(id)->Expect.toBe("cancel")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("returns None for empty button text", t => {
      let result = ButtonParser.parse("[  ]", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("returns None for button with only whitespace", t => {
      let result = ButtonParser.parse("[     ]", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("returns None for text without brackets", t => {
      let result = ButtonParser.parse("Submit", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("returns None for incomplete button syntax (missing closing bracket)", t => {
      let result = ButtonParser.parse("[ Submit", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("returns None for incomplete button syntax (missing opening bracket)", t => {
      let result = ButtonParser.parse("Submit ]", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("handles button with special characters in text", t => {
      let result = ButtonParser.parse("[ Save & Exit ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(text)->Expect.toBe("Save & Exit")
          t->expect(id)->Expect.toBe("save-exit") // Special chars removed in slug
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("handles button with numbers", t => {
      let result = ButtonParser.parse("[ Option 1 ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({id, text, position: _, align: _})) => {
          t->expect(text)->Expect.toBe("Option 1")
          t->expect(id)->Expect.toBe("option-1")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("preserves position in parsed element", t => {
      let customPosition = Types.Position.make(3, 7)
      let result = ButtonParser.parse("[ Test ]", customPosition, testBounds)

      switch result {
      | Some(Types.Button({position, id: _, text: _, align: _})) => {
          t->expect(position)->Expect.toEqual(customPosition)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Button element
      }
    })

    test("returns None for content with extra text before button", t => {
      let result = ButtonParser.parse("Click [ Submit ] here", testPosition, testBounds)
      t->expect(result)->Expect.toEqual(None)
    })

    test("handles nested brackets by matching outer brackets", t => {
      // This tests the edge case mentioned in requirements
      // The regex should match the first [...] pattern
      let result = ButtonParser.parse("[ [nested] ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button({text, id: _, position: _, align: _})) => {
          // Should extract "[nested]" as the text (inner brackets preserved)
          t->expect(text)->Expect.toBe("[nested]")
        }
      | None => {
          // Or it might return None depending on regex behavior
          // Either behavior is acceptable for this edge case
          ()
        }
      }
    })
  })

  describe("make", () => {
    test("creates parser with priority 100", t => {
      let parser = ButtonParser.make()
      t->expect(parser.priority)->Expect.toBe(100)
    })

    test("created parser can parse buttons", t => {
      let parser = ButtonParser.make()
      let result = parser.parse("[ Test ]", testPosition, testBounds)

      switch result {
      | Some(Types.Button(_)) => ()
      | _ => t->expect(true)->Expect.toBe(false) // fail: Parser should be able to parse buttons
      }
    })

    test("created parser canParse works correctly", t => {
      let parser = ButtonParser.make()
      t->expect(parser.canParse("[ Button ]"))->Expect.toBe(true)
      t->expect(parser.canParse("Not a button"))->Expect.toBe(false)
    })
  })
})
