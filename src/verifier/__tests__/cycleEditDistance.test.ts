// cycleEditDistance.test.ts
// Tests for the cycle-consistency metric using both an injected printer
// (fast unit tests) and the real V2 Printer (integration).

import { describe, test, expect } from "vitest";
import { cycleEditDistance } from "../metrics/cycleEditDistance.js";
// @ts-ignore — ReScript-generated
import * as V2Parser from "../../parser/v2/V2Parser.mjs";

describe("cycleEditDistance (injected printer)", () => {
  test("printer returns input verbatim → score 1.0, raw 0", async () => {
    const ascii = "+---+\n| a |\n+---+";
    const result = await cycleEditDistance(ascii, {} as unknown, {
      printer: () => ascii,
    });
    expect(result.score).toBe(1);
    expect(result.raw).toBe(0);
  });

  test("printer returns empty → low score, raw = ascii length", async () => {
    const ascii = "+---+\n| a |\n+---+";
    const result = await cycleEditDistance(ascii, {} as unknown, {
      printer: () => "",
    });
    expect(result.score).toBeCloseTo(0, 5);
    expect(result.raw).toBe(ascii.length);
  });

  test("printer returns one-char-off → score very close to 1.0", async () => {
    const ascii = "+---+\n| a |\n+---+";
    const result = await cycleEditDistance(ascii, {} as unknown, {
      printer: () => ascii.replace("a", "b"),
    });
    expect(result.score).toBeGreaterThan(0.9);
    expect(result.raw).toBe(1);
  });

  test("printer returns completely different string → low score", async () => {
    const ascii = "+---+\n| a |\n+---+";
    const result = await cycleEditDistance(ascii, {} as unknown, {
      printer: () => "xxxxxxxxxxxxxxxxxxxxxxx",
    });
    expect(result.score).toBeLessThan(0.5);
  });

  test("score always in [0, 1]", async () => {
    const result = await cycleEditDistance("abc", {} as unknown, {
      printer: () => "xyz",
    });
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(1);
  });
});

describe("cycleEditDistance (real V2 Parser + Printer)", () => {
  test("parse → print round-trip on simple scene yields high score", async () => {
    const source = `@scene: cycle-test
@title: Demo
@device: mobile

+----------------+
| [ Sign In ]    |
+----------------+`;

    const parseResult = V2Parser.parse(source);
    // V2Parser.parse returns an object; the AST shape is internal — the printer
    // accepts whatever the parser produced.
    const ast = parseResult.ast ?? parseResult;

    const result = await cycleEditDistance(source, ast);
    // Real printer canonicalizes whitespace and ID/border format, so the
    // round-trip is rarely byte-identical. Score should still be high.
    expect(result.score).toBeGreaterThan(0.5);
    expect(result.raw).toBeGreaterThanOrEqual(0);
  });
});
