// LivePreview — parses ASCII via the parent `wyreframe` library, renders the
// resulting HTML into a sandboxed iframe with device + theme toggles.
// (Lighter shape than the original recovered bundle.)

type device = Desktop | Tablet | Mobile

type parseState =
  | Idle
  | Parsing
  | Success({sceneCount: int})
  | Failed({message: string})

// External — wyreframe AST exposes scene metadata. We treat it opaquely and
// use a tiny `%raw` helper to extract scene ids when present.
let extractSceneIds: 'a => array<string> = %raw(`
  function(ast) {
    if (!ast) return [];
    if (Array.isArray(ast.scenes)) {
      return ast.scenes.map(function(s) { return s && (s.id || s.name) || ""; }).filter(Boolean);
    }
    if (Array.isArray(ast.sceneIds)) return ast.sceneIds.slice();
    return [];
  }
`)

let arrayEq = (a: array<string>, b: array<string>): bool => {
  if Array.length(a) !== Array.length(b) {
    false
  } else {
    let i = ref(0)
    let same = ref(true)
    while same.contents && i.contents < Array.length(a) {
      switch (a[i.contents], b[i.contents]) {
      | (Some(x), Some(y)) =>
        if x !== y {
          same := false
        }
      | _ => same := false
      }
      i := i.contents + 1
    }
    same.contents
  }
}

let deviceLabel = (d: device): string =>
  switch d {
  | Desktop => "Desktop"
  | Tablet => "Tablet"
  | Mobile => "Mobile"
  }

let deviceWidth = (d: device): int =>
  switch d {
  | Desktop => 1440
  | Tablet => 768
  | Mobile => 375
  }

let deviceHeight = (d: device): int =>
  switch d {
  | Desktop => 900
  | Tablet => 1024
  | Mobile => 812
  }

let frameClass = (d: device): string =>
  switch d {
  | Desktop => "device-frame-browser"
  | Tablet => "device-frame-tablet"
  | Mobile => "device-frame-mobile"
  }

// Build the full HTML document we write into the iframe. The theme id is
// applied as a CSS class on <body> so site-wide tokens (Theme.res presets)
// can target it.
let buildDocument = (~innerHtml: string, ~theme: string): string => {
  "<!doctype html><html><head><meta charset=\"utf-8\" />" ++
  "<style>" ++
  "html,body{margin:0;padding:0;background:#ffffff;color:#111;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;line-height:1.5;}" ++
  "*{box-sizing:border-box;}" ++
  ".wyreframe-root{padding:16px;}" ++
  "</style></head><body class=\"theme-" ++
  theme ++
  "\"><div class=\"wyreframe-root\">" ++
  innerHtml ++
  "</div></body></html>"
}

@react.component
let make = (
  ~asciiContent: string,
  ~theme: string="clean",
  ~selectedScene: option<string>=?,
  ~onAvailableScenesChange: option<array<string> => unit>=?,
  ~onParseStateChange: option<parseState => unit>=?,
  ~className: string="",
) => {
  let (device, setDevice) = React.useState(() => Desktop)
  let (parseState, setParseState) = React.useState(() => Idle)
  let (renderedHtml, setRenderedHtml) = React.useState(() => "")
  let availableScenesRef = React.useRef([])
  let iframeRef = React.useRef(Nullable.null)

  // Parse + render whenever the ASCII source changes.
  React.useEffect1(() => {
    let trimmed = String.trim(asciiContent)
    if trimmed === "" {
      setParseState(_ => Idle)
      setRenderedHtml(_ => "")
      switch onParseStateChange {
      | Some(cb) => cb(Idle)
      | None => ()
      }
      switch onAvailableScenesChange {
      | Some(cb) =>
        if Array.length(availableScenesRef.current) > 0 {
          availableScenesRef.current = []
          cb([])
        }
      | None => ()
      }
    } else {
      setParseState(_ => Parsing)
      switch onParseStateChange {
      | Some(cb) => cb(Parsing)
      | None => ()
      }
      switch (
        try {
          let ast = Wyreframe.parse(asciiContent)
          let html = Wyreframe.render(ast)
          let scenes = extractSceneIds(ast)
          Ok((html, scenes))
        } catch {
        | Exn.Error(e) =>
          let msg = switch Exn.message(e) {
          | Some(m) => m
          | None => "Parse error"
          }
          Error(msg)
        | _ => Error("Unknown parse error")
        }
      ) {
      | Ok((html, scenes)) =>
        setRenderedHtml(_ => html)
        let state = Success({sceneCount: Array.length(scenes)})
        setParseState(_ => state)
        switch onParseStateChange {
        | Some(cb) => cb(state)
        | None => ()
        }
        switch onAvailableScenesChange {
        | Some(cb) =>
          if !arrayEq(availableScenesRef.current, scenes) {
            availableScenesRef.current = scenes
            cb(scenes)
          }
        | None => ()
        }
      | Error(msg) =>
        let state = Failed({message: msg})
        setParseState(_ => state)
        switch onParseStateChange {
        | Some(cb) => cb(state)
        | None => ()
        }
      }
    }
    None
  }, [asciiContent])

  // Push the rendered HTML into the sandboxed iframe whenever it (or the
  // theme / selectedScene) changes. We use srcDoc rather than mutating the
  // contentDocument so React stays the source of truth.
  let docSrc = React.useMemo3(() => {
    if renderedHtml === "" {
      ""
    } else {
      let sceneAttr = switch selectedScene {
      | Some(id) =>
        "<script>document.body.setAttribute('data-active-scene'," ++
        "'" ++ id ++ "');</script>"
      | None => ""
      }
      buildDocument(~innerHtml=renderedHtml ++ sceneAttr, ~theme)
    }
  }, (renderedHtml, theme, selectedScene))

  let deviceBtn = (target: device, icon: React.element, tooltip: string) => {
    let active = target === device
    let cls =
      "p-1.5 rounded-md transition-all " ++
      (active
        ? "bg-[hsl(265_90%_65%/0.2)] text-[hsl(265_90%_70%)]"
        : "text-muted-foreground hover:text-foreground hover:bg-[hsl(220_20%_95%/0.08)]")
    <button
      key={deviceLabel(target)}
      type_="button"
      className={cls}
      title={tooltip}
      ariaLabel={tooltip}
      onClick={_ => setDevice(_ => target)}>
      {icon}
    </button>
  }

  let isEmpty = String.trim(asciiContent) === ""

  let frameInner =
    isEmpty
      ? <div
          className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground text-sm">
          <Lottie
            path="/animations/empty-state.json"
            loop={true}
            autoplay={true}
            style={ReactDOM.Style.make(~width="280px", ~height="280px", ())}
          />
          <span className="mt-2 text-xs opacity-70">
            {React.string("No content to preview")}
          </span>
        </div>
      : <iframe
          ref={ReactDOM.Ref.domRef(
            Obj.magic(iframeRef): React.ref<Nullable.t<Dom.element>>,
          )}
          title="wyreframe-preview"
          srcDoc={docSrc}
          sandbox="allow-same-origin"
          className="w-full h-full bg-white border-0"
          style={ReactDOM.Style.make(~width="100%", ~height="100%", ())}
        />

  let statusLabel = switch parseState {
  | Idle => "Idle"
  | Parsing => "Parsing…"
  | Success({sceneCount}) =>
    sceneCount === 1
      ? "1 scene"
      : Int.toString(sceneCount) ++ " scenes"
  | Failed({message: _}) => "Error"
  }

  let statusDotClass = switch parseState {
  | Idle => "bg-muted-foreground/40"
  | Parsing => "bg-warning animate-pulse"
  | Success(_) => "bg-emerald-500"
  | Failed(_) => "bg-destructive"
  }

  let errorBar = switch parseState {
  | Failed({message}) =>
    <div
      role="alert"
      className="shrink-0 border-t border-[hsl(220_20%_95%/0.08)] px-3 py-2 bg-[hsl(230_25%_8%/0.6)]">
      <div className="flex items-center gap-2">
        <span className="w-2 h-2 rounded-full bg-destructive animate-pulse" />
        <span className="text-xs font-medium text-destructive">
          {React.string("Parse error")}
        </span>
        <span className="text-xs text-muted-foreground truncate">
          {React.string(message)}
        </span>
      </div>
    </div>
  | _ => React.null
  }

  let rootCls = Cn.cn([
    "relative flex flex-col h-full bg-card border border-[hsl(220_20%_95%/0.08)] rounded-lg overflow-hidden",
    className,
  ])

  <div className={rootCls}>
    <div
      className="shrink-0 flex items-center justify-between gap-2 px-3 py-2 border-b border-[hsl(220_20%_95%/0.08)]">
      <div className="flex items-center gap-2 min-w-0">
        <span className={"w-2 h-2 rounded-full " ++ statusDotClass} />
        <span className="text-xs font-medium text-foreground">
          {React.string("Live Preview")}
        </span>
        <span className="text-xs text-muted-foreground truncate">
          {React.string(" · Fast ASCII Parsing · Multi-Device Preview")}
        </span>
        <span className="text-xs text-muted-foreground/70 hidden sm:inline">
          {React.string("· " ++ statusLabel)}
        </span>
      </div>
      <div
        className="flex items-center bg-[hsl(220_20%_95%/0.05)] rounded-lg p-0.5">
        {deviceBtn(Desktop, <Lucide.Monitor size={16} />, "Desktop (1440px)")}
        {deviceBtn(Tablet, <Lucide.PanelsTopLeft size={16} />, "Tablet (768px)")}
        {deviceBtn(Mobile, <Lucide.Layers size={16} />, "Mobile (375px)")}
      </div>
    </div>
    <div
      className="flex-1 relative overflow-auto flex items-center justify-center bg-[hsl(220_20%_4%/0.4)] p-6">
      <div
        className={frameClass(device) ++ " relative bg-white shadow-lg"}
        style={ReactDOM.Style.make(
          ~width=Int.toString(deviceWidth(device)) ++ "px",
          ~height=Int.toString(deviceHeight(device)) ++ "px",
          ~maxWidth="100%",
          ~maxHeight="100%",
          ~transition="width 200ms ease-in-out, height 200ms ease-in-out",
          (),
        )}>
        {frameInner}
      </div>
    </div>
    {errorBar}
  </div>
}
