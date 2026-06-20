// Public landing page at `/`. Hero with an animated-placeholder prompt box that
// sends the idea to `/playground`, quick suggestion chips, and feature cards.

type promptSuggestion = {
  icon: string,
  label: string,
  prompt: string,
}

let promptSuggestions = [
  {
    icon: "🔐",
    label: "Login Form",
    prompt: "Create a modern login page with email and password fields, social login buttons, and a forgot password link",
  },
  {
    icon: "💳",
    label: "Pricing Table",
    prompt: "Design a pricing table with 3 tiers: Free, Pro, and Enterprise with feature comparisons",
  },
  {
    icon: "👤",
    label: "User Profile",
    prompt: "Build a user profile card with avatar, name, bio, stats, and action buttons",
  },
  {
    icon: "📊",
    label: "Dashboard",
    prompt: "Create a dashboard with stat cards, a chart area, and a recent activity list",
  },
  {
    icon: "🛒",
    label: "Product Card",
    prompt: "Design an e-commerce product card with image, title, price, rating, and add to cart button",
  },
]

let placeholderIdeas = [
  "A modern login page with social auth...",
  "Dashboard with analytics charts...",
  "E-commerce product listing grid...",
  "User profile with activity feed...",
  "Pricing table with 3 tiers...",
  "Navigation bar with dropdown menus...",
  "Contact form with validation...",
  "Blog post card layout...",
]

type cardColor = Purple | Cyan | Pink

type colorStyle = {
  bg: string,
  border: string,
  text: string,
  glow: string,
}

let colorStyles = color =>
  switch color {
  | Purple => {
      bg: "bg-[hsl(265_90%_65%/0.1)]",
      border: "border-[hsl(265_90%_65%/0.2)]",
      text: "text-[hsl(265_90%_70%)]",
      glow: "group-hover:shadow-[0_0_20px_hsl(265_90%_65%/0.2)]",
    }
  | Cyan => {
      bg: "bg-[hsl(200_90%_50%/0.1)]",
      border: "border-[hsl(200_90%_50%/0.2)]",
      text: "text-[hsl(200_90%_60%)]",
      glow: "group-hover:shadow-[0_0_20px_hsl(200_90%_50%/0.2)]",
    }
  | Pink => {
      bg: "bg-[hsl(320_90%_60%/0.1)]",
      border: "border-[hsl(320_90%_60%/0.2)]",
      text: "text-[hsl(320_90%_70%)]",
      glow: "group-hover:shadow-[0_0_20px_hsl(320_90%_60%/0.2)]",
    }
  }

module FeatureCard = {
  @react.component
  let make = (~icon: React.element, ~title: string, ~description: string, ~color: cardColor) => {
    let t = colorStyles(color)
    <div
      className={"group glass border border-[hsl(220_20%_95%/0.08)] rounded-xl p-5 transition-all duration-300 hover:border-[hsl(220_20%_95%/0.15)] " ++
      t.glow}>
      <div
        className={"inline-flex items-center justify-center w-10 h-10 rounded-lg " ++
        t.bg ++
        " " ++
        t.border ++
        " border " ++
        t.text ++ " mb-3"}>
        {icon}
      </div>
      <h3 className="text-sm font-semibold text-foreground mb-1"> {React.string(title)} </h3>
      <p className="text-xs text-muted-foreground leading-relaxed">
        {React.string(description)}
      </p>
    </div>
  }
}

@react.component
let make = () => {
  let navigate = Router.useNavigateWithState()

  let (value, setValue) = React.useState(() => "")
  let (creating, setCreating) = React.useState(() => false)
  let textareaRef = React.useRef(Nullable.null)
  let (placeholder, setPlaceholder) = React.useState(() => "")
  let (ideaIndex, setIdeaIndex) = React.useState(() => 0)
  let (deleting, setDeleting) = React.useState(() => false)

  // Autofocus the textarea on mount.
  React.useEffect0(() => {
    switch textareaRef.current->Nullable.toOption {
    | Some(el) => (el->Obj.magic)["focus"]()
    | None => ()
    }
    None
  })

  // Typewriter animation cycling through `placeholderIdeas` while the textarea
  // is empty.
  React.useEffect4(() => {
    if value !== "" {
      None
    } else {
      let current = placeholderIdeas->Array.get(ideaIndex)->Option.getOr("")
      let speed = deleting ? 30 : 80
      let pause = deleting ? 500 : 2000
      let timeout = Js.Global.setTimeout(() => {
        if deleting {
          if placeholder->String.length > 0 {
            setPlaceholder(_ => current->String.slice(~start=0, ~end=placeholder->String.length - 1))
          } else {
            setDeleting(_ => false)
            setIdeaIndex(n => mod(n + 1, placeholderIdeas->Array.length))
          }
        } else if placeholder->String.length < current->String.length {
          setPlaceholder(_ => current->String.slice(~start=0, ~end=placeholder->String.length + 1))
        } else {
          let _ = Js.Global.setTimeout(() => setDeleting(_ => true), pause)
        }
      }, placeholder->String.length === current->String.length ? pause : speed)
      Some(() => Js.Global.clearTimeout(timeout))
    }
  }, (placeholder, ideaIndex, deleting, value))

  // Auto-resize the textarea up to 120px.
  React.useEffect1(() => {
    switch textareaRef.current->Nullable.toOption {
    | Some(el) =>
      let style = (el->Obj.magic)["style"]
      style["height"] = "auto"
      let scrollHeight: int = (el->Obj.magic)["scrollHeight"]
      style["height"] = Js.Math.min_int(scrollHeight, 120)->Int.toString ++ "px"
    | None => ()
    }
    None
  }, [value])

  let handleCreate = text => {
    if text->String.trim !== "" && !creating {
      setCreating(_ => true)
      navigate("/playground", {state: {"initialPrompt": text->String.trim}})
    }
  }

  let onKeyDown = (e: ReactEvent.Keyboard.t) => {
    if ReactEvent.Keyboard.key(e) === "Enter" && !ReactEvent.Keyboard.shiftKey(e) {
      ReactEvent.Keyboard.preventDefault(e)
      handleCreate(value)
    }
  }

  <div className="min-h-screen gradient-mesh relative overflow-hidden flex flex-col">
    // Decorative background blobs
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      <div
        className="absolute -top-40 -left-40 w-80 h-80 bg-[hsl(265_90%_50%/0.15)] rounded-full blur-[100px] animate-pulse"
      />
      <div
        className="absolute top-1/4 -right-20 w-96 h-96 bg-[hsl(200_90%_50%/0.12)] rounded-full blur-[120px] animate-pulse"
        style={ReactDOM.Style.make(~animationDelay="1s", ())}
      />
      <div
        className="absolute -bottom-20 left-1/4 w-72 h-72 bg-[hsl(320_90%_50%/0.1)] rounded-full blur-[100px] animate-pulse"
        style={ReactDOM.Style.make(~animationDelay="2s", ())}
      />
      <div
        className="absolute bottom-1/3 right-1/4 w-64 h-64 bg-[hsl(180_90%_45%/0.08)] rounded-full blur-[80px] animate-pulse"
        style={ReactDOM.Style.make(~animationDelay="1.5s", ())}
      />
    </div>
    // Top nav
    <nav
      className="h-16 glass-strong border-b border-[hsl(220_20%_95%/0.08)] flex items-center justify-between px-6 flex-shrink-0 relative z-10">
      <Logo />
      <div className="flex items-center gap-3">
        <a
          className="p-2 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-[hsl(220_20%_95%/0.08)]"
          title="npm"
          href="https://www.npmjs.com/package/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          <Lucide.Package size={20} />
        </a>
        <a
          className="p-2 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-[hsl(220_20%_95%/0.08)]"
          title="GitHub"
          href="https://github.com/wickedev/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          <Lucide.Github size={20} />
        </a>
      </div>
    </nav>
    // Hero
    <main
      className="flex-1 flex flex-col items-center justify-center px-4 py-12 relative z-10">
      <div className="text-center mb-10 max-w-3xl">
        <div
          className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full border border-[hsl(265_90%_65%/0.3)] bg-[hsl(265_90%_65%/0.1)] mb-6">
          <span className="relative flex h-2 w-2">
            <span
              className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[hsl(265_90%_65%)] opacity-75"
            />
            <span
              className="relative inline-flex rounded-full h-2 w-2 bg-[hsl(265_90%_65%)]"
            />
          </span>
          <span className="text-xs font-medium text-[hsl(265_90%_75%)]">
            {React.string("Open Source ASCII Wireframe Parser")}
          </span>
        </div>
        <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-5">
          <span className="text-gradient-primary"> {React.string("What would you like")} </span>
          <br />
          <span className="text-foreground"> {React.string("to wireframe?")} </span>
        </h1>
        <p className="text-lg md:text-xl text-muted-foreground max-w-xl mx-auto leading-relaxed">
          {React.string("Describe your UI idea and watch it come to life with ")}
          <span className="text-[hsl(200_90%_60%)]"> {React.string("ASCII-powered")} </span>
          {React.string(" wireframes")}
        </p>
      </div>
      // Prompt box
      <div className="w-full max-w-2xl mb-10">
        <div
          className="relative border-gradient-animated rounded-2xl overflow-hidden glow-multi transition-all duration-300 hover:scale-[1.01]">
          <div className="bg-[hsl(230_25%_8%)] rounded-2xl p-1">
            <textarea
              ref={ReactDOM.Ref.domRef(textareaRef)}
              className="w-full min-h-[60px] max-h-[120px] px-6 py-4 pr-32 bg-transparent text-foreground placeholder:text-muted-foreground/50 resize-none outline-none ring-0 border-0 focus:outline-none focus:ring-0 text-base disabled:opacity-50"
              disabled={creating}
              placeholder={placeholder !== "" ? placeholder : "Describe your wireframe idea..."}
              rows={1}
              value={value}
              onKeyDown={onKeyDown}
              onChange={e => {
                let v = (e->ReactEvent.Form.target)["value"]
                setValue(_ => v)
              }}
            />
            <button
              className="absolute right-4 bottom-4 bg-gradient-to-r from-[hsl(265_90%_60%)] via-[hsl(280_85%_55%)] to-[hsl(320_90%_60%)] text-white hover:opacity-90 disabled:opacity-40 disabled:cursor-not-allowed rounded-xl px-5 py-2.5 font-medium transition-all text-sm flex items-center gap-2 shadow-lg shadow-[hsl(265_90%_50%/0.3)]"
              disabled={value->String.trim === "" || creating}
              onClick={_ => handleCreate(value)}>
              {creating
                ? <>
                    <span
                      className="animate-spin h-4 w-4 border-2 border-white/30 border-t-white rounded-full"
                    />
                    {React.string("Creating...")}
                  </>
                : <>
                    {React.string("Create")}
                    <svg
                      className="w-4 h-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24">
                      <path
                        d="M13 7l5 5m0 0l-5 5m5-5H6"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </>}
            </button>
          </div>
        </div>
        <p className="text-xs text-muted-foreground/50 text-center mt-3">
          {React.string("Press ")}
          <kbd className="px-1.5 py-0.5 rounded bg-secondary/50 text-muted-foreground text-[10px] font-mono">
            {React.string("Enter")}
          </kbd>
          {React.string(" to create · ")}
          <kbd className="px-1.5 py-0.5 rounded bg-secondary/50 text-muted-foreground text-[10px] font-mono">
            {React.string("Shift+Enter")}
          </kbd>
          {React.string(" for new line")}
        </p>
        <div className="flex flex-wrap items-center justify-center gap-2 mt-5">
          {promptSuggestions
          ->Array.map(s =>
            <button
              key={s.label}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 glass border border-[hsl(220_20%_95%/0.08)] hover:border-[hsl(265_90%_65%/0.3)] hover:bg-[hsl(265_90%_65%/0.1)] rounded-full text-xs text-muted-foreground hover:text-foreground transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed group"
              disabled={creating}
              onClick={_ => {
                setValue(_ => s.prompt)
                switch textareaRef.current->Nullable.toOption {
                | Some(el) => (el->Obj.magic)["focus"]()
                | None => ()
                }
              }}>
              <span className="group-hover:scale-110 transition-transform">
                {React.string(s.icon)}
              </span>
              <span> {React.string(s.label)} </span>
            </button>
          )
          ->React.array}
        </div>
      </div>
      // Feature cards
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 max-w-3xl w-full mt-8">
        <FeatureCard
          icon={<svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24">
            <path
              d="M13 10V3L4 14h7v7l9-11h-7z"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.5"
            />
          </svg>}
          title="Real-time Preview"
          description="See your wireframe update instantly as you refine your idea"
          color={Purple}
        />
        <FeatureCard
          icon={<svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24">
            <path
              d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.5"
            />
          </svg>}
          title="Multi-Device"
          description="Preview designs across desktop, tablet, and mobile views"
          color={Cyan}
        />
        <FeatureCard
          icon={<svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24">
            <path
              d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.5"
            />
          </svg>}
          title="ASCII-Powered"
          description="Clean, accessible wireframes using intuitive ASCII syntax"
          color={Pink}
        />
      </div>
    </main>
    // Footer
    <footer
      className="py-6 px-4 text-center relative z-10 border-t border-[hsl(220_20%_95%/0.05)]">
      <p className="text-sm text-muted-foreground/50">
        {React.string("Powered by ")}
        <a
          className="text-[hsl(200_90%_60%)] hover:text-[hsl(200_90%_70%)] transition-colors"
          href="https://www.npmjs.com/package/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          {React.string("wyreframe")}
        </a>
        {React.string(" · Fast ASCII Parsing · Multi-Device Preview")}
      </p>
    </footer>
  </div>
}
