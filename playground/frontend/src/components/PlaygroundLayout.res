// Playground shell — header bar + responsive 3-pane workspace (editor / preview / chat).
// Desktop: three resizable columns. Tablet: tabs + collapsible chat. Mobile: full-width tabs.

@val @scope("window") external innerWidth: int = "innerWidth"
@val @scope("window") external addWindowListener: (string, 'a => unit) => unit = "addEventListener"
@val @scope("window") external removeWindowListener: (string, 'a => unit) => unit = "removeEventListener"
@val @scope("document") external addDocListener: (string, 'a => unit) => unit = "addEventListener"
@val @scope("document") external removeDocListener: (string, 'a => unit) => unit = "removeEventListener"
%%raw(`
function setBodyCursor(v) { document.body.style.cursor = v; }
function setBodyUserSelect(v) { document.body.style.userSelect = v; }
`)
@val external setBodyCursor: string => unit = "setBodyCursor"
@val external setBodyUserSelect: string => unit = "setBodyUserSelect"

type mouseEvt = {clientX: int}

type layoutMode = Desktop | Tablet | Mobile

let useLayoutMode = (): layoutMode => {
  let (mode, setMode) = React.useState(() => Desktop)

  React.useEffect0(() => {
    let compute = _ => {
      let w = innerWidth
      if w < 768 {
        setMode(_ => Mobile)
      } else if w < 1024 {
        setMode(_ => Tablet)
      } else {
        setMode(_ => Desktop)
      }
    }
    compute()
    addWindowListener("resize", compute)
    Some(() => removeWindowListener("resize", compute))
  })

  mode
}

type widths = {
  editor: float,
  preview: float,
  chat: float,
}

type handle = Left | Right

type dragState = {
  isResizing: bool,
  activeHandle: option<handle>,
  startX: float,
  startWidths: widths,
}

let defaultWidths: widths = {editor: 25.0, preview: 45.0, chat: 30.0}

let useResizablePanels = () => {
  let (widths, setWidths) = React.useState(() => defaultWidths)
  let (drag, setDrag) = React.useState(() => {
    isResizing: false,
    activeHandle: None,
    startX: 0.0,
    startWidths: defaultWidths,
  })

  let startResize = (which: handle, e: ReactEvent.Mouse.t) => {
    ReactEvent.Mouse.preventDefault(e)
    let clientX = ReactEvent.Mouse.clientX(e)->Int.toFloat
    setDrag(_ => {
      isResizing: true,
      activeHandle: Some(which),
      startX: clientX,
      startWidths: widths,
    })
  }

  React.useEffect1(() => {
    if drag.isResizing {
      let onMove = (ev: mouseEvt) => {
        let clientX = ev.clientX->Int.toFloat
        let windowWidth = innerWidth->Int.toFloat
        let delta = (clientX -. drag.startX) /. windowWidth *. 100.0
        setWidths(_ =>
          switch drag.activeHandle {
          | None => drag.startWidths
          | Some(Left) =>
            let nextEditor = drag.startWidths.editor +. delta
            let nextPreview = drag.startWidths.preview -. delta
            if (
              nextEditor >= 15.0 &&
              nextEditor <= 60.0 &&
              nextPreview >= 15.0 &&
              nextPreview <= 60.0
            ) {
              {editor: nextEditor, preview: nextPreview, chat: drag.startWidths.chat}
            } else {
              drag.startWidths
            }
          | Some(Right) =>
            let nextPreview = drag.startWidths.preview +. delta
            let nextChat = drag.startWidths.chat -. delta
            if (
              nextPreview >= 15.0 &&
              nextPreview <= 60.0 &&
              nextChat >= 15.0 &&
              nextChat <= 60.0
            ) {
              {editor: drag.startWidths.editor, preview: nextPreview, chat: nextChat}
            } else {
              drag.startWidths
            }
          }
        )
      }
      let moveRef = ref(None)
      let upRef = ref(None)
      let onUp = _ev => {
        setDrag(d => {...d, isResizing: false, activeHandle: None})
        switch (moveRef.contents, upRef.contents) {
        | (Some(m), Some(u)) =>
          removeDocListener("mousemove", m)
          removeDocListener("mouseup", u)
        | _ => ()
        }
        setBodyCursor("")
        setBodyUserSelect("")
      }
      moveRef := Some(onMove)
      upRef := Some(onUp)
      addDocListener("mousemove", onMove)
      addDocListener("mouseup", onUp)
      setBodyCursor("col-resize")
      setBodyUserSelect("none")
      Some(
        () => {
          removeDocListener("mousemove", onMove)
          removeDocListener("mouseup", onUp)
        },
      )
    } else {
      None
    }
  }, [drag.isResizing])

  (widths, startResize, drag.isResizing)
}

module NavBar = {
  @react.component
  let make = () =>
    <nav
      className="h-14 glass-strong border-b border-[hsl(220_20%_95%/0.08)] flex items-center justify-between px-4 flex-shrink-0 relative z-10">
      <Logo asLink=true />
      <div className="flex items-center gap-3">
        <span className="relative flex h-2 w-2">
          <span
            className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[hsl(120_70%_50%)] opacity-75"
          />
          <span className="relative inline-flex rounded-full h-2 w-2 bg-[hsl(120_70%_50%)]" />
        </span>
        <span className="text-xs text-muted-foreground hidden sm:block">
          {React.string("Live")}
        </span>
        <div className="w-px h-4 bg-[hsl(220_20%_95%/0.15)] hidden sm:block" />
        <a
          className="p-1.5 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-[hsl(220_20%_95%/0.08)]"
          title="npm"
          href="https://www.npmjs.com/package/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          <Lucide.Package size={18} />
        </a>
        <a
          className="p-1.5 text-muted-foreground hover:text-foreground transition-colors rounded-lg hover:bg-[hsl(220_20%_95%/0.08)]"
          title="GitHub"
          href="https://github.com/wickedev/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          <Lucide.Github size={18} />
        </a>
      </div>
    </nav>
}

module ResizeHandle = {
  @react.component
  let make = (~isResizing: bool, ~onMouseDown: ReactEvent.Mouse.t => unit) => {
    let outer =
      "group absolute top-0 bottom-0 w-3 cursor-col-resize z-30 flex items-center justify-center hover:bg-[hsl(265_90%_65%/0.15)] transition-colors " ++ (
        isResizing ? "bg-[hsl(265_90%_65%/0.2)]" : ""
      )
    let inner =
      "w-1 h-16 rounded-full transition-all duration-150 " ++ (
        isResizing
          ? "bg-[hsl(265_90%_65%)] shadow-[0_0_10px_hsl(265_90%_65%/0.6)]"
          : "bg-[hsl(220_20%_40%)] group-hover:bg-[hsl(265_90%_65%)] group-hover:shadow-[0_0_8px_hsl(265_90%_65%/0.4)]"
      )
    <div className=outer style={right: "-6px"} onMouseDown>
      <div className=inner />
    </div>
  }
}

let editorIcon =
  <span
    className="inline-flex items-center justify-center w-6 h-6 rounded-md bg-[hsl(265_90%_65%/0.15)] text-[hsl(265_90%_65%)]">
    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
      />
    </svg>
  </span>

let previewIcon =
  <span
    className="inline-flex items-center justify-center w-6 h-6 rounded-md bg-[hsl(200_90%_50%/0.2)] text-[hsl(200_90%_65%)]">
    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
      />
      <path
        d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
      />
    </svg>
  </span>

let chatIcon =
  <span
    className="inline-flex items-center justify-center w-6 h-6 rounded-md bg-[hsl(320_90%_60%/0.2)] text-[hsl(320_90%_70%)]">
    <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
      />
    </svg>
  </span>

let chatIconSmall =
  <span
    className="inline-flex items-center justify-center w-5 h-5 rounded bg-[hsl(320_90%_60%/0.15)] text-[hsl(320_90%_70%)]">
    <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="2"
      />
    </svg>
  </span>

module DesktopLayout = {
  @react.component
  let make = (
    ~editorSection: React.element,
    ~previewSection: React.element,
    ~chatSection: React.element,
    ~sceneTitle: option<string>=?,
    ~previewViewportInfo: option<string>=?,
  ) => {
    let (widths, startResize, isResizing) = useResizablePanels()

    <div
      className="h-screen flex flex-col gradient-mesh relative overflow-hidden playground-mono">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div
          className="absolute -top-40 -left-40 w-80 h-80 bg-[hsl(265_90%_50%/0.08)] rounded-full blur-[120px]"
        />
        <div
          className="absolute top-1/3 -right-20 w-72 h-72 bg-[hsl(200_90%_50%/0.06)] rounded-full blur-[100px]"
        />
        <div
          className="absolute -bottom-20 left-1/3 w-64 h-64 bg-[hsl(320_90%_50%/0.05)] rounded-full blur-[100px]"
        />
      </div>
      <NavBar />
      <div className="flex-1 flex overflow-hidden relative z-0">
        // Editor column
        <div
          className="panel-border-right flex flex-col relative"
          style={width: Float.toString(widths.editor) ++ "%"}>
          <Card className="h-full rounded-none border-0 flex flex-col bg-transparent">
            <Card.Header className="panel-header flex-shrink-0">
              <Card.Title
                className="text-sm font-medium flex items-center gap-2 text-[hsl(220_20%_80%)]">
                <> {editorIcon} {React.string("ASCII Editor")} </>
              </Card.Title>
            </Card.Header>
            <Card.Content className="p-0 flex-1 overflow-hidden panel-content panel-inset">
              {editorSection}
            </Card.Content>
          </Card>
          <ResizeHandle isResizing onMouseDown={e => startResize(Left, e)} />
        </div>
        // Preview column
        <div
          className="panel-border-right flex flex-col relative"
          style={width: Float.toString(widths.preview) ++ "%"}>
          <Card className="h-full rounded-none border-0 flex flex-col bg-transparent">
            <Card.Header className="panel-header flex-shrink-0">
              <Card.Title
                className="text-sm font-medium flex items-center justify-between w-full text-[hsl(220_20%_80%)]">
                <>
                  <div className="flex items-center gap-2">
                    {previewIcon}
                    {React.string("Live Preview")}
                    {switch sceneTitle {
                    | Some(t) =>
                      <span className="text-xs text-muted-foreground font-normal">
                        {React.string("(" ++ t ++ ")")}
                      </span>
                    | None => React.null
                    }}
                  </div>
                  {switch previewViewportInfo {
                  | Some(info) =>
                    <span className="text-xs text-muted-foreground font-mono">
                      {React.string(info)}
                    </span>
                  | None => React.null
                  }}
                </>
              </Card.Title>
            </Card.Header>
            <Card.Content
              className="p-0 flex-1 overflow-hidden panel-content panel-inset flex items-center justify-center">
              {previewSection}
            </Card.Content>
          </Card>
          <ResizeHandle isResizing onMouseDown={e => startResize(Right, e)} />
        </div>
        // Chat column
        <div className="flex flex-col" style={width: Float.toString(widths.chat) ++ "%"}>
          <Card className="h-full rounded-none border-0 flex flex-col bg-transparent">
            <Card.Header className="panel-header flex-shrink-0">
              <Card.Title
                className="text-sm font-medium flex items-center gap-2 text-[hsl(220_20%_80%)]">
                <> {chatIcon} {React.string("AI Assistant")} </>
              </Card.Title>
            </Card.Header>
            <Card.Content
              className="p-0 flex-1 overflow-hidden panel-content panel-inset flex flex-col">
              {chatSection}
            </Card.Content>
          </Card>
        </div>
      </div>
    </div>
  }
}

module TabletLayout = {
  @react.component
  let make = (
    ~editorSection: React.element,
    ~previewSection: React.element,
    ~chatSection: React.element,
    ~sceneTitle as _: option<string>=?,
  ) => {
    let (chatOpen, setChatOpen) = React.useState(() => false)
    let (active, setActive) = React.useState(() => "preview")

    <div
      className="h-screen flex flex-col gradient-mesh relative overflow-hidden playground-mono">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div
          className="absolute -top-20 -left-20 w-48 h-48 bg-[hsl(265_90%_50%/0.1)] rounded-full blur-[80px]"
        />
        <div
          className="absolute top-1/3 -right-10 w-40 h-40 bg-[hsl(200_90%_50%/0.08)] rounded-full blur-[60px]"
        />
      </div>
      <NavBar />
      <div className="flex-1 flex flex-col overflow-hidden relative z-0">
        <div className="flex border-b border-[hsl(220_20%_95%/0.08)] glass-strong">
          <button
            className={"flex-1 py-3 px-4 text-sm font-medium transition-colors " ++ (
              active == "editor"
                ? "text-[hsl(265_90%_60%)] border-b-2 border-[hsl(265_90%_60%)]"
                : "text-[hsl(220_20%_60%)] hover:text-[hsl(220_20%_80%)]"
            )}
            onClick={_ => setActive(_ => "editor")}>
            {React.string("Editor")}
          </button>
          <button
            className={"flex-1 py-3 px-4 text-sm font-medium transition-colors " ++ (
              active == "preview"
                ? "text-[hsl(200_90%_60%)] border-b-2 border-[hsl(200_90%_60%)]"
                : "text-[hsl(220_20%_60%)] hover:text-[hsl(220_20%_80%)]"
            )}
            onClick={_ => setActive(_ => "preview")}>
            {React.string("Preview")}
          </button>
          <button
            className={"py-3 px-4 text-sm font-medium transition-colors " ++ (
              chatOpen
                ? "text-[hsl(320_90%_60%)] bg-[hsl(320_90%_60%/0.1)]"
                : "text-[hsl(220_20%_60%)] hover:text-[hsl(220_20%_80%)]"
            )}
            onClick={_ => setChatOpen(o => !o)}>
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
              />
            </svg>
          </button>
        </div>
        <div className="flex-1 flex overflow-hidden">
          <div
            className={"flex-1 overflow-hidden bg-[hsl(230_25%_6%/0.5)] flex items-center justify-center " ++ (
              chatOpen ? "w-1/2" : "w-full"
            )}>
            {active == "editor" ? editorSection : previewSection}
          </div>
          {chatOpen
            ? <div
                className="w-1/2 border-l border-[hsl(220_20%_95%/0.08)] flex flex-col bg-[hsl(230_25%_6%/0.5)]">
                <div
                  className="border-b border-[hsl(220_20%_95%/0.08)] px-4 py-2 flex items-center justify-between glass-strong">
                  <span className="text-sm font-medium flex items-center gap-2">
                    {chatIconSmall}
                    {React.string("AI Assistant")}
                  </span>
                  <button
                    className="p-1 hover:bg-[hsl(220_20%_20%)] rounded transition-colors"
                    onClick={_ => setChatOpen(_ => false)}>
                    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        d="M6 18L18 6M6 6l12 12"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                      />
                    </svg>
                  </button>
                </div>
                <div className="flex-1 overflow-hidden flex flex-col"> {chatSection} </div>
              </div>
            : React.null}
        </div>
      </div>
    </div>
  }
}

module MobileLayout = {
  @react.component
  let make = (
    ~editorSection: React.element,
    ~previewSection: React.element,
    ~chatSection: React.element,
    ~sceneTitle as _: option<string>=?,
  ) =>
    <div
      className="h-screen flex flex-col gradient-mesh relative overflow-hidden playground-mono">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div
          className="absolute -top-20 -left-20 w-40 h-40 bg-[hsl(265_90%_50%/0.1)] rounded-full blur-[80px]"
        />
        <div
          className="absolute top-1/3 -right-10 w-36 h-36 bg-[hsl(200_90%_50%/0.08)] rounded-full blur-[60px]"
        />
        <div
          className="absolute -bottom-10 left-1/4 w-32 h-32 bg-[hsl(320_90%_50%/0.06)] rounded-full blur-[60px]"
        />
      </div>
      <NavBar />
      <Tabs defaultValue="preview" className="flex-1 flex flex-col relative z-0">
        <Tabs.List
          className="w-full justify-start border-b border-[hsl(220_20%_95%/0.08)] rounded-none flex-shrink-0 glass-strong">
          <Tabs.Trigger
            value="editor"
            className="flex-1 data-[state=active]:bg-[hsl(265_90%_65%/0.08)] data-[state=active]:text-[hsl(265_90%_60%/0.8)]">
            {React.string("Editor")}
          </Tabs.Trigger>
          <Tabs.Trigger
            value="preview"
            className="flex-1 data-[state=active]:bg-[hsl(200_90%_50%/0.1)] data-[state=active]:text-[hsl(200_90%_60%)]">
            {React.string("Preview")}
          </Tabs.Trigger>
          <Tabs.Trigger
            value="chat"
            className="flex-1 data-[state=active]:bg-[hsl(320_90%_60%/0.1)] data-[state=active]:text-[hsl(320_90%_70%)]">
            {React.string("Chat")}
          </Tabs.Trigger>
        </Tabs.List>
        <Tabs.Content
          value="editor"
          className="flex-1 m-0 overflow-hidden bg-[hsl(230_25%_6%/0.5)]">
          {editorSection}
        </Tabs.Content>
        <Tabs.Content
          value="preview"
          className="flex-1 m-0 overflow-hidden bg-[hsl(230_25%_6%/0.5)] flex items-center justify-center">
          {previewSection}
        </Tabs.Content>
        <Tabs.Content
          value="chat"
          className="flex-1 m-0 overflow-hidden bg-[hsl(230_25%_6%/0.5)] flex flex-col">
          {chatSection}
        </Tabs.Content>
      </Tabs>
    </div>
}

@react.component
let make = (
  ~editorSection: React.element,
  ~previewSection: React.element,
  ~chatSection: React.element,
  ~sceneTitle: option<string>=?,
  ~previewViewportInfo: option<string>=?,
) =>
  switch useLayoutMode() {
  | Desktop =>
    <DesktopLayout editorSection previewSection chatSection ?sceneTitle ?previewViewportInfo />
  | Tablet => <TabletLayout editorSection previewSection chatSection ?sceneTitle />
  | Mobile => <MobileLayout editorSection previewSection chatSection ?sceneTitle />
  }
