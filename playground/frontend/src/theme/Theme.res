// Canonical theme model — the 12 design-system presets surfaced by the
// ThemeSelector and applied by LivePreview. Faithfully reconstructed from the
// deployed bundle (theme variant + helpers + the `wyreframe-theme-preference`
// sessionStorage state and the `useTheme` hook).

type theme =
  | Default
  | Instagram
  | MaterialDesign
  | AppleHIG
  | FluentUI
  | AntDesign
  | Linear
  | Notion
  | GitHub
  | Stripe
  | Discord
  | Spotify

type themeInfo = {
  id: string,
  name: string,
  description: string,
  icon: string,
}

let availableThemes: array<theme> = [
  Default,
  Instagram,
  MaterialDesign,
  AppleHIG,
  FluentUI,
  AntDesign,
  Linear,
  Notion,
  GitHub,
  Stripe,
  Discord,
  Spotify,
]

let themeToString = (t: theme): string =>
  switch t {
  | Default => "default"
  | Instagram => "instagram"
  | MaterialDesign => "material"
  | AppleHIG => "apple"
  | FluentUI => "fluent"
  | AntDesign => "antdesign"
  | Linear => "linear"
  | Notion => "notion"
  | GitHub => "github"
  | Stripe => "stripe"
  | Discord => "discord"
  | Spotify => "spotify"
  }

let themeFromString = (s: string): option<theme> =>
  switch String.toLowerCase(s) {
  | "antdesign" => Some(AntDesign)
  | "apple" => Some(AppleHIG)
  | "default" => Some(Default)
  | "discord" => Some(Discord)
  | "fluent" => Some(FluentUI)
  | "github" => Some(GitHub)
  | "instagram" => Some(Instagram)
  | "linear" => Some(Linear)
  | "material" => Some(MaterialDesign)
  | "notion" => Some(Notion)
  | "spotify" => Some(Spotify)
  | "stripe" => Some(Stripe)
  | _ => None
  }

let getThemeClassName = (t: theme): string =>
  switch t {
  | Default => "theme-default"
  | Instagram => "theme-instagram"
  | MaterialDesign => "theme-material"
  | AppleHIG => "theme-apple"
  | FluentUI => "theme-fluent"
  | AntDesign => "theme-antdesign"
  | Linear => "theme-linear"
  | Notion => "theme-notion"
  | GitHub => "theme-github"
  | Stripe => "theme-stripe"
  | Discord => "theme-discord"
  | Spotify => "theme-spotify"
  }

let defaultThemeInfo: themeInfo = {
  id: "default",
  name: "Default",
  description: "Clean wireframe style",
  icon: "layout",
}

let themeInfoMap: Dict.t<themeInfo> = Dict.fromArray([
  ("default", defaultThemeInfo),
  ("instagram", {id: "instagram", name: "Instagram", description: "Instagram design system", icon: "instagram"}),
  ("material", {id: "material", name: "Material", description: "Google Material Design", icon: "material"}),
  ("apple", {id: "apple", name: "Apple", description: "Apple Human Interface", icon: "apple"}),
  ("fluent", {id: "fluent", name: "Fluent", description: "Microsoft Fluent UI", icon: "fluent"}),
  ("antdesign", {id: "antdesign", name: "Ant Design", description: "Alibaba Ant Design", icon: "antdesign"}),
  ("linear", {id: "linear", name: "Linear", description: "Linear App Style", icon: "linear"}),
  ("notion", {id: "notion", name: "Notion", description: "Notion Style", icon: "notion"}),
  ("github", {id: "github", name: "GitHub", description: "GitHub Style", icon: "github"}),
  ("stripe", {id: "stripe", name: "Stripe", description: "Stripe Fintech Style", icon: "stripe"}),
  ("discord", {id: "discord", name: "Discord", description: "Discord Style", icon: "discord"}),
  ("spotify", {id: "spotify", name: "Spotify", description: "Spotify Style", icon: "spotify"}),
])

let getThemeInfo = (t: theme): themeInfo =>
  switch Dict.get(themeInfoMap, themeToString(t)) {
  | Some(info) => info
  | None => defaultThemeInfo
  }

let getThemeOptions = (): array<(theme, themeInfo)> =>
  availableThemes->Array.map(t => (t, getThemeInfo(t)))

// ── Persisted theme state (sessionStorage, JSON) ────────────────────────────

type themeState = {
  current: theme,
  info: themeInfo,
}

let defaultThemeState: themeState = {current: Default, info: defaultThemeInfo}

let storageKey = "wyreframe-theme-preference"

let ssGet: string => Nullable.t<string> = %raw(`(k) => { try { return sessionStorage.getItem(k) } catch { return null } }`)
let ssSet: (string, string) => unit = %raw(`(k, v) => { try { sessionStorage.setItem(k, v) } catch {} }`)
let now: unit => float = %raw(`() => Date.now()`)

let saveThemeState = (state: themeState): unit => {
  let payload = Dict.fromArray([
    ("theme", JSON.Encode.string(themeToString(state.current))),
    ("timestamp", JSON.Encode.float(now())),
  ])
  ssSet(storageKey, JSON.stringify(JSON.Encode.object(payload)))
}

let loadThemeState = (): option<themeState> =>
  switch ssGet(storageKey)->Nullable.toOption {
  | None => None
  | Some(raw) =>
    switch JSON.parseExn(raw) {
    | json =>
      switch JSON.Decode.object(json) {
      | Some(obj) =>
        let name =
          obj
          ->Dict.get("theme")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("default")
        switch themeFromString(name) {
        | Some(t) => Some({current: t, info: getThemeInfo(t)})
        | None => None
        }
      | None => None
      }
    | exception _ => None
    }
  }

// React hook: `let (themeState, setTheme) = Theme.useTheme()`.
let useTheme = (): (themeState, theme => unit) => {
  let (state, setState) = React.useState(() => loadThemeState()->Option.getOr(defaultThemeState))
  let setTheme = React.useCallback1(t => {
    let next = {current: t, info: getThemeInfo(t)}
    setState(_ => next)
    saveThemeState(next)
  }, [setState])
  (state, setTheme)
}
