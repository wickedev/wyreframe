// ReScript bindings to Langfuse for LLM-call observability.
// Talks to env.langfuseBaseURL (https://langfuse.protopie.works in prod).
// Surface: createTrace / updateTrace / createGeneration / updateGeneration,
// driven by the public/secret keys + base URL pulled off the worker env.

open RescriptCore
open Types

type client = {
  publicKey: string,
  secretKey: string,
  baseUrl: string,
}

type usage = {
  input: option<int>,
  output: option<int>,
  total: option<int>,
}

let makeClient = (publicKey, secretKey, ~baseUrl=?) => {
  let baseUrl = switch baseUrl {
  | Some(b) => b
  | None => "https://cloud.langfuse.com"
  }
  {
    publicKey,
    secretKey,
    baseUrl,
  }
}

let makeClientFromEnv = (env: env) => {
  Console.log("[Langfuse] Checking environment variables...")
  Console.log2("[Langfuse] publicKey present:", Option.isSome(env.langfusePublicKey))
  Console.log2("[Langfuse] secretKey present:", Option.isSome(env.langfuseSecretKey))
  Console.log2("[Langfuse] baseUrl:", env.langfuseBaseURL)
  switch (env.langfusePublicKey, env.langfuseSecretKey) {
  | (Some(pk), Some(sk)) =>
    switch env.langfuseBaseURL {
    | Some(baseUrl) =>
      Console.log2("[Langfuse] Creating client with baseUrl:", baseUrl)
      Some(makeClient(pk, sk, ~baseUrl))
    | None =>
      Console.log("[Langfuse] Creating client with default baseUrl")
      Some(makeClient(pk, sk))
    }
  | _ =>
    Console.warn("[Langfuse] Missing required environment variables - Langfuse disabled")
    None
  }
}

let doFetch: (client, string, Dict.t<JSON.t>) => promise<JSON.t> = %raw(`async function(_client, _path, _body) {
  const url = _client.baseUrl + _path;
  const credentials = _client.publicKey + ":" + _client.secretKey;
  const authHeader = "Basic " + btoa(credentials);
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": authHeader,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(_body)
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error("Langfuse API error " + res.status + ": " + text);
  }
  return res.json();
}`)

let makeRequest = async (client, path, body): result<JSON.t, string> => {
  try {
    let result = await doFetch(client, path, body)
    Ok(result)
  } catch {
  | exn =>
    let errorMsg = Exn.asJsExn(exn)->Option.getExn->Exn.message->Option.getOr("")
    Console.error2("[Langfuse] Request failed:", errorMsg)
    Error(errorMsg)
  }
}

@val external generateUUID: unit => string = "crypto.randomUUID"

let createTrace = async (
  client,
  ~id=?,
  ~name=?,
  ~sessionId=?,
  ~userId=?,
  ~input=?,
  ~output=?,
  ~metadata=?,
  ~tags=?,
  ~timestamp=?,
) => {
  let traceId = id->Option.getOr(generateUUID())
  let body = Dict.make()
  body->Dict.set("id", JSON.Encode.string(traceId))
  name->Option.forEach(n => body->Dict.set("name", JSON.Encode.string(n)))
  sessionId->Option.forEach(s => body->Dict.set("sessionId", JSON.Encode.string(s)))
  userId->Option.forEach(u => body->Dict.set("userId", JSON.Encode.string(u)))
  input->Option.forEach(i => body->Dict.set("input", i))
  output->Option.forEach(o => body->Dict.set("output", o))
  metadata->Option.forEach(m => body->Dict.set("metadata", m))
  tags->Option.forEach(t =>
    body->Dict.set("tags", JSON.Encode.array(t->Array.map(JSON.Encode.string)))
  )
  timestamp->Option.forEach(t =>
    body->Dict.set("timestamp", JSON.Encode.string(t->Date.toISOString))
  )
  Console.log2("[Langfuse] Creating trace:", traceId)
  let result = await makeRequest(client, "/api/public/traces", body)
  switch result {
  | Error(e) => Error(e)
  | Ok(_) =>
    Console.log2("[Langfuse] Trace created:", traceId)
    Ok(traceId)
  }
}

let updateTrace = async (
  client,
  traceId,
  ~name=?,
  ~sessionId=?,
  ~userId=?,
  ~input=?,
  ~output=?,
  ~metadata=?,
  ~tags=?,
) => {
  let body = Dict.make()
  body->Dict.set("id", JSON.Encode.string(traceId))
  name->Option.forEach(n => body->Dict.set("name", JSON.Encode.string(n)))
  sessionId->Option.forEach(s => body->Dict.set("sessionId", JSON.Encode.string(s)))
  userId->Option.forEach(u => body->Dict.set("userId", JSON.Encode.string(u)))
  input->Option.forEach(i => body->Dict.set("input", i))
  output->Option.forEach(o => {
    Console.log2("[Langfuse] Setting output in trace body:", JSON.stringify(o))
    body->Dict.set("output", o)
  })
  metadata->Option.forEach(m => body->Dict.set("metadata", m))
  tags->Option.forEach(t =>
    body->Dict.set("tags", JSON.Encode.array(t->Array.map(JSON.Encode.string)))
  )
  Console.log2("[Langfuse] Updating trace:", traceId)
  Console.log2("[Langfuse] Update body:", JSON.stringify(body->JSON.Encode.object))
  let result = await makeRequest(client, "/api/public/traces", body)
  switch result {
  | Ok(value) =>
    Console.log2("[Langfuse] Trace updated:", traceId)
    Console.log2("[Langfuse] Update response:", JSON.stringify(value))
    Ok()
  | Error(err) =>
    Console.error2("[Langfuse] Trace update error:", err)
    Error(err)
  }
}

let createGeneration = async (
  client,
  ~traceId,
  ~id=?,
  ~name=?,
  ~model=?,
  ~modelParameters=?,
  ~input=?,
  ~output=?,
  ~usage=?,
  ~metadata=?,
  ~startTime=?,
  ~endTime=?,
  ~completionStartTime=?,
  ~level=?,
  ~statusMessage=?,
) => {
  let generationId = id->Option.getOr(generateUUID())
  let body = Dict.make()
  body->Dict.set("id", JSON.Encode.string(generationId))
  body->Dict.set("traceId", JSON.Encode.string(traceId))
  name->Option.forEach(n => body->Dict.set("name", JSON.Encode.string(n)))
  model->Option.forEach(m => body->Dict.set("model", JSON.Encode.string(m)))
  modelParameters->Option.forEach(mp => body->Dict.set("modelParameters", mp))
  input->Option.forEach(i => body->Dict.set("input", i))
  output->Option.forEach(o => body->Dict.set("output", o))
  metadata->Option.forEach(m => body->Dict.set("metadata", m))
  level->Option.forEach(l => body->Dict.set("level", JSON.Encode.string(l)))
  statusMessage->Option.forEach(sm => body->Dict.set("statusMessage", JSON.Encode.string(sm)))
  startTime->Option.forEach(st =>
    body->Dict.set("startTime", JSON.Encode.string(st->Date.toISOString))
  )
  endTime->Option.forEach(et =>
    body->Dict.set("endTime", JSON.Encode.string(et->Date.toISOString))
  )
  completionStartTime->Option.forEach(cst =>
    body->Dict.set("completionStartTime", JSON.Encode.string(cst->Date.toISOString))
  )
  usage->Option.forEach(u => {
    let usageDict = Dict.make()
    u.input->Option.forEach(i => usageDict->Dict.set("input", JSON.Encode.int(i)))
    u.output->Option.forEach(o => usageDict->Dict.set("output", JSON.Encode.int(o)))
    u.total->Option.forEach(t => usageDict->Dict.set("total", JSON.Encode.int(t)))
    body->Dict.set("usage", usageDict->JSON.Encode.object)
  })
  Console.log4("[Langfuse] Creating generation:", generationId, "for trace:", traceId)
  let result = await makeRequest(client, "/api/public/generations", body)
  switch result {
  | Error(e) => Error(e)
  | Ok(_) =>
    Console.log2("[Langfuse] Generation created:", generationId)
    Ok(generationId)
  }
}

let updateGeneration = async (
  client,
  ~generationId,
  ~traceId,
  ~name=?,
  ~model=?,
  ~output=?,
  ~usage=?,
  ~metadata=?,
  ~endTime=?,
  ~level=?,
  ~statusMessage=?,
) => {
  let body = Dict.make()
  body->Dict.set("id", JSON.Encode.string(generationId))
  body->Dict.set("traceId", JSON.Encode.string(traceId))
  name->Option.forEach(n => body->Dict.set("name", JSON.Encode.string(n)))
  model->Option.forEach(m => body->Dict.set("model", JSON.Encode.string(m)))
  output->Option.forEach(o => body->Dict.set("output", o))
  metadata->Option.forEach(m => body->Dict.set("metadata", m))
  level->Option.forEach(l => body->Dict.set("level", JSON.Encode.string(l)))
  statusMessage->Option.forEach(sm => body->Dict.set("statusMessage", JSON.Encode.string(sm)))
  endTime->Option.forEach(et =>
    body->Dict.set("endTime", JSON.Encode.string(et->Date.toISOString))
  )
  usage->Option.forEach(u => {
    let usageDict = Dict.make()
    u.input->Option.forEach(i => usageDict->Dict.set("input", JSON.Encode.int(i)))
    u.output->Option.forEach(o => usageDict->Dict.set("output", JSON.Encode.int(o)))
    u.total->Option.forEach(t => usageDict->Dict.set("total", JSON.Encode.int(t)))
    body->Dict.set("usage", usageDict->JSON.Encode.object)
  })
  Console.log2("[Langfuse] Updating generation:", generationId)
  let result = await makeRequest(client, "/api/public/generations", body)
  switch result {
  | Error(e) => Error(e)
  | Ok(_) =>
    Console.log2("[Langfuse] Generation updated:", generationId)
    Ok()
  }
}
