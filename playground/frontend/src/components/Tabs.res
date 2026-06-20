// shadcn/ui Tabs — Root + List + Trigger + Content.
// @radix-ui/react-tabs is NOT a dependency of this project, so the Radix behavior is
// reproduced with a local React context (uncontrolled tab group). Class strings are
// verbatim from the deployed bundle's shadcn Tabs wrappers.
//
// data-state / role / aria-selected must reach the DOM so the verbatim
// `data-[state=active]:*` classes fire, which the typed JSX DOM props can't express —
// hence the small raw element builders below.
%%raw(`
import { jsx as _jsx } from "react/jsx-runtime";
function tabsTrigger(p) {
  return _jsx("button", {
    type: "button", role: "tab", "data-state": p.state,
    "aria-selected": p.selected, className: p.className,
    onClick: p.onClick, children: p.children,
  });
}
function tabsPanel(p) {
  return _jsx("div", {
    role: "tabpanel", "data-state": "active",
    className: p.className, children: p.children,
  });
}
`)
@val
external tabsTrigger: {
  "state": string,
  "selected": bool,
  "className": string,
  "onClick": ReactEvent.Mouse.t => unit,
  "children": React.element,
} => React.element = "tabsTrigger"
@val
external tabsPanel: {"className": string, "children": React.element} => React.element = "tabsPanel"

let context: React.Context.t<(string, string => unit)> = React.createContext(("", _ => ()))

module Provider = {
  let make = React.Context.provider(context)
}

@react.component
let make = (~className: string="", ~defaultValue: string, ~children: React.element) => {
  let (value, setValue) = React.useState(() => defaultValue)
  <div className>
    <Provider value=(value, v => setValue(_ => v))> {children} </Provider>
  </div>
}

module List = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div
      role="tablist"
      className={Cn.cn([
        "inline-flex h-9 items-center justify-center rounded-lg bg-muted p-1 text-muted-foreground",
        className,
      ])}>
      {children}
    </div>
}

module Trigger = {
  @react.component
  let make = (~value: string, ~className: string="", ~children: React.element) => {
    let (active, setValue) = React.useContext(context)
    let state = active == value ? "active" : "inactive"
    tabsTrigger({
      "state": state,
      "selected": active == value,
      "className": Cn.cn([
        "inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1 text-sm font-medium ring-offset-background transition-all focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 data-[state=active]:bg-background data-[state=active]:text-foreground data-[state=active]:shadow",
        className,
      ]),
      "onClick": _ => setValue(value),
      "children": children,
    })
  }
}

module Content = {
  @react.component
  let make = (~value: string, ~className: string="", ~children: React.element) => {
    let (active, _) = React.useContext(context)
    if active == value {
      tabsPanel({
        "className": Cn.cn([
          "mt-2 ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
          className,
        ]),
        "children": children,
      })
    } else {
      React.null
    }
  }
}
