// asciiToBitmap.ts
// Convert ASCII text to a deterministic grayscale bitmap by treating each
// character position as a single pixel (0 = non-space, 255 = space).
//
// This is a *spatial* representation — it captures where ink is on the grid
// without requiring a font rasterizer. Sufficient for SSIM/IoU which care
// about structural similarity, not pixel-perfect glyph fidelity.
//
// Determinism: same input string → byte-identical bitmap, no exceptions.

import type { Bitmap } from "../types.js";

const INK = 0;
const PAPER = 255;

/**
 * Convert ASCII text to a 1-pixel-per-char bitmap.
 *
 * Line endings: '\r\n', '\r', and '\n' are all treated as row separators.
 * Width is the max line length across all rows; shorter rows are right-padded
 * with PAPER (space).
 */
export function asciiToBitmap(ascii: string): Bitmap {
  // Normalize line endings to '\n' (deterministic).
  const normalized = ascii.replace(/\r\n?/g, "\n");
  const lines = normalized.split("\n");

  // Drop a single trailing empty line caused by a trailing '\n' so the
  // height matches "visible row count". A grid of N visible rows ending
  // in '\n' should have height N, not N+1.
  if (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }

  const H = lines.length;
  let W = 0;
  for (const line of lines) {
    if (line.length > W) W = line.length;
  }

  // Edge case: empty input → 1×1 white pixel (avoid 0-sized bitmaps).
  if (W === 0 || H === 0) {
    return { width: 1, height: 1, data: new Uint8Array([PAPER]) };
  }

  const data = new Uint8Array(W * H);
  data.fill(PAPER);

  for (let r = 0; r < H; r++) {
    const line = lines[r];
    const rowOffset = r * W;
    for (let c = 0; c < line.length; c++) {
      // Treat any non-space, non-control char as ink.
      const ch = line.charCodeAt(c);
      if (ch !== 0x20 /* space */ && ch !== 0x09 /* tab */) {
        data[rowOffset + c] = INK;
      }
    }
  }

  return { width: W, height: H, data };
}
