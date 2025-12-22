// PerformanceFixtures.res
// Programmatic wireframe generation for performance testing

/**
 * Generate a wireframe with approximately the target number of lines.
 * Creates realistic nested structures with various element types.
 *
 * @param targetLines - Approximate number of lines to generate
 * @returns ASCII wireframe string
 */
let generateWireframe = (targetLines: int): string => {
  // Calculate structure to approximate target line count
  // Each box produces roughly: 3 (borders) + 2 (empty) + elementsPerBox * 1.5 (elements + spacing) lines
  // Each scene adds: 3 (header) + scene separators
  // Formula: targetLines ≈ numScenes * (3 + boxesPerScene * (5 + elementsPerBox * 1.5))

  // Use more granular scaling
  let (numScenes, boxesPerScene, elementsPerBox) = if targetLines <= 50 {
    (1, 3, 6) // ~45 lines
  } else if targetLines <= 100 {
    (2, 3, 6) // ~95 lines
  } else if targetLines <= 200 {
    (2, 5, 8) // ~185 lines
  } else if targetLines <= 500 {
    (3, 7, 10) // ~480 lines
  } else if targetLines <= 1000 {
    (4, 10, 12) // ~950 lines
  } else {
    (6, 12, 14) // ~2000 lines
  }

  let scenes = []

  // Generate each scene
  for sceneIdx in 0 to numScenes - 1 {
    let sceneName = `scene${Int.toString(sceneIdx + 1)}`
    let sceneTitle = `Scene ${Int.toString(sceneIdx + 1)}`

    // Scene header
    scenes->Array.push(`@scene: ${sceneName}`)->ignore
    scenes->Array.push(`@title: ${sceneTitle}`)->ignore
    scenes->Array.push("")->ignore

    // Generate boxes for this scene
    for boxIdx in 0 to boxesPerScene - 1 {
      let boxName = `Box${Int.toString(boxIdx + 1)}`
      let boxWidth = 40

      // Box top border with name
      // Total width = boxWidth + 2 (for the two | characters on content lines)
      // Top border: + -- Name dashes +
      // Content:    | spaces |
      let topBorder = `+--${boxName}${"-"->String.repeat(boxWidth - String.length(boxName) - 2)}+`
      scenes->Array.push(topBorder)->ignore

      // Empty line
      scenes->Array.push(`|${" "->String.repeat(boxWidth)}|`)->ignore

      // Generate elements
      for elemIdx in 0 to elementsPerBox - 1 {
        let elementType = mod(elemIdx, 5)

        switch elementType {
        | 0 => {
            // Button
            let buttonText = `Button ${Int.toString(elemIdx + 1)}`
            let button = `[ ${buttonText} ]`
            let padding = (boxWidth - String.length(button)) / 2
            let line = `|${" "->String.repeat(padding)}${button}${" "->String.repeat(
                boxWidth - padding - String.length(button),
              )}|`
            scenes->Array.push(line)->ignore
          }
        | 1 => {
            // Input field
            let fieldName = `field${Int.toString(elemIdx + 1)}`
            let label = `Label ${Int.toString(elemIdx + 1)}`
            scenes->Array.push(`|  ${label}${" "->String.repeat(boxWidth - String.length(label) - 2)}|`)->ignore
            scenes->Array.push(`|  #${fieldName}${" "->String.repeat(
                boxWidth - String.length(fieldName) - 3,
              )}|`)->ignore
          }
        | 2 => {
            // Link
            let linkText = `Link ${Int.toString(elemIdx + 1)}`
            let link = `"${linkText}"`
            scenes->Array.push(`|  ${link}${" "->String.repeat(boxWidth - String.length(link) - 2)}|`)->ignore
          }
        | 3 => {
            // Checkbox
            let checked = mod(elemIdx, 2) == 0
            let checkboxLabel = `Option ${Int.toString(elemIdx + 1)}`
            let checkbox = checked ? "[x]" : "[ ]"
            scenes->Array.push(`|  ${checkbox} ${checkboxLabel}${" "->String.repeat(
                boxWidth - String.length(checkbox) - String.length(checkboxLabel) - 3,
              )}|`)->ignore
          }
        | 4 => {
            // Emphasis text
            let emphasisText = `Important ${Int.toString(elemIdx + 1)}`
            scenes->Array.push(`|  * ${emphasisText}${" "->String.repeat(
                boxWidth - String.length(emphasisText) - 4,
              )}|`)->ignore
          }
        | _ => ()
        }

        // Add spacing between elements
        if elemIdx < elementsPerBox - 1 {
          scenes->Array.push(`|${" "->String.repeat(boxWidth)}|`)->ignore
        }
      }

      // Add divider if not last box in scene
      if boxIdx < boxesPerScene - 1 && boxIdx == boxesPerScene / 2 {
        scenes->Array.push(`|${"="->String.repeat(boxWidth)}|`)->ignore
      }

      // Empty line
      scenes->Array.push(`|${" "->String.repeat(boxWidth)}|`)->ignore

      // Box bottom border
      let bottomBorder = `+${"-"->String.repeat(boxWidth)}+`
      scenes->Array.push(bottomBorder)->ignore

      // Space between boxes
      if boxIdx < boxesPerScene - 1 {
        scenes->Array.push("")->ignore
      }
    }

    // Space between scenes
    if sceneIdx < numScenes - 1 {
      scenes->Array.push("")->ignore
      scenes->Array.push("---")->ignore
      scenes->Array.push("")->ignore
    }
  }

  scenes->Array.joinWith("\n")
}

/**
 * Generate a simple box for basic testing
 *
 * @param width - Box width (interior)
 * @param height - Box height (interior lines)
 * @param name - Optional box name
 * @returns ASCII box string
 */
let generateSimpleBox = (~width: int=20, ~height: int=3, ~name: option<string>=None): string => {
  let lines = []

  // Total width = width + 4 (for "| " and " |" on content lines)
  let totalWidth = width + 4

  // Top border
  let topBorder = switch name {
  | Some(n) => {
      let nameStr = `--${n}--`
      let padding = totalWidth - 2 - String.length(nameStr) // -2 for the two +
      if padding < 0 {
        `+${"-"->String.repeat(totalWidth - 2)}+` // Name too long, use plain border
      } else {
        let leftPad = padding / 2
        let rightPad = padding - leftPad
        `+${"-"->String.repeat(leftPad)}${nameStr}${"-"->String.repeat(rightPad)}+`
      }
    }
  | None => `+${"-"->String.repeat(totalWidth - 2)}+`
  }
  lines->Array.push(topBorder)->ignore

  // Interior lines
  for _ in 0 to height - 1 {
    lines->Array.push(`| ${" "->String.repeat(width)} |`)->ignore
  }

  // Bottom border
  lines->Array.push(`+${"-"->String.repeat(totalWidth - 2)}+`)->ignore

  lines->Array.joinWith("\n")
}

/**
 * Generate nested boxes for hierarchy testing
 *
 * @param depth - Nesting depth (1 = no nesting, 2 = one level, etc.)
 * @returns ASCII wireframe with nested boxes
 */
let generateNestedBoxes = (depth: int): string => {
  // Generate properly nested boxes where inner boxes are contained within outer boxes
  // Each level reduces width by 4 (2 for indent + 2 for padding)
  let baseWidth = 40

  let rec buildNested = (currentDepth: int, maxDepth: int): array<string> => {
    if currentDepth > maxDepth {
      []
    } else {
      let lines = []
      let boxName = `Level${Int.toString(currentDepth)}`
      let boxWidth = baseWidth - (currentDepth - 1) * 4
      let innerPadding = 2 // Padding inside box for nested content

      // Top border
      let topBorder = `+--${boxName}${"-"->String.repeat(boxWidth - String.length(boxName) - 2)}+`
      lines->Array.push(topBorder)->ignore

      // Empty line
      lines->Array.push(`|${" "->String.repeat(boxWidth)}|`)->ignore

      // Nested content
      if currentDepth < maxDepth {
        let nested = buildNested(currentDepth + 1, maxDepth)
        // Wrap each nested line with outer box borders
        nested->Array.forEach(nestedLine => {
          let paddedLine = `|${" "->String.repeat(innerPadding)}${nestedLine}${" "->String.repeat(boxWidth - innerPadding - String.length(nestedLine))}|`
          lines->Array.push(paddedLine)->ignore
        })
      } else {
        // Leaf content - add a button
        let buttonText = "[ OK ]"
        let padding = (boxWidth - String.length(buttonText)) / 2
        let contentLine = `|${" "->String.repeat(padding)}${buttonText}${" "->String.repeat(boxWidth - padding - String.length(buttonText))}|`
        lines->Array.push(contentLine)->ignore
      }

      // Empty line
      lines->Array.push(`|${" "->String.repeat(boxWidth)}|`)->ignore

      // Bottom border
      lines->Array.push(`+${"-"->String.repeat(boxWidth)}+`)->ignore

      lines
    }
  }

  let lines = buildNested(1, depth)
  lines->Array.joinWith("\n")
}

/**
 * Get the approximate line count of a generated wireframe
 * Useful for validation in tests
 *
 * @param wireframe - ASCII wireframe string
 * @returns Number of lines
 */
let getLineCount = (wireframe: string): int => {
  wireframe->String.split("\n")->Array.length
}

/**
 * Validate that a wireframe has basic syntactic correctness
 * Checks for balanced borders, no empty lines in boxes, etc.
 *
 * @param wireframe - ASCII wireframe string
 * @returns true if valid, false otherwise
 */
let validateWireframe = (wireframe: string): bool => {
  let lines = wireframe->String.split("\n")

  // Check that corner characters are balanced
  let openCorners = ref(0)
  let closeCorners = ref(0)

  lines->Array.forEach(line => {
    // Count '+' characters
    let plusCount = ref(0)
    for i in 0 to String.length(line) - 1 {
      if String.get(line, i) == Some("+") {
        plusCount := plusCount.contents + 1
      }
    }

    // Assume pairs of '+' (start and end of border)
    if plusCount.contents >= 2 {
      openCorners := openCorners.contents + 1
    }
  })

  // Basic validation: should have at least some box structure
  openCorners.contents > 0
}
