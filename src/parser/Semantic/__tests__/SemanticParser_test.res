// SemanticParser_test.res
// Unit tests for SemanticParser - Box Content Extraction (Task 30)

open Types

// Helper to create a simple grid for testing
let makeTestGrid = (lines: array<string>): Grid.t => {
  Grid.fromLines(lines)
}

// Helper to create a box with bounds
let makeTestBox = (top: int, left: int, bottom: int, right: int): SemanticParser.box => {
  {
    name: None,
    bounds: {top, left, bottom, right},
    children: [],
  }
}

// Test 1: Extract content from a simple box
let test_extractContentLines_simpleBox = () => {
  let grid = makeTestGrid([
    "+-------+",
    "| Hello |",
    "+-------+",
  ])

  let box = makeTestBox(0, 0, 2, 8)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should extract: [" Hello "]
  assert(Array.length(content) === 1)
  assert(content[0] === " Hello ")
}

// Test 2: Extract content from box with multiple lines
let test_extractContentLines_multipleLines = () => {
  let grid = makeTestGrid([
    "+--Login--+",
    "|  #email |",
    "| [Submit]|",
    "+----------+",
  ])

  let box = makeTestBox(0, 0, 3, 10)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should extract: ["  #email ", " [Submit]"]
  assert(Array.length(content) === 2)
  assert(content[0] === "  #email ")
  assert(content[1] === " [Submit]")
}

// Test 3: Extract content preserving internal whitespace
let test_extractContentLines_preserveWhitespace = () => {
  let grid = makeTestGrid([
    "+---------+",
    "|  a   b  |",
    "+---------+",
  ])

  let box = makeTestBox(0, 0, 2, 10)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should preserve the exact spacing: "  a   b  "
  assert(Array.length(content) === 1)
  assert(content[0] === "  a   b  ")
}

// Test 4: Empty box (no content area)
let test_extractContentLines_emptyBox = () => {
  let grid = makeTestGrid([
    "+---+",
    "+---+",
  ])

  let box = makeTestBox(0, 0, 1, 4)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should return empty array for box with no content area
  assert(Array.length(content) === 0)
}

// Test 5: Box with divider in content
let test_extractContentLines_withDivider = () => {
  let grid = makeTestGrid([
    "+------+",
    "| Head |",
    "|======|",
    "| Body |",
    "+------+",
  ])

  let box = makeTestBox(0, 0, 4, 7)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should extract all lines including divider
  assert(Array.length(content) === 3)
  assert(content[0] === " Head ")
  assert(content[1] === "======")
  assert(content[2] === " Body ")
}

// Test 6: Box with empty lines
let test_extractContentLines_withEmptyLines = () => {
  let grid = makeTestGrid([
    "+-----+",
    "| Top |",
    "|     |",
    "| Bot |",
    "+-----+",
  ])

  let box = makeTestBox(0, 0, 4, 6)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should extract all lines, empty line as spaces
  assert(Array.length(content) === 3)
  assert(content[0] === " Top ")
  assert(content[1] === "     ")
  assert(content[2] === " Bot ")
}

// Test 7: Nested box scenario (inner box content)
let test_extractContentLines_nestedBox = () => {
  let grid = makeTestGrid([
    "+-----------+",
    "| +-------+ |",
    "| | Inner | |",
    "| +-------+ |",
    "+-----------+",
  ])

  // Extract inner box content
  let innerBox = makeTestBox(1, 2, 3, 9)
  let innerContent = SemanticParser.extractContentLines(innerBox, grid)

  // Should extract: [" Inner "]
  assert(Array.length(innerContent) === 1)
  assert(innerContent[0] === " Inner ")

  // Extract outer box content (includes inner box structure)
  let outerBox = makeTestBox(0, 0, 4, 12)
  let outerContent = SemanticParser.extractContentLines(outerBox, grid)

  // Should extract outer content with inner box visible
  assert(Array.length(outerContent) === 3)
  assert(String.includes(outerContent[0], "+-------+"))
}

// Test 8: Box with special characters in content
let test_extractContentLines_specialChars = () => {
  let grid = makeTestGrid([
    "+--------+",
    "| a|b-c+ |",
    "+--------+",
  ])

  let box = makeTestBox(0, 0, 2, 9)
  let content = SemanticParser.extractContentLines(box, grid)

  // Should preserve special chars that appear in content
  assert(Array.length(content) === 1)
  assert(content[0] === " a|b-c+ ")
}

// Test utility functions

// Test: hasContent with non-empty box
let test_hasContent_nonEmpty = () => {
  let grid = makeTestGrid([
    "+-----+",
    "| Txt |",
    "+-----+",
  ])

  let box = makeTestBox(0, 0, 2, 6)
  assert(SemanticParser.hasContent(box, grid) === true)
}

// Test: hasContent with empty box
let test_hasContent_empty = () => {
  let grid = makeTestGrid([
    "+-----+",
    "|     |",
    "+-----+",
  ])

  let box = makeTestBox(0, 0, 2, 6)
  assert(SemanticParser.hasContent(box, grid) === false)
}

// Test: getContentLineCount
let test_getContentLineCount = () => {
  let grid = makeTestGrid([
    "+-----+",
    "| L1  |",
    "| L2  |",
    "| L3  |",
    "+-----+",
  ])

  let box = makeTestBox(0, 0, 4, 6)
  assert(SemanticParser.getContentLineCount(box, grid) === 3)
}

// ============================================================================
// Task 32: Scene Directive Parsing Tests
// ============================================================================

// Test: parseSceneDirectives with @scene
let test_parseSceneDirectives_scene = () => {
  let lines = ["@scene: login", "+--Box--+", "|      |", "+-------+"]
  let (metadata, contentLines) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.id === "login")
  assert(metadata.title === "login")
  assert(metadata.transition === "fade")
  assert(Array.length(contentLines) === 3)
}

// Test: parseSceneDirectives with @title
let test_parseSceneDirectives_title = () => {
  let lines = ["@scene: login", "@title: Login Page", "+--Box--+"]
  let (metadata, _) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.id === "login")
  assert(metadata.title === "Login Page")
}

// Test: parseSceneDirectives removes quotes from @title
let test_parseSceneDirectives_titleQuotes = () => {
  let lines = ["@scene: login", "@title: \"Login Page\"", "+--Box--+"]
  let (metadata, _) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.title === "Login Page")
}

// Test: parseSceneDirectives with @transition
let test_parseSceneDirectives_transition = () => {
  let lines = ["@scene: login", "@transition: slide", "+--Box--+"]
  let (metadata, _) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.transition === "slide")
}

// Test: parseSceneDirectives all directives together
let test_parseSceneDirectives_allDirectives = () => {
  let lines = [
    "@scene: login",
    "@title: Login Page",
    "@transition: slide",
    "",
    "+--Login--+",
    "|  #email |",
    "+----------+",
  ]
  let (metadata, contentLines) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.id === "login")
  assert(metadata.title === "Login Page")
  assert(metadata.transition === "slide")
  assert(Array.length(contentLines) === 4)
}

// Test: parseSceneDirectives defaults
let test_parseSceneDirectives_defaults = () => {
  let lines = ["+--Box--+", "|      |", "+-------+"]
  let (metadata, _) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.id === "main")
  assert(metadata.title === "main")
  assert(metadata.transition === "fade")
}

// Test: parseSceneDirectives ignores unknown directives
let test_parseSceneDirectives_unknownDirectives = () => {
  let lines = ["@scene: login", "@unknown: something", "@custom: value", "+--Box--+"]
  let (metadata, contentLines) = SemanticParser.parseSceneDirectives(lines)

  assert(metadata.id === "login")
  assert(Array.length(contentLines) === 1)
}

// Test: splitSceneBlocks with --- separator
let test_splitSceneBlocks_dashedSeparator = () => {
  let input = `@scene: login
+--Login--+

---

@scene: home
+--Home--+`

  let blocks = SemanticParser.splitSceneBlocks(input)

  assert(Array.length(blocks) === 2)
  assert(String.includes(blocks[0]->Belt.Option.getExn, "@scene: login"))
  assert(String.includes(blocks[1]->Belt.Option.getExn, "@scene: home"))
}

// Test: splitSceneBlocks with @scene separator
let test_splitSceneBlocks_sceneDirectiveSeparator = () => {
  let input = `@scene: login
+--Login--+
@scene: home
+--Home--+`

  let blocks = SemanticParser.splitSceneBlocks(input)

  assert(Array.length(blocks) === 2)
}

// Test: splitSceneBlocks single scene
let test_splitSceneBlocks_singleScene = () => {
  let input = `@scene: login
+--Login--+
|  #email |
+----------+`

  let blocks = SemanticParser.splitSceneBlocks(input)

  assert(Array.length(blocks) === 1)
}

// Test: splitSceneBlocks filters empty blocks
let test_splitSceneBlocks_filtersEmpty = () => {
  let input = `

---

@scene: login
+--Box--+

---

`

  let blocks = SemanticParser.splitSceneBlocks(input)

  assert(Array.length(blocks) === 1)
}

// Test: groupContentByScenes simple scene
let test_groupContentByScenes_simple = () => {
  let input = `@scene: login
@title: Login Page
@transition: slide

+--Login--+
|  #email |
+----------+`

  let scenes = SemanticParser.groupContentByScenes(input)

  assert(Array.length(scenes) === 1)

  let (metadata, content) = scenes[0]->Belt.Option.getExn
  assert(metadata.id === "login")
  assert(metadata.title === "Login Page")
  assert(metadata.transition === "slide")
  assert(Array.length(content) > 0)
}

// Test: groupContentByScenes multiple scenes
let test_groupContentByScenes_multiple = () => {
  let input = `@scene: login
+--Login--+

---

@scene: home
+--Home--+

---

@scene: settings
+--Settings--+`

  let scenes = SemanticParser.groupContentByScenes(input)

  assert(Array.length(scenes) === 3)

  let (meta1, _) = scenes[0]->Belt.Option.getExn
  let (meta2, _) = scenes[1]->Belt.Option.getExn
  let (meta3, _) = scenes[2]->Belt.Option.getExn

  assert(meta1.id === "login")
  assert(meta2.id === "home")
  assert(meta3.id === "settings")
}

// Test: groupContentByScenes default scene
let test_groupContentByScenes_default = () => {
  let input = `+--Box--+
|  Text |
+-------+`

  let scenes = SemanticParser.groupContentByScenes(input)

  assert(Array.length(scenes) === 1)

  let (metadata, _) = scenes[0]->Belt.Option.getExn
  assert(metadata.id === "main")
  assert(metadata.title === "main")
  assert(metadata.transition === "fade")
}

// Test: groupContentByScenes empty input
let test_groupContentByScenes_empty = () => {
  let input = ""
  let scenes = SemanticParser.groupContentByScenes(input)

  assert(Array.length(scenes) === 0)
}

// Test: groupContentByScenes complex example
let test_groupContentByScenes_complex = () => {
  let input = `@scene: login
@title: "Login Page"

+--Login----------------+
|   * WYREFRAME         |
|                       |
|   #email              |
|   #password           |
|                       |
|       [ Login ]       |
+----------------------+

---

@scene: home
@transition: slide

+--Home-----------------+
|   Welcome!            |
+----------------------+`

  let scenes = SemanticParser.groupContentByScenes(input)

  assert(Array.length(scenes) === 2)

  let (loginMeta, loginContent) = scenes[0]->Belt.Option.getExn
  assert(loginMeta.id === "login")
  assert(loginMeta.title === "Login Page")
  assert(String.includes(Array.join(loginContent, "\n"), "#email"))

  let (homeMeta, homeContent) = scenes[1]->Belt.Option.getExn
  assert(homeMeta.id === "home")
  assert(homeMeta.transition === "slide")
  assert(String.includes(Array.join(homeContent, "\n"), "Welcome!"))
}

// Run all tests
let runTests = () => {
  Console.log("Running SemanticParser tests...")
  Console.log("\n=== Task 30: Box Content Extraction ===")

  test_extractContentLines_simpleBox()
  Console.log("✓ Simple box content extraction")

  test_extractContentLines_multipleLines()
  Console.log("✓ Multiple lines extraction")

  test_extractContentLines_preserveWhitespace()
  Console.log("✓ Whitespace preservation")

  test_extractContentLines_emptyBox()
  Console.log("✓ Empty box handling")

  test_extractContentLines_withDivider()
  Console.log("✓ Box with divider")

  test_extractContentLines_withEmptyLines()
  Console.log("✓ Box with empty lines")

  test_extractContentLines_nestedBox()
  Console.log("✓ Nested box content")

  test_extractContentLines_specialChars()
  Console.log("✓ Special characters in content")

  test_hasContent_nonEmpty()
  Console.log("✓ hasContent (non-empty)")

  test_hasContent_empty()
  Console.log("✓ hasContent (empty)")

  test_getContentLineCount()
  Console.log("✓ getContentLineCount")

  Console.log("\n=== Task 32: Scene Directive Parsing ===")

  test_parseSceneDirectives_scene()
  Console.log("✓ Parse @scene directive")

  test_parseSceneDirectives_title()
  Console.log("✓ Parse @title directive")

  test_parseSceneDirectives_titleQuotes()
  Console.log("✓ Remove quotes from @title")

  test_parseSceneDirectives_transition()
  Console.log("✓ Parse @transition directive")

  test_parseSceneDirectives_allDirectives()
  Console.log("✓ Parse all directives together")

  test_parseSceneDirectives_defaults()
  Console.log("✓ Default metadata values")

  test_parseSceneDirectives_unknownDirectives()
  Console.log("✓ Ignore unknown directives")

  test_splitSceneBlocks_dashedSeparator()
  Console.log("✓ Split scenes by --- separator")

  test_splitSceneBlocks_sceneDirectiveSeparator()
  Console.log("✓ Split scenes by @scene directive")

  test_splitSceneBlocks_singleScene()
  Console.log("✓ Handle single scene")

  test_splitSceneBlocks_filtersEmpty()
  Console.log("✓ Filter empty blocks")

  test_groupContentByScenes_simple()
  Console.log("✓ Group simple scene with directives")

  test_groupContentByScenes_multiple()
  Console.log("✓ Group multiple scenes")

  test_groupContentByScenes_default()
  Console.log("✓ Create default scene")

  test_groupContentByScenes_empty()
  Console.log("✓ Handle empty input")

  test_groupContentByScenes_complex()
  Console.log("✓ Handle complex multi-scene example")

  Console.log("\n✅ All SemanticParser tests passed!")
}
