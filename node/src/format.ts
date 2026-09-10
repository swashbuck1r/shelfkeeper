/**
 * Minimal table-rendering helper for displaying ranked entries.
 */
import type { RankedEntry } from "./stats.js";

/**
 * Renders ranked entries as a simple two-column, left-aligned text table
 * with a header row. Columns are padded to the widest cell in that column.
 */
export function formatTable(entries: RankedEntry[]): string {
  const header = ["key", "count"];
  const rows = entries.map((e) => [e.key, String(e.count)]);
  const allRows = [header, ...rows];

  const keyWidth = Math.max(...allRows.map((r) => r[0].length));
  const countWidth = Math.max(...allRows.map((r) => r[1].length));

  return allRows.map((r) => `${r[0].padEnd(keyWidth)}  ${r[1].padStart(countWidth)}`).join("\n");
}
