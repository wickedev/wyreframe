/**
 * Hand-rolled TypeScript declarations for the V2 ASCII Printer.
 *
 * Round-trip companion to `wyreframe/parser/v2`: takes a V2 AST and emits
 * canonical ASCII text that re-parses to a semantically equivalent AST.
 */

import type {
  AstNode,
  BlockNode,
} from "../parser/v2/V2Parser";

export type Charset = "ascii" | "unicode";
export type LineEnding = "lf" | "crlf";
export type ErrorHandling = "skip" | "render-comment" | "throw";

export interface PrintOptions {
  /** Border charset. Default "ascii". Round-trip only guaranteed for ASCII. */
  charset?: Charset;
  /** Line ending. Default "lf". */
  lineEnding?: LineEnding;
  /** Error node handling. Default "render-comment". */
  errorHandling?: ErrorHandling;
  /** Padding around inner content. Default 1. */
  containerPadding?: number;
  /** Strip trailing whitespace from each line. Default false. */
  trimTrailing?: boolean;
  /** Soft max column width (warn-only). Default undefined. */
  maxColumns?: number;
}

/**
 * The actual ReScript runtime variant for PrintOptions; printBlock /
 * printAst accept this internal record. JS consumers usually call the
 * `print` convenience which takes plain JS objects.
 */
export interface InternalPrintOptions {
  charset: { TAG?: "ASCII" | "Unicode" } | "ASCII" | "Unicode";
  lineEnding: "LF" | "CRLF";
  errorHandling: "Skip" | "RenderComment" | "Throw";
  containerPadding: number;
  trimTrailing: boolean;
  maxColumns?: number;
}

/** Return the default options record (ReScript-internal shape). */
export function defaultOptions(): InternalPrintOptions;

/** Print a single block (Scene or Component) to ASCII text. */
export function printBlock(
  block: BlockNode,
  options: InternalPrintOptions,
): string;

/** Print any astNode; only Scene/Component nodes yield non-empty output. */
export function printAst(
  ast: AstNode,
  options: InternalPrintOptions,
): string;

/** Convenience: print with default options. */
export function print(ast: AstNode): string;

/** Print multiple blocks back-to-back. */
export function printBlocks(
  blocks: BlockNode[],
  options: InternalPrintOptions,
): string;

export const version: string;
