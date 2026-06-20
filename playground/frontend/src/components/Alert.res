// shadcn/ui Alert — Root + Title + Description, variant driven via
// class-variance-authority style (replicated in ReScript like Badge/Button).

type variant = [#default | #destructive]

let base = "relative w-full rounded-lg border px-4 py-3 text-sm [&>svg+div]:translate-y-[-3px] [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 [&>svg]:text-foreground [&>svg~*]:pl-7"

let variantClasses = (v: variant): string =>
  switch v {
  | #default => "bg-background text-foreground"
  | #destructive => "border-destructive/50 text-destructive dark:border-destructive [&>svg]:text-destructive"
  }

@react.component
let make = (~variant: variant=#default, ~className: string="", ~children: React.element) =>
  <div role="alert" className={Cn.cn([base, variantClasses(variant), className])}>
    {children}
  </div>

module Title = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <h5 className={Cn.cn(["mb-1 font-medium leading-none tracking-tight", className])}>
      {children}
    </h5>
}

module Description = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div className={Cn.cn(["text-sm [&_p]:leading-relaxed", className])}> {children} </div>
}
