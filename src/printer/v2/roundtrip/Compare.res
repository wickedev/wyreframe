// Compare.res
// Semantic AST equality, ignoring sourceLocation and bounds.

let rec eqNode = (a: V2Types.astNode, b: V2Types.astNode): bool =>
  switch (a, b) {
  | (SceneNode(x), SceneNode(y)) =>
    x.slug == y.slug &&
    x.title == y.title &&
    x.device == y.device &&
    x.transition == y.transition &&
    eqArr(x.children, y.children) &&
    eqLayout(x.layout, y.layout)
  | (ComponentNode(x), ComponentNode(y)) =>
    x.slug == y.slug &&
    eqProps(x.props, y.props) &&
    eqArr(x.children, y.children) &&
    eqLayout(x.layout, y.layout)
  | (ContainerNode(x), ContainerNode(y)) =>
    x.id == y.id &&
    x.name == y.name &&
    eqArr(x.children, y.children) &&
    eqLayout(x.layout, y.layout)
  | (TextNode(x), TextNode(y)) =>
    x.content == y.content && x.align == y.align
  | (ButtonNode(x), ButtonNode(y)) =>
    x.id == y.id && x.text == y.text
  | (LinkNode(x), LinkNode(y)) =>
    x.id == y.id && x.text == y.text
  | (InputNode(x), InputNode(y)) => x.placeholder == y.placeholder
  | (SelectNode(x), SelectNode(y)) =>
    x.id == y.id && x.placeholder == y.placeholder
  | (CheckboxNode(x), CheckboxNode(y)) =>
    x.checked == y.checked && x.label == y.label
  | (RadioNode(x), RadioNode(y)) =>
    x.selected == y.selected && x.label == y.label && x.group == y.group
  | (DividerNode(x), DividerNode(y)) =>
    x.style == y.style && x.id == y.id && x.label == y.label
  | (StringNode(x), StringNode(y)) =>
    x.content == y.content && x.multiline == y.multiline
  | (EmojiNode(x), EmojiNode(y)) =>
    x.shortcode == y.shortcode
  | (PropPlaceholderNode(x), PropPlaceholderNode(y)) =>
    x.name == y.name && x.required == y.required && x.defaultValue == y.defaultValue
  | (ErrorNode(x), ErrorNode(y)) =>
    x.message == y.message
  | _ => false
  }

and eqArr = (xs: array<V2Types.astNode>, ys: array<V2Types.astNode>): bool => {
  if Array.length(xs) != Array.length(ys) {
    false
  } else {
    let n = Array.length(xs)
    let i = ref(0)
    let ok = ref(true)
    while ok.contents && i.contents < n {
      let x = xs->Array.getUnsafe(i.contents)
      let y = ys->Array.getUnsafe(i.contents)
      if !eqNode(x, y) {
        ok := false
      }
      i := i.contents + 1
    }
    ok.contents
  }
}

and eqProps = (
  xs: array<V2Types.propDefinition>,
  ys: array<V2Types.propDefinition>,
): bool => {
  if Array.length(xs) != Array.length(ys) {
    false
  } else {
    let n = Array.length(xs)
    let i = ref(0)
    let ok = ref(true)
    while ok.contents && i.contents < n {
      let x = xs->Array.getUnsafe(i.contents)
      let y = ys->Array.getUnsafe(i.contents)
      if x.name != y.name || x.optional != y.optional || x.defaultValue != y.defaultValue {
        ok := false
      }
      i := i.contents + 1
    }
    ok.contents
  }
}

and eqLayout = (a: V2Types.layoutInfo, b: V2Types.layoutInfo): bool =>
  a.direction == b.direction &&
  a.distribution == b.distribution &&
  Array.length(a.groups) == Array.length(b.groups)

let semanticallyEqual = (a: V2Types.astNode, b: V2Types.astNode): bool => eqNode(a, b)

let blockToAst = (block: V2Types.blockNode): V2Types.astNode =>
  switch block {
  | SceneBlock(s) => SceneNode(s)
  | ComponentBlock(c) => ComponentNode(c)
  }

let blocksEqual = (a: V2Types.blockNode, b: V2Types.blockNode): bool =>
  semanticallyEqual(blockToAst(a), blockToAst(b))
