// Textarea with `@L5` / `@L5-10` line-reference autocomplete against an ASCII
// content source. Used by the preview issue reporter.

type lineInfo = {
  lineNumber: int,
  content: string,
  preview: string,
}

type state =
  | Idle
  | Searching(string)
  | SelectingRange(int)

let parseLines = (text: string): array<lineInfo> =>
  text
  ->String.split("\n")
  ->Array.mapWithIndex((line, idx) => {
    let preview = if String.length(line) > 40 {
      String.slice(line, ~start=0, ~end=37) ++ "..."
    } else if String.length(line) === 0 {
      "(empty line)"
    } else {
      line
    }
    {lineNumber: idx + 1, content: line, preview}
  })

let filterLines = (lines: array<lineInfo>, query: string): array<lineInfo> =>
  if query === "" {
    lines
  } else {
    lines->Array.filter(l => l.lineNumber->Int.toString->String.startsWith(query))
  }

// Walk backward from the cursor to find the start of a `@L...` mention being
// typed. Returns `(startIndex, digitsAndDash)` if the current mention is still
// a valid `@L[0-9-]*` token.
let findMentionTrigger = (text: string, cursor: int): option<(int, string)> => {
  let before = String.slice(text, ~start=0, ~end=cursor)
  let length = String.length(before)
  let lastIdx = ref(None)
  let i = ref(0)
  while i.contents < length - 1 {
    let c = String.charAt(before, i.contents)
    let next = String.charAt(before, i.contents + 1)
    if c === "@" && (next === "L" || next === "l") {
      lastIdx := Some(i.contents)
      i := i.contents + 1
    } else {
      i := i.contents + 1
    }
  }
  switch lastIdx.contents {
  | None => None
  | Some(start) =>
    let rest = String.sliceToEnd(before, ~start=start + 2)
    let isValid =
      rest
      ->String.split("")
      ->Array.every(ch => (ch >= "0" && ch <= "9") || ch === "-")
    isValid ? Some(start, rest) : None
  }
}

let parseIntOr = (s: string, fallback: int): int =>
  switch Int.fromString(s) {
  | Some(n) => n
  | None => fallback
  }

@send
external scrollIntoView: (Dom.element, {"block": string, "inline": string}) => unit =
  "scrollIntoView"

@send
external querySelectorAll: (Dom.element, string) => array<Dom.element> = "querySelectorAll"

@react.component
let make = (
  ~value: string,
  ~onChange: string => unit,
  ~asciiContent: string,
  ~placeholder: string="",
  ~className: string="",
  ~id: string="",
  ~maxLength: int=2000,
) => {
  let (state, setState) = React.useState(() => Idle)
  let (cursorPos, setCursorPos) = React.useState(() => 0)
  let (highlightIdx, setHighlightIdx) = React.useState(() => 0)

  let textareaRef = React.useRef(Nullable.null)
  let latestMatchesRef = React.useRef([])
  let dropdownRef = React.useRef(Nullable.null)

  let lines = React.useMemo1(() => parseLines(asciiContent), [asciiContent])

  let matches = React.useMemo2(() => {
    switch state {
    | Idle => []
    | Searching(query) =>
      let parts = String.split(query, "-")
      switch Array.length(parts) {
      | 0 => []
      | 1 =>
        switch parts[0] {
        | Some(q) => filterLines(lines, q)
        | None => []
        }
      | 2 =>
        let startStr = parts[0]->Option.getOr("")
        let startLine = parseIntOr(startStr, 1)
        lines->Array.filter(l => l.lineNumber >= startLine)
      | _ => []
      }
    | SelectingRange(startLine) => lines->Array.filter(l => l.lineNumber >= startLine)
    }
  }, (state, lines))

  React.useEffect1(() => {
    latestMatchesRef.current = matches
    None
  }, [matches])

  React.useEffect2(() => {
    switch dropdownRef.current->Nullable.toOption {
    | None => ()
    | Some(el) =>
      let buttons = querySelectorAll(el, "button")
      switch buttons[highlightIdx] {
      | Some(btn) => scrollIntoView(btn, {"block": "nearest", "inline": "nearest"})
      | None => ()
      }
    }
    None
  }, (highlightIdx, state))

  let handleChange = (e: ReactEvent.Form.t) => {
    let target = ReactEvent.Form.target(e)
    let newValue: string = target["value"]
    let selStart: int = target["selectionStart"]
    setCursorPos(_ => selStart)
    onChange(newValue)
    switch findMentionTrigger(newValue, selStart) {
    | None => setState(_ => Idle)
    | Some(_, query) =>
      setState(_ => Searching(query))
      setHighlightIdx(_ => 0)
    }
  }

  let applySelection = (info: lineInfo) => {
    switch findMentionTrigger(value, cursorPos) {
    | None => ()
    | Some(start, query) =>
      if String.includes(query, "-") {
        let firstPart = String.split(query, "-")->Array.get(0)
        let startLine = switch firstPart {
        | Some(s) => parseIntOr(s, 1)
        | None => 1
        }
        let replacement =
          "@L" ++ Int.toString(startLine) ++ "-" ++ Int.toString(info.lineNumber)
        let prefix = String.slice(value, ~start=0, ~end=start)
        let suffix = String.sliceToEnd(value, ~start=cursorPos)
        onChange(prefix ++ replacement ++ suffix)
        setState(_ => Idle)
      } else {
        let replacement = "@L" ++ Int.toString(info.lineNumber)
        let prefix = String.slice(value, ~start=0, ~end=start)
        let suffix = String.sliceToEnd(value, ~start=cursorPos)
        onChange(prefix ++ replacement ++ suffix)
        setState(_ => Idle)
      }
    }
  }

  let handleKeyDown = (e: ReactEvent.Keyboard.t) => {
    switch state {
    | Idle => ()
    | _ =>
      let key = ReactEvent.Keyboard.key(e)
      let current = latestMatchesRef.current
      switch key {
      | "-" =>
        switch state {
        | Searching(q) when !String.includes(q, "-") =>
          switch Int.fromString(q) {
          | Some(n) => setState(_ => SelectingRange(n))
          | None => ()
          }
        | _ => ()
        }
      | "ArrowDown" =>
        ReactEvent.Keyboard.preventDefault(e)
        setHighlightIdx(idx => {
          let last = Array.length(current) - 1
          idx >= last ? 0 : idx + 1
        })
      | "ArrowUp" =>
        ReactEvent.Keyboard.preventDefault(e)
        setHighlightIdx(idx => {
          let last = Array.length(current) - 1
          idx <= 0 ? last : idx - 1
        })
      | "Escape" =>
        ReactEvent.Keyboard.preventDefault(e)
        setState(_ => Idle)
      | "Enter" | "Tab" =>
        ReactEvent.Keyboard.preventDefault(e)
        switch current[highlightIdx] {
        | Some(info) => applySelection(info)
        | None => ()
        }
      | _ => ()
      }
    }
  }

  let dropdownVisible = switch state {
  | Idle => false
  | _ => Array.length(matches) > 0
  }

  let header = switch state {
  | Idle => "Select line (type - for range)"
  | Searching(q) =>
    String.includes(q, "-") ? "Select end line for range" : "Select line (type - for range)"
  | SelectingRange(n) => "Select end line (from L" ++ Int.toString(n) ++ ")"
  }

  let textareaCls =
    "flex min-h-[100px] w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50 " ++
    className

  <div className="relative">
    <textarea
      ref={ReactDOM.Ref.domRef(textareaRef)}
      className=textareaCls
      id
      maxLength
      placeholder
      value
      onKeyDown=handleKeyDown
      onChange=handleChange
    />
    {dropdownVisible
      ? <div
          ref={ReactDOM.Ref.domRef(dropdownRef)}
          className="absolute z-50 mt-1 w-full max-h-[240px] overflow-y-auto rounded-md border bg-popover shadow-lg">
          <div className="p-1">
            <div
              className="px-2 py-1 text-xs text-muted-foreground border-b mb-1 sticky top-0 bg-popover">
              {React.string(header)}
            </div>
            {matches
            ->Array.mapWithIndex((info, idx) => {
              let isActive = idx === highlightIdx
              let btnCls =
                "w-full text-left px-2 py-1.5 text-sm rounded-sm flex items-center gap-2 " ++ (
                  isActive ? "bg-primary text-primary-foreground" : "hover:bg-accent/50"
                )
              let badgeCls =
                "font-mono text-xs px-1.5 py-0.5 rounded " ++ (
                  isActive ? "bg-primary-foreground/20" : "bg-muted"
                )
              let previewCls = "truncate " ++ (isActive ? "" : "text-muted-foreground")
              <button
                key={Int.toString(info.lineNumber)}
                className=btnCls
                type_="button"
                onClick={_ => applySelection(info)}
                onMouseEnter={_ => setHighlightIdx(_ => idx)}>
                <span className=badgeCls>
                  {React.string("L" ++ Int.toString(info.lineNumber))}
                </span>
                <span className=previewCls> {React.string(info.preview)} </span>
              </button>
            })
            ->React.array}
          </div>
        </div>
      : React.null}
    <p className="mt-1 text-xs text-muted-foreground">
      {React.string("Type @L to reference lines (e.g., @L5 or @L5-10 for range)")}
    </p>
  </div>
}
