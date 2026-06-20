// Chat panel: streams from /api/chat (SSE), renders messages, persists history
// per session, and applies the generated wyreframe back to the editor.

// ---------------------------------------------------------------------------
// Domain types.
// ---------------------------------------------------------------------------
type chatMessage = {
  id: string,
  role: string, // "user" | "assistant"
  content: string,
  timestamp: float,
  isStreaming: bool,
}

type historyEntry = {
  role: string,
  content: string,
  timestamp: float,
}

type sseEvent = {
  eventType: string, // "Chunk" | "Complete" | "Error"
  content: string,
}

type sendRequest = {
  sessionId: string,
  message: string,
  currentAscii: string,
  chatHistory: array<historyEntry>,
}

// ---------------------------------------------------------------------------
// Helpers (translated from the bundle).
// ---------------------------------------------------------------------------
let generateMessageId = (): string =>
  "msg-" ++ Float.toString(Date.now()) ++ "-" ++ Float.toString(Math.random())

let formatTimestamp = (ts: float): string => {
  let d = Date.fromTime(ts)
  let h = Date.getHours(d)->Int.toString->String.padStart(2, "0")
  let m = Date.getMinutes(d)->Int.toString->String.padStart(2, "0")
  h ++ ":" ++ m
}

// Pull a fenced ```wyreframe code block out of the assistant response.
let extractWireframeCode: string => option<string> = %raw(`function(text) {
  var re = /\x60\x60\x60(?:wyreframe)?\s*\n([\s\S]*?)\n\x60\x60\x60/;
  var m = text.match(re);
  if (m == null) return undefined;
  var trimmed = m[1].trim();
  return trimmed === "" ? undefined : trimmed;
}`)

// fixOnly normalises wyreframe markup; the parser lives in the parent library.
let fixOnly: string => string = %raw(`function(content) {
  try {
    if (typeof window !== "undefined" && window.__wyreframe_fixOnly) {
      return window.__wyreframe_fixOnly(content);
    }
    return content;
  } catch (e) {
    console.warn("[WyreframeParser] fixOnly failed, returning original content");
    return content;
  }
}`)

let scrollToBottom: Dom.element => unit = %raw(`function(el) { el.scrollTop = el.scrollHeight; }`)

// SSE streaming against POST /api/chat. Retries (max 3) on non-rate-limit errors.
let sendMessageWithRetry: (
  sendRequest,
  sseEvent => unit,
  unit => unit,
  string => unit,
) => promise<unit> = %raw(`function(req, onEvent, onComplete, onError) {
  function parseSSEEvent(line) {
    if (!line.startsWith("data: ")) return undefined;
    var payload = line.slice(6);
    try {
      var obj = JSON.parse(payload);
      if (obj == null || typeof obj !== "object") return undefined;
      var type = obj.type;
      var content = obj.content;
      if (type === undefined || content === undefined) return undefined;
      var t = typeof type === "string" ? type : "";
      var c = typeof content === "string" ? content : "";
      var eventType;
      switch (t) {
        case "complete": eventType = "Complete"; break;
        case "error": eventType = "Error"; break;
        default: eventType = "Chunk";
      }
      return { eventType: eventType, content: c };
    } catch (e) {
      return undefined;
    }
  }

  async function sendMessage(onErr) {
    var url = "/api/chat";
    var body = {
      sessionId: req.sessionId,
      message: req.message,
      currentAscii: req.currentAscii,
      chatHistory: req.chatHistory.map(function(m) {
        return {
          role: m.role === "user" ? "user" : "assistant",
          content: m.content,
          timestamp: m.timestamp
        };
      })
    };
    try {
      var res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
      });
      var status = res.status;
      if (status >= 400) {
        var txt = await res.text();
        if (status !== 429) return onErr("API error: " + txt);
        var retryAfter = res.headers.get("Retry-After");
        if (retryAfter == null) retryAfter = "60";
        return onErr("Rate limit exceeded. Please retry in " + retryAfter + " seconds.");
      }
      var stream = res.body;
      if (stream == null) return onErr("No response body");
      var reader = stream.getReader();
      var decoder = new TextDecoder();
      var buffer = { contents: "" };
      var pump = async function() {
        var r = await reader.read();
        if (r.done) return onComplete();
        if (r.value == null) return await pump();
        var chunk = decoder.decode(r.value, { stream: true });
        buffer.contents = buffer.contents + chunk;
        var lines = buffer.contents.split("\\n\\n");
        if (lines.length > 0) {
          buffer.contents = lines[lines.length - 1];
          lines.slice(0, lines.length - 1).forEach(function(raw) {
            var line = raw.trim();
            if (line === "") return;
            var ev = parseSSEEvent(line);
            if (ev !== undefined) {
              onEvent(ev);
              if (ev.eventType === "Complete") onComplete();
              else if (ev.eventType === "Error") onErr(ev.content);
            }
          });
        }
        return await pump();
      };
      return await pump();
    } catch (e) {
      var msg = (e && e.message) ? e.message : "Unknown network error";
      return onErr("Network error: " + msg);
    }
  }

  var maxAttempts = 3;
  var attempts = { contents: 0 };
  var attempt = async function() {
    attempts.contents = attempts.contents + 1;
    return await sendMessage(function(errMsg) {
      if (attempts.contents < maxAttempts && errMsg.indexOf("Rate limit") === -1) {
        var delay = attempts.contents * 1000;
        setTimeout(function() { attempt(); }, delay);
        return;
      }
      return onError(errMsg);
    });
  };
  return attempt();
}`)

// localStorage helpers.
let storageGet: string => option<string> = %raw(`function(k) {
  var v = window.localStorage.getItem(k);
  return v == null ? undefined : v;
}`)
let storageSet: (string, string) => unit = %raw(`function(k, v) { window.localStorage.setItem(k, v); }`)

let loadHistory = (sessionId: string): option<array<chatMessage>> => {
  let key = "chat-history-" ++ sessionId
  Console.log2("[LLMChat] Loading chat history from:", key)
  switch storageGet(key) {
  | Some(raw) =>
    Console.log2("[LLMChat] Found chat history, length:", String.length(raw))
    switch JSON.parseExn(raw) {
    | json =>
      switch JSON.Decode.array(json) {
      | Some(arr) =>
        Console.log2("[LLMChat] Parsed messages count:", Array.length(arr))
        let msgs = arr->Array.map(item => {
          switch JSON.Decode.object(item) {
          | None => {
              id: generateMessageId(),
              role: "user",
              content: "",
              timestamp: Date.now(),
              isStreaming: false,
            }
          | Some(o) =>
            let str = field => o->Dict.get(field)->Option.flatMap(JSON.Decode.string)
            let id = str("id")->Option.getOr(generateMessageId())
            let role = str("role")->Option.getOr("user")
            let content = str("content")->Option.getOr("")
            let timestamp =
              o->Dict.get("timestamp")->Option.flatMap(JSON.Decode.float)->Option.getOr(Date.now())
            {
              id,
              role: role === "assistant" ? "assistant" : "user",
              content,
              timestamp,
              isStreaming: false,
            }
          }
        })
        Console.log2("[LLMChat] Loaded messages:", Array.length(msgs))
        Some(msgs)
      | None =>
        Console.warn("[LLMChat] Failed to parse chat history as array")
        None
      }
    | exception _ =>
      Console.error("[LLMChat] Error loading chat history")
      None
    }
  | None =>
    Console.log("[LLMChat] No chat history found in localStorage")
    None
  }
}

let saveHistory = (messages: array<chatMessage>, sessionId: string): unit =>
  if Array.length(messages) > 0 {
    try {
      let key = "chat-history-" ++ sessionId
      let serialised =
        messages
        ->Array.map(m =>
          JSON.Encode.object(
            Dict.fromArray([
              ("id", JSON.Encode.string(m.id)),
              ("role", JSON.Encode.string(m.role === "user" ? "user" : "assistant")),
              ("content", JSON.Encode.string(m.content)),
              ("timestamp", JSON.Encode.float(m.timestamp)),
            ]),
          )
        )
        ->JSON.Encode.array
        ->JSON.stringify
      Console.log2("[LLMChat] Saving chat history to:", key)
      Console.log2("[LLMChat] Messages count:", Array.length(messages))
      storageSet(key, serialised)
    } catch {
    | _ => Console.error("[LLMChat] Error saving chat history")
    }
  }

// ---------------------------------------------------------------------------
// Component.
// ---------------------------------------------------------------------------
@react.component
let make = (
  ~onFixPromptConsumed: option<unit => unit>=?,
  ~fixPrompt: option<string>=?,
  ~initialPrompt: option<string>=?,
  ~currentAscii: string,
  ~onWireframeGenerated: string => unit,
  ~sessionId: string,
) => {
  let (messages, setMessages) = React.useState(() => [])
  let (input, setInput) = React.useState(() => "")
  let (isStreaming, setIsStreaming) = React.useState(() => false)
  let (streamingContent, setStreamingContent) = React.useState(() => "")
  let (error, setError) = React.useState(() => None)
  let (lastUserMessage, setLastUserMessage) = React.useState(() => None)
  let (initialPromptHandled, setInitialPromptHandled) = React.useState(() => false)
  let scrollRef = React.useRef(Nullable.null)
  // Holds the latest `send` so deferred effects (initial/fix prompt) can trigger
  // a submit the same way the original DOM `chat-send-button` click did.
  let sendRef = React.useRef(() => ())
  let triggerSend = () => sendRef.current()

  // Auto-scroll on new messages / streaming output.
  React.useEffect2(() => {
    switch scrollRef.current->Nullable.toOption {
    | Some(el) => scrollToBottom(el)
    | None => ()
    }
    None
  }, (messages, streamingContent))

  // Load persisted history when the session changes.
  React.useEffect1(() => {
    switch loadHistory(sessionId) {
    | Some(msgs) => setMessages(_ => msgs)
    | None => ()
    }
    None
  }, [sessionId])

  // Persist history on change.
  React.useEffect2(() => {
    saveHistory(messages, sessionId)
    None
  }, (messages, sessionId))

  let send = async () => {
    if String.trim(input) === "" || isStreaming {
      ()
    } else {
      let userMsg = {
        id: generateMessageId(),
        role: "user",
        content: input,
        timestamp: Date.now(),
        isStreaming: false,
      }
      setMessages(prev => Array.concat(prev, [userMsg]))
      setInput(_ => "")
      setIsStreaming(_ => true)
      setStreamingContent(_ => "")
      setError(_ => None)
      setLastUserMessage(_ => Some(input))

      let history =
        Array.concat(messages, [userMsg])->Array.map(m => {
          role: m.role,
          content: m.content,
          timestamp: m.timestamp,
        })

      await sendMessageWithRetry(
        {
          sessionId,
          message: input,
          currentAscii,
          chatHistory: history,
        },
        ev =>
          switch ev.eventType {
          | "Chunk" => setStreamingContent(prev => prev ++ ev.content)
          | "Complete" =>
            let full = ev.content
            let assistantMsg = {
              id: generateMessageId(),
              role: "assistant",
              content: full,
              timestamp: Date.now(),
              isStreaming: false,
            }
            setMessages(prev => Array.concat(prev, [assistantMsg]))
            let code = switch extractWireframeCode(full) {
            | Some(c) =>
              Console.log("[LLMChat] Extracted wyreframe code from markdown code block")
              c
            | None =>
              Console.log("[LLMChat] No code block found, using full response as wyreframe")
              full
            }
            let fixed = fixOnly(code)
            Console.log2("[LLMChat] Applied fixOnly, original length:", String.length(code))
            Console.log2("[LLMChat] Fixed content length:", String.length(fixed))
            onWireframeGenerated(fixed)
            setIsStreaming(_ => false)
            setStreamingContent(_ => "")
            setLastUserMessage(_ => None)
          | "Error" =>
            setError(_ => Some(ev.content))
            setIsStreaming(_ => false)
            setStreamingContent(_ => "")
          | _ => ()
          },
        () => {
          setIsStreaming(_ => false)
          setStreamingContent(_ => "")
          setLastUserMessage(_ => None)
        },
        msg => {
          setError(_ => Some(msg))
          setIsStreaming(_ => false)
          setStreamingContent(_ => "")
        },
      )
    }
  }

  sendRef.current = () => send()->Promise.done

  // initialPrompt: auto-fill + auto-send once.
  React.useEffect1(() => {
    switch initialPrompt {
    | Some(prompt) if !initialPromptHandled && String.trim(prompt) !== "" =>
      setInitialPromptHandled(_ => true)
      setInput(_ => prompt)
      let _ = setTimeout(() => triggerSend(), 200)
    | _ => ()
    }
    None
  }, [initialPrompt])

  // fixPrompt (from preview issue reporter): fill + send, then notify consumed.
  React.useEffect1(() => {
    switch fixPrompt {
    | Some(prompt) if String.trim(prompt) !== "" && !isStreaming =>
      setInput(_ => prompt)
      switch onFixPromptConsumed {
      | Some(cb) => cb()
      | None => ()
      }
      let _ = setTimeout(() => triggerSend(), 100)
    | _ => ()
    }
    None
  }, [fixPrompt])

  let handleChange = e => {
    let value = ReactEvent.Form.target(e)["value"]
    setInput(_ => value)
  }

  let handleKeyDown = e => {
    if ReactEvent.Keyboard.key(e) === "Enter" && !ReactEvent.Keyboard.shiftKey(e) {
      ReactEvent.Keyboard.preventDefault(e)
      triggerSend()
    }
  }

  let retry = () =>
    switch lastUserMessage {
    | Some(msg) =>
      setInput(_ => msg)
      setError(_ => None)
    | None => ()
    }

  <div className="h-full flex flex-col">
    <div
      ref={ReactDOM.Ref.domRef(scrollRef)}
      className="flex-1 overflow-y-auto p-4 space-y-3 min-h-0">
      {messages
      ->Array.map(m =>
        <div key={m.id} className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <Badge variant={m.role === "user" ? #default : #secondary} className="text-xs">
              {React.string(m.role === "user" ? "You" : "Assistant")}
            </Badge>
            <span className="text-xs text-muted-foreground">
              {React.string(formatTimestamp(m.timestamp))}
            </span>
          </div>
          <Alert
            variant=#default
            className={m.role === "assistant"
              ? "mb-0 border-[hsl(265_90%_65%/0.5)] rounded-lg"
              : "mb-0"}>
            <Alert.Description
              className={m.role === "assistant"
                ? "whitespace-pre overflow-x-auto font-mono text-sm text-[hsl(265_90%_75%)]"
                : "whitespace-pre overflow-x-auto font-mono text-sm"}>
              {React.string(m.content)}
            </Alert.Description>
          </Alert>
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
            {streamingContent === ""
              ? <div
                  className="flex items-center gap-3 p-4 rounded-lg border border-[hsl(265_90%_65%/0.3)] bg-[hsl(265_90%_65%/0.05)]">
                  <div className="flex gap-1">
                    <div
                      className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce [animation-delay:-0.3s]"
                    />
                    <div
                      className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce [animation-delay:-0.15s]"
                    />
                    <div className="w-2 h-2 rounded-full bg-[hsl(265_90%_65%)] animate-bounce" />
                  </div>
                  <span className="text-sm text-[hsl(265_90%_70%)] animate-pulse">
                    {React.string("AI is thinking...")}
                  </span>
                </div>
              : <Alert variant=#default className="border-gradient-animated rounded-lg">
                  <Alert.Description
                    className="whitespace-pre overflow-x-auto font-mono text-sm text-[hsl(265_90%_75%)]">
                    {React.string(streamingContent ++ "▊")}
                  </Alert.Description>
                </Alert>}
          </div>
        : React.null}
      {switch error {
      | Some(msg) =>
        <Alert variant=#destructive>
          <Alert.Title> {React.string("Error")} </Alert.Title>
          <Alert.Description className="mb-2"> {React.string(msg)} </Alert.Description>
          <Button variant=#outline size=#sm onClick={_ => retry()}>
            {React.string("Retry")}
          </Button>
        </Alert>
      | None => React.null
      }}
    </div>
    <div className="border-t border-[hsl(220_20%_95%/0.08)] p-4 flex-shrink-0 glass-strong">
      <div className="flex gap-2">
        <Input
          type_="text"
          className="flex-1"
          placeholder="Ask AI to create or modify wireframes..."
          value={input}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          disabled={isStreaming}
        />
        <Button
          variant=#default
          size=#default
          onClick={_ => triggerSend()}
          disabled={String.trim(input) === "" || isStreaming}>
          {React.string("Send")}
        </Button>
      </div>
    </div>
  </div>
}
