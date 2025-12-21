// ReScript external bindings for ohm-js
// This module provides type-safe FFI (Foreign Function Interface) bindings to the ohm-js library

// Abstract types for ohm-js objects
type grammar
type matchResult
type semantics
type node

// Grammar creation
@module("ohm-js")
external makeGrammar: string => grammar = "grammar"

// Matching operations
@send
external match: (grammar, string) => matchResult = "match"

// Match result inspection
@send
external succeeded: matchResult => bool = "succeeded"

@send
external failed: matchResult => bool = "failed"

@send
external message: matchResult => string = "message"

// Semantics operations
@send
external createSemantics: grammar => semantics = "createSemantics"

@send
external addOperation: (semantics, string, 'a) => semantics = "addOperation"

@send
external eval: (semantics, matchResult) => 'a = "eval"

// Grammar loading from file system (for Node.js)
@module("ohm-js")
external grammarFromScriptElement: string => grammar = "grammarFromScriptElement"

// Helper function to load grammar from string
let loadGrammar = (grammarString: string): Result.t<grammar, string> => {
  try {
    let g = makeGrammar(grammarString)
    Ok(g)
  } catch {
  | Js.Exn.Error(e) => {
      let message = switch Js.Exn.message(e) {
      | Some(msg) => msg
      | None => "Unknown error loading grammar"
      }
      Error(message)
    }
  }
}

// Helper function to parse with a grammar
let parseString = (grammar: grammar, input: string): Result.t<matchResult, string> => {
  try {
    let result = match(grammar, input)
    if succeeded(result) {
      Ok(result)
    } else {
      Error(message(result))
    }
  } catch {
  | Js.Exn.Error(e) => {
      let message = switch Js.Exn.message(e) {
      | Some(msg) => msg
      | None => "Unknown error during parsing"
      }
      Error(message)
    }
  }
}
