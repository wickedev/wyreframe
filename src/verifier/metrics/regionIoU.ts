// regionIoU.ts
// Coarse spatial agreement metric: divide each bitmap into an N×N grid,
// mark cells as "occupied" if their non-white density crosses a threshold,
// compute IoU over the occupancy masks.
//
// Catches "is content in roughly the same regions" without requiring
// pixel-exact match. Cheaper and more forgiving than SSIM, complementary
// in failure modes.

import type { Bitmap, MetricResult } from "../types.js";
import { padToCommonSize } from "../compare/ssim.js";

/**
 * Compute density grid: each cell's value is the fraction of non-white pixels.
 */
function densityGrid(bm: Bitmap, n: number): Float32Array {
  const grid = new Float32Array(n * n);
  const cellW = bm.width / n;
  const cellH = bm.height / n;

  for (let gy = 0; gy < n; gy++) {
    const y0 = Math.floor(gy * cellH);
    const y1 = Math.floor((gy + 1) * cellH);
    for (let gx = 0; gx < n; gx++) {
      const x0 = Math.floor(gx * cellW);
      const x1 = Math.floor((gx + 1) * cellW);

      let ink = 0;
      let total = 0;
      for (let y = y0; y < y1; y++) {
        const rowOff = y * bm.width;
        for (let x = x0; x < x1; x++) {
          if (bm.data[rowOff + x] < 128) ink++;
          total++;
        }
      }
      grid[gy * n + gx] = total === 0 ? 0 : ink / total;
    }
  }
  return grid;
}

/**
 * Compute IoU between two density grids after thresholding.
 */
export function regionIoU(
  asciiBitmap: Bitmap,
  htmlBitmap: Bitmap,
  gridN = 8,
  threshold = 0.1
): MetricResult {
  const [a, b] = padToCommonSize(asciiBitmap, htmlBitmap);
  const ga = densityGrid(a, gridN);
  const gb = densityGrid(b, gridN);

  let intersection = 0;
  let union = 0;
  for (let i = 0; i < gridN * gridN; i++) {
    const aOcc = ga[i] >= threshold;
    const bOcc = gb[i] >= threshold;
    if (aOcc && bOcc) intersection++;
    if (aOcc || bOcc) union++;
  }

  const score = union === 0 ? 1 : intersection / union;
  return { score, raw: intersection };
}
