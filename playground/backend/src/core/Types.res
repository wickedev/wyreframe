// Shared core types for the wyreframe-backend worker: Cloudflare env bindings,
// domain error variants, Session / ChatMessage / Metrics records and their
// encoders/decoders, and DB row adapters used by the D1 layer.

// ----- Cloudflare binding types --------------------------------------------

type d1PreparedStatement
type d1Result<'a> = {
  success: bool,
  results: array<'a>,
}

type d1Database = {
  prepare: string => d1PreparedStatement,
}

type kvPutOptions = {expirationTtl?: int}
type kvNamespace = {
  get: string => promise<Nullable.t<string>>,
  put: (string, string, kvPutOptions) => promise<unit>,
  delete: string => promise<unit>,
}

type r2Bucket

// Cloudflare worker env. Bindings from wrangler.jsonc (DB, SESSION_KV, ASSETS),
// vars (ANTHROPIC_BASE_URL, LANGFUSE_BASE_URL, ENVIRONMENT), and secrets the
// bundle reads via `env.X` (ANTHROPIC_API_KEY, LANGFUSE_PUBLIC_KEY,
// LANGFUSE_SECRET_KEY, GITHUB_TOKEN).
type env = {
  // D1
  @as("DB") db: d1Database,
  // KV
  @as("SESSION_KV") sessionKV: kvNamespace,
  // R2
  @as("ASSETS") assets: r2Bucket,
  // vars
  @as("ANTHROPIC_BASE_URL") anthropicBaseURL: option<string>,
  @as("LANGFUSE_BASE_URL") langfuseBaseURL: option<string>,
  @as("ENVIRONMENT") environment: option<string>,
  // secrets
  @as("ANTHROPIC_API_KEY") anthropicAPIKey: option<string>,
  @as("LANGFUSE_PUBLIC_KEY") langfusePublicKey: option<string>,
  @as("LANGFUSE_SECRET_KEY") langfuseSecretKey: option<string>,
  @as("GITHUB_TOKEN") githubToken: option<string>,
}

// ----- Domain error variants -----------------------------------------------

type error =
  | ValidationError({field: string, message: string})
  | AuthenticationError(string)
  | AuthorizationError(string)
  | NotFoundError(string)
  | RateLimitError({retryAfter: option<int>})
  | DatabaseError({message: string, query: option<string>})
  | ExternalAPIError({service: string, message: string, statusCode: option<int>})
  | InternalError(string)

// ----- Session -------------------------------------------------------------

type session = {
  sessionId: string,
  userId: option<string>,
  createdAt: Date.t,
  expiresAt: Date.t,
  metadata: option<JSON.t>,
}

module Session = {
  let encode = (session: session): Dict.t<JSON.t> => {
    let obj = Dict.make()
    obj->Dict.set("sessionId", JSON.Encode.string(session.sessionId))
    switch session.userId {
    | Some(id) => obj->Dict.set("userId", JSON.Encode.string(id))
    | None => obj->Dict.set("userId", JSON.Encode.null)
    }
    obj->Dict.set("createdAt", JSON.Encode.string(session.createdAt->Date.toISOString))
    obj->Dict.set("expiresAt", JSON.Encode.string(session.expiresAt->Date.toISOString))
    switch session.metadata {
    | Some(meta) => obj->Dict.set("metadata", meta)
    | None => obj->Dict.set("metadata", JSON.Encode.null)
    }
    obj
  }

  let decode = (json: JSON.t): result<session, string> => {
    switch Decode.object(json) {
    | None => Error("Expected object for Session")
    | Some(obj) =>
      let sessionId = switch obj->Dict.get("sessionId") {
      | Some(v) => Decode.string(v)
      | None => None
      }
      let userId = switch obj->Dict.get("userId") {
      | Some(v) => Decode.string(v)
      | None => None
      }
      let createdAt = switch obj->Dict.get("createdAt") {
      | Some(v) =>
        switch Decode.string(v) {
        | Some(s) => Some(Date.fromString(s))
        | None => None
        }
      | None => None
      }
      let expiresAt = switch obj->Dict.get("expiresAt") {
      | Some(v) =>
        switch Decode.string(v) {
        | Some(s) => Some(Date.fromString(s))
        | None => None
        }
      | None => None
      }
      let metadata = switch obj->Dict.get("metadata") {
      | Some(v) =>
        Decode.null_(v) ? None : Some(v)
      | None => None
      }
      switch sessionId {
      | None => Error("Missing required field: sessionId")
      | Some(sessionId) =>
        switch createdAt {
        | None => Error("Missing or invalid field: createdAt")
        | Some(createdAt) =>
          switch expiresAt {
          | None => Error("Missing or invalid field: expiresAt")
          | Some(expiresAt) => Ok({sessionId, userId, createdAt, expiresAt, metadata})
          }
        }
      }
    }
  }

  let make = (sessionId, userId, metadata): session => {
    let now = Date.make()
    let expiresMs = now->Date.getTime +. 86400000.0
    {
      sessionId,
      userId,
      createdAt: now,
      expiresAt: Date.fromTime(expiresMs),
      metadata,
    }
  }
}

// ----- ChatMessage ---------------------------------------------------------

type role = [#user | #assistant | #system]

type chatMessage = {
  id: string,
  sessionId: string,
  role: role,
  content: string,
  timestamp: Date.t,
  metadata: option<JSON.t>,
}

module ChatMessage = {
  let roleToString = (r: role): string =>
    switch r {
    | #user => "user"
    | #system => "system"
    | #assistant => "assistant"
    }

  let roleFromString = (s: string): option<role> =>
    switch s {
    | "assistant" => Some(#assistant)
    | "system" => Some(#system)
    | "user" => Some(#user)
    | _ => None
    }

  let encode = (msg: chatMessage): Dict.t<JSON.t> => {
    let obj = Dict.make()
    obj->Dict.set("id", JSON.Encode.string(msg.id))
    obj->Dict.set("sessionId", JSON.Encode.string(msg.sessionId))
    obj->Dict.set("role", JSON.Encode.string(roleToString(msg.role)))
    obj->Dict.set("content", JSON.Encode.string(msg.content))
    obj->Dict.set("timestamp", JSON.Encode.string(msg.timestamp->Date.toISOString))
    switch msg.metadata {
    | Some(meta) => obj->Dict.set("metadata", meta)
    | None => obj->Dict.set("metadata", JSON.Encode.null)
    }
    obj
  }

  let decode = (json: JSON.t): result<chatMessage, string> => {
    switch Decode.object(json) {
    | None => Error("Expected object for ChatMessage")
    | Some(obj) =>
      let id = switch obj->Dict.get("id") {
      | Some(v) => Decode.string(v)
      | None => None
      }
      let sessionId = switch obj->Dict.get("sessionId") {
      | Some(v) => Decode.string(v)
      | None => None
      }
      let role = switch obj->Dict.get("role") {
      | Some(v) =>
        switch Decode.string(v) {
        | Some(s) => roleFromString(s)
        | None => None
        }
      | None => None
      }
      let content = switch obj->Dict.get("content") {
      | Some(v) => Decode.string(v)
      | None => None
      }
      let timestamp = switch obj->Dict.get("timestamp") {
      | Some(v) =>
        switch Decode.string(v) {
        | Some(s) => Some(Date.fromString(s))
        | None => None
        }
      | None => None
      }
      let metadata = switch obj->Dict.get("metadata") {
      | Some(v) =>
        Decode.null_(v) ? None : Some(v)
      | None => None
      }
      switch id {
      | None => Error("Missing required field: id")
      | Some(id) =>
        switch sessionId {
        | None => Error("Missing required field: sessionId")
        | Some(sessionId) =>
          switch role {
          | None => Error("Missing or invalid field: role")
          | Some(role) =>
            switch content {
            | None => Error("Missing required field: content")
            | Some(content) =>
              switch timestamp {
              | None => Error("Missing or invalid field: timestamp")
              | Some(timestamp) =>
                Ok({id, sessionId, role, content, timestamp, metadata})
              }
            }
          }
        }
      }
    }
  }

  let make = (id, sessionId, role, content, metadata): chatMessage => {
    id,
    sessionId,
    role,
    content,
    timestamp: Date.make(),
    metadata,
  }
}

// ----- DB row adapters -----------------------------------------------------

module DB = {
  module Sessions = {
    type row = {
      session_id: string,
      user_id: Nullable.t<string>,
      created_at: string,
      expires_at: string,
      metadata: Nullable.t<string>,
    }

    let toSession = (row: row): session => {
      let metadata = switch row.metadata->Nullable.toOption {
      | None => None
      | Some(metaStr) =>
        try {
          Some(JSON.parseExn(metaStr))
        } catch {
        | _ => None
        }
      }
      {
        sessionId: row.session_id,
        userId: row.user_id->Nullable.toOption,
        createdAt: Date.fromString(row.created_at),
        expiresAt: Date.fromString(row.expires_at),
        metadata,
      }
    }

    let fromSession = (session: session): row => {
      let metadata = switch session.metadata {
      | Some(meta) => Nullable.make(JSON.stringify(meta))
      | None => Nullable.null
      }
      {
        session_id: session.sessionId,
        user_id: switch session.userId {
        | Some(id) => Nullable.make(id)
        | None => Nullable.null
        },
        created_at: session.createdAt->Date.toISOString,
        expires_at: session.expiresAt->Date.toISOString,
        metadata,
      }
    }

    let toBindParams = (session: session): array<JSON.t> => {
      let userId = switch session.userId {
      | Some(id) => JSON.Encode.string(id)
      | None => JSON.Encode.null
      }
      let createdAt = JSON.Encode.string(session.createdAt->Date.toISOString)
      let expiresAt = JSON.Encode.string(session.expiresAt->Date.toISOString)
      let metadataStr = switch session.metadata {
      | Some(meta) => JSON.Encode.string(JSON.stringify(meta))
      | None => JSON.Encode.null
      }
      [JSON.Encode.string(session.sessionId), userId, createdAt, expiresAt, metadataStr]
    }
  }

  module ChatMessages = {
    type row = {
      id: string,
      session_id: string,
      role: string,
      content: string,
      timestamp: string,
      metadata: Nullable.t<string>,
    }

    let toChatMessage = (row: row): result<chatMessage, string> => {
      let metadata = switch row.metadata->Nullable.toOption {
      | None => None
      | Some(metaStr) =>
        try {
          Some(JSON.parseExn(metaStr))
        } catch {
        | _ => None
        }
      }
      switch ChatMessage.roleFromString(row.role) {
      | Some(role) =>
        Ok({
          id: row.id,
          sessionId: row.session_id,
          role,
          content: row.content,
          timestamp: Date.fromString(row.timestamp),
          metadata,
        })
      | None => Error("Invalid role value: " ++ row.role)
      }
    }

    let fromChatMessage = (msg: chatMessage): row => {
      let metadata = switch msg.metadata {
      | Some(meta) => Nullable.make(JSON.stringify(meta))
      | None => Nullable.null
      }
      {
        id: msg.id,
        session_id: msg.sessionId,
        role: ChatMessage.roleToString(msg.role),
        content: msg.content,
        timestamp: msg.timestamp->Date.toISOString,
        metadata,
      }
    }

    let toBindParams = (msg: chatMessage): array<JSON.t> => {
      let roleStr = switch msg.role {
      | #user => "user"
      | #assistant => "assistant"
      | #system => "system"
      }
      let timestampStr = msg.timestamp->Date.toISOString
      let metadataStr = switch msg.metadata {
      | Some(meta) => JSON.Encode.string(JSON.stringify(meta))
      | None => JSON.Encode.null
      }
      [
        JSON.Encode.string(msg.id),
        JSON.Encode.string(msg.sessionId),
        JSON.Encode.string(roleStr),
        JSON.Encode.string(msg.content),
        JSON.Encode.string(timestampStr),
        metadataStr,
      ]
    }
  }

  module OAuthStates = {
    let toKey = (state: string): string => "oauth:" ++ state

    let fromKey = (key: string): option<string> =>
      if key->String.startsWith("oauth:") {
        Some(key->String.sliceToEnd(~start=6))
      } else {
        None
      }
  }
}

// ----- Metrics -------------------------------------------------------------

type metrics = {
  requests: int,
  errors: int,
  avgResponseTime: float,
}

module Metrics = {
  let encode = (metrics: metrics): Dict.t<JSON.t> => {
    let obj = Dict.make()
    obj->Dict.set("requests", JSON.Encode.int(metrics.requests))
    obj->Dict.set("errors", JSON.Encode.int(metrics.errors))
    obj->Dict.set("avgResponseTime", JSON.Encode.float(metrics.avgResponseTime))
    obj
  }

  let decode = (json: JSON.t): result<metrics, string> => {
    switch Decode.object(json) {
    | None => Error("Expected object for Metrics")
    | Some(obj) =>
      let requests = switch obj->Dict.get("requests") {
      | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))
      | None => None
      }
      let errors = switch obj->Dict.get("errors") {
      | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))
      | None => None
      }
      let avgResponseTime = switch obj->Dict.get("avgResponseTime") {
      | Some(v) => Decode.float(v)
      | None => None
      }
      switch requests {
      | None => Error("Missing required field: requests")
      | Some(requests) =>
        switch errors {
        | None => Error("Missing required field: errors")
        | Some(errors) =>
          switch avgResponseTime {
          | None => Error("Missing required field: avgResponseTime")
          | Some(avgResponseTime) => Ok({requests, errors, avgResponseTime})
          }
        }
      }
    }
  }

  let empty = (): metrics => {requests: 0, errors: 0, avgResponseTime: 0.0}

  let update = (metrics: metrics, responseTime: float, isError: bool): metrics => {
    let newRequests = metrics.requests + 1
    let newErrors = metrics.errors + (isError ? 1 : 0)
    let newAvgResponseTime =
      (metrics.avgResponseTime *. Int.toFloat(metrics.requests) +. responseTime) /.
        Int.toFloat(newRequests)
    {
      requests: newRequests,
      errors: newErrors,
      avgResponseTime: newAvgResponseTime,
    }
  }
}
