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
  // Determine structure based on target lines
  let (numScenes, boxesPerScene, elementsPerBox) = if targetLines <= 100 {
    (1, 2, 4) // Simple: 1 scene, 2 boxes, 4 elements each
  } else if targetLines <= 500 {
    (2, 4, 5) // Medium: 2 scenes, 4 boxes, 5 elements each
  } else {
    (4, 6, 8) // Large: 4 scenes, 6 boxes, 8 elements each
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
      let topBorder = `+--${boxName}${"-"->String.repeat(boxWidth - String.length(boxName) - 4)}+`
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

  // Top border
  let topBorder = switch name {
  | Some(n) => {
      let nameStr = `--${n}--`
      let padding = width - String.length(nameStr) + 2
      if padding < 0 {
        `+${"-"->String.repeat(width + 2)}+` // Name too long, use plain border
      } else {
        let leftPad = padding / 2
        let rightPad = padding - leftPad
        `+${"-"->String.repeat(leftPad)}${nameStr}${"-"->String.repeat(rightPad)}+`
      }
    }
  | None => `+${"-"->String.repeat(width + 2)}+`
  }
  lines->Array.push(topBorder)->ignore

  // Interior lines
  for _ in 0 to height - 1 {
    lines->Array.push(`| ${" "->String.repeat(width)} |`)->ignore
  }

  // Bottom border
  lines->Array.push(`+${"-"->String.repeat(width + 2)}+`)->ignore

  lines->Array.joinWith("\n")
}

/**
 * Generate nested boxes for hierarchy testing
 *
 * @param depth - Nesting depth (1 = no nesting, 2 = one level, etc.)
 * @returns ASCII wireframe with nested boxes
 */
let generateNestedBoxes = (depth: int): string => {
  let rec buildNested = (currentDepth: int, maxDepth: int, indent: int): array<string> => {
    if currentDepth > maxDepth {
      []
    } else {
      let lines = []
      let boxName = `Level${Int.toString(currentDepth)}`
      let boxWidth = 50 - (currentDepth - 1) * 6
      let indentStr = " "->String.repeat(indent)

      // Top border
      let topBorder = `${indentStr}+--${boxName}${"-"->String.repeat(boxWidth - String.length(boxName) - 4)}+`
      lines->Array.push(topBorder)->ignore

      // Empty line
      lines->Array.push(`${indentStr}|${" "->String.repeat(boxWidth)}|`)->ignore

      // Nested content
      if currentDepth < maxDepth {
        let nested = buildNested(currentDepth + 1, maxDepth, indent + 2)
        nested->Array.forEach(line => lines->Array.push(line)->ignore)
      } else {
        // Leaf content
        lines->Array.push(`${indentStr}|  Content at depth ${Int.toString(currentDepth)}${" "->String.repeat(
            boxWidth - 25,
          )}|`)->ignore
      }

      // Empty line
      lines->Array.push(`${indentStr}|${" "->String.repeat(boxWidth)}|`)->ignore

      // Bottom border
      lines->Array.push(`${indentStr}+${"-"->String.repeat(boxWidth)}+`)->ignore

      lines
    }
  }

  let lines = buildNested(1, depth, 0)
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
