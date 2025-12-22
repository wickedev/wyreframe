// TextParser_test.res
// Unit tests for the TextParser fallback module

open Vitest

// Create a test parser instance
let parser = TextParser.make()

// Helper to create a test position
let makePosition = (row: int, col: int): Types.Position.t => Types.Position.make(row, col)

// Helper to create test bounds
let makeBounds = (~top: int, ~left: int, ~bottom: int, ~right: int): Types.Bounds.t => {
  top: top,
  left: left,
  bottom: bottom,
  right: right,
}

describe("TextParser", () => {
  describe("priority", () => {
    test("should have lowest priority (1)", t => {
      t->expect(parser.priority)->Expect.toBe(1)
    })
  })

  describe("canParse", () => {
    test("should always return true for any content", t => {
      t->expect(parser.canParse("hello world"))->Expect.toBe(true)
    })

    test("should return true for empty string", t => {
      t->expect(parser.canParse(""))->Expect.toBe(true)
    })

    test("should return true for special characters", t => {
      t->expect(parser.canParse("!@#$%^&*()"))->Expect.toBe(true)
    })

    test("should return true for numbers", t => {
      t->expect(parser.canParse("12345"))->Expect.toBe(true)
    })

    test("should return true for content that looks like other elements", t => {
      // Even if content matches other patterns, TextParser accepts it
      // (though it would normally be caught by higher-priority parsers first)
      t->expect(parser.canParse("[ Button ]"))->Expect.toBe(true)
      t->expect(parser.canParse("#input"))->Expect.toBe(true)
      t->expect(parser.canParse("\"Link\""))->Expect.toBe(true)
      t->expect(parser.canParse("[x] Checkbox"))->Expect.toBe(true)
      t->expect(parser.canParse("* Emphasis"))->Expect.toBe(true)
    })

    test("should return true for whitespace-only content", t => {
      t->expect(parser.canParse("   "))->Expect.toBe(true)
      t->expect(parser.canParse("\t"))->Expect.toBe(true)
    })
  })

  describe("parse", () => {
    let pos = makePosition(5, 10)
    let bounds = makeBounds(~top=0, ~left=0, ~bottom=10, ~right=20)

    test("should parse plain text content", t => {
      let result = parser.parse("Hello World", pos, bounds)

      switch result {
      | Some(Types.Text({content, emphasis, position, align})) => {
          t->expect(content)->Expect.toBe("Hello World")
          t->expect(emphasis)->Expect.toBe(false)
          t->expect(position)->Expect.toEqual(pos)
          t->expect(align)->Expect.toBe(Types.Left)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })

    test("should set emphasis to false by default", t => {
      let result = parser.parse("Some text", pos, bounds)

      switch result {
      | Some(Types.Text({emphasis})) => t->expect(emphasis)->Expect.toBe(false)
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })

    test("should preserve the exact content without modification", t => {
      let testCases = [
        "plain text",
        "  whitespace preserved  ",
        "UPPERCASE",
        "123numbers",
        "special!@#chars",
        "",
      ]

      testCases->Array.forEach(content => {
        let result = parser.parse(content, pos, bounds)

        switch result {
        | Some(Types.Text({content: parsed})) =>
          t->expect(parsed)->Expect.toBe(content)
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
        }
      })
    })

    test("should capture unrecognized patterns", t => {
      // These patterns don't match standard element syntax
      let unrecognizedPatterns = [
        "This is just text",
        "No special syntax here",
        "Random content 123",
        "Unmatched [ bracket",
        "Partial #",
        "Quote without end\"",
      ]

      unrecognizedPatterns->Array.forEach(content => {
        let result = parser.parse(content, pos, bounds)

        switch result {
        | Some(Types.Text(_)) => () // Success - pattern matched
        | _ => t->expect(true)->Expect.toBe(false) // fail: Should parse unrecognized pattern
        }
      })
    })

    test("should use provided position", t => {
      let customPos = makePosition(42, 17)
      let result = parser.parse("test", customPos, bounds)

      switch result {
      | Some(Types.Text({position})) => {
          t->expect(position.row)->Expect.toBe(42)
          t->expect(position.col)->Expect.toBe(17)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })

    test("should always use Left alignment for fallback text", t => {
      // TextParser uses Left alignment by default for simplicity
      // More sophisticated alignment is handled by specific parsers
      let result = parser.parse("centered text", pos, bounds)

      switch result {
      | Some(Types.Text({align})) => t->expect(align)->Expect.toBe(Types.Left)
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Text element
      }
    })
  })

  describe("integration with ParserRegistry", () => {
    test("should act as fallback when no other parser matches", t => {
      // Simulate content that no specific parser would recognize
      let unknownContent = "This is completely unstructured text"
      let result = parser.parse(unknownContent, makePosition(0, 0), makeBounds(~top=0, ~left=0, ~bottom=10, ~right=50))

      switch result {
      | Some(Types.Text({content})) =>
        t->expect(content)->Expect.toBe(unknownContent)
      | _ => t->expect(true)->Expect.toBe(false) // fail: TextParser should catch unrecognized content
      }
    })
  })
})
