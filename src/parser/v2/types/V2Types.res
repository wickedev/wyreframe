// V2Types.res
// Core AST type definitions for Wyreframe Syntax v2.3 Parser.
// Per design.md §Data Model. All position fields use {row, col, offset} (0-based).

type position = {
  row: int,
  col: int,
  offset: int,
}

type sourceLocation = {
  start: position,
  end_: position,
}

let zeroPos = {row: 0, col: 0, offset: 0}
let zeroLoc = {start: zeroPos, end_: zeroPos}

type nodeType =
  | Scene
  | Component
  | Container
  | Text
  | Button
  | Link
  | Input
  | Select
  | Checkbox
  | Radio
  | Divider
  | String
  | Emoji
  | PropPlaceholder
  | Error

type deviceType =
  | Mobile
  | Tablet
  | Desktop

type propDefinition = {
  name: string,
  optional: bool,
  defaultValue: option<string>,
}

type layoutDirection =
  | Row
  | Column
  | Mixed

type alignment =
  | Left
  | Center
  | Right

type dividerStyle =
  | Normal
  | Bold

type bounds = {
  x: int,
  y: int,
  width: int,
  height: int,
}

type rec layoutInfo = {
  direction: layoutDirection,
  groups: array<elementGroup>,
  distribution: option<distribution>,
}

and elementGroup = {
  direction: layoutDirection,
  start: int,
  end_: int,
  startRow: int,
}

and distribution =
  | Equal
  | SpaceBetween
  | SpaceAround
  | Start
  | End
  | Center_

and astNode =
  | SceneNode(sceneNode)
  | ComponentNode(componentNode)
  | ContainerNode(containerNode)
  | TextNode(textNode)
  | ButtonNode(buttonNode)
  | LinkNode(linkNode)
  | InputNode(inputNode)
  | SelectNode(selectNode)
  | CheckboxNode(checkboxNode)
  | RadioNode(radioNode)
  | DividerNode(dividerNode)
  | StringNode(stringNode)
  | EmojiNode(emojiNode)
  | PropPlaceholderNode(propPlaceholderNode)
  | ErrorNode(errorNode)

and sceneNode = {
  location: sourceLocation,
  slug: string,
  title: option<string>,
  device: option<deviceType>,
  transition: option<string>,
  children: array<astNode>,
  layout: layoutInfo,
}

and componentNode = {
  location: sourceLocation,
  slug: string,
  props: array<propDefinition>,
  children: array<astNode>,
  layout: layoutInfo,
}

and containerNode = {
  location: sourceLocation,
  id: option<string>,
  name: option<string>,
  children: array<astNode>,
  layout: layoutInfo,
  bounds: bounds,
  containsErrorRecovery: bool,
}

and textNode = {
  location: sourceLocation,
  content: string,
  align: alignment,
}

and buttonNode = {
  location: sourceLocation,
  id: string,
  text: string,
}

and linkNode = {
  location: sourceLocation,
  id: string,
  text: string,
}

and inputNode = {
  location: sourceLocation,
  placeholder: string,
}

and selectNode = {
  location: sourceLocation,
  id: string,
  placeholder: string,
}

and checkboxNode = {
  location: sourceLocation,
  checked: bool,
  label: string,
}

and radioNode = {
  location: sourceLocation,
  selected: bool,
  label: string,
  group: option<string>,
}

and dividerNode = {
  location: sourceLocation,
  style: dividerStyle,
  id: option<string>,
  label: option<string>,
}

and interpolationContent =
  | Literal(string)
  | PropRef(propPlaceholderNode)
  | EmojiRef(emojiNode)

and stringNode = {
  location: sourceLocation,
  content: string,
  interpolations: array<interpolationContent>,
  multiline: bool,
}

and emojiNode = {
  location: sourceLocation,
  shortcode: string,
  emoji: string,
}

and propPlaceholderNode = {
  location: sourceLocation,
  name: string,
  required: bool,
  defaultValue: option<string>,
}

and errorNode = {
  location: sourceLocation,
  message: string,
  recoveredContent: option<string>,
}

type blockNode =
  | SceneBlock(sceneNode)
  | ComponentBlock(componentNode)

let getLocation = (node: astNode): sourceLocation =>
  switch node {
  | SceneNode(n) => n.location
  | ComponentNode(n) => n.location
  | ContainerNode(n) => n.location
  | TextNode(n) => n.location
  | ButtonNode(n) => n.location
  | LinkNode(n) => n.location
  | InputNode(n) => n.location
  | SelectNode(n) => n.location
  | CheckboxNode(n) => n.location
  | RadioNode(n) => n.location
  | DividerNode(n) => n.location
  | StringNode(n) => n.location
  | EmojiNode(n) => n.location
  | PropPlaceholderNode(n) => n.location
  | ErrorNode(n) => n.location
  }

let getNodeType = (node: astNode): nodeType =>
  switch node {
  | SceneNode(_) => Scene
  | ComponentNode(_) => Component
  | ContainerNode(_) => Container
  | TextNode(_) => Text
  | ButtonNode(_) => Button
  | LinkNode(_) => Link
  | InputNode(_) => Input
  | SelectNode(_) => Select
  | CheckboxNode(_) => Checkbox
  | RadioNode(_) => Radio
  | DividerNode(_) => Divider
  | StringNode(_) => String
  | EmojiNode(_) => Emoji
  | PropPlaceholderNode(_) => PropPlaceholder
  | ErrorNode(_) => Error
  }

let isBlockNode = (node: astNode): bool =>
  switch node {
  | SceneNode(_) | ComponentNode(_) => true
  | _ => false
  }

let getChildren = (node: astNode): option<array<astNode>> =>
  switch node {
  | SceneNode(n) => Some(n.children)
  | ComponentNode(n) => Some(n.children)
  | ContainerNode(n) => Some(n.children)
  | _ => None
  }

let emptyLayout: layoutInfo = {
  direction: Column,
  groups: [],
  distribution: None,
}
