// TextParser_test.res
// Unit tests for the TextParser fallback module

open RescriptCore

// Create a test parser instance
let parser = TextParser.make()

// Helper to create a test position
let makePosition = (row: int, col: int): Position.t => Position.make(row, col)

// Helper to create test bounds
let makeBounds = (~top: int, ~left: int, ~bottom: int, ~right: int): Types.bounds => {
  top: top,
  left: left,
  bottom: bottom,
  right: right,
}

describe("TextParser", () => {
  describe("priority", () => {
    test("should have lowest priority (1)", () => {
      Assert.equals(parser.priority, 1)
    })
  })

  describe("canParse", () => {
    test("should always return true for any content", () => {
      Assert.equals(parser.canParse("hello world"), true)
    })

    test("should return true for empty string", () => {
      Assert.equals(parser.canParse(""), true)
    })

    test("should return true for special characters", () => {
      Assert.equals(parser.canParse("!@#$%^&*()"), true)
    })

    test("should return true for numbers", () => {
      Assert.equals(parser.canParse("12345"), true)
    })

    test("should return true for content that looks like other elements", () => {
      // Even if content matches other patterns, TextParser accepts it
      // (though it would normally be caught by higher-priority parsers first)
      Assert.equals(parser.canParse("[ Button ]"), true)
      Assert.equals(parser.canParse("#input"), true)
      Assert.equals(parser.canParse("\"Link\""), true)
      Assert.equals(parser.canParse("[x] Checkbox"), true)
      Assert.equals(parser.canParse("* Emphasis"), true)
    })

    test("should return true for whitespace-only content", () => {
      Assert.equals(parser.canParse("   "), true)
      Assert.equals(parser.canParse("\t"), true)
    })
  })

  describe("parse", () => {
    let pos = makePosition(5, 10)
    let bounds = makeBounds(~top=0, ~left=0, ~bottom=10, ~right=20)

    test("should parse plain text content", () => {
      let result = parser.parse("Hello World", pos, bounds)

      switch result {
      | Some(Types.Text({content, emphasis, position, align})) => {
          Assert.equals(content, "Hello World")
          Assert.equals(emphasis, false)
          Assert.equals(position, pos)
          Assert.equals(align, Types.Left)
        }
      | _ => Assert.fail("Expected Text element")
      }
    })

    test("should set emphasis to false by default", () => {
      let result = parser.parse("Some text", pos, bounds)

      switch result {
      | Some(Types.Text({emphasis})) => Assert.equals(emphasis, false)
      | _ => Assert.fail("Expected Text element")
      }
    })

    test("should preserve the exact content without modification", () => {
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
          Assert.equals(parsed, content)
        | _ => Assert.fail(`Expected Text element for content: ${content}`)
        }
      })
    })

    test("should capture unrecognized patterns", () => {
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
        | _ => Assert.fail(`Should parse unrecognized pattern: ${content}`)
        }
      })
    })

    test("should use provided position", () => {
      let customPos = makePosition(42, 17)
      let result = parser.parse("test", customPos, bounds)

      switch result {
      | Some(Types.Text({position})) => {
          Assert.equals(position.row, 42)
          Assert.equals(position.col, 17)
        }
      | _ => Assert.fail("Expected Text element")
      }
    })

    test("should always use Left alignment for fallback text", () => {
      // TextParser uses Left alignment by default for simplicity
      // More sophisticated alignment is handled by specific parsers
      let result = parser.parse("centered text", pos, bounds)

      switch result {
      | Some(Types.Text({align})) => Assert.equals(align, Types.Left)
      | _ => Assert.fail("Expected Text element")
      }
    })
  })

  describe("integration with ParserRegistry", () => {
    test("should act as fallback when no other parser matches", () => {
      // Simulate content that no specific parser would recognize
      let unknownContent = "This is completely unstructured text"
      let result = parser.parse(unknownContent, makePosition(0, 0), makeBounds(~top=0, ~left=0, ~bottom=10, ~right=50))

      switch result {
      | Some(Types.Text({content})) =>
        Assert.equals(content, unknownContent)
      | _ => Assert.fail("TextParser should catch unrecognized content")
      }
    })
  })
})
