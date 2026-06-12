// HtmlBuilder.res
// Deterministic string emit for IR → HTML.
//
// Design rules (design.md §8.1, §9):
// - Escape text: <, >, &, ", '
// - Escape attribute values: &, "
// - Attribute order: `id`, then `class`, then alphabetical for the rest of
//   attrs, then alphabetical for data-*
// - Class array sorted alphabetically at emit time
// - Self-closing tags: <name ... />
// - No pretty-printing by default (single-line, no extra whitespace)

let escapeText = (s: string): string => {
  let buf = StringBuffer.make()
  let len = String.length(s)
  let i = ref(0)
  while i.contents < len {
    let c = String.charAt(s, i.contents)
    switch c {
    | "&" => StringBuffer.addString(buf, "&amp;")
    | "<" => StringBuffer.addString(buf, "&lt;")
    | ">" => StringBuffer.addString(buf, "&gt;")
    | "\"" => StringBuffer.addString(buf, "&quot;")
    | "'" => StringBuffer.addString(buf, "&#39;")
    | _ => StringBuffer.addString(buf, c)
    }
    i := i.contents + 1
  }
  StringBuffer.contents(buf)
}

let escapeAttr = (s: string): string => {
  let buf = StringBuffer.make()
  let len = String.length(s)
  let i = ref(0)
  while i.contents < len {
    let c = String.charAt(s, i.contents)
    switch c {
    | "&" => StringBuffer.addString(buf, "&amp;")
    | "\"" => StringBuffer.addString(buf, "&quot;")
    | _ => StringBuffer.addString(buf, c)
    }
    i := i.contents + 1
  }
  StringBuffer.contents(buf)
}

// Deterministic attribute order:
//   1) id  (if present)
//   2) class (if present and class list non-empty)
//   3) remaining attrs sorted alphabetically by name
//   4) data-* attrs sorted alphabetically by name
//
// The class list (within the class attribute) is sorted alphabetically and
// deduped.
let writeAttrs = (
  buf: StringBuffer.t,
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
      // Class is built from `classes` array. Ignore explicit attribute.
      ()
    } else {
      Array.push(others, (k, v))
    }
  )

  switch idAttr.contents {
  | Some(v) => {
      StringBuffer.addString(buf, " id=\"")
      StringBuffer.addString(buf, escapeAttr(v))
      StringBuffer.addString(buf, "\"")
    }
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
    StringBuffer.addString(buf, " class=\"")
    StringBuffer.addString(buf, escapeAttr(Array.join(deduped, " ")))
    StringBuffer.addString(buf, "\"")
  }

  let sortedOthers = Array.copy(others)
  Array.sort(sortedOthers, ((a, _), (b, _)) => (Pervasives.compare(a, b) :> float))
  Array.forEach(sortedOthers, ((k, v)) => {
    StringBuffer.addString(buf, " ")
    StringBuffer.addString(buf, k)
    StringBuffer.addString(buf, "=\"")
    StringBuffer.addString(buf, escapeAttr(v))
    StringBuffer.addString(buf, "\"")
  })

  let sortedData = Array.copy(dataAttrs)
  Array.sort(sortedData, ((a, _), (b, _)) => (Pervasives.compare(a, b) :> float))
  Array.forEach(sortedData, ((k, v)) => {
    StringBuffer.addString(buf, " ")
    StringBuffer.addString(buf, k)
    StringBuffer.addString(buf, "=\"")
    StringBuffer.addString(buf, escapeAttr(v))
    StringBuffer.addString(buf, "\"")
  })
}

let rec writeNode = (buf: StringBuffer.t, node: Ir.outputNode): unit =>
  if node.tag === "" {
    // Empty IR = transparent wrapper; render children only.
    Array.forEach(node.children, child => writeChild(buf, child))
  } else {
    StringBuffer.addString(buf, "<")
    StringBuffer.addString(buf, node.tag)
    writeAttrs(buf, node.classes, node.attrs, node.dataAttrs)

    if node.selfClosing && Array.length(node.children) == 0 {
      StringBuffer.addString(buf, " />")
    } else {
      StringBuffer.addString(buf, ">")
      Array.forEach(node.children, child => writeChild(buf, child))
      StringBuffer.addString(buf, "</")
      StringBuffer.addString(buf, node.tag)
      StringBuffer.addString(buf, ">")
    }
  }
and writeChild = (buf: StringBuffer.t, child: Ir.child): unit =>
  switch child {
  | Element(node) => writeNode(buf, node)
  | Text(s) => StringBuffer.addString(buf, escapeText(s))
  | Raw(s) => StringBuffer.addString(buf, s)
  }

let emit = (node: Ir.outputNode): string => {
  let buf = StringBuffer.make()
  writeNode(buf, node)
  StringBuffer.contents(buf)
}

let emitChildren = (children: array<Ir.child>): string => {
  let buf = StringBuffer.make()
  Array.forEach(children, child => writeChild(buf, child))
  StringBuffer.contents(buf)
}
