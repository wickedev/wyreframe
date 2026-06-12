// Theme presets that drive the LivePreview's visual style. The three theme
// names below are the ones surfaced in the original deployment (UI strings
// preserved in the recovered bundle).

type theme = {
  id: string,
  name: string,
  description: string,
}

let presets: array<theme> = [
  {
    id: "clean",
    name: "Clean wireframe style",
    description: "Minimal, no-frills wireframe rendering — strict line work.",
  },
  {
    id: "apple",
    name: "Apple Human Interface",
    description: "iOS / macOS visual language with SF Pro-style spacing.",
  },
  {
    id: "ant",
    name: "Alibaba Ant Design",
    description: "Ant Design tokens — dense data tables, square corners.",
  },
]

let storageKey = "wyreframe-theme-preference"

let load = (): string => {
  switch Global.lsGet(storageKey)->Nullable.toOption {
  | Some(v) => v
  | None => "clean"
  }
}

let save = (id: string): unit => Global.lsSet(storageKey, id)
