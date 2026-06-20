// @monaco-editor/react bindings. Loads Monaco from cdn.jsdelivr.net per the
// original deployment config.

@module("@monaco-editor/react") @react.component
external make: (
  ~height: string=?,
  ~defaultLanguage: string=?,
  ~language: string=?,
  ~defaultValue: string=?,
  ~value: string=?,
  ~theme: string=?,
  ~onChange: (option<string>, 'a) => unit=?,
  ~onMount: ('a, 'b) => unit=?,
  ~options: 'opts=?,
  ~loading: React.element=?,
) => React.element = "default"

module Loader = {
  type config = {paths?: {"vs": string}}
  @module("@monaco-editor/loader") external loader: 'a = "default"

  // Configure Monaco to load from CDN (mirroring the deployed playground).
  let configureFromCdn = () => {
    let configure: 'a => unit = %raw(`(l) => {
      l.config({ paths: { vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/min/vs" } });
    }`)
    configure(loader)
  }
}
