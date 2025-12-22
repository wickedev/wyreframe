// ParserRegistry_test.res
// Unit tests for ParserRegistry module

open Vitest

describe("ParserRegistry", t => {
  describe("make", t => {
    test("creates an empty registry", t => {
      let registry = ParserRegistry.make()
      t->expect(registry.parsers->Array.length)->Expect.toBe(0)
    })
  })

  describe("register", t => {
    test("adds a parser to the registry", t => {
      let registry = ParserRegistry.make()
      let parser = TextParser.make()

      registry->ParserRegistry.register(parser)

      t->expect(registry.parsers->Array.length)->Expect.toBe(1)
    })

    test("sorts parsers by priority (descending)", t => {
      let registry = ParserRegistry.make()

      // Register parsers in random order
      registry->ParserRegistry.register(TextParser.make()) // priority 1
      registry->ParserRegistry.register(InputParser.make()) // priority 90
      registry->ParserRegistry.register(CheckboxParser.make()) // priority 85
      registry->ParserRegistry.register(LinkParser.make()) // priority 80

      // Verify they are sorted by priority descending
      t->expect(Array.getUnsafe(registry.parsers, 0).priority)->Expect.toBe(90) // InputParser
      t->expect(Array.getUnsafe(registry.parsers, 1).priority)->Expect.toBe(85) // CheckboxParser
      t->expect(Array.getUnsafe(registry.parsers, 2).priority)->Expect.toBe(80) // LinkParser
      t->expect(Array.getUnsafe(registry.parsers, 3).priority)->Expect.toBe(1) // TextParser
    })

    test("maintains sort order when registering multiple parsers", t => {
      let registry = ParserRegistry.make()

      registry->ParserRegistry.register(LinkParser.make()) // priority 80
      registry->ParserRegistry.register(InputParser.make()) // priority 90
      registry->ParserRegistry.register(TextParser.make()) // priority 1

      t->expect(Array.getUnsafe(registry.parsers, 0).priority)->Expect.toBe(90)
      t->expect(Array.getUnsafe(registry.parsers, 1).priority)->Expect.toBe(80)
      t->expect(Array.getUnsafe(registry.parsers, 2).priority)->Expect.toBe(1)
    })
  })

  describe("parse", t => {
    let testPosition = Types.Position.make(0, 0)
    let testBounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

    test("tries parsers in priority order", t => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())
      registry->ParserRegistry.register(TextParser.make())

      // Should match InputParser (higher priority)
      let result = registry->ParserRegistry.parse("#email", testPosition, testBounds)

      switch result {
      | Types.Input({id}) => t->expect(id)->Expect.toBe("email")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
      }
    })

    test("falls back to lower priority parser if higher priority fails", t => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())
      registry->ParserRegistry.register(TextParser.make())

      // Should fall back to TextParser (InputParser won't match)
      let result = registry->ParserRegistry.parse("plain text", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => t->expect(content)->Expect.toBe("plain text")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })

    test("parses checkbox content correctly", t => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(CheckboxParser.make())
      registry->ParserRegistry.register(TextParser.make())

      let result = registry->ParserRegistry.parse("[x] Accept terms", testPosition, testBounds)

      switch result {
      | Types.Checkbox({checked, label}) => {
          t->expect(checked)->Expect.toBe(true)
          t->expect(label)->Expect.toBe("Accept terms")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("parses link content correctly", t => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(LinkParser.make())
      registry->ParserRegistry.register(TextParser.make())

      let result = registry->ParserRegistry.parse("\"Click Here\"", testPosition, testBounds)

      switch result {
      | Types.Link({text, id}) => {
          t->expect(text)->Expect.toBe("Click Here")
          t->expect(id)->Expect.toBe("click-here")
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
      }
    })

    test("returns text element as fallback when no parser matches", t => {
      // Create registry without TextParser to test fallback
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())

      let result = registry->ParserRegistry.parse("unmatched content", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => t->expect(content)->Expect.toBe("unmatched content")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected fallback Text element
      }
    })
  })

  describe("makeDefault", t => {
    test("creates registry with built-in parsers", t => {
      let registry = ParserRegistry.makeDefault()

      // Should have at least InputParser, CheckboxParser, LinkParser, TextParser
      t->expect(registry.parsers->Array.length)->Expect.Int.toBeGreaterThanOrEqual(4)
    })

    test("default registry can parse input fields", t => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Types.Position.make(5, 10)
      let testBounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=30)

      let result = registry->ParserRegistry.parse("#password", testPosition, testBounds)

      switch result {
      | Types.Input({id}) => t->expect(id)->Expect.toBe("password")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Input element
      }
    })

    test("default registry can parse checkboxes", t => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Types.Position.make(0, 0)
      let testBounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

      let result = registry->ParserRegistry.parse("[ ] Unchecked", testPosition, testBounds)

      switch result {
      | Types.Checkbox({checked}) => t->expect(checked)->Expect.toBe(false)
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Checkbox element
      }
    })

    test("default registry can parse links", t => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Types.Position.make(0, 0)
      let testBounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

      let result = registry->ParserRegistry.parse("\"Sign Up\"", testPosition, testBounds)

      switch result {
      | Types.Link({text}) => t->expect(text)->Expect.toBe("Sign Up")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
      }
    })

    test("default registry falls back to text for unrecognized content", t => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Types.Position.make(0, 0)
      let testBounds = Types.Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)

      let result = registry->ParserRegistry.parse("Random text", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => t->expect(content)->Expect.toBe("Random text")
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })
  })
})
