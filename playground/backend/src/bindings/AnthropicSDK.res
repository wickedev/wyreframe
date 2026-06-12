// Thin ReScript bindings to `@anthropic-ai/sdk` v0.71 plus a few helpers.

open RescriptCore

module Client = {
  type t

  type config = {
    apiKey: string,
    baseURL: string,
  }

  @module("@anthropic-ai/sdk") @new
  external make: config => t = "default"
}

type message = {
  role: string,
  content: string,
}

type messageOptions = {
  model: string,
  @as("max_tokens") maxTokens: int,
  messages: array<message>,
  system: string,
  temperature: option<float>,
  stream: bool,
}

module Messages = {
  type t

  @get external get: Client.t => t = "messages"

  type stream

  @send external stream: (t, messageOptions) => stream = "stream"
}

type textDelta = {
  @as("type") type_: string,
  text: option<string>,
}

type streamEvent = {
  @as("type") type_: string,
  delta: option<textDelta>,
}

type contentBlock = {
  @as("type") type_: string,
  text: string,
}

type apiMessage = {content: array<contentBlock>}

let userMessage = (content): message => {
  role: "user",
  content,
}

let makeMessageOptions = (
  ~model="claude-sonnet-4-20250514",
  ~maxTokens=4096,
  ~temperature,
  ~system,
  ~stream,
  messages,
): messageOptions => {
  model,
  maxTokens,
  messages,
  system,
  temperature,
  stream,
}

let isTextDelta = (event: streamEvent) =>
  if event.type_ === "content_block_delta" {
    event.delta->Option.mapOr(false, d => d.type_ === "text_delta")
  } else {
    false
  }

let extractDeltaText = (event: streamEvent) =>
  if isTextDelta(event) {
    event.delta->Option.flatMap(d => d.text)
  } else {
    None
  }

let iterateStream: (
  Messages.stream,
  streamEvent => promise<unit>,
  string => promise<unit>,
) => promise<unit> = %raw(`async function(iterator, callback, onError) {
  try {
    for await (const event of iterator) {
      await callback(event);
    }
  } catch (error) {
    const message = error && error.message ? error.message : String(error);
    await onError(message);
  }
}`)

let extractMessageText = (msg: apiMessage) =>
  msg.content
  ->Array.filterMap(block =>
    if block.type_ === "text" {
      Some(block.text)
    } else {
      None
    }
  )
  ->Array.join("")
