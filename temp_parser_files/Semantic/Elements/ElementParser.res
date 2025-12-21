// ElementParser.res
// Interface for all element parsers in the semantic parsing stage
//
// This module defines the contract that all element parsers must implement
// to be registered in the ParserRegistry and participate in element recognition.

/**
 * Result type for parsing operations.
 * Returns Some(element) if parsing succeeds, None if the pattern doesn't match.
 */
type parseResult<'element> = option<'element>

/**
 * ElementParser interface type.
 *
 * All element parsers (ButtonParser, InputParser, LinkParser, etc.) must
 * implement this interface to be compatible with the ParserRegistry.
 *
 * Fields:
 * - priority: Determines the order in which parsers are tried (higher = earlier)
 *             Recommended ranges: 100 (buttons), 90 (inputs), 80 (links), 70 (emphasis), 1 (text fallback)
 * - canParse: Quick check function to determine if this parser can handle the content
 * - parse: Full parsing function that extracts element data from content
 */
type t<'position, 'bounds, 'element> = {
  /**
   * Priority value for parser ordering.
   * Higher priority parsers are checked first.
   * Use 1 for fallback parsers, 100+ for specific element types.
   */
  priority: int,

  /**
   * Quick pattern matching function.
   * Returns true if this parser can handle the given content string.
   * Should be fast and use simple pattern matching (regex test, string contains, etc.)
   *
   * @param content - The text content to check
   * @return true if this parser should attempt to parse the content
   */
  canParse: string => bool,

  /**
   * Full parsing function.
   * Extracts element data from content and returns a structured element.
   * Only called if canParse() returns true.
   *
   * @param content - The text content to parse
   * @param position - Position in the grid where this content was found
   * @param bounds - Bounding box of the containing box (for alignment calculation)
   * @return Some(element) if parsing succeeds, None if it fails
   */
  parse: (string, 'position, 'bounds) => parseResult<'element>,
}

/**
 * Concrete type alias for element parsers using the actual types.
 * This will be used by the ParserRegistry and concrete parser implementations.
 *
 * Note: This assumes Position.t, Bounds.t, and element types are defined in Core/Types.res
 * The generic version above allows for testing without those dependencies.
 */
type elementParser = t<Position.t, Bounds.t, Types.element>

/**
 * Helper function to create an element parser.
 *
 * @param priority - Priority value for ordering
 * @param canParse - Pattern matching function
 * @param parse - Full parsing function
 * @return An ElementParser.t instance
 */
let make = (
  ~priority: int,
  ~canParse: string => bool,
  ~parse: (string, Position.t, Bounds.t) => parseResult<Types.element>,
): elementParser => {
  priority,
  canParse,
  parse,
}
