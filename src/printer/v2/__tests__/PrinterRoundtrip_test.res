// Roundtrip_test.res
// Verifies V2Parser.parse(V2Printer.print(ast)) is semantically equal to ast,
// across a corpus of ASCII inputs covering every node variant + edge case.

open Vitest

let parseToBlock = (source: string): option<V2Types.blockNode> => {
  let result = V2Parser.parse(source, ())
  result.blocks->Array.get(0)
}

let runRoundtrip = (t, source: string): unit => {
  switch parseToBlock(source) {
  | None => t->expect(true)->Expect.toBe(false) // force fail
  | Some(block1) => {
      let out1 = V2Printer.printBlock(block1, V2Printer.defaultOptions())
      let r2 = V2Parser.parse(out1, ())
      t->expect(r2.success)->Expect.toBe(true)
      switch r2.blocks->Array.get(0) {
      | None => t->expect(true)->Expect.toBe(false)
      | Some(block2) => {
          let eq = Compare.blocksEqual(block1, block2)
          if !eq {
            Console.log("---- BLOCK 1 ----")
            Console.log(out1)
            Console.log("---- BLOCK 2 OUT ----")
            let out2 = V2Printer.printBlock(block2, V2Printer.defaultOptions())
            Console.log(out2)
          }
          t->expect(eq)->Expect.toBe(true)
          // Idempotency
          let out2 = V2Printer.printBlock(block2, V2Printer.defaultOptions())
          t->expect(out1)->Expect.toBe(out2)
        }
      }
    }
  }
}

describe("V2 Printer — round-trip suite", () => {
  test("F01: empty scene", t => {
    runRoundtrip(
      t,
      `@scene: empty

`,
    )
  })

  test("F02: scene with title and device", t => {
    runRoundtrip(
      t,
      `@scene: home
@title: Home Page
@device: mobile

`,
    )
  })

  test("F03: scene with transition", t => {
    runRoundtrip(
      t,
      `@scene: dash
@transition: fade

`,
    )
  })

  test("F04: single container", t => {
    runRoundtrip(
      t,
      `@scene: one

+--Form--+
|        |
+--------+
`,
    )
  })

  test("F05: container with single button", t => {
    runRoundtrip(
      t,
      `@scene: btn

+------------+
| [ Login ]  |
+------------+
`,
    )
  })

  test("F06: container with button + link (column)", t => {
    runRoundtrip(
      t,
      `@scene: col

+-------------+
| [ Login ]   |
| < Forgot >  |
+-------------+
`,
    )
  })

  test("F07: container with row layout (button + button)", t => {
    runRoundtrip(
      t,
      `@scene: row

+----------------------+
| [ Cancel ]  [ OK ]   |
+----------------------+
`,
    )
  })

  test("F08: input field", t => {
    runRoundtrip(
      t,
      `@scene: form

+--------------------+
| [__email__]        |
+--------------------+
`,
    )
  })

  test("F09: select dropdown", t => {
    runRoundtrip(
      t,
      `@scene: form2

+--------------------+
| [v: Choose option] |
+--------------------+
`,
    )
  })

  test("F10: checkbox checked + unchecked", t => {
    runRoundtrip(
      t,
      `@scene: chk

+----------------+
| [x] Remember   |
| [ ] Subscribe  |
+----------------+
`,
    )
  })

  test("F11: radio buttons", t => {
    runRoundtrip(
      t,
      `@scene: rad

+----------------+
| (*) Card       |
| ( ) Bank       |
| ( ) Crypto     |
+----------------+
`,
    )
  })

  test("F12: divider normal + bold", t => {
    runRoundtrip(
      t,
      `@scene: div

+-----------------+
| ---             |
| ===             |
+-----------------+
`,
    )
  })

  test("F13: divider with label", t => {
    runRoundtrip(
      t,
      `@scene: divlbl

+-------------------+
| --- Section ---   |
+-------------------+
`,
    )
  })

  test("F14: divider with id", t => {
    runRoundtrip(
      t,
      `@scene: divid

+-------------------+
| ---#top---        |
+-------------------+
`,
    )
  })

  test("F15: string literal", t => {
    runRoundtrip(
      t,
      `@scene: str

+--------------------+
| "Welcome back!"    |
+--------------------+
`,
    )
  })

  test("F16: emoji shortcode", t => {
    runRoundtrip(
      t,
      `@scene: emo

+-----------+
| :check:   |
+-----------+
`,
    )
  })

  test("F17: container with name", t => {
    runRoundtrip(
      t,
      `@scene: named

+--Login--+
| [ Go ]  |
+---------+
`,
    )
  })

  test("F18: container with id format 1", t => {
    runRoundtrip(
      t,
      `@scene: idfmt1

+--#main-form--+
| [ Submit ]   |
+--------------+
`,
    )
  })

  test("F19: component with no props", t => {
    runRoundtrip(
      t,
      `@component: card

+-------------+
| [ Click ]   |
+-------------+
`,
    )
  })

  test("F20: component with props", t => {
    runRoundtrip(
      t,
      `@component: greeting
@props: name, title?

+-------------+
| [ Click ]   |
+-------------+
`,
    )
  })

  test("F21: prop placeholder in component", t => {
    runRoundtrip(
      t,
      `@component: greet
@props: name

+----------------+
| \${name}        |
+----------------+
`,
    )
  })

  test("F22: prop with default value", t => {
    runRoundtrip(
      t,
      `@component: greet2
@props: role

+--------------------+
| \${role:Member}     |
+--------------------+
`,
    )
  })

  test("F23: nested container (2 deep)", t => {
    runRoundtrip(
      t,
      `@scene: nested

+--------------------+
| +--Inner--+        |
| | [ Go ]  |        |
| +---------+        |
+--------------------+
`,
    )
  })

  test("F24: multiple containers in scene", t => {
    runRoundtrip(
      t,
      `@scene: multi

+-----------+
| [ One ]   |
+-----------+
+-----------+
| [ Two ]   |
+-----------+
`,
    )
  })

  test("F25: plain text inside container", t => {
    runRoundtrip(
      t,
      `@scene: txt

+-----------------+
| Welcome back    |
+-----------------+
`,
    )
  })

  test("F26: distribution SpaceBetween (row with 0 edge pad)", t => {
    runRoundtrip(
      t,
      `@scene: dspb

+-------------------+
|[ Cancel ] [ OK ]  |
+-------------------+
`,
    )
  })

  test("F27: distribution Center for row", t => {
    runRoundtrip(
      t,
      `@scene: dcenter

+----------------------+
|    [ A ]  [ B ]      |
+----------------------+
`,
    )
  })

  test("F28: distribution End", t => {
    runRoundtrip(
      t,
      `@scene: dend

+----------------------+
|         [ Save ]     |
+----------------------+
`,
    )
  })

  test("F29: scene with single button outside container", t => {
    runRoundtrip(
      t,
      `@scene: lone

[ Standalone ]
`,
    )
  })

  test("F30: text alignment right", t => {
    runRoundtrip(
      t,
      `@scene: alright

+--------------------+
|     Welcome here   |
+--------------------+
`,
    )
  })

  test("F31: text alignment center", t => {
    runRoundtrip(
      t,
      `@scene: alcenter

+--------------------+
|     Heading        |
+--------------------+
`,
    )
  })

  test("F32: empty container", t => {
    runRoundtrip(
      t,
      `@scene: emptycont

+--+
+--+
`,
    )
  })

  test("F33: component with optional + default props", t => {
    runRoundtrip(
      t,
      `@component: combo
@props: name, title?, role=Member

+----------+
| [ Go ]   |
+----------+
`,
    )
  })

  test("F34: divider bold with label", t => {
    runRoundtrip(
      t,
      `@scene: dboldlbl

+------------------+
| === Payment ===  |
+------------------+
`,
    )
  })

  test("F35: deep nesting 3 levels", t => {
    runRoundtrip(
      t,
      `@scene: deep

+----------------------+
| +----A----+          |
| | +--B--+ |          |
| | | [c] | |          |
| | +-----+ |          |
| +---------+          |
+----------------------+
`,
    )
  })

  test("F36: every leaf node combined", t => {
    runRoundtrip(
      t,
      `@scene: combo

+--------------------------+
| [ Btn ]                  |
| < Lnk >                  |
| [__email__]              |
| [v: pick]                |
| [x] cb                   |
| ( ) rd                   |
| ---                      |
| "string"                 |
| :check:                  |
+--------------------------+
`,
    )
  })

  test("F37: nested container with sibling content above and below", t => {
    runRoundtrip(
      t,
      `@scene: sandwich

+--------------------+
| Top text           |
| +------+           |
| | [ X ]|           |
| +------+           |
| Bottom text        |
+--------------------+
`,
    )
  })

  test("F38: container with id (format 2 standalone)", t => {
    runRoundtrip(
      t,
      `@scene: id2

+--#my-id--+
| [ Go ]   |
+----------+
`,
    )
  })

  test("F39: row with three children Start dist", t => {
    runRoundtrip(
      t,
      `@scene: trio

+-----------------------+
| [ A ] [ B ] [ C ]     |
+-----------------------+
`,
    )
  })

  test("F40: divider with id only", t => {
    runRoundtrip(
      t,
      `@scene: divid2

+--------------------+
| ---#section-1---   |
+--------------------+
`,
    )
  })
})
