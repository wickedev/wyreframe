// TextExtractor.res
// Intelligent extraction of wireframe and interaction content from mixed text
// Supports markdown, comments, and other noise in the input

// ============================================================================
// Pattern Detection
// ============================================================================

/**
 * Check if a line is part of an ASCII wireframe.
 * Matches: +---+, |...|, +===+, box borders
 */
let isWireframeLine = (line: string): bool => {
  let trimmed = line->String.trim

  // Empty lines within wireframe context are preserved
  if trimmed === "" {
    false // Will be handled by context
  } else {
    // Box top/bottom border: +---+ or +===+
    let boxBorder = %re("/^\+[-=]+\+/")
    // Box side with content: | ... |
    let boxSide = %re("/^\|.*\|$/")
    // Named box border: +--Name--+
    let namedBorder = %re("/^\+--[^-].*--\+/")
    // Partial box patterns (for multi-line detection)
    let startsWithPlus = trimmed->String.startsWith("+")
    let startsWithPipe = trimmed->String.startsWith("|")

    Js.Re.test_(boxBorder, trimmed) ||
    Js.Re.test_(boxSide, trimmed) ||
    Js.Re.test_(namedBorder, trimmed) ||
    (startsWithPlus && trimmed->String.includes("-")) ||
    (startsWithPipe && trimmed->String.endsWith("|"))
  }
}

/**
 * Check if a line is a scene/title/device directive.
 * Matches: @scene:, @title:, @device:, @transition:
 */
let isDirectiveLine = (line: string): bool => {
  let trimmed = line->String.trim
  trimmed->String.startsWith("@scene:") ||
  trimmed->String.startsWith("@title:") ||
  trimmed->String.startsWith("@device:") ||
  trimmed->String.startsWith("@transition:")
}

/**
 * Check if a line is a scene separator.
 */
let isSceneSeparator = (line: string): bool => {
  line->String.trim === "---"
}

/**
 * Check if a line starts an interaction block.
 * Matches: #id:, [Button]:, "Link":
 */
let isInteractionSelector = (line: string): bool => {
  let trimmed = line->String.trim

  // Input selector: #email:
  let inputSelector = %re("/^#[\w-]+:$/")
  // Button selector: [Button Text]:
  let buttonSelector = %re("/^\[.+\]:$/")
  // Link selector: "Link Text":
  let linkSelector = %re("/^\"[^\"]+\":$/")

  Js.Re.test_(inputSelector, trimmed) ||
  Js.Re.test_(buttonSelector, trimmed) ||
  Js.Re.test_(linkSelector, trimmed)
}

/**
 * Check if a line is an indented interaction property.
 * Matches: lines starting with 2+ spaces followed by property
 */
let isInteractionProperty = (line: string): bool => {
  // Must start with whitespace (indentation)
  let hasIndent = line->String.length > 0 &&
    (line->String.startsWith("  ") || line->String.startsWith("\t"))

  if !hasIndent {
    false
  } else {
    let trimmed = line->String.trim
    // Property patterns: key: value, @click -> action
    let propertyPattern = %re("/^[\w@-]+:?\s*(->|\S)/")
    trimmed !== "" && Js.Re.test_(propertyPattern, trimmed)
  }
}

// ============================================================================
// Content Classification
// ============================================================================

type lineType =
  | Wireframe
  | Directive
  | SceneSeparator
  | InteractionSelector
  | InteractionProperty
  | EmptyLine
  | Noise

/**
 * Classify a single line.
 */
let classifyLine = (line: string): lineType => {
  let trimmed = line->String.trim

  if trimmed === "" {
    EmptyLine
  } else if isSceneSeparator(line) {
    SceneSeparator
  } else if isDirectiveLine(line) {
    Directive
  } else if isInteractionSelector(line) {
    InteractionSelector
  } else if isInteractionProperty(line) {
    InteractionProperty
  } else if isWireframeLine(line) {
    Wireframe
  } else {
    Noise
  }
}

// ============================================================================
// Extraction State Machine
// ============================================================================

type extractionContext =
  | Initial
  | InWireframe
  | InInteraction

type extractedContent = {
  wireframe: string,
  interactions: string,
}

/**
 * Extract wireframe and interaction content from mixed text.
 *
 * Algorithm:
 * 1. Process line by line with context awareness
 * 2. Directives and scene separators go to wireframe
 * 3. ASCII box patterns go to wireframe
 * 4. Selector + indented properties go to interactions
 * 5. Empty lines are context-sensitive
 * 6. Everything else is ignored (noise)
 */
let extract = (text: string): extractedContent => {
  let lines = text->String.split("\n")

  let wireframeLines: array<string> = []
  let interactionLines: array<string> = []
  let context = ref(Initial)
  let currentSceneId = ref(None)
  let interactionHasSceneHeader = ref(false)

  lines->Array.forEach(line => {
    let lineType = classifyLine(line)

    switch lineType {
    | SceneSeparator => {
        // Scene separator goes to both
        wireframeLines->Array.push(line)->ignore
        if interactionLines->Array.length > 0 {
          interactionLines->Array.push(line)->ignore
        }
        context := Initial
        interactionHasSceneHeader := false
      }

    | Directive => {
        // Directives go to wireframe
        wireframeLines->Array.push(line)->ignore

        // Track current scene for interactions
        let trimmed = line->String.trim
        if trimmed->String.startsWith("@scene:") {
          let sceneId = trimmed
            ->String.sliceToEnd(~start=7)
            ->String.trim
          currentSceneId := Some(sceneId)
          interactionHasSceneHeader := false
        }

        context := InWireframe
      }

    | Wireframe => {
        wireframeLines->Array.push(line)->ignore
        context := InWireframe
      }

    | InteractionSelector => {
        // Add scene header to interactions if needed
        switch currentSceneId.contents {
        | Some(sceneId) if !interactionHasSceneHeader.contents => {
            interactionLines->Array.push("@scene: " ++ sceneId)->ignore
            interactionLines->Array.push("")->ignore
            interactionHasSceneHeader := true
          }
        | _ => ()
        }

        interactionLines->Array.push(line)->ignore
        context := InInteraction
      }

    | InteractionProperty => {
        // Only add if we're in an interaction context
        if context.contents === InInteraction {
          interactionLines->Array.push(line)->ignore
        }
      }

    | EmptyLine => {
        // Empty lines are context-sensitive
        switch context.contents {
        | InWireframe => wireframeLines->Array.push(line)->ignore
        | InInteraction => interactionLines->Array.push(line)->ignore
        | Initial => () // Ignore leading empty lines
        }
      }

    | Noise => {
        // Ignore noise (markdown, comments, etc.)
        // But preserve empty-like structure in wireframe context
        if context.contents === InWireframe {
          // Check if this might be text content inside a box
          // (text that doesn't match wireframe patterns but is between | |)
          ()
        }
      }
    }
  })

  {
    wireframe: wireframeLines->Array.join("\n"),
    interactions: interactionLines->Array.join("\n")->String.trim,
  }
}

/**
 * Check if text contains any wireframe content.
 */
let hasWireframe = (text: string): bool => {
  let lines = text->String.split("\n")
  lines->Array.some(line => isWireframeLine(line))
}

/**
 * Check if text contains any interaction content.
 */
let hasInteractions = (text: string): bool => {
  let lines = text->String.split("\n")
  lines->Array.some(line => isInteractionSelector(line))
}
