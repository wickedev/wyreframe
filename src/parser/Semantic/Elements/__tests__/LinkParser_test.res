// LinkParser_test.res
// Unit tests for LinkParser module
//
// Tests cover:
// - Valid link patterns
// - Escaped quotes within link text
// - Empty link text
// - Edge cases and boundary conditions

open Jest
open Expect

describe("LinkParser", () => {
  let testPosition = Position.make(5, 10)
  let testBounds: Types.bounds = {
    top: 0,
    left: 0,
    bottom: 10,
    right: 40,
  }

  describe("canParse", () => {
    test("returns true for valid quoted text", () => {
      expect(LinkParser.canParse("\"Login\"))->toBe(true)
    })

    test("returns true for quoted text with spaces", () => {
      expect(LinkParser.canParse("\"Sign Up Here\""))->toBe(true)
    })

    test("returns true for quoted text with numbers", () => {
      expect(LinkParser.canParse("\"Page 123\""))->toBe(true)
    })

    test("returns true for quoted text with special characters", () => {
      expect(LinkParser.canParse("\"Home - Main Page\""))->toBe(true)
    })

    test("returns false for text without quotes", () => {
      expect(LinkParser.canParse("Login"))->toBe(false)
    })

    test("returns false for text with only opening quote", () => {
      expect(LinkParser.canParse("\"Login"))->toBe(false)
    })

    test("returns false for text with only closing quote", () => {
      expect(LinkParser.canParse("Login\""))->toBe(false)
    })

    test("returns false for empty quotes", () => {
      expect(LinkParser.canParse("\"\""))->toBe(false)
    })

    test("returns false for button syntax", () => {
      expect(LinkParser.canParse("[ Submit ]"))->toBe(false)
    })

    test("returns false for input syntax", () => {
      expect(LinkParser.canParse("#username"))->toBe(false)
    })
  })

  describe("parse", () => {
    describe("valid links", () => {
      test("parses simple quoted text", () => {
        let result = LinkParser.parse("\"Login\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text, position, align})) => {
            expect(id)->toBe("login")
            expect(text)->toBe("Login")
            expect(position)->toEqual(testPosition)
            expect(align)->toBe(Types.Left)
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses quoted text with spaces", () => {
        let result = LinkParser.parse("\"Sign Up Here\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("sign-up-here")
            expect(text)->toBe("Sign Up Here")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses quoted text with numbers", () => {
        let result = LinkParser.parse("\"Page 123\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("page-123")
            expect(text)->toBe("Page 123")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses quoted text with hyphens", () => {
        let result = LinkParser.parse("\"Home-Page\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("home-page")
            expect(text)->toBe("Home-Page")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses quoted text with special characters", () => {
        let result = LinkParser.parse("\"Contact Us!\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("contact-us")
            expect(text)->toBe("Contact Us!")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses quoted text with multiple words", () => {
        let result = LinkParser.parse("\"Learn More About Our Services\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("learn-more-about-our-services")
            expect(text)->toBe("Learn More About Our Services")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("parses link in context with surrounding text", () => {
        let result = LinkParser.parse("Click \"Here\" to continue", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("here")
            expect(text)->toBe("Here")
          }
        | _ => fail("Expected Link element")
        }
      })
    })

    describe("escaped quotes", () => {
      test("handles escaped quotes within link text", () => {
        let result = LinkParser.parse("\"Say \\\"Hello\\\"\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            expect(text)->toBe("Say \"Hello\"")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("handles multiple escaped quotes", () => {
        let result = LinkParser.parse("\"\\\"Quote\\\" and \\\"Unquote\\\"\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            expect(text)->toBe("\"Quote\" and \"Unquote\"")
          }
        | _ => fail("Expected Link element")
        }
      })
    })

    describe("empty and whitespace text", () => {
      test("returns None for empty quotes", () => {
        let result = LinkParser.parse("\"\"", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for quotes with only whitespace", () => {
        let result = LinkParser.parse("\"   \"", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for quotes with only tabs", () => {
        let result = LinkParser.parse("\"\t\t\"", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for quotes with only newlines", () => {
        let result = LinkParser.parse("\"\n\n\"", testPosition, testBounds)
        expect(result)->toBe(None)
      })
    })

    describe("invalid patterns", () => {
      test("returns None for text without quotes", () => {
        let result = LinkParser.parse("Login", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for text with only opening quote", () => {
        let result = LinkParser.parse("\"Login", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for text with only closing quote", () => {
        let result = LinkParser.parse("Login\"", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for button syntax", () => {
        let result = LinkParser.parse("[ Submit ]", testPosition, testBounds)
        expect(result)->toBe(None)
      })

      test("returns None for input syntax", () => {
        let result = LinkParser.parse("#username", testPosition, testBounds)
        expect(result)->toBe(None)
      })
    })

    describe("edge cases", () => {
      test("handles single character link", () => {
        let result = LinkParser.parse("\"A\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            expect(id)->toBe("a")
            expect(text)->toBe("A")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("handles very long link text", () => {
        let longText = "This is a very long link text that spans multiple words and contains various characters"
        let result = LinkParser.parse(`"${longText}"`, testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            expect(text)->toBe(longText)
          }
        | _ => fail("Expected Link element")
        }
      })

      test("preserves case in link text", () => {
        let result = LinkParser.parse("\"CamelCaseLink\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            expect(text)->toBe("CamelCaseLink")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("converts uppercase to lowercase in ID", () => {
        let result = LinkParser.parse("\"UPPERCASE LINK\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id})) => {
            expect(id)->toBe("uppercase-link")
          }
        | _ => fail("Expected Link element")
        }
      })

      test("handles consecutive spaces in ID generation", () => {
        let result = LinkParser.parse("\"Multiple   Spaces\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id})) => {
            expect(id)->toBe("multiple-spaces")
          }
        | _ => fail("Expected Link element")
        }
      })
    })
  })

  describe("slugify", () => {
    test("converts text to lowercase", () => {
      expect(LinkParser.slugify("HELLO WORLD"))->toBe("hello-world")
    })

    test("replaces spaces with hyphens", () => {
      expect(LinkParser.slugify("hello world"))->toBe("hello-world")
    })

    test("removes special characters", () => {
      expect(LinkParser.slugify("hello! world?"))->toBe("hello-world")
    })

    test("removes consecutive hyphens", () => {
      expect(LinkParser.slugify("hello---world"))->toBe("hello-world")
    })

    test("trims leading and trailing hyphens", () => {
      expect(LinkParser.slugify("-hello-world-"))->toBe("hello-world")
    })

    test("handles empty string", () => {
      expect(LinkParser.slugify(""))->toBe("")
    })

    test("handles only special characters", () => {
      expect(LinkParser.slugify("!!!###"))->toBe("")
    })

    test("preserves numbers", () => {
      expect(LinkParser.slugify("Page 123"))->toBe("page-123")
    })

    test("handles mixed alphanumeric", () => {
      expect(LinkParser.slugify("Test123Page"))->toBe("test123page")
    })
  })

  describe("unescapeQuotes", () => {
    test("unescapes escaped quotes", () => {
      expect(LinkParser.unescapeQuotes("Say \\\"Hello\\\""))->toBe("Say \"Hello\"")
    })

    test("handles multiple escaped quotes", () => {
      expect(LinkParser.unescapeQuotes("\\\"A\\\" and \\\"B\\\""))->toBe("\"A\" and \"B\"")
    })

    test("returns unchanged text without escaped quotes", () => {
      expect(LinkParser.unescapeQuotes("Hello World"))->toBe("Hello World")
    })

    test("handles empty string", () => {
      expect(LinkParser.unescapeQuotes(""))->toBe("")
    })
  })

  describe("make", () => {
    test("creates parser with priority 80", () => {
      let parser = LinkParser.make()
      expect(parser.priority)->toBe(80)
    })

    test("creates parser with canParse function", () => {
      let parser = LinkParser.make()
      expect(parser.canParse("\"Link\""))->toBe(true)
    })

    test("creates parser with parse function", () => {
      let parser = LinkParser.make()
      let result = parser.parse("\"Link\"", testPosition, testBounds)

      switch result {
      | Some(Types.Link(_)) => pass
      | _ => fail("Expected Link element")
      }
    })
  })

  describe("integration", () => {
    test("parses link within box content", () => {
      // Simulating link within a box: "Click \"here\" for details"
      let result = LinkParser.parse("Click \"here\" for details", testPosition, testBounds)

      switch result {
      | Some(Types.Link({id, text, position})) => {
          expect(id)->toBe("here")
          expect(text)->toBe("here")
          expect(position.row)->toBe(5)
          expect(position.col)->toBe(10)
        }
      | _ => fail("Expected Link element")
      }
    })

    test("distinguishes link from button syntax", () => {
      let linkResult = LinkParser.parse("\"Submit\"", testPosition, testBounds)
      let buttonResult = LinkParser.parse("[ Submit ]", testPosition, testBounds)

      switch (linkResult, buttonResult) {
      | (Some(Types.Link(_)), None) => pass
      | _ => fail("Link parser should match quoted text but not button syntax")
      }
    })

    test("handles position information correctly", () => {
      let customPos = Position.make(20, 35)
      let result = LinkParser.parse("\"Test\"", customPos, testBounds)

      switch result {
      | Some(Types.Link({position})) => {
          expect(position.row)->toBe(20)
          expect(position.col)->toBe(35)
        }
      | _ => fail("Expected Link element")
      }
    })
  })
})
