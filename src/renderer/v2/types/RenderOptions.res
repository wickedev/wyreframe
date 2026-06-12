// RenderOptions.res
// Public configuration record for the V2 Renderer. Mirrored in V2Renderer.d.ts.

type errorHandling =
  | Skip
  | RenderMarker
  | Throw

type t = {
  classPrefix: string,
  errorHandling: errorHandling,
  componentPropValues: Dict.t<string>,
  emojiResolver: option<string => option<string>>,
  includeSourceLocations: bool,
  idPrefix: string,
  syntheticIdSalt: string,
  prettyPrint: bool,
}

let default: t = {
  classPrefix: "wf-",
  errorHandling: RenderMarker,
  componentPropValues: Dict.make(),
  emojiResolver: None,
  includeSourceLocations: true,
  idPrefix: "wf-",
  syntheticIdSalt: "v2",
  prettyPrint: false,
}

let defaultOptions = (): t => {
  ...default,
  componentPropValues: Dict.make(),
}
