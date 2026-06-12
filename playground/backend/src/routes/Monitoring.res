// /api/monitoring/{health,metrics,ready,live} + /api/status + /api/tokens
// routes, plus a metricsMiddleware mounted at the top of the app stack
// (registered separately by Index.res via `Hono.use`).

open Types

// ---------------------------------------------------------------------------
// KV-backed metrics helpers
// ---------------------------------------------------------------------------

let getMetrics = async kv => {
  let stored = await kv->KV.get("metrics:current")
  switch stored {
  | None => Metrics.empty()
  | Some(stored) =>
    try {
      let json = JSON.parseExn(stored)
      switch Metrics.decode(json) {
      | Ok(m) => m
      | Error(_) => Metrics.empty()
      }
    } catch {
    | _ => Metrics.empty()
    }
  }
}

let saveMetrics = async (kv, metrics) => {
  let json = JSON.Encode.object(Metrics.encode(metrics))
  let jsonStr = JSON.stringify(json)
  await kv->KV.put("metrics:current", jsonStr)
}

let getStartTime = async kv => {
  let stored = await kv->KV.get("metrics:startTime")
  switch stored {
  | None =>
    let now = Date.now()
    await kv->KV.put("metrics:startTime", Float.toString(now))
    now
  | Some(stored) =>
    switch Float.fromString(stored) {
    | Some(t) => t
    | None => Date.now()
    }
  }
}

let updateMetrics = async (kv, responseTime, isError) => {
  let current = await getMetrics(kv)
  let updated = Metrics.update(current, responseTime, isError)
  await saveMetrics(kv, updated)
}

// ---------------------------------------------------------------------------
// Dependency health checks
// ---------------------------------------------------------------------------

type healthStatus = [#healthy | #degraded | #unhealthy]

type checkResult = {
  status: healthStatus,
  responseTime: float,
  details: option<Dict.t<JSON.t>>,
}

let checkDatabase = async db => {
  let startTime = Date.now()
  try {
    let _ = await db->D1.prepare("SELECT 1")->D1.first
    let responseTime = Date.now() -. startTime
    let status = if responseTime < 100.0 {
      #healthy
    } else if responseTime < 200.0 {
      #degraded
    } else {
      #unhealthy
    }
    {status, responseTime, details: None}
  } catch {
  | _ =>
    let responseTime = Date.now() -. startTime
    {
      status: #unhealthy,
      responseTime,
      details: Some(Dict.fromArray([("error", JSON.Encode.string("Database connection failed"))])),
    }
  }
}

let checkKV = async (kv, name) => {
  let startTime = Date.now()
  try {
    let _ = await kv->KV.get("health:check")
    let responseTime = Date.now() -. startTime
    let status = if responseTime < 50.0 {
      #healthy
    } else if responseTime < 100.0 {
      #degraded
    } else {
      #unhealthy
    }
    {
      status,
      responseTime,
      details: Some(Dict.fromArray([("namespace", JSON.Encode.string(name))])),
    }
  } catch {
  | _ =>
    let responseTime = Date.now() -. startTime
    {
      status: #unhealthy,
      responseTime,
      details: Some(
        Dict.fromArray([
          ("namespace", JSON.Encode.string(name)),
          ("error", JSON.Encode.string("KV access failed")),
        ]),
      ),
    }
  }
}

let statusToString = status =>
  switch status {
  | #unhealthy => "unhealthy"
  | #healthy => "healthy"
  | #degraded => "degraded"
  }

let encodeCheckResult = (result): Dict.t<JSON.t> => {
  let baseFields = [
    ("status", JSON.Encode.string(statusToString(result.status))),
    ("responseTime", JSON.Encode.float(result.responseTime)),
  ]
  let fields = switch result.details {
  | Some(d) => baseFields->Array.concat([("details", JSON.Encode.object(d))])
  | None => baseFields
  }
  Dict.fromArray(fields)
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

let handleHealth = async ctx => {
  let env = ctx->Hono.env
  let checks: Dict.t<checkResult> = Dict.make()
  let statuses = ref([])

  let dbResult = await checkDatabase(env.db)
  checks->Dict.set("database", dbResult)
  statuses := statuses.contents->Array.concat([dbResult.status])

  let kvResult = await checkKV(env.sessionKV, "kv")
  checks->Dict.set("kv", kvResult)
  statuses := statuses.contents->Array.concat([kvResult.status])

  let hasUnhealthy = statuses.contents->Array.some(s => s === #unhealthy)
  let hasDegraded = statuses.contents->Array.some(s => s === #degraded)
  let overallStatus = if hasUnhealthy {
    #unhealthy
  } else if hasDegraded {
    #degraded
  } else {
    #healthy
  }

  let checksJson: Dict.t<Dict.t<JSON.t>> = Dict.make()
  checks->Dict.forEachWithKey((result, key) => {
    checksJson->Dict.set(key, encodeCheckResult(result))
  })

  let response = Dict.fromArray([
    ("status", JSON.Encode.string(statusToString(overallStatus))),
    ("timestamp", JSON.Encode.float(Date.now())),
    ("checks", Obj.magic(checksJson)),
  ])

  let httpStatus = overallStatus === #unhealthy ? 503 : 200
  ctx->Hono.jsonWithStatus(response, httpStatus)
}

let handleMetrics = async ctx => {
  let env = ctx->Hono.env
  let metrics = await getMetrics(env.sessionKV)
  let startTime = await getStartTime(env.sessionKV)
  let uptime = (Date.now() -. startTime) /. 1000.0
  let response = Dict.fromArray([
    ("requests", JSON.Encode.int(metrics.requests)),
    ("errors", JSON.Encode.int(metrics.errors)),
    ("avgResponseTime", JSON.Encode.float(metrics.avgResponseTime)),
    ("uptime", JSON.Encode.float(uptime)),
    ("timestamp", JSON.Encode.float(Date.now())),
  ])
  ctx->Hono.json(response)
}

let handleReady = async ctx =>
  ctx->Hono.json({
    "status": "ready",
    "timestamp": Date.now(),
  })

let handleLive = async ctx =>
  ctx->Hono.json({
    "status": "alive",
    "timestamp": Date.now(),
  })

// NOTE: the recovered .mjs emits {status, timestamp} only. The live worker
// response also includes {tokenCount, activeTokens} — that shape comes from
// a separately-compiled override (see _recovered/backend/bundle.js around
// `handleStatus2`). Reverse-engineering from this .mjs alone yields the
// two-field shape below; the extra fields are added by Index.res wiring or a
// post-build patch we have not recovered yet.
let handleStatus = async ctx =>
  ctx->Hono.json({
    "status": "ok",
    "timestamp": Date.now(),
  })

let handleTokens = async ctx => {
  let env = ctx->Hono.env
  let apiKeyConfigured = Option.isSome(env.anthropicAPIKey)
  let baseUrl = env.anthropicBaseURL->Option.getOr("https://api.anthropic.com")
  ctx->Hono.json({
    "authMethod": "api-key",
    "apiKeyConfigured": apiKeyConfigured,
    "baseUrl": baseUrl,
  })
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

let metricsMiddleware = async (ctx, next) => {
  let startTime = Date.now()
  let response = await next()
  let responseTime = Date.now() -. startTime
  let isError = response->Web.Response.status >= 400
  let env = ctx->Hono.env
  let execCtx = ctx->Hono.executionCtx
  execCtx->ExecutionContext.waitUntil(updateMetrics(env.sessionKV, responseTime, isError))
  response
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

let register = (app: Hono.t<env>): Hono.t<env> =>
  app
  ->Hono.get("/api/status", handleStatus)
  ->Hono.get("/api/tokens", handleTokens)
  ->Hono.get("/api/monitoring/health", handleHealth)
  ->Hono.get("/api/monitoring/metrics", handleMetrics)
  ->Hono.get("/api/monitoring/ready", handleReady)
  ->Hono.get("/api/monitoring/live", handleLive)

let registerMiddleware = (app: Hono.t<env>): Hono.t<env> => app->Hono.use(metricsMiddleware)
