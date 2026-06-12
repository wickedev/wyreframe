// /api/sessions* — session CRUD against D1 `sessions` + KV `SESSION_KV`.
// Each session row carries `viewport_state` and `ascii_content` (the
// wireframe source) and is referenced by `chat_messages.session_id` and
// `exports.session_id`.

open Types

// Hono's `c.req` exposes `param(name)` for URL params and `json()` for body
// parsing. The shared `Hono.req` binding returns the underlying Fetch
// `Request.t`, so we re-bind the two HonoRequest helpers we need here.
@send external reqParam: (Hono.context<'env>, string) => Nullable.t<string> = "param"
@send external reqJsonBody: (Hono.context<'env>, string) => promise<JSON.t> = "json"
@get external ctxReq: Hono.context<'env> => 'req = "req"

// `SESSION_KV.put` accepts an options object with `expirationTtl`.
type kvPutOptions = {expirationTtl: int}
@send external kvPut: ('kv, string, string, kvPutOptions) => promise<unit> = "put"
@send external kvGet: ('kv, string) => promise<Nullable.t<string>> = "get"
@send external kvDelete: ('kv, string) => promise<unit> = "delete"

// Hono context body() / Response constructor for the 204 no-content case.
type responseInit = {status: int}
@new external makeEmptyResponse: (Nullable.t<string>, responseInit) => Web.Response.t = "Response"

let getSessionKey = (sessionId: string): string => "session:" ++ sessionId

let handleCreateSession = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let bodyResult = try {
    await ctxReq(ctx)->reqJsonBody("")
  } catch {
  | _ => JSON.Encode.object(Dict.make())
  }
  let (userId, metadata) = switch Decode.object(bodyResult) {
  | Some(obj) =>
    let userId = switch Dict.get(obj, "userId") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let metadata = Dict.get(obj, "metadata")
    (userId, metadata)
  | None => (None, None)
  }
  let sessionId = SecurityUtils.generateToken(32)
  let session = Session.make(sessionId, userId, metadata)
  let sessionJson = JSON.stringify(JSON.Encode.object(Session.encode(session)))
  let key = getSessionKey(sessionId)
  await env.sessionKV->kvPut(key, sessionJson, {expirationTtl: 86400})
  ctx->Hono.jsonWithStatus(
    {
      "sessionId": sessionId,
      "userId": userId,
      "createdAt": session.createdAt->Date.toISOString,
      "expiresAt": session.expiresAt->Date.toISOString,
    },
    201,
  )
}

let handleGetSession = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let sessionIdN = ctxReq(ctx)->reqParam("id")
  switch sessionIdN->Nullable.toOption {
  | None => ctx->Hono.jsonWithStatus({"error": "Session ID is required"}, 400)
  | Some(sessionId) =>
    let key = getSessionKey(sessionId)
    let sessionJsonN = await env.sessionKV->kvGet(key)
    switch sessionJsonN->Nullable.toOption {
    | None =>
      ctx->Hono.jsonWithStatus(
        {"error": "NotFound", "message": "Session not found or expired"},
        404,
      )
    | Some(sessionJson) =>
      try {
        let json = JSON.parseExn(sessionJson)
        switch Session.decode(json) {
        | Error(msg) =>
          ctx->Hono.jsonWithStatus(
            {
              "error": "InternalError",
              "message": "Failed to decode session: " ++ msg,
            },
            500,
          )
        | Ok(session) =>
          let now = Date.now()
          let expiresAt = session.expiresAt->Date.getTime
          if now >= expiresAt {
            await env.sessionKV->kvDelete(key)
            ctx->Hono.jsonWithStatus(
              {"error": "NotFound", "message": "Session expired"},
              404,
            )
          } else {
            ctx->Hono.json({
              "sessionId": session.sessionId,
              "userId": session.userId,
              "createdAt": session.createdAt->Date.toISOString,
              "expiresAt": session.expiresAt->Date.toISOString,
            })
          }
        }
      } catch {
      | _ =>
        ctx->Hono.jsonWithStatus(
          {
            "error": "InternalError",
            "message": "Failed to parse session data",
          },
          500,
        )
      }
    }
  }
}

let handleDeleteSession = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let sessionIdN = ctxReq(ctx)->reqParam("id")
  switch sessionIdN->Nullable.toOption {
  | None => ctx->Hono.jsonWithStatus({"error": "Session ID is required"}, 400)
  | Some(sessionId) =>
    let key = getSessionKey(sessionId)
    await env.sessionKV->kvDelete(key)
    makeEmptyResponse(Nullable.null, {status: 204})
  }
}

let register = (app: Hono.t<env>): Hono.t<env> =>
  app
  ->Hono.post("/api/sessions", handleCreateSession)
  ->Hono.get("/api/sessions/:id", handleGetSession)
  ->Hono.delete("/api/sessions/:id", handleDeleteSession)
