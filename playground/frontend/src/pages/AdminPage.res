// Admin / Token Pool Manager page — lists OAuth tokens with usage/Rate Limit
// monitoring, supports manual JSON paste + OAuth login, and token deletion.
// Reconstructed from the deployed bundle; Korean copy preserved verbatim.

type token = {
  id: string,
  account: option<string>,
  isActive: bool,
  expiresAt: float,
  createdAt: float,
}

type counts = {
  total: int,
  active: int,
}

type notifKind = Success | Error | Info

type notif = {
  message: string,
  @as("type") type_: notifKind,
}

let getTokenStatus = (t: token): string =>
  if !t.isActive || t.expiresAt < Date.now() {
    "expired"
  } else {
    "active"
  }

let formatTimeRemaining = (expiresAt: float): string => {
  let diff = expiresAt -. Date.now()
  if diff < 0.0 {
    "Expired"
  } else {
    let hours = Js.Math.floor_int(diff /. (1000.0 *. 60.0 *. 60.0))
    let minutes = Js.Math.floor_int(mod_float(diff, 1000.0 *. 60.0 *. 60.0) /. (1000.0 *. 60.0))
    if hours > 0 {
      Int.toString(hours) ++ "h " ++ Int.toString(minutes) ++ "m"
    } else {
      Int.toString(minutes) ++ "m"
    }
  }
}

@send
external dateToLocaleStringRaw: (Date.t, string, {..}) => string = "toLocaleString"

let formatDate = (ts: float): string => {
  let d = Date.fromTime(ts)
  dateToLocaleStringRaw(
    d,
    "ko-KR",
    {
      "year": "numeric",
      "month": "2-digit",
      "day": "2-digit",
      "hour": "2-digit",
      "minute": "2-digit",
    },
  )
}

// Raw fetch surface — the deployed bundle hits the backend directly here
// rather than going through the typed Client module.
@val external fetch: string => promise<'res> = "fetch"
@val external fetchWithInit: (string, {..}) => promise<'res> = "fetch"
@send external resJson: 'res => promise<'json> = "json"
@get external resOk: 'res => bool = "ok"
@get external resStatus: 'res => int = "status"
@get external resHeaders: 'res => {..} = "headers"

let apiBase = ""

@val external windowConfirm: string => bool = "window.confirm"
@val external windowOpen: (string, string, string) => Nullable.t<{..}> = "window.open"

type messageData = {
  @as("type") type_?: string,
  account?: string,
}
type messageEvent = {data: Nullable.t<messageData>}

@send
external addMessageListener: (Dom.window, @as("message") _, messageEvent => unit) => unit =
  "addEventListener"
@send
external removeMessageListener: (Dom.window, @as("message") _, messageEvent => unit) => unit =
  "removeEventListener"
@val external window: Dom.window = "window"

@react.component
let make = () => {
  let (tokens, setTokens) = React.useState((): array<token> => [])
  let (_usage, setUsage) = React.useState(() => Dict.make())
  let (counts, setCounts) = React.useState(() => {total: 0, active: 0})
  let (serverOk, setServerOk) = React.useState(() => false)
  let (loading, setLoading) = React.useState(() => true)
  let (refreshing, setRefreshing) = React.useState(() => false)
  let (totalRequests, _setTotalRequests) = React.useState(() => 0)
  let (addOpen, setAddOpen) = React.useState(() => false)
  let (manualJson, setManualJson) = React.useState(() => "")
  let (adding, setAdding) = React.useState(() => false)
  let (notif, setNotif) = React.useState((): option<notif> => None)

  let showNotif = React.useCallback1((message, type_) => {
    setNotif(_ => Some({message, type_}))
    let _ = Js.Global.setTimeout(() => setNotif(_ => None), 3000)
  }, [setNotif])

  let checkStatus = React.useCallback0(async () => {
    try {
      let res = await fetch(apiBase ++ "/api/status")
      let json = await resJson(res)
      setServerOk(_ => json["status"] === "ok")
    } catch {
    | _ => setServerOk(_ => false)
    }
  })

  let refreshTokens = React.useCallback1(async (force: bool) => {
    if force {
      setRefreshing(_ => true)
    }
    try {
      let res = await fetch(apiBase ++ "/api/tokens")
      let json = await resJson(res)
      let toks: array<token> = json["tokens"]
      setTokens(_ => toks)
      setCounts(_ => {total: json["total"], active: json["active"]})
      let nextUsage = Dict.make()
      let _ = await Promise.all(
        toks->Array.map(async tok => {
          try {
            let url = force
              ? apiBase ++ "/api/usage/" ++ tok.id ++ "?refresh=true"
              : apiBase ++ "/api/usage/" ++ tok.id
            let uRes = await fetch(url)
            let uJson = await resJson(uRes)
            nextUsage->Dict.set(tok.id, uJson)
          } catch {
          | _ => ()
          }
        }),
      )
      setUsage(_ => nextUsage)
      if force {
        showNotif("Usage info refreshed", Success)
      }
    } catch {
    | e =>
      Console.error2("Failed to refresh tokens:", e)
      if force {
        showNotif("Refresh failed", Error)
      }
    }
    setLoading(_ => false)
    setRefreshing(_ => false)
  }, [showNotif])

  let deleteToken = React.useCallback2(async (id: string) => {
    if windowConfirm("Delete this token?") {
      try {
        let res = await fetchWithInit(apiBase ++ "/api/tokens/" ++ id, {"method": "DELETE"})
        let json = await resJson(res)
        if json["success"] {
          showNotif("Token deleted", Success)
          let _ = refreshTokens(false)
        } else {
          let msg = switch Nullable.toOption(json["error"]) {
          | Some(e) => e
          | None => "Failed to delete token"
          }
          showNotif(msg, Error)
        }
      } catch {
      | _ => showNotif("Server connection error", Error)
      }
    }
  }, (showNotif, refreshTokens))

  let addManual = React.useCallback2(async () => {
    let trimmed = String.trim(manualJson)
    if trimmed === "" {
      showNotif("Please enter JSON", Error)
    } else {
      let parsedOpt = try Some(JSON.parseExn(trimmed)) catch {
      | _ => None
      }
      switch parsedOpt {
      | None => showNotif("Invalid JSON format", Error)
      | Some(parsed) =>
        let obj: {"access_token": Nullable.t<string>, "expires_in": Nullable.t<float>} =
          parsed->Obj.magic
        if Nullable.toOption(obj["access_token"]) === None {
          showNotif("access_token field is required", Error)
        } else if Nullable.toOption(obj["expires_in"]) === None {
          showNotif("expires_in field is required", Error)
        } else {
          setAdding(_ => true)
          try {
            let init = {
              "method": "POST",
              "headers": {"Content-Type": "application/json"},
              "body": trimmed,
            }
            let res = await fetchWithInit(apiBase ++ "/api/tokens/manual", init)
            let json = await resJson(res)
            if json["success"] {
              showNotif("Token added", Success)
              setManualJson(_ => "")
              let _ = refreshTokens(false)
            } else {
              let msg = switch Nullable.toOption(json["error"]) {
              | Some(e) => e
              | None => "Failed to add token"
              }
              showNotif(msg, Error)
            }
          } catch {
          | e =>
            Console.error2("Add manual token error:", e)
            showNotif("Server connection error", Error)
          }
          setAdding(_ => false)
        }
      }
    }
  }, (manualJson, refreshTokens))

  let startOauth = React.useCallback1(async () => {
    try {
      showNotif("Starting OAuth authentication...", Info)
      let res = await fetch(apiBase ++ "/api/auth/start")
      if resOk(res) {
        let ct: Nullable.t<string> = resHeaders(res)["get"]("content-type")
        switch Nullable.toOption(ct) {
        | None => showNotif("Server response error: please restart the server", Error)
        | Some(ctv) if !String.includes(ctv, "application/json") =>
          showNotif("Server response error: please restart the server", Error)
        | Some(_) =>
          let json = await resJson(res)
          switch Nullable.toOption(json["authUrl"]) {
          | None =>
            switch Nullable.toOption(json["error"]) {
            | None => showNotif("Failed to create OAuth URL", Error)
            | Some(err) => showNotif("OAuth error: " ++ err, Error)
            }
          | Some(authUrl) =>
            let popup = windowOpen(authUrl, "_blank", "width=600,height=700")
            if Nullable.toOption(popup) === None {
              showNotif("Popup was blocked. Please allow popups.", Error)
            } else {
              showNotif("Please complete login in your browser", Info)
            }
          }
        }
      } else {
        let s = Int.toString(resStatus(res))
        showNotif("Server error (" ++ s ++ "): please restart the server", Error)
      }
    } catch {
    | e =>
      Console.error2("OAuth error:", e)
      showNotif("Failed to start OAuth", Error)
    }
  }, [showNotif])

  // OAuth postMessage listener
  React.useEffect2(() => {
    let handler = (ev: messageEvent) => {
      switch Nullable.toOption(ev.data) {
      | Some(d) if d.type_ === Some("oauth-success") =>
        let account = switch d.account {
        | Some(a) => a
        | None => "Unknown"
        }
        showNotif("Token added: " ++ account, Success)
        let _ = refreshTokens(false)
      | _ => ()
      }
    }
    addMessageListener(window, handler)
    Some(() => removeMessageListener(window, handler))
  }, (refreshTokens, showNotif))

  // Initial load + polling
  React.useEffect2(() => {
    let _ = (async () => {
      let _ = await checkStatus()
      let _ = await refreshTokens(false)
    })()
    let tokensTimer = Js.Global.setInterval(() => {
      let _ = refreshTokens(false)
    }, 10000)
    let statusTimer = Js.Global.setInterval(() => {
      let _ = checkStatus()
    }, 5000)
    Some(
      () => {
        Js.Global.clearInterval(tokensTimer)
        Js.Global.clearInterval(statusTimer)
      },
    )
  }, (checkStatus, refreshTokens))

  let notifEl = switch notif {
  | None => React.null
  | Some({message, type_}) =>
    let borderCls = switch type_ {
    | Success => "bg-card border-success"
    | Error => "bg-card border-destructive"
    | Info => "bg-card border-border"
    }
    <div
      className={"fixed bottom-8 left-1/2 -translate-x-1/2 px-6 py-3 rounded-lg border shadow-lg z-50 " ++
      borderCls}>
      {React.string(message)}
    </div>
  }

  <div className="min-h-screen bg-background text-foreground">
    <header className="bg-card border-b border-border px-6 py-4">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold flex items-center gap-3">
            {React.string("Token Pool Manager")}
            <span
              className="bg-primary text-primary-foreground px-3 py-1 rounded-full text-sm font-medium">
              {React.string("Claudius OAuth")}
            </span>
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            {React.string("Real-time token status and rate-limit monitoring")}
          </p>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <div
              className={"w-2 h-2 rounded-full " ++ (
                serverOk ? "bg-success animate-pulse" : "bg-destructive"
              )}
            />
            <span className="text-sm text-muted-foreground">
              {React.string(serverOk ? "Server connected" : "Server connection failed")}
            </span>
          </div>
          <a
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            href="/">
            {React.string("← Back to Playground")}
          </a>
        </div>
      </div>
    </header>
    <main className="p-6">
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("Total tokens")} </div>
          <div className="text-2xl font-bold"> {React.string(Int.toString(counts.total))} </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("Active tokens")} </div>
          <div className="text-2xl font-bold text-success">
            {React.string(Int.toString(counts.active))}
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("Total requests")} </div>
          <div className="text-2xl font-bold"> {React.string(Int.toString(totalRequests))} </div>
        </div>
      </div>
      <div className="bg-card rounded-lg border border-border p-4 mb-6">
        <button
          className="w-full flex items-center gap-2 text-left font-semibold"
          onClick={_ => setAddOpen(o => !o)}>
          <span className={"transition-transform " ++ (addOpen ? "rotate-90" : "")}>
            {React.string("▶")}
          </span>
          {React.string("Add token")}
        </button>
        {addOpen
          ? <div className="mt-4 space-y-4">
              <div className="bg-muted rounded-lg p-4">
                <h3 className="text-sm font-semibold text-secondary-foreground mb-3">
                  {React.string("Manual token entry")}
                </h3>
                <div className="space-y-3">
                  <div>
                    <label className="block text-xs text-muted-foreground mb-1">
                      {React.string("OAuth Response JSON *")}
                    </label>
                    <textarea
                      className="w-full px-3 py-2 bg-background border border-input rounded-md text-sm text-foreground placeholder-muted-foreground focus:border-primary focus:outline-none resize-none font-mono"
                      placeholder={`{
  "access_token": "sk-ant-oat01-...",
  "refresh_token": "sk-ant-ort01-...",
  "expires_in": 28800,
  "account": { "email_address": "user@example.com" }
}`}
                      rows={7}
                      value={manualJson}
                      onChange={ev => {
                        let v = ReactEvent.Form.target(ev)["value"]
                        setManualJson(_ => v)
                      }}
                    />
                  </div>
                  <button
                    className="w-full py-2.5 rounded-lg font-semibold text-primary-foreground transition-all disabled:opacity-50 disabled:cursor-not-allowed bg-primary hover:bg-primary/90"
                    disabled={adding || String.trim(manualJson) === ""}
                    onClick={_ => {
                      let _ = addManual()
                    }}>
                    {React.string(adding ? "Adding..." : "Add token")}
                  </button>
                </div>
                <p className="text-xs text-muted-foreground mt-2">
                  {React.string("Paste the Claude OAuth response JSON as-is")}
                </p>
              </div>
              <div className="border-t border-border pt-4">
                <p className="text-xs text-muted-foreground mb-3 text-center">
                  {React.string("Or sign in with OAuth locally:")}
                </p>
                <button
                  className="w-full py-3 rounded-lg font-semibold text-primary-foreground transition-all bg-primary/70 hover:bg-primary"
                  onClick={_ => {
                    let _ = startOauth()
                  }}>
                  {React.string("Claude OAuth login")}
                </button>
                <p className="text-xs text-muted-foreground mt-2 text-center">
                  {React.string("⚠️ OAuth only works on localhost")}
                </p>
              </div>
            </div>
          : React.null}
      </div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
          {React.string("Token Pool")}
        </h2>
        <button
          className={"px-3 py-1.5 text-sm border rounded-md transition-colors " ++ (
            refreshing
              ? "border-primary text-primary cursor-wait"
              : "border-input text-muted-foreground hover:border-primary hover:text-primary"
          )}
          title="Bypass cache and fetch live"
          disabled={refreshing}
          onClick={_ => {
            let _ = refreshTokens(true)
          }}>
          {React.string(refreshing ? "Loading..." : "🔄 Refresh")}
        </button>
      </div>
      {if loading {
        <div className="text-center py-8">
          <div
            className="w-8 h-8 border-2 border-input border-t-primary rounded-full animate-spin mx-auto mb-4"
          />
          <p className="text-muted-foreground"> {React.string("Loading token list...")} </p>
        </div>
      } else if Array.length(tokens) === 0 {
        <div className="text-center py-12 bg-card rounded-lg border border-border">
          <p className="text-muted-foreground"> {React.string("No tokens registered")} </p>
          <p className="text-sm text-muted-foreground mt-2">
            {React.string("Add an OAuth token above")}
          </p>
        </div>
      } else {
        <div className="space-y-4">
          {tokens
          ->Array.map(tok => {
            let status = getTokenStatus(tok)
            let isActive = status === "active"
            let borderCls = isActive ? "border-success/50" : "border-destructive/50"
            let label = switch tok.account {
            | Some(a) => a
            | None => tok.id
            }
            <div
              key={tok.id}
              className={"bg-card rounded-lg border p-4 transition-colors " ++ borderCls}>
              <div className="flex items-center justify-between mb-4">
                <span className="font-semibold"> {React.string(label)} </span>
                <div className="flex items-center gap-3">
                  <span
                    className={"px-2 py-0.5 rounded-full text-xs font-semibold uppercase " ++ (
                      isActive ? "bg-success/20 text-success" : "bg-destructive/20 text-destructive"
                    )}>
                    {React.string(isActive ? "Active" : "Expired")}
                  </span>
                  <button
                    className="p-1 text-muted-foreground hover:text-destructive transition-colors"
                    title="Delete token"
                    onClick={_ => {
                      let _ = deleteToken(tok.id)
                    }}>
                    {React.string("🗑")}
                  </button>
                </div>
              </div>
              <div className="border-t border-border pt-3 space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("ID")} </span>
                  <span className="font-mono text-muted-foreground"> {React.string(tok.id)} </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("Expires")} </span>
                  <span className="text-muted-foreground">
                    {React.string(formatTimeRemaining(tok.expiresAt))}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("Created")} </span>
                  <span className="text-muted-foreground">
                    {React.string(formatDate(tok.createdAt))}
                  </span>
                </div>
              </div>
            </div>
          })
          ->React.array}
        </div>
      }}
    </main>
    {notifEl}
  </div>
}
