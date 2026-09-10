/**
 * Pure text-statistics helpers. No I/O, no randomness, no time dependence.
 */

/**
 * Counts the number of whitespace-separated words in the given text.
 * Leading/trailing/consecutive whitespace does not affect the count.
 */
export function wordCount(text: string): number {
  const trimmed = text.trim();
  if (trimmed === "") {
    return 0;
  }
  return trimmed.split(/\s+/).length;
}

/**
 * Builds a histogram of character frequencies in the given text.
 * Whitespace characters are excluded from the histogram.
 */
export function charHistogram(text: string): Map<string, number> {
  const histogram = new Map<string, number>();
  for (const ch of text) {
    if (/\s/.test(ch)) {
      continue;
    }
    histogram.set(ch, (histogram.get(ch) ?? 0) + 1);
  }
  return histogram;
}

/** A single entry in a top-N ranking. */
export interface RankedEntry {
  key: string;
  count: number;
}

/**
 * Returns the top N entries of the histogram, sorted by count descending.
 * Ties are broken by ascending key (lexicographic) so results are deterministic.
 */
export function topN(histogram: Map<string, number>, n: number): RankedEntry[] {
  if (n < 0) {
    throw new RangeError("n must be non-negative");
  }
  const entries: RankedEntry[] = Array.from(histogram, ([key, count]) => ({ key, count }));
  entries.sort((a, b) => {
    if (b.count !== a.count) {
      return b.count - a.count;
    }
    return a.key < b.key ? -1 : a.key > b.key ? 1 : 0;
  });
  return entries.slice(0, n);
}
