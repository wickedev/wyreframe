// StringBuffer.res
// Tiny mutable string-buffer abstraction so HtmlBuilder doesn't need to
// pick between ReScript stdlib Buffer (unavailable) and ad-hoc array push.
//
// Implementation: array<string> + Array.join at the end. ES2020 engines
// optimize this well; benchmark proved it is well below the 10k-node /
// 100ms target.

type t = {parts: array<string>}

let make = (): t => {parts: []}

let addString = (b: t, s: string): unit => Array.push(b.parts, s)

let contents = (b: t): string => Array.join(b.parts, "")
