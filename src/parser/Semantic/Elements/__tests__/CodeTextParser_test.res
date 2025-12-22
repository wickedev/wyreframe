// CodeTextParser_test.res
// Tests for single-quote-wrapped text parser with position-based alignment

open Types

// Test: should recognize single-quote-wrapped text
let test_canParse_quotedText = () => {
  let content = "'centered text'"
  assert(CodeTextParser.canParse(content) === true)
}

// Test: should recognize quoted text with spaces
let test_canParse_withSpaces = () => {
  let content = "  'code'  "
  assert(CodeTextParser.canParse(content) === true)
}

// Test: should not recognize plain text
let test_canParse_plainText = () => {
  let content = "plain text"
  assert(CodeTextParser.canParse(content) === false)
}

// Test: should extract text from quotes
let test_parse_extractText = () => {
  let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=30)
  let content = "'Submit'"
  let position = Position.make(1, 1)

  switch CodeTextParser.parse(content, position, bounds) {
  | Some(Text({content, emphasis, _})) => {
      assert(content === "Submit")
      assert(emphasis === true)
    }
  | _ => assert(false)
  }
}

// Test: should calculate center alignment for centered content
let test_parse_centerAlignment = () => {
  let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=30)
  let content = "'Centered'"
  let position = Position.make(1, 12) // Roughly centered

  switch CodeTextParser.parse(content, position, bounds) {
  | Some(Text({align, _})) => {
      assert(align === Center)
    }
  | _ => assert(false)
  }
}

// Test: should calculate left alignment for left-positioned content
let test_parse_leftAlignment = () => {
  let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=30)
  let content = "'Left'"
  let position = Position.make(1, 1) // Near left edge

  switch CodeTextParser.parse(content, position, bounds) {
  | Some(Text({align, _})) => {
      assert(align === Left)
    }
  | _ => assert(false)
  }
}

// Test: should calculate right alignment for right-positioned content
let test_parse_rightAlignment = () => {
  let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=30)
  let content = "'Right'"
  let position = Position.make(1, 24) // Near right edge

  switch CodeTextParser.parse(content, position, bounds) {
  | Some(Text({align, _})) => {
      assert(align === Right)
    }
  | _ => assert(false)
  }
}

// Test: should return None for empty quoted content
let test_parse_emptyContent = () => {
  let bounds = Bounds.make(~top=0, ~left=0, ~bottom=5, ~right=30)
  let content = "'   '"
  let position = Position.make(1, 1)

  switch CodeTextParser.parse(content, position, bounds) {
  | None => assert(true)
  | Some(_) => assert(false)
  }
}

// Test: parser should have priority 75
let test_make_priority = () => {
  let parser = CodeTextParser.make()
  assert(parser.priority === 75)
}

// Run all tests
let runTests = () => {
  Console.log("Running CodeTextParser tests...")

  test_canParse_quotedText()
  Console.log("  test_canParse_quotedText passed")

  test_canParse_withSpaces()
  Console.log("  test_canParse_withSpaces passed")

  test_canParse_plainText()
  Console.log("  test_canParse_plainText passed")

  test_parse_extractText()
  Console.log("  test_parse_extractText passed")

  test_parse_centerAlignment()
  Console.log("  test_parse_centerAlignment passed")

  test_parse_leftAlignment()
  Console.log("  test_parse_leftAlignment passed")

  test_parse_rightAlignment()
  Console.log("  test_parse_rightAlignment passed")

  test_parse_emptyContent()
  Console.log("  test_parse_emptyContent passed")

  test_make_priority()
  Console.log("  test_make_priority passed")

  Console.log("All CodeTextParser tests passed!")
}

// Auto-run tests
let _ = runTests()
