// Playground workspace — wires the ASCII editor, live preview and AI chat
// together: parses wyreframe markup, persists the session (debounced), and
// surfaces parse errors/warnings, dead-end navigation and the issue reporter.
// Faithfully reconstructed from the deployed bundle's `Playground` component.

// ── Parser / session layer (shared library + SessionManager surface) ────────
// These helpers live in the bundle's WyreframeParser + SessionManager modules.
// No exported ReScript module wraps them, so the bits `Playground` needs are
// transcribed here (library/localStorage API surface → %raw).

// A parser issue: { message, line?, column?, snippet? }.
type parseIssue = {
  message: string,
  line: option<int>,
  column: option<int>,
  snippet: option<string>,
}

type parseResult =
  | Success({data: LivePreview.ast, warnings: array<parseIssue>})
  | ParseError(parseIssue)

// ESM import of the parent `wyreframe` library (browser has no `require`).
%%raw(`import * as WyreframeLib from "wyreframe"`)

let parse: string => parseResult = %raw(`function(content) {
  try {
    var lib = WyreframeLib;
    var raw = lib.parse(content);
    console.log("[WyreframeParser] Raw result:", raw);
    if (raw.TAG === "Ok") {
      var tuple = raw._0;
      var ast = tuple[0];
      var rawWarnings = tuple[1];
      var ws = (rawWarnings !== undefined) ? rawWarnings : [];
      var warnings = ws.map(function(w) {
        var t = w.code.TAG, msg;
        switch (t) {
          case "InvalidSyntax": msg = "Invalid syntax"; break;
          case "MisalignedClosingBorder":
            var ec = w.code.expectedCol, ac = w.code.actualCol;
            msg = (ec !== undefined && ac !== undefined)
              ? "Misaligned closing border: expected column " + ec.toString() + ", got " + ac.toString()
              : "Misaligned closing border";
            break;
          case "UnclosedBox": msg = "Unclosed box - missing closing border"; break;
          default: msg = t;
        }
        var pos = w.code.position;
        var line = pos !== undefined ? pos.row : undefined;
        var col = pos !== undefined ? pos.col : undefined;
        return { message: msg, line: line, column: col, snippet: undefined };
      });
      if (ast == null) {
        return { TAG: "ParseError", _0: { message: "Parse succeeded but AST is null", line: undefined, column: undefined, snippet: undefined } };
      }
      return { TAG: "Success", data: ast, warnings: warnings };
    } else {
      var errs = raw._0;
      var first = (errs !== undefined && errs.length > 0) ? errs[0] : undefined;
      var message = (first !== undefined && first.message !== undefined) ? first.message : "Unknown parsing error";
      var l = (first !== undefined) ? first.line : undefined;
      var c = (first !== undefined) ? first.column : undefined;
      return { TAG: "ParseError", _0: { message: message, line: l, column: c, snippet: undefined } };
    }
  } catch (e) {
    var m = (e && e.message) ? e.message : "Unknown parsing error";
    return { TAG: "ParseError", _0: { message: m, line: undefined, column: undefined, snippet: undefined } };
  }
}`)

// fixOnly normalises wyreframe markup; the fixer lives in the parent library.
let fixOnly: string => string = %raw(`function(content) {
  try {
    var lib = WyreframeLib;
    if (lib.fixOnly) {
      var r = lib.fixOnly(content);
      if (r && r.TAG === "Ok") return r._0.text;
      if (typeof r === "string") return r;
    }
    return content;
  } catch (e) {
    console.warn("[WyreframeParser] fixOnly failed, returning original content");
    return content;
  }
}`)

// AST scene helpers (operate on the parsed AST's `.scenes` array).
let getSceneIds: LivePreview.ast => array<string> = %raw(`function(ast) {
  var s = ast.scenes;
  if (s === undefined) return [];
  var out = [];
  for (var i = 0; i < s.length; i++) { if (s[i].id !== undefined) out.push(s[i].id); }
  return out;
}`)

let getAstTitle: LivePreview.ast => option<string> = %raw(`function(ast) {
  var s = ast.scenes[0];
  if (s !== undefined && s.title !== "") return s.title;
  return undefined;
}`)

let getSceneTitleById: (LivePreview.ast, string) => option<string> = %raw(`function(ast, id) {
  var s = ast.scenes.find(function(x) { return x.id === id; });
  if (s !== undefined && s.title !== "") return s.title;
  return undefined;
}`)

// Default editor content (the bundled login-form example).
%%raw(`
var loginFormExample = "@scene: login\n\n+---------------------------+\n|       'LOGIN'             |\n|                           |\n|  +---------------------+  |\n|  | #email              |  |\n|  +---------------------+  |\n|                           |\n|  +---------------------+  |\n|  | #password           |  |\n|  +---------------------+  |\n|                           |\n|  [x] Remember me          |\n|                           |\n|       [ Login ]           |\n|                           |\n|  \"Forgot password?\"       |\n+---------------------------+\n\n#email:\n  placeholder: \"Enter your email\"\n  type: email\n\n#password:\n  placeholder: \"Enter your password\"\n  type: password\n\n[Login]:\n  variant: primary\n  @click -> goto(dashboard, fade)\n";
`)
let getDefault: unit => string = %raw("() => loginFormExample")

// ── Session model + persistence (SessionManager surface, localStorage) ──────

type session = {
  sessionId: string,
  asciiContent: string,
  chatHistory: array<JSON.t>,
  viewportState: LivePreview.viewportState,
  lastUpdated: float,
  createdAt: float,
}

let loadSession: string => option<session> = %raw(`function(sessionId) {
  try {
    var key = "wyreframe_session_" + sessionId;
    console.log("[SessionManager] Loading from key:", key);
    var raw = localStorage.getItem(key);
    if (raw == null) { console.warn("[SessionManager] No data found in localStorage"); return undefined; }
    var data = JSON.parse(raw);
    return data == null ? undefined : data;
  } catch (e) {
    console.error("[SessionManager] Failed to load session", e);
    return undefined;
  }
}`)

type saveResult =
  | SaveOk
  | SaveError(string)

let saveSession: session => saveResult = %raw(`function(s) {
  try {
    var key = "wyreframe_session_" + s.sessionId;
    console.log("[SessionManager] Saving to key:", key);
    console.log("[SessionManager] Content length:", s.asciiContent.length);
    localStorage.setItem(key, JSON.stringify(s));
    return "SaveOk";
  } catch (e) {
    return { TAG: "SaveError", _0: (e && e.message) ? e.message : "Unknown error" };
  }
}`)

module WandSparkles = {
  @module("lucide-react") @react.component
  external make: (~size: int=?, ~className: string=?) => React.element = "WandSparkles"
}

// ── Component state ─────────────────────────────────────────────────────────

type state = {
  asciiContent: string,
  parsedAst: option<LivePreview.ast>,
  parseError: option<parseIssue>,
  parseWarnings: array<parseIssue>,
  chatHistory: array<JSON.t>,
  viewport: LivePreview.viewportState,
  sessionId: string,
  hasError: bool,
  errorMessage: option<string>,
}

let defaultViewportState = (): LivePreview.viewportState => {
  current: LivePreview.Mobile,
  zoom: 1.0,
  dimensions: ({width: 375, height: 773}: LivePreview.dimensions),
}

@val external setTimeout: (unit => unit, int) => float = "setTimeout"
@val external clearTimeout: float => unit = "clearTimeout"

@react.component
let make = (
  ~initialPrompt: option<string>=?,
  ~initialSession: option<session>=?,
  ~sessionId: string,
) => {
  let (state, setState) = React.useState(() =>
    switch initialSession {
    | Some(s) => {
        asciiContent: switch initialPrompt {
        | Some(_) => ""
        | None => s.asciiContent
        },
        parsedAst: None,
        parseError: None,
        parseWarnings: [],
        chatHistory: s.chatHistory,
        viewport: s.viewportState,
        sessionId: s.sessionId,
        hasError: false,
        errorMessage: None,
      }
    | None => {
        asciiContent: switch initialPrompt {
        | Some(_) => ""
        | None => getDefault()
        },
        parsedAst: None,
        parseError: None,
        parseWarnings: [],
        chatHistory: [],
        viewport: defaultViewportState(),
        sessionId,
        hasError: false,
        errorMessage: None,
      }
    }
  )

  let (showIssueReporter, setShowIssueReporter) = React.useState(() => false)
  let (fixPrompt, setFixPrompt) = React.useState((): option<string> => None)
  let (deadEnd, setDeadEnd) = React.useState((): option<LivePreview.deadEndInfo> => None)
  let (additionalInstructions, setAdditionalInstructions) = React.useState(() => "")
  let (currentScene, setCurrentScene) = React.useState((): option<string> => None)

  let (themeState, setTheme) = Theme.useTheme()

  // Keep the latest state in a ref for the debounced session save.
  let stateRef = React.useRef(state)
  React.useEffect1(() => {
    stateRef.current = state
    None
  }, [state])

  // Debounced session persistence (500ms after last change).
  let saveTimeoutRef = React.useRef((None: option<float>))
  React.useEffect1(() => {
    switch saveTimeoutRef.current {
    | Some(id) => clearTimeout(id)
    | None => ()
    }
    let id = setTimeout(() => {
      let cur = stateRef.current
      Console.log2(
        "[Playground] Saving session with content length:",
        String.length(cur.asciiContent),
      )
      Console.log2(
        "[Playground] First 100 chars:",
        String.slice(cur.asciiContent, ~start=0, ~end=100),
      )
      let existing = loadSession(cur.sessionId)
      let createdAt = switch existing {
      | Some(e) => e.createdAt
      | None => Date.now()
      }
      let result = saveSession({
        sessionId: cur.sessionId,
        asciiContent: cur.asciiContent,
        chatHistory: cur.chatHistory,
        viewportState: cur.viewport,
        lastUpdated: Date.now(),
        createdAt,
      })
      switch result {
      | SaveOk => Console.log("[Playground] Session saved successfully")
      | SaveError(msg) => Console.error2("[Playground] Session save failed:", msg)
      }
    }, 500)
    saveTimeoutRef.current = Some(id)
    Some(
      () =>
        switch saveTimeoutRef.current {
        | Some(t) => clearTimeout(t)
        | None => ()
        },
    )
  }, [state])

  // Parse the ASCII content, surfacing the AST + first warning / parse error.
  let handleParse = (content: string) => {
    let result = parse(content)
    Console.log2("[Playground] Parse result:", result->Obj.magic)
    switch result {
    | Success({data, warnings}) =>
      Console.log2("[Playground] Parse success, AST:", data->Obj.magic)
      Console.log2("[Playground] Parse warnings count:", Array.length(warnings))
      Console.log2("[Playground] Parse warnings:", warnings->Obj.magic)
      let hasWarning = Array.length(warnings) > 0
      let firstWarning = warnings[0]
      switch firstWarning {
      | Some(w) =>
        Console.log2("[Playground] First warning message:", w.message)
        Console.log2("[Playground] First warning line:", w.line->Obj.magic)
        Console.log2("[Playground] First warning column:", w.column->Obj.magic)
      | None => Console.log("[Playground] No warnings found")
      }
      setState(prev => {
        asciiContent: content,
        parsedAst: Some(data),
        parseError: firstWarning,
        parseWarnings: warnings,
        chatHistory: prev.chatHistory,
        viewport: prev.viewport,
        sessionId: prev.sessionId,
        hasError: hasWarning,
        errorMessage: firstWarning->Option.map(w => w.message),
      })
    | ParseError(err) =>
      Console.log2("[Playground] Parse error:", err->Obj.magic)
      setState(prev => {
        asciiContent: content,
        parsedAst: prev.parsedAst,
        parseError: Some(err),
        parseWarnings: [],
        chatHistory: prev.chatHistory,
        viewport: prev.viewport,
        sessionId: prev.sessionId,
        hasError: true,
        errorMessage: Some(err.message),
      })
    }
  }

  // Editor error callback (first warning / parse error from AsciiEditor).
  let handleEditorError = (issue: option<AsciiEditor.parseIssue>) => {
    let converted = issue->Option.map((i): parseIssue => {
      message: i.message,
      line: i.line,
      column: i.column,
      snippet: None,
    })
    setState(prev => {
      asciiContent: prev.asciiContent,
      parsedAst: prev.parsedAst,
      parseError: converted,
      parseWarnings: prev.parseWarnings,
      chatHistory: prev.chatHistory,
      viewport: prev.viewport,
      sessionId: prev.sessionId,
      hasError: Option.isSome(converted),
      errorMessage: prev.errorMessage,
    })
  }

  // Wireframe generated from chat → set content and re-parse.
  let handleWireframeGenerated = (content: string) => {
    setState(prev => {
      asciiContent: content,
      parsedAst: prev.parsedAst,
      parseError: prev.parseError,
      parseWarnings: prev.parseWarnings,
      chatHistory: prev.chatHistory,
      viewport: prev.viewport,
      sessionId: prev.sessionId,
      hasError: prev.hasError,
      errorMessage: prev.errorMessage,
    })
    handleParse(content)
  }

  let handleViewportChange = (v: LivePreview.viewport) => {
    let dims = LivePreview.getViewportDimensions(v)
    setState(prev => {
      asciiContent: prev.asciiContent,
      parsedAst: prev.parsedAst,
      parseError: prev.parseError,
      parseWarnings: prev.parseWarnings,
      chatHistory: prev.chatHistory,
      viewport: {
        current: v,
        zoom: prev.viewport.zoom,
        dimensions: dims,
      },
      sessionId: prev.sessionId,
      hasError: prev.hasError,
      errorMessage: prev.errorMessage,
    })
  }

  let handleZoomChange = (z: float) =>
    setState(prev => {
      asciiContent: prev.asciiContent,
      parsedAst: prev.parsedAst,
      parseError: prev.parseError,
      parseWarnings: prev.parseWarnings,
      chatHistory: prev.chatHistory,
      viewport: {
        current: prev.viewport.current,
        zoom: z,
        dimensions: prev.viewport.dimensions,
      },
      sessionId: prev.sessionId,
      hasError: prev.hasError,
      errorMessage: prev.errorMessage,
    })

  // Single error (preferred to the warnings array for the LivePreview bar).
  let buildError = (): option<LivePreview.parseError> => {
    let isWarning = Option.isSome(state.parsedAst) && Array.length(state.parseWarnings) > 0
    switch state.parseError {
    | Some(err) =>
      Some({
        title: isWarning ? "Warning" : "Parse Error",
        message: err.message,
        line: err.line,
        column: err.column,
      })
    | None => None
    }
  }

  // Full error/warning list for the LivePreview error bar.
  let buildErrors = (): option<array<LivePreview.parseError>> => {
    if Option.isSome(state.parsedAst) && Array.length(state.parseWarnings) > 0 {
      Some(
        state.parseWarnings->Array.map((w): LivePreview.parseError => {
          title: "Warning",
          message: w.message,
          line: w.line,
          column: w.column,
        }),
      )
    } else {
      switch state.parseError {
      | Some(err) =>
        Some([
          {
            title: "Parse Error",
            message: err.message,
            line: err.line,
            column: err.column,
          },
        ])
      | None => None
      }
    }
  }

  // Parse the initial content once on mount.
  React.useEffect0(() => {
    if state.asciiContent !== "" {
      handleParse(state.asciiContent)
    }
    None
  })

  let editorSection =
    <AsciiEditor
      value={state.asciiContent}
      onChange=handleParse
      onError=handleEditorError
      sessionId={state.sessionId}
      isDark=true
    />

  let handleReportIssue = () => setShowIssueReporter(_ => true)

  let handleRequestFix = (errorsText: string) => {
    let prompt = "Fix the following errors/warnings in the current code:\n" ++ errorsText
    setFixPrompt(_ => Some(prompt))
  }

  let handleWyreframeFix = () => {
    let fixed = fixOnly(state.asciiContent)
    if fixed !== state.asciiContent {
      Console.log("[Playground] Applied wyreframe fixOnly")
      handleParse(fixed)
    }
  }

  let handleDeadEndClick = (info: LivePreview.deadEndInfo) => {
    Console.log2("[Playground] Dead-end click detected:", info->Obj.magic)
    setDeadEnd(_ => Some(info))
  }

  // Build the "generate next scene" prompt and dispatch it to the chat.
  let handleGenerateScene = () => {
    switch deadEnd {
    | None => ()
    | Some(info) =>
      let sceneRef =
        info.sceneId !== "" ? "scene \"" ++ info.sceneId ++ "\"" : "the initial scene"
      let elementRef = switch info.elementType {
      | "button" => "[" ++ info.elementText ++ "]"
      | "link" => "\"" ++ info.elementText ++ "\""
      | _ => info.elementText
      }
      let extra =
        String.trim(additionalInstructions) !== ""
          ? "\n\nAdditional instructions: " ++ additionalInstructions
          : ""
      let prompt =
        "The user clicked " ++
        elementRef ++
        " in " ++
        sceneRef ++
        " but the target scene doesn't exist.\n\nPlease add the missing scene to the current wireframe. The new scene should:\n1. Have a logical connection from the " ++
        elementRef ++
        " action\n2. Match the visual style of existing scenes\n3. Include a way to navigate back if appropriate\n\nAdd the new scene at the end of the current wireframe code." ++
        extra
      setFixPrompt(_ => Some(prompt))
      setDeadEnd(_ => None)
      setAdditionalInstructions(_ => "")
    }
  }

  let previewError = buildError()
  let previewErrors = buildErrors()

  let previewSection =
    <LivePreview
      ast=?{state.parsedAst}
      viewport={state.viewport}
      onViewportChange=handleViewportChange
      onZoomChange=handleZoomChange
      theme={themeState.current}
      onThemeChange=setTheme
      error=?{previewError}
      errors=?{previewErrors}
      onReportIssue=handleReportIssue
      onRequestFix=handleRequestFix
      onWyreframeFix=handleWyreframeFix
      onDeadEndClick=handleDeadEndClick
      onCurrentSceneChange={scene => setCurrentScene(_ => Some(scene))}
    />

  let availableScenes = state.parsedAst->Option.map(getSceneIds)

  let handleFixPromptConsumed = () => setFixPrompt(_ => None)

  let chatSection = if showIssueReporter {
    <PreviewIssueReporter
      onClose={() => setShowIssueReporter(_ => false)}
      asciiContent={state.asciiContent}
      parseWarnings={state.parseWarnings->Array.map((w): PreviewIssueReporter.parseIssue => {
        message: w.message,
        line: w.line,
        column: w.column,
      })}
      parseError=?{state.parseError->Option.map((e): PreviewIssueReporter.parseIssue => {
        message: e.message,
        line: e.line,
        column: e.column,
      })}
      parsedAst=?{state.parsedAst->Option.map(a => Obj.magic(a))}
      ?availableScenes
      onSuccess={url => Console.log2("[Playground] Issue created:", url)}
    />
  } else {
    <LLMChat
      sessionId={state.sessionId}
      onWireframeGenerated=handleWireframeGenerated
      currentAscii={state.asciiContent}
      ?initialPrompt
      ?fixPrompt
      onFixPromptConsumed=handleFixPromptConsumed
    />
  }

  let previewViewportInfo =
    Int.toString(state.viewport.dimensions.width) ++
    " × " ++
    Int.toString(state.viewport.dimensions.height)

  // Dead-end "generate next scene" dialog.
  let deadEndDialog = switch deadEnd {
  | None => React.null
  | Some(info) =>
    let elementRef = switch info.elementType {
    | "button" => "[" ++ info.elementText ++ "]"
    | "link" => "\"" ++ info.elementText ++ "\""
    | _ => info.elementText
    }
    <Dialog.Root
      open_=true
      onOpenChange={_ => {
        setDeadEnd(_ => None)
        setAdditionalInstructions(_ => "")
      }}>
      <Dialog.Content className="sm:max-w-md">
        <>
          <Dialog.Header>
            <>
              <Dialog.Title> {React.string("Generate Next Scene?")} </Dialog.Title>
              <Dialog.Description>
                {React.string(
                  "You clicked \"" ++
                  info.elementText ++ "\" but there's no target scene defined yet.",
                )}
              </Dialog.Description>
            </>
          </Dialog.Header>
          <div className="py-4">
            <p className="text-sm text-muted-foreground">
              {React.string(
                "Would you like AI to generate an appropriate next scene based on this navigation?",
              )}
            </p>
            <div className="mt-3 p-3 rounded-md bg-muted/50 text-xs font-mono">
              <div className="flex items-center gap-2">
                <span className="text-muted-foreground"> {React.string("Element:")} </span>
                <span> {React.string(elementRef)} </span>
              </div>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-muted-foreground"> {React.string("Current Scene:")} </span>
                <span>
                  {React.string(info.sceneId !== "" ? info.sceneId : "(initial scene)")}
                </span>
              </div>
            </div>
            <div className="mt-4">
              <label className="text-sm text-muted-foreground block mb-2">
                {React.string("Additional instructions (optional):")}
              </label>
              <textarea
                className="w-full px-3 py-2 text-sm rounded-md border border-input bg-background placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring resize-none"
                placeholder="e.g., Include a form with email and password fields..."
                rows=3
                value={additionalInstructions}
                onChange={e => {
                  let v = ReactEvent.Form.target(e)["value"]
                  setAdditionalInstructions(_ => v)
                }}
              />
            </div>
          </div>
          <Dialog.Footer>
            <>
              <Button
                variant=#outline
                onClick={_ => {
                  setDeadEnd(_ => None)
                  setAdditionalInstructions(_ => "")
                }}>
                {React.string("Cancel")}
              </Button>
              <Button onClick={_ => handleGenerateScene()}>
                <>
                  <WandSparkles className="mr-2" size=14 />
                  {React.string("Generate Scene")}
                </>
              </Button>
            </>
          </Dialog.Footer>
        </>
      </Dialog.Content>
    </Dialog.Root>
  }

  // Scene title shown in the preview header.
  let sceneTitle = switch state.parsedAst {
  | None => None
  | Some(ast) =>
    switch currentScene {
    | Some(scene) => getSceneTitleById(ast, scene)
    | None => getAstTitle(ast)
    }
  }

  <>
    <PlaygroundLayout editorSection previewSection chatSection previewViewportInfo ?sceneTitle />
    {deadEndDialog}
  </>
}
