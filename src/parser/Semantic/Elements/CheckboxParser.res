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
let make = (): ElementParser.elementParser => {
  ElementParser.make(
    ~priority=85,
    ~canParse=content => {
      // Match either [x] or [ ] patterns
      let checkedPattern = %re("/\[x\]/i")
      let uncheckedPattern = %re("/\[\s*\]/")

      Js.Re.test_(checkedPattern, content) || Js.Re.test_(uncheckedPattern, content)
    },
    ~parse=(content, position, _bounds) => {
      let trimmed = content->String.trim

      // Try to match checked checkbox [x]
      let checkedPattern = %re("/^\[x\]\s*(.*)/i")
      switch Js.Re.exec_(checkedPattern, trimmed) {
      | Some(result) => {
          let captures = Js.Re.captures(result)
          let label = switch captures[1] {
          | Some(labelCapture) =>
              labelCapture
              ->Js.Nullable.toOption
              ->Belt.Option.getWithDefault("")
              ->String.trim
          | None => ""
          }

          Some(
            Types.Checkbox({
              checked: true,
              label: label,
              position: position,
            })
          )
        }
      | None => {
          // Try to match unchecked checkbox [ ]
          let uncheckedPattern = %re("/^\[\s*\]\s*(.*)/")
          switch Js.Re.exec_(uncheckedPattern, trimmed) {
          | Some(result) => {
              let captures = Js.Re.captures(result)
              let label = switch captures[1] {
              | Some(labelCapture) =>
                  labelCapture
                  ->Js.Nullable.toOption
                  ->Belt.Option.getWithDefault("")
                  ->String.trim
              | None => ""
              }

              Some(
                Types.Checkbox({
                  checked: false,
                  label: label,
                  position: position,
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
