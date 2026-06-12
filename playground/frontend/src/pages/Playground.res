// Playground — top-level authoring surface. Composes <AsciiEditor>, <LivePreview>,
// and <LLMChat> inside <PlaygroundLayout>, owns the shared ascii / theme /
// selected-scene state, and persists ascii content to localStorage under a
// session-scoped key.

type parseError = {
  message: string,
  line: option<int>,
  column: option<int>,
}

type parseWarning = {
  message: string,
  line: option<int>,
  column: option<int>,
}

let defaultAscii = `# Welcome

[Sign in] [Sign up]

A clean wireframe playground for sketching screen flows in plain text.
`

let storageKeyFor = (sessionId: string): string =>
  SessionContext.storageKeyPrefix ++ sessionId ++ "_ascii"

let loadAscii = (sessionId: string): string =>
  switch Global.lsGet(storageKeyFor(sessionId))->Nullable.toOption {
  | Some(v) if v !== "" => v
  | _ => defaultAscii
  }

@react.component
let make = () => {
  let ctx = SessionContext.use()
  let sessionId = switch ctx.session {
  | Some({sessionId}) => sessionId
  | None => "anonymous"
  }

  let (asciiContent, setAsciiContent) = React.useState(() => loadAscii(sessionId))
  let (theme, setTheme) = React.useState(() => Theme.load())
  let (selectedScene, setSelectedScene) = React.useState((): option<string> => None)
  let (availableScenes, setAvailableScenes) = React.useState((): array<string> => [])
  let (parseError, setParseError) = React.useState((): option<parseError> => None)
  let (parseWarnings, setParseWarnings) = React.useState((): array<parseWarning> => [])

  // Persist ascii content per-session whenever it changes. Skips the empty
  // string so we don't clobber the saved draft mid-edit.
  React.useEffect2(() => {
    if asciiContent !== "" {
      Global.lsSet(storageKeyFor(sessionId), asciiContent)
    }
    None
  }, (sessionId, asciiContent))

  // If the session id changes (e.g. after sign-in), reload the persisted draft.
  React.useEffect1(() => {
    setAsciiContent(_ => loadAscii(sessionId))
    setSelectedScene(_ => None)
    setAvailableScenes(_ => [])
    setParseError(_ => None)
    setParseWarnings(_ => [])
    None
  }, [sessionId])

  let handleAsciiChange = (next: string) => setAsciiContent(_ => next)
  let handleThemeChange = (next: string) => setTheme(_ => next)
  let handleAsciiUpdate = (next: string) => setAsciiContent(_ => next)

  let onAsciiError = (err: option<AsciiEditor.parseIssue>) => {
    switch err {
    | Some({message, line, column}) => setParseError(_ => Some({message, line, column}))
    | None => setParseError(_ => None)
    }
  }
  let editor =
    <AsciiEditor
      value=asciiContent
      sessionId
      onChange=handleAsciiChange
      onError=onAsciiError
    />

  let preview =
    <LivePreview
      asciiContent
      theme
      ?selectedScene
    />

  let chat =
    <LLMChat
      sessionId
      currentAscii=asciiContent
      onAsciiUpdate=handleAsciiUpdate
    />

  // Silence unused-binding warnings for state setters that downstream
  // hooks (parser, scene introspection) will wire up once those modules
  // come online. The setters/values themselves are part of the documented
  // state graph for this page.
  let _ = (setAvailableScenes, setSelectedScene, setParseError, setParseWarnings)

  let _ = (theme, handleThemeChange, availableScenes)
  <PlaygroundLayout
    editorSection=editor
    previewSection=preview
    chatSection=chat
    sceneTitle=?selectedScene
  />
}
