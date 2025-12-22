// ParserRegistry.res
// Registry for element parsers with priority-based ordering

open Types

/**
 * The parser registry type.
 * Contains a mutable array of element parsers sorted by priority (descending).
 */
type t = {
  mutable parsers: array<ElementParser.elementParser>,
}

/**
 * Create a new empty parser registry.
 *
 * @return A new registry instance with no registered parsers
 */
let make = (): t => {
  {parsers: []}
}

/**
 * Register an element parser in the registry.
 * Parsers are automatically sorted by priority (highest first).
 *
 * @param registry - The registry to add the parser to
 * @param parser - The element parser to register
 */
let register = (registry: t, parser: ElementParser.elementParser): unit => {
  // Add parser to array
  registry.parsers->Array.push(parser)->ignore

  // Re-sort by priority (descending - highest priority first)
  registry.parsers = registry.parsers->Array.toSorted((a, b) => {
    Int.toFloat(compare(b.priority, a.priority))
  })
}

/**
 * Parse content using registered parsers.
 *
 * Tries each parser in priority order until one succeeds.
 * The first parser whose canParse() returns true AND whose parse() returns Some(element)
 * will be used, and remaining parsers will be skipped.
 *
 * If no parser succeeds, returns a default Text element (fallback).
 *
 * @param registry - The registry containing registered parsers
 * @param content - The text content to parse
 * @param position - Grid position where content appears
 * @param bounds - Bounding box of containing box
 * @return A parsed element (never None because of fallback)
 */
let parse = (
  registry: t,
  content: string,
  position: Position.t,
  bounds: Bounds.t,
): Types.element => {
  // Try each parser in priority order
  let result = ref(None)

  for i in 0 to Array.length(registry.parsers) - 1 {
    switch result.contents {
    | Some(_) => () // Already found a match, skip remaining
    | None => {
        let parser = registry.parsers->Array.getUnsafe(i)

        // First check if parser can handle this content
        if parser.canParse(content) {
          // Try to parse
          switch parser.parse(content, position, bounds) {
          | Some(element) => result := Some(element)
          | None => () // This parser couldn't parse it, try next
          }
        }
      }
    }
  }

  // Return result or fallback to plain text
  switch result.contents {
  | Some(element) => element
  | None =>
    // Fallback: create a plain text element if no parser matched
    // This shouldn't happen if TextParser is registered, but provides safety
    Types.Text({
      content: content,
      emphasis: false,
      position: Types.Position.make(position.row, position.col),
      align: Types.Left,
    })
  }
}

/**
 * Create a registry with all default parsers pre-registered.
 *
 * Registers parsers in this priority order:
 * 1. ButtonParser (priority 100)
 * 2. InputParser (priority 90)
 * 3. CheckboxParser (priority 85)
 * 4. LinkParser (priority 80)
 * 5. CodeTextParser (priority 75) - backtick-wrapped text with position-based alignment
 * 6. EmphasisParser (priority 70)
 * 7. TextParser (priority 1) - fallback
 *
 * @return A registry with all standard parsers registered
 */
let makeDefault = (): t => {
  let registry = make()

  // Register all standard parsers
  // They'll be automatically sorted by priority
  registry->register(ButtonParser.make())
  registry->register(InputParser.make())
  registry->register(CheckboxParser.make())
  registry->register(LinkParser.make())
  registry->register(CodeTextParser.make())
  registry->register(EmphasisParser.make())
  registry->register(TextParser.make()) // Fallback with priority 1

  registry
}

/**
 * Get the number of registered parsers.
 *
 * @param registry - The registry to query
 * @return The number of parsers registered
 */
let count = (registry: t): int => {
  Array.length(registry.parsers)
}

/**
 * Get all registered parsers (sorted by priority).
 *
 * @param registry - The registry to query
 * @return Array of registered parsers in priority order
 */
let getParsers = (registry: t): array<ElementParser.elementParser> => {
  registry.parsers
}
