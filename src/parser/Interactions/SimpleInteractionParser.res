/**
 * SimpleInteractionParser.res
 *
 * A simple line-based parser for the Interaction DSL.
 * No external dependencies - pure ReScript implementation.
 */

open Types

// Regex Patterns
let scenePattern = %re("/^@scene:\s*(\w+)\s*$/")
let inputSelectorPattern = %re("/^#(\w+):\s*$/")
let buttonSelectorPattern = %re("/^\[([^\]]+)\]:\s*$/")
let linkSelectorPattern = %re("/^\"([^\"]+)\":\s*$/")
let propertyPattern = %re("/^\s{2}(\w+):\s*(.+?)\s*$/")
let actionPattern = %re("/^\s{2}@(\w+)\s*->\s*(.+?)\s*$/")
let sceneSeparator = %re("/^---\s*$/")

let parseStringValue = (value: string): string => {
  let trimmed = value->String.trim
  if trimmed->String.startsWith("\"") && trimmed->String.endsWith("\"") {
    trimmed->String.slice(~start=1, ~end=-1)
  } else {
    trimmed
  }
}

let getCapture = (result: RegExp.Result.t, index: int): option<string> => {
  result->RegExp.Result.matches->Array.get(index)
}

let parseActionExpr = (expr: string): option<interactionAction> => {
  let gotoPattern = %re("/^goto\s*\(\s*(\w+)(?:\s*,\s*([\w-]+))?\s*\)$/")
  let backPattern = %re("/^back\s*\(\s*\)$/")
  let forwardPattern = %re("/^forward\s*\(\s*\)$/")

  switch gotoPattern->RegExp.exec(expr) {
  | Some(result) => {
      let target = getCapture(result, 0)
      let transition = getCapture(result, 1)->Option.getOr("fade")
      switch target {
      | Some(t) => Some(Goto({target: t, transition, condition: None}))
      | None => None
      }
    }
  | None => {
      if backPattern->RegExp.test(expr) {
        Some(Back)
      } else if forwardPattern->RegExp.test(expr) {
        Some(Forward)
      } else {
        let callPattern = %re("/^(\w+)\s*\(([^)]*)\)$/")
        switch callPattern->RegExp.exec(expr) {
        | Some(result) => {
            let funcName = getCapture(result, 0)
            let argsStr = getCapture(result, 1)->Option.getOr("")
            switch funcName {
            | Some(name) => {
                let args = if argsStr->String.trim === "" {
                  []
                } else {
                  argsStr->String.split(",")->Array.map(String.trim)
                }
                Some(Call({function: name, args, condition: None}))
              }
            | None => None
            }
          }
        | None => None
        }
      }
    }
  }
}

let selectorToId = (selectorType: string, text: string): string => {
  switch selectorType {
  | "input" => text
  | "button" | "link" => {
      text
      ->String.trim
      ->String.toLowerCase
      ->String.replaceRegExp(%re("/[^a-z0-9]+/g"), "-")
      ->String.replaceRegExp(%re("/^-|-$/g"), "")
    }
  | _ => text
  }
}

type parserState = {
  mutable currentScene: option<string>,
  mutable currentElementId: option<string>,
  mutable currentProperties: Js.Dict.t<Js.Json.t>,
  mutable currentActions: array<interactionAction>,
  mutable sceneInteractions: array<sceneInteractions>,
  mutable currentInteractions: array<interaction>,
}

let createState = (): parserState => {
  currentScene: None,
  currentElementId: None,
  currentProperties: Js.Dict.empty(),
  currentActions: [],
  sceneInteractions: [],
  currentInteractions: [],
}

let flushElement = (state: parserState): unit => {
  switch state.currentElementId {
  | Some(elementId) => {
      let interaction: interaction = {
        elementId,
        properties: state.currentProperties,
        actions: state.currentActions,
      }
      state.currentInteractions->Array.push(interaction)->ignore
      state.currentElementId = None
      state.currentProperties = Js.Dict.empty()
      state.currentActions = []
    }
  | None => ()
  }
}

let flushScene = (state: parserState): unit => {
  flushElement(state)
  switch state.currentScene {
  | Some(sceneId) => {
      if state.currentInteractions->Array.length > 0 {
        let si: sceneInteractions = {
          sceneId,
          interactions: state.currentInteractions,
        }
        state.sceneInteractions->Array.push(si)->ignore
      }
      state.currentScene = None
      state.currentInteractions = []
    }
  | None => ()
  }
}

let parse = (input: string): result<array<sceneInteractions>, string> => {
  let state = createState()
  let lines = input->String.split("\n")
  let lineNum = ref(0)
  let error = ref(None)

  lines->Array.forEach(line => {
    lineNum := lineNum.contents + 1

    if error.contents->Option.isSome {
      ()
    } else {
      let trimmed = line->String.trim
      if trimmed === "" || trimmed->String.startsWith("//") {
        ()
      } else if sceneSeparator->RegExp.test(trimmed) {
        flushScene(state)
      } else {
        switch scenePattern->RegExp.exec(trimmed) {
        | Some(result) => {
            flushScene(state)
            let matches = result->RegExp.Result.matches
            switch matches->Array.get(0) {
            | Some(sceneId) => state.currentScene = Some(sceneId)
            | None => ()
            }
          }
        | None => {
            switch inputSelectorPattern->RegExp.exec(trimmed) {
            | Some(result) => {
                flushElement(state)
                let matches = result->RegExp.Result.matches
                switch matches->Array.get(0) {
                | Some(id) => state.currentElementId = Some(id)
                | None => ()
                }
              }
            | None => {
                switch buttonSelectorPattern->RegExp.exec(trimmed) {
                | Some(result) => {
                    flushElement(state)
                    let matches = result->RegExp.Result.matches
                    switch matches->Array.get(0) {
                    | Some(text) => {
                        let id = selectorToId("button", text)
                        state.currentElementId = Some(id)
                      }
                    | None => ()
                    }
                  }
                | None => {
                    switch linkSelectorPattern->RegExp.exec(trimmed) {
                    | Some(result) => {
                        flushElement(state)
                        let matches = result->RegExp.Result.matches
                        switch matches->Array.get(0) {
                        | Some(text) => {
                            let id = selectorToId("link", text)
                            state.currentElementId = Some(id)
                          }
                        | None => ()
                        }
                      }
                    | None => {
                        switch propertyPattern->RegExp.exec(line) {
                        | Some(result) => {
                            let matches = result->RegExp.Result.matches
                            let key = matches->Array.get(0)
                            let value = matches->Array.get(1)
                            switch (key, value, state.currentElementId) {
                            | (Some(k), Some(v), Some(_)) => {
                                let parsedValue = parseStringValue(v)
                                state.currentProperties->Js.Dict.set(k, Js.Json.string(parsedValue))
                              }
                            | _ => ()
                            }
                          }
                        | None => {
                            switch actionPattern->RegExp.exec(line) {
                            | Some(result) => {
                                let matches = result->RegExp.Result.matches
                                let _event = matches->Array.get(0)
                                let actionExpr = matches->Array.get(1)
                                switch (actionExpr, state.currentElementId) {
                                | (Some(expr), Some(_)) => {
                                    switch parseActionExpr(expr) {
                                    | Some(action) => {
                                        state.currentActions->Array.push(action)->ignore
                                      }
                                    | None => {
                                        error := Some(`Line ${Int.toString(lineNum.contents)}: Invalid action`)
                                      }
                                    }
                                  }
                                | _ => ()
                                }
                              }
                            | None => ()
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })

  flushScene(state)

  switch error.contents {
  | Some(msg) => Error(msg)
  | None => Ok(state.sceneInteractions)
  }
}
