// shadcn/ui Label — wraps Radix Label primitive.

let base = "text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"

@react.component
let make = (
  ~htmlFor: string=?,
  ~className: string="",
  ~children: React.element,
) =>
  <label ?htmlFor className={Cn.cn([base, className])}>
    {children}
  </label>
