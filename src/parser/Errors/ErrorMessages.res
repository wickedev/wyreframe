// ErrorMessages.res
// Natural language error message templates for all parser error codes

// Import error types
open ErrorTypes

// Template type containing structured error message parts
type template = {
  title: string,
  message: string,
  solution: string,
}

// Helper function to format position as "row X, column Y" (1-indexed for user display)
let formatPosition = (pos: Types.Position.t): string => {
  `row ${Int.toString(pos.row + 1)}, column ${Int.toString(pos.col + 1)}`
}

// Helper function to format optional box name
let formatBoxName = (name: option<string>): string => {
  switch name {
  | Some(n) => `"${n}"`
  | None => "unnamed box"
  }
}

// Get error message template for a specific error code
let getTemplate = (code: errorCode): template => {
  switch code {
  // Structural Errors
  | UncloseBox({corner, direction}) => {
      title: "❌ Box is not closed",
      message: `Box opened at ${formatPosition(corner)} but never closed on the ${direction} side.

The parser detected a '+' corner character that starts a box, but couldn't find the matching closing border. This usually happens when:
• The closing corner '+' is missing
• The border characters ('-' or '|') are broken or incomplete
• The box structure is malformed`,
      solution: `💡 Solution:
Add the missing ${direction} border to close the box:
• If ${direction} is "top" or "bottom": use '+' corners and '-' characters
• If ${direction} is "left" or "right": use '+' corners and '|' characters
• Ensure all four corners are present and borders are continuous`,
    }

  | MismatchedWidth({topLeft, topWidth, bottomWidth}) => {
      title: "❌ Box width mismatch",
      message: `Box starting at ${formatPosition(topLeft)} has different widths on top and bottom borders:
• Top border: ${Int.toString(topWidth)} characters wide
• Bottom border: ${Int.toString(bottomWidth)} characters wide

All boxes must have matching top and bottom border widths to form a valid rectangle.`,
      solution: `💡 Solution:
Make both borders the same width. Adjust the ${topWidth > bottomWidth ? "bottom" : "top"} border to match:
• Add ${Int.toString(Js.Math.abs_int(topWidth - bottomWidth))} ${topWidth > bottomWidth ? "dashes" : "dashes"} to make them equal
• Count carefully: include both corner '+' characters in the width
• Example: "+----+" is 6 characters wide (including corners)`,
    }

  | MisalignedPipe({position, expectedCol, actualCol}) => {
      title: "❌ Vertical border misaligned",
      message: `The '|' character at ${formatPosition(position)} is not aligned with the box edge:
• Expected column: ${Int.toString(expectedCol + 1)}
• Actual column: ${Int.toString(actualCol + 1)}
• Off by: ${Int.toString(Js.Math.abs_int(expectedCol - actualCol))} ${Js.Math.abs_int(expectedCol - actualCol) === 1 ? "space" : "spaces"}

Vertical borders must be perfectly aligned to form valid box sides.`,
      solution: `💡 Solution:
Move the '|' character to column ${Int.toString(expectedCol + 1)}:
• ${expectedCol > actualCol ? "Add" : "Remove"} ${Int.toString(Js.Math.abs_int(expectedCol - actualCol))} space${Js.Math.abs_int(expectedCol - actualCol) === 1 ? "" : "s"} ${expectedCol > actualCol ? "before" : "after"} the '|' character
• Use a monospace font editor to ensure proper alignment
• Check that all '|' characters in this box are in the same column`,
    }

  | OverlappingBoxes({box1Name, box2Name, position}) => {
      title: "❌ Overlapping boxes detected",
      message: `Two boxes overlap at ${formatPosition(position)} but neither completely contains the other:
• Box 1: ${formatBoxName(box1Name)}
• Box 2: ${formatBoxName(box2Name)}

Boxes must either:
• Be completely nested (one fully inside the other), OR
• Be completely separate (no overlap at all)`,
      solution: `💡 Solution:
Fix the overlap by either:
1. Nesting: Make one box completely inside the other
   • Ensure all four borders of the inner box are inside the outer box
2. Separating: Move the boxes so they don't touch
   • Add space between the boxes
   • Or place them on different rows

Partial overlaps are not allowed in the wireframe syntax.`,
    }

  // Syntax Errors
  | InvalidElement({content, position}) => {
      title: "❌ Invalid element syntax",
      message: `Unrecognized element syntax at ${formatPosition(position)}:
"${content}"

The parser couldn't match this content to any known element pattern:
• Buttons: [ Text ]
• Inputs: #fieldname
• Links: "Link Text"
• Checkboxes: [x] or [ ]
• Emphasis: * Text`,
      solution: `💡 Solution:
Check the element syntax and fix any typos:
• Make sure brackets match: [ and ]
• Ensure quotes are paired: "text"
• Verify input fields start with #
• Use supported element patterns from the documentation

If this is plain text, it will be treated as a text element automatically.`,
    }

  | UnclosedBracket({opening}) => {
      title: "❌ Unclosed bracket",
      message: `Opening bracket '[' at ${formatPosition(opening)} is never closed.

This bracket starts a button or checkbox but has no matching closing ']' bracket.`,
      solution: `💡 Solution:
Add the closing ']' bracket to complete the element:
• For buttons: [ Button Text ]
• For checkboxes: [x] or [ ]

Make sure both brackets are on the same line.`,
    }

  | EmptyButton({position}) => {
      title: "❌ Empty button",
      message: `Button at ${formatPosition(position)} has no text content.

Buttons must have descriptive text between the brackets: [ Text ]`,
      solution: `💡 Solution:
Add text between the brackets:
• Bad: [ ]
• Good: [ Submit ]
• Good: [ Click Here ]

Button text should clearly describe the action.`,
    }

  | InvalidInteractionDSL({message, position}) => {
      let posInfo = switch position {
      | Some(pos) => ` at ${formatPosition(pos)}`
      | None => ""
      }

      {
        title: "❌ Invalid interaction syntax",
        message: `Failed to parse interaction DSL${posInfo}:
${message}

The interaction definition doesn't match the expected YAML-like syntax.`,
        solution: `💡 Solution:
Check your interaction syntax:
• Scene declarations: @scene: sceneName
• Element selectors: #input: or [ button ]:
• Properties: indent with 2 spaces, use "key: value"
• Actions: @click -> goto(target)

Refer to the interaction DSL documentation for examples.`,
      }
    }

  // Warnings
  | UnusualSpacing({position, issue}) => {
      title: "⚠️  Unusual spacing detected",
      message: `Spacing issue at ${formatPosition(position)}:
${issue}

While this may still parse correctly, it could cause alignment problems in some environments.`,
      solution: `💡 Solution:
Normalize the spacing:
• Use spaces instead of tabs for alignment
• Use consistent spacing throughout the wireframe
• Use a monospace font to verify alignment visually

This is a warning - parsing will continue.`,
    }

  | DeepNesting({depth, position}) => {
      title: "⚠️  Deep nesting detected",
      message: `Box at ${formatPosition(position)} is nested ${Int.toString(depth)} levels deep.

While technically valid, deeply nested boxes can:
• Reduce readability
• Make maintenance difficult
• Indicate overly complex UI structure`,
      solution: `💡 Solution:
Consider simplifying the structure:
• Flatten the hierarchy where possible
• Split complex sections into separate scenes
• Use dividers (===) instead of nested boxes for simple grouping
• Keep nesting to 3-4 levels maximum for best readability

This is a warning - parsing will continue.`,
    }

  | InvalidInput({message}) => {
      title: "❌ Invalid input",
      message: `${message}

The input could not be processed due to formatting or content issues.`,
      solution: `💡 Solution:
Check your input format:
• Ensure the wireframe text is properly formatted
• Use ASCII characters for box drawing
• Check for encoding issues if pasting from external sources`,
    }

  | InvalidStartPosition(position) => {
      title: "❌ Invalid starting position",
      message: `Position ${formatPosition(position)} is not a valid corner for box tracing.

Box tracing must start from a '+' character that forms a valid corner.`,
      solution: `💡 Solution:
Ensure the starting position:
• Contains a '+' character
• Is part of a complete box structure
• Has valid border characters adjacent to it`,
    }
  }
}

// Format complete error message from error code
let format = (code: errorCode): string => {
  let template = getTemplate(code)

  `${template.title}

${template.message}

${template.solution}`
}

// Format error message from ParseError type
let formatError = (error: t): string => {
  format(error.code)
}

// Format complete error message from ParseError with code snippet context
// This is the main formatting function for Task 38
// Includes: title, message, code snippet (if available), and solution
let formatWithContext = (error: t): string => {
  let template = getTemplate(error.code)

  // Build the formatted message parts
  let parts = []

  // 1. Title
  parts->Js.Array2.push(template.title)->ignore
  parts->Js.Array2.push("")->ignore

  // 2. Message
  parts->Js.Array2.push(template.message)->ignore
  parts->Js.Array2.push("")->ignore

  // 3. Code Snippet (if context is available)
  switch error.context {
  | Some(ctx) => {
      let snippet = ErrorContext.getSnippet(ctx)
      parts->Js.Array2.push("📍 Location:")->ignore
      parts->Js.Array2.push("")->ignore
      parts->Js.Array2.push(snippet)->ignore
      parts->Js.Array2.push("")->ignore
    }
  | None => ()
  }

  // 4. Solution
  parts->Js.Array2.push(template.solution)->ignore

  // Join all parts with newlines
  parts->Js.Array2.joinWith("\n")
}

// Format complete error message from ParseError type
// Uses formatWithContext if context is available, otherwise uses simple format
let formatComplete = (error: t): string => {
  switch error.context {
  | Some(_) => formatWithContext(error)
  | None => formatError(error)
  }
}

// Get just the title from an error code
let getTitle = (code: errorCode): string => {
  let template = getTemplate(code)
  template.title
}

// Get just the message from an error code
let getMessage = (code: errorCode): string => {
  let template = getTemplate(code)
  template.message
}

// Get just the solution from an error code
let getSolution = (code: errorCode): string => {
  let template = getTemplate(code)
  template.solution
}
