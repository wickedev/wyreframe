// Ir.res
// Intermediate Representation for renderer output, shared between
// HtmlBuilder (string mode) and DomBuilder (DOM mode).
//
// Determinism notes (design.md §9):
// - Class array order: alphabetical within an element, sorted at emit time
// - Attribute order: id, class, then alphabetical for everything else,
//   then alphabetical for data-* (see HtmlBuilder)
// - Children: AST document order (the renderer never reorders).

type rec outputNode = {
  tag: string,
  classes: array<string>,
  attrs: array<(string, string)>,
  dataAttrs: array<(string, string)>,
  children: array<child>,
  selfClosing: bool,
}
and child =
  | Element(outputNode)
  | Text(string)
  | Raw(string)

let make = (
  ~tag: string,
  ~classes: array<string>=[],
  ~attrs: array<(string, string)>=[],
  ~dataAttrs: array<(string, string)>=[],
  ~children: array<child>=[],
  ~selfClosing: bool=false,
  (),
): outputNode => {
  tag,
  classes,
  attrs,
  dataAttrs,
  children,
  selfClosing,
}

let empty = (): outputNode => make(~tag="", ())

let isEmpty = (node: outputNode): bool => node.tag === ""
