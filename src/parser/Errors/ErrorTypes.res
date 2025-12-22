// ErrorTypes.res
// Structured error types for the Wyreframe parser
// Provides comprehensive error classification with contextual information

open Types

/**
 * Error severity levels for categorizing parser errors
 */
type severity =
  | Error // Fatal errors that prevent parsing
  | Warning // Non-fatal issues that should be addressed

/**
 * Comprehensive error code variants for all parser stages
 * Each variant carries specific context for helpful error messages
 */
type errorCode =
  // Grid Scanner Errors
  | InvalidInput({message: string}) // Invalid input format
  // Shape Detector Errors - Box Tracing (REQ-3, REQ-7)
  | InvalidStartPosition(Position.t) // Starting position is not a corner
  | UncloseBox({
      corner: Position.t,
      direction: string, // "top", "right", "bottom", or "left"
    }) // Box edge not closed - consolidated variant
  | MismatchedWidth({
      topLeft: Position.t,
      topWidth: int,
      bottomWidth: int,
    }) // Top and bottom widths don't match (REQ-7, Task 12)
  | MisalignedPipe({
      position: Position.t,
      expectedCol: int,
      actualCol: int,
    }) // Vertical pipe not aligned with box edge (REQ-7, Task 13)
  | OverlappingBoxes({
      box1Name: option<string>,
      box2Name: option<string>,
      position: Position.t,
    }) // Boxes overlap incorrectly (REQ-6)
  // Semantic Parser Errors
  | InvalidElement({
      content: string,
      position: Position.t,
    }) // Unknown element syntax (REQ-19)
  | UnclosedBracket({opening: Position.t}) // Bracket not closed (REQ-19)
  | EmptyButton({position: Position.t}) // Button has no text (REQ-19)
  | InvalidInteractionDSL({
      message: string,
      position: option<Position.t>,
    }) // Interaction DSL parsing failed
  // Warnings (REQ-19)
  | UnusualSpacing({
      position: Position.t,
      issue: string,
    }) // Tabs instead of spaces, etc.
  | DeepNesting({
      depth: int,
      position: Position.t,
    }) // Nesting depth exceeds recommended level

/**
 * Complete parse error with error code, severity, and context
 */
type t = {
  code: errorCode,
  severity: severity,
  context: option<ErrorContext.t>,
}

/**
 * Determine severity from error code
 * Warnings start with "Unusual" or "Deep", all others are Errors
 */
let getSeverity = (code: errorCode): severity => {
  switch code {
  | UnusualSpacing(_) | DeepNesting(_) => Warning
  | _ => Error
  }
}

/**
 * Create a ParseError from an error code
 * Automatically determines severity based on error type
 */
let make = (code: errorCode, context: option<ErrorContext.t>): t => {
  {
    code: code,
    severity: getSeverity(code),
    context: context,
  }
}

/**
 * Create a ParseError without context (simple errors)
 * Useful when grid context is not available or needed
 * REQ-16: Structured error objects
 */
let makeSimple = (code: errorCode): t => {
  make(code, None)
}

/**
 * Create a ParseError from an error code with grid context
 * Builds error context from grid and position
 * REQ-18: Contextual code snippets
 */
let makeWithGrid = (code: errorCode, grid: Grid.t, position: Position.t): t => {
  let typesPosition = Types.Position.make(position.row, position.col)
  let context = ErrorContext.make(grid, typesPosition)
  make(code, Some(context))
}

/**
 * Get position from error code if available
 * Returns the primary position associated with the error
 */
let getPosition = (code: errorCode): option<Position.t> => {
  switch code {
  | InvalidInput(_) => None
  | InvalidStartPosition(pos) => Some(pos)
  | UncloseBox({corner}) => Some(corner)
  | MismatchedWidth({topLeft}) => Some(topLeft)
  | MisalignedPipe({position}) => Some(position)
  | OverlappingBoxes({position}) => Some(position)
  | InvalidElement({position}) => Some(position)
  | UnclosedBracket({opening}) => Some(opening)
  | EmptyButton({position}) => Some(position)
  | InvalidInteractionDSL({position}) => position
  | UnusualSpacing({position}) => Some(position)
  | DeepNesting({position}) => Some(position)
  }
}

/**
 * Check if error is a warning
 */
let isWarning = (error: t): bool => {
  error.severity == Warning
}

/**
 * Check if error is an error (not a warning)
 */
let isError = (error: t): bool => {
  error.severity == Error
}

/**
 * Get error code name as string (useful for logging/debugging)
 * REQ-16: Error codes for different types of problems
 */
let getCodeName = (code: errorCode): string => {
  switch code {
  | InvalidInput(_) => "InvalidInput"
  | InvalidStartPosition(_) => "InvalidStartPosition"
  | UncloseBox(_) => "UncloseBox"
  | MismatchedWidth(_) => "MismatchedWidth"
  | MisalignedPipe(_) => "MisalignedPipe"
  | OverlappingBoxes(_) => "OverlappingBoxes"
  | InvalidElement(_) => "InvalidElement"
  | UnclosedBracket(_) => "UnclosedBracket"
  | EmptyButton(_) => "EmptyButton"
  | InvalidInteractionDSL(_) => "InvalidInteractionDSL"
  | UnusualSpacing(_) => "UnusualSpacing"
  | DeepNesting(_) => "DeepNesting"
  }
}
