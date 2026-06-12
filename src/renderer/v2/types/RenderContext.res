// RenderContext.res
// Internal mutable state threaded through the render pass.
// design.md §7.

type containerDirection = V2Types.layoutDirection

type t = {
  options: RenderOptions.t,
  // ID dedupe: set of explicit ids already emitted in the current render.
  seenIds: Dict.t<bool>,
  warnings: array<RenderWarning.t>,
  // Pre-computed radio group names by source position key
  // (key = `${row}:${col}`).
  radioGroups: Dict.t<string>,
  // Component prop values precomputed (defaults applied).
  propValues: Dict.t<string>,
  // Stack of parent container directions, used by TextRenderer to
  // pick between <p> (block) and <span> (inline) when inside a Row.
  parentDirectionStack: array<containerDirection>,
}

let make = (~options: RenderOptions.t): t => {
  options,
  seenIds: Dict.make(),
  warnings: [],
  radioGroups: Dict.make(),
  propValues: Dict.make(),
  parentDirectionStack: [],
}

let positionKey = (loc: V2Types.sourceLocation): string =>
  Int.toString(loc.start.row) ++ ":" ++ Int.toString(loc.start.col)

let recordSeenId = (ctx: t, id: string, loc: V2Types.sourceLocation): bool =>
  switch Dict.get(ctx.seenIds, id) {
  | Some(_) => {
      Array.push(ctx.warnings, RenderWarning.DuplicateId(id, loc))
      false
    }
  | None => {
      Dict.set(ctx.seenIds, id, true)
      true
    }
  }

let pushDirection = (ctx: t, dir: containerDirection): t => {
  let next = Array.copy(ctx.parentDirectionStack)
  Array.push(next, dir)
  {...ctx, parentDirectionStack: next}
}

let currentDirection = (ctx: t): option<containerDirection> => {
  let len = Array.length(ctx.parentDirectionStack)
  if len == 0 {
    None
  } else {
    Array.get(ctx.parentDirectionStack, len - 1)
  }
}
