// Bug-report dialog launched from the playground preview. POSTs to
// /api/issues/report; supports per-scene targeted descriptions.

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

type sceneIssue = {
  sceneId: string,
  description: string,
}

type submitState =
  | Input
  | Submitting
  | Success(string)
  | Error(string)

type successResult = {
  issueUrl: string,
  issueNumber: int,
}

type reportResult =
  | OkResult(successResult)
  | NetworkError(string)
  | ApiError(string)

// ---------------------------------------------------------------------------
// Browser + version probes.

@val external navigator: {"userAgent": string} = "navigator"
@val @scope("window") external innerWidth: int = "innerWidth"
@val @scope("window") external innerHeight: int = "innerHeight"
@val @scope("window") external openInNewTab: string => unit = "open"

let getBrowserInfo = (): browserInfo => {
  userAgent: navigator["userAgent"],
  viewport: {
    width: innerWidth,
    height: innerHeight,
  },
}

let getVersionInfo = (): versionInfo => {wyreframe: "0.7.11"}

let fromWyreframeParseError = (e: parseIssue): parseIssue => {
  message: e.message,
  line: e.line,
  column: e.column,
}

// ---------------------------------------------------------------------------
// Submission to backend.

let encodeParseIssue = (p: parseIssue): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("message", JSON.Encode.string(p.message))
  switch p.line {
  | Some(n) => obj->Dict.set("line", JSON.Encode.float(Int.toFloat(n)))
  | None => obj->Dict.set("line", JSON.Encode.null)
  }
  switch p.column {
  | Some(n) => obj->Dict.set("column", JSON.Encode.float(Int.toFloat(n)))
  | None => obj->Dict.set("column", JSON.Encode.null)
  }
  JSON.Encode.object(obj)
}

let encodeBody = (
  ~userDescription: string,
  ~asciiContent: string,
  ~parseWarnings: array<parseIssue>,
  ~parseError: option<parseIssue>,
  ~browserInfo: browserInfo,
  ~versionInfo: versionInfo,
  ~availableScenes: array<string>,
  ~selectedScenes: array<string>,
  ~parsedAst: option<JSON.t>,
): string => {
  let body = Dict.make()
  body->Dict.set("userDescription", JSON.Encode.string(userDescription))
  body->Dict.set("asciiContent", JSON.Encode.string(asciiContent))
  body->Dict.set(
    "parseWarnings",
    JSON.Encode.array(parseWarnings->Array.map(encodeParseIssue)),
  )
  switch parseError {
  | Some(pe) => body->Dict.set("parseError", encodeParseIssue(pe))
  | None => body->Dict.set("parseError", JSON.Encode.null)
  }

  let vp = Dict.make()
  vp->Dict.set("width", JSON.Encode.float(Int.toFloat(browserInfo.viewport.width)))
  vp->Dict.set("height", JSON.Encode.float(Int.toFloat(browserInfo.viewport.height)))
  let bi = Dict.make()
  bi->Dict.set("userAgent", JSON.Encode.string(browserInfo.userAgent))
  bi->Dict.set("viewport", JSON.Encode.object(vp))
  body->Dict.set("browserInfo", JSON.Encode.object(bi))

  let vi = Dict.make()
  vi->Dict.set("wyreframe", JSON.Encode.string(versionInfo.wyreframe))
  body->Dict.set("versionInfo", JSON.Encode.object(vi))

  body->Dict.set(
    "availableScenes",
    JSON.Encode.array(availableScenes->Array.map(JSON.Encode.string)),
  )
  body->Dict.set(
    "selectedScenes",
    JSON.Encode.array(selectedScenes->Array.map(JSON.Encode.string)),
  )
  switch parsedAst {
  | Some(ast) => body->Dict.set("parsedAst", ast)
  | None => body->Dict.set("parsedAst", JSON.Encode.null)
  }

  JSON.stringify(JSON.Encode.object(body))
}

let reportIssue = async (
  ~userDescription: string,
  ~asciiContent: string,
  ~parseWarnings: array<parseIssue>,
  ~parseError: option<parseIssue>,
  ~browserInfo: browserInfo,
  ~versionInfo: versionInfo,
  ~availableScenes: array<string>,
  ~selectedScenes: array<string>,
  ~parsedAst: option<JSON.t>,
): reportResult => {
  let url = ApiBase.url("/api/issues/report")
  let body = encodeBody(
    ~userDescription,
    ~asciiContent,
    ~parseWarnings,
    ~parseError,
    ~browserInfo,
    ~versionInfo,
    ~availableScenes,
    ~selectedScenes,
    ~parsedAst,
  )

  try {
    let init = {
      "method": "POST",
      "headers": {"Content-Type": "application/json"},
      "body": body,
    }
    let res = await Fetch.fetch(url, init->Obj.magic)
    let status = Fetch.status(res)
    let text = await Fetch.text(res)

    if status >= 400 {
      try {
        let json = JSON.parseExn(text)
        switch JSON.Classify.classify(json) {
        | Object(obj) =>
          let err = switch obj->Dict.get("error") {
          | Some(v) =>
            switch JSON.Classify.classify(v) {
            | String(s) => s
            | _ => "Unknown error"
            }
          | None => "Unknown error"
          }
          ApiError(err)
        | _ => ApiError("Server error: " ++ Int.toString(status))
        }
      } catch {
      | _ => ApiError("Server error: " ++ Int.toString(status))
      }
    } else {
      try {
        let json = JSON.parseExn(text)
        switch JSON.Classify.classify(json) {
        | Object(obj) =>
          let success = switch obj->Dict.get("success") {
          | Some(v) =>
            switch JSON.Classify.classify(v) {
            | Bool(b) => b
            | _ => false
            }
          | None => false
          }
          if success {
            let issueUrl = switch obj->Dict.get("issueUrl") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | String(s) => s
              | _ => ""
              }
            | None => ""
            }
            let issueNumber = switch obj->Dict.get("issueNumber") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | Number(n) => Float.toInt(n)
              | _ => 0
              }
            | None => 0
            }
            if issueUrl !== "" && issueNumber > 0 {
              OkResult({issueUrl, issueNumber})
            } else {
              ApiError("Invalid response: missing issue URL or number")
            }
          } else {
            let err = switch obj->Dict.get("error") {
            | Some(v) =>
              switch JSON.Classify.classify(v) {
              | String(s) => s
              | _ => "Unknown error"
              }
            | None => "Unknown error"
            }
            ApiError(err)
          }
        | _ => ApiError("Invalid response format")
        }
      } catch {
      | _ => ApiError("Failed to parse response")
      }
    }
  } catch {
  | Exn.Error(e) =>
    NetworkError(Exn.message(e)->Option.getOr("Unknown network error"))
  | _ => NetworkError("Unknown error occurred")
  }
}

// ---------------------------------------------------------------------------
// Component.

@react.component
let make = (
  ~asciiContent: string,
  ~parsedAst: option<JSON.t>=?,
  ~parseWarnings: array<parseIssue>=[],
  ~parseError: option<parseIssue>=?,
  ~availableScenes: array<string>=[],
  ~onClose: unit => unit,
  ~onSuccess: option<string => unit>=?,
) => {
  let (state, setState) = React.useState(() => Input)
  let (description, setDescription) = React.useState(() => "")
  let (sceneIssues, setSceneIssues) = React.useState((): array<sceneIssue> => [])

  let remainingScenes =
    availableScenes->Array.filter(s => !(sceneIssues->Array.some(si => si.sceneId === s)))

  let addScene = (id: string) => {
    if id !== "" {
      setSceneIssues(prev => prev->Array.concat([{sceneId: id, description: ""}]))
    }
  }

  let submit = async () => {
    let hasMain = String.trim(description) !== ""
    let hasScene = sceneIssues->Array.some(s => String.trim(s.description) !== "")

    if !hasMain && !hasScene {
      setState(_ => Error("Please describe the issue"))
    } else {
      setState(_ => Submitting)
      let sceneBlocks =
        sceneIssues
        ->Array.filter(s => String.trim(s.description) !== "")
        ->Array.map(s => "[" ++ s.sceneId ++ "]: " ++ s.description)
        ->Array.join("\n\n")

      let combined = if hasMain && hasScene {
        description ++ "\n\n--- Scene-specific issues ---\n" ++ sceneBlocks
      } else if hasScene {
        sceneBlocks
      } else {
        description
      }

      let warnings = parseWarnings->Array.map(fromWyreframeParseError)
      let err = parseError->Option.map(fromWyreframeParseError)
      let browserInfo = getBrowserInfo()
      let versionInfo = getVersionInfo()
      let selected = sceneIssues->Array.map(s => s.sceneId)

      let result = await reportIssue(
        ~userDescription=combined,
        ~asciiContent,
        ~parseWarnings=warnings,
        ~parseError=err,
        ~browserInfo,
        ~versionInfo,
        ~availableScenes,
        ~selectedScenes=selected,
        ~parsedAst,
      )

      switch result {
      | OkResult({issueUrl}) =>
        setState(_ => Success(issueUrl))
        switch onSuccess {
        | Some(cb) => cb(issueUrl)
        | None => ()
        }
      | NetworkError(msg) => setState(_ => Error("Network error: " ++ msg))
      | ApiError(msg) => setState(_ => Error(msg))
      }
    }
  }

  let renderSceneSelector = () => {
    if Array.length(availableScenes) < 1 {
      React.null
    } else {
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <Label htmlFor="scene-selector">
            {React.string("Scene-specific Issues")}
          </Label>
        </div>
        {if Array.length(sceneIssues) > 0 {
          <div className="space-y-3">
            {sceneIssues
            ->Array.mapWithIndex((issue, idx) =>
              <div
                key={Int.toString(idx)}
                className="border rounded-md p-3 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">
                    {React.string(issue.sceneId)}
                  </span>
                  <button
                    type_="button"
                    className="text-muted-foreground hover:text-destructive transition-colors"
                    onClick={_ => {
                      let target = issue.sceneId
                      setSceneIssues(prev =>
                        prev->Array.filter(si => si.sceneId !== target)
                      )
                    }}>
                    <Lucide.X className="h-4 w-4" />
                  </button>
                </div>
                <LineReferenceInput
                  value={issue.description}
                  onChange={v => {
                    let target = issue.sceneId
                    setSceneIssues(prev =>
                      prev->Array.map(si =>
                        si.sceneId === target
                          ? {sceneId: si.sceneId, description: v}
                          : si
                      )
                    )
                  }}
                  asciiContent
                  placeholder={"Describe the issue with " ++
                  issue.sceneId ++ "... (Use @L5 to reference lines)"}
                  className="min-h-[60px]"
                  maxLength=1000
                />
              </div>
            )
            ->React.array}
          </div>
        } else {
          React.null
        }}
        {if Array.length(remainingScenes) > 0 {
          <div className="flex items-center gap-2">
            <select
              id="scene-selector"
              defaultValue=""
              className="flex h-9 w-full rounded-md border border-input bg-transparent px-3 py-1 text-sm shadow-sm transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
              onChange={e => {
                let target = ReactEvent.Form.target(e)
                let v: string = target["value"]
                addScene(v)
                target["value"] = ""
              }}>
              <option disabled=true value="">
                {React.string("+ Add scene...")}
              </option>
              {remainingScenes
              ->Array.mapWithIndex((s, idx) =>
                <option key={Int.toString(idx)} value={s}>
                  {React.string(s)}
                </option>
              )
              ->React.array}
            </select>
          </div>
        } else if Array.length(sceneIssues) === Array.length(availableScenes) &&
          Array.length(availableScenes) > 0 {
          <p className="text-xs text-muted-foreground">
            {React.string("All scenes have been added.")}
          </p>
        } else {
          React.null
        }}
        <p className="text-xs text-muted-foreground">
          {React.string(
            "Add scenes to report issues specific to certain parts of your wireframe.",
          )}
        </p>
      </div>
    }
  }

  let renderBody = () => {
    switch state {
    | Input =>
      <div className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="issue-description">
            {React.string("What went wrong?")}
          </Label>
          <LineReferenceInput
            value={description}
            onChange={v => setDescription(_ => v)}
            asciiContent
            placeholder="Describe the issue with the preview... (Use @L5 to reference lines)"
            id="issue-description"
            maxLength=2000
          />
        </div>
        {renderSceneSelector()}
        <div className="flex items-start gap-2 text-sm text-muted-foreground">
          <Lucide.Info className="h-4 w-4 mt-0.5 shrink-0" />
          <p>
            {React.string(
              "Your wireframe content and browser info will be included in the report.",
            )}
          </p>
        </div>
      </div>
    | Submitting =>
      <div className="flex flex-col items-center justify-center py-12 space-y-4">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
        <p className="text-sm text-muted-foreground">
          {React.string("Creating issue...")}
        </p>
        <ul className="text-xs text-muted-foreground space-y-1">
          <li> {React.string("\xe2\x80\xa2 Analyzing your report with AI")} </li>
          <li> {React.string("\xe2\x80\xa2 Creating GitHub issue")} </li>
        </ul>
      </div>
    | Error(msg) =>
      <div className="space-y-4">
        <div
          role="alert"
          className="relative w-full rounded-lg border border-destructive/50 text-destructive dark:border-destructive p-4 [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 [&>svg]:text-destructive [&>svg+div]:translate-y-[-3px] [&:has(svg)]:pl-11">
          <Lucide.CircleAlert className="h-4 w-4" />
          <h5 className="mb-1 font-medium leading-none tracking-tight">
            {React.string("Error")}
          </h5>
          <div className="text-sm [&_p]:leading-relaxed">
            {React.string(msg)}
          </div>
        </div>
        <div className="space-y-2">
          <Label htmlFor="issue-description">
            {React.string("What went wrong?")}
          </Label>
          <LineReferenceInput
            value={description}
            onChange={v => setDescription(_ => v)}
            asciiContent
            placeholder="Describe the issue with the preview... (Use @L5 to reference lines)"
            id="issue-description"
            maxLength=2000
          />
        </div>
        {renderSceneSelector()}
      </div>
    | Success(url) =>
      <div className="flex flex-col items-center justify-center py-12 space-y-4">
        <div className="rounded-full bg-success/20 p-3">
          <Lucide.Check className="h-6 w-6 text-success" />
        </div>
        <p className="font-medium"> {React.string("Issue Created!")} </p>
        <p className="text-sm text-muted-foreground text-center">
          {React.string("Your issue has been created:")}
        </p>
        <a
          className="text-sm text-primary hover:underline flex items-center gap-1"
          href={url}
          rel="noopener noreferrer"
          target="_blank">
          <Lucide.ExternalLink className="h-3 w-3" />
          {React.string(url)}
        </a>
        <p className="text-sm text-muted-foreground">
          {React.string("Thank you for your feedback!")}
        </p>
      </div>
    }
  }

  let hasMain = String.trim(description) !== ""
  let hasScene = sceneIssues->Array.some(s => String.trim(s.description) !== "")
  let canSubmit = hasMain || hasScene

  let renderFooter = () => {
    switch state {
    | Input =>
      <div className="flex justify-end gap-2 pt-4 border-t">
        <Button variant=#outline size=#sm onClick={_ => onClose()}>
          {React.string("Cancel")}
        </Button>
        <Button
          size=#sm
          disabled={!canSubmit}
          onClick={_ => {
            let _ = submit()
          }}>
          {React.string("Submit Report")}
        </Button>
      </div>
    | Submitting => React.null
    | Error(_) =>
      <div className="flex justify-end gap-2 pt-4 border-t">
        <Button variant=#outline size=#sm onClick={_ => onClose()}>
          {React.string("Cancel")}
        </Button>
        <Button
          size=#sm
          disabled={!canSubmit}
          onClick={_ => {
            let _ = submit()
          }}>
          {React.string("Try Again")}
        </Button>
      </div>
    | Success(url) =>
      <div className="flex justify-end gap-2 pt-4 border-t">
        <Button variant=#outline size=#sm onClick={_ => onClose()}>
          {React.string("Back to Chat")}
        </Button>
        <Button size=#sm onClick={_ => openInNewTab(url)}>
          <Lucide.ExternalLink className="h-4 w-4 mr-2" />
          {React.string("View Issue")}
        </Button>
      </div>
    }
  }

  <div className="flex flex-col h-full bg-background">
    <div className="flex items-center justify-between px-4 py-3 border-b">
      <div>
        <h2 className="text-lg font-semibold">
          {React.string("Report Preview Issue")}
        </h2>
        <p className="text-sm text-muted-foreground">
          {React.string("Help us improve by reporting unexpected behavior.")}
        </p>
      </div>
      <button
        type_="button"
        className="rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        onClick={_ => onClose()}>
        <Lucide.X className="h-5 w-5" />
        <span className="sr-only"> {React.string("Close")} </span>
      </button>
    </div>
    <div className="flex-1 overflow-y-auto p-4"> {renderBody()} </div>
    <div className="px-4 pb-4"> {renderFooter()} </div>
  </div>
}
