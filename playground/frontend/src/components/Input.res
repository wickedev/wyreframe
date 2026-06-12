// shadcn/ui Input.

let base = "flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

@react.component
let make = (
  ~type_: string="text",
  ~value: string=?,
  ~defaultValue: string=?,
  ~placeholder: string=?,
  ~className: string="",
  ~disabled: bool=false,
  ~onChange: ReactEvent.Form.t => unit=_ => (),
  ~onKeyDown: ReactEvent.Keyboard.t => unit=_ => (),
  ~name: string=?,
  ~id: string=?,
) =>
  <input
    ?id ?name type_ ?value ?defaultValue ?placeholder disabled
    className={Cn.cn([base, className])} onChange onKeyDown
  />
