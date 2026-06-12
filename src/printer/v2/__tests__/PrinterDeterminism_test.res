// Determinism_test.res
// Print the same AST 50× and confirm byte-identical output.

open Vitest

let parseFirst = (source: string): option<V2Types.blockNode> => {
  let r = V2Parser.parse(source, ())
  r.blocks->Array.get(0)
}

let sources = [
  `@scene: a
@title: T

+--Form--+
| [ Go ] |
+--------+
`,
  `@scene: row

+--------------+
| [ A ] [ B ]  |
+--------------+
`,
  `@component: card
@props: name, role?

+----------+
| [ X ]    |
+----------+
`,
]

describe("V2 Printer — determinism", () => {
  test("byte-identical output on repeated print", t => {
    Array.forEach(sources, src => {
      switch parseFirst(src) {
      | None => t->expect(true)->Expect.toBe(false)
      | Some(block) => {
          let opts = V2Printer.defaultOptions()
          let baseline = V2Printer.printBlock(block, opts)
          let i = ref(0)
          let allEqual = ref(true)
          while i.contents < 50 {
            let s = V2Printer.printBlock(block, opts)
            if s != baseline {
              allEqual := false
            }
            i := i.contents + 1
          }
          t->expect(allEqual.contents)->Expect.toBe(true)
        }
      }
    })
  })
})
