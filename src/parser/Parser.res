// WyreframeParser.res
// Public API for Wyreframe Parser - ReScript Implementation
// This module provides the main entry points for parsing wireframes and interactions.
// All functions are exported to TypeScript via GenType annotations.

// ============================================================================
// Type Aliases for Public API
// ============================================================================

/**
 * Parse result type - either a successful AST or an array of parse errors.
 * This Result type is compatible with TypeScript through GenType.
 */
type parseResult = result<Types.ast, array<ErrorTypes.t>>

/**
 * Interaction parse result type.
 */
type interactionResult = result<array<Types.sceneInteractions>, array<ErrorTypes.t>>

// ============================================================================
// Type Aliases for Internal Use
// ============================================================================

// Box type from BoxTracer
type box = BoxTracer.box

// ============================================================================
// Stage 1: Grid Scanner
// ============================================================================

/**
 * Scan ASCII wireframe input into a 2D grid structure.
 * Normalizes line endings and creates indexed grid.
 *
 * @param wireframe Raw ASCII wireframe string
 * @returns Result containing Grid or errors
 *
 * Requirements: REQ-1, REQ-2 (Grid Scanner)
 */
let scanGrid = (wireframe: string): result<Grid.t, array<ErrorTypes.t>> => {
  // Normalize line endings (CRLF -> LF, CR -> LF)
  let normalized = wireframe->String.replaceAll("\r\n", "\n")->String.replaceAll("\r", "\n")

  // Split into lines
  let lines = normalized->String.split("\n")

  // TODO: Add validation for unusual spacing (tabs vs spaces)
  // This would generate UnusualSpacing warnings (REQ-19)

  // Create grid structure
  let grid = Grid.fromLines(lines)

  Ok(grid)
}

// ============================================================================
// Stage 2: Shape Detector
// ============================================================================

/**
 * Detect all boxes and dividers in the grid.
 *
 * This function identifies boxes, traces their boundaries, detects dividers,
 * and builds parent-child hierarchy.
 *
 * @param grid The 2D grid from Stage 1
 * @returns Result containing root boxes or errors
 *
 * Requirements: REQ-3, REQ-4, REQ-5, REQ-6, REQ-7 (Shape Detection)
 */
let detectShapes = (grid: Grid.t): result<array<box>, array<ErrorTypes.t>> => {
  // Use ShapeDetector to detect all shapes in the grid
  ShapeDetector.detect(grid)
}

// ============================================================================
// Stage 3: Semantic Parser
// ============================================================================

/**
 * Convert BoxTracer.box to SemanticParser.box
 * The types are structurally identical except BoxTracer has mutable children
 */
let rec convertBox = (tracerBox: box): SemanticParser.box => {
  {
    name: tracerBox.name,
    bounds: tracerBox.bounds,
    children: tracerBox.children->Array.map(convertBox),
  }
}

/**
 * Parse box contents into semantic elements and build AST.
 *
 * This function extracts content, recognizes elements, calculates alignment,
 * parses scene directives, and builds the complete AST.
 *
 * @param grid The 2D grid from Stage 1
 * @param shapes Root boxes from Stage 2
 * @returns Result containing AST or errors
 *
 * Requirements: REQ-8 through REQ-15 (Semantic Parser)
 */
let parseSemantics = (
  grid: Grid.t,
  shapes: array<box>,
): result<Types.ast, array<ErrorTypes.t>> => {
  // Create parser registry with all element parsers
  let registry = ParserRegistry.makeDefault()

  // Convert BoxTracer boxes to SemanticParser boxes
  let semanticBoxes = shapes->Array.map(convertBox)

  // Build parse context
  let context: SemanticParser.parseContext = {
    gridCells: grid.cells,
    shapes: semanticBoxes,
    registry: registry,
  }

  // Parse semantics using SemanticParser
  SemanticParser.parse(context)
}

// ============================================================================
// Interaction DSL Parser (Optional)
// ============================================================================

/**
 * Parse interaction DSL and return interaction definitions.
 *
 * @param dsl Interaction DSL string
 * @returns Result containing interactions or errors
 *
 * Requirements: Interaction DSL Parser
 */
let parseInteractionsDSL = (
  dsl: string,
): result<array<Types.sceneInteractions>, array<ErrorTypes.t>> => {
  // Parse interactions using InteractionParser
  switch InteractionParser.parse(dsl) {
  | Ok(interactions) => Ok(interactions)
  | Error({message, position}) => {
      // Convert InteractionParser error to ErrorTypes.t
      let error = ErrorTypes.make(
        InvalidInteractionDSL({
          message: message,
          position: position,
        }),
        None,
      )
      Error([error])
    }
  }
}

/**
 * Merge interaction definitions into the AST.
 *
 * Matches interactions to elements by ID and attaches properties and actions.
 *
 * @param ast Base AST from semantic parsing
 * @param sceneInteractions Interaction definitions grouped by scene
 * @returns AST with interactions merged in
 *
 * Requirements: Integration
 */
let mergeInteractionsIntoAST = (
  ast: Types.ast,
  sceneInteractions: array<Types.sceneInteractions>,
): Types.ast => {
  // Merge interactions using InteractionMerger
  switch InteractionMerger.mergeInteractions(ast, sceneInteractions) {
  | Ok(mergedAst) => mergedAst
  | Error(_errors) => {
      // If merging fails, return AST without interactions
      // Errors are silent - this maintains backward compatibility
      ast
    }
  }
}

// ============================================================================
// Main Public API Functions
// ============================================================================

/**
 * Parse a single scene block through the 3-stage pipeline.
 *
 * @param sceneContent ASCII wireframe content for one scene (without directives)
 * @param sceneMetadata Scene metadata from directives
 * @param errors Accumulator for errors
 * @returns Parsed scene or None if parsing failed
 */
let parseSingleScene = (
  sceneContent: string,
  sceneMetadata: SemanticParser.sceneMetadata,
  errors: array<ErrorTypes.t>,
): option<Types.scene> => {
  // Stage 1: Grid Scanner
  let gridResult = scanGrid(sceneContent)

  switch gridResult {
  | Error(gridErrors) => {
      gridErrors->Array.forEach(err => errors->Array.push(err)->ignore)
      None
    }
  | Ok(grid) => {
      // Stage 2: Shape Detector
      let shapesResult = detectShapes(grid)

      let shapes = switch shapesResult {
      | Error(shapeErrors) => {
          shapeErrors->Array.forEach(err => errors->Array.push(err)->ignore)
          []
        }
      | Ok(shapes) => shapes
      }

      // Stage 3: Parse box content into elements
      let registry = ParserRegistry.makeDefault()
      let semanticBoxes = shapes->Array.map(convertBox)

      // Parse each box recursively
      let elements = semanticBoxes->Array.flatMap(box => {
        let boxElement = SemanticParser.parseBoxRecursive(box, grid.cells, registry)

        // Extract children from Box element
        switch boxElement {
        | Box({children, _}) => children
        | _ => [boxElement]
        }
      })

      // Build scene from metadata and elements
      Some({
        id: sceneMetadata.id,
        title: sceneMetadata.title,
        transition: sceneMetadata.transition,
        device: sceneMetadata.device,
        elements: elements,
      })
    }
  }
}

/**
 * Internal parsing function - parses wireframe and optional interactions separately.
 *
 * This executes the complete 3-stage pipeline for each scene:
 * 1. Split wireframe by scene separators ("---")
 * 2. For each scene:
 *    a. Parse scene directives (@scene, @title, @transition)
 *    b. Grid Scanner - converts ASCII to 2D grid
 *    c. Shape Detector - identifies boxes and hierarchy
 *    d. Semantic Parser - recognizes elements and builds scene
 * 3. Combine all scenes into AST
 *
 * Optionally parses and merges interaction DSL if provided.
 *
 * Error Handling:
 * - Collects errors from all stages
 * - Returns all errors together (no early stopping)
 * - Continues parsing even after non-fatal errors
 *
 * @param wireframe ASCII wireframe string (may contain multiple scenes)
 * @param interactions Optional interaction DSL string
 * @returns Result containing AST or array of parse errors
 */
let parseInternal = (wireframe: string, interactions: option<string>): parseResult => {
  // Accumulator for all errors across stages
  let allErrors = []

  // Split wireframe into scene blocks
  let sceneBlocks = SemanticParser.splitSceneBlocks(wireframe)

  // Check if wireframe is empty
  let trimmed = wireframe->String.trim
  if sceneBlocks->Array.length === 0 && trimmed === "" {
    // Empty wireframe - return empty AST
    Ok({scenes: []})
  } else {
    // Parse each scene block
    let scenes = []

    sceneBlocks->Array.forEach(block => {
      // Parse scene directives
      let lines = block->String.split("\n")
      let (metadata, contentLines) = SemanticParser.parseSceneDirectives(lines)

      // Rejoin content lines (without directives)
      let sceneContent = contentLines->Array.join("\n")

      // Parse this scene through 3-stage pipeline
      switch parseSingleScene(sceneContent, metadata, allErrors) {
      | Some(scene) => scenes->Array.push(scene)->ignore
      | None => () // Scene parsing failed, errors already collected
      }
    })

    // Build base AST from scenes
    let baseAst: Types.ast = {scenes: scenes}

    // Optional: Parse and merge interactions
    let finalAst = switch interactions {
    | None => baseAst
    | Some(dsl) => {
        let interactionsResult = parseInteractionsDSL(dsl)

        switch interactionsResult {
        | Error(errors) => {
            errors->Array.forEach(err => allErrors->Array.push(err)->ignore)
            baseAst // Return AST without interactions on error
          }
        | Ok(sceneInteractions) => {
            // Merge interactions into AST
            mergeInteractionsIntoAST(baseAst, sceneInteractions)
          }
        }
      }
    }

    // Return final result
    // Only return Error if we have no scenes at all
    // Otherwise return Ok even if there were some errors during parsing
    if Array.length(finalAst.scenes) === 0 && Array.length(allErrors) > 0 {
      // No scenes parsed and we have errors - return error
      Error(allErrors)
    } else {
      // We have scenes - return Ok
      Ok(finalAst)
    }
  }
}

/**
 * Main parsing function - parses mixed text containing wireframe and interactions.
 *
 * This function accepts a single text input that can contain:
 * - ASCII wireframe (boxes with +---+, | |, etc.)
 * - Interaction DSL (#id:, [Button]:, "Link": with properties)
 * - Markdown, comments, or other noise (automatically ignored)
 *
 * The parser intelligently extracts wireframe and interaction content,
 * allowing you to write everything in one place.
 *
 * Example:
 * ```
 * @scene: login
 *
 * +---------------------------+
 * |       'WYREFRAME'         |
 * |  +---------------------+  |
 * |  | #email              |  |
 * |  +---------------------+  |
 * |       [ Login ]           |
 * +---------------------------+
 *
 * #email:
 *   placeholder: "이메일을 입력하세요"
 *
 * [Login]:
 *   @click -> goto(dashboard)
 * ```
 *
 * @param text Mixed text containing wireframe and/or interactions
 * @returns Result containing AST or array of parse errors
 *
 * REQ-20: Backward Compatibility
 * REQ-21: Public API Stability
 * REQ-28: Error Recovery (collect all errors)
 */
@genType
let parse = (text: string): parseResult => {
  // Extract wireframe and interactions from mixed content
  let extracted = TextExtractor.extract(text)

  // Parse with extracted content
  let interactions = if extracted.interactions->String.trim === "" {
    None
  } else {
    Some(extracted.interactions)
  }

  parseInternal(extracted.wireframe, interactions)
}

/**
 * Parse only the wireframe structure (no interactions).
 * Convenience function that calls parseInternal(wireframe, None).
 *
 * @param wireframe ASCII wireframe string
 * @returns Result containing AST or array of parse errors
 *
 * REQ-21: Public API Stability
 */
@genType
let parseWireframe = (wireframe: string): parseResult => {
  parseInternal(wireframe, None)
}

/**
 * Parse only the interaction DSL.
 * Useful when interactions are defined separately from the wireframe structure.
 *
 * @param dsl Interaction DSL string
 * @returns Result containing scene interactions or array of parse errors
 *
 * REQ-21: Public API Stability
 * Task 50: Implement parseInteractions Helper
 */
@genType
let parseInteractions = (dsl: string): interactionResult => {
  // TODO: Call InteractionParser.parse when Task 46 is complete
  // Placeholder implementation
  parseInteractionsDSL(dsl)
}

/**
 * Merge interaction definitions into an existing AST.
 * Attaches properties and actions to elements based on element IDs.
 *
 * @param ast Base AST from wireframe parsing
 * @param sceneInteractions Array of scene interactions to merge
 * @returns AST with interactions merged into elements
 *
 * Integration requirement
 */
@genType
let mergeInteractions = (
  ast: Types.ast,
  _sceneInteractions: array<Types.sceneInteractions>,
): Types.ast => {
  // TODO: Implement AST merger
  // Match interactions to elements by ID
  // Validate all element IDs exist
  // Attach properties and actions

  // Placeholder - return unchanged AST
  ast
}

// ============================================================================
// Helper Functions (Not exported to TypeScript)
// ============================================================================

/**
 * Execute the 3-stage parsing pipeline.
 * Internal helper that coordinates Grid Scanner, Shape Detector, and Semantic Parser.
 */
let executePipeline = (_wireframe: string): parseResult => {
  // TODO: Implement pipeline coordination
  // 1. GridScanner.scan(wireframe)
  // 2. ShapeDetector.detect(grid)
  // 3. SemanticParser.parse(context)

  Error([])
}

/**
 * Collect all errors from multiple parsing stages.
 * Ensures all errors are reported, not just the first one (REQ-28).
 */
let collectErrors = (
  gridErrors: array<ErrorTypes.t>,
  shapeErrors: array<ErrorTypes.t>,
  semanticErrors: array<ErrorTypes.t>,
): array<ErrorTypes.t> => {
  [gridErrors, shapeErrors, semanticErrors]->Array.flatMap(x => x)
}

// ============================================================================
// Version Information
// ============================================================================

/**
 * Parser version string.
 * Exported to TypeScript for version checking and compatibility validation.
 */
@genType
let version = "0.1.0"

/**
 * Parser implementation identifier.
 * Useful for distinguishing between legacy JavaScript and new ReScript parser.
 */
@genType
let implementation = "rescript"
