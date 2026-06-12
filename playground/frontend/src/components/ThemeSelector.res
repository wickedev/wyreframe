// Theme picker dropdown — switches between Theme.presets and persists to
// localStorage via Theme.save. Controlled component: parent owns `value`.

let triggerClass = "h-8 px-2 gap-1.5 text-xs bg-[hsl(220_20%_95%/0.05)] border-0 hover:bg-[hsl(220_20%_95%/0.1)] focus:outline-none focus:ring-1 focus:ring-[hsl(265_90%_65%/0.5)] min-w-[140px] rounded-md text-foreground cursor-pointer"

@react.component
let make = (
  ~value: string,
  ~onChange: string => unit,
  ~className: string="",
) => {
  let handleChange = (e: ReactEvent.Form.t) => {
    let target = ReactEvent.Form.target(e)
    let nextId: string = target["value"]
    Theme.save(nextId)
    onChange(nextId)
  }

  <div className={Cn.cn(["flex items-center", className])} title="Design System">
    <select
      className=triggerClass
      value
      onChange=handleChange
      ariaLabel="Design System">
      {Theme.presets
      ->Array.map(preset =>
        <option key={preset.id} value={preset.id}>
          {React.string(preset.name)}
        </option>
      )
      ->React.array}
    </select>
  </div>
}
