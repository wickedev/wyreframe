// AttrHelpers.res
// Shared helpers used by every per-node renderer.

let prefixClass = (ctx: RenderContext.t, base: string): string =>
  if ctx.options.classPrefix == "wf-" {
    base
  } else {
    // Replace leading "wf-" with classPrefix; design.md §2 keeps the default
    // as "wf-" and the option lets a host page sidestep collisions.
    let len = String.length(base)
    if len >= 3 && String.slice(base, ~start=0, ~end=3) == "wf-" {
      ctx.options.classPrefix ++ String.sliceToEnd(base, ~start=3)
    } else {
      base
    }
  }

let prefixClasses = (ctx: RenderContext.t, classes: array<string>): array<string> =>
  Array.map(classes, c => prefixClass(ctx, c))

let locationAttrs = (
  ctx: RenderContext.t,
  loc: V2Types.sourceLocation,
): array<(string, string)> =>
  if !ctx.options.includeSourceLocations {
    []
  } else {
    let attrs: array<(string, string)> = [
      ("data-wf-row", Int.toString(loc.start.row)),
      ("data-wf-col", Int.toString(loc.start.col)),
    ]
    let sameRow = loc.start.row == loc.end_.row
    let sameCol = loc.start.col == loc.end_.col
    if !(sameRow && sameCol) {
      Array.push(attrs, ("data-wf-row-end", Int.toString(loc.end_.row)))
      Array.push(attrs, ("data-wf-col-end", Int.toString(loc.end_.col)))
    }
    attrs
  }

// Handle id/data-wf-id: emit `id="<idPrefix><id>"` and `data-wf-id="<id>"`
// when the id is unique. Duplicate ids only emit data-wf-id (skip the
// real DOM id), and a DuplicateId warning is recorded.
let identityAttrs = (
  ctx: RenderContext.t,
  id: option<string>,
  loc: V2Types.sourceLocation,
): (array<(string, string)>, array<(string, string)>) => {
  switch id {
  | None => ([], [])
  | Some(idValue) => {
      let isFirst = RenderContext.recordSeenId(ctx, idValue, loc)
      let attrs = if isFirst {
        [("id", ctx.options.idPrefix ++ idValue)]
      } else {
        []
      }
      let dataAttrs = [("data-wf-id", idValue)]
      (attrs, dataAttrs)
    }
  }
}

let mergeAttrs = (
  a: array<(string, string)>,
  b: array<(string, string)>,
): array<(string, string)> => {
  let merged = Array.copy(a)
  Array.forEach(b, attr => Array.push(merged, attr))
  merged
}
