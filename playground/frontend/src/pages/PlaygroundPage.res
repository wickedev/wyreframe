// Route entry for /play. Boots a backend session and gates entry on having
// at least one active token before rendering the Playground.

type loadState =
  | Loading
  | Ready
  | NoToken
  | Failed(string)

@react.component
let make = () => {
  let navigate = Router.useNavigate()
  let (state, setState) = React.useState(() => Loading)
  let (session, setSession) = React.useState(() => SessionContext.loadStoredSession())
  let (hasToken, setHasToken) = React.useState(() => false)
  let didInit = React.useRef(false)

  let refreshTokens = React.useCallback0(async () => {
    switch await Client.getStatus() {
    | Ok(s) => setHasToken(_ => s.tokenCount > 0)
    | Error(_) => setHasToken(_ => false)
    }
  })

  React.useEffect0(() => {
    if didInit.current {
      ()
    } else {
      didInit.current = true
      let _ = (
        async () => {
          let statusResult = await Client.getStatus()
          switch statusResult {
          | Ok(s) if s.tokenCount > 0 => {
              setHasToken(_ => true)
              let existing = SessionContext.loadStoredSession()
              switch existing {
              | Some(s) => {
                  setSession(_ => Some(s))
                  setState(_ => Ready)
                }
              | None =>
                switch await Client.createSession(()) {
                | Ok(created) => {
                    let next: SessionContext.session = {sessionId: created.sessionId}
                    SessionContext.saveStoredSession(Some(next))
                    setSession(_ => Some(next))
                    setState(_ => Ready)
                  }
                | Error(msg) => setState(_ => Failed(msg))
                }
              }
            }
          | Ok(_) => {
              setHasToken(_ => false)
              setState(_ => NoToken)
              navigate("/")
            }
          | Error(msg) => setState(_ => Failed(msg))
          }
        }
      )()
    }
    None
  })

  let ctx: SessionContext.contextValue = {
    session,
    setSession: next => {
      SessionContext.saveStoredSession(next)
      setSession(_ => next)
    },
    hasToken,
    refreshTokens,
  }

  switch state {
  | Loading =>
    <div className="h-screen flex items-center justify-center">
      <div className="text-center space-y-4 w-64">
        <Skeleton className="h-8 w-48 mx-auto" />
        <Skeleton className="h-4 w-64" />
        <Skeleton className="h-4 w-56" />
        <p className="text-muted-foreground text-sm"> {React.string("Loading playground...")} </p>
      </div>
    </div>
  | NoToken => React.null
  | Failed(msg) =>
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
  | Ready =>
    <SessionContext.Provider value={ctx}>
      <Playground />
    </SessionContext.Provider>
  }
}
