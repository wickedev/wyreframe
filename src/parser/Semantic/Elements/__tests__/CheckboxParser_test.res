// CheckboxParser_test.res
// Unit tests for checkbox element parser

open Jest
open Expect

describe("CheckboxParser", () => {
  let parser = CheckboxParser.make()

  describe("canParse", () => {
    test("recognizes checked checkbox [x]", () => {
      expect(parser.canParse("[x]"))->toBe(true)
    })

    test("recognizes checked checkbox with uppercase X", () => {
      expect(parser.canParse("[X]"))->toBe(true)
    })

    test("recognizes unchecked checkbox [ ]", () => {
      expect(parser.canParse("[ ]"))->toBe(true)
    })

    test("recognizes unchecked checkbox with multiple spaces", () => {
      expect(parser.canParse("[   ]"))->toBe(true)
    })

    test("recognizes checkbox with label", () => {
      expect(parser.canParse("[x] Accept terms"))->toBe(true)
    })

    test("recognizes checkbox with label at end", () => {
      expect(parser.canParse("Accept terms [x]"))->toBe(true)
    })

    test("rejects plain text", () => {
      expect(parser.canParse("plain text"))->toBe(false)
    })

    test("rejects button syntax", () => {
      expect(parser.canParse("[ Button ]"))->toBe(false)
    })

    test("rejects input syntax", () => {
      expect(parser.canParse("#email"))->toBe(false)
    })

    test("rejects incomplete brackets", () => {
      expect(parser.canParse("[x"))->toBe(false)
      expect(parser.canParse("x]"))->toBe(false)
    })
  })

  describe("parse - checked state", () => {
    let position = Position.make(5, 10)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

    test("extracts checked state from [x]", () => {
      switch parser.parse("[x]", position, bounds) {
      | Some(Checkbox({checked, label, position: pos})) => {
          expect(checked)->toBe(true)
          expect(label)->toBe("")
          expect(pos.row)->toBe(5)
          expect(pos.col)->toBe(10)
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles uppercase X in [X]", () => {
      switch parser.parse("[X]", position, bounds) {
      | Some(Checkbox({checked})) => {
          expect(checked)->toBe(true)
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("extracts label after checked checkbox", () => {
      switch parser.parse("[x] Accept terms and conditions", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          expect(checked)->toBe(true)
          expect(label)->toBe("Accept terms and conditions")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("trims whitespace from label", () => {
      switch parser.parse("[x]   Subscribe to newsletter   ", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Subscribe to newsletter")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles label with special characters", () => {
      switch parser.parse("[x] I agree to the Terms & Conditions", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("I agree to the Terms & Conditions")
        }
      | _ => fail("Expected Checkbox element")
      }
    })
  })

  describe("parse - unchecked state", () => {
    let position = Position.make(3, 5)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

    test("extracts unchecked state from [ ]", () => {
      switch parser.parse("[ ]", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          expect(checked)->toBe(false)
          expect(label)->toBe("")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles multiple spaces in brackets", () => {
      switch parser.parse("[   ]", position, bounds) {
      | Some(Checkbox({checked})) => {
          expect(checked)->toBe(false)
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("extracts label after unchecked checkbox", () => {
      switch parser.parse("[ ] Remember me", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          expect(checked)->toBe(false)
          expect(label)->toBe("Remember me")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles long labels", () => {
      switch parser.parse("[ ] I would like to receive promotional emails and updates", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("I would like to receive promotional emails and updates")
        }
      | _ => fail("Expected Checkbox element")
      }
    })
  })

  describe("parse - edge cases", () => {
    let position = Position.make(0, 0)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

    test("handles checkbox with no label", () => {
      switch parser.parse("[x]", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles extra whitespace before checkbox", () => {
      switch parser.parse("   [x] Label", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          expect(checked)->toBe(true)
          expect(label)->toBe("Label")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles extra whitespace after label", () => {
      switch parser.parse("[x] Label   ", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Label")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("returns None for invalid pattern", () => {
      let result = parser.parse("not a checkbox", position, bounds)
      expect(result)->toBe(None)
    })

    test("returns None for button-like pattern [ Text ]", () => {
      let result = parser.parse("[ Submit ]", position, bounds)
      expect(result)->toBe(None)
    })
  })

  describe("parse - label variations", () => {
    let position = Position.make(2, 3)
    let bounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=40)

    test("handles label with numbers", () => {
      switch parser.parse("[x] Option 123", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Option 123")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles label with punctuation", () => {
      switch parser.parse("[ ] Yes, I agree!", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Yes, I agree!")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles label with parentheses", () => {
      switch parser.parse("[x] Enable feature (beta)", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Enable feature (beta)")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("handles label with quotes", () => {
      switch parser.parse("[x] Accept \"User Agreement\"", position, bounds) {
      | Some(Checkbox({label})) => {
          expect(label)->toBe("Accept \"User Agreement\"")
        }
      | _ => fail("Expected Checkbox element")
      }
    })
  })

  describe("priority", () => {
    test("has priority of 85", () => {
      expect(parser.priority)->toBe(85)
    })

    test("priority is higher than text parser (1)", () => {
      expect(parser.priority)->toBeGreaterThan(1)
    })

    test("priority is lower than button parser (100)", () => {
      expect(parser.priority)->toBeLessThan(100)
    })

    test("priority is lower than input parser (90)", () => {
      expect(parser.priority)->toBeLessThan(90)
    })
  })
})
