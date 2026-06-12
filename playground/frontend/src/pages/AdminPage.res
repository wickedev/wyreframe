// Admin / Token Pool Manager page — lists active OAuth tokens, exposes manual
// JSON paste + OAuth login, shows usage/Rate Limit stats, allows deletion and
// refresh of cached profile metadata. Korean copy preserved verbatim.

type token = {
  id: string,
  account: option<string>,
  organization: option<string>,
  isActive: bool,
  expiresAt: float,
  createdAt: float,
}

type tokensSummary = {
  tokens: array<token>,
  total: int,
  active: int,
}

type usage = {
  total_requests?: int,
  remaining?: int,
  reset_at?: float,
}

type notifKind = Success | ErrorN | Info

type notif = {
  message: string,
  kind: notifKind,
}

type statusResponse = {status: string}

type addManualResponse = {
  success: bool,
  error?: string,
}

type oauthStartResponse = {
  authUrl?: string,
  error?: string,
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
    "만료됨"
  } else {
    let hours = Js.Math.floor(diff /. (1000.0 *. 60.0 *. 60.0))
    let minutes = Js.Math.floor(mod_float(diff, 1000.0 *. 60.0 *. 60.0) /. (1000.0 *. 60.0))
    if hours > 0 {
      Int.toString(hours) ++ "시간 " ++ Int.toString(minutes) ++ "분"
    } else {
      Int.toString(minutes) ++ "분"
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

let getInit: {..} = {"method": "GET"}

external asStatus: JSON.t => statusResponse = "%identity"
external asTokens: JSON.t => tokensSummary = "%identity"
external asUsage: JSON.t => usage = "%identity"
external asAddResult: JSON.t => addManualResponse = "%identity"
external asOauthStart: JSON.t => oauthStartResponse = "%identity"
external asManualPayload: JSON.t =>
  {"access_token": Js.undefined<string>, "expires_in": Js.undefined<float>} = "%identity"

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
  let (tokens, setTokens) = React.useState(() => [])
  let (_usageMap, setUsageMap) = React.useState(() => Dict.make())
  let (counts, setCounts) = React.useState(() => {tokens: [], total: 0, active: 0})
  let (serverOk, setServerOk) = React.useState(() => false)
  let (loading, setLoading) = React.useState(() => true)
  let (refreshing, setRefreshing) = React.useState(() => false)
  let (totalRequests, _setTotalRequests) = React.useState(() => 0)
  let (addOpen, setAddOpen) = React.useState(() => false)
  let (manualJson, setManualJson) = React.useState(() => "")
  let (adding, setAdding) = React.useState(() => false)
  let (notif, setNotif) = React.useState((): option<notif> => None)

  let showNotif = React.useCallback1((message, kind) => {
    setNotif(_ => Some({message, kind}))
    let _ = Js.Global.setTimeout(() => setNotif(_ => None), 3000)
  }, [setNotif])

  let checkStatus = React.useCallback0(async () => {
    try {
      let res = await Fetch.fetch(ApiBase.url("/api/status"), getInit)
      let json = await Fetch.json(res)
      let parsed = asStatus(json)
      setServerOk(_ => parsed.status === "ok")
    } catch {
    | _ => setServerOk(_ => false)
    }
  })

  let refreshTokens = React.useCallback1(async (force: bool) => {
    if force {
      setRefreshing(_ => true)
    }
    try {
      let res = await Fetch.fetch(ApiBase.url("/api/tokens"), getInit)
      let json = await Fetch.json(res)
      let parsed = asTokens(json)
      setTokens(_ => parsed.tokens)
      setCounts(_ => {tokens: parsed.tokens, total: parsed.total, active: parsed.active})
      let nextUsage = Dict.make()
      let _ = await Promise.all(
        parsed.tokens->Array.map(async tok => {
          try {
            let url = force
              ? ApiBase.url("/api/usage/" ++ tok.id ++ "?refresh=true")
              : ApiBase.url("/api/usage/" ++ tok.id)
            let uRes = await Fetch.fetch(url, getInit)
            let uJson = await Fetch.json(uRes)
            nextUsage->Dict.set(tok.id, asUsage(uJson))
          } catch {
          | _ => ()
          }
        }),
      )
      setUsageMap(_ => nextUsage)
      if force {
        showNotif("사용량 정보가 갱신되었습니다", Success)
      }
    } catch {
    | e =>
      Console.error2("Failed to refresh tokens:", e)
      if force {
        showNotif("갱신 실패", ErrorN)
      }
    }
    setLoading(_ => false)
    setRefreshing(_ => false)
  }, [showNotif])

  let deleteToken = React.useCallback2(async (id: string) => {
    if windowConfirm("이 토큰을 삭제하시겠습니까?") {
      try {
        let init = {"method": "DELETE"}->Obj.magic
        let res = await Fetch.fetch(ApiBase.url("/api/tokens/" ++ id), init)
        let json = await Fetch.json(res)
        let parsed = asAddResult(json)
        if parsed.success {
          showNotif("토큰이 삭제되었습니다", Success)
          await refreshTokens(false)
        } else {
          let msg = switch parsed.error {
          | Some(e) => e
          | None => "토큰 삭제 실패"
          }
          showNotif(msg, ErrorN)
        }
      } catch {
      | _ => showNotif("서버 연결 오류", ErrorN)
      }
    }
  }, (showNotif, refreshTokens))

  let refreshProfile = React.useCallback1(async (tokenId: string) => {
    try {
      let init = {"method": "POST"}->Obj.magic
      let _ = await Fetch.fetch(ApiBase.url("/api/tokens/" ++ tokenId ++ "/refresh-profile"), init)
      showNotif("프로필이 갱신되었습니다", Success)
      await refreshTokens(false)
    } catch {
    | _ => showNotif("프로필 갱신 실패", ErrorN)
    }
  }, [showNotif])

  let addManual = React.useCallback2(async () => {
    let trimmed = String.trim(manualJson)
    if trimmed === "" {
      showNotif("JSON을 입력해주세요", ErrorN)
    } else {
      let parsedOpt = try Some(JSON.parseExn(trimmed)) catch {
      | _ => None
      }
      switch parsedOpt {
      | None => showNotif("JSON 형식이 올바르지 않습니다", ErrorN)
      | Some(parsed) =>
        let obj = asManualPayload(parsed)
        if Js.Undefined.toOption(obj["access_token"]) === None {
          showNotif("access_token 필드가 필요합니다", ErrorN)
        } else if Js.Undefined.toOption(obj["expires_in"]) === None {
          showNotif("expires_in 필드가 필요합니다", ErrorN)
        } else {
          setAdding(_ => true)
          try {
            let init =
              {
                "method": "POST",
                "headers": {"Content-Type": "application/json"},
                "body": trimmed,
              }->Obj.magic
            let res = await Fetch.fetch(ApiBase.url("/api/tokens/manual"), init)
            let json = await Fetch.json(res)
            let result = asAddResult(json)
            if result.success {
              showNotif("토큰이 추가되었습니다", Success)
              setManualJson(_ => "")
              await refreshTokens(false)
            } else {
              let msg = switch result.error {
              | Some(e) => e
              | None => "토큰 추가 실패"
              }
              showNotif(msg, ErrorN)
            }
          } catch {
          | e =>
            Console.error2("Add manual token error:", e)
            showNotif("서버 연결 오류", ErrorN)
          }
          setAdding(_ => false)
        }
      }
    }
  }, (manualJson, refreshTokens))

  let startOauth = React.useCallback1(async () => {
    try {
      showNotif("OAuth 인증을 시작합니다...", Info)
      let res = await Fetch.fetch(ApiBase.url("/api/auth/start"), getInit)
      if Fetch.ok(res) {
        let ct = Fetch.headers(res)["get"]("content-type")
        if ct === Js.null || ct === Js.undefined || !String.includes(ct, "application/json") {
          showNotif("서버 응답 오류: 서버를 재시작해주세요", ErrorN)
        } else {
          let json = await Fetch.json(res)
          let parsed = asOauthStart(json)
          switch parsed.authUrl {
          | None =>
            switch parsed.error {
            | Some(err) => showNotif("OAuth 오류: " ++ err, ErrorN)
            | None => showNotif("OAuth URL 생성 실패", ErrorN)
            }
          | Some(authUrl) =>
            let popup = windowOpen(authUrl, "_blank", "width=600,height=700")
            if Nullable.toOption(popup) === None {
              showNotif("팝업이 차단되었습니다. 팝업 차단을 해제해주세요.", ErrorN)
            } else {
              showNotif("브라우저에서 로그인을 완료해주세요", Info)
            }
          }
        }
      } else {
        let s = Int.toString(Fetch.status(res))
        showNotif("서버 오류 (" ++ s ++ "): 서버를 재시작해주세요", ErrorN)
      }
    } catch {
    | e =>
      Console.error2("OAuth error:", e)
      showNotif("OAuth 시작 실패", ErrorN)
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
        showNotif("토큰이 추가되었습니다: " ++ account, Success)
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
  | Some({message, kind}) =>
    let borderCls = switch kind {
    | Success => "bg-card border-success"
    | ErrorN => "bg-card border-destructive"
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
            {React.string("실시간 토큰 상태 및 Rate Limit 모니터링")}
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
              {React.string(serverOk ? "서버 연결됨" : "서버 연결 실패")}
            </span>
          </div>
          <a
            className="text-sm text-muted-foreground hover:text-foreground transition-colors"
            href="/">
            {React.string("← Playground로 돌아가기")}
          </a>
        </div>
      </div>
    </header>
    <main className="p-6">
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("총 토큰")} </div>
          <div className="text-2xl font-bold"> {React.string(Int.toString(counts.total))} </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("활성 토큰")} </div>
          <div className="text-2xl font-bold text-success">
            {React.string(Int.toString(counts.active))}
          </div>
        </div>
        <div className="bg-card rounded-lg border border-border p-4 text-center">
          <div className="text-sm text-muted-foreground mb-1"> {React.string("총 요청")} </div>
          <div className="text-2xl font-bold">
            {React.string(Int.toString(totalRequests))}
          </div>
        </div>
      </div>
      <div className="bg-card rounded-lg border border-border p-4 mb-6">
        <button
          className="w-full flex items-center gap-2 text-left font-semibold"
          onClick={_ => setAddOpen(o => !o)}>
          <span className={"transition-transform " ++ (addOpen ? "rotate-90" : "")}>
            {React.string("▶")}
          </span>
          {React.string("토큰 추가")}
        </button>
        {addOpen
          ? <div className="mt-4 space-y-4">
              <div className="bg-muted rounded-lg p-4">
                <h3 className="text-sm font-semibold text-secondary-foreground mb-3">
                  {React.string("수동 토큰 입력")}
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
                  <Button
                    className="w-full py-2.5 rounded-lg font-semibold text-primary-foreground transition-all disabled:opacity-50 disabled:cursor-not-allowed bg-primary hover:bg-primary/90"
                    disabled={adding || String.trim(manualJson) === ""}
                    onClick={_ => {
                      let _ = addManual()
                    }}>
                    {React.string(adding ? "추가 중..." : "토큰 추가")}
                  </Button>
                </div>
                <p className="text-xs text-muted-foreground mt-2">
                  {React.string("Claude OAuth 응답 JSON을 그대로 붙여넣으세요")}
                </p>
              </div>
              <div className="border-t border-border pt-4">
                <p className="text-xs text-muted-foreground mb-3 text-center">
                  {React.string("또는 로컬 환경에서 OAuth 로그인:")}
                </p>
                <Button
                  className="w-full py-3 rounded-lg font-semibold text-primary-foreground transition-all bg-primary/70 hover:bg-primary"
                  onClick={_ => {
                    let _ = startOauth()
                  }}>
                  <Lucide.ExternalLink size={16} />
                  {React.string("Claude OAuth 로그인")}
                </Button>
                <p className="text-xs text-muted-foreground mt-2 text-center">
                  {React.string("⚠️ OAuth는 localhost에서만 작동합니다")}
                </p>
              </div>
            </div>
          : React.null}
      </div>
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-muted-foreground uppercase tracking-wide">
          {React.string("Token Pool")}
        </h2>
        <Button
          variant=#outline
          size=#sm
          className={"px-3 py-1.5 text-sm border rounded-md transition-colors " ++ (
            refreshing
              ? "border-primary text-primary cursor-wait"
              : "border-input text-muted-foreground hover:border-primary hover:text-primary"
          )}
          disabled={refreshing}
          onClick={_ => {
            let _ = refreshTokens(true)
          }}>
          <Lucide.RotateCcw size={14} />
          {React.string(refreshing ? "조회 중..." : "새로고침")}
        </Button>
      </div>
      {if loading {
        <div className="text-center py-8">
          <div className="space-y-3 max-w-md mx-auto">
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-20 w-full" />
          </div>
          <p className="text-muted-foreground mt-4">
            {React.string("토큰 목록을 불러오는 중...")}
          </p>
        </div>
      } else if Array.length(tokens) === 0 {
        <div className="text-center py-12 bg-card rounded-lg border border-border">
          <p className="text-muted-foreground"> {React.string("등록된 토큰이 없습니다")} </p>
          <p className="text-sm text-muted-foreground mt-2">
            {React.string("위에서 OAuth 토큰을 추가해주세요")}
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
                  <Badge variant={isActive ? #default : #destructive}>
                    {React.string(isActive ? "활성" : "만료됨")}
                  </Badge>
                  <button
                    className="p-1 text-muted-foreground hover:text-primary transition-colors"
                    title="프로필 갱신"
                    onClick={_ => {
                      let _ = refreshProfile(tok.id)
                    }}>
                    <Lucide.RotateCcw size={16} />
                  </button>
                  <button
                    className="p-1 text-muted-foreground hover:text-destructive transition-colors"
                    title="토큰 삭제"
                    onClick={_ => {
                      let _ = deleteToken(tok.id)
                    }}>
                    <Lucide.Trash2 size={16} />
                  </button>
                </div>
              </div>
              <div className="border-t border-border pt-3 space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("ID")} </span>
                  <span className="font-mono text-muted-foreground">
                    {React.string(tok.id)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("만료")} </span>
                  <span className="text-muted-foreground">
                    {React.string(formatTimeRemaining(tok.expiresAt))}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground"> {React.string("생성")} </span>
                  <span className="text-muted-foreground">
                    {React.string(formatDate(tok.createdAt))}
                  </span>
                </div>
                {switch tok.organization {
                | Some(org) =>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground"> {React.string("조직")} </span>
                    <span className="text-muted-foreground"> {React.string(org)} </span>
                  </div>
                | None => React.null
                }}
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
