// EmojiRegistry.res
// Shortcode → unicode emoji mapping. 14 default shortcodes per REQ-13.3.

// IMPORTANT: build the default dict in a function rather than holding a
// shared `defaults: Dict.t<string>`. A shared dict gets mutated by
// `register`, so a subsequent `reset()` would just point back to an
// already-polluted "defaults". Constructing a fresh dict per call keeps
// the canonical defaults stable.
let buildDefaults = (): Dict.t<string> => {
  let d = Dict.make()
  Dict.set(d, "check", "✔")
  Dict.set(d, "cross", "✘")
  Dict.set(d, "warning", "⚠")
  Dict.set(d, "info", "ℹ")
  Dict.set(d, "heart", "❤")
  Dict.set(d, "star", "\u{2B50}")
  Dict.set(d, "search", "\u{1F50D}")
  Dict.set(d, "settings", "⚙")
  Dict.set(d, "user", "\u{1F464}")
  Dict.set(d, "home", "\u{1F3E0}")
  Dict.set(d, "mail", "✉")
  Dict.set(d, "bell", "\u{1F514}")
  Dict.set(d, "lock", "\u{1F512}")
  Dict.set(d, "bow", "\u{1F647}")
  d
}

let mutableRegistry: ref<Dict.t<string>> = ref(buildDefaults())

let lookup = (shortcode: string): option<string> =>
  Dict.get(mutableRegistry.contents, shortcode)

let register = (shortcode: string, emoji: string): unit => {
  Dict.set(mutableRegistry.contents, shortcode, emoji)
}

let reset = (): unit => {
  mutableRegistry := buildDefaults()
}

// Per-parse lookup: a `parseOptions.emojiRegistry` (a `Dict.t<string>`) is
// consulted first, then the module-default registry. Returns None if neither
// has the shortcode. Pure — never mutates global state.
//
// JS callers may pass `null` for an option field; the ReScript option
// encoding (None = undefined) doesn't catch null, so we guard explicitly.
let isNullOverride: option<Dict.t<string>> => bool = %raw(`
  function(o) { return o === null; }
`)

let lookupWithOverride = (
  overrides: option<Dict.t<string>>,
  shortcode: string,
): option<string> => {
  switch overrides {
  | Some(d) when !isNullOverride(overrides) =>
    switch Dict.get(d, shortcode) {
    | Some(_) as found => found
    | None => lookup(shortcode)
    }
  | _ => lookup(shortcode)
  }
}
