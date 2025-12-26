// FixTypes.res
// Type definitions for the auto-fix functionality

/**
 * Describes a single fix that was applied to the source text
 */
type fixedIssue = {
  original: ErrorTypes.t,
  description: string,
  line: int,
  column: int,
}

/**
 * Result of a successful fix operation
 */
type fixSuccess = {
  text: string,
  fixed: array<fixedIssue>,
  remaining: array<ErrorTypes.t>,
}

/**
 * Result type for fix operations
 */
type fixResult = result<fixSuccess, array<ErrorTypes.t>>

/**
 * Strategy for fixing a specific error type
 */
type fixStrategy = {
  canFix: ErrorTypes.errorCode => bool,
  apply: (string, ErrorTypes.t) => option<(string, fixedIssue)>,
}
