// levenshtein.ts
// Classic O(m*n) Levenshtein edit distance with O(min(m,n)) memory.
//
// Used by cycleEditDistance to measure how far the printer's output drifts
// from the original ASCII input. Deterministic, dependency-free.

export function levenshtein(a: string, b: string): number {
  if (a === b) return 0;
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;

  // Ensure a is the shorter string to minimize memory.
  if (a.length > b.length) [a, b] = [b, a];

  const m = a.length;
  const n = b.length;

  let prev = new Int32Array(m + 1);
  let curr = new Int32Array(m + 1);

  for (let i = 0; i <= m; i++) prev[i] = i;

  for (let j = 1; j <= n; j++) {
    curr[0] = j;
    const bj = b.charCodeAt(j - 1);
    for (let i = 1; i <= m; i++) {
      const cost = a.charCodeAt(i - 1) === bj ? 0 : 1;
      const del = curr[i - 1] + 1;
      const ins = prev[i] + 1;
      const sub = prev[i - 1] + cost;
      curr[i] = del < ins ? (del < sub ? del : sub) : ins < sub ? ins : sub;
    }
    [prev, curr] = [curr, prev];
  }

  return prev[m];
}

/**
 * Normalized edit distance ∈ [0, 1]. 0 = identical, 1 = completely different.
 */
export function normalizedEditDistance(a: string, b: string): number {
  if (a.length === 0 && b.length === 0) return 0;
  return levenshtein(a, b) / Math.max(a.length, b.length);
}
