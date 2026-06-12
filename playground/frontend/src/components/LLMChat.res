// Chat panel: streams `/api/chat` SSE frames and hands the final ASCII back to
// the parent on `complete`. Preserves the legacy "AI is thinking..." UI.

// ---------------------------------------------------------------------------
// Stream bindings (Fetch + ReadableStream + TextDecoder).
// The shared Fetch binding only exposes json/text; the SSE flow needs the raw
// body reader so we add minimal externals here.
// ---------------------------------------------------------------------------

type readableStream
type reader
type decoder
type readResult = {done: bool, value: Nullable.t<Uint8Array.t>}

@send external getReader: readableStream => reader = "getReader"
@send external read: reader => promise<readResult> = "read"
@send external cancel: reader => promise<unit> = "cancel"

@new external makeDecoder: unit => decoder = "TextDecoder"
@send external decode: (decoder, Uint8Array.t) => string = "decode"

@get external responseBody: Fetch.response => readableStream = "body"

// ---------------------------------------------------------------------------
// Domain types.
// ---------------------------------------------------------------------------

type role = [#user | #assistant]

type message = {
  id: string,
  role: role,
  content: string,
  timestamp: float,
}

let roleLabel = (r: role): string =>
  switch r {
  | #user => "You"
  | #assistant => "Assistant"
  }

let roleBadgeVariant = (r: role): Badge.variant =>
  switch r {
  | #user => #default
  | #assistant => #secondary
  }

let genId = (): string =>
  Int.toString(Date.now()->Float.toInt) ++ "-" ++ Int.toString(Js.Math.random_int(0, 1000000))

let formatTimestamp = (ts: float): string => {
  let d = Date.fromTime(ts)
  let hh = d->Date.getHours->Int.toString
  let mmRaw = d->Date.getMinutes->Int.toString
  let mm = String.length(mmRaw) === 1 ? "0" ++ mmRaw : mmRaw
  hh ++ ":" ++ mm
}

// Built-in prompt example chips. Click to fill the input.
let examplePrompts = [
  "Build a user profile card with avatar, name, bio, stats, and action buttons",
  "Design a pricing table with 3 tiers: Free, Pro, and Enterprise with feature comparisons",
  "Blog post card layout...",
  "Contact form with validation...",
  "Dashboard with analytics charts...",
  "A modern login page with social auth...",
]

// Parse `data: {...}` SSE lines pulled from the response body.
let parseSSEFrame = (line: string): option<(string, string)> => {
  let trimmed = String.trim(line)
  if !(trimmed->String.startsWith("data:")) {
    None
  } else {
    let payload = String.sliceToEnd(trimmed, ~start=5)->String.trim
    if payload === "" || payload === "[DONE]" {
      None
    } else {
      try {
        let json = JSON.parseExn(payload)
        switch JSON.Decode.object(json) {
        | None => None
        | Some(obj) =>
          let t = obj->Dict.get("type")->Option.flatMap(JSON.Decode.string)
          let c = obj->Dict.get("content")->Option.flatMap(JSON.Decode.string)
          switch (t, c) {
          | (Some(t), Some(c)) => Some((t, c))
          | _ => None
          }
        }
      } catch {
      | _ => None
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Component.
// ---------------------------------------------------------------------------

@react.component
let make = (
  ~sessionId: string,
  ~currentAscii: string,
  ~onAsciiUpdate: string => unit,
  ~disabled: bool=false,
) => {
  let (messages, setMessages) = React.useState(() => [])
  let (input, setInput) = React.useState(() => "")
  let (isStreaming, setIsStreaming) = React.useState(() => false)
  let (streamingText, setStreamingText) = React.useState(() => "")
  let (errorMsg, setErrorMsg) = React.useState(() => None)
  let scrollRef = React.useRef(Nullable.null)

  // Keep latest currentAscii in a ref so the async send loop reads the
  // up-to-date value without re-creating the callback on every keystroke.
  let asciiRef = React.useRef(currentAscii)
  React.useEffect1(() => {
    asciiRef.current = currentAscii
    None
  }, [currentAscii])

  // Auto-scroll to bottom when messages or streamingText changes.
  React.useEffect2(() => {
    switch scrollRef.current->Nullable.toOption {
    | Some(el) =>
      let _ = %raw(`function(e) { e.scrollTop = e.scrollHeight; }`)(el)
    | None => ()
    }
    None
  }, (Array.length(messages), String.length(streamingText)))

  let handleSend = async () => {
    let text = String.trim(input)
    if text === "" || isStreaming || disabled {
      ()
    } else {
      let userMsg = {
        id: genId(),
        role: #user,
        content: text,
        timestamp: Date.now(),
      }
      setMessages(prev => Array.concat(prev, [userMsg]))
      setInput(_ => "")
      setIsStreaming(_ => true)
      setStreamingText(_ => "")
      setErrorMsg(_ => None)

      let body = Dict.make()
      body->Dict.set("message", JSON.Encode.string(text))
      body->Dict.set("sessionId", JSON.Encode.string(sessionId))
      body->Dict.set("currentAscii", JSON.Encode.string(asciiRef.current))

      let init = {
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": JSON.stringify(JSON.Encode.object(body)),
      }

      try {
        let res = await Fetch.fetch(ApiBase.url("/api/chat"), init->Obj.magic)
        if !(Fetch.ok(res)) {
          setErrorMsg(_ => Some(
            "Request failed: " ++ Int.toString(Fetch.status(res)) ++ " " ++ Fetch.statusText(res),
          ))
          setIsStreaming(_ => false)
        } else {
          let reader = res->responseBody->getReader
          let decoder = makeDecoder()
          let buffer = ref("")
          let accumulated = ref("")
          let finalContent = ref(None)
          let errored = ref(None)
          let done = ref(false)
          while !done.contents {
            let chunk = await read(reader)
            if chunk.done {
              done := true
            } else {
              switch chunk.value->Nullable.toOption {
              | None => ()
              | Some(bytes) =>
                let textChunk = decode(decoder, bytes)
                buffer := buffer.contents ++ textChunk
                // SSE frames are separated by blank lines.
                let parts = String.split(buffer.contents, "\n")
                let lastIdx = Array.length(parts) - 1
                let keep = parts[lastIdx]->Option.getOr("")
                buffer := keep
                let _ =
                  parts
                  ->Array.slice(~start=0, ~end=lastIdx)
                  ->Array.forEach(line => {
                    switch parseSSEFrame(line) {
                    | None => ()
                    | Some(("chunk", c)) =>
                      accumulated := accumulated.contents ++ c
                      let snapshot = accumulated.contents
                      setStreamingText(_ => snapshot)
                    | Some(("complete", c)) => finalContent := Some(c)
                    | Some(("error", c)) => errored := Some(c)
                    | Some(_) => ()
                    }
                  })
              }
            }
          }
          switch errored.contents {
          | Some(msg) =>
            setErrorMsg(_ => Some(msg))
            setIsStreaming(_ => false)
            setStreamingText(_ => "")
          | None =>
            let finalText = switch finalContent.contents {
            | Some(c) => c
            | None => accumulated.contents
            }
            let assistantMsg = {
              id: genId(),
              role: #assistant,
              content: finalText,
              timestamp: Date.now(),
            }
            setMessages(prev => Array.concat(prev, [assistantMsg]))
            setStreamingText(_ => "")
            setIsStreaming(_ => false)
            if finalText !== "" {
              onAsciiUpdate(finalText)
            }
          }
        }
      } catch {
      | Exn.Error(e) =>
        let m = Exn.message(e)->Option.getOr("Network error")
        setErrorMsg(_ => Some(m))
        setIsStreaming(_ => false)
        setStreamingText(_ => "")
      | _ =>
        setErrorMsg(_ => Some("Network error"))
        setIsStreaming(_ => false)
        setStreamingText(_ => "")
      }
    }
  }

  let onInputChange = (e: ReactEvent.Form.t) => {
    let v = (e->ReactEvent.Form.target)["value"]
    setInput(_ => v)
  }

  let onInputKeyDown = (e: ReactEvent.Keyboard.t) => {
    if ReactEvent.Keyboard.key(e) === "Enter" && !ReactEvent.Keyboard.shiftKey(e) {
      ReactEvent.Keyboard.preventDefault(e)
      let _ = handleSend()
    }
  }

  let onSendClick = _ => {
    let _ = handleSend()
  }

  let onChipClick = (prompt: string) => {
    setInput(_ => prompt)
  }

  let canSend = String.trim(input) !== "" && !isStreaming && !disabled
  let showEmptyState = Array.length(messages) === 0 && !isStreaming

  <div className="h-full flex flex-col">
    // Scroll region
    <div
      ref={ReactDOM.Ref.domRef(scrollRef)}
      className="flex-1 overflow-y-auto p-4 space-y-3 min-h-0">
      {showEmptyState
        ? <div className="flex flex-col gap-3 text-sm text-muted-foreground">
            <p>
              {React.string("Describe your UI idea and watch it come to life with ")}
              <span className="font-semibold text-[hsl(265_90%_70%)]">
                {React.string("wyreframe")}
              </span>
            </p>
            <div className="flex flex-wrap gap-2">
              {examplePrompts
              ->Array.map(p =>
                <button
                  key={p}
                  type_="button"
                  onClick={_ => onChipClick(p)}
                  className="text-left text-xs rounded-md border border-[hsl(220_20%_95%/0.12)] bg-[hsl(220_20%_95%/0.03)] hover:bg-[hsl(265_90%_65%/0.08)] hover:border-[hsl(265_90%_65%/0.4)] px-3 py-2 transition-colors">
                  {React.string(p)}
                </button>
              )
              ->React.array}
            </div>
          </div>
        : React.null}
      {messages
      ->Array.map(m =>
        <div key={m.id} className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <Badge variant={roleBadgeVariant(m.role)} className="text-xs">
              {React.string(roleLabel(m.role))}
            </Badge>
            <span className="text-xs text-muted-foreground">
              {React.string(formatTimestamp(m.timestamp))}
            </span>
          </div>
          <div
            className={Cn.cn([
              "rounded-lg border p-3",
              m.role === #assistant
                ? "border-[hsl(265_90%_65%/0.5)]"
                : "border-[hsl(220_20%_95%/0.1)]",
            ])}>
            <pre
              className={Cn.cn([
                "whitespace-pre overflow-x-auto font-mono text-sm",
                m.role === #assistant ? "text-[hsl(265_90%_75%)]" : "",
              ])}>
              {React.string(m.content)}
            </pre>
          </div>
        </div>
      )
      ->React.array}
      {isStreaming
        ? <div className="flex flex-col gap-1">
            <div className="flex items-center gap-2">
              <Badge variant=#secondary className="text-xs animate-pulse">
                {React.string("Assistant")}
              </Badge>
              <span className="text-xs text-muted-foreground">
                {React.string(formatTimestamp(Date.now()))}
              </span>
            </div>
            {streamingText === ""
              ? <div
                  className="flex items-center gap-3 p-4 rounded-lg border border-[hsl(265_90%_65%/0.3)] bg-[hsl(265_90%_65%/0.05)]">
                  <div className="flex gap-1">
                    <div
                      className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce [animation-delay:-0.3s]"
                    />
                    <div
                      className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce [animation-delay:-0.15s]"
                    />
                    <div
                      className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce"
                    />
                  </div>
                  <span className="text-sm text-[hsl(265_90%_70%)] animate-pulse">
                    {React.string("AI is thinking...")}
                  </span>
                </div>
              : <div
                  className="rounded-lg border border-[hsl(265_90%_65%/0.5)] p-3">
                  <pre
                    className="whitespace-pre overflow-x-auto font-mono text-sm text-[hsl(265_90%_75%)]">
                    {React.string(streamingText ++ "▊")}
                  </pre>
                </div>}
          </div>
        : React.null}
      {switch errorMsg {
      | None => React.null
      | Some(msg) =>
        <div
          className="rounded-lg border border-destructive bg-destructive/10 p-3 text-sm text-destructive">
          <div className="font-semibold mb-1"> {React.string("Error")} </div>
          <div className="mb-2"> {React.string(msg)} </div>
          <Button
            variant=#outline
            size=#sm
            onClick={_ => {
              setErrorMsg(_ => None)
              setInput(_ => String.trim(input))
            }}>
            {React.string("Dismiss")}
          </Button>
        </div>
      }}
    </div>
    // Composer
    <div
      className="border-t border-[hsl(220_20%_95%/0.08)] p-4 flex-shrink-0 glass-strong">
      <div className="flex gap-2">
        <Input
          type_="text"
          className="flex-1"
          placeholder="Ask AI to create or modify wireframes..."
          value={input}
          onChange={onInputChange}
          onKeyDown={onInputKeyDown}
          disabled={isStreaming || disabled}
          id="chat-send-input"
        />
        <Button
          variant=#default
          size=#default
          onClick={onSendClick}
          disabled={!canSend}>
          {React.string("Send")}
        </Button>
      </div>
    </div>
  </div>
}
