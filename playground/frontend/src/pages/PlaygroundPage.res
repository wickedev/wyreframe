// PlaygroundPage — route entry for `/playground` and `/playground/:sessionId`.
// Resolves (or creates on the backend) a session, persists a default draft to
// localStorage, then renders the inner <Playground>. Reads router location
// state `{initialPrompt}` forwarded from the landing page.

// --- Session model + manager helpers ---------------------------------------
// These mirror the original SessionManager module. They aren't exported by any
// sibling module in the current tree, so they're transcribed here faithfully.

type viewport = Desktop | Tablet | Mobile

type viewportDimensions = {
  width: int,
  height: int,
}

type viewportState = {
  current: viewport,
  zoom: float,
  dimensions: viewportDimensions,
}

type messageRole = User | Assistant | System

type message = {
  id: string,
  role: messageRole,
  content: string,
  timestamp: float,
  metadata: option<JSON.t>,
}

type sessionData = {
  sessionId: string,
  asciiContent: string,
  chatHistory: array<message>,
  viewportState: viewportState,
  lastUpdated: float,
  createdAt: float,
}

let loginFormExample = `@scene: login

+---------------------------+
|       'LOGIN'             |
|                           |
|  +---------------------+  |
|  | #email              |  |
|  +---------------------+  |
|                           |
|  +---------------------+  |
|  | #password           |  |
|  +---------------------+  |
|                           |
|  [x] Remember me          |
|                           |
|       [ Login ]           |
|                           |
|  "Forgot password?"       |
+---------------------------+

#email:
  placeholder: "Enter your email"
  type: email

#password:
  placeholder: "Enter your password"
  type: password

[Login]:
  variant: primary
  @click -> goto(dashboard, fade)
`

let getDefault = () => loginFormExample

let defaultViewportState = (): viewportState => {
  current: Mobile,
  zoom: 1.0,
  dimensions: {width: 375, height: 773},
}

let createDefaultSession = (sessionId: string): sessionData => {
  let now = Date.now()
  {
    sessionId,
    asciiContent: getDefault(),
    chatHistory: [],
    viewportState: defaultViewportState(),
    lastUpdated: now,
    createdAt: now,
  }
}

let sessionKeyPrefix = "wyreframe_session_"

@val @scope(("window", "localStorage")) external lsGetItem: string => Nullable.t<string> = "getItem"
@val @scope(("window", "localStorage")) external lsSetItem: (string, string) => unit = "setItem"

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

let messageRoleToString = (r: messageRole): string =>
  switch r {
  | User => "user"
  | Assistant => "assistant"
  | System => "system"
  }

let serializeSessionData = (s: sessionData): string => {
  let dims = Dict.fromArray([
    ("width", JSON.Encode.int(s.viewportState.dimensions.width)),
    ("height", JSON.Encode.int(s.viewportState.dimensions.height)),
  ])
  let vp = Dict.fromArray([
    ("current", JSON.Encode.string(viewportToString(s.viewportState.current))),
    ("zoom", JSON.Encode.float(s.viewportState.zoom)),
    ("dimensions", JSON.Encode.object(dims)),
  ])
  let chat = s.chatHistory->Array.map(m => {
    let base = [
      ("id", JSON.Encode.string(m.id)),
      ("role", JSON.Encode.string(messageRoleToString(m.role))),
      ("content", JSON.Encode.string(m.content)),
      ("timestamp", JSON.Encode.float(m.timestamp)),
    ]
    let entries = switch m.metadata {
    | Some(md) => Array.concat(base, [("metadata", md)])
    | None => base
    }
    JSON.Encode.object(Dict.fromArray(entries))
  })
  let root = Dict.fromArray([
    ("sessionId", JSON.Encode.string(s.sessionId)),
    ("asciiContent", JSON.Encode.string(s.asciiContent)),
    ("chatHistory", JSON.Encode.array(chat)),
    ("viewportState", JSON.Encode.object(vp)),
    ("lastUpdated", JSON.Encode.float(s.lastUpdated)),
    ("createdAt", JSON.Encode.float(s.createdAt)),
  ])
  JSON.stringify(JSON.Encode.object(root))
}

let saveSession = (s: sessionData): result<unit, string> => {
  try {
    let payload = serializeSessionData({...s, lastUpdated: Date.now()})
    let key = sessionKeyPrefix ++ s.sessionId
    Console.log2("[SessionManager] Saving to key:", key)
    Console.log2("[SessionManager] Content length:", s.asciiContent->String.length)
    lsSetItem(key, payload)
    Ok()
  } catch {
  | Exn.Error(e) =>
    let msg = Exn.message(e)->Option.getOr("Unknown error")
    if msg->String.includes("quota") || msg->String.includes("QuotaExceededError") {
      Error("Storage quota exceeded. Please clear some old sessions.")
    } else {
      Error("Failed to save session: " ++ msg)
    }
  | _ => Error("Failed to save session: Unknown error")
  }
}

// Best-effort deserialize: returns the parsed session if it round-trips,
// otherwise None. (chatHistory is restored empty here.)
let deserializeSessionData = (raw: string): option<sessionData> => {
  try {
    let json = JSON.parseExn(raw)
    switch JSON.Decode.object(json) {
    | None => None
    | Some(obj) =>
      let str = k => obj->Dict.get(k)->Option.flatMap(JSON.Decode.string)
      let flt = k => obj->Dict.get(k)->Option.flatMap(JSON.Decode.float)
      switch (str("sessionId"), str("asciiContent"), flt("lastUpdated"), flt("createdAt")) {
      | (Some(sessionId), Some(asciiContent), Some(lastUpdated), Some(createdAt)) =>
        let viewportState =
          obj
          ->Dict.get("viewportState")
          ->Option.flatMap(JSON.Decode.object)
          ->Option.flatMap(vp => {
            let vstr = k => vp->Dict.get(k)->Option.flatMap(JSON.Decode.string)
            let vflt = k => vp->Dict.get(k)->Option.flatMap(JSON.Decode.float)
            let dims =
              vp
              ->Dict.get("dimensions")
              ->Option.flatMap(JSON.Decode.object)
              ->Option.flatMap(d => {
                let dflt = k => d->Dict.get(k)->Option.flatMap(JSON.Decode.float)
                switch (dflt("width"), dflt("height")) {
                | (Some(w), Some(h)) => Some({width: Float.toInt(w), height: Float.toInt(h)})
                | _ => None
                }
              })
            switch (vstr("current")->Option.flatMap(viewportFromString), vflt("zoom"), dims) {
            | (Some(current), Some(zoom), Some(dimensions)) => Some({current, zoom, dimensions})
            | _ => None
            }
          })
        switch viewportState {
        | Some(vs) =>
          Some({
            sessionId,
            asciiContent,
            chatHistory: [],
            viewportState: vs,
            lastUpdated,
            createdAt,
          })
        | None => None
        }
      | _ => None
      }
    }
  } catch {
  | _ => None
  }
}

let loadSession = (sessionId: string): option<sessionData> => {
  try {
    let key = sessionKeyPrefix ++ sessionId
    Console.log2("[SessionManager] Loading from key:", key)
    switch lsGetItem(key)->Nullable.toOption {
    | None =>
      Console.warn("[SessionManager] No data found in localStorage")
      None
    | Some(raw) =>
      Console.log2("[SessionManager] Found data, length:", raw->String.length)
      switch deserializeSessionData(raw) {
      | Some(session) =>
        Console.log2(
          "[SessionManager] Parsed content length:",
          session.asciiContent->String.length,
        )
        Some(session)
      | None =>
        Console.warn("[SessionManager] Failed to deserialize session")
        None
      }
    }
  } catch {
  | _ => None
  }
}

// --- Backend session creation ----------------------------------------------
// The original returned a richer variant than the shared Client.createSession,
// so it is transcribed locally here.

type createSessionResult =
  | Success(SessionContext.session)
  | NetworkError(string)
  | ApiError(string)
  | RateLimitError(int)

let createSession = async (): createSessionResult => {
  let endpoint = ApiBase.url("/api/sessions")
  try {
    let res = await Fetch.fetch(
      endpoint,
      {"method": "POST", "headers": {"Content-Type": "application/json"}, "body": "{}"},
    )
    if Fetch.status(res) >= 400 {
      let text = await Fetch.text(res)
      ApiError("Failed to create session: " ++ text)
    } else {
      let text = await Fetch.text(res)
      try {
        let json = JSON.parseExn(text)
        switch JSON.Decode.object(json) {
        | None => ApiError("Invalid session response JSON")
        | Some(obj) =>
          switch obj->Dict.get("sessionId")->Option.flatMap(JSON.Decode.string) {
          | Some(sessionId) => Success({sessionId: sessionId})
          | None => ApiError("Invalid session response format")
          }
        }
      } catch {
      | _ => ApiError("Failed to parse session response")
      }
    }
  } catch {
  | Exn.Error(e) => NetworkError(Exn.message(e)->Option.getOr("Unknown network error"))
  | _ => NetworkError("Unknown error creating session")
  }
}

// --- Page ------------------------------------------------------------------

type loadState =
  | Loading
  | Loaded
  | Error(string)

@react.component
let make = () => {
  let params = Router.useParams()
  let navigate = Router.useNavigate()
  let location = Router.useLocation()
  let sessionId = params->Dict.get("sessionId")

  let initialPrompt: option<string> = switch location["state"]->Nullable.toOption {
  | None => None
  | Some(state) =>
    try {state["initialPrompt"]->Nullable.toOption} catch {
    | _ => None
    }
  }

  let (session, setSession) = React.useState((): option<sessionData> => None)
  let (state, setState) = React.useState(() => Loading)
  let initializedSessionId = React.useRef(None)
  let isCreating = React.useRef(false)

  React.useEffect1(() => {
    let shouldSkip = if isCreating.current {
      Console.log("[PlaygroundPage] Already creating session, skipping...")
      true
    } else {
      switch initializedSessionId.current {
      | Some(prev) =>
        switch sessionId {
        | Some(id) =>
          if prev === id {
            Console.log2("[PlaygroundPage] Already initialized sessionId:", id)
            true
          } else {
            false
          }
        | None =>
          Console.log("[PlaygroundPage] sessionId became None after initialization, skipping...")
          true
        }
      | None => false
      }
    }

    if !shouldSkip {
      let run = async () => {
        try {
          setState(_ => Loading)
          switch sessionId {
          | Some(id) =>
            Console.log2("[PlaygroundPage] Loading session:", id)
            switch loadSession(id) {
            | Some(loaded) =>
              Console.log2(
                "[PlaygroundPage] Session loaded, content length:",
                loaded.asciiContent->String.length,
              )
              Console.log2(
                "[PlaygroundPage] First 100 chars:",
                loaded.asciiContent->String.slice(~start=0, ~end=100),
              )
              initializedSessionId.current = Some(id)
              setSession(_ => Some(loaded))
              setState(_ => Loaded)
            | None =>
              Console.warn(
                "[PlaygroundPage] Session " ++ id ++ " not found, redirecting to landing page",
              )
              navigate("/")
            }
          | None =>
            isCreating.current = true
            Console.log("[PlaygroundPage] Creating new session on backend...")
            let result = await createSession()
            switch result {
            | Success({sessionId: newId}) =>
              Console.log("[PlaygroundPage] Backend session created: " ++ newId)
              let fresh = createDefaultSession(newId)
              let _ = saveSession(fresh)
              initializedSessionId.current = Some(newId)
              isCreating.current = false
              navigate("/playground/" ++ newId)
              setSession(_ => Some(fresh))
              setState(_ => Loaded)
            | NetworkError(err) =>
              Console.error("[PlaygroundPage] Network error: " ++ err)
              isCreating.current = false
              setState(_ => Error("Network error: " ++ err))
            | ApiError(err) =>
              Console.error("[PlaygroundPage] Backend session creation failed: " ++ err)
              isCreating.current = false
              setState(_ => Error(err))
            | RateLimitError(retryAfter) =>
              let msg =
                "Rate limit exceeded. Retry after " ++ retryAfter->Int.toString ++ " seconds"
              Console.error(msg)
              isCreating.current = false
              setState(_ => Error(msg))
            }
          }
        } catch {
        | Exn.Error(e) =>
          let msg = Exn.message(e)->Option.getOr("Unknown error")
          Console.error2("[PlaygroundPage] Error initializing session:", msg)
          isCreating.current = false
          setState(_ => Error("Failed to initialize session. Please try again."))
        | _ =>
          Console.error("[PlaygroundPage] Unknown error initializing session")
          isCreating.current = false
          setState(_ => Error("Failed to initialize session. Please try again."))
        }
      }
      run()->Promise.done
    }
    None
  }, [sessionId])

  // initialPrompt is forwarded into the inner page; it takes no props in the
  // current interface, so keep it referenced as part of the page state graph.
  let _ = initialPrompt

  switch state {
  | Loading =>
    <div className="h-screen flex items-center justify-center">
      <div className="text-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4" />
        <p className="text-muted-foreground"> {React.string("Loading playground...")} </p>
      </div>
    </div>
  | Loaded =>
    switch session {
    | None => React.null
    | Some(resolved) =>
      // The inner <Playground> reads its session via SessionContext, so the
      // resolved session id is provided here.
      let ctx: SessionContext.contextValue = {
        ...SessionContext.defaultValue,
        session: Some({sessionId: resolved.sessionId}),
      }
      <SessionContext.Provider value={ctx}>
        <Playground sessionId={resolved.sessionId} initialPrompt=?{initialPrompt} />
      </SessionContext.Provider>
    }
  | Error(msg) =>
    <div className="h-screen flex items-center justify-center">
      <div className="text-center max-w-md">
        <div className="bg-destructive/10 text-destructive rounded-lg p-6 mb-4">
          <h2 className="text-lg font-semibold mb-2"> {React.string("Error")} </h2>
          <p> {React.string(msg)} </p>
        </div>
        <button
          className="bg-primary text-primary-foreground hover:bg-primary/90 rounded-md px-4 py-2 font-medium transition-colors"
          onClick={_ => navigate("/")}>
          {React.string("Return to Home")}
        </button>
      </div>
    </div>
  }
}
