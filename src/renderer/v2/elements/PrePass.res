// PrePass.res
// Single AST walk that populates RenderContext fields before the main
// render pass starts. design.md §7.
//
// Computed:
// - radioGroups: contiguous Radio siblings inside the same parent become
//   one group (design.md §6).
//
// Note: ID dedupe is handled inline during render rather than here, so
// that radio synthetic group names can also rely on positions deterministically.

let radioPositionKey = (loc: V2Types.sourceLocation): string =>
  Int.toString(loc.start.row) ++ ":" ++ Int.toString(loc.start.col)

let rec walkRadioGroups = (
  ctx: RenderContext.t,
  children: array<V2Types.astNode>,
): unit => {
  // Sliding window of consecutive Radio siblings.
  let group: array<V2Types.radioNode> = []
  let flush = () =>
    if Array.length(group) > 0 {
      let first = Array.getUnsafe(group, 0)
      let name = switch first.group {
      | Some(g) => g
      | None =>
        ctx.options.idPrefix ++
        "radio-" ++
        ctx.options.syntheticIdSalt ++
        "-" ++
        Int.toString(first.location.start.row) ++
        "-" ++
        Int.toString(first.location.start.col)
      }
      Array.forEach(group, r => Dict.set(ctx.radioGroups, radioPositionKey(r.location), name))
      // Clear group (mutate by re-assigning length)
      while Array.length(group) > 0 {
        let _ = Array.pop(group)
      }
    }

  Array.forEach(children, child => {
    switch child {
    | V2Types.RadioNode(r) => Array.push(group, r)
    | _ => {
        flush()
        // Recurse into children of any node that has them.
        switch V2Types.getChildren(child) {
        | Some(grand) => walkRadioGroups(ctx, grand)
        | None => ()
        }
      }
    }
  })
  flush()
}

let run = (ctx: RenderContext.t, root: V2Types.astNode): unit => {
  // The root itself may be a Scene/Component/Container with children.
  switch V2Types.getChildren(root) {
  | Some(children) => walkRadioGroups(ctx, children)
  | None => ()
  }
}
