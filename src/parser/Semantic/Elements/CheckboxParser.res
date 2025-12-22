// CheckboxParser.res
// Parser for checkbox syntax "[x]" (checked) and "[ ]" (unchecked)

/**
 * Creates a checkbox element parser.
 *
 * Recognizes:
 * - "[x]" - Checked checkbox
 * - "[ ]" - Unchecked checkbox
 *
 * Optionally followed by label text on the same line.
 *
 * Priority: 85 (high - should be checked before text parser but after buttons)
 *
 * Examples:
 * - "[x] Accept terms" -> Checkbox(checked=true, label="Accept terms")
 * - "[ ] Subscribe" -> Checkbox(checked=false, label="Subscribe")
 * - "[x]" -> Checkbox(checked=true, label="")
 */
// Pattern for detecting checkboxes (used in canParse)
let checkedTestPattern = %re("/\[x\]/i")
let uncheckedTestPattern = %re("/\[\s*\]/")

// Patterns for parsing (capturing label)
let checkedParsePattern = %re("/^\[x\]\s*(.*)/i")
let uncheckedParsePattern = %re("/^\[\s*\]\s*(.*)/")

let make = (): ElementParser.elementParser => {
  ElementParser.make(
    ~priority=85,
    ~canParse=content => {
      // Match either [x] or [ ] patterns
      checkedTestPattern->RegExp.test(content) || uncheckedTestPattern->RegExp.test(content)
    },
    ~parse=(content, position, _bounds) => {
      let trimmed = content->String.trim

      // Try to match checked checkbox [x]
      switch checkedParsePattern->RegExp.exec(trimmed) {
      | Some(result) => {
          let matches = result->RegExp.Result.matches
          let label = switch matches[0] {
          | Some(labelStr) => labelStr->String.trim
          | None => ""
          }

          Some(
            Types.Checkbox({
              checked: true,
              label: label,
              position: Types.Position.make(position.row, position.col),
            })
          )
        }
      | None => {
          // Try to match unchecked checkbox [ ]
          switch uncheckedParsePattern->RegExp.exec(trimmed) {
          | Some(result) => {
              let matches = result->RegExp.Result.matches
              let label = switch matches[0] {
              | Some(labelStr) => labelStr->String.trim
              | None => ""
              }

              Some(
                Types.Checkbox({
                  checked: false,
                  label: label,
                  position: Types.Position.make(position.row, position.col),
                })
              )
            }
          | None => None
          }
        }
      }
    }
  )
}
