// Regressions9_test.res
// Codex-review-driven regressions, round 9.

open Vitest

let collectNodes = (block: V2Types.blockNode): array<V2Types.astNode> => {
  let acc: array<V2Types.astNode> = []
  let rec walk = (n: V2Types.astNode) => {
    acc->Array.push(n)
    switch V2Types.getChildren(n) {
    | Some(c) => Array.forEach(c, walk)
    | None => ()
    }
  }
  let root = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }
  walk(root)
  acc
}

describe("Regression P2: tab-indented container slices by visual cols (Codex round 9)", () => {
  test("tab-indented container keeps its inner text child", t => {
    // Tab at the start (tabSize=4 → tab occupies cols 0-3).
    // Visually:
    //   ....+------+
    //   ....| Hi   |
    //   ....+------+
    let src = "@scene: s\n\n\t+------+\n\t| Hi   |\n\t+------+"
    let result = V2Parser.parse(src, ())
    let containers = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | ContainerNode(c) => Some(c)
      | _ => None
      }
    )
    t->expect(Array.length(containers) >= 1)->Expect.toBe(true)
    // Find a child Text node carrying "Hi".
    let foundHi = ref(false)
    Array.forEach(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | TextNode(t) =>
        if String.includes(t.content, "Hi") {
          foundHi := true
        }
      | _ => ()
      }
    )
    t->expect(foundHi.contents)->Expect.toBe(true)
  })
})

describe("Regression P3: radio group naming (Codex round 9)", () => {
  test("two separated groups → -group-1 and -group-2", t => {
    // Two well-separated groups (more than radioMaxBlankRows blank rows apart
    // is unsafe because horizontal/vertical heuristic would still link them).
    // We separate them with a Divider line — but no easier way; use rows where
    // the columns differ beyond radioVerticalColumnTolerance.
    let src = `@scene: s

(*) A
(*) B
         (*) C
         (*) D`
    let result = V2Parser.parse(src, ())
    let radios = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | RadioNode(r) => Some(r)
      | _ => None
      }
    )
    let groups = Array.map(radios, (r: V2Types.radioNode) => r.group->Option.getOr(""))
    // 4 radios. Two distinct groups.
    t->expect(Array.length(radios))->Expect.toBe(4)
    let distinct = Belt.Set.String.fromArray(groups)
    let distinctCount = Belt.Set.String.size(distinct)
    t->expect(distinctCount)->Expect.toBe(2)
    // Both groups must follow the `-group-N` pattern (with N >= 1).
    Belt.Set.String.forEach(distinct, g => {
      let hasPattern =
        String.includes(g, "-group-1") ||
        String.includes(g, "-group-2") ||
        String.includes(g, "-group-3")
      t->expect(hasPattern)->Expect.toBe(true)
    })
  })

  test("single group → bare -group suffix", t => {
    let src = `@scene: s

(*) A
( ) B`
    let result = V2Parser.parse(src, ())
    let radios = Array.filterMap(switch result.ast {
    | Some(block) => collectNodes(block)
    | None => []
    }, n =>
      switch n {
      | RadioNode(r) => Some(r)
      | _ => None
      }
    )
    switch radios->Array.get(0) {
    | Some(r) => {
        let g = r.group->Option.getOr("")
        // Single group: no numeric suffix.
        t->expect(String.endsWith(g, "-group"))->Expect.toBe(true)
        t->expect(String.includes(g, "-group-"))->Expect.toBe(false)
      }
    | None => t->expect("no-radio")->Expect.toBe("found")
    }
  })
})
