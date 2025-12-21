// Placeholder module to verify ReScript build configuration
// This file confirms the build system is correctly set up
// Will be replaced by actual implementation modules in subsequent tasks

@val external console: 'a = "console"

let version = "0.1.0"

let greet = (name: string) => {
  Js.log(`Wyreframe Parser v${version} - Hello ${name}!`)
}
