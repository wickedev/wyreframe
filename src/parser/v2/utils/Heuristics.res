// Heuristics.res
// Central source of all parser tolerances and thresholds.
// Per design.md §Heuristics Catalog, requirements.md REQ-23.

type t = {
  // -- Grid alignment --
  containerColumnTolerance: int,
  containerWidthTolerance: int,
  // -- Radio grouping --
  radioHorizontalGap: int,
  radioVerticalColumnTolerance: int,
  radioMaxBlankRows: int,
  // -- Text alignment --
  centerSymmetryThreshold: float,
  rightAlignThreshold: float,
  // -- Divider --
  dividerMinRun: int,
  // -- Near-miss detection --
  nearMissTokenDistance: int,
}

let default: t = {
  containerColumnTolerance: 1,
  containerWidthTolerance: 2,
  radioHorizontalGap: 6,
  radioVerticalColumnTolerance: 1,
  radioMaxBlankRows: 0,
  centerSymmetryThreshold: 0.15,
  rightAlignThreshold: 0.10,
  dividerMinRun: 3,
  nearMissTokenDistance: 1,
}

// A partial heuristics override. Every field is optional; missing fields
// fall back to `default`. Per REQ-23.3.
type partial = {
  containerColumnTolerance: option<int>,
  containerWidthTolerance: option<int>,
  radioHorizontalGap: option<int>,
  radioVerticalColumnTolerance: option<int>,
  radioMaxBlankRows: option<int>,
  centerSymmetryThreshold: option<float>,
  rightAlignThreshold: option<float>,
  dividerMinRun: option<int>,
  nearMissTokenDistance: option<int>,
}

let emptyPartial: partial = {
  containerColumnTolerance: None,
  containerWidthTolerance: None,
  radioHorizontalGap: None,
  radioVerticalColumnTolerance: None,
  radioMaxBlankRows: None,
  centerSymmetryThreshold: None,
  rightAlignThreshold: None,
  dividerMinRun: None,
  nearMissTokenDistance: None,
}

// JS-side ints/floats may arrive as `undefined` when the caller spelled
// the field name wrong or omitted it. The %raw shim normalizes that to a
// proper `partial` with all fields = None when missing — so applyPartial
// can stay simple ReScript.
let normalizePartial: partial => partial = %raw(`
  function(p) {
    if (p === undefined || p === null) {
      return {
        containerColumnTolerance: undefined,
        containerWidthTolerance: undefined,
        radioHorizontalGap: undefined,
        radioVerticalColumnTolerance: undefined,
        radioMaxBlankRows: undefined,
        centerSymmetryThreshold: undefined,
        rightAlignThreshold: undefined,
        dividerMinRun: undefined,
        nearMissTokenDistance: undefined,
      };
    }
    return p;
  }
`)

// Merge a partial override on top of a base `t`. Unspecified fields keep
// the base value.
let applyPartial = (p: partial, base: t): t => {
  let p = normalizePartial(p)
  {
    containerColumnTolerance: p.containerColumnTolerance->Option.getOr(base.containerColumnTolerance),
    containerWidthTolerance: p.containerWidthTolerance->Option.getOr(base.containerWidthTolerance),
    radioHorizontalGap: p.radioHorizontalGap->Option.getOr(base.radioHorizontalGap),
    radioVerticalColumnTolerance: p.radioVerticalColumnTolerance->Option.getOr(
      base.radioVerticalColumnTolerance,
    ),
    radioMaxBlankRows: p.radioMaxBlankRows->Option.getOr(base.radioMaxBlankRows),
    centerSymmetryThreshold: p.centerSymmetryThreshold->Option.getOr(base.centerSymmetryThreshold),
    rightAlignThreshold: p.rightAlignThreshold->Option.getOr(base.rightAlignThreshold),
    dividerMinRun: p.dividerMinRun->Option.getOr(base.dividerMinRun),
    nearMissTokenDistance: p.nearMissTokenDistance->Option.getOr(base.nearMissTokenDistance),
  }
}

// Make a full `t` from an optional partial override (no override → default).
let make = (~overrides: option<partial>=?, ()): t =>
  switch overrides {
  | Some(o) => applyPartial(o, default)
  | None => default
  }

// Stable rule-id constants.
module Rule = {
  let containerCornerAlignment = "container.cornerAlignment"
  let containerWallAlignment = "container.wallAlignment"
  let containerWidthConsistency = "container.widthConsistency"
  let radioGroupingHorizontal = "radioGrouping.horizontal"
  let radioGroupingVertical = "radioGrouping.vertical"
  let radioGroupingContainer = "radioGrouping.container"
  let textCenter = "text.center"
  let textRight = "text.right"
  let dividerMinRun = "divider.minRun"
  let nearMissPatterns = "nearMissPatterns"
  let errorRecoveryContainerSync = "errorRecovery.containerSync"
  let errorRecoveryInputSync = "errorRecovery.inputSync"
}
