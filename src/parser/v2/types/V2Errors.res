// V2Errors.res
// Error/Warning type definitions for v2 parser.
// Per design.md §Error Types, requirements.md REQ-17.

type severity =
  | Error
  | Warning

type errorCode =
  | InvalidIdFormat
  | MultipleIdDeclarations
  | UnclosedInput
  | UnclosedString
  | UnclosedContainer
  | MissingBlockDeclaration
  | NestedBlockDeclaration
  | MaxDepthExceeded

type warningCode =
  | PropOutsideComponent
  | UnknownEmoji(string)
  | MixedDividerLabelId
  | MissingCheckboxLabel
  | MissingRadioLabel
  | MisalignedContainerCorner
  | MisalignedContainerWall
  | InconsistentContainerWidth
  | RadioGroupAmbiguous
  | DuplicatePropName(string)
  | DuplicateContainerId(string)
  | UnknownPropReference(string)
  | MultipleRadiosSelected(string)
  | LooksLikeButton
  | LooksLikeInput
  | LooksLikeCheckbox
  | LooksLikeRadio

type parseError = {
  code: errorCode,
  message: string,
  location: V2Types.sourceLocation,
  recoverable: bool,
}

type parseWarning = {
  code: warningCode,
  message: string,
  location: V2Types.sourceLocation,
  ruleId: option<string>,
}

let getErrorMessage = (code: errorCode): string =>
  switch code {
  | InvalidIdFormat => "Error: Invalid ID format - ID line must contain only #id"
  | MultipleIdDeclarations => "Error: Multiple ID declarations in container"
  | UnclosedInput => "Error: Unclosed Input boundary - missing '__]'"
  | UnclosedString => "Error: Unclosed string literal - missing '\"'"
  | UnclosedContainer => "Error: Unclosed container - missing bottom border"
  | MissingBlockDeclaration => "Error: Missing block declaration - add @scene: or @component:"
  | NestedBlockDeclaration => "Error: @scene/@component cannot be nested inside another block"
  | MaxDepthExceeded => "Error: Container nesting exceeded maxDepth"
  }

let getWarningMessage = (code: warningCode): string =>
  switch code {
  | PropOutsideComponent => "Warning: PropPlaceholder outside @component - will render as literal"
  | UnknownEmoji(name) => `Warning: Unknown emoji shortcode ':${name}:' - rendering as text`
  | MixedDividerLabelId => "Warning: Mixed label and ID in divider - treating as text"
  | MissingCheckboxLabel => "Warning: Checkbox without label"
  | MissingRadioLabel => "Warning: Radio without label"
  | MisalignedContainerCorner => "Warning: Container corners are not aligned"
  | MisalignedContainerWall => "Warning: Container wall column drifted from the corner"
  | InconsistentContainerWidth => "Warning: Top and bottom borders have different widths"
  | RadioGroupAmbiguous => "Warning: Could not unambiguously group these radios"
  | DuplicatePropName(name) => `Warning: Duplicate prop '${name}' - last declaration wins`
  | DuplicateContainerId(id) => `Warning: Duplicate container id '${id}'`
  | UnknownPropReference(name) => `Warning: \${${name}} does not appear in @props`
  | MultipleRadiosSelected(g) => `Warning: Multiple selected radios in group '${g}'`
  | LooksLikeButton => "Warning: Bracket form looks like a Button but does not match"
  | LooksLikeInput => "Warning: Bracket form looks like an Input but does not match"
  | LooksLikeCheckbox => "Warning: Bracket form looks like a Checkbox but does not match"
  | LooksLikeRadio => "Warning: Paren form looks like a Radio but does not match"
  }

let makeError = (~code, ~location, ~recoverable=true, ()): parseError => {
  code,
  message: getErrorMessage(code),
  location,
  recoverable,
}

let makeWarning = (~code, ~location, ~ruleId=?, ()): parseWarning => {
  code,
  message: getWarningMessage(code),
  location,
  ruleId,
}
