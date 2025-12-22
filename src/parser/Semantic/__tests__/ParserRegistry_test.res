// ParserRegistry_test.res
// Unit tests for ParserRegistry module

open Jest
open Expect

describe("ParserRegistry", () => {
  describe("make", () => {
    test("creates an empty registry", () => {
      let registry = ParserRegistry.make()
      expect(registry.parsers->Array.length)->toBe(0)
    })
  })

  describe("register", () => {
    test("adds a parser to the registry", () => {
      let registry = ParserRegistry.make()
      let parser = TextParser.make()

      registry->ParserRegistry.register(parser)

      expect(registry.parsers->Array.length)->toBe(1)
    })

    test("sorts parsers by priority (descending)", () => {
      let registry = ParserRegistry.make()

      // Register parsers in random order
      registry->ParserRegistry.register(TextParser.make()) // priority 1
      registry->ParserRegistry.register(InputParser.make()) // priority 90
      registry->ParserRegistry.register(CheckboxParser.make()) // priority 85
      registry->ParserRegistry.register(LinkParser.make()) // priority 80

      // Verify they are sorted by priority descending
      expect(registry.parsers[0].priority)->toBe(90) // InputParser
      expect(registry.parsers[1].priority)->toBe(85) // CheckboxParser
      expect(registry.parsers[2].priority)->toBe(80) // LinkParser
      expect(registry.parsers[3].priority)->toBe(1) // TextParser
    })

    test("maintains sort order when registering multiple parsers", () => {
      let registry = ParserRegistry.make()

      registry->ParserRegistry.register(LinkParser.make()) // priority 80
      registry->ParserRegistry.register(InputParser.make()) // priority 90
      registry->ParserRegistry.register(TextParser.make()) // priority 1

      expect(registry.parsers[0].priority)->toBe(90)
      expect(registry.parsers[1].priority)->toBe(80)
      expect(registry.parsers[2].priority)->toBe(1)
    })
  })

  describe("parse", () => {
    let testPosition = Position.make(0, 0)
    let testBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

    test("tries parsers in priority order", () => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())
      registry->ParserRegistry.register(TextParser.make())

      // Should match InputParser (higher priority)
      let result = registry->ParserRegistry.parse("#email", testPosition, testBounds)

      switch result {
      | Types.Input({id}) => expect(id)->toBe("email")
      | _ => fail("Expected Input element")
      }
    })

    test("falls back to lower priority parser if higher priority fails", () => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())
      registry->ParserRegistry.register(TextParser.make())

      // Should fall back to TextParser (InputParser won't match)
      let result = registry->ParserRegistry.parse("plain text", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => expect(content)->toBe("plain text")
      | _ => fail("Expected Text element")
      }
    })

    test("parses checkbox content correctly", () => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(CheckboxParser.make())
      registry->ParserRegistry.register(TextParser.make())

      let result = registry->ParserRegistry.parse("[x] Accept terms", testPosition, testBounds)

      switch result {
      | Types.Checkbox({checked, label}) => {
          expect(checked)->toBe(true)
          expect(label)->toBe("Accept terms")
        }
      | _ => fail("Expected Checkbox element")
      }
    })

    test("parses link content correctly", () => {
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(LinkParser.make())
      registry->ParserRegistry.register(TextParser.make())

      let result = registry->ParserRegistry.parse("\"Click Here\"", testPosition, testBounds)

      switch result {
      | Types.Link({text, id}) => {
          expect(text)->toBe("Click Here")
          expect(id)->toBe("click-here")
        }
      | _ => fail("Expected Link element")
      }
    })

    test("returns text element as fallback when no parser matches", () => {
      // Create registry without TextParser to test fallback
      let registry = ParserRegistry.make()
      registry->ParserRegistry.register(InputParser.make())

      let result = registry->ParserRegistry.parse("unmatched content", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => expect(content)->toBe("unmatched content")
      | _ => fail("Expected fallback Text element")
      }
    })
  })

  describe("makeDefault", () => {
    test("creates registry with built-in parsers", () => {
      let registry = ParserRegistry.makeDefault()

      // Should have at least InputParser, CheckboxParser, LinkParser, TextParser
      expect(registry.parsers->Array.length)->toBeGreaterThanOrEqual(4)
    })

    test("default registry can parse input fields", () => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Position.make(5, 10)
      let testBounds = Bounds.make(~top=0, ~left=0, ~bottom=20, ~right=30)->Option.getExn

      let result = registry->ParserRegistry.parse("#password", testPosition, testBounds)

      switch result {
      | Types.Input({id}) => expect(id)->toBe("password")
      | _ => fail("Expected Input element")
      }
    })

    test("default registry can parse checkboxes", () => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Position.make(0, 0)
      let testBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

      let result = registry->ParserRegistry.parse("[ ] Unchecked", testPosition, testBounds)

      switch result {
      | Types.Checkbox({checked}) => expect(checked)->toBe(false)
      | _ => fail("Expected Checkbox element")
      }
    })

    test("default registry can parse links", () => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Position.make(0, 0)
      let testBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

      let result = registry->ParserRegistry.parse("\"Sign Up\"", testPosition, testBounds)

      switch result {
      | Types.Link({text}) => expect(text)->toBe("Sign Up")
      | _ => fail("Expected Link element")
      }
    })

    test("default registry falls back to text for unrecognized content", () => {
      let registry = ParserRegistry.makeDefault()
      let testPosition = Position.make(0, 0)
      let testBounds = Bounds.make(~top=0, ~left=0, ~bottom=10, ~right=10)->Option.getExn

      let result = registry->ParserRegistry.parse("Random text", testPosition, testBounds)

      switch result {
      | Types.Text({content}) => expect(content)->toBe("Random text")
      | _ => fail("Expected Text element")
      }
    })
  })
})
