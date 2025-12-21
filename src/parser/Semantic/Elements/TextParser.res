// TextParser.res
// Fallback parser for plain text that doesn't match any other pattern
//
// This parser has the lowest priority (1) and always accepts content,
// making it the last resort when no other parser matches.

/**
 * Create a TextParser instance.
 *
 * This is a fallback parser that catches all unrecognized content and
 * treats it as plain text. It should be registered with the lowest priority
 * in the ParserRegistry.
 *
 * Behavior:
 * - canParse: Always returns true (catches everything)
 * - parse: Generates a Text element with emphasis=false
 * - Priority: 1 (lowest - used as fallback)
 *
 * @return An ElementParser instance configured as a text fallback parser
 */
let make = (): ElementParser.elementParser => {
  ElementParser.make(
    ~priority=1, // Lowest priority - fallback parser
    ~canParse=_content => {
      // Always returns true to catch any content that no other parser matched
      true
    },
    ~parse=(content, position, _bounds) => {
      // Generate a plain text element with the raw content
      // Note: For fallback text, we use Left alignment by default
      // This is simpler than calculating alignment for unstructured text
      Some(
        Types.Text({
          content: content,
          emphasis: false,
          position: position,
          align: Types.Left,
        }),
      )
    },
  )
}
