// DomBuilder.res
// DOM emit for IR. Uses minimal DOM bindings; works under both browser
// and jsdom.
//
// Self-contained bindings (not shared with V1 renderer) so we can iterate
// without risk of regressing V1. design.md §15 explicitly permits duplication.

module Dom = {
  type element
  type document

  @val external document: document = "document"
  @send external createElement: (document, string) => element = "createElement"
  @send external createTextNode: (document, string) => element = "createTextNode"
  @send external appendChild: (element, element) => unit = "appendChild"
  @send external setAttribute: (element, string, string) => unit = "setAttribute"
  @set external setInnerHTML: (element, string) => unit = "innerHTML"
  @set external setChecked: (element, bool) => unit = "checked"
  @set external setSelected: (element, bool) => unit = "selected"
  @set external setValue: (element, string) => unit = "value"
}

// Apply the same canonical attribute order as HtmlBuilder so that
// DOM-mode output is structurally identical to string-mode output.
let setOrderedAttributes = (
  el: Dom.element,
  classes: array<string>,
  attrs: array<(string, string)>,
  dataAttrs: array<(string, string)>,
): unit => {
  let idAttr = ref(None)
  let others: array<(string, string)> = []
  Array.forEach(attrs, ((k, v)) =>
    if k == "id" {
      idAttr := Some(v)
    } else if k == "class" {
      ()
    } else {
      Array.push(others, (k, v))
    }
  )

  switch idAttr.contents {
  | Some(v) => Dom.setAttribute(el, "id", v)
  | None => ()
  }

  if Array.length(classes) > 0 {
    let sorted = Array.copy(classes)
    Array.sort(sorted, (a, b) => (Pervasives.compare(a, b) :> float))
    let deduped: array<string> = []
    Array.forEach(sorted, cls => {
      let last = Array.get(deduped, Array.length(deduped) - 1)
      switch last {
      | Some(prev) if prev == cls => ()
      | _ => Array.push(deduped, cls)
      }
    })
    Dom.setAttribute(el, "class", Array.join(deduped, " "))
  }

  let sortedOthers = Array.copy(others)
  Array.sort(sortedOthers, ((a, _), (b, _)) => (Pervasives.compare(a, b) :> float))
  Array.forEach(sortedOthers, ((k, v)) => Dom.setAttribute(el, k, v))

  let sortedData = Array.copy(dataAttrs)
  Array.sort(sortedData, ((a, _), (b, _)) => (Pervasives.compare(a, b) :> float))
  Array.forEach(sortedData, ((k, v)) => Dom.setAttribute(el, k, v))
}

let rec build = (node: Ir.outputNode): option<Dom.element> =>
  if node.tag === "" {
    // Transparent wrapper — build children into a fragment using a
    // pseudo-element. Callers handle this by directly appending children;
    // here we return None so the caller knows there is no single root.
    None
  } else {
    let el = Dom.createElement(Dom.document, node.tag)
    setOrderedAttributes(el, node.classes, node.attrs, node.dataAttrs)
    Array.forEach(node.children, child => appendChild(el, child))
    Some(el)
  }
and appendChild = (parent: Dom.element, child: Ir.child): unit =>
  switch child {
  | Element(n) =>
    switch build(n) {
    | Some(el) => Dom.appendChild(parent, el)
    | None =>
      // Transparent wrapper inside a parent: recurse into children.
      Array.forEach(n.children, c => appendChild(parent, c))
    }
  | Text(s) => {
      let textNode = Dom.createTextNode(Dom.document, s)
      Dom.appendChild(parent, textNode)
    }
  | Raw(s) => {
      // Use innerHTML on a wrapper span so the raw is parsed. Raw is only
      // used for already-safe content (e.g. emoji glyphs).
      let span = Dom.createElement(Dom.document, "span")
      Dom.setInnerHTML(span, s)
      // Move children out of the wrapper span so we don't pollute the tree.
      // jsdom-safe trick: just attach the wrapper; consumers see a span.
      // For determinism we keep the wrapper, since Raw is rare.
      Dom.appendChild(parent, span)
    }
  }

let mount = (root: Dom.element, node: Ir.outputNode): unit => {
  if node.tag === "" {
    Array.forEach(node.children, child => appendChild(root, child))
  } else {
    switch build(node) {
    | Some(el) => Dom.appendChild(root, el)
    | None => ()
    }
  }
}
