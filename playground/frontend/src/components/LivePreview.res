// LivePreview — renders a parsed `wyreframe` AST into the DOM with device-frame
// switching (Desktop / Tablet / Mobile), zoom, undo/redo scene history, theme
// selection, an error/warning bar, and a Lottie empty-state. Faithfully
// reconstructed from the deployed bundle.

// ── Domain model (theme + viewport + zoom) ──────────────────────────────────
// The theme variant + helpers live in the shared Theme module.
open Theme

type viewport = Desktop | Tablet | Mobile

type dimensions = {
  width: int,
  height: int,
}

type viewportState = {
  current: viewport,
  zoom: float,
  dimensions: dimensions,
}

let viewportToString = (v: viewport): string =>
  switch v {
  | Desktop => "Desktop"
  | Tablet => "Tablet"
  | Mobile => "Mobile"
  }

let viewportFromString = (s: string): option<viewport> =>
  switch s {
  | "Desktop" => Some(Desktop)
  | "Mobile" => Some(Mobile)
  | "Tablet" => Some(Tablet)
  | _ => None
  }

let getViewportDimensions = (v: viewport): dimensions =>
  switch v {
  | Desktop => {width: 1440, height: 900}
  | Tablet => {width: 768, height: 1064}
  | Mobile => {width: 375, height: 773}
  }

let getViewportLabel = (v: viewport): string =>
  viewportToString(v) ++ " (" ++ Int.toString(getViewportDimensions(v).width) ++ "px)"

let zoomLevels: array<float> = [0.5, 0.75, 1.0, 1.25, 1.5]

let getNextZoomLevel = (z: float): option<float> => {
  let i = zoomLevels->Array.findIndex(n => n === z)
  if i >= 0 && i < Array.length(zoomLevels) - 1 {
    zoomLevels[i + 1]
  } else {
    None
  }
}

let getPreviousZoomLevel = (z: float): option<float> => {
  let i = zoomLevels->Array.findIndex(n => n === z)
  if i > 0 {
    zoomLevels[i - 1]
  } else {
    None
  }
}

let formatZoomPercentage = (z: float): string =>
  Int.toString(Float.toInt(z *. 100.0)) ++ "%"

// Screen-reader live-region announcements.
let announce: string => unit = %raw(`
  function(msg) {
    var id = "sr-announcer";
    var el = document.getElementById(id);
    if (el == null) {
      el = document.createElement("div");
      el.id = id;
      el.setAttribute("aria-live", "polite");
      el.setAttribute("aria-atomic", "true");
      el.style.position = "absolute";
      el.style.width = "1px";
      el.style.height = "1px";
      el.style.padding = "0";
      el.style.margin = "-1px";
      el.style.overflow = "hidden";
      el.style.clip = "rect(0,0,0,0)";
      el.style.whiteSpace = "nowrap";
      el.style.border = "0";
      document.body.appendChild(el);
    }
    el.textContent = "";
    setTimeout(function() { el.textContent = msg; }, 100);
  }
`)

let announceViewportChange = (label: string, width: int, height: int, zoom: float): unit => {
  let pct = Float.toInt(zoom *. 100.0)
  announce(
    "Viewport changed to " ++
    label ++
    ": " ++
    Int.toString(width) ++
    " by " ++
    Int.toString(height) ++
    " pixels, zoom " ++
    Int.toString(pct) ++
    " percent",
  )
}

let announceZoomChange = (zoom: float): unit =>
  announce("Zoom level changed to " ++ Int.toString(Float.toInt(zoom *. 100.0)) ++ " percent")

// ── Errors / warnings ───────────────────────────────────────────────────────

// Opaque parsed-wireframe AST handed to the interactive renderer.
type ast

type parseError = {
  title: string,
  message: string,
  line: option<int>,
  column: option<int>,
}

type deadEndInfo = {
  sceneId: string,
  elementId: string,
  elementText: string,
  elementType: string,
}

// ── Interactive renderer (parent `wyreframe` library, DOM surface) ──────────
// `render(ast, opts)` returns { root, sceneManager }. We expose a typed wrapper
// matching the bundle's renderToDOMWithOptions plus the scene manager methods.

type sceneManager
type renderResult =
  | SuccessWithManager(Dom.element, sceneManager)
  | RenderErrorWithManager(string)

// ESM import of the parent `wyreframe` library (browser has no `require`).
%%raw(`import * as WyreframeLib from "wyreframe"`)

let renderToDOMWithOptions: (
  ast,
  (option<string>, string) => unit,
  option<deadEndInfo => unit>,
) => renderResult = %raw(`
  function(ast, onSceneChange, onDeadEndClick) {
    try {
      var lib = WyreframeLib;
      var d = lib.render(ast, {
        interactive: true,
        injectStyles: true,
        onSceneChange: onSceneChange,
        onDeadEndClick: onDeadEndClick
      });
      d.root.classList.add("font-mono");
      return { TAG: "SuccessWithManager", _0: d.root, _1: d.sceneManager };
    } catch (c) {
      return { TAG: "RenderErrorWithManager", _0: "Unexpected error during rendering" };
    }
  }
`)

let smGetCurrentScene: sceneManager => option<string> = %raw(`function(sm){ return sm.getCurrentScene(); }`)
let smGetSceneIds: sceneManager => array<string> = %raw(`function(sm){ return sm.getSceneIds(); }`)
let smGoto: (sceneManager, string) => unit = %raw(`function(sm, id){ sm.goto(id); }`)

// ── Missing Lucide icons (not yet in Lucide.res) ────────────────────────────
module Wrench = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Wrench"
}
module WandSparkles = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "WandSparkles"
}
module Undo2 = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "Undo2"
}

// ── Tooltip: now the shared `Tooltip` module (Tooltip.res) ──────────────────

// ── Scene history (undo / redo) ─────────────────────────────────────────────
type history = {
  past: array<string>,
  current: option<string>,
  future: array<string>,
  initialScene: option<string>,
}

// DOM measurement helpers — capture/restore scroll, ResizeObserver, scene query.
let captureScroll: (Js.Nullable.t<Dom.element>, React.ref<array<float>>) => unit = %raw(`
  function(el, ref) {
    if (el == null) return;
    ref.current = [el.scrollTop, el.scrollLeft];
  }
`)
let restoreScroll: (Js.Nullable.t<Dom.element>, React.ref<array<float>>) => unit = %raw(`
  function(el, ref) {
    if (el == null) return;
    el.scrollTop = ref.current[0];
    el.scrollLeft = ref.current[1];
  }
`)
let observeResize: (Js.Nullable.t<Dom.element>, (float, float) => unit) => (unit => unit) = %raw(`
  function(el, cb) {
    if (el == null) return function(){};
    var ro = new ResizeObserver(function(entries) {
      var e = entries[0];
      if (e === undefined) return;
      var r = e.contentRect;
      cb(r.width, r.height);
    });
    ro.observe(el);
    return function(){ ro.disconnect(); };
  }
`)
let querySelectorEl: (Dom.element, string) => Js.Nullable.t<Dom.element> = %raw(`
  function(el, sel) { return el.querySelector(sel); }
`)
let setInnerHtmlEmpty: Dom.element => unit = %raw(`function(el){ el.innerHTML = ""; }`)
let appendChildEl: (Dom.element, Dom.element) => unit = %raw(`function(p, c){ p.appendChild(c); }`)

@react.component
let make = (
  ~ast: option<ast>=?,
  ~viewport: viewportState,
  ~theme: option<theme>=?,
  ~errors: option<array<parseError>>=?,
  ~error: option<parseError>=?,
  ~onViewportChange: viewport => unit,
  ~onZoomChange: float => unit,
  ~onThemeChange: option<theme => unit>=?,
  ~onCurrentSceneChange: option<string => unit>=?,
  ~onDeadEndClick: option<deadEndInfo => unit>=?,
  ~onWyreframeFix: option<unit => unit>=?,
  ~onRequestFix: option<string => unit>=?,
  ~onReportIssue: option<unit => unit>=?,
) => {
  let activeTheme = switch theme {
  | Some(t) => t
  | None => Default
  }
  let themeClass = getThemeClassName(activeTheme)

  let containerRef = React.useRef(Js.Nullable.null)
  let savedScroll = React.useRef([0.0, 0.0])
  let (isPending, startTransition) = React.useTransition()
  let renderedElRef = React.useRef(Js.Nullable.null)
  let sceneManagerRef = React.useRef(None)

  let (history, setHistory) = React.useState(() => {
    past: [],
    current: None,
    future: [],
    initialScene: None,
  })
  let isNavigatingRef = React.useRef(false)
  let (containerSize, setContainerSize) = React.useState(() => (0.0, 0.0))
  let (errorsExpanded, setErrorsExpanded) = React.useState(() => false)
  let (isFixing, setIsFixing) = React.useState(() => false)

  let canUndo = Array.length(history.past) > 0
  let canRedo = Array.length(history.future) > 0
  let undoCount = Array.length(history.past)
  let redoCount = Array.length(history.future)

  let handleUndo = () => {
    if canUndo {
      let len = Array.length(history.past)
      switch history.past[len - 1] {
      | None => ()
      | Some(target) =>
        isNavigatingRef.current = true
        setHistory(h => {
          let cur = h.current
          {
            past: h.past->Array.slice(~start=0, ~end=len - 1),
            current: Some(target),
            future: switch cur {
            | Some(c) => Array.concat([c], h.future)
            | None => h.future
            },
            initialScene: h.initialScene,
          }
        })
        switch sceneManagerRef.current {
        | Some(sm) => smGoto(sm, target)
        | None => ()
        }
      }
    }
  }

  let handleRedo = () => {
    if canRedo {
      switch history.future[0] {
      | None => ()
      | Some(target) =>
        isNavigatingRef.current = true
        setHistory(h => {
          let cur = h.current
          {
            past: switch cur {
            | Some(c) => Array.concat(h.past, [c])
            | None => h.past
            },
            current: Some(target),
            future: h.future->Array.slice(~start=1, ~end=Array.length(h.future)),
            initialScene: h.initialScene,
          }
        })
        switch sceneManagerRef.current {
        | Some(sm) => smGoto(sm, target)
        | None => ()
        }
      }
    }
  }

  let handleRefresh = () => {
    switch history.current {
    | None => ()
    | Some(cur) =>
      isNavigatingRef.current = true
      switch sceneManagerRef.current {
      | Some(sm) => smGoto(sm, cur)
      | None => ()
      }
    }
  }

  let handleHome = () => {
    switch history.initialScene {
    | None => ()
    | Some(initial) =>
      isNavigatingRef.current = true
      setHistory(h => {
        past: [],
        current: Some(initial),
        future: [],
        initialScene: h.initialScene,
      })
      switch sceneManagerRef.current {
      | Some(sm) => smGoto(sm, initial)
      | None => ()
      }
    }
  }

  let canGoHome = switch (history.current, history.initialScene) {
  | (Some(c), Some(i)) => c !== i
  | _ => false
  }

  // Observe the preview container size.
  React.useEffect0(() => {
    let cleanup = observeResize(containerRef.current, (w, h) => setContainerSize(_ => (w, h)))
    Some(cleanup)
  })

  // Render the AST into the .preview-content node whenever it changes.
  React.useEffect2(() => {
    let containerN = containerRef.current
    switch ast {
    | None => ()
    | Some(astVal) =>
      switch Js.Nullable.toOption(containerN) {
      | None => ()
      | Some(container) =>
        captureScroll(containerN, savedScroll)
        startTransition(() => {
          switch Js.Nullable.toOption(querySelectorEl(container, ".preview-content")) {
          | None => ()
          | Some(previewContent) =>
            let onSceneChange = (from: option<string>, to: string) => {
              switch onCurrentSceneChange {
              | Some(cb) => cb(to)
              | None => ()
              }
              if isNavigatingRef.current {
                isNavigatingRef.current = false
                setHistory(h => {
                  past: h.past,
                  current: Some(to),
                  future: h.future,
                  initialScene: h.initialScene,
                })
              } else {
                setHistory(h =>
                  switch from {
                  | Some(f) if f !== to => {
                      past: Array.concat(h.past, [f]),
                      current: Some(to),
                      future: [],
                      initialScene: h.initialScene,
                    }
                  | _ => {
                      past: h.past,
                      current: Some(to),
                      future: h.future,
                      initialScene: h.initialScene,
                    }
                  }
                )
              }
            }
            let result = renderToDOMWithOptions(astVal, onSceneChange, onDeadEndClick)
            switch result {
            | SuccessWithManager(el, manager) =>
              setInnerHtmlEmpty(previewContent)
              appendChildEl(previewContent, el)
              renderedElRef.current = Js.Nullable.return(el)
              let cur = smGetCurrentScene(manager)
              let sceneIds = smGetSceneIds(manager)
              let first = sceneIds[0]
              sceneManagerRef.current = Some(manager)
              setHistory(_ => {
                past: [],
                current: switch cur {
                | Some(_) => cur
                | None => first
                },
                future: [],
                initialScene: first,
              })
              restoreScroll(containerN, savedScroll)
            | RenderErrorWithManager(_) => ()
            }
          }
        })
      }
    }
    None
  }, (ast, viewport.current))

  let handleViewportChange = (s: string) => {
    switch viewportFromString(s) {
    | None => ()
    | Some(v) =>
      onViewportChange(v)
      let dims = getViewportDimensions(v)
      announceViewportChange(getViewportLabel(v), dims.width, dims.height, viewport.zoom)
    }
  }

  let handleZoomIn = () => {
    switch getNextZoomLevel(viewport.zoom) {
    | Some(z) =>
      onZoomChange(z)
      announceZoomChange(z)
    | None => ()
    }
  }

  let handleZoomOut = () => {
    switch getPreviousZoomLevel(viewport.zoom) {
    | Some(z) =>
      onZoomChange(z)
      announceZoomChange(z)
    | None => ()
    }
  }

  // Compute the scaled frame dimensions.
  let frameW = Int.toFloat(viewport.dimensions.width)
  let frameH = Int.toFloat(viewport.dimensions.height)
  let zoom = viewport.zoom
  let aspect = frameW /. frameH
  let (cW, cH) = containerSize

  let (scaledW, scaledH) = if cW > 0.0 && cH > 0.0 {
    if cW /. cH > aspect {
      let h = cH *. 0.95 *. zoom
      (h *. aspect, h)
    } else {
      let w = cW *. 0.95 *. zoom
      (w, w /. aspect)
    }
  } else {
    (400.0, 300.0)
  }
  let scale = scaledW /. 600.0

  let previewContentStyle = (~top: string) =>
    ReactDOM.Style.make(
      ~height=Float.toString(600.0 /. aspect) ++ "px",
      ~left="0",
      ~position="absolute",
      ~top,
      ~transform="scale(" ++ Float.toString(scale) ++ ")",
      ~transformOrigin="top left",
      ~transition="transform 200ms ease-in-out",
      ~width="600px",
      (),
    )

  let emptyState = (~size: string) =>
    <div
      className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground text-sm">
      <Lottie
        path="/animations/empty-state.json"
        loop=true
        autoplay=true
        style={ReactDOM.Style.make(~width=size, ~height=size, ())}
      />
      <span className="mt-2 text-xs opacity-70">
        {React.string(Option.isSome(error) ? "Fix errors to see preview" : "No content to preview")}
      </span>
    </div>

  let frameContentStyle =
    ReactDOM.Style.make(
      ~height=Float.toString(scaledH) ++ "px",
      ~transition="width 200ms ease-in-out, height 200ms ease-in-out",
      ~width=Float.toString(scaledW) ++ "px",
      (),
    )

  let deviceFrame = switch viewport.current {
  | Desktop =>
    <div
      key="desktop-frame"
      className="device-frame-browser"
      style={ReactDOM.Style.make(~transition="all 200ms ease-in-out", ())}>
      <div className="device-frame-browser-toolbar">
        <div className="device-frame-browser-dots">
          <div className="device-frame-browser-dot device-frame-browser-dot-red" />
          <div className="device-frame-browser-dot device-frame-browser-dot-yellow" />
          <div className="device-frame-browser-dot device-frame-browser-dot-green" />
        </div>
        <div className="device-frame-browser-url">
          <Lucide.Lock className="text-white/40" size=10 />
          <span className="device-frame-browser-url-text"> {React.string("wyreframe.studio")} </span>
        </div>
      </div>
      <div className={"device-frame-browser-content bg-white " ++ themeClass} style={frameContentStyle}>
        {switch ast {
        | Some(_) =>
          <div
            className={"preview-content font-mono bg-white overflow-y-auto overflow-x-hidden " ++ themeClass}
            style={previewContentStyle(~top="0")}
          />
        | None => emptyState(~size="360px")
        }}
      </div>
    </div>
  | Tablet =>
    <div
      key="tablet-frame"
      className="device-frame-tablet"
      style={ReactDOM.Style.make(~transition="all 200ms ease-in-out", ())}>
      <div className={"device-frame-tablet-screen " ++ themeClass} style={frameContentStyle}>
        {switch ast {
        | Some(_) =>
          <div
            className={"preview-content font-mono bg-white overflow-y-auto overflow-x-hidden " ++ themeClass}
            style={previewContentStyle(~top="0")}
          />
        | None => emptyState(~size="300px")
        }}
      </div>
    </div>
  | Mobile =>
    <div
      key="mobile-frame"
      className="device-frame-mobile"
      style={ReactDOM.Style.make(~transition="all 200ms ease-in-out", ())}>
      <div className="device-frame-mobile-volume" />
      <div className="device-frame-mobile-volume-2" />
      <div className={"device-frame-mobile-screen " ++ themeClass} style={frameContentStyle}>
        <div className="device-frame-mobile-notch" />
        <div className="device-frame-mobile-home-indicator" />
        {switch ast {
        | Some(_) =>
          <div
            className={"preview-content font-mono bg-white overflow-y-auto overflow-x-hidden " ++ themeClass}
            style={previewContentStyle(~top="40px")}
          />
        | None =>
          <div
            className="absolute inset-0 flex flex-col items-center justify-center text-muted-foreground text-sm pt-10 pb-5">
            <Lottie
              path="/animations/empty-state.json"
              loop=true
              autoplay=true
              style={ReactDOM.Style.make(~width="240px", ~height="240px", ())}
            />
            <span className="mt-2 text-xs opacity-70">
              {React.string(
                Option.isSome(error) ? "Fix errors to see preview" : "No content to preview",
              )}
            </span>
          </div>
        }}
      </div>
    </div>
  }

  // Collect the list of errors/warnings to render.
  let allErrors = switch errors {
  | Some(es) =>
    if Array.length(es) > 0 {
      es
    } else {
      switch error {
      | Some(e) => [e]
      | None => []
      }
    }
  | None =>
    switch error {
    | Some(e) => [e]
    | None => []
    }
  }
  let errorCount = Array.length(allErrors)

  let errorBar = if errorCount > 0 {
    let first = allErrors->Array.getUnsafe(0)
    let warningCount = allErrors->Array.filter(e => e.title === "Warning")->Array.length
    let realErrorCount = errorCount - warningCount
    let onlyWarnings = warningCount > 0 && realErrorCount === 0
    let mixed = warningCount > 0 && realErrorCount > 0
    let dotClass = mixed || onlyWarnings ? "bg-warning" : "bg-destructive"
    let textClass = mixed || onlyWarnings ? "text-warning" : "text-destructive"
    let summary = if mixed {
      Int.toString(realErrorCount) ++
      " Error" ++
      (realErrorCount > 1 ? "s" : "") ++
      ", " ++
      Int.toString(warningCount) ++
      " Warning" ++
      (warningCount > 1 ? "s" : "")
    } else if onlyWarnings {
      Int.toString(warningCount) ++ " Warning" ++ (warningCount > 1 ? "s" : "")
    } else {
      Int.toString(realErrorCount) ++ " Error" ++ (realErrorCount > 1 ? "s" : "")
    }
    let lineLabel = switch (first.line, first.column) {
    | (Some(l), Some(c)) => "Line " ++ Int.toString(l) ++ ":" ++ Int.toString(c)
    | (Some(l), None) => "Line " ++ Int.toString(l)
    | _ => ""
    }

    <div
      ariaLive=#polite
      className="shrink-0 border-t border-[hsl(220_20%_95%/0.08)]"
      role="alert">
      <div
        className="w-full flex items-center gap-2 px-3 py-1.5 bg-[hsl(230_25%_8%/0.6)] cursor-pointer hover:bg-[hsl(230_25%_12%/0.8)] transition-all"
        role="button"
        tabIndex=0
        onKeyDown={e => {
          let key = ReactEvent.Keyboard.key(e)
          if key === "Enter" || key === " " {
            ReactEvent.Keyboard.preventDefault(e)
            setErrorsExpanded(prev => !prev)
          }
        }}
        onClick={_ => setErrorsExpanded(prev => !prev)}>
        <span className={"w-2 h-2 rounded-full " ++ dotClass ++ " animate-pulse"} />
        <span className={"text-xs font-medium " ++ textClass}> {React.string(summary)} </span>
        {lineLabel !== "" && errorCount === 1
          ? <span className="text-xs text-muted-foreground"> {React.string(lineLabel)} </span>
          : React.null}
        <span className="text-xs text-muted-foreground truncate flex-1 text-left">
          {React.string(first.message)}
        </span>
        {switch onWyreframeFix {
        | Some(fix) =>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className={"inline-flex items-center justify-center w-5 h-5 rounded text-warning hover:bg-warning/20 transition-colors " ++ (
                  isFixing ? "opacity-50 cursor-not-allowed" : ""
                )}
                disabled=isFixing
                type_="button"
                onClick={e => {
                  ReactEvent.Mouse.stopPropagation(e)
                  setIsFixing(_ => true)
                  fix()
                  let _ = Js.Global.setTimeout(() => setIsFixing(_ => false), 800)
                }}>
                {isFixing
                  ? <Lucide.LoaderCircle className="animate-spin" size=12 />
                  : <Wrench size=12 />}
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content>
              {React.string(isFixing ? "Fixing..." : "Quick fix syntax")}
            </Tooltip.Content>
          </Tooltip>
        | None => React.null
        }}
        {switch onRequestFix {
        | Some(requestFix) =>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className="inline-flex items-center justify-center w-5 h-5 rounded-full bg-primary hover:bg-primary/90 text-primary-foreground transition-colors"
                type_="button"
                onClick={e => {
                  ReactEvent.Mouse.stopPropagation(e)
                  let text =
                    allErrors
                    ->Array.mapWithIndex((err, i) => {
                      let loc = switch (err.line, err.column) {
                      | (Some(l), Some(c)) => " (Line " ++ Int.toString(l) ++ ":" ++ Int.toString(c) ++ ")"
                      | (Some(l), None) => " (Line " ++ Int.toString(l) ++ ")"
                      | _ => ""
                      }
                      Int.toString(i + 1) ++ ". " ++ err.title ++ loc ++ ": " ++ err.message
                    })
                    ->Array.join("\n")
                  requestFix(text)
                }}>
                <WandSparkles size=12 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Auto-fix with AI")} </Tooltip.Content>
          </Tooltip>
        | None => React.null
        }}
        <span className="text-xs text-muted-foreground">
          {React.string(errorsExpanded ? "▼" : "▶")}
        </span>
      </div>
      {errorsExpanded
        ? <div
            className="px-3 py-2 bg-[hsl(230_25%_8%/0.6)] border-t border-[hsl(220_20%_95%/0.08)] max-h-48 overflow-y-auto">
            {allErrors
            ->Array.mapWithIndex((err, i) => {
              let loc = switch (err.line, err.column) {
              | (Some(l), Some(c)) => "Line " ++ Int.toString(l) ++ ", Column " ++ Int.toString(c)
              | (Some(l), None) => "Line " ++ Int.toString(l)
              | _ => ""
              }
              let titleClass = err.title === "Warning" ? "text-warning" : "text-destructive"
              <div key={Int.toString(i)} className={i > 0 ? "mt-2 pt-2 border-t border-[hsl(220_20%_95%/0.08)]" : ""}>
                <div className="flex items-start gap-2">
                  <span className={"text-xs font-medium " ++ titleClass ++ " shrink-0"}>
                    {React.string(Int.toString(i + 1) ++ ". " ++ err.title)}
                  </span>
                  {loc !== ""
                    ? <span className="text-xs text-muted-foreground shrink-0">
                        {React.string("(" ++ loc ++ ")")}
                      </span>
                    : React.null}
                </div>
                <div className="text-xs text-foreground/80 font-mono whitespace-pre-wrap mt-1 ml-4">
                  {React.string(err.message)}
                </div>
              </div>
            })
            ->React.array}
          </div>
        : React.null}
    </div>
  } else {
    React.null
  }

  let toolbarBtnClass = (active: bool) =>
    "p-1.5 rounded-md transition-all " ++ (
      active
        ? "bg-[hsl(265_90%_65%/0.2)] text-[hsl(265_90%_70%)]"
        : "text-muted-foreground hover:text-foreground hover:bg-[hsl(220_20%_95%/0.08)]"
    )

  let zoomBtnClass = "p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-[hsl(220_20%_95%/0.08)] transition-all disabled:opacity-30 disabled:cursor-not-allowed"

  <div className="flex flex-col h-full w-full">
    <div className="px-3 py-2 border-b border-[hsl(220_20%_95%/0.08)] bg-[hsl(230_25%_8%/0.4)]">
      {isPending
        ? <div className="absolute top-2 right-3">
            <span className="text-xs text-muted-foreground animate-pulse">
              {React.string("Updating...")}
            </span>
          </div>
        : React.null}
      <div className="flex items-center gap-1 w-full">
        <div className="flex items-center bg-[hsl(220_20%_95%/0.05)] rounded-lg p-0.5">
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className={toolbarBtnClass(viewport.current === Desktop)}
                type_="button"
                onClick={_ => handleViewportChange("Desktop")}>
                <Lucide.Monitor size=16 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Desktop (1440px)")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className={toolbarBtnClass(viewport.current === Tablet)}
                type_="button"
                onClick={_ => handleViewportChange("Tablet")}>
                <Lucide.Tablet size=16 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Tablet (768px)")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className={toolbarBtnClass(viewport.current === Mobile)}
                type_="button"
                onClick={_ => handleViewportChange("Mobile")}>
                <Lucide.Smartphone size=16 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Mobile (375px)")} </Tooltip.Content>
          </Tooltip>
        </div>
        <div className="w-px h-5 bg-[hsl(220_20%_95%/0.1)] mx-1" />
        <div className="flex items-center bg-[hsl(220_20%_95%/0.05)] rounded-lg p-0.5">
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className=zoomBtnClass
                disabled={Option.isNone(getPreviousZoomLevel(viewport.zoom))}
                type_="button"
                onClick={_ => handleZoomOut()}>
                <Lucide.Minus size=14 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Zoom Out")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className="px-2 py-1 text-xs font-mono text-muted-foreground hover:text-foreground transition-all min-w-[48px] text-center"
                type_="button"
                onClick={_ => {
                  onZoomChange(1.0)
                  announceZoomChange(1.0)
                }}>
                {React.string(formatZoomPercentage(viewport.zoom))}
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Reset to 100%")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className=zoomBtnClass
                disabled={Option.isNone(getNextZoomLevel(viewport.zoom))}
                type_="button"
                onClick={_ => handleZoomIn()}>
                <Lucide.Plus size=14 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Zoom In")} </Tooltip.Content>
          </Tooltip>
        </div>
        <div className="w-px h-5 bg-[hsl(220_20%_95%/0.1)] mx-1" />
        <div className="flex items-center gap-0.5">
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className=zoomBtnClass
                disabled={!canGoHome}
                type_="button"
                onClick={_ => handleHome()}>
                <Lucide.House size=15 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Go to Home")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className=zoomBtnClass
                disabled={!canUndo}
                type_="button"
                onClick={_ => handleUndo()}>
                <Undo2 size=15 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Undo (" ++ Int.toString(undoCount) ++ ")")} </Tooltip.Content>
          </Tooltip>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className=zoomBtnClass
                disabled={!canRedo}
                type_="button"
                onClick={_ => handleRedo()}>
                <Lucide.Redo2 size=15 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Redo (" ++ Int.toString(redoCount) ++ ")")} </Tooltip.Content>
          </Tooltip>
        </div>
        <div className="w-px h-5 bg-[hsl(220_20%_95%/0.1)] mx-1" />
        <Tooltip>
          <Tooltip.Trigger>
            <button
              className="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-[hsl(220_20%_95%/0.08)] transition-all"
              type_="button"
              onClick={_ => handleRefresh()}>
              <Lucide.RotateCcw size=15 />
            </button>
          </Tooltip.Trigger>
          <Tooltip.Content> {React.string("Refresh")} </Tooltip.Content>
        </Tooltip>
        <div className="w-px h-5 bg-[hsl(220_20%_95%/0.1)] mx-1" />
        {switch onThemeChange {
        | Some(onChange) =>
          <ThemeSelector currentTheme={activeTheme} onThemeChange={onChange} />
        | None => React.null
        }}
        <div className="flex-1" />
        {switch onReportIssue {
        | Some(report) =>
          <Tooltip>
            <Tooltip.Trigger>
              <button
                className="p-1.5 rounded-md text-muted-foreground hover:text-foreground hover:bg-[hsl(220_20%_95%/0.08)] transition-all"
                type_="button"
                onClick={_ => report()}>
                <Lucide.Bug size=15 />
              </button>
            </Tooltip.Trigger>
            <Tooltip.Content> {React.string("Report Issue")} </Tooltip.Content>
          </Tooltip>
        | None => React.null
        }}
      </div>
    </div>
    <div className="flex-1 min-h-0 flex items-center justify-center p-4 bg-muted/30 overflow-hidden">
      <div
        ref={ReactDOM.Ref.domRef(containerRef)}
        className="h-full w-full flex items-center justify-center overflow-hidden">
        {deviceFrame}
      </div>
    </div>
    {errorBar}
  </div>
}
