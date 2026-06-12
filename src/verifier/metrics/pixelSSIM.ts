// pixelSSIM.ts
// Pixel-level similarity between two bitmap representations.
//
// One is derived from the input ASCII (1 pixel per char, see asciiToBitmap).
// The other typically comes from a headless-browser screenshot of the
// V2 Renderer's HTML output. Consumers supply the HTML→Bitmap function;
// this module is renderer-agnostic.
//
// Lower scores indicate the rendered HTML's spatial structure diverges
// from the ASCII input. See ml-parser/self-improvement.md §2.1 (Pixel SSIM).

import type { Bitmap, MetricResult } from "../types.js";
import { ssim, ssimToScore } from "../compare/ssim.js";

/**
 * Compare two bitmaps with windowed SSIM and return a normalized metric.
 */
export function pixelSSIM(
  asciiBitmap: Bitmap,
  htmlBitmap: Bitmap,
  windowSize = 8
): MetricResult {
  const raw = ssim(asciiBitmap, htmlBitmap, windowSize);
  return { score: ssimToScore(raw), raw };
}
