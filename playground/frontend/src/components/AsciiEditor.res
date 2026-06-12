// ASCII grid editor — wraps Monaco (via LazyMonacoEditor) and overlays the
// wyreframe V1 parser's error + warning decorations. Persists content into
// the per-session localStorage slot used by the rest of the app.

// ---------------------------------------------------------------------------
// Parser result shapes (V1 parser, matches the bundled `wyreframe` library).
// Both parse errors and parse warnings carry the same `{message,line,column}`
// shape — line/column may be undefined for whole-document issues.
// ---------------------------------------------------------------------------

type parseIssue = {
  message: string,
  line: option<int>,
  column: option<int>,
}

// `Wyreframe.parse` returns a tagged-variant Result<Success, Error>. We hold
// the raw return as an opaque object and classify it manually — this avoids
// fighting ReScript variant marshaling when the JS side ships inline records.
type parseSuccess = {warnings: array<parseIssue>}

type parseResult =
  | Success(parseSuccess)
  | ParseError(parseIssue)

@module("wyreframe") external parse: string => {..} = "parse"

let classifyParse = (raw: {..}): parseResult => {
  let tag: string = raw["TAG"]
  let payload = raw["_0"]
  if tag === "Success" {
    Success({warnings: payload["warnings"]})
  } else {
    ParseError({
      message: payload["message"],
      line: payload["line"]->Nullable.toOption,
      column: payload["column"]->Nullable.toOption,
    })
  }
}

// ---------------------------------------------------------------------------
// Monaco editor surface — we hold an opaque editor instance and a decoration
// id array. All Monaco interop happens via %raw.
// ---------------------------------------------------------------------------

type monacoEditor
type monacoInstance

let applyErrorDecorations: (
  monacoEditor,
  array<string>,
  option<parseIssue>,
  array<parseIssue>,
) => array<string> = %raw(`function(editor, prevIds, firstError, warnings) {
  var issues = (warnings && warnings.length > 0)
    ? warnings
    : (firstError !== undefined ? [firstError] : []);
  if (issues.length === 0) {
    return editor.deltaDecorations(prevIds, []);
  }
  var decos = issues.map(function(e) {
    var line = (e.line == null) ? 1 : e.line;
    var col = (e.column == null) ? 1 : e.column;
    return {
      range: {
        startLineNumber: line,
        startColumn: col,
        endLineNumber: line,
        endColumn: col + 10
      },
      options: {
        isWholeLine: false,
        className: "monaco-error-line",
        glyphMarginClassName: "monaco-error-glyph",
        hoverMessage: [{ value: e.message }],
        inlineClassName: "monaco-error-inline"
      }
    };
  });
  return editor.deltaDecorations(prevIds, decos);
}`)

// ---------------------------------------------------------------------------
// Editor language + theme constants. The "wireframe" language id and the
// dark/light theme names mirror the original deployed playground bundle.
// ---------------------------------------------------------------------------

let languageId = "wireframe"

let themeName = (isDark: bool) => isDark ? "wireframe-dark" : "wireframe-light"

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

let defaultOptions = (isDark: bool): editorOptions => {
  language: languageId,
  theme: themeName(isDark),
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
// Tiny debounce helper. We keep the timeout id in a ref so the cleanup effect
// can cancel any pending work on unmount.
// ---------------------------------------------------------------------------

type debounceState = {mutable timeoutId: option<Js.Global.timeoutId>}

let createDebounced = (fn: 'a => unit, delay: int, state: debounceState): ('a => unit) => {
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
// Per-session ASCII content persistence. We only touch the `asciiContent`
// slice of the stored blob — every other field is preserved or defaulted so
// the SessionManager module owned by other agents stays compatible.
// ---------------------------------------------------------------------------

let sessionKeyPrefix = "wyreframe_session_"

let persistAscii: (string, string) => unit = %raw(`function(sessionId, asciiContent) {
  try {
    var key = "wyreframe_session_" + sessionId;
    var now = Date.now();
    var existing = window.localStorage.getItem(key);
    var data;
    if (existing != null) {
      try {
        data = JSON.parse(existing);
      } catch (e) {
        data = null;
      }
    }
    if (data == null || typeof data !== "object") {
      data = {
        sessionId: sessionId,
        asciiContent: asciiContent,
        chatHistory: [],
        viewportState: {
          current: "desktop",
          zoom: 1,
          dimensions: { width: 1440, height: 900 }
        },
        lastUpdated: now,
        createdAt: now
      };
    } else {
      data.asciiContent = asciiContent;
      data.lastUpdated = now;
    }
    window.localStorage.setItem(key, JSON.stringify(data));
  } catch (err) {
    // Swallow storage errors (quota etc.) — the editor must keep working.
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
    let state = {timeoutId: None}
    createDebounced((content: string) => persistAscii(sessionId, content), 300, state)
  })

  // Debounced parser pass — runs the V1 parser, then surfaces the first
  // warning (or the parse error) to both local state and the parent via
  // `onError`. The parent decides what to do with it.
  let parseDebounced = React.useMemo0(() => {
    let state = {timeoutId: None}
    createDebounced((content: string) => {
      let result = classifyParse(parse(content))
      switch result {
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
    }, 300, state)
  })

  // Cancel any pending debounce on unmount so we don't fire setState on a
  // dead component.
  React.useEffect0(() => {
    Some(() => clearDebounce(debounceRef.current))
  })

  // Re-apply Monaco decorations whenever the warning set, error or editor
  // instance changes.
  React.useEffect2(() => {
    switch editorRef {
    | None => ()
    | Some(editor) =>
      let nextIds =
        Array.length(warnings) > 0
          ? applyErrorDecorations(editor, decorationIds, firstError, warnings)
          : applyErrorDecorations(editor, decorationIds, firstError, [])
      setDecorationIds(_ => nextIds)
    }
    None
    // eslint-disable-next-line — decorationIds intentionally omitted to avoid
    // a self-triggering loop; the deltaDecorations call already handles the
    // previous-id bookkeeping.
  }, (warnings, editorRef))

  let handleMount = (editor: monacoEditor, _monaco: monacoInstance) => {
    setEditorRef(_ => Some(editor))
  }

  let handleChange = (next: option<string>, _ev: 'a) => {
    switch next {
    | None => ()
    | Some(content) =>
      onChange(content)
      parseDebounced(content)
      saveDebounced(content)
    }
  }

  let options = defaultOptions(isDark)

  <div className="h-full w-full">
    <Monaco
      value
      language=languageId
      theme={themeName(isDark)}
      options
      onChange=handleChange
      onMount=handleMount
      height="100%"
    />
  </div>
}
