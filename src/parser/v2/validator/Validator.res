// Validator.res
// Cross-cutting checks against an assembled block.
// Per design.md §Component 7.

let walkAst = (root: V2Types.astNode, f: V2Types.astNode => unit): unit => {
  let rec go = (node: V2Types.astNode) => {
    f(node)
    switch V2Types.getChildren(node) {
    | Some(children) => Array.forEach(children, go)
    | None => ()
    }
  }
  go(root)
}

let validate = (
  block: V2Types.blockNode,
): (array<V2Errors.parseError>, array<V2Errors.parseWarning>) => {
  let errs: array<V2Errors.parseError> = []
  let warns: array<V2Errors.parseWarning> = []

  let root: V2Types.astNode = switch block {
  | SceneBlock(s) => V2Types.SceneNode(s)
  | ComponentBlock(c) => V2Types.ComponentNode(c)
  }

  // Collect declared props (Component only).
  let declaredProps: Dict.t<bool> = Dict.make()
  switch block {
  | ComponentBlock(c) =>
    Array.forEach(c.props, (p: V2Types.propDefinition) => Dict.set(declaredProps, p.name, true))
  | SceneBlock(_) => ()
  }

  let seenIds: Dict.t<int> = Dict.make()
  let radioGroups: Dict.t<int> = Dict.make()
  // For MultipleRadiosSelected: remember the source location of a radio in
  // each group so the warning points at the conflicting controls, not zeroLoc.
  let radioGroupLoc: Dict.t<V2Types.sourceLocation> = Dict.make()

  // Check a propPlaceholderNode for unknown prop references (component-only).
  let checkPropRef = (p: V2Types.propPlaceholderNode) => {
    let isComponent = switch block {
    | ComponentBlock(_) => true
    | _ => false
    }
    if isComponent && Dict.get(declaredProps, p.name) == None {
      warns->Array.push(
        V2Errors.makeWarning(
          ~code=UnknownPropReference(p.name),
          ~location=p.location,
          (),
        ),
      )
    }
  }

  // Track every node that exposes an auto-generated id (Container / Button /
  // Link / Select). Per tasks.md 32.2, a duplicate slug within a block emits
  // DuplicateContainerId; the code name is "container id" historically but
  // serves as the generic "duplicate-element-id" warning.
  let checkDupId = (id: string, loc: V2Types.sourceLocation) => {
    let count = Dict.get(seenIds, id)->Option.getOr(0)
    if count > 0 {
      warns->Array.push(
        V2Errors.makeWarning(~code=DuplicateContainerId(id), ~location=loc, ()),
      )
    }
    Dict.set(seenIds, id, count + 1)
  }
  walkAst(root, node => {
    switch node {
    | ContainerNode(c) =>
      switch c.id {
      | Some(id) => checkDupId(id, c.location)
      | None => ()
      }
    | ButtonNode(b) => checkDupId(b.id, b.location)
    | LinkNode(l) => checkDupId(l.id, l.location)
    | SelectNode(s) => checkDupId(s.id, s.location)
    | PropPlaceholderNode(p) => checkPropRef(p)
    | StringNode(s) =>
      // PropRefs inside `"...${name}..."` are stored in interpolations and
      // do NOT appear as standalone PropPlaceholderNode entries — they
      // would otherwise be missed by the validator. Walk the segments.
      Array.forEach(s.interpolations, (seg: V2Types.interpolationContent) =>
        switch seg {
        | PropRef(p) => checkPropRef(p)
        | _ => ()
        }
      )
    | RadioNode(r) =>
      switch r.group {
      | Some(g) => {
          let n = Dict.get(radioGroups, g)->Option.getOr(0)
          Dict.set(radioGroups, g, n + (r.selected ? 1 : 0))
          // Remember the first SELECTED radio's location for the warning.
          if r.selected && Dict.get(radioGroupLoc, g) == None {
            Dict.set(radioGroupLoc, g, r.location)
          }
        }
      | None => ()
      }
    | TextNode(tn) => {
        // Near-miss detection: text content that looks like an element
        // start but failed to match the actual parser (e.g. `[Save` with
        // no closing `]`). Emit `LooksLike*` warning with the
        // `nearMissPatterns` ruleId so users/IDEs can hint the user.
        let c = tn.content
        let ruleId = Heuristics.Rule.nearMissPatterns
        let emit = code =>
          warns->Array.push(
            V2Errors.makeWarning(~code, ~location=tn.location, ~ruleId, ()),
          )
        if String.startsWith(c, "[") && !String.includes(c, "]") {
          // Disambiguate the bracket near-miss by what follows.
          if String.startsWith(c, "[__") {
            emit(LooksLikeInput)
          } else if String.length(c) >= 2 {
            let ch1 = String.charAt(c, 1)
            if ch1 == "x" || ch1 == "X" || ch1 == "v" || ch1 == "V" || ch1 == " " {
              emit(LooksLikeCheckbox)
            } else {
              emit(LooksLikeButton)
            }
          } else {
            emit(LooksLikeButton)
          }
        } else if String.startsWith(c, "(") && !String.includes(c, ")") {
          emit(LooksLikeRadio)
        }
      }
    | _ => ()
    }
  })

  // Multiple radios selected per group?
  Dict.forEachWithKey(radioGroups, (count, g) => {
    if count >= 2 {
      let loc = Dict.get(radioGroupLoc, g)->Option.getOr(V2Types.zeroLoc)
      warns->Array.push(
        V2Errors.makeWarning(
          ~code=MultipleRadiosSelected(g),
          ~location=loc,
          (),
        ),
      )
    }
  })

  (errs, warns)
}
