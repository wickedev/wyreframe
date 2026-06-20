// Theme picker — a shadcn Select (12 design-system presets) wrapped in a
// Tooltip ("Design System"). Faithfully reconstructed from the deployed bundle.
//
// NOTE: the project's `Theme.res` module only carries the lightweight
// presets/load/save surface, so the richer theme model the bundle's
// ThemeSelector depends on (the 12-case `theme` variant + helpers) is kept
// local here. The shadcn Select / Tooltip wrappers now live in their own shared
// modules (Select.res / Tooltip.res).

// Theme model (variant + helpers) lives in the shared Theme module so the
// ThemeSelector and LivePreview agree on a single `theme` type.
open Theme

// ---------------------------------------------------------------------------
// Lucide icons not already exposed by the shared Lucide binding
// ---------------------------------------------------------------------------

module Instagram = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Instagram"
}
module Apple = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Apple"
}
module AppWindow = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "AppWindow"
}
module Component = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Component"
}
module Zap = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Zap"
}
module CreditCard = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "CreditCard"
}
module Music = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Music"
}

let renderThemeIcon = (t: theme, size: int): React.element =>
  switch t {
  | Default => <Lucide.PanelsTopLeft size />
  | Instagram => <Instagram size />
  | MaterialDesign => <Lucide.Layers size />
  | AppleHIG => <Apple size />
  | FluentUI => <AppWindow size />
  | AntDesign => <Component size />
  | Linear => <Zap size />
  | Notion => <Lucide.FileText size />
  | GitHub => <Lucide.Github size />
  | Stripe => <CreditCard size />
  | Discord => <Lucide.MessageCircle size />
  | Spotify => <Music size />
  }

// shadcn Select / Tooltip are now the shared `Select` (Select.res) and
// `Tooltip` (Tooltip.res) modules.

// ---------------------------------------------------------------------------
// ThemeSelector
// ---------------------------------------------------------------------------

@react.component
let make = (~currentTheme: theme, ~onThemeChange: theme => unit) => {
  let options = getThemeOptions()

  <div className="flex items-center">
    <Tooltip>
      {<>
        <Tooltip.Trigger>
          <div>
            <Select
              value={themeToString(currentTheme)}
              onValueChange={s =>
                switch themeFromString(s) {
                | Some(t) => onThemeChange(t)
                | None => ()
                }}>
              {<>
                <Select.Trigger className="h-8 px-2 gap-1.5 text-xs bg-[hsl(220_20%_95%/0.05)] border-0 hover:bg-[hsl(220_20%_95%/0.1)] focus:ring-1 focus:ring-[hsl(265_90%_65%/0.5)] min-w-[100px]">
                  <Select.Value placeholder="Theme" />
                </Select.Trigger>
                <Select.Content className="min-w-[160px]">
                  {options
                  ->Array.map(((t, info)) =>
                    <Select.Item key={info.id} value={info.id}>
                      <div className="flex items-center gap-2">
                        {renderThemeIcon(t, 14)}
                        <div className="flex flex-col">
                          <span className="text-sm"> {React.string(info.name)} </span>
                        </div>
                      </div>
                    </Select.Item>
                  )
                  ->React.array}
                </Select.Content>
              </>}
            </Select>
          </div>
        </Tooltip.Trigger>
        <Tooltip.Content> {React.string("Design System")} </Tooltip.Content>
      </>}
    </Tooltip>
  </div>
}
