// Core type definitions for Wyreframe parser
// These types represent the parsed AST structure

// Position in the grid (row, col)
module rec Position: {
  type t = {
    row: int,
    col: int,
  }

  let make: (int, int) => t
  let right: (t, ~n: int=?) => t
  let down: (t, ~n: int=?) => t
  let left: (t, ~n: int=?) => t
  let up: (t, ~n: int=?) => t
  let equals: (t, t) => bool
  let isWithin: (t, Bounds.t) => bool
  let toString: t => string
} = {
  type t = {
    row: int,
    col: int,
  }

  let make = (row: int, col: int): t => {row, col}

  // Move right by n columns (default: 1)
  let right = (pos: t, ~n: int=1): t => {
    {row: pos.row, col: pos.col + n}
  }

  // Move down by n rows (default: 1)
  let down = (pos: t, ~n: int=1): t => {
    {row: pos.row + n, col: pos.col}
  }

  // Move left by n columns (default: 1)
  let left = (pos: t, ~n: int=1): t => {
    {row: pos.row, col: pos.col - n}
  }

  // Move up by n rows (default: 1)
  let up = (pos: t, ~n: int=1): t => {
    {row: pos.row - n, col: pos.col}
  }

  let equals = (a: t, b: t): bool => a.row == b.row && a.col == b.col

  // Check if position is within given bounds (inclusive)
  let isWithin = (pos: t, bounds: Bounds.t): bool => {
    pos.row >= bounds.top &&
    pos.row <= bounds.bottom &&
    pos.col >= bounds.left &&
    pos.col <= bounds.right
  }

  let toString = (pos: t): string => `(${Int.toString(pos.row)}, ${Int.toString(pos.col)})`
}

// Bounding box
and Bounds: {
  type t = {
    top: int,
    left: int,
    bottom: int,
    right: int,
  }

  let make: (~top: int, ~left: int, ~bottom: int, ~right: int) => t
  let width: t => int
  let height: t => int
  let area: t => int
  let contains: (t, t) => bool
  let overlaps: (t, t) => bool
  let equals: (t, t) => bool
} = {
  type t = {
    top: int,
    left: int,
    bottom: int,
    right: int,
  }

  let make = (~top: int, ~left: int, ~bottom: int, ~right: int): t => {
    top,
    left,
    bottom,
    right,
  }

  let width = (bounds: t): int => bounds.right - bounds.left
  let height = (bounds: t): int => bounds.bottom - bounds.top
  let area = (bounds: t): int => width(bounds) * height(bounds)

  // Strict containment - inner must be strictly inside outer (not touching edges)
  let contains = (outer: t, inner: t): bool => {
    outer.top < inner.top &&
    outer.left < inner.left &&
    outer.bottom > inner.bottom &&
    outer.right > inner.right
  }

  let overlaps = (a: t, b: t): bool => {
    !(a.right < b.left || b.right < a.left || a.bottom < b.top || b.bottom < a.top)
  }

  let equals = (a: t, b: t): bool => {
    a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right
  }
}

// Cell character types for grid representation
type cellChar =
  | Corner // '+'
  | HLine  // '-'
  | VLine  // '|'
  | Divider // '='
  | Space  // ' '
  | Char(string) // Any other character

// Alignment type
type alignment =
  | Left
  | Center
  | Right

// Forward declaration of action type for use in elements
type rec interactionAction =
  | Goto({
      target: string,
      transition: string,
      condition: option<string>,
    })
  | Back
  | Forward
  | Validate({fields: array<string>})
  | Call({
      function: string,
      args: array<string>,
      condition: option<string>,
    })

// Element types
and element =
  | Box({
      name: option<string>,
      bounds: Bounds.t,
      children: array<element>,
    })
  | Button({
      id: string,
      text: string,
      position: Position.t,
      align: alignment,
      actions: array<interactionAction>,
    })
  | Input({
      id: string,
      placeholder: option<string>,
      position: Position.t,
    })
  | Link({
      id: string,
      text: string,
      position: Position.t,
      align: alignment,
      actions: array<interactionAction>,
    })
  | Checkbox({
      checked: bool,
      label: string,
      position: Position.t,
    })
  | Text({
      content: string,
      emphasis: bool,
      position: Position.t,
      align: alignment,
    })
  | Divider({
      position: Position.t,
    })
  | Spacer({
      position: Position.t,
    })
  | Row({
      children: array<element>,
      align: alignment,
    })
  | Section({
      name: string,
      children: array<element>,
    })

// Device type for responsive wireframes
type deviceType =
  | Desktop      // 1440x900 (16:10)
  | Laptop       // 1280x800 (16:10)
  | Tablet       // 768x1024 (3:4)
  | TabletLandscape // 1024x768 (4:3)
  | Mobile       // 375x812 (iPhone X ratio)
  | MobileLandscape // 812x375
  | Custom(int, int) // width, height

// Device dimensions record
type deviceDimensions = {
  width: int,
  height: int,
  ratio: float,
  name: string,
}

// Get dimensions for a device type
let getDeviceDimensions = (device: deviceType): deviceDimensions => {
  switch device {
  | Desktop => {width: 1440, height: 900, ratio: 16.0 /. 10.0, name: "desktop"}
  | Laptop => {width: 1280, height: 800, ratio: 16.0 /. 10.0, name: "laptop"}
  | Tablet => {width: 768, height: 1024, ratio: 3.0 /. 4.0, name: "tablet"}
  | TabletLandscape => {width: 1024, height: 768, ratio: 4.0 /. 3.0, name: "tablet-landscape"}
  | Mobile => {width: 375, height: 812, ratio: 375.0 /. 812.0, name: "mobile"}
  | MobileLandscape => {width: 812, height: 375, ratio: 812.0 /. 375.0, name: "mobile-landscape"}
  | Custom(w, h) => {
      width: w,
      height: h,
      ratio: Int.toFloat(w) /. Int.toFloat(h),
      name: "custom-" ++ Int.toString(w) ++ "x" ++ Int.toString(h),
    }
  }
}

// Parse device type from string
let parseDeviceType = (str: string): option<deviceType> => {
  let normalized = str->String.trim->String.toLowerCase
  switch normalized {
  | "desktop" => Some(Desktop)
  | "laptop" => Some(Laptop)
  | "tablet" => Some(Tablet)
  | "tablet-landscape" | "tabletlandscape" => Some(TabletLandscape)
  | "mobile" | "phone" => Some(Mobile)
  | "mobile-landscape" | "mobilelandscape" | "phone-landscape" => Some(MobileLandscape)
  | _ => {
      // Try to parse custom format: "WxH" or "W x H"
      let customPattern = %re("/^(\d+)\s*x\s*(\d+)$/i")
      switch Js.Re.exec_(customPattern, normalized) {
      | Some(result) => {
          let captures = Js.Re.captures(result)
          switch (captures->Array.get(1), captures->Array.get(2)) {
          | (Some(wNullable), Some(hNullable)) =>
            switch (Js.Nullable.toOption(wNullable), Js.Nullable.toOption(hNullable)) {
            | (Some(wStr), Some(hStr)) =>
              switch (Int.fromString(wStr), Int.fromString(hStr)) {
              | (Some(w), Some(h)) => Some(Custom(w, h))
              | _ => None
              }
            | _ => None
            }
          | _ => None
          }
        }
      | None => None
      }
    }
  }
}

// Scene definition
type scene = {
  id: string,
  title: string,
  transition: string,
  device: deviceType,
  elements: array<element>,
}

// Complete AST
type ast = {
  scenes: array<scene>,
}

// Helper functions for elements
let getElementType = (elem: element): string => {
  switch elem {
  | Box(_) => "Box"
  | Button(_) => "Button"
  | Input(_) => "Input"
  | Link(_) => "Link"
  | Checkbox(_) => "Checkbox"
  | Text(_) => "Text"
  | Divider(_) => "Divider"
  | Spacer(_) => "Spacer"
  | Row(_) => "Row"
  | Section(_) => "Section"
  }
}

let getElementId = (elem: element): option<string> => {
  switch elem {
  | Button({id}) => Some(id)
  | Input({id}) => Some(id)
  | Link({id}) => Some(id)
  | Box({name}) => name
  | Section({name}) => Some(name)
  | _ => None
  }
}

// ============================================================================
// Interaction DSL Types
// ============================================================================

/**
 * Interaction variant types for styling and behavior categorization.
 */
type interactionVariant =
  | Primary // Primary action button
  | Secondary // Secondary action button
  | Ghost // Ghost/subtle button style

/**
 * Represents an interaction definition for a specific element.
 * Interactions define behavior, properties, and actions for elements.
 */
type interaction = {
  elementId: string, // ID of the element this interaction applies to
  properties: Js.Dict.t<Js.Json.t>, // Additional properties (variant, disabled, etc.)
  actions: array<interactionAction>, // Actions triggered by events
}

/**
 * Groups all interactions for a specific scene.
 */
type sceneInteractions = {
  sceneId: string, // Scene identifier
  interactions: array<interaction>, // All interactions in this scene
}
