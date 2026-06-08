// EscapeUtils.res
// Handle escape sequences inside string literals: \" \\ \$
// Per REQ-12.4, REQ-12.5, REQ-12.6.

// Process one escape character given the char immediately after `\`.
// Returns (Some(decoded_char), 2_chars_consumed) on success, None otherwise.
let processEscapeChar = (c: string): option<string> =>
  switch c {
  | "\"" => Some("\"")
  | "\\" => Some("\\")
  | "$" => Some("$")
  | "n" => Some("\n")
  | "t" => Some("\t")
  | _ => None
  }

// Unescape a whole string. Unknown escapes pass through verbatim (`\x` → `\x`).
let unescapeString = (s: string): string => {
  let n = String.length(s)
  let out = ref("")
  let i = ref(0)
  while i.contents < n {
    let ch = String.charAt(s, i.contents)
    if ch == "\\" && i.contents + 1 < n {
      let next = String.charAt(s, i.contents + 1)
      switch processEscapeChar(next) {
      | Some(decoded) => {
          out := out.contents ++ decoded
          i := i.contents + 2
        }
      | None => {
          out := out.contents ++ ch
          i := i.contents + 1
        }
      }
    } else {
      out := out.contents ++ ch
      i := i.contents + 1
    }
  }
  out.contents
}
