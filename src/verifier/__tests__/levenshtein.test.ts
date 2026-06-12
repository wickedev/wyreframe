// levenshtein.test.ts
// Unit tests for edit distance.

import { describe, test, expect } from "vitest";
import {
  levenshtein,
  normalizedEditDistance,
} from "../compare/levenshtein.js";

describe("levenshtein", () => {
  test("identical strings → 0", () => {
    expect(levenshtein("hello", "hello")).toBe(0);
    expect(levenshtein("", "")).toBe(0);
  });

  test("empty vs non-empty → length", () => {
    expect(levenshtein("", "hello")).toBe(5);
    expect(levenshtein("hello", "")).toBe(5);
  });

  test("single substitution", () => {
    expect(levenshtein("cat", "bat")).toBe(1);
  });

  test("single insertion", () => {
    expect(levenshtein("cat", "cats")).toBe(1);
    expect(levenshtein("cat", "scat")).toBe(1);
  });

  test("single deletion", () => {
    expect(levenshtein("cats", "cat")).toBe(1);
  });

  test("classic Wikipedia example: kitten ↔ sitting → 3", () => {
    expect(levenshtein("kitten", "sitting")).toBe(3);
  });

  test("multiline ASCII wireframe-like inputs", () => {
    const a = "+---+\n| a |\n+---+";
    const b = "+---+\n| b |\n+---+";
    expect(levenshtein(a, b)).toBe(1);
  });

  test("symmetric: lev(a,b) === lev(b,a)", () => {
    const a = "the quick brown fox";
    const b = "the slow red fox";
    expect(levenshtein(a, b)).toBe(levenshtein(b, a));
  });

  test("triangle inequality (sanity)", () => {
    const a = "abcdef";
    const b = "abcxyz";
    const c = "xyzdef";
    const ab = levenshtein(a, b);
    const bc = levenshtein(b, c);
    const ac = levenshtein(a, c);
    expect(ac).toBeLessThanOrEqual(ab + bc);
  });
});

describe("normalizedEditDistance", () => {
  test("identical → 0", () => {
    expect(normalizedEditDistance("hello", "hello")).toBe(0);
    expect(normalizedEditDistance("", "")).toBe(0);
  });

  test("totally different of equal length → 1", () => {
    expect(normalizedEditDistance("aaa", "bbb")).toBe(1);
  });

  test("partial match", () => {
    // "cat" vs "bat": distance 1, max length 3 → 1/3
    expect(normalizedEditDistance("cat", "bat")).toBeCloseTo(1 / 3);
  });

  test("never returns negative or > 1", () => {
    expect(normalizedEditDistance("foo", "bar")).toBeGreaterThanOrEqual(0);
    expect(normalizedEditDistance("foo", "bar")).toBeLessThanOrEqual(1);
  });
});
