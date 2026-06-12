// Session + token state shared across the app.

type session = {sessionId: string}

type contextValue = {
  session: option<session>,
  setSession: option<session> => unit,
  hasToken: bool,
  refreshTokens: unit => promise<unit>,
}

let defaultValue: contextValue = {
  session: None,
  setSession: _ => (),
  hasToken: false,
  refreshTokens: () => Promise.resolve(),
}

let context = React.createContext(defaultValue)

module Provider = {
  let make = React.Context.provider(context)
}

let use = () => React.useContext(context)

let storageKeyPrefix = "wyreframe_session_"
let themeKey = "wyreframe-theme-preference"

let loadStoredSession = (): option<session> => {
  switch Global.lsGet(storageKeyPrefix ++ "current")->Nullable.toOption {
  | Some(id) => Some({sessionId: id})
  | None => None
  }
}

let saveStoredSession = (s: option<session>): unit => {
  switch s {
  | Some({sessionId}) => Global.lsSet(storageKeyPrefix ++ "current", sessionId)
  | None => Global.lsRemove(storageKeyPrefix ++ "current")
  }
}
