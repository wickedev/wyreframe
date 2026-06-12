// Radix UI Dialog primitives (used for modals, the issue reporter etc).

module Root = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~open_: bool=?,
    ~onOpenChange: bool => unit=?,
    ~children: React.element,
  ) => React.element = "Root"
}

module Trigger = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~asChild: bool=?,
    ~children: React.element,
  ) => React.element = "Trigger"
}

module Portal = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (~children: React.element) => React.element = "Portal"
}

module Overlay = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (~className: string=?) => React.element = "Overlay"
}

module Content = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~className: string=?,
    ~onEscapeKeyDown: 'a => unit=?,
    ~onInteractOutside: 'a => unit=?,
    ~children: React.element,
  ) => React.element = "Content"
}

module Title = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "Title"
}

module Description = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "Description"
}

module Close = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~asChild: bool=?,
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "Close"
}
