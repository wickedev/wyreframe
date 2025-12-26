/**
 * Tests for TypeScript API wrapper input validation
 *
 * These tests verify that render() provides helpful error messages
 * when called with incorrect arguments (Issue #1).
 */

import { describe, test, expect } from 'vitest';
import { parse, render, createUI } from './index';
import type { AST, ParseResult } from './index';

describe('render() input validation (Issue #1)', () => {
  const validWireframe = `
@scene: test

+-------+
| Hello |
+-------+
`;

  test('throws descriptive error when passed successful ParseResult instead of AST', () => {
    const result = parse(validWireframe);

    // Verify we have a successful parse result
    expect(result.success).toBe(true);

    // This is the common mistake: passing result instead of result.ast
    expect(() => {
      render(result as unknown as AST);
    }).toThrow('render() expects an AST object, but received a ParseResult');

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('Did you forget to extract .ast?');
  });

  test('throws descriptive error when passed failed ParseResult', () => {
    // Invalid wireframe that will fail to parse
    const invalidWireframe = '+--incomplete';
    const result = parse(invalidWireframe);

    // This should be a failed parse
    expect(result.success).toBe(false);

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('render() received a failed ParseResult');

    expect(() => {
      render(result as unknown as AST);
    }).toThrow('Check parse errors before calling render');
  });

  test('throws descriptive error when passed null or undefined', () => {
    expect(() => {
      render(null as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');

    expect(() => {
      render(undefined as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');
  });

  test('throws descriptive error when passed object without scenes array', () => {
    const invalidAST = { foo: 'bar' };

    expect(() => {
      render(invalidAST as unknown as AST);
    }).toThrow('render() expects an AST object with a scenes array');

    expect(() => {
      render(invalidAST as unknown as AST);
    }).toThrow('Did you pass ParseResult instead of ParseResult.ast?');
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  // The renderer requires a browser or jsdom environment
  test.skip('works correctly when passed valid AST (requires DOM)', () => {
    const result = parse(validWireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      // This is the correct usage
      const { root, sceneManager } = render(result.ast);

      expect(root).toBeDefined();
      expect(root).toBeInstanceOf(HTMLElement);
      expect(sceneManager).toBeDefined();
      expect(sceneManager.getSceneIds()).toContain('test');
    }
  });
});

describe('createUI() convenience function', () => {
  test('handles parse errors gracefully', () => {
    const invalidWireframe = '+--incomplete';
    const result = createUI(invalidWireframe);

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.errors).toBeDefined();
      expect(result.errors.length).toBeGreaterThan(0);
    }
  });

  // Note: DOM-dependent tests are skipped in Node.js environment
  test.skip('works correctly with valid wireframe (requires DOM)', () => {
    const validWireframe = `
@scene: test

+-------+
| Hello |
+-------+
`;
    const result = createUI(validWireframe);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.root).toBeDefined();
      expect(result.sceneManager).toBeDefined();
      expect(result.ast).toBeDefined();
    }
  });
});
