// ssim.ts
// Structural Similarity Index (SSIM) on grayscale bitmaps.
//
// Standard windowed SSIM with uniform weighting (no Gaussian — simpler,
// deterministic). Each non-overlapping window contributes equally to the
// final score. See: Wang et al., "Image Quality Assessment: From Error
// Visibility to Structural Similarity", IEEE TIP 2004.

import type { Bitmap } from "../types.js";

// SSIM constants for 8-bit grayscale (dynamic range L=255):
// c1 = (K1 * L)^2 where K1 = 0.01, c2 = (K2 * L)^2 where K2 = 0.03.
const C1 = (0.01 * 255) ** 2; // 6.5025
const C2 = (0.03 * 255) ** 2; // 58.5225

/**
 * Compute SSIM between two bitmaps. Bitmaps are padded to a common size
 * (white-padded on right/bottom) before windowing.
 *
 * Returns a value in [-1, 1], typically [0, 1] for natural images.
 */
export function ssim(a: Bitmap, b: Bitmap, windowSize = 8): number {
  const [aPadded, bPadded] = padToCommonSize(a, b);

  const ws = Math.max(1, Math.floor(windowSize));
  const w = aPadded.width;
  const h = aPadded.height;

  if (w < ws || h < ws) {
    // Fall back to a single global window if image smaller than window.
    return windowSSIM(aPadded.data, bPadded.data, 0, 0, w, h, w);
  }

  let total = 0;
  let count = 0;

  // Non-overlapping windows. Trailing partial windows ignored.
  for (let y = 0; y + ws <= h; y += ws) {
    for (let x = 0; x + ws <= w; x += ws) {
      total += windowSSIM(aPadded.data, bPadded.data, x, y, ws, ws, w);
      count++;
    }
  }

  return count === 0 ? 0 : total / count;
}

function windowSSIM(
  a: Uint8Array,
  b: Uint8Array,
  x: number,
  y: number,
  ww: number,
  wh: number,
  stride: number
): number {
  const n = ww * wh;

  let sumA = 0;
  let sumB = 0;
  for (let dy = 0; dy < wh; dy++) {
    for (let dx = 0; dx < ww; dx++) {
      const idx = (y + dy) * stride + (x + dx);
      sumA += a[idx];
      sumB += b[idx];
    }
  }

  const muA = sumA / n;
  const muB = sumB / n;

  let varA = 0;
  let varB = 0;
  let cov = 0;
  for (let dy = 0; dy < wh; dy++) {
    for (let dx = 0; dx < ww; dx++) {
      const idx = (y + dy) * stride + (x + dx);
      const da = a[idx] - muA;
      const db = b[idx] - muB;
      varA += da * da;
      varB += db * db;
      cov += da * db;
    }
  }
  varA /= n;
  varB /= n;
  cov /= n;

  const numerator = (2 * muA * muB + C1) * (2 * cov + C2);
  const denominator = (muA * muA + muB * muB + C1) * (varA + varB + C2);

  return denominator === 0 ? 1 : numerator / denominator;
}

/**
 * Right/bottom-pad both bitmaps to max(W, H) with white (255). Returns new
 * bitmaps; inputs are unchanged. Deterministic.
 */
export function padToCommonSize(a: Bitmap, b: Bitmap): [Bitmap, Bitmap] {
  const W = Math.max(a.width, b.width);
  const H = Math.max(a.height, b.height);
  return [padToSize(a, W, H), padToSize(b, W, H)];
}

function padToSize(src: Bitmap, W: number, H: number): Bitmap {
  if (src.width === W && src.height === H) return src;
  const out = new Uint8Array(W * H).fill(255);
  for (let y = 0; y < src.height; y++) {
    const srcStart = y * src.width;
    const dstStart = y * W;
    out.set(src.data.subarray(srcStart, srcStart + src.width), dstStart);
  }
  return { width: W, height: H, data: out };
}

/**
 * Map SSIM ∈ [-1, 1] to a score ∈ [0, 1]. Clamps to be safe.
 */
export function ssimToScore(s: number): number {
  if (Number.isNaN(s)) return 0;
  if (s <= 0) return 0;
  if (s >= 1) return 1;
  return s;
}
