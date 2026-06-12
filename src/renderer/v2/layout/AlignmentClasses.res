// AlignmentClasses.res
// V2 alignment → CSS class names. See design.md §5.

let alignmentClass = (a: V2Types.alignment): string =>
  switch a {
  | Left => "wf-align-left"
  | Center => "wf-align-center"
  | Right => "wf-align-right"
  }
