// /api/chat — main LLM endpoint. Streams Anthropic completions over SSE,
// traces calls via bindings/Langfuse, persists user + assistant turns into D1
// `chat_messages` keyed by `session_id` from KV `SESSION_KV`.

open Types

// ---------------------------------------------------------------------------
// Hono request extras the shared binding doesn't yet expose.
// `c.req` exposes `param(name)` for URL params and `json()` for body parsing;
// the shared `Hono.req` binding returns the underlying Fetch Request, so we
// re-bind the two HonoRequest helpers we need here.
// ---------------------------------------------------------------------------
@send external reqParam: (Hono.context<'env>, string) => Nullable.t<string> = "param"
@send external reqJsonBody: (Hono.context<'env>, unit) => promise<JSON.t> = "json"
@get external ctxReq: Hono.context<'env> => 'req = "req"

// Cloudflare ExecutionContext (`ctx.executionCtx.waitUntil`).
type executionCtx
@get external executionCtx: Hono.context<'env> => executionCtx = "executionCtx"
@send external waitUntil: (executionCtx, promise<'a>) => unit = "waitUntil"

// ---------------------------------------------------------------------------
// D1 prepared statement helpers used by the chat history queries.
// ---------------------------------------------------------------------------
@send external prepare: (d1Database, string) => d1PreparedStatement = "prepare"
@variadic @send
external bind: (d1PreparedStatement, array<JSON.t>) => d1PreparedStatement = "bind"
@send external all: d1PreparedStatement => promise<d1Result<DB.ChatMessages.row>> = "all"
@send
external run: d1PreparedStatement => promise<{"success": bool}> = "run"

// ---------------------------------------------------------------------------
// SSE response plumbing (TransformStream + writer + TextEncoder + Response).
// Compiled into a single IIFE in the original .mjs, kept as a %raw block here
// so the JS output matches byte-for-byte.
// ---------------------------------------------------------------------------
type sseChannel<'writer, 'encoder> = {
  writer: 'writer,
  encoder: 'encoder,
  response: Web.Response.t,
}

let makeSSEChannel: unit => sseChannel<'a, 'b> = %raw(`function() {
  const transformStream = new TransformStream();
  const writer = transformStream.writable.getWriter();
  const encoder = new TextEncoder();
  const headers = {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
    "Access-Control-Allow-Origin": "*"
  };
  const response = new Response(transformStream.readable, { status: 200, headers });
  return { writer, encoder, response };
}`)

let writerWrite: ('writer, 'chunk) => promise<unit> = %raw(`function(w, c) { return w.write(c); }`)
let writerClose: 'writer => promise<unit> = %raw(`function(w) { return w.close(); }`)
let encoderEncode: ('encoder, string) => 'chunk = %raw(`function(e, s) { return e.encode(s); }`)

// ---------------------------------------------------------------------------
// Request validation
// ---------------------------------------------------------------------------

type chatRequest = {
  message: string,
  sessionId: string,
  systemPrompt: option<string>,
  model: option<string>,
  temperature: option<float>,
}

type validationResult =
  | Valid(chatRequest)
  | Invalid(Types.error)

let validateRequest = (json: JSON.t): validationResult => {
  switch Decode.object(json) {
  | None => Invalid(ErrorHandler.validationError("body", "Request body must be a JSON object"))
  | Some(obj) =>
    let message = switch obj->Dict.get("message") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let sessionId = switch obj->Dict.get("sessionId") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let systemPrompt = switch obj->Dict.get("systemPrompt") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let model = switch obj->Dict.get("model") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let temperature = switch obj->Dict.get("temperature") {
    | Some(v) => Decode.float(v)
    | None => None
    }
    switch message {
    | None => Invalid(ErrorHandler.validationError("message", "Message is required"))
    | Some("") => Invalid(ErrorHandler.validationError("message", "Message cannot be empty"))
    | Some(message) if String.length(message) > 100000 =>
      Invalid(
        ErrorHandler.validationError(
          "message",
          "Message exceeds maximum length of 100000 characters",
        ),
      )
    | Some(message) =>
      switch sessionId {
      | None => Invalid(ErrorHandler.validationError("sessionId", "Session ID is required"))
      | Some("") => Invalid(ErrorHandler.validationError("sessionId", "Session ID cannot be empty"))
      | Some(sessionId) =>
        switch temperature {
        | Some(t) if t < 0.0 || t > 1.0 =>
          Invalid(
            ErrorHandler.validationError(
              "temperature",
              "Temperature must be between 0.0 and 1.0",
            ),
          )
        | _ => Valid({message, sessionId, systemPrompt, model, temperature})
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Session lookup against KV (`session:<id>` key).
// ---------------------------------------------------------------------------

let getSessionKey = (sessionId: string): string => "session:" ++ sessionId

let validateSession = async (kv: kvNamespace, sessionId: string): option<session> => {
  let key = getSessionKey(sessionId)
  let sessionJsonN = await kv.get(key)
  switch sessionJsonN->Nullable.toOption {
  | None => None
  | Some(sessionJson) =>
    try {
      let json = JSON.parseExn(sessionJson)
      switch Session.decode(json) {
      | Error(_) => None
      | Ok(session) =>
        let now = Date.now()
        let expiresAt = session.expiresAt->Date.getTime
        if now < expiresAt {
          Some(session)
        } else {
          None
        }
      }
    } catch {
    | _ => None
    }
  }
}

// ---------------------------------------------------------------------------
// Anthropic client + D1 chat history helpers.
// ---------------------------------------------------------------------------

let createAnthropicClient = (env: env): AnthropicSDK.Client.t => {
  let apiKey = env.anthropicAPIKey->Option.getOr("")
  let baseURL = env.anthropicBaseURL->Option.getOr("https://api.anthropic.com")
  if apiKey === "" {
    Console.warn("[Chat] ANTHROPIC_API_KEY not set")
  }
  AnthropicSDK.Client.make({apiKey, baseURL})
}

let getChatHistory = async (db: d1Database, sessionId: string): array<chatMessage> => {
  let bindParams = [JSON.Encode.string(sessionId)]
  let result =
    await db
    ->prepare("SELECT * FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC")
    ->bind(bindParams)
    ->all
  if result.success {
    result.results->Array.filterMap(row => {
      switch DB.ChatMessages.toChatMessage(row) {
      | Ok(msg) => Some(msg)
      | Error(_) => None
      }
    })
  } else {
    []
  }
}

let saveMessage = async (db: d1Database, message: chatMessage): unit => {
  let params = DB.ChatMessages.toBindParams(message)
  let _ =
    await db
    ->prepare(
      "INSERT INTO chat_messages (id, session_id, role, content, timestamp, metadata) VALUES (?, ?, ?, ?, ?, ?)",
    )
    ->bind(params)
    ->run
}

// ---------------------------------------------------------------------------
// Safe SSE writer wrappers — never throw.
// ---------------------------------------------------------------------------

let safeWrite = async (writer, encoder, data: string): bool => {
  try {
    await writerWrite(writer, encoderEncode(encoder, data))
    true
  } catch {
  | _ => false
  }
}

let safeClose = async writer => {
  try {
    await writerClose(writer)
  } catch {
  | _ => ()
  }
}

// ---------------------------------------------------------------------------
// streamResponse — pumps the Anthropic stream into the SSE writer.
// Emits {type: "chunk", content} for each text delta and a final
// {type: "complete", content: <fullText>} on message_stop.
// Errors are forwarded as {type: "error", content: <msg>}.
// ---------------------------------------------------------------------------

let streamResponse = async (
  client: AnthropicSDK.Client.t,
  options: AnthropicSDK.messageOptions,
  writer,
  encoder,
): string => {
  let fullText = ref("")
  let connectionClosed = ref(false)
  let messagesApi = client->AnthropicSDK.Messages.get
  let stream = messagesApi->AnthropicSDK.Messages.stream(options)
  await AnthropicSDK.iterateStream(
    stream,
    async event => {
      if connectionClosed.contents {
        ()
      } else {
        switch AnthropicSDK.extractDeltaText(event) {
        | Some(text) =>
          fullText := fullText.contents ++ text
          let chunkJson = JSON.stringify(
            Dict.fromArray([
              ("type", JSON.Encode.string("chunk")),
              ("content", JSON.Encode.string(text)),
            ])->JSON.Encode.object,
          )
          let sseEvent = SSEStream.formatSSE(chunkJson)
          let success = await safeWrite(writer, encoder, sseEvent)
          if !success {
            connectionClosed := true
          }
        | None =>
          if event.type_ === "message_stop" {
            let completeJson = JSON.stringify(
              Dict.fromArray([
                ("type", JSON.Encode.string("complete")),
                ("content", JSON.Encode.string(fullText.contents)),
              ])->JSON.Encode.object,
            )
            let doneEvent = SSEStream.formatSSE(completeJson)
            let _ = await safeWrite(writer, encoder, doneEvent)
          }
        }
      }
    },
    async errorMessage => {
      if connectionClosed.contents {
        ()
      } else {
        let errorJson = JSON.stringify(
          Dict.fromArray([
            ("type", JSON.Encode.string("error")),
            ("content", JSON.Encode.string(errorMessage)),
          ])->JSON.Encode.object,
        )
        let errorEvent = SSEStream.formatSSE(errorJson)
        let _ = await safeWrite(writer, encoder, errorEvent)
      }
    },
  )
  fullText.contents
}

// ---------------------------------------------------------------------------
// POST /api/chat — main handler.
// ---------------------------------------------------------------------------

let handleChat = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let bodyResult = try {
    let json = await ctxReq(ctx)->reqJsonBody()
    Some(json)
  } catch {
  | _ => None
  }
  switch bodyResult {
  | None => ctx->Hono.jsonWithStatus({"error": "Invalid JSON body"}, 400)
  | Some(body) =>
    switch validateRequest(body) {
    | Invalid(error) =>
      let errorResponse = ErrorHandler.toErrorResponse(error)
      ctx->Hono.jsonWithStatus(
        ErrorHandler.encodeErrorResponse(errorResponse),
        errorResponse.statusCode,
      )
    | Valid(request) =>
      let sessionOpt = await validateSession(env.sessionKV, request.sessionId)
      switch sessionOpt {
      | None =>
        ctx->Hono.jsonWithStatus(
          {
            "error": "AuthenticationError",
            "message": "Invalid or expired session",
          },
          401,
        )
      | Some(_) =>
        let client = createAnthropicClient(env)
        let langfuseClient = Langfuse.makeClientFromEnv(env)
        let history = await getChatHistory(env.db, request.sessionId)
        let messages = history->Array.map((msg: chatMessage) => {
          let role = switch msg.role {
          | #system | #user => "user"
          | #assistant => "assistant"
          }
          ({role, content: msg.content}: AnthropicSDK.message)
        })
        let messages = Array.concat(messages, [AnthropicSDK.userMessage(request.message)])
        let model = request.model->Option.getOr("claude-sonnet-4-20250514")
        let systemPrompt =
          request.systemPrompt->Option.getOr(WireframeAssistant.getSystemPrompt())
        Console.log2("[Chat] System prompt length:", String.length(systemPrompt))
        Console.log2("[Chat] System prompt preview:", String.slice(systemPrompt, ~start=0, ~end=200))
        Console.log2("[Chat] Model:", model)
        let messageOptions = AnthropicSDK.makeMessageOptions(
          ~model,
          ~maxTokens=4096,
          ~temperature=request.temperature,
          ~system=systemPrompt,
          ~stream=true,
          messages,
        )
        let channel = makeSSEChannel()
        let writer = channel.writer
        let encoder = channel.encoder
        let execCtx = ctx->executionCtx
        execCtx->waitUntil(
          (async () => {
            try {
              Console.log("[Chat] Starting streaming response...")
              let langfuseTraceId = switch langfuseClient {
              | None => None
              | Some(lc) =>
                Console.log("[Chat] Creating Langfuse trace")
                let input = Dict.fromArray([
                  ("message", JSON.Encode.string(request.message)),
                  ("system", JSON.Encode.string(systemPrompt)),
                ])->JSON.Encode.object
                let output =
                  Dict.fromArray([("response", JSON.Encode.string(""))])->JSON.Encode.object
                let metadata = Dict.fromArray([
                  ("model", JSON.Encode.string(model)),
                  ("historyLength", JSON.Encode.int(Array.length(history))),
                  ("systemPromptLength", JSON.Encode.int(String.length(systemPrompt))),
                ])->JSON.Encode.object
                let result = await Langfuse.createTrace(
                  lc,
                  ~name="wyreframe-chat",
                  ~sessionId=request.sessionId,
                  ~input,
                  ~output,
                  ~metadata,
                  ~timestamp=Date.make(),
                )
                switch result {
                | Ok(traceId) =>
                  Console.log2("[Chat] Langfuse trace created:", traceId)
                  Some(traceId)
                | Error(err) =>
                  Console.error2("[Chat] Langfuse trace creation failed:", err)
                  None
                }
              }
              let langfuseGenerationId = switch (langfuseClient, langfuseTraceId) {
              | (Some(lc), Some(traceId)) =>
                let systemMessage =
                  Dict.fromArray([
                    ("role", JSON.Encode.string("system")),
                    ("content", JSON.Encode.string(systemPrompt)),
                  ])->JSON.Encode.object
                let messagesJson = messages->Array.map((msg: AnthropicSDK.message) => {
                  let roleStr = msg.role === "user" ? "user" : "assistant"
                  Dict.fromArray([
                    ("role", JSON.Encode.string(roleStr)),
                    ("content", JSON.Encode.string(msg.content)),
                  ])->JSON.Encode.object
                })
                let messagesJsonWithSystem = Array.concat([systemMessage], messagesJson)
                let modelParameters = Dict.fromArray([
                  (
                    "temperature",
                    request.temperature->Option.mapOr(JSON.Encode.null, t =>
                      JSON.Encode.float(t)
                    ),
                  ),
                  ("max_tokens", JSON.Encode.int(4096)),
                  ("system", JSON.Encode.string(systemPrompt)),
                ])->JSON.Encode.object
                let input = JSON.Encode.array(messagesJsonWithSystem)
                let result = await Langfuse.createGeneration(
                  lc,
                  ~traceId,
                  ~name="claude-completion",
                  ~model,
                  ~modelParameters,
                  ~input,
                  ~startTime=Date.make(),
                )
                switch result {
                | Ok(generationId) => Some(generationId)
                | Error(err) =>
                  Console.error2("[Chat] Langfuse generation creation failed:", err)
                  None
                }
              | _ => None
              }
              let userMessageId = SecurityUtils.generateUUID()
              let userMsg = ChatMessage.make(
                userMessageId,
                request.sessionId,
                #user,
                request.message,
                None,
              )
              await saveMessage(env.db, userMsg)
              Console.log("[Chat] User message saved")
              Console.log("[Chat] Starting stream response...")
              let fullText = await streamResponse(client, messageOptions, writer, encoder)
              Console.log2("[Chat] Streaming complete, text length:", String.length(fullText))
              Console.log2("[Chat] Full text preview:", String.slice(fullText, ~start=0, ~end=100))
              Console.log2(
                "[Chat] Langfuse trace ID:",
                langfuseTraceId->Option.getOr("None"),
              )
              Console.log2(
                "[Chat] Langfuse generation ID:",
                langfuseGenerationId->Option.getOr("None"),
              )
              switch langfuseClient {
              | None => Console.warn("[Chat] No Langfuse client available")
              | Some(lc) =>
                switch langfuseTraceId {
                | None => Console.warn("[Chat] No Langfuse trace ID available")
                | Some(traceId) =>
                  switch langfuseGenerationId {
                  | None => Console.warn("[Chat] No Langfuse generation ID available")
                  | Some(generationId) =>
                    Console.log("[Chat] Updating Langfuse with final output...")
                    Console.log2("[Chat] Output text length:", String.length(fullText))
                    Console.log2("[Chat] Updating generation:", generationId)
                    let genUpdateResult = await Langfuse.updateGeneration(
                      lc,
                      ~generationId,
                      ~traceId,
                      ~output=JSON.Encode.string(fullText),
                      ~endTime=Date.make(),
                    )
                    switch genUpdateResult {
                    | Ok() =>
                      Console.log("[Chat] ✓ Langfuse generation updated successfully")
                    | Error(err) =>
                      Console.error2(
                        "[Chat] ✗ Langfuse generation update failed:",
                        err,
                      )
                    }
                    Console.log2("[Chat] Updating trace:", traceId)
                    let outputObj =
                      Dict.fromArray([
                        ("response", JSON.Encode.string(fullText)),
                      ])->JSON.Encode.object
                    Console.log2("[Chat] Output object:", JSON.stringify(outputObj))
                    let traceUpdateResult = await Langfuse.updateTrace(
                      lc,
                      traceId,
                      ~output=outputObj,
                    )
                    switch traceUpdateResult {
                    | Ok() => Console.log("[Chat] ✓ Langfuse trace updated successfully")
                    | Error(err) =>
                      Console.error2("[Chat] ✗ Langfuse trace update failed:", err)
                    }
                  }
                }
              }
              if fullText !== "" {
                let assistantMessageId = SecurityUtils.generateUUID()
                let assistantMsg = ChatMessage.make(
                  assistantMessageId,
                  request.sessionId,
                  #assistant,
                  fullText,
                  None,
                )
                await saveMessage(env.db, assistantMsg)
                Console.log("[Chat] Assistant message saved")
              }
            } catch {
            | Exn.Error(err) =>
              let errorMsg = Exn.message(err)->Option.getOr("Unknown error")
              Console.error2("[Chat] Streaming error:", errorMsg)
              let errorJson = JSON.stringify(
                Dict.fromArray([
                  ("type", JSON.Encode.string("error")),
                  ("content", JSON.Encode.string(errorMsg)),
                ])->JSON.Encode.object,
              )
              let errorEvent = SSEStream.formatSSE(errorJson)
              let _ = await safeWrite(writer, encoder, errorEvent)
            | _ => Console.error("[Chat] Unknown streaming error")
            }
            await safeClose(writer)
          })(),
        )
        channel.response
      }
    }
  }
}

// ---------------------------------------------------------------------------
// GET /api/chat/:sessionId — return the persisted history for a session.
// ---------------------------------------------------------------------------

let handleGetHistory = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let sessionIdN = ctxReq(ctx)->reqParam("sessionId")
  switch sessionIdN->Nullable.toOption {
  | None =>
    ctx->Hono.jsonWithStatus(
      {"error": "ValidationError", "message": "Session ID is required"},
      400,
    )
  | Some(sessionId) =>
    let sessionOpt = await validateSession(env.sessionKV, sessionId)
    switch sessionOpt {
    | None =>
      ctx->Hono.jsonWithStatus(
        {
          "error": "AuthenticationError",
          "message": "Invalid or expired session",
        },
        401,
      )
    | Some(_) =>
      let history = await getChatHistory(env.db, sessionId)
      let historyJson = history->Array.map((msg: chatMessage) => {
        let roleStr = switch msg.role {
        | #user => "user"
        | #system => "system"
        | #assistant => "assistant"
        }
        Dict.fromArray([
          ("id", JSON.Encode.string(msg.id)),
          ("sessionId", JSON.Encode.string(msg.sessionId)),
          ("role", JSON.Encode.string(roleStr)),
          ("content", JSON.Encode.string(msg.content)),
          ("timestamp", JSON.Encode.string(msg.timestamp->Date.toISOString)),
          ("metadata", msg.metadata->Option.getOr(JSON.Encode.null)),
        ])
      })
      ctx->Hono.json({
        "success": true,
        "sessionId": sessionId,
        "messages": historyJson,
        "count": Array.length(history),
      })
    }
  }
}

// ---------------------------------------------------------------------------
// DELETE /api/chat/:sessionId — wipe persisted history for a session.
// ---------------------------------------------------------------------------

let handleDeleteHistory = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let sessionIdN = ctxReq(ctx)->reqParam("sessionId")
  switch sessionIdN->Nullable.toOption {
  | None =>
    ctx->Hono.jsonWithStatus(
      {"error": "ValidationError", "message": "Session ID is required"},
      400,
    )
  | Some(sessionId) =>
    let sessionOpt = await validateSession(env.sessionKV, sessionId)
    switch sessionOpt {
    | None =>
      ctx->Hono.jsonWithStatus(
        {
          "error": "AuthenticationError",
          "message": "Invalid or expired session",
        },
        401,
      )
    | Some(_) =>
      let bindParams = [JSON.Encode.string(sessionId)]
      let result =
        await env.db
        ->prepare("DELETE FROM chat_messages WHERE session_id = ?")
        ->bind(bindParams)
        ->run
      if result["success"] {
        ctx->Hono.json({
          "success": true,
          "sessionId": sessionId,
          "message": "Chat history deleted successfully",
        })
      } else {
        ctx->Hono.jsonWithStatus(
          {
            "error": "DatabaseError",
            "message": "Failed to delete chat history",
          },
          500,
        )
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

let register = (app: Hono.t<env>): Hono.t<env> =>
  app
  ->Hono.post("/api/chat", handleChat)
  ->Hono.get("/api/chat/:sessionId", handleGetHistory)
  ->Hono.delete("/api/chat/:sessionId", handleDeleteHistory)
