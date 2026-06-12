// shadcn/ui Button — variant + size driven via class-variance-authority style.

type variant = [#default | #destructive | #outline | #secondary | #ghost | #link]
type size = [#default | #sm | #lg | #icon]

let variantClasses = (v: variant): string =>
  switch v {
  | #default => "bg-primary text-primary-foreground hover:bg-primary/90"
  | #destructive => "bg-destructive text-destructive-foreground hover:bg-destructive/90"
  | #outline => "border border-input bg-background hover:bg-accent hover:text-accent-foreground"
  | #secondary => "bg-secondary text-secondary-foreground hover:bg-secondary/80"
  | #ghost => "hover:bg-accent hover:text-accent-foreground"
  | #link => "text-primary underline-offset-4 hover:underline"
  }

let sizeClasses = (s: size): string =>
  switch s {
  | #default => "h-10 px-4 py-2"
  | #sm => "h-9 rounded-md px-3"
  | #lg => "h-11 rounded-md px-8"
  | #icon => "h-10 w-10"
  }

let base = "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50"

@react.component
let make = (
  ~variant: variant=#default,
  ~size: size=#default,
  ~className: string="",
  ~type_: string="button",
  ~disabled: bool=false,
  ~onClick: ReactEvent.Mouse.t => unit=_ => (),
  ~children: React.element,
) => {
  let cls = Cn.cn([base, variantClasses(variant), sizeClasses(size), className])
  <button className={cls} type_ disabled onClick> {children} </button>
}
