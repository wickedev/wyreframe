// Minimal test file to verify ReScript compilation
// This validates the ReScript toolchain is properly configured

let projectName = "wyreframe-parser"
let version = "0.1.0"

// Simple function demonstrating ReScript type safety
let greet = (name: string): string => {
  `Hello, ${name}! Welcome to ${projectName} v${version}`
}

// Verify compilation works
Console.log("ReScript compiler is working correctly!")
Console.log(greet("Developer"))
