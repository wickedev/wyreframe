// PrinterIdempotency_test.res
// For each fixture: print(parse(print(ast))) must be byte-identical to print(ast).

open Vitest

let parseFirst = (source: string): option<V2Types.blockNode> => {
  let r = V2Parser.parse(source, ())
  r.blocks->Array.get(0)
}

let fixtures = [
  `@scene: a

+--Form--+
| [ Go ] |
+--------+
`,
  `@scene: row

+----------------+
| [ A ]  [ B ]   |
+----------------+
`,
  `@component: card
@props: name, title?, role=Member

+-------+
| [ X ] |
+-------+
`,
  `@scene: emoji

+----------+
| :check:  |
+----------+
`,
  `@scene: deep

+----------------+
| +----A----+    |
| | [ x ]   |    |
| +---------+    |
+----------------+
`,
]

describe("V2 Printer — idempotency on round-trip", () => {
  test("print(parse(print(ast))) == print(ast)", t => {
    Array.forEach(fixtures, src => {
      switch parseFirst(src) {
      | None => t->expect(true)->Expect.toBe(false)
      | Some(b1) => {
          let s1 = V2Printer.printBlock(b1, V2Printer.defaultOptions())
          let r2 = V2Parser.parse(s1, ())
          switch r2.blocks->Array.get(0) {
          | None => t->expect(true)->Expect.toBe(false)
          | Some(b2) => {
              let s2 = V2Printer.printBlock(b2, V2Printer.defaultOptions())
              t->expect(s1)->Expect.toBe(s2)
            }
          }
        }
      }
    })
  })
})
