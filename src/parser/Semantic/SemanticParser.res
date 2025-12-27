// SemanticParser.res
// Stage 3: Semantic parsing - extracts and interprets box content

open Types

// ============================================================================
// Type Definitions
// ============================================================================

/**
 * Box type representing a rectangular container with bounds and children.
 * This matches the Box variant from the element type but is used during
 * the shape detection stage before full element parsing.
 */
type rec box = {
  name: option<string>,
  bounds: Bounds.t,
  children: array<box>,
}

/**
 * Type for scene metadata extracted from directives.
 * Represents the parsed values from @scene, @title, @transition, @device directives.
 */
type sceneMetadata = {
  id: string,
  title: string,
  transition: string,
  device: deviceType,
}

// ============================================================================
// Box Content Extraction
// ============================================================================

/**
 * Check if a position is within any child box (for Grid.t version).
 */
let isWithinChildBoxGrid = (row: int, col: int, children: array<box>): bool => {
  children->Array.some(child => {
    let b = child.bounds
    row >= b.top && row <= b.bottom && col >= b.left && col <= b.right
  })
}

/**
 * Extracts content lines from within a box's bounds, excluding child box regions.
 *
 * Core box content extraction function for SemanticParser
 *
 * Algorithm:
 * 1. Calculate content area by excluding border rows (top and bottom)
 * 2. For each content row, extract characters between left and right borders
 * 3. SKIP regions covered by child boxes to avoid duplicate content
 * 4. Preserve all internal whitespace exactly as it appears
 * 5. Convert cellChar array to string representation
 *
 * Border Exclusion:
 * - Top border: row at bounds.top
 * - Bottom border: row at bounds.bottom
 * - Left border: column at bounds.left
 * - Right border: column at bounds.right
 *
 * Content Area:
 * - Starts at row: bounds.top + 1
 * - Ends at row: bounds.bottom - 1
 * - Starts at column: bounds.left + 1
 * - Ends at column: bounds.right - 1
 *
 * @param box - The box to extract content from
 * @param grid - The grid containing the box (Grid.t type from Scanner module)
 * @returns Array of content lines (strings) without borders
 *
 * Example:
 * ```
 * +--Login--+     (row 0 - top border, excluded)
 * |  #email |     (row 1 - content: "  #email ")
 * | [Submit]|     (row 2 - content: " [Submit]")
 * +---------+     (row 3 - bottom border, excluded)
 * ```
 * Returns: ["  #email ", " [Submit]"]
 *
 * The function preserves:
 * - Leading whitespace: "  #email" keeps the two leading spaces
 * - Trailing whitespace: " [Submit]" keeps the leading space
 * - Internal whitespace: all spaces within content are preserved
 */
let extractContentLinesFromGrid = (box: box, grid: Grid.t): array<string> => {
  let bounds = box.bounds
  let children = box.children

  // Calculate content row range (exclude top and bottom borders)
  let contentStartRow = bounds.top + 1
  let contentEndRow = bounds.bottom - 1

  // If box has no content area (height <= 2), return empty array
  // This handles edge cases like single-line boxes: +---+
  if contentStartRow > contentEndRow {
    []
  } else {
    // Build array of content lines
    let contentLines = []

    // Iterate through each content row
    for row in contentStartRow to contentEndRow {
      // Skip rows that are entirely within child boxes
      let rowCoveredByChild = children->Array.some(child => {
        let b = child.bounds
        row >= b.top && row <= b.bottom &&
        b.left <= bounds.left + 1 && b.right >= bounds.right - 1
      })

      if !rowCoveredByChild {
        // Use Grid.getLine to safely retrieve the row
        switch Grid.getLine(grid, row) {
        | Some(rowCells) => {
            // Calculate content column range (exclude left and right borders)
            let contentStartCol = bounds.left + 1
            let contentEndCol = bounds.right - 1

            // Validate that we have a valid content area
            if contentStartCol <= contentEndCol {
              // Build line character by character, skipping child box regions
              let lineChars = []

              for col in contentStartCol to contentEndCol {
                // Skip columns within child boxes
                if !isWithinChildBoxGrid(row, col, children) {
                  switch rowCells->Array.get(col) {
                  | Some(cell) => {
                      let char = switch cell {
                      | Char(c) => c
                      | Space => " "
                      | VLine => "|"
                      | HLine => "-"
                      | Corner => "+"
                      | Divider => "="
                      }
                      lineChars->Array.push(char)->ignore
                    }
                  | None => ()
                  }
                }
              }

              let line = lineChars->Array.join("")
              contentLines->Array.push(line)->ignore
            } else {
              // Invalid content area (left border >= right border)
              contentLines->Array.push("")->ignore
            }
          }
        | None => {
            // Row doesn't exist in grid
            contentLines->Array.push("")->ignore
          }
        }
      }
    }

    contentLines
  }
}

/**
 * Convert a single cellChar to its string representation
 * Used internally for debugging and display purposes
 */
let cellCharToString = (cell: cellChar): string => {
  switch cell {
  | Char(c) => c
  | Space => " "
  | VLine => "|"
  | HLine => "-"
  | Corner => "+"
  | Divider => "="
  }
}

/**
 * Convert an array of cellChar to a string
 * This is a utility function that can be used by other semantic parsing functions
 */
let cellCharsToString = (cells: array<cellChar>): string => {
  cells->Array.map(cellCharToString)->Array.join("")
}

/**
 * Get box content as a single string with newlines
 * Useful for debugging and logging
 */
let getBoxContentAsString = (box: box, grid: Grid.t): string => {
  let lines = extractContentLinesFromGrid(box, grid)
  lines->Array.join("\n")
}

/**
 * Check if a box has any content (non-empty lines)
 */
let hasContent = (box: box, grid: Grid.t): bool => {
  let lines = extractContentLinesFromGrid(box, grid)
  lines->Array.some(line => {
    let trimmed = String.trim(line)
    String.length(trimmed) > 0
  })
}

/**
 * Get the number of content lines in a box (excluding borders)
 */
let getContentLineCount = (box: box, _grid: Grid.t): int => {
  let bounds = box.bounds
  let contentStartRow = bounds.top + 1
  let contentEndRow = bounds.bottom - 1

  if contentStartRow > contentEndRow {
    0
  } else {
    contentEndRow - contentStartRow + 1
  }
}

// ============================================================================
// Scene Directive Parsing
// ============================================================================

/**
 * Default scene metadata values.
 * Used when directives are not present or as fallback values.
 */
let defaultSceneMetadata = (): sceneMetadata => {
  id: "main",
  title: "main",
  transition: "fade",
  device: Desktop,
}

/**
 * Parse scene directives from an array of lines.
 *
 * Recognizes and extracts:
 * - @scene: <id> - Sets the scene identifier
 * - @title: <title> - Sets the scene title (quotes are removed)
 * - @transition: <transition> - Sets the transition type
 *
 * Returns a tuple of (sceneMetadata, contentLines) where contentLines
 * are the non-directive lines that contain actual wireframe content.
 *
 * @param lines - Array of lines from a scene block
 * @returns Tuple of (metadata, content lines)
 *
 * Example:
 * ```
 * @scene: login
 * @title: "Login Page"
 * @transition: slide
 *
 * +--Login--+
 * |  #email |
 * +----------+
 * ```
 * Returns: ({id: "login", title: "Login Page", transition: "slide"}, ["+--Login--+", ...])
 */
/**
 * Result type for parseSceneDirectives that includes line offset information.
 * The lineOffset indicates how many lines were removed from the beginning
 * before the first content line, which is needed to correctly report
 * line numbers in warnings and errors.
 */
type directiveParseResult = {
  metadata: sceneMetadata,
  contentLines: array<string>,
  lineOffset: int,  // Number of directive lines stripped from the beginning
}

/**
 * Parse scene directives and track line offset.
 * Returns metadata, content lines, and the number of lines stripped from the beginning.
 *
 * The lineOffset is calculated as the index of the first content line in the original
 * input. This offset is needed to convert grid row numbers back to original file line numbers.
 *
 * Example:
 * - Input: ["@scene: login", "", "+---+", ...]
 * - Output: contentLines = ["", "+---+", ...], lineOffset = 1
 *
 * Grid row 0 corresponds to original line (0 + lineOffset + 1) = line 2 (1-indexed)
 */
let parseSceneDirectivesWithOffset = (lines: array<string>): directiveParseResult => {
  // Use mutable refs to accumulate directive values
  let sceneId = ref(None)
  let title = ref(None)
  let transition = ref(None)
  let device = ref(None)
  let contentLines = []

  // Track the index of the first content line (for line offset calculation)
  let firstContentLineIndex = ref(None)

  lines->Array.forEachWithIndex((line, lineIndex) => {
    let trimmed = line->String.trim

    if trimmed->String.startsWith("@scene:") {
      // Extract scene ID: "@scene: login" -> "login"
      let id = trimmed->String.replace("@scene:", "")->String.trim
      sceneId := Some(id)
    } else if trimmed->String.startsWith("@title:") {
      // Extract title: "@title: Login Page" -> "Login Page"
      // Remove quotes if present: "@title: "Login Page"" -> "Login Page"
      let titleValue =
        trimmed
        ->String.replace("@title:", "")
        ->String.trim
        ->String.replaceAll("\"", "")
      title := Some(titleValue)
    } else if trimmed->String.startsWith("@transition:") {
      // Extract transition: "@transition: slide" -> "slide"
      let transitionValue = trimmed->String.replace("@transition:", "")->String.trim
      transition := Some(transitionValue)
    } else if trimmed->String.startsWith("@device:") {
      // Extract device: "@device: mobile" -> Mobile
      let deviceValue = trimmed->String.replace("@device:", "")->String.trim
      switch parseDeviceType(deviceValue) {
      | Some(d) => device := Some(d)
      | None => () // Invalid device, use default
      }
    } else if trimmed->String.startsWith("@") {
      // Skip other @ directives (for future extensibility)
      ()
    } else {
      // Non-directive line - add to content
      // Track the index of the first content line
      if firstContentLineIndex.contents === None {
        firstContentLineIndex := Some(lineIndex)
      }
      contentLines->Array.push(line)
    }
  })

  // Build final metadata record
  let finalId = switch sceneId.contents {
  | Some(id) => id
  | None => "main"
  }

  let finalTitle = switch (title.contents, sceneId.contents) {
  | (Some(t), _) => t // Explicit title takes precedence
  | (None, Some(id)) => id // Use scene ID as title if no explicit title
  | (None, None) => "main" // Default
  }

  let finalTransition = switch transition.contents {
  | Some(t) => t
  | None => "fade"
  }

  let finalDevice = switch device.contents {
  | Some(d) => d
  | None => Desktop // Default to desktop
  }

  let metadata = {
    id: finalId,
    title: finalTitle,
    transition: finalTransition,
    device: finalDevice,
  }

  // Calculate line offset: index of first content line
  // If no content lines, offset is 0
  let lineOffset = switch firstContentLineIndex.contents {
  | Some(idx) => idx
  | None => 0
  }

  {
    metadata,
    contentLines,
    lineOffset,
  }
}

/**
 * Parse scene directives from an array of lines.
 * This is the original API that returns just (metadata, contentLines) for backward compatibility.
 */
let parseSceneDirectives = (lines: array<string>): (sceneMetadata, array<string>) => {
  let result = parseSceneDirectivesWithOffset(lines)
  (result.metadata, result.contentLines)
}

/**
 * Split wireframe input into scene blocks.
 *
 * Scenes are separated by:
 * 1. The separator "---" on its own line
 * 2. A new @scene directive
 *
 * This function groups the wireframe content into distinct scene blocks
 * that can then be individually parsed for metadata and elements.
 *
 * @param wireframeText - The complete wireframe input string
 * @returns Array of scene block strings
 *
 * Example:
 * ```
 * @scene: login
 * +--Login--+
 *
 * ---
 *
 * @scene: home
 * +--Home--+
 * ```
 * Returns: ["@scene: login\n+--Login--+", "@scene: home\n+--Home--+"]
 */
let splitSceneBlocks = (wireframeText: string): array<string> => {
  let lines = wireframeText->String.split("\n")
  let blocks = []
  let currentBlock = ref([])

  lines->Array.forEach(line => {
    let trimmed = line->String.trim

    // Check for scene separator "---"
    if trimmed === "---" {
      // Finish current block if it has content
      if currentBlock.contents->Array.length > 0 {
        blocks->Array.push(currentBlock.contents->Array.join("\n"))
        currentBlock := []
      }
    } else if trimmed->String.startsWith("@scene:") && currentBlock.contents->Array.length > 0 {
      // New scene directive - finish previous block
      blocks->Array.push(currentBlock.contents->Array.join("\n"))
      currentBlock := [line]
    } else {
      // Regular content line - add to current block
      currentBlock := currentBlock.contents->Array.concat([line])
    }
  })

  // Add final block if it has content
  if currentBlock.contents->Array.length > 0 {
    blocks->Array.push(currentBlock.contents->Array.join("\n"))
  }

  // Filter out empty blocks
  blocks->Array.filter(block => block->String.trim !== "")
}

/**
 * Group content lines by scene boundaries.
 *
 * This is the main function for scene directive parsing that:
 * 1. Splits input into scene blocks
 * 2. Parses directives from each block
 * 3. Returns metadata and content for each scene
 *
 * If no scene blocks are found, creates a single default scene
 * with all content.
 *
 * @param wireframeText - Complete wireframe input
 * @returns Array of tuples (metadata, contentLines) for each scene
 *
 * Example:
 * ```
 * @scene: login
 * @title: Login
 * +--Login--+
 * ```
 * Returns: [({id: "login", title: "Login", transition: "fade"}, ["+--Login--+"])]
 */
let groupContentByScenes = (wireframeText: string): array<(sceneMetadata, array<string>)> => {
  let blocks = splitSceneBlocks(wireframeText)

  // If no blocks found, create default scene with all content
  if blocks->Array.length === 0 {
    let trimmed = wireframeText->String.trim
    if trimmed !== "" {
      [(defaultSceneMetadata(), [wireframeText])]
    } else {
      []
    }
  } else {
    // Parse each block into metadata and content
    blocks->Array.map(block => {
      let lines = block->String.split("\n")
      parseSceneDirectives(lines)
    })
  }
}

// ============================================================================
// Box Content Extraction (continued)
// ============================================================================

/**
 * Check if a column is within any child box's horizontal bounds for a given row.
 * Returns true if the column falls inside a child box at the specified row.
 */
let isWithinChildBox = (row: int, col: int, children: array<box>): bool => {
  children->Array.some(child => {
    let b = child.bounds
    // Check if position is within child box bounds (including borders)
    row >= b.top && row <= b.bottom && col >= b.left && col <= b.right
  })
}

/**
 * Check if a row intersects with any child box.
 * Returns true if the row passes through a child box.
 */
let rowIntersectsChildBox = (row: int, children: array<box>): bool => {
  children->Array.some(child => {
    let b = child.bounds
    row >= b.top && row <= b.bottom
  })
}

/**
 * Extracts content lines from within a box's bounds, excluding child box regions.
 *
 * This function:
 * - Excludes the top border line (row at bounds.top)
 * - Excludes the bottom border line (row at bounds.bottom)
 * - Extracts content from rows between top and bottom
 * - Removes the left and right border characters ('|') from each line
 * - SKIPS regions covered by child boxes to avoid duplicate content
 * - Preserves all internal whitespace
 *
 * @param box - The box to extract content from
 * @param gridCells - The 2D array of grid cells
 * @returns Array of content lines (strings) without borders
 *
 * Example:
 * ```
 * +--Login--+
 * |  #email |
 * | [Submit]|
 * +---------+
 * ```
 * Returns: ["  #email ", " [Submit]"]
 */
let extractContentLines = (box: box, gridCells: array<array<cellChar>>): array<string> => {
  let bounds = box.bounds
  let children = box.children

  // Calculate content rows (exclude top and bottom borders)
  let contentStartRow = bounds.top + 1
  let contentEndRow = bounds.bottom - 1

  // If box has no content area (height <= 2), return empty array
  if contentStartRow > contentEndRow {
    []
  } else {
    // Build array of content lines
    let contentLines = []
    let gridHeight = Array.length(gridCells)

    for row in contentStartRow to contentEndRow {
      // Skip rows that are entirely within child boxes
      // (rows where the entire content area is covered by children)
      let rowCoveredByChild = children->Array.some(child => {
        let b = child.bounds
        // Row is completely covered if it's within child's vertical bounds
        // AND child spans the entire parent content width
        row >= b.top && row <= b.bottom &&
        b.left <= bounds.left + 1 && b.right >= bounds.right - 1
      })

      if !rowCoveredByChild && row >= 0 && row < gridHeight {
        // Get the row from the grid
        switch gridCells[row] {
        | Some(rowCells) => {
            // Check if this row starts with a Corner (section header pattern)
            // In this case, include the corner in the content
            let leftBorderCell = rowCells->Array.get(bounds.left)
            let startsWithCorner = switch leftBorderCell {
            | Some(Corner) => true
            | _ => false
            }

            // Determine content column range
            // If row starts with Corner, include it (section header)
            // Otherwise, skip the left border as usual
            let contentStartCol = if startsWithCorner {
              bounds.left  // Include the '+' at the left edge
            } else {
              bounds.left + 1  // Skip the '|' border
            }
            let contentEndCol = bounds.right - 1

            // Extract characters between borders, skipping child box regions
            let lineChars = []

            for col in contentStartCol to contentEndCol {
              // Skip columns that are within child boxes at this row
              if !isWithinChildBox(row, col, children) {
                if col >= 0 && col < Array.length(rowCells) {
                  let cell = rowCells->Array.getUnsafe(col)
                  switch cell {
                  | Char(c) => lineChars->Array.push(c)
                  | Space => lineChars->Array.push(" ")
                  | VLine => lineChars->Array.push("|")
                  | HLine => lineChars->Array.push("-")
                  | Corner => lineChars->Array.push("+")
                  | Divider => lineChars->Array.push("=")
                  }
                }
              }
            }

            // Convert character array to string
            let line = lineChars->Array.join("")
            contentLines->Array.push(line)
          }
        | None => ()
        }
      }
    }

    contentLines
  }
}

// ============================================================================
// Element Recognition Pipeline
// ============================================================================

/**
 * Inline element segment type.
 * Represents a piece of content that may be text or a special element.
 * Includes column offset for position-based alignment calculation.
 */
type inlineSegment =
  | TextSegment(string, int)   // (text, column offset within line)
  | ButtonSegment(string, int) // (text inside [ ], column offset)
  | LinkSegment(string, int)   // (text inside " ", column offset)

/**
 * Split a content line into inline segments with position information.
 * Handles mixed content like "Dashboard      [ Logout ]" -> [TextSegment("Dashboard", 0), ButtonSegment("Logout", 15)]
 *
 * Pattern recognition:
 * - [ Text ] -> ButtonSegment with column offset
 * - Other text -> TextSegment with column offset
 *
 * @param line - The content line to split
 * @returns Array of inline segments with column offsets
 */
/**
 * Check if content inside brackets is a checkbox pattern.
 * Checkbox patterns: "x", "X", " " (single character only)
 */
let isCheckboxContent = (content: string): bool => {
  let trimmed = content->String.trim
  let lowerContent = trimmed->String.toLowerCase
  // [x] or [X] - checked checkbox
  // [ ] - unchecked checkbox (empty or just whitespace)
  lowerContent === "x" || trimmed === ""
}

let splitInlineSegments = (line: string): array<inlineSegment> => {
  let segments = []
  let currentText = ref("")
  let currentTextStart = ref(0)
  let i = ref(0)
  let len = line->String.length

  while i.contents < len {
    let char = line->String.charAt(i.contents)

    // Check for button pattern [ ... ]
    if char === "[" {
      // Find matching ]
      let buttonStart = i.contents
      let start = i.contents + 1
      let endPos = ref(None)
      let j = ref(start)
      while j.contents < len && endPos.contents === None {
        if line->String.charAt(j.contents) === "]" {
          endPos := Some(j.contents)
        }
        j := j.contents + 1
      }

      switch endPos.contents {
      | Some(end) => {
          let bracketContent = line->String.slice(~start, ~end)

          // Check if this is a checkbox pattern [x], [X], or [ ]
          // If so, treat the whole thing as text, not a button
          if isCheckboxContent(bracketContent) {
            // Include the brackets in text accumulation
            if currentText.contents === "" {
              currentTextStart := i.contents
            }
            // Add the entire checkbox pattern to current text
            let checkboxText = "[" ++ bracketContent ++ "]"
            currentText := currentText.contents ++ checkboxText
            i := end + 1
          } else {
            // This is a button pattern
            // Flush any accumulated text
            let text = currentText.contents->String.trim
            if text !== "" {
              // Find actual start position (skip leading whitespace)
              let leadingSpaces = String.length(currentText.contents) - String.length(currentText.contents->String.trimStart)
              segments->Array.push(TextSegment(text, currentTextStart.contents + leadingSpaces))->ignore
            }
            currentText := ""

            let buttonText = bracketContent->String.trim
            if buttonText !== "" {
              segments->Array.push(ButtonSegment(buttonText, buttonStart))->ignore
            }
            i := end + 1
            currentTextStart := i.contents
          }
        }
      | None => {
          // No matching ], treat as regular text
          if currentText.contents === "" {
            currentTextStart := i.contents
          }
          currentText := currentText.contents ++ char
          i := i.contents + 1
        }
      }
    } else if char === "\"" {
      // Check for link pattern "..."
      let linkStart = i.contents
      let start = i.contents + 1
      let endPos = ref(None)
      let j = ref(start)
      // Find matching closing quote, handling escaped quotes
      while j.contents < len && endPos.contents === None {
        let currentChar = line->String.charAt(j.contents)
        if currentChar === "\"" {
          // Check if this quote is escaped (preceded by backslash)
          let isEscaped = j.contents > start && line->String.charAt(j.contents - 1) === "\\"
          if !isEscaped {
            endPos := Some(j.contents)
          }
        }
        j := j.contents + 1
      }

      switch endPos.contents {
      | Some(end) => {
          let quotedContent = line->String.slice(~start, ~end)
          let trimmedContent = quotedContent->String.trim

          // Check if the quoted content is not empty
          if trimmedContent !== "" {
            // Flush any accumulated text before the link
            let text = currentText.contents->String.trim
            if text !== "" {
              let leadingSpaces = String.length(currentText.contents) - String.length(currentText.contents->String.trimStart)
              segments->Array.push(TextSegment(text, currentTextStart.contents + leadingSpaces))->ignore
            }
            currentText := ""

            // Add the link segment
            segments->Array.push(LinkSegment(trimmedContent, linkStart))->ignore
            i := end + 1
            currentTextStart := i.contents
          } else {
            // Empty quoted content, treat as regular text
            if currentText.contents === "" {
              currentTextStart := i.contents
            }
            currentText := currentText.contents ++ char
            i := i.contents + 1
          }
        }
      | None => {
          // No matching closing quote, treat as regular text
          if currentText.contents === "" {
            currentTextStart := i.contents
          }
          currentText := currentText.contents ++ char
          i := i.contents + 1
        }
      }
    } else {
      // Regular character
      if currentText.contents === "" {
        currentTextStart := i.contents
      }
      currentText := currentText.contents ++ char
      i := i.contents + 1
    }
  }

  // Flush remaining text
  let text = currentText.contents->String.trim
  if text !== "" {
    let leadingSpaces = String.length(currentText.contents) - String.length(currentText.contents->String.trimStart)
    segments->Array.push(TextSegment(text, currentTextStart.contents + leadingSpaces))->ignore
  }

  segments
}

/**
 * Check if a line contains inline elements (buttons, links mixed with text).
 * Returns true if the line has multiple segments or a single non-text segment.
 */
let hasInlineElements = (line: string): bool => {
  let segments = splitInlineSegments(line)
  // Has inline elements if:
  // 1. More than one segment
  // 2. Or single segment that is not text
  if segments->Array.length > 1 {
    true
  } else {
    switch segments->Array.get(0) {
    | Some(TextSegment(_, _)) => false
    | Some(ButtonSegment(_, _)) => true
    | Some(LinkSegment(_, _)) => true
    | None => false
    }
  }
}

/**
 * Check if a line is a divider (consists of '=' characters).
 *
 * Dividers act as section separators within boxes.
 * A line is considered a divider if it consists primarily of '=' characters.
 *
 * @param line - The content line to check
 * @returns true if this is a divider line
 */
let isDividerLine = (line: string): bool => {
  let trimmed = line->String.trim
  // Check if the line consists only of '=' characters (at least 3)
  // Also match +===+ or +===  patterns (divider with corners, trailing + may be cut off)
  let pureEqualsPattern = %re("/^=+$/")
  let cornerDividerPattern = %re("/^\+=+\+?$/")  // Optional trailing +
  let length = trimmed->String.length
  length >= 3 && (Js.Re.test_(pureEqualsPattern, trimmed) || Js.Re.test_(cornerDividerPattern, trimmed))
}

/**
 * Check if a line is a section header pattern.
 * Matches patterns like:
 * - "+--Name--+" (full section header)
 * - "--Name--+" (left edge shared with outer box)
 * - "+--Name--" (right edge shared with outer box)
 * - "--Name--" (both edges shared)
 *
 * @param line - The content line to check
 * @returns Option containing section name if this is a section header
 */
let extractSectionName = (line: string): option<string> => {
  let trimmed = line->String.trim

  // Pattern: +--Name--+ or --Name--+ or +--Name-- or --Name--
  // Must contain at least -- on each side of the name
  // Allow optional trailing space or characters after the closing +
  let sectionPattern = %re("/^\+?-{2,}([^-+]+)-{2,}\+?\s*$/")

  switch Js.Re.exec_(sectionPattern, trimmed) {
  | Some(result) => {
      // Get the captured group (the name)
      switch Js.Re.captures(result)->Array.get(1) {
      | Some(Js.Nullable.Value(name)) => {
          let cleanName = name->String.trim
          if cleanName !== "" {
            Some(cleanName)
          } else {
            None
          }
        }
      | _ => None
      }
    }
  | None => None
  }
}

/**
 * Check if a line is a section footer (closing border).
 * Matches patterns like:
 * - "+-------+" (full footer)
 * - "--------+" (left edge shared)
 * - "+--------" (right edge shared)
 * - "--------" (both edges shared)
 *
 * @param line - The content line to check
 * @returns true if this is a section footer
 */
let isSectionFooter = (line: string): bool => {
  let trimmed = line->String.trim
  // Pattern: only + and - characters, at least 3 dashes
  // Allow optional trailing space
  let footerPattern = %re("/^\+?-{3,}\+?\s*$/")
  Js.Re.test_(footerPattern, trimmed)
}

/**
 * Strip section borders from a content line.
 * Section content lines often have their own | borders that need to be removed.
 * Handles patterns like "| Content |" or "| Content"
 *
 * @param line - The content line to strip
 * @returns The line with leading/trailing | borders removed
 */
let stripSectionBorders = (line: string): string => {
  let trimmed = line->String.trim

  // Remove leading "| " or "|"
  let withoutLeading = if String.startsWith(trimmed, "| ") {
    String.sliceToEnd(trimmed, ~start=2)
  } else if String.startsWith(trimmed, "|") {
    String.sliceToEnd(trimmed, ~start=1)
  } else {
    trimmed
  }

  // Remove trailing " |" or "|"
  let result = if String.endsWith(withoutLeading, " |") {
    String.slice(withoutLeading, ~start=0, ~end=String.length(withoutLeading) - 2)
  } else if String.endsWith(withoutLeading, "|") {
    String.slice(withoutLeading, ~start=0, ~end=String.length(withoutLeading) - 1)
  } else {
    withoutLeading
  }

  result
}

/**
 * Parse elements from box content lines using the parser registry.
 *
 * Algorithm:
 * 1. Extract content lines from box
 * 2. Iterate through each content line
 * 3. Detect dividers as section separators
 * 4. Calculate line position in grid (with column offset for alignment)
 * 5. Call registry.parse to recognize element type
 * 6. Collect all parsed elements
 *
 * Divider Handling:
 * - Lines consisting only of '===' are treated as dividers
 * - Dividers create Divider elements in the output
 * - Dividers act as visual section separators in the UI
 *
 * @param box - The box containing elements
 * @param gridCells - The 2D array of grid cells
 * @param registry - The parser registry for element recognition
 * @returns Array of parsed elements
 *
 * Requirements: REQ-15 (Element parsing and AST generation)
 */
/**
 * Convert inline segment to element.
 * Creates appropriate element type based on segment variant.
 * Uses the segment's column offset for accurate position-based alignment.
 */
let segmentToElement = (
  segment: inlineSegment,
  basePosition: Position.t,
  baseCol: int,
  bounds: Bounds.t,
): element => {
  switch segment {
  | TextSegment(text, colOffset) => {
      // Calculate actual position using segment's column offset
      let actualCol = baseCol + colOffset
      let position = Position.make(basePosition.row, actualCol)

      // Calculate alignment based on actual position within bounds
      let align = AlignmentCalc.calculateWithStrategy(
        text,
        position,
        bounds,
        AlignmentCalc.RespectPosition,
      )
      Text({
        content: text,
        position: position,
        emphasis: false,
        align: align,
      })
    }
  | ButtonSegment(text, colOffset) => {
      // Calculate actual position using segment's column offset
      let actualCol = baseCol + colOffset
      let position = Position.make(basePosition.row, actualCol)

      // Create button ID from text (slugified)
      // Use String.replaceRegExp (modern API) to avoid escaping issues with %re
      let id = text
        ->String.trim
        ->String.toLowerCase
        ->String.replaceRegExp(%re("/\s+/g"), "-")
        ->String.replaceRegExp(%re("/[^a-z0-9-]/g"), "")
        ->String.replaceRegExp(%re("/-+/g"), "-")
        ->String.replaceRegExp(%re("/^-+|-+$/g"), "")

      // Use "[ text ]" format (with spaces) to match visual button width for alignment
      let buttonContent = "[ " ++ text ++ " ]"
      let align = AlignmentCalc.calculateWithStrategy(
        buttonContent,
        position,
        bounds,
        AlignmentCalc.RespectPosition,
      )
      Button({
        id: id,
        text: text,
        position: position,
        align: align,
        actions: [],
      })
    }
  | LinkSegment(text, colOffset) => {
      // Calculate actual position using segment's column offset
      let actualCol = baseCol + colOffset
      let position = Position.make(basePosition.row, actualCol)

      // Use the same slugify logic as LinkParser for consistent ID generation
      // Use String.replaceRegExp (modern API) to avoid escaping issues with %re
      let id = text
        ->String.trim
        ->String.toLowerCase
        ->String.replaceRegExp(%re("/\s+/g"), "-")
        ->String.replaceRegExp(%re("/[^a-z0-9-]/g"), "")
        ->String.replaceRegExp(%re("/-+/g"), "-")
        ->String.replaceRegExp(%re("/^-+|-+$/g"), "")

      let align = AlignmentCalc.calculateWithStrategy(
        text,
        position,
        bounds,
        AlignmentCalc.RespectPosition,
      )
      Link({
        id: id,
        text: text,
        position: position,
        align: align,
        actions: [],
      })
    }
  }
}

/**
 * Parse a single content line into an element.
 * Handles buttons, links, inline elements, and regular text.
 */
let parseContentLine = (
  line: string,
  lineIndex: int,
  contentStartRow: int,
  box: box,
  registry: ParserRegistry.t,
): option<element> => {
  let trimmed = line->String.trim

  // Issue #16: Preserve empty lines as spacer elements for vertical spacing
  if trimmed === "" {
    // Calculate position for the empty line
    let row = contentStartRow + lineIndex
    let baseCol = box.bounds.left + 1
    let position = Position.make(row, baseCol)

    // Create a Text element with empty content to act as a vertical spacer
    Some(Text({
      content: "",
      emphasis: false,
      position: position,
      align: Left,
    }))
  } else {
    // Calculate position in grid
    let row = contentStartRow + lineIndex

    // Calculate base column (content starts after left border)
    let baseCol = box.bounds.left + 1

    let basePosition = Position.make(row, baseCol)

    // Check for inline elements (mixed content like "Dashboard [ Logout ]")
    let segments = splitInlineSegments(trimmed)

    if segments->Array.length > 1 {
      // Multiple segments - create a Row with all elements
      // Each segment has its own column offset for correct alignment calculation
      let rowChildren = segments->Array.map(segment => {
        segmentToElement(segment, basePosition, baseCol, box.bounds)
      })
      Some(Row({
        children: rowChildren,
        align: Left,
      }))
    } else if segments->Array.length === 1 {
      // Single segment - check if it's a special element
      // Need to account for leading spaces from the original line since
      // splitInlineSegments operates on the trimmed string
      let leadingSpaces = {
        let original = line
        let trimmedStart = original->String.trimStart
        original->String.length - trimmedStart->String.length
      }

      switch segments->Array.get(0) {
      | Some(ButtonSegment(text, colOffset)) => {
          // Add leading spaces to colOffset for correct position calculation
          let actualCol = baseCol + leadingSpaces + colOffset
          let position = Position.make(row, actualCol)
          // Use "[ text ]" format (with spaces) to match visual button width
          let buttonContent = "[ " ++ text ++ " ]"
          Some(registry->ParserRegistry.parse(buttonContent, position, box.bounds))
        }
      | Some(LinkSegment(text, colOffset)) => {
          // For single LinkSegment, pass through to ParserRegistry to use LinkParser's slugify
          let actualCol = baseCol + leadingSpaces + colOffset
          let position = Position.make(row, actualCol)
          // Reconstruct the quoted text format for the parser
          let linkContent = "\"" ++ text ++ "\""
          Some(registry->ParserRegistry.parse(linkContent, position, box.bounds))
        }
      | Some(TextSegment(_, _)) | None => {
          // For single text segment, use original position calculation
          let position = Position.make(row, baseCol + leadingSpaces)
          Some(registry->ParserRegistry.parse(trimmed, position, box.bounds))
        }
      }
    } else {
      let leadingSpaces = {
        let original = line
        let trimmedStart = original->String.trimStart
        original->String.length - trimmedStart->String.length
      }
      let position = Position.make(row, baseCol + leadingSpaces)
      Some(registry->ParserRegistry.parse(trimmed, position, box.bounds))
    }
  }
}

let parseBoxContent = (
  box: box,
  gridCells: array<array<cellChar>>,
  registry: ParserRegistry.t,
): array<element> => {
  let contentLines = extractContentLines(box, gridCells)
  let elements = []

  // Calculate starting row for content (first row inside box border)
  let contentStartRow = box.bounds.top + 1

  // State for section parsing
  let currentSection = ref(None) // (name, startIndex, contentLines)
  let i = ref(0)

  while i.contents < contentLines->Array.length {
    let lineOpt = contentLines->Array.get(i.contents)
    switch lineOpt {
    | None => i := i.contents + 1
    | Some(line) => {
        let lineIndex = i.contents

        // Check if this line is a divider
        if isDividerLine(line) {
          let row = contentStartRow + lineIndex
          let col = box.bounds.left + 1
          elements->Array.push(Divider({position: Position.make(row, col)}))->ignore
          i := i.contents + 1
        } else {
          // Check for section header pattern
          switch extractSectionName(line) {
          | Some(sectionName) => {
              // Start a new section - collect lines until footer
              let sectionContent = []
              i := i.contents + 1

              // Collect content until section footer or end of lines
              let foundFooter = ref(false)
              while i.contents < contentLines->Array.length && !foundFooter.contents {
                switch contentLines->Array.get(i.contents) {
                | Some(contentLine) => {
                    if isSectionFooter(contentLine) {
                      foundFooter := true
                      i := i.contents + 1
                    } else {
                      sectionContent->Array.push((contentLine, i.contents))->ignore
                      i := i.contents + 1
                    }
                  }
                | None => i := i.contents + 1
                }
              }

              // Parse section content into elements
              let sectionElements = []
              sectionContent->Array.forEach(((contentLine, contentLineIndex)) => {
                // Strip section borders (| characters) before parsing
                let strippedLine = stripSectionBorders(contentLine)
                switch parseContentLine(strippedLine, contentLineIndex, contentStartRow, box, registry) {
                | Some(elem) => sectionElements->Array.push(elem)->ignore
                | None => ()
                }
              })

              // Create Section element
              let sectionElement = Section({
                name: sectionName,
                children: sectionElements,
              })
              elements->Array.push(sectionElement)->ignore
            }
          | None => {
              // Not a section header - check for section footer (without header)
              if isSectionFooter(line) {
                // Skip orphan footer
                i := i.contents + 1
              } else {
                // Regular content line
                switch parseContentLine(line, lineIndex, contentStartRow, box, registry) {
                | Some(elem) => elements->Array.push(elem)->ignore
                | None => ()
                }
                i := i.contents + 1
              }
            }
          }
        }
      }
    }
  }

  // Handle any remaining section
  switch currentSection.contents {
  | Some((name, _, sectionLines)) => {
      let sectionElements = []
      sectionLines->Array.forEach(((contentLine, contentLineIndex)) => {
        // Strip section borders (| characters) before parsing
        let strippedLine = stripSectionBorders(contentLine)
        switch parseContentLine(strippedLine, contentLineIndex, contentStartRow, box, registry) {
        | Some(elem) => sectionElements->Array.push(elem)->ignore
        | None => ()
        }
      })
      elements->Array.push(Section({name: name, children: sectionElements}))->ignore
    }
  | None => ()
  }

  elements
}

/**
 * Get the column position of a Box element.
 */
let getBoxColumn = (elem: element): int => {
  switch elem {
  | Box({bounds, _}) => bounds.left
  | _ => 0
  }
}

/**
 * Group horizontally aligned box elements into Row elements.
 *
 * Boxes are considered horizontally aligned if they share the same top row.
 * Single boxes are returned as-is, while groups of 2+ are wrapped in a Row.
 *
 * @param elements - Array of elements (should be Box elements)
 * @returns Array of elements with horizontal boxes wrapped in Rows
 */
let groupHorizontalBoxes = (elements: array<element>): array<element> => {
  // Only process Box elements - separate them from non-boxes
  let boxes = elements->Array.filter(el =>
    switch el {
    | Box(_) => true
    | _ => false
    }
  )
  let nonBoxes = elements->Array.filter(el =>
    switch el {
    | Box(_) => false
    | _ => true
    }
  )

  // If no boxes or only one box, return as-is
  if Array.length(boxes) <= 1 {
    elements
  } else {
    // Group boxes by their top row
    let boxesWithRow = boxes->Array.map(box => {
      let row = switch box {
      | Box({bounds, _}) => bounds.top
      | _ => 0
      }
      (row, box)
    })

    // Sort by row first, then by column within same row
    let sorted = boxesWithRow->Array.toSorted(((rowA, boxA), (rowB, boxB)) => {
      if rowA !== rowB {
        Float.fromInt(rowA - rowB)
      } else {
        Float.fromInt(getBoxColumn(boxA) - getBoxColumn(boxB))
      }
    })

    // Group boxes by row
    let groups: array<(int, array<element>)> = []
    sorted->Array.forEach(((row, box)) => {
      // Find if there's already a group for this row
      let existingGroupIdx = groups->Array.findIndex(((groupRow, _)) => groupRow === row)
      if existingGroupIdx >= 0 {
        // Add to existing group
        switch groups->Array.get(existingGroupIdx) {
        | Some((_, groupBoxes)) => {
            groupBoxes->Array.push(box)
          }
        | None => ()
        }
      } else {
        // Create new group
        groups->Array.push((row, [box]))
      }
    })

    // Convert groups to elements
    let groupedElements = groups->Array.map(((_, groupBoxes)) => {
      if Array.length(groupBoxes) >= 2 {
        // Wrap multiple boxes in a Row
        Row({
          children: groupBoxes,
          align: Left, // Default alignment
        })
      } else {
        // Single box, return as-is
        groupBoxes->Array.getUnsafe(0)
      }
    })

    // Combine non-boxes with grouped elements
    Array.concat(nonBoxes, groupedElements)
  }
}

/**
 * Get the row position of an element for sorting purposes.
 */
let rec getElementRow = (elem: element): int => {
  switch elem {
  | Box({bounds, _}) => bounds.top
  | Button({position, _}) => position.row
  | Input({position, _}) => position.row
  | Link({position, _}) => position.row
  | Checkbox({position, _}) => position.row
  | Text({position, _}) => position.row
  | Divider({position}) => position.row
  | Row({children, _}) => {
      // Use the first child's row position
      switch children->Array.get(0) {
      | Some(child) => getElementRow(child)
      | None => 0
      }
    }
  | Section({children, _}) => {
      // Use the first child's row position, or high value if empty
      switch children->Array.get(0) {
      | Some(child) => getElementRow(child)
      | None => Int.Constants.maxValue // Empty sections sort last
      }
    }
  }
}

/**
 * Recursively parse a box and all its children into elements.
 *
 * This function:
 * 1. Parses the content of the current box
 * 2. Recursively parses all child boxes
 * 3. SORTS all elements by their row position to preserve visual order
 * 4. Creates a Box element containing all parsed children
 *
 * @param box - The box to parse
 * @param gridCells - The 2D array of grid cells
 * @param registry - The parser registry
 * @returns A Box element with all children
 *
 * Requirements: REQ-15, REQ-6 (Hierarchy reflection in AST)
 */
let rec parseBoxRecursive = (
  box: box,
  gridCells: array<array<cellChar>>,
  registry: ParserRegistry.t,
): element => {
  // Parse immediate content of this box
  let contentElements = parseBoxContent(box, gridCells, registry)

  // Recursively parse child boxes
  let childBoxElements = box.children->Array.map(childBox => {
    parseBoxRecursive(childBox, gridCells, registry)
  })

  // Group horizontally aligned child boxes into Row elements
  let groupedChildElements = groupHorizontalBoxes(childBoxElements)

  // Combine content elements and grouped child boxes
  let allChildren = Array.concat(contentElements, groupedChildElements)

  // Sort elements by their row position to preserve visual order
  let sortedChildren = allChildren->Array.toSorted((a, b) => {
    let rowA = getElementRow(a)
    let rowB = getElementRow(b)
    Float.fromInt(rowA - rowB)
  })

  // Create Box element
  Box({
    name: box.name,
    bounds: box.bounds,
    children: sortedChildren,
  })
}

// ============================================================================
// AST Builder
// ============================================================================

/**
 * Build a scene from metadata and parsed elements.
 *
 * @param metadata - Scene metadata (id, title, transition)
 * @param elements - Array of parsed elements in the scene
 * @returns A complete scene record
 *
 * Requirements: REQ-15 (Scene structure in AST)
 */
let buildScene = (metadata: sceneMetadata, elements: array<element>): scene => {
  {
    id: metadata.id,
    title: metadata.title,
    transition: metadata.transition,
    device: metadata.device,
    elements: elements,
  }
}

/**
 * Build complete AST from array of scenes.
 *
 * @param scenes - Array of parsed scenes
 * @returns Complete AST with scenes array
 *
 * Requirements: REQ-15 (AST root structure)
 */
let buildAST = (scenes: array<scene>): ast => {
  {
    scenes: scenes,
  }
}

// ============================================================================
// Main Parse Function
// ============================================================================

/**
 * Parse context containing all inputs needed for semantic parsing.
 */
type parseContext = {
  gridCells: array<array<cellChar>>,
  shapes: array<box>,
  registry: ParserRegistry.t,
}

/**
 * Parse result: either an AST or a list of errors.
 */
type parseResult = result<ast, array<ErrorTypes.t>>

/**
 * Main semantic parsing function.
 *
 * This function integrates all parsing stages:
 * 1. Groups shapes by scene (using scene directives if present)
 * 2. Parses content from each box
 * 3. Recognizes elements using the parser registry
 * 4. Builds complete AST with scenes
 * 5. Collects all errors encountered during parsing
 *
 * Algorithm:
 * - Accept gridCells, shapes, and registry as input
 * - For each shape (root box):
 *   - Parse box content recursively
 *   - Build scene with metadata
 * - Combine all scenes into AST
 * - Return Result with AST or errors
 *
 * @param context - Parse context containing grid cells, shapes, and registry
 * @returns Result<ast, errors> - Either complete AST or array of parse errors
 *
 * Requirements: REQ-15 (Complete AST generation)
 */
let parse = (context: parseContext): parseResult => {
  let errors = []

  // If no shapes, return empty AST
  if context.shapes->Array.length === 0 {
    Ok(buildAST([]))
  } else {

  // Parse each root-level box into a scene
  let scenes = context.shapes->Array.map(box => {
    // Parse box recursively to get all elements
    let boxElement = parseBoxRecursive(box, context.gridCells, context.registry)

    // Extract children from the box element
    let elements = switch boxElement {
    | Box({children, _}) => children
    | _ => [] // Should never happen for root boxes
    }

    // Create scene metadata
    // For now, we use the box name as scene ID if available
    let metadata = switch box.name {
    | Some(name) => {
        id: name,
        title: name,
        transition: "fade",
        device: Desktop,
      }
    | None => defaultSceneMetadata()
    }

    // Build scene
    buildScene(metadata, elements)
  })

  // Build complete AST
  let ast = buildAST(scenes)

  // Return result
  if errors->Array.length > 0 {
    Error(errors)
  } else {
    Ok(ast)
  }
  }
}

/**
 * Parse wireframe text with scene directives.
 *
 * This is a higher-level function that:
 * 1. Splits input by scene directives
 * 2. Parses each scene separately
 * 3. Combines into complete AST
 *
 * Note: This function assumes the grid and shapes have already been
 * extracted. For complete wireframe parsing, use WyreframeParser module.
 *
 * @param wireframeText - Raw wireframe text with scene directives
 * @param context - Parse context
 * @returns Result with complete AST or errors
 */
let parseWithSceneDirectives = (
  wireframeText: string,
  context: parseContext,
): parseResult => {
  // Group content by scene directives
  let sceneGroups = groupContentByScenes(wireframeText)

  // For each scene group, find matching shapes and parse
  let scenes = sceneGroups->Array.map(((metadata, _contentLines)) => {
    // For now, parse all shapes into this scene
    // TODO: In future, match shapes to scene boundaries
    let elements = context.shapes->Array.map(box => {
      parseBoxRecursive(box, context.gridCells, context.registry)
    })

    buildScene(metadata, elements)
  })

  // Build AST
  let ast = buildAST(scenes)
  Ok(ast)
}
