// RadioGrouper.res
// Algorithm 3: assign group IDs to radio nodes inside a parent.

let assignGroups = (
  radios: array<V2Types.radioNode>,
  ~parentSlug: string="parent",
  ~heuristics: Heuristics.t=Heuristics.default,
  (),
): array<V2Types.radioNode> => {
  let n = Array.length(radios)
  if n == 0 {
    radios
  } else {
    // Union-find for connected components.
    let parent = Array.fromInitializer(~length=n, i => i)
    let rec find = (i: int): int => {
      let p = parent->Array.getUnsafe(i)
      if p == i {
        i
      } else {
        let r = find(p)
        parent->Array.setUnsafe(i, r)
        r
      }
    }
    let union = (a: int, b: int) => {
      let ra = find(a)
      let rb = find(b)
      if ra != rb {
        parent->Array.setUnsafe(ra, rb)
      }
    }
    // Build edges.
    Array.forEachWithIndex(radios, (r, i) => {
      for j in i + 1 to n - 1 {
        let s = radios->Array.getUnsafe(j)
        let rRow = r.location.start.row
        let sRow = s.location.start.row
        // Horizontal: same row, close cols
        if rRow == sRow {
          let gap = Math.Int.abs(s.location.start.col - r.location.end_.col)
          if gap <= heuristics.radioHorizontalGap {
            union(i, j)
          }
        } else {
          let rowDist = Math.Int.abs(sRow - rRow)
          let colDist = Math.Int.abs(s.location.start.col - r.location.start.col)
          if rowDist <= heuristics.radioMaxBlankRows + 1 &&
            colDist <= heuristics.radioVerticalColumnTolerance {
            union(i, j)
          }
        }
      }
    })
    // Pass 1: enumerate components in document order to learn their count
    // and assign each component a stable index.
    let groupIds: Dict.t<int> = Dict.make()
    let nextId = ref(1)
    Array.forEachWithIndex(radios, (_r, i) => {
      let root = find(i)
      let key = Int.toString(root)
      switch Dict.get(groupIds, key) {
      | Some(_) => ()
      | None => {
          Dict.set(groupIds, key, nextId.contents)
          nextId := nextId.contents + 1
        }
      }
    })
    let totalGroups = nextId.contents - 1
    // Pass 2: assign names. With a single group, drop the numeric suffix
    // (`<parent>-group`). With multiple groups, always number from 1
    // (`<parent>-group-1`, `-2`, ...).
    Array.fromInitializer(~length=n, i => {
      let root = find(i)
      let key = Int.toString(root)
      let gid = Dict.get(groupIds, key)->Option.getOr(1)
      let radio = radios->Array.getUnsafe(i)
      let groupName = if totalGroups <= 1 {
        parentSlug ++ "-group"
      } else {
        `${parentSlug}-group-${Int.toString(gid)}`
      }
      {...radio, group: Some(groupName)}
    })
  }
}

// Walk a children array, gather radios at THIS level (direct radio kids only
// — containers handle their own radios in their own scope), assign groups,
// then return a children array with the updated radio nodes substituted in.
// Recursively descends into ContainerNode children so nested containers also
// get their own groupings.
let rec assignGroupsRecursive = (
  children: array<V2Types.astNode>,
  ~parentSlug: string,
  ~heuristics: Heuristics.t,
): array<V2Types.astNode> => {
  // First, recurse into containers so nested radios are grouped inside their
  // own container before we collect THIS level's direct radio children.
  let withNested = Array.map(children, (node: V2Types.astNode) =>
    switch node {
    | ContainerNode(c) => {
        let innerSlug = switch c.id {
        | Some(id) => id
        | None =>
          switch c.name {
          | Some(n) => Slugify.slugify(n)
          | None => `${parentSlug}-container`
          }
        }
        let newKids = assignGroupsRecursive(c.children, ~parentSlug=innerSlug, ~heuristics)
        V2Types.ContainerNode({...c, children: newKids})
      }
    | SceneNode(s) => {
        let newKids = assignGroupsRecursive(s.children, ~parentSlug=s.slug, ~heuristics)
        V2Types.SceneNode({...s, children: newKids})
      }
    | ComponentNode(co) => {
        let newKids = assignGroupsRecursive(co.children, ~parentSlug=co.slug, ~heuristics)
        V2Types.ComponentNode({...co, children: newKids})
      }
    | other => other
    }
  )
  // Collect direct radio children of THIS level.
  let directRadios: array<V2Types.radioNode> = []
  let directRadioIndices: array<int> = []
  Array.forEachWithIndex(withNested, (n, i) => {
    switch n {
    | RadioNode(r) => {
        directRadios->Array.push(r)
        directRadioIndices->Array.push(i)
      }
    | _ => ()
    }
  })
  if Array.length(directRadios) == 0 {
    withNested
  } else {
    let assigned = assignGroups(directRadios, ~parentSlug, ~heuristics, ())
    // Substitute assigned radios back into the children array.
    let result = Array.copy(withNested)
    Array.forEachWithIndex(directRadioIndices, (idx, k) => {
      let updated = assigned->Array.getUnsafe(k)
      result->Array.setUnsafe(idx, V2Types.RadioNode(updated))
    })
    result
  }
}
