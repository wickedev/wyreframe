/**
 * Hand-rolled TypeScript declarations for the v2 parser export.
 *
 * The runtime values are ReScript variants encoded as `{TAG, _0, ...}`.
 * These declarations mirror the public surface area documented in
 * .claude/specs/syntax-v2-parser/design.md (V2Types, V2Errors, V2Parser).
 *
 * Consumers should treat AST node fields as read-only; the parser never
 * mutates AST records after construction.
 */

// ---------- Positions / locations ----------

export interface Position {
  /** 0-based row (line index) */
  row: number;
  /** 0-based visual column (Unicode + tab-aware) */
  col: number;
  /** 0-based byte/UTF-16 offset into source */
  offset: number;
}

export interface SourceLocation {
  start: Position;
  /** Exclusive end position */
  end_: Position;
}

// ---------- Node-level enumerations ----------

export type DeviceType = "Mobile" | "Tablet" | "Desktop";
export type Alignment = "Left" | "Center" | "Right";
export type DividerStyle = "Normal" | "Bold";
export type LayoutDirection = "Row" | "Column" | "Mixed";
export type Distribution =
  | "Equal"
  | "SpaceBetween"
  | "SpaceAround"
  | "Start"
  | "End"
  | "Center_";

// ---------- Layout ----------

export interface ElementGroup {
  direction: LayoutDirection;
  /** Inclusive start index into the parent's children array */
  start: number;
  /** Exclusive end index */
  end_: number;
  startRow: number;
}

export interface LayoutInfo {
  direction: LayoutDirection;
  groups: ElementGroup[];
  distribution?: Distribution;
}

// ---------- AST nodes ----------

export interface Bounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface PropDefinition {
  name: string;
  optional: boolean;
  defaultValue?: string;
}

export interface SceneNode {
  TAG: "SceneNode";
  _0: {
    location: SourceLocation;
    slug: string;
    title?: string;
    device?: DeviceType;
    transition?: string;
    children: AstNode[];
    layout: LayoutInfo;
  };
}

export interface ComponentNode {
  TAG: "ComponentNode";
  _0: {
    location: SourceLocation;
    slug: string;
    props: PropDefinition[];
    children: AstNode[];
    layout: LayoutInfo;
  };
}

export interface ContainerNode {
  TAG: "ContainerNode";
  _0: {
    location: SourceLocation;
    id?: string;
    name?: string;
    children: AstNode[];
    layout: LayoutInfo;
    bounds: Bounds;
    containsErrorRecovery: boolean;
  };
}

export interface TextNode {
  TAG: "TextNode";
  _0: { location: SourceLocation; content: string; align: Alignment };
}

export interface ButtonNode {
  TAG: "ButtonNode";
  _0: { location: SourceLocation; id: string; text: string };
}

export interface LinkNode {
  TAG: "LinkNode";
  _0: { location: SourceLocation; id: string; text: string };
}

export interface InputNode {
  TAG: "InputNode";
  _0: { location: SourceLocation; placeholder: string };
}

export interface SelectNode {
  TAG: "SelectNode";
  _0: { location: SourceLocation; id: string; placeholder: string };
}

export interface CheckboxNode {
  TAG: "CheckboxNode";
  _0: { location: SourceLocation; checked: boolean; label: string };
}

export interface RadioNode {
  TAG: "RadioNode";
  _0: {
    location: SourceLocation;
    selected: boolean;
    label: string;
    group?: string;
  };
}

export interface DividerNode {
  TAG: "DividerNode";
  _0: {
    location: SourceLocation;
    style: DividerStyle;
    id?: string;
    label?: string;
  };
}

export type InterpolationContent =
  | { TAG: "Literal"; _0: string }
  | { TAG: "PropRef"; _0: PropPlaceholderNode["_0"] }
  | { TAG: "EmojiRef"; _0: EmojiNode["_0"] };

export interface StringNode {
  TAG: "StringNode";
  _0: {
    location: SourceLocation;
    content: string;
    interpolations: InterpolationContent[];
    multiline: boolean;
  };
}

export interface EmojiNode {
  TAG: "EmojiNode";
  _0: { location: SourceLocation; shortcode: string; emoji: string };
}

export interface PropPlaceholderNode {
  TAG: "PropPlaceholderNode";
  _0: {
    location: SourceLocation;
    name: string;
    required: boolean;
    defaultValue?: string;
  };
}

export interface ErrorNode {
  TAG: "ErrorNode";
  _0: { location: SourceLocation; message: string; recoveredContent?: string };
}

export type AstNode =
  | SceneNode
  | ComponentNode
  | ContainerNode
  | TextNode
  | ButtonNode
  | LinkNode
  | InputNode
  | SelectNode
  | CheckboxNode
  | RadioNode
  | DividerNode
  | StringNode
  | EmojiNode
  | PropPlaceholderNode
  | ErrorNode;

export type BlockNode =
  | { TAG: "SceneBlock"; _0: SceneNode["_0"] }
  | { TAG: "ComponentBlock"; _0: ComponentNode["_0"] };

// ---------- Errors / Warnings ----------

export type ErrorCode =
  | "InvalidIdFormat"
  | "MultipleIdDeclarations"
  | "UnclosedInput"
  | "UnclosedString"
  | "UnclosedContainer"
  | "MissingBlockDeclaration"
  | "NestedBlockDeclaration"
  | "MaxDepthExceeded";

/**
 * Warning codes. Spec-mandated codes are plain strings; codes that carry
 * a payload (e.g. UnknownEmoji name) are `{ TAG, _0 }` variants.
 */
export type WarningCode =
  | "PropOutsideComponent"
  | "MixedDividerLabelId"
  | "MissingCheckboxLabel"
  | "MissingRadioLabel"
  | "MisalignedContainerCorner"
  | "MisalignedContainerWall"
  | "InconsistentContainerWidth"
  | "RadioGroupAmbiguous"
  | "LooksLikeButton"
  | "LooksLikeInput"
  | "LooksLikeCheckbox"
  | "LooksLikeRadio"
  | { TAG: "UnknownEmoji"; _0: string }
  | { TAG: "DuplicatePropName"; _0: string }
  | { TAG: "DuplicateContainerId"; _0: string }
  | { TAG: "UnknownPropReference"; _0: string }
  | { TAG: "MultipleRadiosSelected"; _0: string };

export interface ParseError {
  code: ErrorCode;
  message: string;
  location: SourceLocation;
  recoverable: boolean;
}

export interface ParseWarning {
  code: WarningCode;
  message: string;
  location: SourceLocation;
  /** Rule ID linking heuristic-driven warnings to design.md Heuristics Catalog */
  ruleId?: string;
}

// ---------- Heuristics ----------

/** Partial heuristics override; any field omitted falls back to defaults. */
export interface HeuristicsPartial {
  containerColumnTolerance?: number;
  containerWidthTolerance?: number;
  radioHorizontalGap?: number;
  radioVerticalColumnTolerance?: number;
  radioMaxBlankRows?: number;
  centerSymmetryThreshold?: number;
  rightAlignThreshold?: number;
  dividerMinRun?: number;
  nearMissTokenDistance?: number;
}

// ---------- Options / Result ----------

export interface ParseOptions {
  /** Promote recoverable errors to fatal and halt on first error. */
  strict?: boolean;
  /** Tab width for column calculation. Default 4. */
  tabSize?: number;
  /** Maximum container nesting depth. Default 10. */
  maxDepth?: number;
  /** Partial heuristics override; unspecified fields use defaults. */
  heuristics?: HeuristicsPartial;
  /** Per-parse emoji shortcode overrides. Falls back to default registry. */
  emojiRegistry?: Record<string, string>;
}

export interface ParseResult {
  /** First parsed block (legacy single-block accessor). */
  ast?: BlockNode;
  /** All top-level @scene / @component blocks in declaration order. */
  blocks: BlockNode[];
  errors: ParseError[];
  warnings: ParseWarning[];
  /** True iff `errors.length === 0`. */
  success: boolean;
}

// ---------- Public functions ----------

export function parse(source: string, options?: ParseOptions): ParseResult;
export function parseWireframe(source: string): ParseResult;
export const version: string;
export const implementation: string;
export const defaultOptions: ParseOptions;
