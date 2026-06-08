// Regressions29.test.ts
// Codex-review-driven regressions, round 30.
// This is a TypeScript test that exercises the type surface of `wyreframe/parser/v2`.
// If the .d.ts is missing or incorrect, `tsc --noEmit` (run by `npm run ts:build`)
// will fail. We also assert at runtime that the file resolves.

import { describe, test, expect } from "vitest";
import * as V2 from "wyreframe/parser/v2";
import type {
  ParseResult,
  ParseOptions,
  BlockNode,
  SceneNode,
  ParseError,
  ParseWarning,
} from "wyreframe/parser/v2";

describe("Regression P2: V2 parser TypeScript declarations (Codex round 30)", () => {
  test("`wyreframe/parser/v2` resolves and exports the documented API", () => {
    expect(typeof V2.parse).toBe("function");
    expect(typeof V2.parseWireframe).toBe("function");
    expect(typeof V2.version).toBe("string");
    expect(typeof V2.implementation).toBe("string");
    expect(typeof V2.defaultOptions).toBe("object");
  });

  test("ParseOptions / ParseResult shapes match the declared types", () => {
    const opts: ParseOptions = { strict: false, tabSize: 2 };
    const result: ParseResult = V2.parse("@scene: s\n\nHello", opts);
    expect(result.success).toBe(true);
    expect(Array.isArray(result.blocks)).toBe(true);
    expect(Array.isArray(result.errors)).toBe(true);
    expect(Array.isArray(result.warnings)).toBe(true);
  });

  test("Block AST node types narrow correctly", () => {
    const result = V2.parse("@scene: hello\n\nworld");
    const block = result.blocks[0] as BlockNode;
    expect(block.TAG).toBe("SceneBlock");
    if (block.TAG === "SceneBlock") {
      // type narrows to SceneNode["_0"]
      const scene: SceneNode["_0"] = block._0;
      expect(scene.slug).toBe("hello");
    }
  });

  test("Error / Warning types are usable", () => {
    const result = V2.parse("[__unclosed");
    const errs: ParseError[] = result.errors;
    const warns: ParseWarning[] = result.warnings;
    expect(Array.isArray(errs)).toBe(true);
    expect(Array.isArray(warns)).toBe(true);
  });
});
