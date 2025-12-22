// CheckboxParser_test.res
// Unit tests for checkbox element parser

open Vitest

describe("CheckboxParser", () => {
  let parser = CheckboxParser.make()

  describe("canParse", () => {
    test("recognizes checked checkbox [x]", t => {
      t->expect(parser.canParse("[x]"))->Expect.toBe(true)
    })

    test("recognizes checked checkbox with uppercase X", t => {
      t->expect(parser.canParse("[X]"))->Expect.toBe(true)
    })

    test("recognizes unchecked checkbox [ ]", t => {
      t->expect(parser.canParse("[ ]"))->Expect.toBe(true)
    })

    test("recognizes unchecked checkbox with multiple spaces", t => {
      t->expect(parser.canParse("[   ]"))->Expect.toBe(true)
    })

    test("recognizes checkbox with label", t => {
      t->expect(parser.canParse("[x] Accept terms"))->Expect.toBe(true)
    })

    test("recognizes checkbox with label at end", t => {
      t->expect(parser.canParse("Accept terms [x]"))->Expect.toBe(true)
    })

    test("rejects plain text", t => {
      t->expect(parser.canParse("plain text"))->Expect.toBe(false)
    })

    test("rejects button syntax", t => {
      t->expect(parser.canParse("[ Button ]"))->Expect.toBe(false)
    })

    test("rejects input syntax", t => {
      t->expect(parser.canParse("#email"))->Expect.toBe(false)
    })

    test("rejects incomplete brackets", t => {
      t->expect(parser.canParse("[x"))->Expect.toBe(false)
      t->expect(parser.canParse("x]"))->Expect.toBe(false)
    })
  })

  describe("parse - checked state", () => {
    let position = Types.Position.make(5, 10)
    let bounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

    test("extracts checked state from [x]", t => {
      switch parser.parse("[x]", position, bounds) {
      | Some(Checkbox({checked, label, position: pos})) => {
          t->expect(checked)->Expect.toBe(true)
          t->expect(label)->Expect.toBe("")
          t->expect(pos.row)->Expect.toBe(5)
          t->expect(pos.col)->Expect.toBe(10)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles uppercase X in [X]", t => {
      switch parser.parse("[X]", position, bounds) {
      | Some(Checkbox({checked})) => {
          t->expect(checked)->Expect.toBe(true)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("extracts label after checked checkbox", t => {
      switch parser.parse("[x] Accept terms and conditions", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          t->expect(checked)->Expect.toBe(true)
          t->expect(label)->Expect.toBe("Accept terms and conditions")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("trims whitespace from label", t => {
      switch parser.parse("[x]   Subscribe to newsletter   ", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Subscribe to newsletter")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles label with special characters", t => {
      switch parser.parse("[x] I agree to the Terms & Conditions", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("I agree to the Terms & Conditions")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })
  })

  describe("parse - unchecked state", () => {
    let position = Types.Position.make(3, 5)
    let bounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=30)

    test("extracts unchecked state from [ ]", t => {
      switch parser.parse("[ ]", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          t->expect(checked)->Expect.toBe(false)
          t->expect(label)->Expect.toBe("")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles multiple spaces in brackets", t => {
      switch parser.parse("[   ]", position, bounds) {
      | Some(Checkbox({checked})) => {
          t->expect(checked)->Expect.toBe(false)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("extracts label after unchecked checkbox", t => {
      switch parser.parse("[ ] Remember me", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          t->expect(checked)->Expect.toBe(false)
          t->expect(label)->Expect.toBe("Remember me")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles long labels", t => {
      switch parser.parse("[ ] I would like to receive promotional emails and updates", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("I would like to receive promotional emails and updates")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })
  })

  describe("parse - edge cases", () => {
    let position = Types.Position.make(0, 0)
    let bounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=20)

    test("handles checkbox with no label", t => {
      switch parser.parse("[x]", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles extra whitespace before checkbox", t => {
      switch parser.parse("   [x] Label", position, bounds) {
      | Some(Checkbox({checked, label})) => {
          t->expect(checked)->Expect.toBe(true)
          t->expect(label)->Expect.toBe("Label")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles extra whitespace after label", t => {
      switch parser.parse("[x] Label   ", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Label")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("returns None for invalid pattern", t => {
      let result = parser.parse("not a checkbox", position, bounds)
      t->expect(result)->Expect.toBe(None)
    })

    test("returns None for button-like pattern [ Text ]", t => {
      let result = parser.parse("[ Submit ]", position, bounds)
      t->expect(result)->Expect.toBe(None)
    })
  })

  describe("parse - label variations", () => {
    let position = Types.Position.make(2, 3)
    let bounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=40)

    test("handles label with numbers", t => {
      switch parser.parse("[x] Option 123", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Option 123")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles label with punctuation", t => {
      switch parser.parse("[ ] Yes, I agree!", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Yes, I agree!")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles label with parentheses", t => {
      switch parser.parse("[x] Enable feature (beta)", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Enable feature (beta)")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("handles label with quotes", t => {
      switch parser.parse("[x] Accept \"User Agreement\"", position, bounds) {
      | Some(Checkbox({label})) => {
          t->expect(label)->Expect.toBe("Accept \"User Agreement\"")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })
  })

  describe("priority", () => {
    test("has priority of 85", t => {
      t->expect(parser.priority)->Expect.toBe(85)
    })

    test("priority is higher than text parser (1)", t => {
      t->expect(parser.priority)->Expect.Int.toBeGreaterThan(1)
    })

    test("priority is lower than button parser (100)", t => {
      t->expect(parser.priority)->Expect.Int.toBeLessThan(100)
    })

    test("priority is lower than input parser (90)", t => {
      t->expect(parser.priority)->Expect.Int.toBeLessThan(90)
    })
  })
})
