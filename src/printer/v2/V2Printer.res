// V2Printer.res
// Public entry. Converts a V2 AST node back into V2 syntax v2.3 ASCII.

type charset = PrintOptions.charset
type lineEnding = PrintOptions.lineEnding
type errorHandling = PrintOptions.errorHandling
type printOptions = PrintOptions.printOptions

let defaultOptions = PrintOptions.defaultOptions

// Print a single block (scene or component).
let printBlock = (block: V2Types.blockNode, options: printOptions): string => {
  let chars = BorderChars.forCharset(options.charset)
  let lines = BlockEmitter.emitBlock(block, ~chars)
  let le = PrintOptions.lineEndingString(options.lineEnding)
  let processed = if options.trimTrailing {
    Array.map(lines, l => {
      // Strip trailing spaces
      let n = String.length(l)
      let i = ref(n)
      while i.contents > 0 && String.charAt(l, i.contents - 1) == " " {
        i := i.contents - 1
      }
      String.slice(l, ~start=0, ~end=i.contents)
    })
  } else {
    lines
  }
  let joined = Array.join(processed, le)
  joined ++ le
}

// Accept any astNode; only SceneNode and ComponentNode are top-level blocks.
let printAst = (ast: V2Types.astNode, options: printOptions): string =>
  switch ast {
  | SceneNode(s) => printBlock(V2Types.SceneBlock(s), options)
  | ComponentNode(c) => printBlock(V2Types.ComponentBlock(c), options)
  | _ => ""
  }

// Convenience: print with default options.
let print = (ast: V2Types.astNode): string =>
  printAst(ast, defaultOptions())

// Print a full parseResult (one or more blocks).
let printBlocks = (blocks: array<V2Types.blockNode>, options: printOptions): string => {
  let parts = Array.map(blocks, b => printBlock(b, options))
  Array.join(parts, "")
}

let version: string = "0.1.0"
