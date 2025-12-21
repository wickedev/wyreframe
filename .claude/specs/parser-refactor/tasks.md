# Implementation Plan - Wyreframe Parser Refactoring

**Project**: Wyreframe ASCII Wireframe to HTML Converter
**Implementation Language**: ReScript
**Target**: Browser-based parser with TypeScript API

This document outlines the implementation tasks for refactoring the Wyreframe parser from JavaScript to ReScript. Each task builds incrementally on previous tasks.

---

## Phase 0: Project Setup

- [ ] 1. Initialize ReScript Project Configuration
  - Set up `bsconfig.json` with correct module settings (es6, in-source)
  - Add ReScript compiler to package.json dependencies
  - Add `res:build`, `res:watch`, `res:clean` scripts
  - Add ReScript build artifacts to .gitignore
  - Verify `npm run res:build` compiles successfully
  - _Requirements: REQ-24_

- [ ] 2. Set Up Testing Framework
  - Install and configure @glennsl/rescript-jest
  - Set up jest.config.js to handle ReScript files
  - Create sample test file and verify it runs
  - Enable coverage reporting
  - _Requirements: REQ-25_

- [x] 3. Create Directory Structure
  - Create modular directory structure: Core, Scanner, Detector, Semantic, Elements, Interactions, Errors
  - Add index files or README placeholders
  - Verify structure matches PARSER_ARCHITECTURE.md
  - _Requirements: REQ-24_

- [ ] 4. Set Up ohm-js Integration
  - Install ohm-js as dependency
  - Create ReScript FFI bindings in OhmBindings.res
  - Create empty interaction.ohm grammar placeholder
  - Test basic grammar loading
  - _Requirements: Interaction DSL Parser_

---

## Phase 1: Core Infrastructure

- [ ] 5. Implement Position Type
  - Create Position module with row/col coordinates
  - Implement make, navigation functions (right, down, left, up)
  - Implement equals and toString
  - Write unit tests with ≥90% coverage
  - _Requirements: REQ-1, REQ-2_

- [ ] 6. Implement Bounds Type
  - Create Bounds module with top, left, bottom, right
  - Implement make with validation, width, height, area
  - Implement contains and overlaps detection
  - Write unit tests covering edge cases
  - _Requirements: REQ-6_

- [ ] 7. Implement Core Types Module
  - Define cellChar variant (Corner, HLine, VLine, Divider, Space, Char)
  - Define alignment variant (Left, Center, Right)
  - Define element variant (Box, Button, Input, Link, Checkbox, Text, Divider, Row, Section)
  - Define scene and ast record types
  - Add type documentation comments
  - _Requirements: REQ-15_

- [ ] 8. Implement Grid Data Structure
  - Create Grid with 2D array, width, height, character indices
  - Implement fromLines with normalization
  - Implement get, getLine, getRange
  - Implement scanRight/Down/Left/Up with predicate
  - Implement findAll using prebuilt indices (O(1) lookup)
  - Write unit tests, performance test: 1000-line grid <10ms
  - _Requirements: REQ-1, REQ-2_

- [ ] 9. Write Grid Scanner Integration Tests
  - Test simple box, nested boxes, dividers, uneven lines, special characters
  - _Requirements: REQ-25_

---

## Phase 2: Shape Detection

- [ ] 10. Implement BoxTracer - Basic Box Tracing
  - Implement traceBox starting from '+' corner
  - Trace all four edges validating characters
  - Return Ok(box) or Error for incomplete boxes
  - Write unit tests for all edge directions
  - _Requirements: REQ-3_

- [ ] 11. Implement BoxTracer - Box Name Extraction
  - Implement extractBoxName recognizing "+--Name--+" pattern
  - Extract and trim text between dashes
  - Handle multi-word names, return None for unnamed boxes
  - _Requirements: REQ-4_

- [ ] 12. Implement BoxTracer - Width Validation
  - Compare top and bottom edge widths
  - Return Error(MismatchedWidth) with context
  - _Requirements: REQ-7_

- [ ] 13. Implement BoxTracer - Pipe Alignment Validation
  - Validate left and right '|' alignment
  - Return Error(MisalignedPipe) with position
  - _Requirements: REQ-7_

- [ ] 14. Implement DividerDetector Module
  - Detect '=' characters within box bounds
  - Validate full-width dividers
  - Return array of row positions in order
  - _Requirements: REQ-5_

- [ ] 15. Implement HierarchyBuilder - Containment Detection
  - Implement contains(outer, inner) using bounds comparison
  - Handle overlapping, equal, and disjoint boxes
  - _Requirements: REQ-6_

- [ ] 16. Implement HierarchyBuilder - Parent-Child Relationships
  - Implement buildHierarchy sorting by area
  - Find immediate parent for each box
  - Populate children arrays, return root boxes
  - Test 2-level, 3-level, 4-level nesting
  - _Requirements: REQ-6_

- [ ] 17. Implement HierarchyBuilder - Overlap Detection
  - Detect invalid overlapping boxes
  - Return Error(OverlappingBoxes) with positions
  - _Requirements: REQ-6_

- [ ] 18. Implement ShapeDetector Main Module
  - Implement detect(grid) finding all '+' corners
  - Trace boxes, detect dividers, build hierarchy
  - Return Result<array<box>, array<error>>
  - Collect all errors (no early stopping)
  - _Requirements: REQ-28_

- [ ] 19. Write Shape Detection Integration Tests
  - Test single box, nested (2-3 levels), siblings, dividers, names, malformed boxes
  - _Requirements: REQ-25_

---

## Phase 3: Semantic Parsing

- [ ] 20. Implement ElementParser Interface
  - Define ElementParser type with priority field
  - Define canParse and parse function signatures
  - Add documentation, export types
  - _Requirements: REQ-8, REQ-26_

- [ ] 21. Implement ButtonParser
  - Recognize "[ Text ]" pattern (priority 100)
  - Extract text between brackets
  - Generate button element with id and text
  - _Requirements: REQ-9_

- [ ] 22. Implement InputParser
  - Recognize "#fieldname" pattern (priority 90)
  - Extract identifier, generate input element
  - _Requirements: REQ-10_

- [ ] 23. Implement LinkParser
  - Recognize quoted text pattern (priority 80)
  - Extract text, handle escaped quotes
  - _Requirements: REQ-11_

- [ ] 24. Implement CheckboxParser
  - Recognize "[x]" and "[ ]" patterns (priority 85)
  - Extract checked state and label
  - _Requirements: REQ-12_

- [ ] 25. Implement EmphasisParser
  - Recognize "* Text" pattern (priority 70)
  - Generate text element with emphasis=true
  - _Requirements: REQ-13_

- [ ] 26. Implement TextParser (Fallback)
  - Always return true for canParse (priority 1)
  - Generate plain text element
  - _Requirements: REQ-8_

- [ ] 27. Implement ParserRegistry
  - Implement make, register (sort by priority)
  - Implement parse trying each parser in order
  - Fall back to TextParser if no match
  - _Requirements: REQ-8_

- [ ] 28. Implement AlignmentCalc Module
  - Calculate leftSpace, rightSpace, ratios
  - Return Left/Right/Center based on thresholds
  - _Requirements: REQ-14_

- [ ] 29. Implement ASTBuilder Module
  - Implement buildScene and buildAST
  - Handle optional fields, validate unique scene IDs
  - Return Result<ast, error>
  - _Requirements: REQ-15_

- [ ] 30. Implement SemanticParser - Box Content Extraction
  - Extract lines within bounds, exclude borders
  - Preserve internal whitespace
  - _Requirements: Semantic Parser_

- [ ] 31. Implement SemanticParser - Element Recognition Pipeline
  - Iterate content lines, determine positions
  - Call registry.parse, calculate alignment
  - Handle dividers as section separators
  - _Requirements: REQ-15_

- [ ] 32. Implement SemanticParser - Scene Directive Parsing
  - Recognize @scene, @title, @transition patterns
  - Extract IDs and metadata
  - Group content by scene boundaries
  - _Requirements: REQ-20_

- [ ] 33. Implement SemanticParser - Main Parse Function
  - Accept grid, shapes, registry
  - Group shapes by scene, parse content
  - Build complete AST, collect all errors
  - _Requirements: REQ-15_

- [ ] 34. Write Semantic Parser Integration Tests
  - Test login scene, multiple scenes, nested boxes, dividers, all element types, alignment
  - _Requirements: REQ-25_

---

## Phase 4: Error System

- [ ] 35. Define Error Type Variants
  - Define errorCode variant (all error types)
  - Define severity variant (Error, Warning)
  - Define ParseError type with context
  - Implement getSeverity function
  - _Requirements: REQ-16, REQ-19_

- [ ] 36. Implement Error Message Templates
  - Define template type (title, message, solution)
  - Implement getTemplate for each error code
  - Use natural language, emojis, interpolation
  - Include "💡 Solution" sections
  - _Requirements: REQ-17, REQ-27_

- [ ] 37. Implement ErrorContext Builder
  - Implement make and buildCodeSnippet
  - Mark error line (→) and column (^)
  - Handle edge cases, configurable radius
  - _Requirements: REQ-18_

- [ ] 38. Implement Error Formatting Function
  - Implement format(parseError) with complete message
  - Include title, message, snippet, solution
  - Format consistently across types
  - _Requirements: REQ-17, REQ-27_

- [ ] 39. Integrate Errors into BoxTracer
  - Update traceBox to return Result.t<box, ParseError.t>
  - Create structured error variants with context
  - _Requirements: REQ-16_

- [ ] 40. Integrate Errors into HierarchyBuilder
  - Update buildHierarchy to use ParseError.t
  - Create OverlappingBoxes error
  - _Requirements: REQ-16_

- [ ] 41. Implement Warning Detection - Unusual Spacing
  - Detect tab characters, generate warning
  - Don't stop parsing (warning only)
  - _Requirements: REQ-19_

- [ ] 42. Implement Warning Detection - Deep Nesting
  - Calculate nesting depth, warn if > 4
  - Include depth and position
  - _Requirements: REQ-19_

---

## Phase 5: Integration

- [ ] 43. Create ohm Grammar for Interaction DSL
  - Define Document, SceneBlock, Interaction rules
  - Support selectors, properties, actions
  - Support action types (goto, back, forward, validate, call)
  - Verify parsing and rejection behavior
  - _Requirements: Interaction DSL Parser_

- [x] 44. Implement InteractionAST Types
  - Define interactionVariant, interactionAction variants
  - Define interaction and sceneInteractions records
  - Add documentation
  - _Requirements: Interaction DSL Parser_

- [ ] 45. Implement Ohm Semantic Actions
  - Create semantic actions for all grammar rules
  - Convert to ReScript InteractionAST types
  - Handle all action types
  - _Requirements: Interaction DSL Parser_

- [ ] 46. Implement InteractionParser Main Function
  - Implement parse loading grammar
  - Return Ok or Error(InvalidInteractionDSL)
  - Extract error position from ohm failure
  - _Requirements: Interaction DSL Parser_

- [ ] 47. Implement AST Merger
  - Implement mergeInteractions matching by ID
  - Attach properties and actions to elements
  - Validate element IDs exist
  - _Requirements: Integration_

- [ ] 48. Implement WyreframeParser - Main Parse Function
  - Execute 3 stages: Grid, Shape, Semantic
  - Optionally parse and merge interactions
  - Return Result<ast, array<ParseError.t>>
  - Collect all errors from all stages
  - _Requirements: REQ-20, REQ-21_

- [ ] 49. Implement parseWireframe Helper
  - Call parse(wireframe, None)
  - _Requirements: Public API_

- [ ] 50. Implement parseInteractions Helper
  - Call InteractionParser.parse
  - _Requirements: Public API_

- [ ] 51. Create End-to-End Integration Tests
  - Test login scene, multi-scene, nested boxes, interactions, errors, warnings
  - Use realistic examples
  - _Requirements: REQ-25_

- [ ] 52. Implement Performance Benchmarks
  - Benchmark 100-line (≤50ms), 500-line (≤200ms), 2000-line (≤1000ms) wireframes
  - Test memory usage (<50MB for 2000 lines)
  - Generate fixtures programmatically
  - _Requirements: REQ-22, REQ-23_

- [ ] 53. Add GenType Annotations for TypeScript Interop
  - Add @genType.as annotations
  - Export parse and helper functions
  - Verify generated types compile
  - _Requirements: REQ-21_

---

## Phase 6: Migration & Documentation

- [ ] 54. Create Compatibility Layer for Legacy Parser
  - Create FFI bindings to legacy JavaScript parser
  - Implement convertJsJsonToAst
  - Create parseLegacy wrapper
  - _Requirements: REQ-30_

- [ ] 55. Implement Parser Comparison Tool
  - Implement compareResults comparing ASTs
  - Categorize differences (improvements, neutral, regressions)
  - Generate detailed comparison report
  - _Requirements: REQ-30_

- [ ] 56. Run Parallel Validation Tests
  - Run both parsers on all fixtures
  - Generate per-fixture and summary reports
  - Verify no critical regressions
  - _Requirements: REQ-30_

- [ ] 57. Implement Feature Flag System
  - Implement ParserConfig.useNewParser
  - Default to legacy, allow per-test override
  - Document usage
  - _Requirements: REQ-30_

- [ ] 58. Write API Documentation
  - Create API.md, TYPES.md, EXAMPLES.md
  - Include TypeScript examples
  - Explain error handling patterns
  - _Requirements: REQ-29_

- [ ] 59. Write Migration Guide
  - Explain differences, breaking changes
  - Provide step-by-step instructions
  - Include feature flag usage
  - _Requirements: REQ-30_

- [ ] 60. Write Developer Guide
  - Explain 3-stage architecture
  - Show custom ElementParser creation
  - Document extension points
  - _Requirements: REQ-26, REQ-29_

- [ ] 61. Update README
  - Mention parser refactoring
  - Link to documentation
  - Update usage examples
  - _Requirements: REQ-29_

- [ ] 62. Deprecate Legacy Parser
  - Add console warnings
  - Add @deprecated annotations
  - Allow warning suppression
  - _Requirements: REQ-30_

- [ ] 63. Remove Legacy Parser Code
  - Delete legacy and comparison directories
  - Remove feature flag logic
  - Verify tests pass, bundle size reduced
  - _Requirements: REQ-30_

---

## Summary

- **Total Tasks**: 63
- **Must-Have**: 51 (81%)
- **Should-Have**: 12 (19%)
- **Estimated Timeline**: 8-12 weeks (1-2 developers)

---

## Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0 | 2025-12-21 | Claude | Initial implementation plan |
| 1.1 | 2025-12-22 | Claude | Reformatted to simple checkbox format |
