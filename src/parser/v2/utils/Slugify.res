// Slugify.res
// Convert arbitrary text to kebab-case identifiers.
// Any character that is NOT alphanumeric (ASCII) and NOT a wide-character
// codepoint (≥ U+0080, covering CJK identifier-like content) is treated
// as a separator. This handles `/`, `#`, `@`, `.`, `,`, etc.

let slugify = (text: string): string => {
  let trimmed = String.trim(text)
  if trimmed == "" {
    "empty"
  } else {
    let lower = String.toLowerCase(trimmed)
    // Replace any run of "non-identifier" chars with a single hyphen.
    // -￿ preserves CJK and other wide characters verbatim.
    let withDashes =
      lower->String.replaceRegExp(%re("/[^a-z0-9-￿]+/g"), "-")
    let collapsed = withDashes->String.replaceRegExp(%re("/-+/g"), "-")
    let stripped =
      collapsed->String.replaceRegExp(%re("/^-+|-+$/g"), "")
    stripped == "" ? "empty" : stripped
  }
}
