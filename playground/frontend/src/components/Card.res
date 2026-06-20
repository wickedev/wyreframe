// shadcn/ui Card — Root + Header + Title + Content.
// Class strings are verbatim from the deployed bundle (function Card / Card$Header /
// Card$Title / Card$Content). The bundle defines no Description or Footer submodule.

@react.component
let make = (~className: string="", ~children: React.element) =>
  <div className={Cn.cn(["rounded-xl border bg-card text-card-foreground shadow", className])}>
    {children}
  </div>

module Header = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div className={Cn.cn(["flex flex-col space-y-1.5 p-6", className])}> {children} </div>
}

module Title = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div className={Cn.cn(["font-semibold leading-none tracking-tight", className])}>
      {children}
    </div>
}

module Content = {
  @react.component
  let make = (~className: string="", ~children: React.element) =>
    <div className={Cn.cn(["p-6 pt-0", className])}> {children} </div>
}
