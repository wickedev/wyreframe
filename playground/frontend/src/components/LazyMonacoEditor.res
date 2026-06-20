// Lazy-loaded Monaco editor wrapper. Loads Monaco from the jsdelivr CDN and
// shows a Skeleton fallback while the chunk + editor initialise.

// --- Monaco loader configuration -------------------------------------------

// Configure @monaco-editor/loader to fetch the editor from cdn.jsdelivr.net.
// Runs once on module load; the loader package is idempotent and safe to
// re-configure across HMR.
%%raw(`
  import loader from "@monaco-editor/loader";
  loader.config({
    paths: { vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.55.1/min/vs" },
  });
`)

// --- Custom wireframe themes ------------------------------------------------

type themeRule = {
  token: string,
  foreground: string,
  fontStyle?: string,
}

type themeDef = {
  base: string,
  inherit: bool,
  rules: array<themeRule>,
  colors: Dict.t<string>,
}

let wireframeDarkRules: array<themeRule> = [
  {token: "type.identifier", foreground: "5B9BF5", fontStyle: "bold"},
  {token: "variable.property", foreground: "C792EA"},
  {token: "keyword", foreground: "89DDFF"},
  {token: "string", foreground: "98C379"},
  {token: "number", foreground: "F78C6C"},
  {token: "comment", foreground: "6A9955", fontStyle: "italic"},
  {token: "delimiter", foreground: "6b7280"},
  {token: "delimiter.bracket", foreground: "6b7280"},
  {token: "delimiter.angle", foreground: "6b7280"},
]

let wireframeDarkColors = Dict.fromArray([
  ("editor.background", "#0c0d10"),
  ("editor.foreground", "#a0a8b8"),
  ("editorLineNumber.foreground", "#4a5568"),
  ("editorCursor.foreground", "#8b95a8"),
  ("editor.selectionBackground", "#1e3a5f"),
  ("editor.lineHighlightBackground", "#12141a"),
  ("editorGutter.background", "#0c0d10"),
  ("editorWidget.background", "#0c0d10"),
  ("editorWidget.border", "#1e2028"),
])

let wireframeDarkTheme: themeDef = {
  base: "vs-dark",
  inherit: true,
  rules: wireframeDarkRules,
  colors: wireframeDarkColors,
}

let wireframeLightRules: array<themeRule> = [
  {token: "type.identifier", foreground: "0066CC", fontStyle: "bold"},
  {token: "variable.property", foreground: "9333EA"},
  {token: "keyword", foreground: "0891B2"},
  {token: "string", foreground: "16A34A"},
  {token: "number", foreground: "EA580C"},
  {token: "comment", foreground: "6B7280", fontStyle: "italic"},
  {token: "delimiter", foreground: "4B5563"},
  {token: "delimiter.bracket", foreground: "4B5563"},
  {token: "delimiter.angle", foreground: "4B5563"},
]

let wireframeLightColors = Dict.fromArray([
  ("editor.background", "#FFFFFF"),
  ("editor.foreground", "#1F2937"),
  ("editorLineNumber.foreground", "#9CA3AF"),
  ("editorCursor.foreground", "#1F2937"),
  ("editor.selectionBackground", "#B3D7FF"),
  ("editor.lineHighlightBackground", "#F3F4F6"),
  ("editorGutter.background", "#FFFFFF"),
])

let wireframeLightTheme: themeDef = {
  base: "vs",
  inherit: true,
  rules: wireframeLightRules,
  colors: wireframeLightColors,
}

let themesRegistered = ref(false)

let defineTheme: (Js.Json.t, string, themeDef) => unit = %raw(`
  function(monaco, name, theme) { monaco.editor.defineTheme(name, theme); }
`)

// Register the custom wireframe themes against the Monaco instance, once.
let registerThemes = (monaco: Js.Json.t): unit =>
  if !themesRegistered.contents {
    try {
      defineTheme(monaco, "wireframe-dark", wireframeDarkTheme)
      defineTheme(monaco, "wireframe-light", wireframeLightTheme)
      themesRegistered := true
      Console.log("[Monaco] Custom themes registered successfully")
    } catch {
    | exn => Console.error2("[Monaco] Failed to register themes:", exn)
    }
  }

// --- Lazy boundary ----------------------------------------------------------

type editorProps = {
  value: string,
  language: string,
  theme: string,
  options: option<Js.Json.t>,
  onChange: option<(option<string>, Js.Json.t) => unit>,
  onMount: option<(Js.Json.t, Js.Json.t) => unit>,
  height: string,
  width: string,
}

// React.lazy(() => import("@monaco-editor/react")) — dynamic chunk so Monaco
// is only fetched when an editor is actually rendered. The dynamic import
// resolves to the module namespace `{default: Editor, ...}`, which is exactly
// the shape React.lazy expects.
@module("react")
external reactLazy: (
  unit => promise<{"default": React.component<editorProps>}>
) => React.component<editorProps> = "lazy"

let importMonacoEditor: unit => promise<{"default": React.component<editorProps>}> = %raw(`
  () => import("@monaco-editor/react")
`)

let lazyMonacoEditor: React.component<editorProps> = reactLazy(importMonacoEditor)

// --- Skeleton fallback ------------------------------------------------------

module EditorSkeleton = {
  @react.component
  let make = (~width: string="100%", ~height: string="100%") =>
    <div className="relative bg-muted/30 rounded-md overflow-hidden" style={{height, width}}>
      <div className="absolute inset-0 flex flex-col gap-2 p-4">
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 flex-1" />
        </div>
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 w-3/4" />
        </div>
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 w-2/3" />
        </div>
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 w-full" />
        </div>
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 w-4/5" />
        </div>
        <div className="flex gap-3">
          <Skeleton className="h-4 w-8" /> <Skeleton className="h-4 w-1/2" />
        </div>
      </div>
      <div className="absolute inset-0 flex items-center justify-center bg-background/50">
        <div className="text-sm text-muted-foreground"> {React.string("Loading editor...")} </div>
      </div>
    </div>
}

// --- Error fallback ---------------------------------------------------------

module ErrorFallback = {
  @react.component
  let make = (~error: option<Js.Exn.t>=?) =>
    <div
      className="h-full w-full flex items-center justify-center bg-destructive/10 rounded-md p-4">
      <div className="text-center max-w-md">
        <h3 className="text-lg font-semibold text-destructive mb-2">
          {React.string("Failed to load editor")}
        </h3>
        <p className="text-sm text-muted-foreground mb-4">
          {React.string("The code editor failed to load. Please refresh the page to try again.")}
        </p>
        {switch error {
        | Some(err) =>
          <details className="text-xs text-left bg-muted p-2 rounded">
            <summary className="cursor-pointer font-medium mb-1">
              {React.string("Error details")}
            </summary>
            <pre className="whitespace-pre-wrap">
              {React.string(Js.Exn.message(err)->Option.getOr("Unknown error"))}
            </pre>
          </details>
        | None => React.null
        }}
      </div>
    </div>
}

// --- react-error-boundary binding ------------------------------------------

module ErrorBoundary = {
  @module("react-error-boundary") @react.component
  external make: (~fallback: React.element, ~children: React.element) => React.element =
    "ErrorBoundary"
}

// --- Public component -------------------------------------------------------

@react.component
let make = (
  ~value: string,
  ~language: string,
  ~theme: string,
  ~options: option<Js.Json.t>=?,
  ~onChange: option<option<string> => unit>=?,
  ~onMount: option<(Js.Json.t, Js.Json.t) => unit>=?,
  ~height: string="100%",
  ~width: string="100%",
) => {
  // onMount: register the wireframe themes, then forward to the caller's hook.
  let handleMount = React.useCallback1((editor, monaco) => {
    registerThemes(monaco)
    switch onMount {
    | Some(fn) => fn(editor, monaco)
    | None => ()
    }
  }, [onMount])

  // Monaco emits the raw editor value (possibly undefined); collapse it into an
  // option<string> before handing it to the caller — mirrors `map$2`.
  let handleChange = switch onChange {
  | Some(cb) => Some((v: option<string>, _ev: Js.Json.t) => cb(v))
  | None => None
  }

  let props: editorProps = {
    value,
    language,
    theme,
    options,
    onChange: handleChange,
    onMount: Some(handleMount),
    height,
    width,
  }

  <ErrorBoundary fallback={<ErrorFallback />}>
    <React.Suspense fallback={<EditorSkeleton height width />}>
      {React.createElement(lazyMonacoEditor, props)}
    </React.Suspense>
  </ErrorBoundary>
}
