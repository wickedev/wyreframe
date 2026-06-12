// asciiToBitmap.test.ts
// Unit tests for ASCII → bitmap conversion.

import { describe, test, expect } from "vitest";
import { asciiToBitmap } from "../render/asciiToBitmap.js";

describe("asciiToBitmap", () => {
  test("empty string → 1×1 white pixel (no crash)", () => {
    const bm = asciiToBitmap("");
    expect(bm.width).toBe(1);
    expect(bm.height).toBe(1);
    expect(bm.data[0]).toBe(255);
  });

  test("single line → 1 row, ink at non-space positions", () => {
    const bm = asciiToBitmap("a b");
    expect(bm.width).toBe(3);
    expect(bm.height).toBe(1);
    expect(bm.data[0]).toBe(0); // 'a'
    expect(bm.data[1]).toBe(255); // ' '
    expect(bm.data[2]).toBe(0); // 'b'
  });

  test("multi-line wireframe", () => {
    const ascii = "+--+\n|  |\n+--+";
    const bm = asciiToBitmap(ascii);
    expect(bm.width).toBe(4);
    expect(bm.height).toBe(3);
    // Top-left corner is '+' → ink.
    expect(bm.data[0]).toBe(0);
    // Middle row, middle cells are spaces → paper.
    expect(bm.data[1 * 4 + 1]).toBe(255);
    expect(bm.data[1 * 4 + 2]).toBe(255);
  });

  test("ragged-right lines → padded with white", () => {
    const ascii = "abc\nde";
    const bm = asciiToBitmap(ascii);
    expect(bm.width).toBe(3);
    expect(bm.height).toBe(2);
    // Second row, last col is missing in source → paper.
    expect(bm.data[1 * 3 + 2]).toBe(255);
  });

  test("trailing newline does not add an empty row", () => {
    const bm = asciiToBitmap("abc\n");
    expect(bm.height).toBe(1);
    expect(bm.width).toBe(3);
  });

  test("CRLF and CR line endings normalized", () => {
    const a = asciiToBitmap("ab\r\ncd");
    const b = asciiToBitmap("ab\rcd");
    const c = asciiToBitmap("ab\ncd");
    expect(a.width).toBe(b.width);
    expect(a.width).toBe(c.width);
    expect(a.height).toBe(b.height);
    expect(a.height).toBe(c.height);
    // Byte-identical regardless of line ending variant.
    expect(Array.from(a.data)).toEqual(Array.from(c.data));
    expect(Array.from(b.data)).toEqual(Array.from(c.data));
  });

  test("deterministic: same input → byte-identical output", () => {
    const input = "+-----+\n| Hi  |\n+-----+";
    const a = asciiToBitmap(input);
    const b = asciiToBitmap(input);
    expect(Array.from(a.data)).toEqual(Array.from(b.data));
    expect(a.width).toBe(b.width);
    expect(a.height).toBe(b.height);
  });

  test("tabs treated as paper (like spaces)", () => {
    const bm = asciiToBitmap("a\tb");
    expect(bm.data[1]).toBe(255);
  });
});
