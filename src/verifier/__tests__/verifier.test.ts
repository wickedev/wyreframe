// verifier.test.ts
// End-to-end tests for the verifier orchestrator.
//
// Uses the real V2 Parser to build ASTs from ASCII, and stubs the
// htmlToBitmap renderer (no headless browser dep).

import { describe, test, expect } from "vitest";
import { verify, asciiToBitmap } from "../index.js";
import type { Bitmap, HtmlToBitmap } from "../types.js";
import { regionIoU } from "../metrics/regionIoU.js";
// @ts-ignore — ReScript-generated
import * as V2Parser from "../../parser/v2/V2Parser.mjs";

// A stub htmlToBitmap that simply returns the ascii bitmap unchanged.
// Used to test the orchestrator without requiring a real browser renderer.
function makeIdentityHtmlToBitmap(asciiSnapshot: string): HtmlToBitmap {
  const snap = asciiToBitmap(asciiSnapshot);
  return async (_html: string): Promise<Bitmap> => snap;
}

// A stub that returns a "broken" bitmap (everything inverted) to drive
// SSIM toward a low score.
function makeBrokenHtmlToBitmap(): HtmlToBitmap {
  return async (_html: string): Promise<Bitmap> => ({
    width: 8,
    height: 8,
    data: new Uint8Array(64).fill(0),
  });
}

function parseAst(source: string): unknown {
  const r = V2Parser.parse(source);
  return r.ast ?? r;
}

describe("verify (cycle-only mode)", () => {
  test("without htmlToBitmap → only cycle metric, warning emitted", async () => {
    const source = `@scene: a
@title: A
@device: mobile

+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({ ascii: source, ast });

    expect(result.metrics.cycleEditDistance).toBeDefined();
    expect(result.metrics.pixelSSIM).toBeUndefined();
    expect(result.metrics.regionIoU).toBeUndefined();
    expect(result.warnings.some((w) => w.includes("htmlToBitmap"))).toBe(true);
    expect(result.score).toBe(result.metrics.cycleEditDistance.score);
  });

  test("score is in [0, 1]", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({ ascii: source, ast });
    expect(result.score).toBeGreaterThanOrEqual(0);
    expect(result.score).toBeLessThanOrEqual(1);
  });
});

describe("verify (full mode with stubbed htmlToBitmap)", () => {
  test("identity-stub htmlToBitmap → all three metrics computed", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({
      ascii: source,
      ast,
      htmlToBitmap: makeIdentityHtmlToBitmap(source),
    });

    expect(result.metrics.cycleEditDistance).toBeDefined();
    expect(result.metrics.pixelSSIM).toBeDefined();
    expect(result.metrics.regionIoU).toBeDefined();
    // No "skipped" warning when htmlToBitmap is supplied.
    expect(result.warnings.some((w) => w.includes("skipped"))).toBe(false);
  });

  test("identity bitmap → pixel SSIM and IoU near 1.0", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({
      ascii: source,
      ast,
      htmlToBitmap: makeIdentityHtmlToBitmap(source),
    });

    expect(result.metrics.pixelSSIM!.score).toBeGreaterThan(0.9);
    expect(result.metrics.regionIoU!.score).toBeGreaterThan(0.9);
  });

  test("broken bitmap → pixel SSIM degraded", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({
      ascii: source,
      ast,
      htmlToBitmap: makeBrokenHtmlToBitmap(),
    });

    expect(result.metrics.pixelSSIM!.score).toBeLessThan(0.9);
  });

  test("htmlToBitmap that throws → warning, no crash, cycle still computed", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);
    const result = await verify({
      ascii: source,
      ast,
      htmlToBitmap: async () => {
        throw new Error("boom");
      },
    });

    expect(result.metrics.cycleEditDistance).toBeDefined();
    expect(result.metrics.pixelSSIM).toBeUndefined();
    expect(result.warnings.some((w) => w.includes("boom"))).toBe(true);
  });
});

describe("verify (weights)", () => {
  test("custom weights affect combined score", async () => {
    const source = `@scene: a
+----+
| Hi |
+----+`;
    const ast = parseAst(source);

    // cycle alone with a printer that produces near-perfect output: high.
    // With broken bitmap (SSIM ≈ 0, IoU ≈ 0), heavy cycle weight wins.
    const heavyCycle = await verify(
      {
        ascii: source,
        ast,
        htmlToBitmap: makeBrokenHtmlToBitmap(),
      },
      { weights: { cycle: 1, ssim: 0, iou: 0 } }
    );

    const heavySSIM = await verify(
      {
        ascii: source,
        ast,
        htmlToBitmap: makeBrokenHtmlToBitmap(),
      },
      { weights: { cycle: 0, ssim: 1, iou: 0 } }
    );

    expect(heavyCycle.score).toBeGreaterThan(heavySSIM.score);
  });
});

describe("regionIoU (direct unit test for completeness)", () => {
  test("identical bitmaps → IoU 1.0", () => {
    const bm: Bitmap = {
      width: 8,
      height: 8,
      data: new Uint8Array(64).fill(0),
    };
    const result = regionIoU(bm, bm);
    expect(result.score).toBe(1);
  });

  test("disjoint occupancy → IoU 0", () => {
    const a: Bitmap = { width: 8, height: 8, data: new Uint8Array(64).fill(255) };
    const b: Bitmap = { width: 8, height: 8, data: new Uint8Array(64).fill(255) };
    // a has ink in top-left quadrant, b in bottom-right.
    for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) a.data[y * 8 + x] = 0;
    for (let y = 4; y < 8; y++) for (let x = 4; x < 8; x++) b.data[y * 8 + x] = 0;
    const result = regionIoU(a, b, 4, 0.5);
    expect(result.score).toBe(0);
  });
});
