// Typed API client for the wyreframe-backend worker.

type status = {
  status: string,
  tokenCount: int,
  activeTokens: int,
  timestamp: float,
}

type token = {
  id: string,
  account: option<string>,
  organization: option<string>,
  createdAt: float,
  lastUsed: option<float>,
}

type tokensResponse = {tokens: array<token>}

type session = {
  sessionId: string,
  userId: option<string>,
  createdAt: string,
  expiresAt: string,
}

let getStatus = async (): result<status, string> => {
  try {
    let res = await Fetch.fetch(ApiBase.url("/api/status"), Obj.magic(Dict.make()))
    let json = await Fetch.json(res)
    let parsed = json->Obj.magic
    Ok(parsed)
  } catch {
  | _ => Error("Failed to fetch status")
  }
}

let getTokens = async (): result<tokensResponse, string> => {
  try {
    let res = await Fetch.fetch(ApiBase.url("/api/tokens"), Obj.magic(Dict.make()))
    let json = await Fetch.json(res)
    Ok(json->Obj.magic)
  } catch {
  | _ => Error("Failed to fetch tokens")
  }
}

let createSession = async (~userId: option<string>=?, ~metadata: option<JSON.t>=?, ()): result<
  session,
  string,
> => {
  try {
    let body = Dict.make()
    switch userId {
    | Some(id) => body->Dict.set("userId", JSON.Encode.string(id))
    | None => ()
    }
    switch metadata {
    | Some(m) => body->Dict.set("metadata", m)
    | None => ()
    }
    let init = {
      "method": "POST",
      "headers": {"Content-Type": "application/json"},
      "body": JSON.stringify(JSON.Encode.object(body)),
    }
    let res = await Fetch.fetch(ApiBase.url("/api/sessions"), init->Obj.magic)
    let json = await Fetch.json(res)
    Ok(json->Obj.magic)
  } catch {
  | _ => Error("Failed to create session")
  }
}

let oauthStart = async (~redirectUri: string): result<string, string> => {
  try {
    let url = ApiBase.url("/api/auth/start?redirect_uri=" ++ Global.encodeURIComponent(redirectUri))
    let res = await Fetch.fetch(url, Obj.magic(Dict.make()))
    let json = await Fetch.json(res)
    let url = json->Obj.magic
    Ok(url["authorizationUrl"])
  } catch {
  | _ => Error("Failed to start OAuth")
  }
}

let addManualToken = async (~accessToken: string, ~refreshToken: option<string>=?, ()): result<
  unit,
  string,
> => {
  try {
    let body = Dict.make()
    body->Dict.set("accessToken", JSON.Encode.string(accessToken))
    switch refreshToken {
    | Some(rt) => body->Dict.set("refreshToken", JSON.Encode.string(rt))
    | None => ()
    }
    let init = {
      "method": "POST",
      "headers": {"Content-Type": "application/json"},
      "body": JSON.stringify(JSON.Encode.object(body)),
    }
    let _ = await Fetch.fetch(ApiBase.url("/api/tokens/manual"), init->Obj.magic)
    Ok()
  } catch {
  | _ => Error("Failed to add token")
  }
}

let deleteToken = async (id: string): result<unit, string> => {
  try {
    let init = {"method": "DELETE"}->Obj.magic
    let _ = await Fetch.fetch(ApiBase.url("/api/tokens/" ++ id), init)
    Ok()
  } catch {
  | _ => Error("Failed to delete token")
  }
}
