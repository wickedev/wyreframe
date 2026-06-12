// Visual Verifier — types.ts
// Public types for the verifier API.
//
// The verifier scores a triple (input ASCII, ML-produced V2 AST, rendered HTML)
// by combining three independent signals: cycle edit distance, pixel SSIM,
// and region IoU. See ml-parser/self-improvement.md §2 and §4.3.

/**
 * Grayscale bitmap used for pixel-level metrics. Pixel values are 0..255.
 * Stored row-major.
 */
export interface Bitmap {
  width: number;
  height: number;
  /** Length = width * height. Single channel (grayscale). */
  data: Uint8Array;
}

/**
 * A single metric's contribution to the verification score.
 */
export interface MetricResult {
  /** Normalized to [0, 1]. Higher is better (more faithful). */
  score: number;
  /** Raw underlying value (e.g. edit distance, SSIM value). Useful for debugging. */
  raw: number;
}

/**
 * Pluggable HTML → bitmap renderer. The verifier does not bundle a headless
 * browser; consumers can supply their own (Playwright, Puppeteer, jsdom + DOM
 * snapshot, etc). When omitted, pixel-level metrics are skipped.
 */
export type HtmlToBitmap = (html: string) => Promise<Bitmap>;

/**
 * Inputs to a verification call.
 */
export interface VerifyInput {
  /** Original ASCII the ML model received. */
  ascii: string;
  /** V2 AST node the ML model produced (typically a SceneNode or ComponentNode). */
  ast: unknown; // V2 AST — ReScript-generated; consumers pass through opaquely
  /** Optional HTML→Bitmap renderer; if absent, pixel SSIM + region IoU are skipped. */
  htmlToBitmap?: HtmlToBitmap;
}

/**
 * Tunable weights for combining metric scores. Defaults sum to 1.0 when all
 * three metrics are available; the orchestrator renormalizes if some are missing.
 */
export interface VerifyWeights {
  cycle: number;
  ssim: number;
  iou: number;
}

/**
 * Options controlling verifier behavior.
 */
export interface VerifyOptions {
  /** Weighting of the three sub-metrics. Default: { cycle: 0.5, ssim: 0.3, iou: 0.2 }. */
  weights?: Partial<VerifyWeights>;
  /** Window size (cells) for windowed SSIM. Default 8. */
  ssimWindow?: number;
  /** Grid size for region-IoU density map. Default 8 (→ 8×8 grid). */
  iouGrid?: number;
  /** Density threshold for IoU occupancy. Default 0.1. */
  iouThreshold?: number;
}

/**
 * Result of a verification run.
 */
export interface VerifyResult {
  /** Weighted combined score ∈ [0, 1]. */
  score: number;
  /** Per-metric breakdown. Metrics that could not run are absent. */
  metrics: {
    cycleEditDistance: MetricResult;
    pixelSSIM?: MetricResult;
    regionIoU?: MetricResult;
  };
  /** Non-fatal issues (e.g. missing htmlToBitmap, oversized inputs). */
  warnings: string[];
}
