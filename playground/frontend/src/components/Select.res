// shadcn Select — wraps @radix-ui/react-select. Class strings, icons and scroll
// buttons reproduced verbatim from the deployed bundle. Single canonical Select
// used across the app (ThemeSelector).
//
// Module shape mirrors the bundle:
//   <Select> .. </Select>          -> Radix Root
//   <Select.Value placeholder />   -> Radix Value
//   <Select.Trigger> .. </>        -> styled Trigger + ChevronDown icon
//   <Select.Content> .. </>        -> Portal + scroll buttons + Viewport
//   <Select.Item value> .. </>     -> styled Item + Check indicator

// ── Radix bindings ──────────────────────────────────────────────────────────

module RadixRoot = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~value: string=?,
    ~defaultValue: string=?,
    ~onValueChange: string => unit=?,
    ~open_: bool=?,
    ~defaultOpen: bool=?,
    ~onOpenChange: bool => unit=?,
    ~name: string=?,
    ~disabled: bool=?,
    ~required: bool=?,
    ~children: React.element,
  ) => React.element = "Root"
}
module RadixValue = {
  @module("@radix-ui/react-select") @react.component
  external make: (~placeholder: string=?) => React.element = "Value"
}
module RadixTrigger = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element) => React.element = "Trigger"
}
module RadixIcon = {
  @module("@radix-ui/react-select") @react.component
  external make: (~asChild: bool=?, ~children: React.element) => React.element = "Icon"
}
module RadixPortal = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element) => React.element = "Portal"
}
module RadixContent = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~className: string=?,
    ~position: string=?,
    ~children: React.element,
  ) => React.element = "Content"
}
module RadixViewport = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element) => React.element = "Viewport"
}
module RadixItem = {
  @module("@radix-ui/react-select") @react.component
  external make: (
    ~value: string,
    ~className: string=?,
    ~disabled: bool=?,
    ~children: React.element,
  ) => React.element = "Item"
}
module RadixItemText = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element) => React.element = "ItemText"
}
module RadixItemIndicator = {
  @module("@radix-ui/react-select") @react.component
  external make: (~children: React.element) => React.element = "ItemIndicator"
}
module RadixScrollUpButton = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element) => React.element = "ScrollUpButton"
}
module RadixScrollDownButton = {
  @module("@radix-ui/react-select") @react.component
  external make: (~className: string=?, ~children: React.element) => React.element =
    "ScrollDownButton"
}

// ── Root ─────────────────────────────────────────────────────────────────────

@react.component
let make = (
  ~value: string=?,
  ~defaultValue: string=?,
  ~onValueChange: string => unit=?,
  ~open_: bool=?,
  ~defaultOpen: bool=?,
  ~onOpenChange: bool => unit=?,
  ~name: string=?,
  ~disabled: bool=?,
  ~required: bool=?,
  ~children: React.element,
) =>
  <RadixRoot
    ?value ?defaultValue ?onValueChange ?open_ ?defaultOpen ?onOpenChange ?name ?disabled ?required>
    children
  </RadixRoot>

// ── Value ─────────────────────────────────────────────────────────────────────

module Value = {
  @react.component
  let make = (~placeholder: string=?) => <RadixValue ?placeholder />
}

// ── Trigger ───────────────────────────────────────────────────────────────────

module Trigger = {
  @react.component
  let make = (~className: string="", ~children: React.element) => {
    let cls = Cn.cn([
      "flex h-9 w-full items-center justify-between whitespace-nowrap rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm ring-offset-background data-[placeholder]:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring disabled:cursor-not-allowed disabled:opacity-50 [&>span]:line-clamp-1",
      className,
    ])
    <RadixTrigger className=cls>
      {<>
        children
        <RadixIcon asChild=true>
          <Lucide.ChevronDown className="h-4 w-4 opacity-50" />
        </RadixIcon>
      </>}
    </RadixTrigger>
  }
}

// ── Scroll buttons ─────────────────────────────────────────────────────────────

module ScrollUpButton = {
  @react.component
  let make = (~className: string="") => {
    let cls = Cn.cn(["flex cursor-default items-center justify-center py-1", className])
    <RadixScrollUpButton className=cls>
      <Lucide.ChevronUp className="h-4 w-4" />
    </RadixScrollUpButton>
  }
}

module ScrollDownButton = {
  @react.component
  let make = (~className: string="") => {
    let cls = Cn.cn(["flex cursor-default items-center justify-center py-1", className])
    <RadixScrollDownButton className=cls>
      <Lucide.ChevronDown className="h-4 w-4" />
    </RadixScrollDownButton>
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

module Content = {
  @react.component
  let make = (~className: string="", ~position: string="popper", ~children: React.element) => {
    let cls = Cn.cn([
      "relative z-50 max-h-[--radix-select-content-available-height] min-w-[8rem] overflow-y-auto overflow-x-hidden rounded-md border bg-popover text-popover-foreground shadow-md data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 origin-[--radix-select-content-transform-origin]",
      position === "popper"
        ? "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"
        : "",
      className,
    ])
    let viewportCls =
      position === "popper"
        ? "p-1 h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)]"
        : "p-1"
    <RadixPortal>
      <RadixContent className=cls position>
        {<>
          <ScrollUpButton />
          <RadixViewport className=viewportCls> children </RadixViewport>
          <ScrollDownButton />
        </>}
      </RadixContent>
    </RadixPortal>
  }
}

// ── Item ──────────────────────────────────────────────────────────────────────

module Item = {
  @react.component
  let make = (
    ~value: string,
    ~className: string="",
    ~disabled: bool=?,
    ~children: React.element,
  ) => {
    let cls = Cn.cn([
      "relative flex w-full cursor-default select-none items-center rounded-sm py-1.5 pl-2 pr-8 text-sm outline-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50",
      className,
    ])
    <RadixItem value className=cls ?disabled>
      {<>
        <span className="absolute right-2 flex h-3.5 w-3.5 items-center justify-center">
          <RadixItemIndicator>
            <Lucide.Check className="h-4 w-4" />
          </RadixItemIndicator>
        </span>
        <RadixItemText> children </RadixItemText>
      </>}
    </RadixItem>
  }
}
