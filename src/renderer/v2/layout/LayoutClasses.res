// LayoutClasses.res
// V2 layout categories → CSS class names. See design.md §5.

let directionClass = (dir: V2Types.layoutDirection): string =>
  switch dir {
  | Row => "wf-direction-row"
  | Column => "wf-direction-column"
  | Mixed => "wf-direction-mixed"
  }

let distributionClass = (d: V2Types.distribution): string =>
  switch d {
  | Equal => "wf-dist-equal"
  | SpaceBetween => "wf-dist-space-between"
  | SpaceAround => "wf-dist-space-around"
  | Start => "wf-dist-start"
  | End => "wf-dist-end"
  | Center_ => "wf-dist-center"
  }
