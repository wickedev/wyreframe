/**
 * Hand-rolled TypeScript declarations for the V2 Renderer.
 *
 * Spec: .claude/specs/v2-renderer/{requirements,design}.md
 *
 * The runtime values are ReScript variants encoded as { TAG, _0, ... }; this
 * file declares the JS-friendly public surface and works with the AST shapes
 * exported from `wyreframe/parser/v2`.
 */

import type { AstNode, BlockNode, SourceLocation } from "../../parser/v2/V2Parser";

// ---------- Options ----------

export type ErrorHandling =
  | { TAG: "Skip" }
  | { TAG: "RenderMarker" }
  | { TAG: "Throw" };

export interface RenderOptions {
  /** Class name prefix; default "wf-". */
  classPrefix: string;
  /** What to do when an ErrorNode is encountered. */
  errorHandling: ErrorHandling;
  /** Map of prop-name → value used to resolve PropPlaceholderNodes. */
  componentPropValues: Record<string, string>;
  /** Optional override for emoji glyph resolution. */
  emojiResolver?: (shortcode: string) => string | undefined;
  /** Whether to emit data-wf-row/data-wf-col attrs. Default true. */
  includeSourceLocations: boolean;
  /** Prefix applied when stamping DOM `id`. Default "wf-". */
  idPrefix: string;
  /** Salt used for deterministic synthetic IDs. Default "v2". */
  syntheticIdSalt: string;
  /** Reserved; currently always false. */
  prettyPrint: boolean;
}

// ---------- Diagnostics ----------

export type RenderWarning =
  | { TAG: "DuplicateId"; _0: string; _1: SourceLocation }
  | { TAG: "UnresolvedProp"; _0: string; _1: SourceLocation }
  | { TAG: "UnknownEmojiShortcode"; _0: string; _1: SourceLocation }
  | { TAG: "ErrorNodeRendered"; _0: string; _1: SourceLocation };

// ---------- Handle ----------

export interface RenderHandle {
  /** The DOM container into which the tree was mounted. */
  root: HTMLElement;
  /** Warnings collected during this render. */
  warnings: RenderWarning[];
  /** Detach the rendered tree. */
  dispose: () => void;
  /** Re-render with a new AST (full re-render in V1 of this renderer). */
  update: (newAst: AstNode) => void;
}

// ---------- Public functions ----------

export function defaultOptions(): RenderOptions;

export function renderToString(node: AstNode, options: RenderOptions): string;

export function renderToStringWithDiagnostics(
  node: AstNode,
  options: RenderOptions
): [string, RenderWarning[]];

export function renderBlockToString(block: BlockNode, options: RenderOptions): string;

export function renderBlockToStringWithDiagnostics(
  block: BlockNode,
  options: RenderOptions
): [string, RenderWarning[]];

export function renderToDOM(
  node: AstNode,
  container: HTMLElement,
  options: RenderOptions
): RenderHandle;

export function renderComponent(
  node: AstNode,
  props: Record<string, string>,
  options: RenderOptions
): string;

export const version: string;
export const implementation: string;
