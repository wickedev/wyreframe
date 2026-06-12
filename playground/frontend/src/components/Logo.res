// Wyreframe wordmark — "Wyreframe" gradient text + version pill. Optional Link wrapper.

@react.component
let make = (~asLink: bool=false) => {
  let inner =
    <>
      <span className="text-xl font-bold text-gradient-primary"> {React.string("Wyreframe")} </span>
      <span className="text-xs text-muted-foreground font-mono"> {React.string("v0.7.11")} </span>
    </>

  if asLink {
    <Router.Link
      to="/" className="flex items-center gap-2 hover:opacity-80 transition-opacity">
      inner
    </Router.Link>
  } else {
    <div className="flex items-center gap-2"> inner </div>
  }
}
