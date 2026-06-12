// ssim.test.ts
// Unit tests for SSIM implementation.

import { describe, test, expect } from "vitest";
import type { Bitmap } from "../types.js";
import { ssim, ssimToScore, padToCommonSize } from "../compare/ssim.js";

function makeBitmap(rows: number[][]): Bitmap {
  const height = rows.length;
  const width = rows[0]?.length ?? 0;
  const data = new Uint8Array(width * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      data[y * width + x] = rows[y][x];
    }
  }
  return { width, height, data };
}

function uniform(width: number, height: number, value: number): Bitmap {
  const data = new Uint8Array(width * height).fill(value);
  return { width, height, data };
}

describe("ssim", () => {
  test("identical bitmaps → 1.0", () => {
    const a = uniform(16, 16, 100);
    const b = uniform(16, 16, 100);
    expect(ssim(a, b, 8)).toBeCloseTo(1, 5);
  });

  test("same size, different mid-tones → lower than 1.0", () => {
    // Half-checker pattern vs same pattern with one cell flipped.
    const aRows: number[][] = [];
    const bRows: number[][] = [];
    for (let y = 0; y < 16; y++) {
      aRows.push([]);
      bRows.push([]);
      for (let x = 0; x < 16; x++) {
        const v = (x + y) % 2 === 0 ? 0 : 255;
        aRows[y].push(v);
        bRows[y].push(v);
      }
    }
    bRows[5][5] = 128;
    const score = ssim(makeBitmap(aRows), makeBitmap(bRows), 8);
    expect(score).toBeLessThan(1);
    expect(score).toBeGreaterThan(0);
  });

  test("completely inverted → much lower", () => {
    const a = uniform(16, 16, 0);
    const b = uniform(16, 16, 255);
    const score = ssim(a, b, 8);
    expect(score).toBeLessThan(0.5);
  });

  test("different sizes → padded then compared", () => {
    const a = uniform(8, 8, 100);
    const b = uniform(16, 16, 100);
    // The 8×8 region of `a` is padded to 16×16 with white (255).
    // `b` is uniform 100. So the regions diverge — score < 1 but > 0.
    const score = ssim(a, b, 8);
    expect(score).toBeGreaterThanOrEqual(0);
    expect(score).toBeLessThanOrEqual(1);
  });

  test("small images smaller than window → falls back to global window", () => {
    const a = uniform(4, 4, 100);
    const b = uniform(4, 4, 100);
    expect(ssim(a, b, 8)).toBeCloseTo(1, 5);
  });

  test("deterministic — same inputs → same output", () => {
    const a = uniform(32, 32, 100);
    const b = uniform(32, 32, 100);
    const s1 = ssim(a, b, 8);
    const s2 = ssim(a, b, 8);
    expect(s1).toBe(s2);
  });
});

describe("ssimToScore", () => {
  test("clamps to [0, 1]", () => {
    expect(ssimToScore(1.5)).toBe(1);
    expect(ssimToScore(-0.5)).toBe(0);
    expect(ssimToScore(0.5)).toBe(0.5);
  });

  test("NaN → 0", () => {
    expect(ssimToScore(NaN)).toBe(0);
  });
});

describe("padToCommonSize", () => {
  test("no-op when already same size", () => {
    const a = uniform(8, 8, 100);
    const b = uniform(8, 8, 200);
    const [a2, b2] = padToCommonSize(a, b);
    expect(a2).toBe(a);
    expect(b2).toBe(b);
  });

  test("pads smaller bitmap with white", () => {
    const a = uniform(4, 4, 0);
    const b = uniform(8, 8, 0);
    const [a2, b2] = padToCommonSize(a, b);
    expect(a2.width).toBe(8);
    expect(a2.height).toBe(8);
    expect(b2.width).toBe(8);
    expect(b2.height).toBe(8);
    // Bottom-right corner of `a2` should be padded white (255).
    expect(a2.data[a2.width * a2.height - 1]).toBe(255);
    // Top-left of `a2` should preserve original ink (0).
    expect(a2.data[0]).toBe(0);
  });
});
