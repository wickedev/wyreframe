// ASCII grid editor — wraps Monaco (via LazyMonacoEditor) and overlays the
// wyreframe parser's error + warning decorations, persisting content into the
// per-session localStorage slot used by the rest of the app.

// ---------------------------------------------------------------------------
// Parser result shapes. The bundled `wyreframe` parser returns a tagged
// Result<Success, Error>; both warnings and parse errors carry the same
// `{message, line, column}` issue shape (line/column optional).
// ---------------------------------------------------------------------------

type parseIssue = {
  message: string,
  line: option<int>,
  column: option<int>,
}

type parseSuccess = {warnings: array<parseIssue>}

type parseResult =
  | Success(parseSuccess)
  | ParseError(parseIssue)

@module("wyreframe") external parse: string => {..} = "parse"

let classifyParse = (raw: {..}): parseResult => {
  let tag: string = raw["TAG"]
  if tag === "Success" {
    Success({warnings: raw["_0"]["warnings"]})
  } else {
    let payload = raw["_0"]
    ParseError({
      message: payload["message"],
      line: payload["line"]->Nullable.toOption,
      column: payload["column"]->Nullable.toOption,
    })
  }
}

// ---------------------------------------------------------------------------
// Monaco editor surface — opaque editor instance + decoration-id array. All
// Monaco interop happens via %raw, matching the deployed bundle.
// ---------------------------------------------------------------------------

type monacoEditor

// createErrorDecoration + applyErrorDecorations, ported verbatim from the
// bundle. `applyErrorDecorations(editor, prevIds, firstError, warnings)`:
//   - prefers the warnings array; falls back to [firstError]; else clears.
let applyErrorDecorations: (
  monacoEditor,
  array<string>,
  option<parseIssue>,
  option<array<parseIssue>>,
) => array<string> = %raw(`function(editor, prevIds, firstError, warnings) {
  function createErrorDecoration(e) {
    var line = (e.line == null) ? 1 : e.line;
    var col = (e.column == null) ? 1 : e.column;
    return {
      range: {
        startLineNumber: line,
        startColumn: col,
        endLineNumber: line,
        endColumn: (col + 10) | 0
      },
      options: {
        isWholeLine: false,
        className: "monaco-error-line",
        glyphMarginClassName: "monaco-error-glyph",
        hoverMessage: [{ value: e.message }],
        inlineClassName: "monaco-error-inline"
      }
    };
  }
  var issues = (warnings !== undefined)
    ? (warnings.length > 0 ? warnings : (firstError !== undefined ? [firstError] : []))
    : (firstError !== undefined ? [firstError] : []);
  if (issues.length <= 0) {
    return editor.deltaDecorations(prevIds, []);
  }
  var decos = issues.map(createErrorDecoration);
  return editor.deltaDecorations(prevIds, decos);
}`)

// ---------------------------------------------------------------------------
// Editor language + theme + default options. The "wireframe" language id and
// the dark/light theme names mirror the deployed playground bundle.
// ---------------------------------------------------------------------------

let languageId = "wireframe"

let getLanguageId = () => languageId

let getThemeName = (isDark: bool) => isDark ? "wireframe-dark" : "wireframe-light"

type editorOptions = {
  language: string,
  theme: string,
  minimap: {"enabled": bool},
  fontSize: int,
  lineNumbers: string,
  wordWrap: string,
  automaticLayout: bool,
  scrollBeyondLastLine: bool,
  tabSize: int,
  insertSpaces: bool,
  suggestOnTriggerCharacters: bool,
  quickSuggestions: bool,
}

let createDefaultOptions = (isDark: bool): editorOptions => {
  language: languageId,
  theme: isDark ? "wireframe-dark" : "wireframe-light",
  minimap: {"enabled": false},
  fontSize: 14,
  lineNumbers: "on",
  wordWrap: "off",
  automaticLayout: true,
  scrollBeyondLastLine: false,
  tabSize: 2,
  insertSpaces: true,
  suggestOnTriggerCharacters: true,
  quickSuggestions: true,
}

// ---------------------------------------------------------------------------
// Debounce helper, ported from the bundle's `createDebounced` / `clearDebounce`.
// State (timeout id) lives in a closure-local record per debounced fn.
// ---------------------------------------------------------------------------

type debounceState = {mutable timeoutId: option<Js.Global.timeoutId>}

let createDebounced = (fn: 'a => unit, delay: int): ('a => unit) => {
  let state = {timeoutId: None}
  arg => {
    switch state.timeoutId {
    | Some(id) => Js.Global.clearTimeout(id)
    | None => ()
    }
    let id = Js.Global.setTimeout(() => {
      state.timeoutId = None
      fn(arg)
    }, delay)
    state.timeoutId = Some(id)
  }
}

let clearDebounce = (state: debounceState) => {
  switch state.timeoutId {
  | Some(id) =>
    Js.Global.clearTimeout(id)
    state.timeoutId = None
  | None => ()
  }
}

// ---------------------------------------------------------------------------
// Per-session content persistence. Mirrors the bundle's SessionManager flow:
// load the existing session and overwrite only `asciiContent`/`lastUpdated`,
// preserving every other field; if none exists, create a default session.
// Kept inline (no SessionManager module is exported to the frontend).
// ---------------------------------------------------------------------------

let sessionKeyPrefix = "wyreframe_session_"

let saveAsciiContent: (string, string) => unit = %raw(`function(sessionId, asciiContent) {
  try {
    var key = "wyreframe_session_" + sessionId;
    var now = Date.now();
    var existing = window.localStorage.getItem(key);
    var data = null;
    if (existing != null) {
      try { data = JSON.parse(existing); } catch (e) { data = null; }
    }
    if (data != null && typeof data === "object") {
      data.asciiContent = asciiContent;
      data.lastUpdated = now;
    } else {
      data = {
        sessionId: sessionId,
        asciiContent: asciiContent,
        chatHistory: [],
        viewportState: {
          current: "Mobile",
          zoom: 1,
          dimensions: { width: 375, height: 773 }
        },
        lastUpdated: now,
        createdAt: now
      };
    }
    window.localStorage.setItem(key, JSON.stringify(data));
  } catch (err) {
    if (typeof console !== "undefined") {
      console.warn("[AsciiEditor] failed to persist session", err);
    }
  }
}`)

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

@react.component
let make = (
  ~value: string,
  ~sessionId: string,
  ~onChange: string => unit,
  ~onError: option<parseIssue> => unit=_ => (),
  ~isDark: bool=false,
) => {
  let (editorRef, setEditorRef) = React.useState((): option<monacoEditor> => None)
  let (decorationIds, setDecorationIds) = React.useState((): array<string> => [])
  let (firstError, setFirstError) = React.useState((): option<parseIssue> => None)
  let (warnings, setWarnings) = React.useState((): array<parseIssue> => [])
  let debounceRef = React.useRef({timeoutId: None})

  // Debounced session-storage write — fires 300ms after the last edit.
  let saveDebounced = React.useMemo0(() => {
    createDebounced((content: string) => saveAsciiContent(sessionId, content), 300)
  })

  // Debounced parser pass — runs the parser, surfaces the first warning (or
  // the parse error) to local state and to the parent via `onError`, then
  // emits the content through `onChange`.
  let parseDebounced = React.useMemo0(() => {
    createDebounced((content: string) => {
      switch classifyParse(parse(content)) {
      | Success({warnings: ws}) =>
        setWarnings(_ => ws)
        switch ws[0] {
        | Some(first) =>
          setFirstError(_ => Some(first))
          onError(Some(first))
        | None =>
          setFirstError(_ => None)
          onError(None)
        }
      | ParseError(err) =>
        setFirstError(_ => Some(err))
        setWarnings(_ => [err])
        onError(Some(err))
      }
      onChange(content)
    }, 300)
  })

  // Re-apply Monaco decorations whenever the warning set or editor instance
  // changes. decorationIds is intentionally not a dependency — deltaDecorations
  // already does the previous-id bookkeeping, avoiding a self-triggering loop.
  React.useEffect2(() => {
    switch editorRef {
    | None => ()
    | Some(editor) =>
      let nextIds =
        Array.length(warnings) > 0
          ? applyErrorDecorations(editor, decorationIds, firstError, Some(warnings))
          : applyErrorDecorations(editor, decorationIds, firstError, None)
      setDecorationIds(_ => nextIds)
    }
    None
  }, (warnings, editorRef))

  // Cancel any pending debounce on unmount.
  React.useEffect0(() => {
    Some(() => clearDebounce(debounceRef.current))
  })

  let handleMount = (editor: Js.Json.t, _monaco: Js.Json.t) => {
    setEditorRef(_ => Some((Obj.magic(editor): monacoEditor)))
  }

  // LazyMonacoEditor forwards Monaco's `option<string>` value (None on clear).
  let handleChange = (value: option<string>) => {
    let content = value->Option.getOr("")
    onChange(content)
    parseDebounced(content)
    saveDebounced(content)
  }

  let options = createDefaultOptions(isDark)

  <div className="h-full w-full">
    <LazyMonacoEditor
      value
      language={getLanguageId()}
      theme={getThemeName(isDark)}
      options={Obj.magic(options)}
      onChange=handleChange
      onMount=handleMount
      height="100%"
      width="100%"
    />
  </div>
}
