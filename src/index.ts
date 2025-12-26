/**
 * Wyreframe - ASCII Wireframe to HTML/UI Converter
 *
 * This module provides a TypeScript-friendly API wrapper
 * around the ReScript parser implementation.
 */

// Note: These imports use relative paths that work when compiled to dist/
// The ReScript .mjs files remain in src/parser/, so dist/index.js imports ../src/parser/
// @ts-ignore - ReScript generated module
import * as Parser from '../src/parser/Parser.mjs';
// @ts-ignore - ReScript generated module
import * as Renderer from '../src/renderer/Renderer.mjs';
// @ts-ignore - ReScript generated module
import * as Fixer from '../src/parser/Fixer/Fixer.mjs';

// ============================================================================
// Type Definitions
// ============================================================================

/** Device type for responsive design */
export type DeviceType =
  | 'desktop'
  | 'laptop'
  | 'tablet'
  | 'tablet-landscape'
  | 'mobile'
  | 'mobile-landscape';

/** Transition effect for scene changes */
export type TransitionType = 'fade' | 'slide-left' | 'slide-right' | 'zoom';

/** Text alignment */
export type Alignment = 'left' | 'center' | 'right';

/** Button variant styles */
export type ButtonVariant = 'primary' | 'secondary' | 'ghost';

/** Action types for interactions */
export interface GotoAction {
  type: 'goto';
  target: string;
  transition?: TransitionType;
}

export type Action = GotoAction;

/** UI Element types */
export interface BoxElement {
  TAG: 'Box';
  name?: string;
  children: Element[];
}

export interface ButtonElement {
  TAG: 'Button';
  id: string;
  text: string;
  align: Alignment;
  variant?: ButtonVariant;
  actions: Action[];
}

export interface InputElement {
  TAG: 'Input';
  id: string;
  placeholder?: string;
  variant?: string;
}

export interface LinkElement {
  TAG: 'Link';
  id: string;
  text: string;
  align: Alignment;
  actions: Action[];
}

export interface TextElement {
  TAG: 'Text';
  content: string;
  emphasis: boolean;
  align: Alignment;
}

export interface CheckboxElement {
  TAG: 'Checkbox';
  checked: boolean;
  label: string;
}

export interface DividerElement {
  TAG: 'Divider';
}

export interface RowElement {
  TAG: 'Row';
  children: Element[];
  align: Alignment;
}

export interface SectionElement {
  TAG: 'Section';
  name: string;
  children: Element[];
}

export type Element =
  | BoxElement
  | ButtonElement
  | InputElement
  | LinkElement
  | TextElement
  | CheckboxElement
  | DividerElement
  | RowElement
  | SectionElement;

/** Scene definition */
export interface Scene {
  id: string;
  title: string;
  device: DeviceType;
  transition: TransitionType;
  elements: Element[];
}

/** Abstract Syntax Tree */
export interface AST {
  scenes: Scene[];
}

/** Parse error information */
export interface ParseError {
  message: string;
  line?: number;
  column?: number;
  source?: string;
}

/** Scene manager for programmatic navigation */
export interface SceneManager {
  /** Navigate to a scene by ID */
  goto: (sceneId: string) => void;
  /** Get the current scene ID */
  getCurrentScene: () => string | undefined;
  /** Get all available scene IDs */
  getSceneIds: () => string[];
}

/** Scene change callback type */
export type OnSceneChangeCallback = (fromScene: string | undefined, toScene: string) => void;

/** Element type for dead end clicks */
export type DeadEndElementType = 'button' | 'link';

/** Information about a clicked element with no navigation target */
export interface DeadEndClickInfo {
  /** The scene ID where the click occurred */
  sceneId: string;
  /** The ID of the clicked element */
  elementId: string;
  /** The display text of the clicked element */
  elementText: string;
  /** The type of element that was clicked */
  elementType: DeadEndElementType;
}

/** Dead end click callback type */
export type OnDeadEndClickCallback = (info: DeadEndClickInfo) => void;

/** Render options */
export interface RenderOptions {
  /** Theme name */
  theme?: string;
  /** Enable interactions (default: true) */
  interactive?: boolean;
  /** Inject default styles (default: true) */
  injectStyles?: boolean;
  /** Additional CSS class for container */
  containerClass?: string;
  /**
   * Callback fired when navigating between scenes.
   * Useful for implementing scene history, analytics, or state synchronization.
   * @param fromScene - The scene ID navigating from (undefined if initial navigation)
   * @param toScene - The scene ID navigating to
   */
  onSceneChange?: OnSceneChangeCallback;
  /**
   * Override the device type for all scenes.
   * When provided, this overrides the device type defined in scene definitions.
   * Useful for previewing wireframes in different device contexts without modifying the source.
   */
  device?: DeviceType;
  /**
   * Callback fired when a button or link without a navigation target is clicked.
   * Useful for handling dead-end interactions, showing modals, or custom navigation logic.
   * @param info - Information about the clicked element and current scene
   */
  onDeadEndClick?: OnDeadEndClickCallback;
}

/** Render result */
export interface RenderResult {
  /** Rendered root element */
  root: HTMLElement;
  /** Scene manager for navigation */
  sceneManager: SceneManager;
}

// ============================================================================
// Result Types (TypeScript-friendly)
// ============================================================================

export type ParseSuccessResult = {
  success: true;
  ast: AST;
  warnings: ParseError[];
};

export type ParseErrorResult = {
  success: false;
  errors: ParseError[];
};

export type ParseResult = ParseSuccessResult | ParseErrorResult;

export type InteractionSuccessResult = {
  success: true;
  interactions: unknown[];
};

export type InteractionErrorResult = {
  success: false;
  errors: ParseError[];
};

export type InteractionResult = InteractionSuccessResult | InteractionErrorResult;

export type CreateUISuccessResult = {
  success: true;
  root: HTMLElement;
  sceneManager: SceneManager;
  ast: AST;
  warnings: ParseError[];
};

export type CreateUIErrorResult = {
  success: false;
  errors: ParseError[];
};

export type CreateUIResult = CreateUISuccessResult | CreateUIErrorResult;

// ============================================================================
// Fix Result Types
// ============================================================================

/** Describes a single fix that was applied */
export interface FixedIssue {
  original: ParseError;
  description: string;
  line: number;
  column: number;
}

/** Successful fix result */
export type FixSuccessResult = {
  success: true;
  text: string;
  fixed: FixedIssue[];
  remaining: ParseError[];
};

/** Failed fix result */
export type FixErrorResult = {
  success: false;
  errors: ParseError[];
};

/** Result of fix operation */
export type FixResult = FixSuccessResult | FixErrorResult;

// ============================================================================
// Internal ReScript Result Type
// ============================================================================

interface ReScriptOk<T> {
  TAG: 'Ok';
  _0: T;
}

interface ReScriptError<E> {
  TAG: 'Error';
  _0: E;
}

type ReScriptResult<T, E> = ReScriptOk<T> | ReScriptError<E>;

// ============================================================================
// API Functions
// ============================================================================

/**
 * Parse mixed text containing wireframe and interactions.
 *
 * @param text - Text containing ASCII wireframe and/or interaction DSL
 * @returns Parse result with success flag
 *
 * @example
 * ```typescript
 * const result = parse(text);
 * if (result.success) {
 *   const { root, sceneManager } = render(result.ast);
 *   document.body.appendChild(root);
 * } else {
 *   console.error(result.errors);
 * }
 * ```
 */
export function parse(text: string): ParseResult {
  const result = Parser.parse(text) as ReScriptResult<[AST, ParseError[]], ParseError[]>;

  if (result.TAG === 'Ok') {
    const [ast, warnings] = result._0;
    return { success: true, ast, warnings };
  } else {
    return { success: false, errors: result._0 };
  }
}

/**
 * Parse text and throw on error.
 * Use this for simpler code when you expect parsing to succeed.
 *
 * @param text - Text containing ASCII wireframe and/or interaction DSL
 * @returns Parsed AST
 * @throws Error if parsing fails
 *
 * @example
 * ```typescript
 * try {
 *   const ast = parseOrThrow(text);
 *   const { root } = render(ast);
 *   document.body.appendChild(root);
 * } catch (error) {
 *   console.error('Parse failed:', error.message);
 * }
 * ```
 */
export function parseOrThrow(text: string): AST {
  const result = parse(text);

  if (result.success) {
    return result.ast;
  } else {
    const errorMessages = result.errors
      .map((e) => e.message || JSON.stringify(e))
      .join('\n');
    throw new Error(`Parse failed:\n${errorMessages}`);
  }
}

/**
 * Parse only the wireframe structure (no interactions).
 *
 * @param wireframe - ASCII wireframe string
 * @returns Parse result with success flag
 */
export function parseWireframe(wireframe: string): ParseResult {
  const result = Parser.parseWireframe(wireframe) as ReScriptResult<[AST, ParseError[]], ParseError[]>;

  if (result.TAG === 'Ok') {
    const [ast, warnings] = result._0;
    return { success: true, ast, warnings };
  } else {
    return { success: false, errors: result._0 };
  }
}

/**
 * Parse only the interaction DSL.
 *
 * @param dsl - Interaction DSL string
 * @returns Interaction result with success flag
 */
export function parseInteractions(dsl: string): InteractionResult {
  const result = Parser.parseInteractions(dsl) as ReScriptResult<unknown[], ParseError[]>;

  if (result.TAG === 'Ok') {
    return { success: true, interactions: result._0 };
  } else {
    return { success: false, errors: result._0 };
  }
}

/**
 * Render AST to DOM elements.
 *
 * @param ast - Parsed AST from parse()
 * @param options - Render options
 * @returns Render result with root element and scene manager
 *
 * @example
 * ```typescript
 * const { root, sceneManager } = render(ast);
 * document.getElementById('app')!.appendChild(root);
 *
 * // Navigate between scenes
 * sceneManager.goto('dashboard');
 * ```
 */
export function render(ast: AST, options?: RenderOptions): RenderResult {
  // Input validation: Check if user accidentally passed ParseResult instead of AST
  if (ast && typeof ast === 'object' && 'success' in ast) {
    const parseResult = ast as unknown as ParseResult;
    if (parseResult.success === true && 'ast' in parseResult) {
      throw new Error(
        'render() expects an AST object, but received a ParseResult. ' +
          'Did you forget to extract .ast? Use: render(result.ast) instead of render(result)'
      );
    } else if (parseResult.success === false) {
      throw new Error(
        'render() received a failed ParseResult. ' +
          'Check parse errors before calling render: if (result.success) { render(result.ast); }'
      );
    }
  }

  // Validate AST structure
  if (!ast || typeof ast !== 'object' || !Array.isArray(ast.scenes)) {
    throw new Error(
      'render() expects an AST object with a scenes array. ' +
        'Did you pass ParseResult instead of ParseResult.ast? ' +
        'Correct usage: const result = parse(text); if (result.success) { render(result.ast); }'
    );
  }

  // Pass undefined if no options, so ReScript uses its defaults
  const result = Renderer.render(ast, options);

  return {
    root: result.root,
    sceneManager: {
      goto: result.sceneManager.goto,
      getCurrentScene: result.sceneManager.getCurrentScene,
      getSceneIds: result.sceneManager.getSceneIds,
    },
  };
}

/**
 * Parse and render in one step.
 * Convenience function that combines parse() and render().
 *
 * @param text - Text containing ASCII wireframe and/or interaction DSL
 * @param options - Render options
 * @returns Create UI result with success flag
 *
 * @example
 * ```typescript
 * const result = createUI(text);
 * if (result.success) {
 *   document.getElementById('app')!.appendChild(result.root);
 *   result.sceneManager.goto('login');
 * }
 * ```
 */
export function createUI(text: string, options?: RenderOptions): CreateUIResult {
  const parseResult = parse(text);

  if (!parseResult.success) {
    return parseResult;
  }

  const { root, sceneManager } = render(parseResult.ast, options);

  return {
    success: true,
    root,
    sceneManager,
    ast: parseResult.ast,
    warnings: parseResult.warnings,
  };
}

/**
 * Parse and render, throwing on error.
 *
 * @param text - Text containing ASCII wireframe and/or interaction DSL
 * @param options - Render options
 * @returns Render result with root element, scene manager, and AST
 * @throws Error if parsing fails
 *
 * @example
 * ```typescript
 * const { root, sceneManager } = createUIOrThrow(text);
 * document.getElementById('app')!.appendChild(root);
 * ```
 */
export function createUIOrThrow(
  text: string,
  options?: RenderOptions
): RenderResult & { ast: AST } {
  const ast = parseOrThrow(text);
  const { root, sceneManager } = render(ast, options);

  return { root, sceneManager, ast };
}

// ============================================================================
// Fix API Functions
// ============================================================================

/**
 * Internal ReScript Fix Result type
 */
interface ReScriptFixSuccess {
  text: string;
  fixed: Array<{
    original: { code: unknown; severity: unknown; context: unknown };
    description: string;
    line: number;
    column: number;
  }>;
  remaining: Array<{ code: unknown; severity: unknown; context: unknown }>;
}

/**
 * Convert ReScript error to ParseError
 */
function convertReScriptError(err: { code: unknown; severity: unknown; context: unknown }): ParseError {
  // The ReScript error has a complex structure, extract what we need
  return {
    message: String(err.code) || 'Unknown error',
    line: undefined,
    column: undefined,
    source: undefined,
  };
}

/**
 * Attempt to auto-fix errors and warnings in the wireframe text.
 *
 * This function analyzes the text for common issues and automatically
 * corrects them where possible. Fixable issues include:
 * - MisalignedPipe: Adjusts pipe positions to correct columns
 * - MisalignedClosingBorder: Fixes closing border alignment
 * - UnusualSpacing: Replaces tabs with spaces
 * - UnclosedBracket: Adds missing closing brackets
 * - MismatchedWidth: Extends shorter borders to match
 *
 * @param text - The wireframe markdown text
 * @returns Fix result with fixed text and details about applied fixes
 *
 * @example
 * ```typescript
 * const result = fix(text);
 * if (result.success) {
 *   console.log(`Fixed ${result.fixed.length} issues`);
 *   if (result.remaining.length > 0) {
 *     console.warn('Some issues require manual fix:', result.remaining);
 *   }
 *   // Use the fixed text
 *   const parsed = parse(result.text);
 * }
 * ```
 */
export function fix(text: string): FixResult {
  const result = Fixer.fix(text) as ReScriptResult<ReScriptFixSuccess, Array<{ code: unknown; severity: unknown; context: unknown }>>;

  if (result.TAG === 'Ok') {
    const success = result._0;
    return {
      success: true,
      text: success.text,
      fixed: success.fixed.map((f) => ({
        original: convertReScriptError(f.original),
        description: f.description,
        line: f.line,
        column: f.column,
      })),
      remaining: success.remaining.map(convertReScriptError),
    };
  } else {
    return {
      success: false,
      errors: result._0.map(convertReScriptError),
    };
  }
}

/**
 * Convenience function - fix and return just the fixed text.
 * Returns the original text if nothing was fixed or if fixing failed.
 *
 * @param text - The wireframe markdown text
 * @returns The fixed text (or original if no fixes applied)
 *
 * @example
 * ```typescript
 * const fixedText = fixOnly(rawMarkdown);
 * const result = parse(fixedText);
 * ```
 */
export function fixOnly(text: string): string {
  return Fixer.fixOnly(text) as string;
}

// Version info
export const version: string = Parser.version;
export const implementation: string = Parser.implementation;

// Default export for convenience
export default {
  parse,
  parseOrThrow,
  parseWireframe,
  parseInteractions,
  render,
  createUI,
  createUIOrThrow,
  fix,
  fixOnly,
  version,
  implementation,
};
