// /api/status, /api/auth/start, /callback, /api/tokens(+manual/delete/refresh-profile),
// /api/usage/:tokenId — Anthropic OAuth + manual token entry + usage tracking.
//
// Tokens stored as a single JSON array under KV key `claudius:tokens`
// (see _recovered/backend/trimmed/routes_OAuth.mjs for the source-of-truth shape).
// OAuth PKCE state is stashed under `oauth:state:<state>` with a 5-minute TTL.

open Types

// ---------------------------------------------------------------------------
// Local bindings the shared Hono.res does not yet expose. Routes need access
// to HonoRequest's `url`, `json()`, `param(name)`, `query(name)` and `c.html`.

type honoReq
@get external honoReq: Hono.context<'env> => honoReq = "req"
@get external reqUrl: honoReq => string = "url"
@send external reqJson: honoReq => promise<'a> = "json"
@send external reqParam: (honoReq, string) => string = "param"
@send external reqQuery: (honoReq, string) => Nullable.t<string> = "query"

@send external html: (Hono.context<'env>, string) => Web.Response.t = "html"

// Cloudflare KV namespace surface used here. Lives on env.sessionKV.
type kv = {
  get: string => promise<Nullable.t<string>>,
  put: (string, string, {"expirationTtl": int}) => promise<unit>,
  delete: string => promise<unit>,
}

@get external sessionKv: env => kv = "SESSION_KV"

// Web Crypto access.
@val external crypto: 'a = "crypto"
@val external btoa: string => string = "btoa"
@val external encodeURIComponent: string => string = "encodeURIComponent"

@new external textEncoder: unit => 'a = "TextEncoder"
@new external urlObj: string => 'a = "URL"

// ---------------------------------------------------------------------------

let claudeClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
let oauthAuthorizeUrl = "https://claude.ai/oauth/authorize"
let oauthScopes = "org:create_api_key user:profile user:inference user:sessions:claude_code"
let oauthStatePrefix = "oauth:state:"
let tokensKey = "claudius:tokens"

// ---------------------------------------------------------------------------
// Profile / token / usage record shapes (mirrored from the .mjs).

type profileAccount = {
  uuid: string,
  email: string,
  displayName: option<string>,
}

type profileOrganization = {
  uuid: string,
  organizationType: string,
  rateLimitTier: option<string>,
  hasExtraUsageEnabled: option<bool>,
}

type profile = {
  account: profileAccount,
  organization: profileOrganization,
}

type usageBucket = {
  percentage: int,
  resetTime: string,
  resetTimestamp: string,
}

type usageMetrics = {
  currentSession: usageBucket,
  currentWeekAll: usageBucket,
  currentWeekSonnet: usageBucket,
}

type cachedUsageMetrics = {
  currentSession: usageBucket,
  currentWeekAll: usageBucket,
  currentWeekSonnet: usageBucket,
  extractedAt: string,
}

type storedToken = {
  id: string,
  accessToken: string,
  refreshToken: string,
  expiresAt: float,
  account: option<string>,
  organization: option<string>,
  profile: option<profile>,
  createdAt: float,
  lastUsed: option<float>,
  cachedUsageMetrics: option<cachedUsageMetrics>,
}

type oauthStateData = {
  codeVerifier: string,
  redirectUri: string,
  createdAt: float,
}

type tokenExchangeResult = {
  accessToken: string,
  refreshToken: string,
  expiresIn: int,
  accountEmail: Nullable.t<string>,
  orgName: Nullable.t<string>,
}

// ---------------------------------------------------------------------------
// PKCE helpers.

let generateRandomString = (length: int): string => {
  %raw(`(function(_length) {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
    const array2 = new Uint8Array(_length);
    crypto.getRandomValues(array2);
    return Array.from(array2, (byte) => chars[byte % chars.length]).join("");
  })`)(length)
}

let generateCodeChallenge = (verifier: string): promise<string> => {
  %raw(`(async function(_verifier) {
    const encoder = new TextEncoder();
    const data = encoder.encode(_verifier);
    const hash = await crypto.subtle.digest("SHA-256", data);
    return btoa(String.fromCharCode(...new Uint8Array(hash))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  })`)(verifier)
}

// ---------------------------------------------------------------------------
// Token persistence (one JSON array under `claudius:tokens`).

let getTokens = async (kv: kv): array<storedToken> => {
  let stored = await kv.get(tokensKey)
  switch stored->Nullable.toOption {
  | None => []
  | Some(json) =>
    try {
      (Obj.magic(JSON.parseExn(json)): array<storedToken>)
    } catch {
    | _ => []
    }
  }
}

let saveTokens = async (kv: kv, tokens: array<storedToken>): unit => {
  let json = JSON.stringifyAny(tokens)->Option.getOr("[]")
  await kv.put(tokensKey, json, {"expirationTtl": 2592000})
}

// ---------------------------------------------------------------------------
// Anthropic profile + usage fetchers (raw JS — mirrors the bundle exactly).

let fetchProfileFn: string => promise<Nullable.t<profile>> = %raw(`async function(token) {
  try {
    const response = await fetch("https://api.anthropic.com/api/oauth/profile", {
      method: "GET",
      headers: {
        "Authorization": "Bearer " + token,
        "Accept": "application/json"
      }
    });
    if (!response.ok) {
      console.error("[OAuth] Profile fetch failed:", response.status);
      return null;
    }
    const data = await response.json();
    console.log("[OAuth] Profile data:", JSON.stringify(data, null, 2));
    if (!data.account?.uuid || !data.account?.email || !data.organization?.uuid) {
      console.error("[OAuth] Profile missing required fields:", {
        hasAccount: !!data.account,
        hasEmail: !!data.account?.email,
        hasOrg: !!data.organization
      });
      return null;
    }
    return {
      account: {
        uuid: data.account.uuid,
        email: data.account.email,
        displayName: data.account.display_name || void 0
      },
      organization: {
        uuid: data.organization.uuid,
        organizationType: data.organization.organization_type || "unknown",
        rateLimitTier: data.organization.rate_limit_tier || void 0,
        hasExtraUsageEnabled: data.organization.has_extra_usage_enabled || void 0
      }
    };
  } catch (err) {
    console.error("[OAuth] Profile fetch error:", err);
    return null;
  }
}`)

let fetchProfile = async (accessToken: string): option<profile> => {
  let result = await fetchProfileFn(accessToken)
  result->Nullable.toOption
}

let fetchUsageMetricsFn: string => promise<Nullable.t<usageMetrics>> = %raw(`async function(token) {
  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer " + token,
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "claude-code-20250219,oauth-2025-04-20",
        "anthropic-dangerous-direct-browser-access": "true",
        "Content-Type": "application/json",
        "User-Agent": "claude-cli/2.0.75 (external, cli)",
        "x-app": "cli"
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        messages: [{ role: "user", content: [{ type: "text", text: "quota" }] }],
        system: [{ type: "text", text: "You are Claude Code, Anthropic's official CLI for Claude.", cache_control: { type: "ephemeral" } }],
        tools: [],
        metadata: { user_id: "usage_client_quota_check" },
        max_tokens: 1
      })
    });
    if (!response.ok) {
      console.error("[OAuth] Usage metrics fetch failed:", response.status);
      return null;
    }
    const fiveHourUtil = parseFloat(response.headers.get("anthropic-ratelimit-unified-5h-utilization") || "0");
    const sevenDayUtil = parseFloat(response.headers.get("anthropic-ratelimit-unified-7d-utilization") || "0");
    const sonnetUtil = parseFloat(response.headers.get("anthropic-ratelimit-unified-7d_sonnet-utilization") || "0");
    const fiveHourReset = parseInt(response.headers.get("anthropic-ratelimit-unified-5h-reset") || "0");
    const sevenDayReset = parseInt(response.headers.get("anthropic-ratelimit-unified-7d-reset") || "0");
    const sonnetReset = parseInt(response.headers.get("anthropic-ratelimit-unified-7d_sonnet-reset") || "0");
    const formatResetTimeJs = (timestamp) => {
      if (!timestamp || timestamp === 0) return "Unknown";
      const date = new Date(timestamp * 1e3);
      const now = new Date();
      const diffMs = date.getTime() - now.getTime();
      const diffHours = Math.floor(diffMs / (1e3 * 60 * 60));
      const diffMinutes = Math.floor(diffMs % (1e3 * 60 * 60) / (1e3 * 60));
      if (diffHours < 24 && diffHours >= 0) {
        if (diffHours === 0) return diffMinutes + "m";
        return diffHours + "h " + diffMinutes + "m";
      }
      return date.toLocaleString("ko-KR", { month: "long", day: "numeric", hour: "numeric", minute: "2-digit", hour12: true });
    };
    return {
      currentSession: {
        percentage: Math.floor(fiveHourUtil * 100),
        resetTime: formatResetTimeJs(fiveHourReset),
        resetTimestamp: new Date(fiveHourReset * 1e3).toISOString()
      },
      currentWeekAll: {
        percentage: Math.floor(sevenDayUtil * 100),
        resetTime: formatResetTimeJs(sevenDayReset),
        resetTimestamp: new Date(sevenDayReset * 1e3).toISOString()
      },
      currentWeekSonnet: {
        percentage: Math.floor(sonnetUtil * 100),
        resetTime: formatResetTimeJs(sonnetReset),
        resetTimestamp: new Date(sonnetReset * 1e3).toISOString()
      }
    };
  } catch (err) {
    console.error("[OAuth] Usage metrics error:", err);
    return null;
  }
}`)

let fetchUsageMetrics = async (accessToken: string): option<usageMetrics> => {
  let result = await fetchUsageMetricsFn(accessToken)
  result->Nullable.toOption
}

// ---------------------------------------------------------------------------
// Handlers.

let handleStatus = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let tokens = await getTokens(env->sessionKv)
  let now = Date.now()
  ctx->Hono.json({
    "status": "ok",
    "tokenCount": Array.length(tokens),
    "activeTokens": tokens->Array.filter(t => t.expiresAt > now)->Array.length,
    "timestamp": now,
  })
}

let handleStart = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  try {
    let state = generateRandomString(32)
    let codeVerifier = generateRandomString(64)
    let codeChallenge = await generateCodeChallenge(codeVerifier)
    let u = urlObj((ctx->honoReq)->reqUrl)
    let p: string = %raw(`u.port`)
    let port = String.length(p) > 0 ? p : "8788"
    let redirectUri = "http://localhost:" ++ port ++ "/callback"
    let stateData = {
      codeVerifier,
      redirectUri,
      createdAt: Date.now(),
    }
    let stateJson = JSON.stringifyAny(stateData)->Option.getOr("{}")
    await (env->sessionKv).put(oauthStatePrefix ++ state, stateJson, {"expirationTtl": 300})
    let encodedRedirectUri = encodeURIComponent(redirectUri)
    let encodedScopes = encodeURIComponent(oauthScopes)
    let authUrl =
      oauthAuthorizeUrl ++
      "?code=true&client_id=" ++
      claudeClientId ++
      "&response_type=code&redirect_uri=" ++
      encodedRedirectUri ++
      "&scope=" ++
      encodedScopes ++
      "&code_challenge=" ++
      codeChallenge ++
      "&code_challenge_method=S256&state=" ++
      state
    ctx->Hono.json({"authUrl": authUrl, "state": state})
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"error": "Failed to start OAuth flow"}, 500)
  }
}

let errorHtml = (message: string, ~debug: string="") => {
  let debugSection = debug === ""
    ? ""
    : `<pre style="text-align: left; background: #1e293b; padding: 1rem; border-radius: 8px; font-size: 0.75rem; overflow: auto; max-width: 500px; margin: 1rem auto;">` ++
      debug ++ `</pre>`
  `<!DOCTYPE html>
    <html>
    <head><title>OAuth Error</title></head>
    <body style="font-family: sans-serif; text-align: center; padding: 2rem; background: #0f172a; color: #f1f5f9;">
      <h1 style="color: #ef4444;">\u{C778}\u{C99D} \u{C2E4}\u{D328}</h1>
      <p>` ++
  message ++
  `</p>
      ` ++
  debugSection ++
  `
      <p style="color: #64748b; font-size: 0.875rem; margin-top: 1rem;">\u{C774} \u{CC3D}\u{C740} 5\u{CD08} \u{D6C4} \u{C790}\u{B3D9}\u{C73C}\u{B85C} \u{B2EB}\u{D799}\u{B2C8}\u{B2E4}.</p>
      <script>setTimeout(() => window.close(), 5000);<\/script>
    </body>
    </html>`
}

let exchangeToken: (
  string,
  string,
  string,
  string,
  string,
) => promise<Nullable.t<tokenExchangeResult>> = %raw(`async function(code2, redirectUri, clientId, codeVerifier, state2) {
  try {
    const tokenBody = {
      grant_type: "authorization_code",
      code: code2,
      redirect_uri: redirectUri,
      client_id: clientId,
      code_verifier: codeVerifier,
      state: state2
    };
    console.log("[OAuth] Token exchange request:", {
      url: "https://console.anthropic.com/v1/oauth/token",
      redirect_uri: redirectUri,
      client_id: clientId,
      code_length: code2?.length,
      code_verifier_length: codeVerifier?.length,
      state_length: state2?.length
    });
    const response = await fetch("https://console.anthropic.com/v1/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify(tokenBody)
    });
    console.log("[OAuth] Token response status:", response.status);
    if (!response.ok) {
      const errorText = await response.text();
      console.error("[OAuth] Token exchange failed:", response.status, errorText);
      return null;
    }
    const data = await response.json();
    return {
      accessToken: data.access_token,
      refreshToken: data.refresh_token || "",
      expiresIn: data.expires_in || 28800,
      accountEmail: data.account?.email_address || null,
      orgName: data.organization?.name || null
    };
  } catch (err) {
    console.error("[OAuth] Token exchange error:", err);
    return null;
  }
}`)

let handleCallback = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let u = urlObj((ctx->honoReq)->reqUrl)
  ignore(u)
  let url: string = %raw(`u.toString()`)
  let code: Nullable.t<string> = %raw(`u.searchParams.get("code")`)
  let state: Nullable.t<string> = %raw(`u.searchParams.get("state")`)
  let errorParam: Nullable.t<string> = %raw(`u.searchParams.get("error")`)
  let errorDescription: Nullable.t<string> = %raw(`u.searchParams.get("error_description")`)

  Console.log2("[OAuth Callback] URL:", url)
  Console.log2("[OAuth Callback] code:", code->Nullable.toOption)
  Console.log2("[OAuth Callback] state:", state->Nullable.toOption)
  Console.log2("[OAuth Callback] error:", errorParam->Nullable.toOption)
  Console.log2("[OAuth Callback] error_description:", errorDescription->Nullable.toOption)

  switch errorParam->Nullable.toOption {
  | None =>
    switch (code->Nullable.toOption, state->Nullable.toOption) {
    | (None, _) =>
      ctx->html(
        errorHtml(`\u{D544}\u{C218} \u{D30C}\u{B77C}\u{BBF8}\u{D130}\u{AC00} \u{B204}\u{B77D}\u{B418}\u{C5C8}\u{C2B5}\u{B2C8}\u{B2E4}.`),
      )
    | (_, None) =>
      ctx->html(
        errorHtml(`\u{D544}\u{C218} \u{D30C}\u{B77C}\u{BBF8}\u{D130}\u{AC00} \u{B204}\u{B77D}\u{B418}\u{C5C8}\u{C2B5}\u{B2C8}\u{B2E4}.`),
      )
    | (Some(code), Some(state)) =>
      let storedJsonNull = await (env->sessionKv).get(oauthStatePrefix ++ state)
      switch storedJsonNull->Nullable.toOption {
      | None =>
        ctx->html(
          errorHtml(`\u{C138}\u{C158}\u{C774} \u{B9CC}\u{B8CC}\u{B418}\u{C5C8}\u{C2B5}\u{B2C8}\u{B2E4}. \u{B2E4}\u{C2DC} \u{C2DC}\u{B3C4}\u{D574}\u{C8FC}\u{C138}\u{C694}.`),
        )
      | Some(storedJson) =>
        let storedData: oauthStateData = Obj.magic(JSON.parseExn(storedJson))
        await (env->sessionKv).delete(oauthStatePrefix ++ state)
        let tokenResultNullable = await exchangeToken(
          code,
          storedData.redirectUri,
          claudeClientId,
          storedData.codeVerifier,
          state,
        )
        switch tokenResultNullable->Nullable.toOption {
        | None =>
          ctx->html(
            errorHtml(`\u{D1A0}\u{D070} \u{AD50}\u{D658}\u{C5D0} \u{C2E4}\u{D328}\u{D588}\u{C2B5}\u{B2C8}\u{B2E4}.`),
          )
        | Some(tokenResult) =>
          let accessToken = tokenResult.accessToken
          let refreshToken = tokenResult.refreshToken
          let expiresIn = tokenResult.expiresIn
          let profile = await fetchProfile(accessToken)
          let newTokenId = "token_" ++ Float.toString(Date.now())
          let newTokenExpiresAt = Date.now() +. Int.toFloat(expiresIn) *. 1000.0
          let newTokenAccount = switch profile {
          | Some(p) => Some(p.account.email)
          | None => tokenResult.accountEmail->Nullable.toOption
          }
          let newTokenOrganization = tokenResult.orgName->Nullable.toOption
          let newToken: storedToken = {
            id: newTokenId,
            accessToken,
            refreshToken,
            expiresAt: newTokenExpiresAt,
            account: newTokenAccount,
            organization: newTokenOrganization,
            profile,
            createdAt: Date.now(),
            lastUsed: None,
            cachedUsageMetrics: None,
          }
          let tokens = await getTokens(env->sessionKv)
          let updatedTokens = Array.concat(tokens, [newToken])
          await saveTokens(env->sessionKv, updatedTokens)
          let planDisplay = switch profile {
          | Some(p) => p.organization.organizationType
          | None => "Unknown"
          }
          let accountDisplay = switch newTokenAccount {
          | Some(a) => a
          | None => "Unknown Account"
          }
          ctx->html(
            `<!DOCTYPE html>
              <html>
              <head><title>OAuth Success</title></head>
              <body style="font-family: sans-serif; text-align: center; padding: 2rem; background: #0f172a; color: #f1f5f9;">
                <h1 style="color: #22c55e;">\u{2713} \u{C778}\u{C99D} \u{C131}\u{ACF5}!</h1>
                <p>\u{D1A0}\u{D070}\u{C774} \u{CD94}\u{AC00}\u{B418}\u{C5C8}\u{C2B5}\u{B2C8}\u{B2E4}.</p>
                <p style="color: #94a3b8;">` ++
            accountDisplay ++
            `</p>
                <p style="color: #60a5fa; font-size: 0.875rem;">\u{D50C}\u{B79C}: ` ++
            planDisplay ++
            `</p>
                <script>
                  // Notify parent window about OAuth success
                  if (window.opener) {
                    window.opener.postMessage({ type: 'oauth-success', account: '` ++
            accountDisplay ++
            `', plan: '` ++
            planDisplay ++
            `' }, '*');
                  }
                  setTimeout(() => window.close(), 1500);
                <\/script>
              </body>
              </html>`,
          )
        }
      }
    }
  | Some(errStr) =>
    let fullError = switch errorDescription->Nullable.toOption {
    | None => errStr
    | Some(desc) => errStr ++ ": " ++ desc
    }
    ctx->html(errorHtml(`\u{C624}\u{B958}: ` ++ fullError, ~debug=`URL: ` ++ url))
  }
}

let handleListTokens = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  try {
    let tokens = await getTokens(env->sessionKv)
    let now = Date.now()
    let safeTokens = tokens->Array.map(t => {
      let profileField = switch t.profile {
      | Some(p) =>
        Some({
          "email": p.account.email,
          "displayName": p.account.displayName,
          "plan": p.organization.organizationType,
          "rateLimitTier": p.organization.rateLimitTier,
          "hasExtraUsage": p.organization.hasExtraUsageEnabled,
        })
      | None => None
      }
      {
        "id": t.id,
        "account": t.account->Option.getOr("Unknown"),
        "organization": t.organization->Option.getOr("Unknown"),
        "profile": profileField,
        "expiresAt": t.expiresAt,
        "createdAt": t.createdAt,
        "lastUsed": t.lastUsed,
        "isActive": t.expiresAt > now,
        "cachedUsageMetrics": t.cachedUsageMetrics,
      }
    })
    ctx->Hono.json({
      "success": true,
      "tokens": safeTokens,
      "total": Array.length(tokens),
      "active": tokens->Array.filter(t => t.expiresAt > now)->Array.length,
    })
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to list tokens"}, 500)
  }
}

type manualTokenBody = {
  accessToken: option<string>,
  refreshToken: string,
  expiresIn: option<int>,
  bodyAccount: string,
  bodyOrg: string,
}

let parseManualTokenBody: honoReq => promise<manualTokenBody> = %raw(`async function(req) {
  const body = await req.json();
  return {
    accessToken: body.access_token || void 0,
    refreshToken: body.refresh_token || "",
    expiresIn: body.expires_in || void 0,
    bodyAccount: body.account?.email_address || "Manual Token",
    bodyOrg: body.organization?.name || body.organization?.uuid || "manual"
  };
}`)

let handleAddManualToken = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let parsed = await parseManualTokenBody(ctx->honoReq)
  try {
    switch (parsed.accessToken, parsed.expiresIn) {
    | (None, _) =>
      ctx->Hono.jsonWithStatus({"success": false, "error": "access_token is required"}, 400)
    | (_, None) =>
      ctx->Hono.jsonWithStatus(
        {"success": false, "error": "expires_in is required (seconds)"},
        400,
      )
    | (Some(accessToken), Some(expiresIn)) =>
      let profile = await fetchProfile(accessToken)
      let newTokenId = "token_" ++ Float.toString(Date.now())
      let newTokenExpiresAt = Date.now() +. Int.toFloat(expiresIn) *. 1000.0
      let newTokenAccount = switch profile {
      | Some(p) => Some(p.account.email)
      | None => Some(parsed.bodyAccount)
      }
      let newTokenOrganization = switch profile {
      | Some(p) => Some(p.organization.organizationType)
      | None => Some(parsed.bodyOrg)
      }
      let newToken: storedToken = {
        id: newTokenId,
        accessToken,
        refreshToken: parsed.refreshToken,
        expiresAt: newTokenExpiresAt,
        account: newTokenAccount,
        organization: newTokenOrganization,
        profile,
        createdAt: Date.now(),
        lastUsed: None,
        cachedUsageMetrics: None,
      }
      let tokens = await getTokens(env->sessionKv)
      let existingIdx = tokens->Array.findIndex(t => t.account == newTokenAccount)
      let updatedTokens = if existingIdx >= 0 {
        tokens->Array.mapWithIndex((t, i) => i === existingIdx ? newToken : t)
      } else {
        Array.concat(tokens, [newToken])
      }
      await saveTokens(env->sessionKv, updatedTokens)
      ctx->Hono.json({
        "success": true,
        "token": {
          "id": newTokenId,
          "account": newTokenAccount,
          "expiresAt": newTokenExpiresAt,
          "hasProfile": Option.isSome(profile),
        },
      })
    }
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to add token"}, 500)
  }
}

let handleDeleteToken = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let tokenId = (ctx->honoReq)->reqParam("tokenId")
  try {
    let tokens = await getTokens(env->sessionKv)
    let filteredTokens = tokens->Array.filter(t => t.id !== tokenId)
    if Array.length(filteredTokens) === Array.length(tokens) {
      ctx->Hono.jsonWithStatus({"success": false, "error": "Token not found"}, 404)
    } else {
      await saveTokens(env->sessionKv, filteredTokens)
      ctx->Hono.json({"success": true})
    }
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to delete token"}, 500)
  }
}

let handleGetUsage = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let tokenId = (ctx->honoReq)->reqParam("tokenId")
  let forceRefresh =
    ((ctx->honoReq)->reqQuery("refresh"))
    ->Nullable.toOption
    ->Option.mapOr(false, v => v === "true")
  try {
    let tokens = await getTokens(env->sessionKv)
    let tokenIdx = tokens->Array.findIndex(t => t.id === tokenId)
    if tokenIdx < 0 {
      ctx->Hono.jsonWithStatus({"success": false, "error": "Token not found"}, 404)
    } else {
      let token = tokens->Array.getUnsafe(tokenIdx)
      let profileInfo = switch token.profile {
      | Some(p) =>
        Some({
          "email": p.account.email,
          "displayName": p.account.displayName,
          "plan": p.organization.organizationType,
          "rateLimitTier": p.organization.rateLimitTier,
          "hasExtraUsage": p.organization.hasExtraUsageEnabled,
        })
      | None => None
      }
      let cacheTtl = 5.0 *. 60.0 *. 1000.0
      let isCacheFresh = switch token.cachedUsageMetrics {
      | Some(cached) =>
        let extractedTime = Date.fromString(cached.extractedAt)->Date.getTime
        Date.now() -. extractedTime < cacheTtl
      | None => false
      }
      if isCacheFresh && !forceRefresh {
        let cached = token.cachedUsageMetrics->Option.getExn
        ctx->Hono.json({
          "success": true,
          "metrics": {
            "currentSession": cached.currentSession,
            "currentWeekAll": cached.currentWeekAll,
            "currentWeekSonnet": cached.currentWeekSonnet,
          },
          "profile": profileInfo,
          "source": "cache",
          "fetchedAt": cached.extractedAt,
        })
      } else {
        let metrics = await fetchUsageMetrics(token.accessToken)
        switch metrics {
        | Some(metrics) =>
          let now = Date.make()->Date.toISOString
          let updatedToken: storedToken = {
            ...token,
            cachedUsageMetrics: Some({
              currentSession: metrics.currentSession,
              currentWeekAll: metrics.currentWeekAll,
              currentWeekSonnet: metrics.currentWeekSonnet,
              extractedAt: now,
            }),
          }
          let updatedTokens = tokens->Array.mapWithIndex((t, i) =>
            i === tokenIdx ? updatedToken : t
          )
          await saveTokens(env->sessionKv, updatedTokens)
          ctx->Hono.json({
            "success": true,
            "metrics": metrics,
            "profile": profileInfo,
            "source": "api",
            "fetchedAt": now,
          })
        | None =>
          switch token.cachedUsageMetrics {
          | Some(cached) =>
            ctx->Hono.json({
              "success": true,
              "metrics": {
                "currentSession": cached.currentSession,
                "currentWeekAll": cached.currentWeekAll,
                "currentWeekSonnet": cached.currentWeekSonnet,
              },
              "profile": profileInfo,
              "source": "stale_cache",
              "fetchedAt": cached.extractedAt,
            })
          | None =>
            ctx->Hono.json({
              "success": true,
              "metrics": Nullable.null,
              "profile": profileInfo,
              "source": "none",
              "fetchedAt": Date.make()->Date.toISOString,
              "error": "Failed to fetch usage metrics",
            })
          }
        }
      }
    }
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to get usage"}, 500)
  }
}

let handleRefreshProfile = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  let tokenId = (ctx->honoReq)->reqParam("tokenId")
  try {
    let tokens = await getTokens(env->sessionKv)
    let tokenIdx = tokens->Array.findIndex(t => t.id === tokenId)
    if tokenIdx < 0 {
      ctx->Hono.jsonWithStatus({"success": false, "error": "Token not found"}, 404)
    } else {
      let token = tokens->Array.getUnsafe(tokenIdx)
      let profile = await fetchProfile(token.accessToken)
      switch profile {
      | None =>
        ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to fetch profile"}, 500)
      | Some(profile) =>
        let updatedToken: storedToken = {
          ...token,
          account: Some(profile.account.email),
          profile: Some(profile),
        }
        let updatedTokens = tokens->Array.mapWithIndex((t, i) =>
          i === tokenIdx ? updatedToken : t
        )
        await saveTokens(env->sessionKv, updatedTokens)
        ctx->Hono.json({
          "success": true,
          "profile": {
            "email": profile.account.email,
            "displayName": profile.account.displayName,
            "plan": profile.organization.organizationType,
            "rateLimitTier": profile.organization.rateLimitTier,
            "hasExtraUsage": profile.organization.hasExtraUsageEnabled,
          },
        })
      }
    }
  } catch {
  | _ => ctx->Hono.jsonWithStatus({"success": false, "error": "Failed to refresh profile"}, 500)
  }
}

// ---------------------------------------------------------------------------
// Register routes onto the shared Hono app.

let register = (app: Hono.t<env>): Hono.t<env> => {
  app
  ->Hono.get("/api/status", handleStatus)
  ->Hono.get("/api/auth/start", handleStart)
  ->Hono.get("/callback", handleCallback)
  ->Hono.get("/api/tokens", handleListTokens)
  ->Hono.post("/api/tokens/manual", handleAddManualToken)
  ->Hono.delete("/api/tokens/:tokenId", handleDeleteToken)
  ->Hono.get("/api/usage/:tokenId", handleGetUsage)
  ->Hono.post("/api/tokens/:tokenId/refresh-profile", handleRefreshProfile)
}
