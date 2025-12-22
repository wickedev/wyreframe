// LinkParser_test.res
// Unit tests for LinkParser module
//
// Tests cover:
// - Valid link patterns
// - Escaped quotes within link text
// - Empty link text
// - Edge cases and boundary conditions

open Vitest

describe("LinkParser", () => {
  let testPosition = Types.Position.make(5, 10)
  let testBounds: Types.Bounds.t = {
    top: 0,
    left: 0,
    bottom: 10,
    right: 40,
  }

  describe("canParse", () => {
    test("returns true for valid quoted text", t => {
      t->expect(LinkParser.canParse("\"Login\""))->Expect.toBe(true)
    })

    test("returns true for quoted text with spaces", t => {
      t->expect(LinkParser.canParse("\"Sign Up Here\""))->Expect.toBe(true)
    })

    test("returns true for quoted text with numbers", t => {
      t->expect(LinkParser.canParse("\"Page 123\""))->Expect.toBe(true)
    })

    test("returns true for quoted text with special characters", t => {
      t->expect(LinkParser.canParse("\"Home - Main Page\""))->Expect.toBe(true)
    })

    test("returns false for text without quotes", t => {
      t->expect(LinkParser.canParse("Login"))->Expect.toBe(false)
    })

    test("returns false for text with only opening quote", t => {
      t->expect(LinkParser.canParse("\"Login"))->Expect.toBe(false)
    })

    test("returns false for text with only closing quote", t => {
      t->expect(LinkParser.canParse("Login\""))->Expect.toBe(false)
    })

    test("returns false for empty quotes", t => {
      t->expect(LinkParser.canParse("\"\""))->Expect.toBe(false)
    })

    test("returns false for button syntax", t => {
      t->expect(LinkParser.canParse("[ Submit ]"))->Expect.toBe(false)
    })

    test("returns false for input syntax", t => {
      t->expect(LinkParser.canParse("#username"))->Expect.toBe(false)
    })
  })

  describe("parse", () => {
    describe("valid links", () => {
      test("parses simple quoted text", t => {
        let result = LinkParser.parse("\"Login\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text, position, align})) => {
            t->expect(id)->Expect.toBe("login")
            t->expect(text)->Expect.toBe("Login")
            t->expect(position)->Expect.toEqual(testPosition)
            t->expect(align)->Expect.toBe(Types.Left)
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses quoted text with spaces", t => {
        let result = LinkParser.parse("\"Sign Up Here\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("sign-up-here")
            t->expect(text)->Expect.toBe("Sign Up Here")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses quoted text with numbers", t => {
        let result = LinkParser.parse("\"Page 123\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("page-123")
            t->expect(text)->Expect.toBe("Page 123")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses quoted text with hyphens", t => {
        let result = LinkParser.parse("\"Home-Page\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("home-page")
            t->expect(text)->Expect.toBe("Home-Page")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses quoted text with special characters", t => {
        let result = LinkParser.parse("\"Contact Us!\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("contact-us")
            t->expect(text)->Expect.toBe("Contact Us!")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses quoted text with multiple words", t => {
        let result = LinkParser.parse("\"Learn More About Our Services\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("learn-more-about-our-services")
            t->expect(text)->Expect.toBe("Learn More About Our Services")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("parses link in context with surrounding text", t => {
        let result = LinkParser.parse("Click \"Here\" to continue", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("here")
            t->expect(text)->Expect.toBe("Here")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })
    })

    describe("escaped quotes", () => {
      test("handles escaped quotes within link text", t => {
        let result = LinkParser.parse("\"Say \\\"Hello\\\"\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            t->expect(text)->Expect.toBe("Say \"Hello\"")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("handles multiple escaped quotes", t => {
        let result = LinkParser.parse("\"\\\"Quote\\\" and \\\"Unquote\\\"\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            t->expect(text)->Expect.toBe("\"Quote\" and \"Unquote\"")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })
    })

    describe("empty and whitespace text", () => {
      test("returns None for empty quotes", t => {
        let result = LinkParser.parse("\"\"", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for quotes with only whitespace", t => {
        let result = LinkParser.parse("\"   \"", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for quotes with only tabs", t => {
        let result = LinkParser.parse("\"\t\t\"", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for quotes with only newlines", t => {
        let result = LinkParser.parse("\"\n\n\"", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })
    })

    describe("invalid patterns", () => {
      test("returns None for text without quotes", t => {
        let result = LinkParser.parse("Login", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for text with only opening quote", t => {
        let result = LinkParser.parse("\"Login", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for text with only closing quote", t => {
        let result = LinkParser.parse("Login\"", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for button syntax", t => {
        let result = LinkParser.parse("[ Submit ]", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })

      test("returns None for input syntax", t => {
        let result = LinkParser.parse("#username", testPosition, testBounds)
        t->expect(result)->Expect.toBe(None)
      })
    })

    describe("edge cases", () => {
      test("handles single character link", t => {
        let result = LinkParser.parse("\"A\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id, text})) => {
            t->expect(id)->Expect.toBe("a")
            t->expect(text)->Expect.toBe("A")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("handles very long link text", t => {
        let longText = "This is a very long link text that spans multiple words and contains various characters"
        let result = LinkParser.parse(`"${longText}"`, testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            t->expect(text)->Expect.toBe(longText)
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("preserves case in link text", t => {
        let result = LinkParser.parse("\"CamelCaseLink\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({text})) => {
            t->expect(text)->Expect.toBe("CamelCaseLink")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("converts uppercase to lowercase in ID", t => {
        let result = LinkParser.parse("\"UPPERCASE LINK\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id})) => {
            t->expect(id)->Expect.toBe("uppercase-link")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })

      test("handles consecutive spaces in ID generation", t => {
        let result = LinkParser.parse("\"Multiple   Spaces\"", testPosition, testBounds)

        switch result {
        | Some(Types.Link({id})) => {
            t->expect(id)->Expect.toBe("multiple-spaces")
          }
        | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
        }
      })
    })
  })

  describe("slugify", () => {
    test("converts text to lowercase", t => {
      t->expect(LinkParser.slugify("HELLO WORLD"))->Expect.toBe("hello-world")
    })

    test("replaces spaces with hyphens", t => {
      t->expect(LinkParser.slugify("hello world"))->Expect.toBe("hello-world")
    })

    test("removes special characters", t => {
      t->expect(LinkParser.slugify("hello! world?"))->Expect.toBe("hello-world")
    })

    test("removes consecutive hyphens", t => {
      t->expect(LinkParser.slugify("hello---world"))->Expect.toBe("hello-world")
    })

    test("trims leading and trailing hyphens", t => {
      t->expect(LinkParser.slugify("-hello-world-"))->Expect.toBe("hello-world")
    })

    test("handles empty string", t => {
      t->expect(LinkParser.slugify(""))->Expect.toBe("")
    })

    test("handles only special characters", t => {
      t->expect(LinkParser.slugify("!!!###"))->Expect.toBe("")
    })

    test("preserves numbers", t => {
      t->expect(LinkParser.slugify("Page 123"))->Expect.toBe("page-123")
    })

    test("handles mixed alphanumeric", t => {
      t->expect(LinkParser.slugify("Test123Page"))->Expect.toBe("test123page")
    })
  })

  describe("unescapeQuotes", () => {
    test("unescapes escaped quotes", t => {
      t->expect(LinkParser.unescapeQuotes("Say \\\"Hello\\\""))->Expect.toBe("Say \"Hello\"")
    })

    test("handles multiple escaped quotes", t => {
      t->expect(LinkParser.unescapeQuotes("\\\"A\\\" and \\\"B\\\""))->Expect.toBe("\"A\" and \"B\"")
    })

    test("returns unchanged text without escaped quotes", t => {
      t->expect(LinkParser.unescapeQuotes("Hello World"))->Expect.toBe("Hello World")
    })

    test("handles empty string", t => {
      t->expect(LinkParser.unescapeQuotes(""))->Expect.toBe("")
    })
  })

  describe("make", () => {
    test("creates parser with priority 80", t => {
      let parser = LinkParser.make()
      t->expect(parser.priority)->Expect.toBe(80)
    })

    test("creates parser with canParse function", t => {
      let parser = LinkParser.make()
      t->expect(parser.canParse("\"Link\""))->Expect.toBe(true)
    })

    test("creates parser with parse function", t => {
      let parser = LinkParser.make()
      let result = parser.parse("\"Link\"", testPosition, testBounds)

      switch result {
      | Some(Types.Link(_)) => ()
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
      }
    })
  })

  describe("integration", () => {
    test("parses link within box content", t => {
      // Simulating link within a box: "Click \"here\" for details"
      let result = LinkParser.parse("Click \"here\" for details", testPosition, testBounds)

      switch result {
      | Some(Types.Link({id, text, position})) => {
          t->expect(id)->Expect.toBe("here")
          t->expect(text)->Expect.toBe("here")
          t->expect(position.row)->Expect.toBe(5)
          t->expect(position.col)->Expect.toBe(10)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
      }
    })

    test("distinguishes link from button syntax", t => {
      let linkResult = LinkParser.parse("\"Submit\"", testPosition, testBounds)
      let buttonResult = LinkParser.parse("[ Submit ]", testPosition, testBounds)

      switch (linkResult, buttonResult) {
      | (Some(Types.Link(_)), None) => ()
      | _ => t->expect(true)->Expect.toBe(false) // fail: Link parser should match quoted text but not button syntax
      }
    })

    test("handles position information correctly", t => {
      let customPos = Types.Position.make(20, 35)
      let result = LinkParser.parse("\"Test\"", customPos, testBounds)

      switch result {
      | Some(Types.Link({position})) => {
          t->expect(position.row)->Expect.toBe(20)
          t->expect(position.col)->Expect.toBe(35)
        }
      | _ => t->expect(true)->Expect.toBe(false) // fail: Expected Link element
      }
    })
  })
})
