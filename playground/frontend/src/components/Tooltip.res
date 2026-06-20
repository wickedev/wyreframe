// shadcn Tooltip — wraps @radix-ui/react-tooltip. Class strings reproduced
// verbatim from the deployed bundle. This is the single canonical Tooltip used
// across the app (LivePreview, ThemeSelector).
//
// Module shape mirrors the bundle:
//   <Tooltip> .. </Tooltip>            -> Radix Root
//   <Tooltip.Trigger> .. </>           -> Radix Trigger (asChild defaults true)
//   <Tooltip.Content> .. </>           -> Portal + styled Content
//   <Tooltip.Provider> .. </>          -> Radix Provider (app already wraps in main.tsx)

// ── Radix bindings ──────────────────────────────────────────────────────────

module RadixProvider = {
  @module("@radix-ui/react-tooltip") @react.component
  external make: (
    ~delayDuration: int=?,
    ~skipDelayDuration: int=?,
    ~children: React.element,
  ) => React.element = "Provider"
}
module RadixRoot = {
  @module("@radix-ui/react-tooltip") @react.component
  external make: (
    ~open_: bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~delayDuration: int=?,
    ~children: React.element,
  ) => React.element = "Root"
}
module RadixTrigger = {
  @module("@radix-ui/react-tooltip") @react.component
  external make: (~asChild: bool=?, ~children: React.element) => React.element = "Trigger"
}
module RadixPortal = {
  @module("@radix-ui/react-tooltip") @react.component
  external make: (~children: React.element) => React.element = "Portal"
}
module RadixContent = {
  @module("@radix-ui/react-tooltip") @react.component
  external make: (
    ~className: string=?,
    ~sideOffset: int=?,
    ~side: string=?,
    ~align: string=?,
    ~children: React.element,
  ) => React.element = "Content"
}

// ── Provider (exposed for completeness; app root supplies one in main.tsx) ───

module Provider = {
  @react.component
  let make = (~delayDuration: int=400, ~skipDelayDuration: int=300, ~children: React.element) =>
    <RadixProvider delayDuration skipDelayDuration> children </RadixProvider>
}

// ── Root ─────────────────────────────────────────────────────────────────────

@react.component
let make = (
  ~open_: bool=?,
  ~defaultOpen: bool=?,
  ~onOpenChange: bool => unit=?,
  ~delayDuration: int=?,
  ~children: React.element,
) => <RadixRoot ?open_ ?defaultOpen ?onOpenChange ?delayDuration> children </RadixRoot>

// ── Trigger ───────────────────────────────────────────────────────────────────

module Trigger = {
  @react.component
  let make = (~asChild: bool=true, ~children: React.element) =>
    <RadixTrigger asChild> children </RadixTrigger>
}

// ── Content ───────────────────────────────────────────────────────────────────

module Content = {
  @react.component
  let make = (
    ~className: string="",
    ~sideOffset: int=4,
    ~side: string=?,
    ~align: string=?,
    ~children: React.element,
  ) => {
    let cls = Cn.cn([
      "z-50 overflow-hidden rounded-md bg-primary px-3 py-1.5 text-xs text-primary-foreground animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 origin-[--radix-tooltip-content-transform-origin]",
      className,
    ])
    <RadixPortal>
      <RadixContent className=cls sideOffset ?side ?align> children </RadixContent>
    </RadixPortal>
  }
}
