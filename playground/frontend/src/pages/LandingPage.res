// Public landing page at `/`. Pitches the product and gates entry behind
// either Anthropic OAuth login or a manually pasted access token.

let navigateOnLogin = "/play"

@react.component
let make = () => {
  let navigate = Router.useNavigate()

  let (accessToken, setAccessToken) = React.useState(() => "")
  let (loading, setLoading) = React.useState(() => false)
  let (error, setError) = React.useState(() => "")
  let (info, setInfo) = React.useState(() => "")
  let (activeTokens, setActiveTokens) = React.useState(() => 0)

  // Poll status to know if any token is already active. If so, jump
  // straight into the playground.
  let pollStatus = React.useCallback1(async () => {
    switch await Client.getStatus() {
    | Ok(status) =>
      setActiveTokens(_ => status.activeTokens)
      if status.activeTokens > 0 {
        navigate(navigateOnLogin)
      }
    | Error(_) => ()
    }
  }, [navigate])

  React.useEffect0(() => {
    let _ = pollStatus()
    let id = Js.Global.setInterval(() => {
      let _ = pollStatus()
    }, 5000)
    Some(() => Js.Global.clearInterval(id))
  })

  // Listen for OAuth popup completion broadcast over `postMessage`.
  React.useEffect1(() => {
    let handler = (event: {"data": Nullable.t<{"type": Nullable.t<string>}>}) => {
      switch event["data"]->Nullable.toOption {
      | Some(data) =>
        switch data["type"]->Nullable.toOption {
        | Some("oauth-success") =>
          setInfo(_ => "로그인이 완료되었습니다")
          let _ = pollStatus()
        | _ => ()
        }
      | None => ()
      }
    }
    let addListener: (string, 'a => unit) => unit = %raw(`(t, h) => window.addEventListener(t, h)`)
    let removeListener: (string, 'a => unit) => unit = %raw(`(t, h) => window.removeEventListener(t, h)`)
    addListener("message", handler)
    Some(() => removeListener("message", handler))
  }, [pollStatus])

  let startOAuth = async () => {
    setError(_ => "")
    setInfo(_ => "")
    setLoading(_ => true)
    let redirectUri = Global.location["origin"] ++ "/oauth/callback"
    let openPopup: string => unit = %raw(`(u) => window.open(u, "_blank", "width=600,height=700")`)
    switch await Client.oauthStart(~redirectUri) {
    | Ok(url) =>
      openPopup(url)
      setInfo(_ => "브라우저에서 로그인을 완료해주세요")
    | Error(msg) => setError(_ => msg)
    }
    setLoading(_ => false)
  }

  let submitManualToken = async () => {
    let trimmed = accessToken->String.trim
    if trimmed === "" {
      setError(_ => "위에서 OAuth 토큰을 추가해주세요")
    } else {
      setError(_ => "")
      setLoading(_ => true)
      switch await Client.addManualToken(~accessToken=trimmed, ()) {
      | Ok() =>
        setInfo(_ => "토큰이 추가되었습니다")
        setAccessToken(_ => "")
        let _ = pollStatus()
        navigate(navigateOnLogin)
      | Error(msg) => setError(_ => msg)
      }
      setLoading(_ => false)
    }
  }

  let onTokenKeyDown = (e: ReactEvent.Keyboard.t) => {
    let key: string = ReactEvent.Keyboard.key(e)
    let shift: bool = ReactEvent.Keyboard.shiftKey(e)
    if key === "Enter" && !shift {
      ReactEvent.Keyboard.preventDefault(e)
      let _ = submitManualToken()
    }
  }

  <div
    className="min-h-screen flex flex-col bg-background text-foreground relative overflow-hidden">
    // Decorative background blobs
    <div className="absolute inset-0 overflow-hidden pointer-events-none">
      <div
        className="absolute -top-40 -left-40 w-80 h-80 bg-[hsl(265_90%_50%/0.15)] rounded-full blur-[100px] animate-pulse"
      />
      <div
        className="absolute top-1/4 -right-20 w-96 h-96 bg-[hsl(200_90%_50%/0.12)] rounded-full blur-[120px] animate-pulse"
      />
      <div
        className="absolute -bottom-20 left-1/4 w-72 h-72 bg-[hsl(320_90%_50%/0.10)] rounded-full blur-[100px] animate-pulse"
      />
    </div>
    // Top nav
    <nav
      className="h-16 border-b border-[hsl(220_20%_95%/0.08)] flex items-center justify-between px-6 flex-shrink-0 relative z-10">
      <Logo />
      <a
        className="p-2 text-muted-foreground hover:text-foreground transition-colors rounded-lg"
        title="GitHub"
        href="https://github.com/wickedev/wyreframe"
        rel="noopener noreferrer"
        target="_blank">
        <Lucide.Github size={20} />
      </a>
    </nav>
    // Hero + login card
    <main
      className="flex-1 flex flex-col items-center justify-center px-4 py-12 relative z-10">
      <div className="text-center mb-10 max-w-3xl">
        <h1 className="text-4xl md:text-6xl font-bold tracking-tight mb-5">
          <span className="text-gradient-primary"> {React.string("Wyreframe")} </span>
          <br />
          <span className="text-foreground"> {React.string("ASCII Wireframes, Instantly")} </span>
        </h1>
        <p
          className="text-lg md:text-xl text-muted-foreground max-w-xl mx-auto leading-relaxed">
          {React.string(
            "Sketch UI in plain text and watch it render across devices in real-time.",
          )}
        </p>
      </div>
      // Login card
      <div
        className="w-full max-w-md bg-card border border-border rounded-2xl p-6 shadow-lg backdrop-blur-sm">
        <div className="flex items-center gap-2 mb-4">
          <Lucide.Lock size={18} />
          <h2 className="text-lg font-semibold"> {React.string("Sign in to continue")} </h2>
        </div>
        // Manual token entry
        <div className="space-y-3">
          <Label htmlFor="access-token">
            {React.string("Anthropic Access Token")}
          </Label>
          <Input
            id="access-token"
            type_="password"
            placeholder="sk-ant-oat01-..."
            value={accessToken}
            disabled={loading}
            onChange={e => {
              let v = (e->ReactEvent.Form.target)["value"]
              setAccessToken(_ => v)
            }}
            onKeyDown={onTokenKeyDown}
          />
          <Button
            variant=#default
            className="w-full"
            disabled={loading || accessToken->String.trim === ""}
            onClick={_ => {
              let _ = submitManualToken()
            }}>
            {React.string(loading ? "Adding..." : "Add Token")}
          </Button>
        </div>
        // OAuth divider + button
        <div className="border-t border-border mt-6 pt-4">
          <p className="text-xs text-muted-foreground mb-3 text-center">
            {React.string("또는 로컬 환경에서 OAuth 로그인:")}
          </p>
          <Button
            variant=#outline
            className="w-full"
            disabled={loading}
            onClick={_ => {
              let _ = startOAuth()
            }}>
            <Lucide.ExternalLink size={16} />
            {React.string("Claude OAuth 로그인")}
          </Button>
          <p className="text-xs text-muted-foreground mt-2 text-center">
            {React.string("⚠️ OAuth는 localhost에서만 작동합니다")}
          </p>
        </div>
        // Status messages
        {error !== ""
          ? <p
              className="text-xs text-destructive mt-4 text-center">
              {React.string(error)}
            </p>
          : React.null}
        {info !== ""
          ? <p
              className="text-xs text-muted-foreground mt-4 text-center">
              {React.string(info)}
            </p>
          : React.null}
        {activeTokens === 0 && error === "" && info === ""
          ? <p
              className="text-xs text-muted-foreground mt-4 text-center">
              {React.string("위에서 OAuth 토큰을 추가해주세요")}
            </p>
          : React.null}
      </div>
    </main>
    // Footer
    <footer
      className="py-6 px-4 text-center relative z-10 border-t border-[hsl(220_20%_95%/0.05)]">
      <p className="text-sm text-muted-foreground/50">
        {React.string("Powered by ")}
        <a
          className="text-[hsl(200_90%_60%)] hover:text-[hsl(200_90%_70%)] transition-colors"
          href="https://www.npmjs.com/package/wyreframe"
          rel="noopener noreferrer"
          target="_blank">
          {React.string("wyreframe")}
        </a>
        {React.string(" · Fast ASCII Parsing · Multi-Device Preview")}
      </p>
    </footer>
  </div>
}
