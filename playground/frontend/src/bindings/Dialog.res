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

// Raw Radix `Content`/`Title`/`Description` primitives. These are the building
// blocks for the shadcn-styled composites below (which reuse the `Content`,
// `Title` and `Description` names), so the raw bindings are suffixed to avoid a
// module-name clash inside this file.
module ContentPrimitive = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~className: string=?,
    ~onEscapeKeyDown: 'a => unit=?,
    ~onInteractOutside: 'a => unit=?,
    ~children: React.element,
  ) => React.element = "Content"
}

module TitlePrimitive = {
  @module("@radix-ui/react-dialog") @react.component
  external make: (
    ~className: string=?,
    ~children: React.element,
  ) => React.element = "Title"
}

module DescriptionPrimitive = {
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

// ── shadcn Dialog composites (wrappers around the Radix primitives) ─────────
// Mirrors the deployed bundle's single `Dialog` namespace which holds both the
// Radix root/trigger/portal primitives AND the shadcn-styled composites.

// `Content` wraps Portal + Overlay + the raw Radix Content (with the styled
// container) and appends the absolute-positioned close button.
module Content = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <Portal>
      <Overlay
        className="fixed inset-0 z-50 bg-black/80 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"
      />
      <ContentPrimitive
        className={Cn.cn([
          "fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border bg-background p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%] sm:rounded-lg",
          className,
        ])}>
        <>
          {children}
          <Close
            className="absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground">
            <>
              <Lucide.X className="h-4 w-4" />
              <span className="sr-only"> {React.string("Close")} </span>
            </>
          </Close>
        </>
      </ContentPrimitive>
    </Portal>
}

module Header = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div className={Cn.cn(["flex flex-col space-y-1.5 text-center sm:text-left", className])}>
      {children}
    </div>
}

module Footer = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div
      className={Cn.cn(["flex flex-col-reverse sm:flex-row sm:justify-end sm:space-x-2", className])}>
      {children}
    </div>
}

module Title = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <TitlePrimitive
      className={Cn.cn(["text-lg font-semibold leading-none tracking-tight", className])}>
      {children}
    </TitlePrimitive>
}

module Description = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <DescriptionPrimitive className={Cn.cn(["text-sm text-muted-foreground", className])}>
      {children}
    </DescriptionPrimitive>
}
