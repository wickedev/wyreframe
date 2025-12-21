// Error Type Definitions for Wyreframe Parser
// This module defines all error codes, severities, and the ParseError type

// Position type reference (from Core/Position.res)
// This will be properly resolved once Position module is implemented
type position = {
  row: int,
  col: int,
}

// Error severity levels
type severity =
  | Error
  | Warning

// Error code variants with context data
type errorCode =
  // Structural errors
  | UncloseBox({
      corner: position,
      direction: string, // "top", "right", "bottom", or "left"
    })
  | MismatchedWidth({
      topLeft: position,
      topWidth: int,
      bottomWidth: int,
    })
  | MisalignedPipe({
      position: position,
      expected: int, // Expected column position
      actual: int, // Actual column position
    })
  | OverlappingBoxes({
      box1Name: option<string>,
      box2Name: option<string>,
      position: position,
    })
  // Syntax errors
  | InvalidElement({
      content: string,
      position: position,
    })
  | UnclosedBracket({
      opening: position,
    })
  | EmptyButton({
      position: position,
    })
  | InvalidInteractionDSL({
      message: string,
      position: option<position>,
    })
  // Warnings
  | UnusualSpacing({
      position: position,
      issue: string, // Description of the spacing issue
    })
  | DeepNesting({
      depth: int,
      position: position,
    })

// Error context (placeholder for now - will be implemented in ErrorContext module)
type errorContext = {
  codeSnippet: option<string>,
  linesBefore: int,
  linesAfter: int,
}

// Complete parse error type
type t = {
  code: errorCode,
  severity: severity,
  context: option<errorContext>,
}

// Determine severity based on error code
let getSeverity = (code: errorCode): severity => {
  switch code {
  // Structural errors are always Error severity
  | UncloseBox(_) => Error
  | MismatchedWidth(_) => Error
  | MisalignedPipe(_) => Error
  | OverlappingBoxes(_) => Error
  // Syntax errors are always Error severity
  | InvalidElement(_) => Error
  | UnclosedBracket(_) => Error
  | EmptyButton(_) => Error
  | InvalidInteractionDSL(_) => Error
  // Warnings
  | UnusualSpacing(_) => Warning
  | DeepNesting(_) => Warning
  }
}

// Create a ParseError from an error code
let make = (code: errorCode, ~context: option<errorContext>=?): t => {
  {
    code: code,
    severity: getSeverity(code),
    context: context,
  }
}

// Create a ParseError without context
let makeSimple = (code: errorCode): t => {
  make(code, ~context=None)
}

// Get position from error code if available
let getPosition = (code: errorCode): option<position> => {
  switch code {
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

// Check if error is a warning
let isWarning = (error: t): bool => {
  error.severity == Warning
}

// Check if error is an error (not a warning)
let isError = (error: t): bool => {
  error.severity == Error
}

// Get error code name as string (useful for logging/debugging)
let getCodeName = (code: errorCode): string => {
  switch code {
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
