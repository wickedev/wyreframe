// /api/issues/report — receives bug/feedback reports, runs them through the
// LLM to format, then opens a GitHub issue against the Wyreframe repository.
//
// Faithful translation of `_recovered/backend/trimmed/routes_Issues.mjs`.
// `expandLineReferences` and `jsonStringifyMinified` are reimplemented in
// ReScript so we never need a `%raw` block containing JS backticks; the
// triple-backtick fences in the LLM prompt and the user prompt are spliced in
// via regular `"\`\`\`"` strings (regular ReScript strings do not treat ``` as
// a terminator, so no escaping gymnastics are needed).

open Types

// ---------------------------------------------------------------------------
// Local Anthropic SDK extras. The shared binding only exposes `Messages.stream`,
// but this route uses the non-streaming `Messages.create` endpoint.

@send
external messagesCreate: (AnthropicSDK.Messages.t, AnthropicSDK.messageOptions) => promise<
  AnthropicSDK.apiMessage,
> = "create"

// ---------------------------------------------------------------------------
// Request shape (mirrors the `.mjs`).

type parseIssue = {
  message: string,
  line: option<int>,
  column: option<int>,
}

type viewport = {
  width: int,
  height: int,
}

type browserInfo = {
  userAgent: string,
  viewport: viewport,
}

type versionInfo = {wyreframe: string}

type issueRequest = {
  userDescription: string,
  asciiContent: string,
  parseWarnings: array<parseIssue>,
  parseError: option<parseIssue>,
  browserInfo: browserInfo,
  versionInfo: versionInfo,
  availableScenes: array<string>,
  selectedScenes: array<string>,
  parsedAst: option<JSON.t>,
}

type validationResult =
  | Valid(issueRequest)
  | Invalid(Types.error)

// ---------------------------------------------------------------------------
// Validation.

let decodeParseIssue = (json: JSON.t): option<parseIssue> => {
  switch Decode.object(json) {
  | None => None
  | Some(obj) =>
    let message = switch obj->Dict.get("message") {
    | Some(v) => Decode.string(v)->Option.getOr("")
    | None => ""
    }
    let line = switch obj->Dict.get("line") {
    | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))
    | None => None
    }
    let column = switch obj->Dict.get("column") {
    | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))
    | None => None
    }
    Some({message, line, column})
  }
}

let decodeViewport = (json: JSON.t): option<viewport> => {
  switch Decode.object(json) {
  | None => None
  | Some(obj) =>
    let width = switch obj->Dict.get("width") {
    | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))->Option.getOr(0)
    | None => 0
    }
    let height = switch obj->Dict.get("height") {
    | Some(v) => Decode.float(v)->Option.map(f => Float.toInt(f))->Option.getOr(0)
    | None => 0
    }
    Some({width, height})
  }
}

let decodeBrowserInfo = (json: JSON.t): option<browserInfo> => {
  switch Decode.object(json) {
  | None => None
  | Some(obj) =>
    let userAgent = switch obj->Dict.get("userAgent") {
    | Some(v) => Decode.string(v)->Option.getOr("")
    | None => ""
    }
    let viewport = switch obj->Dict.get("viewport") {
    | Some(v) => decodeViewport(v)
    | None => None
    }
    switch viewport {
    | Some(vp) => Some({userAgent, viewport: vp})
    | None => None
    }
  }
}

let decodeVersionInfo = (json: JSON.t): option<versionInfo> => {
  switch Decode.object(json) {
  | None => None
  | Some(obj) =>
    let wyreframe = switch obj->Dict.get("wyreframe") {
    | Some(v) => Decode.string(v)->Option.getOr("unknown")
    | None => "unknown"
    }
    Some({wyreframe: wyreframe})
  }
}

let validateRequest = (json: JSON.t): validationResult => {
  switch Decode.object(json) {
  | None => Invalid(ErrorHandler.validationError("body", "Request body must be a JSON object"))
  | Some(obj) =>
    let userDescription = switch obj->Dict.get("userDescription") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let asciiContent = switch obj->Dict.get("asciiContent") {
    | Some(v) => Decode.string(v)
    | None => None
    }
    let parseWarnings = switch obj->Dict.get("parseWarnings") {
    | Some(v) =>
      switch Decode.array(v) {
      | Some(arr) => arr->Array.filterMap(decodeParseIssue)
      | None => []
      }
    | None => []
    }
    let parseError = switch obj->Dict.get("parseError") {
    | Some(v) =>
      if Decode.null_(v) {
        None
      } else {
        decodeParseIssue(v)
      }
    | None => None
    }
    let browserInfo = switch obj->Dict.get("browserInfo") {
    | Some(v) => decodeBrowserInfo(v)
    | None => None
    }
    let availableScenes = switch obj->Dict.get("availableScenes") {
    | Some(v) =>
      switch Decode.array(v) {
      | Some(arr) => arr->Array.filterMap(Decode.string)
      | None => []
      }
    | None => []
    }
    let selectedScenes = switch obj->Dict.get("selectedScenes") {
    | Some(v) =>
      switch Decode.array(v) {
      | Some(arr) => arr->Array.filterMap(Decode.string)
      | None => []
      }
    | None => []
    }
    let parsedAst = switch obj->Dict.get("parsedAst") {
    | Some(v) =>
      if Decode.null_(v) {
        None
      } else {
        Some(v)
      }
    | None => None
    }
    let versionInfo = switch obj->Dict.get("versionInfo") {
    | Some(v) => decodeVersionInfo(v)
    | None => None
    }
    switch userDescription {
    | None => Invalid(ErrorHandler.validationError("userDescription", "Description is required"))
    | Some("") =>
      Invalid(ErrorHandler.validationError("userDescription", "Description cannot be empty"))
    | Some(userDescription) if String.length(userDescription) > 2000 =>
      Invalid(
        ErrorHandler.validationError(
          "userDescription",
          "Description exceeds maximum length of 2000 characters",
        ),
      )
    | Some(userDescription) =>
      switch asciiContent {
      | None => Invalid(ErrorHandler.validationError("asciiContent", "ASCII content is required"))
      | Some(asciiContent) if String.length(asciiContent) > 100000 =>
        Invalid(
          ErrorHandler.validationError(
            "asciiContent",
            "ASCII content exceeds maximum length of 100000 characters",
          ),
        )
      | Some(asciiContent) =>
        switch browserInfo {
        | None => Invalid(ErrorHandler.validationError("browserInfo", "Browser info is required"))
        | Some(browserInfo) =>
          switch versionInfo {
          | None => Invalid(ErrorHandler.validationError("versionInfo", "Version info is required"))
          | Some(versionInfo) =>
            Valid({
              userDescription,
              asciiContent,
              parseWarnings,
              parseError,
              browserInfo,
              versionInfo,
              availableScenes,
              selectedScenes,
              parsedAst,
            })
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// LLM prompt. Triple-backtick fences are spliced via regular `"\`\`\`"`
// strings — inside a `"..."` ReScript string, backticks are literal.

let tripleBacktick = "```"

let llmSystemPrompt =
  `You are a helpful assistant that converts user bug reports into well-structured
GitHub issues for the Wyreframe project.

Wyreframe is an ASCII wireframe to UI renderer. Users write ASCII art wireframes
and the library renders them as interactive HTML/UI components. Wireframes can contain
multiple scenes with transitions.

**IMPORTANT: Language Handling**
- The user may write their report in any language (Korean, Japanese, Chinese, etc.)
- You MUST translate ALL user-provided content to English in the final GitHub issue
- The title and body must be written in clear, professional English
- Preserve the original meaning and technical details while translating

Given:
- User's description of the issue (may be in any language)
- ASCII wireframe content
- Scene information (affected scenes, if specified)
- Parse warnings/errors (if any)
- Parsed AST (JSON structure of the parsed wireframe)
- Version information (wyreframe library version)
- Browser information

**OUTPUT FORMAT (MUST follow exactly):**

TITLE: [Prefix] Concise title (max 80 chars)
LABELS: label1, label2
BODY:
## Summary
Brief description of the issue

## Steps to Reproduce
How to reproduce the issue

## Expected Behavior
What the user expected

## Actual Behavior
What actually happened

## Wireframe Content
` ++
  tripleBacktick ++
  `
ASCII content here
` ++
  tripleBacktick ++
  `

## Affected Scenes
Scene information if applicable

## Parse Information
Warnings or errors if any

## Parsed AST
` ++
  tripleBacktick ++
  `json
Include the full parsed AST JSON here (copy as-is from input, do not truncate)
` ++
  tripleBacktick ++
  `

## Environment
Wyreframe version, browser, and viewport info

**Prefix options:**
- [Parser] for parsing issues
- [Renderer] for rendering issues
- [UI] for visual/layout issues

**Label options:** bug, parser, renderer, documentation, enhancement`

// ---------------------------------------------------------------------------
// Helpers.

let jsonStringifyMinified = (json: JSON.t): string => JSON.stringify(json)

// `expandLineReferences` — replaces `@L<n>-<m>` with the code range fenced
// in triple-backticks, and `@L<n>` with a single inline-coded line. Mirrors
// the JS implementation but stays in pure ReScript so we don't have to embed
// JS template-literals (which contain backticks) in a `%raw` block.
let expandLineReferences = (description: string, asciiContent: string): string => {
  let lines = String.split(asciiContent, "\n")
  let lineCount = Array.length(lines)

  let rangeRe = RegExp.fromStringWithFlags("@L(\\d+)-(\\d+)", ~flags="g")
  let withRanges = description->String.unsafeReplaceRegExpBy2(rangeRe, (
    ~match as m,
    ~group1 as startStr,
    ~group2 as endStr,
    ~offset as _,
    ~input as _,
  ) => {
    let startLine = Int.fromString(startStr)->Option.getOr(0)
    let endLine = Int.fromString(endStr)->Option.getOr(0)
    if startLine >= 1 && endLine >= startLine && endLine <= lineCount {
      let rangeLines = []
      for i in startLine to endLine {
        let lineContent = Array.getUnsafe(lines, i - 1)
        if String.length(String.trim(lineContent)) > 0 {
          Array.push(rangeLines, lineContent)
        }
      }
      if Array.length(rangeLines) > 0 {
        tripleBacktick ++
        "\n" ++
        Array.join(rangeLines, "\n") ++
        "\n" ++
        tripleBacktick ++
        " (lines " ++
        Int.toString(startLine) ++
        "-" ++
        Int.toString(endLine) ++
        ")"
      } else {
        "(empty lines " ++ Int.toString(startLine) ++ "-" ++ Int.toString(endLine) ++ ")"
      }
    } else {
      m
    }
  })

  let singleRe = RegExp.fromStringWithFlags("@L(\\d+)", ~flags="g")
  withRanges->String.unsafeReplaceRegExpBy1(singleRe, (
    ~match as m,
    ~group1 as numStr,
    ~offset as _,
    ~input as _,
  ) => {
    let lineNum = Int.fromString(numStr)->Option.getOr(0)
    if lineNum >= 1 && lineNum <= lineCount {
      let lineContent = String.trim(Array.getUnsafe(lines, lineNum - 1))
      if String.length(lineContent) > 0 {
        "`" ++ lineContent ++ "` (line " ++ Int.toString(lineNum) ++ ")"
      } else {
        "(empty line " ++ Int.toString(lineNum) ++ ")"
      }
    } else {
      m
    }
  })
}

let formatLoc = (line: option<int>, column: option<int>): string => {
  switch (line, column) {
  | (Some(l), Some(c)) => " (line " ++ Int.toString(l) ++ ", column " ++ Int.toString(c) ++ ")"
  | (Some(l), None) => " (line " ++ Int.toString(l) ++ ")"
  | _ => ""
  }
}

let buildUserPrompt = (request: issueRequest): string => {
  let warningsStr = if Array.length(request.parseWarnings) > 0 {
    request.parseWarnings
    ->Array.map(w => "- " ++ w.message ++ formatLoc(w.line, w.column))
    ->Array.join("\n")
  } else {
    "None"
  }
  let errorStr = switch request.parseError {
  | Some(e) => e.message ++ formatLoc(e.line, e.column)
  | None => "None"
  }
  let scenesStr = if Array.length(request.selectedScenes) > 0 {
    "Affected Scenes: " ++ Array.join(request.selectedScenes, ", ")
  } else if Array.length(request.availableScenes) > 0 {
    "Available Scenes: " ++
    Array.join(request.availableScenes, ", ") ++
    " (user did not select specific scenes)"
  } else {
    "Scenes: Not specified"
  }
  let expandedDescription = expandLineReferences(request.userDescription, request.asciiContent)
  let parsedAstStr = switch request.parsedAst {
  | Some(ast) => jsonStringifyMinified(ast)
  | None => "Not available"
  }
  `User Description:
` ++
  expandedDescription ++
  `

ASCII Wireframe Content:
` ++
  tripleBacktick ++
  `
` ++
  request.asciiContent ++
  `
` ++
  tripleBacktick ++
  `

` ++
  scenesStr ++
  `

Parse Warnings:
` ++
  warningsStr ++
  `

Parse Error: ` ++
  errorStr ++
  `

Parsed AST:
` ++
  tripleBacktick ++
  `json
` ++
  parsedAstStr ++
  `
` ++
  tripleBacktick ++
  `

Wyreframe Version: ` ++
  request.versionInfo.wyreframe ++
  `
Browser: ` ++
  request.browserInfo.userAgent ++
  `
Viewport: ` ++
  Int.toString(request.browserInfo.viewport.width) ++
  `x` ++
  Int.toString(request.browserInfo.viewport.height)
}

// ---------------------------------------------------------------------------
// Parsing LLM response.

type formattedIssue = {
  title: string,
  body: string,
  labels: array<string>,
}

let parseLLMResponse = (text: string): result<formattedIssue, string> => {
  let rawText = String.trim(text)
  let titlePrefix = "TITLE:"
  let labelsPrefix = "LABELS:"
  let bodyPrefix = "BODY:"
  let titleStart = String.indexOf(rawText, titlePrefix)
  let labelsStart = String.indexOf(rawText, labelsPrefix)
  let bodyStart = String.indexOf(rawText, bodyPrefix)
  if titleStart < 0 {
    Error("Missing TITLE in LLM response")
  } else if labelsStart < 0 {
    Error("Missing LABELS in LLM response")
  } else if bodyStart < 0 {
    Error("Missing BODY in LLM response")
  } else {
    let titleValue = String.trim(
      String.slice(rawText, ~start=titleStart + String.length(titlePrefix), ~end=labelsStart),
    )
    let labelsValue = String.trim(
      String.slice(rawText, ~start=labelsStart + String.length(labelsPrefix), ~end=bodyStart),
    )
    let bodyValue = String.trim(
      String.sliceToEnd(rawText, ~start=bodyStart + String.length(bodyPrefix)),
    )
    let labels =
      labelsValue
      ->String.split(",")
      ->Array.map(String.trim)
      ->Array.filter(s => String.length(s) > 0)
    if titleValue === "" || bodyValue === "" {
      Error("LLM returned empty title or body")
    } else {
      Ok({title: titleValue, body: bodyValue, labels})
    }
  }
}

// ---------------------------------------------------------------------------
// LLM call.

let formatWithLLM = async (
  client: AnthropicSDK.Client.t,
  request: issueRequest,
): result<formattedIssue, string> => {
  let messages = [AnthropicSDK.userMessage(buildUserPrompt(request))]
  let messageOptions = AnthropicSDK.makeMessageOptions(
    ~model="claude-sonnet-4-20250514",
    ~maxTokens=8192,
    ~temperature=Some(0.3),
    ~system=llmSystemPrompt,
    ~stream=false,
    messages,
  )
  try {
    let messagesApi = client->AnthropicSDK.Messages.get
    let response = await messagesCreate(messagesApi, messageOptions)
    parseLLMResponse(AnthropicSDK.extractMessageText(response))
  } catch {
  | Exn.Error(err) =>
    let message = Exn.message(err)->Option.getOr("Unknown error")
    Error("LLM query failed: " ++ message)
  | _ => Error("LLM query failed: Unknown error")
  }
}

// ---------------------------------------------------------------------------
// GitHub API call.

type githubIssueResponse = {
  @as("html_url") htmlUrl: string,
  number: int,
}

let fetchGitHubIssue: (
  string,
  string,
  string,
) => promise<result<githubIssueResponse, string>> = %raw(`async function(url, token, body) {
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + token,
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Type": "application/json",
        "User-Agent": "Wyreframe-Playground"
      },
      body
    });
    if (response.ok) {
      const json = await response.json();
      if (json.html_url && json.number) {
        return { TAG: "Ok", _0: { html_url: json.html_url, number: json.number } };
      } else {
        return { TAG: "Error", _0: "GitHub API returned invalid response" };
      }
    } else {
      return { TAG: "Error", _0: "GitHub API error: " + response.status + " " + response.statusText };
    }
  } catch (error3) {
    const message2 = error3 && error3.message ? error3.message : "Unknown error";
    return { TAG: "Error", _0: "GitHub API request failed: " + message2 };
  }
}`)

let createGitHubIssue = async (
  issue: formattedIssue,
  githubToken: string,
): result<githubIssueResponse, string> => {
  let url = "https://api.github.com/repos/wickedev/wyreframe/issues"
  let requestBody = Dict.fromArray([
    ("title", JSON.Encode.string(issue.title)),
    ("body", JSON.Encode.string(issue.body)),
    ("labels", JSON.Encode.array(issue.labels->Array.map(JSON.Encode.string))),
  ])
  let bodyJson = JSON.stringify(JSON.Encode.object(requestBody))
  await fetchGitHubIssue(url, githubToken, bodyJson)
}

// ---------------------------------------------------------------------------
// Anthropic client factory.

let createAnthropicClient = (env: env): AnthropicSDK.Client.t => {
  let apiKey = env.anthropicAPIKey->Option.getOr("")
  let baseURL = env.anthropicBaseURL->Option.getOr("https://api.anthropic.com")
  if apiKey === "" {
    Console.warn("[Issues] ANTHROPIC_API_KEY not set")
  }
  AnthropicSDK.Client.make({apiKey, baseURL})
}

// ---------------------------------------------------------------------------
// POST /api/issues/report handler.

let handleReportIssue = async (ctx: Hono.context<env>): Web.Response.t => {
  let env = ctx->Hono.env
  switch env.githubToken {
  | None =>
    ctx->Hono.jsonWithStatus(
      {
        "success": false,
        "error": "GitHub integration not configured",
      },
      500,
    )
  | Some(githubToken) =>
    let bodyResult = try {
      let json = await (ctx->Hono.req)->Hono.reqJson
      Some(json)
    } catch {
    | _ => None
    }
    switch bodyResult {
    | None =>
      ctx->Hono.jsonWithStatus(
        {
          "success": false,
          "error": "Invalid JSON body",
        },
        400,
      )
    | Some(body) =>
      switch validateRequest(body) {
      | Invalid(error) =>
        let errorResponse = ErrorHandler.toErrorResponse(error)
        ctx->Hono.jsonWithStatus(
          {
            "success": false,
            "error": errorResponse.message,
          },
          400,
        )
      | Valid(request) =>
        let client = createAnthropicClient(env)
        let formatResult = await formatWithLLM(client, request)
        switch formatResult {
        | Error(msg) =>
          ctx->Hono.jsonWithStatus(
            {
              "success": false,
              "error": "Failed to format issue: " ++ msg,
            },
            500,
          )
        | Ok(issue) =>
          let createResult = await createGitHubIssue(issue, githubToken)
          switch createResult {
          | Error(msg) =>
            ctx->Hono.jsonWithStatus(
              {
                "success": false,
                "error": "Failed to create GitHub issue: " ++ msg,
              },
              502,
            )
          | Ok(issueResponse) =>
            ctx->Hono.json({
              "success": true,
              "issueUrl": issueResponse.htmlUrl,
              "issueNumber": issueResponse.number,
            })
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Registration.

let register = (app: Hono.t<env>): Hono.t<env> =>
  app->Hono.post("/api/issues/report", handleReportIssue)
