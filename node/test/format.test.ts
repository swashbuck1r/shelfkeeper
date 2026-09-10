import { describe, expect, it } from "vitest";
import { formatTable } from "../src/format.js";
import type { RankedEntry } from "../src/stats.js";

describe("formatTable", () => {
  it("renders a header row and one data row", () => {
    const entries: RankedEntry[] = [{ key: "a", count: 3 }];
    const table = formatTable(entries);
    const lines = table.split("\n");
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain("key");
    expect(lines[0]).toContain("count");
  });

  it("renders an empty table with only a header when given no entries", () => {
    const table = formatTable([]);
    expect(table.split("\n")).toHaveLength(1);
  });

  it("pads columns to the widest cell", () => {
    const entries: RankedEntry[] = [
      { key: "a", count: 1 },
      { key: "bbbb", count: 22 },
    ];
    const table = formatTable(entries);
    const lines = table.split("\n");
    // The key column is padEnd'd to the widest key ("bbbb", length 4),
    // so every line's first 4 characters are the (possibly space-padded) key.
    expect(lines[0].slice(0, 4)).toBe("key ");
    expect(lines[1].slice(0, 4)).toBe("a   ");
    expect(lines[2].slice(0, 4)).toBe("bbbb");
  });

  it("preserves row order (already sorted by caller)", () => {
    const entries: RankedEntry[] = [
      { key: "z", count: 5 },
      { key: "a", count: 1 },
    ];
    const table = formatTable(entries);
    const lines = table.split("\n");
    expect(lines[1]).toContain("z");
    expect(lines[2]).toContain("a");
  });

  it("is deterministic for the same input", () => {
    const entries: RankedEntry[] = [{ key: "x", count: 9 }];
    expect(formatTable(entries)).toBe(formatTable(entries));
  });

  it("right-aligns the count column", () => {
    const entries: RankedEntry[] = [
      { key: "a", count: 1 },
      { key: "b", count: 100 },
    ];
    const table = formatTable(entries);
    const lines = table.split("\n");
    expect(lines[1].endsWith("  1")).toBe(true);
    expect(lines[2].endsWith("100")).toBe(true);
  });
});
