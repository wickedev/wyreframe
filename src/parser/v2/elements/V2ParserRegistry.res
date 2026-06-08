// V2ParserRegistry.res
// Owns priority-ordered dispatch. tryParse walks parsers descending by priority
// and dispatches the first whose canParse returns true.

type t = {
  mutable parsers: array<V2ElementParser.t>,
}

let make = (): t => {parsers: []}

// Insert preserving descending-priority sort.
let register = (reg: t, p: V2ElementParser.t): unit => {
  let combined = Array.copy(reg.parsers)
  combined->Array.push(p)
  combined->Array.sort((a, b) => Int.toFloat(b.priority - a.priority))
  reg.parsers = combined
}

let unregister = (reg: t, et: V2Types.nodeType): unit => {
  reg.parsers = reg.parsers->Array.filter(p => p.elementType != et)
}

let parsers = (reg: t): array<V2ElementParser.t> => reg.parsers

// First parser whose canParse claims the current position wins.
let tryParse = (
  reg: t,
  ctx: ParseContext.t,
  stream: TokenStream.t,
): option<V2Types.astNode> => {
  let found = ref(None)
  let i = ref(0)
  let n = Array.length(reg.parsers)
  while found.contents == None && i.contents < n {
    let p = reg.parsers->Array.getUnsafe(i.contents)
    let snapshot = TokenStream.save(stream)
    if p.canParse(stream) {
      // canParse must not advance; defensive restore.
      TokenStream.restore(stream, snapshot)
      switch p.parse(ctx, stream) {
      | Some(node) => found := Some(node)
      | None => TokenStream.restore(stream, snapshot)
      }
    } else {
      TokenStream.restore(stream, snapshot)
    }
    i := i.contents + 1
  }
  found.contents
}
