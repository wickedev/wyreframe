// LayoutInferrer.res
// Per design.md Algorithm "Layout inference": groups address children by
// index range; never copies child nodes.

let inferLayout = (
  ~children: array<V2Types.astNode>,
  ~containerBounds: option<V2Types.bounds>=None,
  (),
): V2Types.layoutInfo => {
  let n = Array.length(children)
  if n == 0 {
    {
      direction: V2Types.Column,
      groups: [],
      distribution: None,
    }
  } else {
    // Walk children left-to-right; group consecutive children sharing the
    // same start row into one group.
    let groups: array<V2Types.elementGroup> = []
    let i = ref(0)
    while i.contents < n {
      let start = i.contents
      let startRow = (V2Types.getLocation(children->Array.getUnsafe(start))).start.row
      let j = ref(start + 1)
      let keep = ref(true)
      while keep.contents && j.contents < n {
        let row = (V2Types.getLocation(children->Array.getUnsafe(j.contents))).start.row
        if row == startRow {
          j := j.contents + 1
        } else {
          keep := false
        }
      }
      let end_ = j.contents
      let dir: V2Types.layoutDirection = if end_ - start >= 2 {
        V2Types.Row
      } else {
        V2Types.Column
      }
      groups->Array.push({
        direction: dir,
        start,
        end_,
        startRow,
      })
      i := end_
    }

    // Overall direction.
    let allRow = ref(true)
    let allCol = ref(true)
    Array.forEach(groups, (g: V2Types.elementGroup) => {
      switch g.direction {
      | V2Types.Row => allCol := false
      | V2Types.Column => allRow := false
      | V2Types.Mixed => {
          allRow := false
          allCol := false
        }
      }
    })
    let overall: V2Types.layoutDirection = if Array.length(groups) == 0 {
      V2Types.Column
    } else if Array.length(groups) == 1 {
      let g = groups->Array.getUnsafe(0)
      g.direction
    } else if allRow.contents {
      V2Types.Row
    } else if allCol.contents {
      V2Types.Column
    } else {
      V2Types.Mixed
    }

    // Distribution (best-effort) for single-row group with bounds.
    let distribution = switch (Array.length(groups), containerBounds) {
    | (1, Some(b)) => {
        let g = groups->Array.getUnsafe(0)
        if g.direction == V2Types.Row && g.end_ - g.start >= 2 {
          let innerLeft = b.x + 1
          let innerRight = b.x + b.width - 2
          let firstChild = children->Array.getUnsafe(g.start)
          let lastChild = children->Array.getUnsafe(g.end_ - 1)
          let firstStartCol = (V2Types.getLocation(firstChild)).start.col
          let lastEndCol = (V2Types.getLocation(lastChild)).end_.col
          let leftPad = firstStartCol - innerLeft
          let rightPad = innerRight - (lastEndCol - 1)
          let lp = leftPad < 0 ? 0 : leftPad
          let rp = rightPad < 0 ? 0 : rightPad
          let w = innerRight - innerLeft + 1
          if w <= 0 {
            None
          } else if lp <= 1 && rp <= 1 {
            Some(V2Types.SpaceBetween)
          } else if Math.abs(Int.toFloat(lp - rp)) <= 1.0 && lp > 1 {
            Some(V2Types.Center_)
          } else if lp <= 1 && rp > 1 {
            Some(V2Types.Start)
          } else if lp > 1 && rp <= 1 {
            Some(V2Types.End)
          } else {
            Some(V2Types.SpaceAround)
          }
        } else {
          None
        }
      }
    | _ => None
    }

    {
      direction: overall,
      groups,
      distribution,
    }
  }
}
