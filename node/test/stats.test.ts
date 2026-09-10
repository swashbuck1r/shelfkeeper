import { describe, expect, it } from "vitest";
import { wordCount, charHistogram, topN } from "../src/stats.js";

describe("wordCount", () => {
  it("counts words separated by single spaces", () => {
    expect(wordCount("the quick brown fox")).toBe(4);
  });

  it("counts a single word", () => {
    expect(wordCount("hello")).toBe(1);
  });

  it("is deterministic across repeated calls", () => {
    expect(wordCount("stable input")).toBe(wordCount("stable input"));
  });

  it("returns 0 for an empty string", () => {
    expect(wordCount("")).toBe(0);
  });

  it("returns 0 for a whitespace-only string", () => {
    expect(wordCount("   \t\n  ")).toBe(0);
  });

  it("collapses consecutive whitespace", () => {
    expect(wordCount("a    b\tc\nd")).toBe(4);
  });

  it("ignores leading and trailing whitespace", () => {
    expect(wordCount("  padded words  ")).toBe(2);
  });
});

describe("charHistogram", () => {
  it("counts character frequency", () => {
    const hist = charHistogram("aab");
    expect(hist.get("a")).toBe(2);
    expect(hist.get("b")).toBe(1);
  });

  it("excludes whitespace characters", () => {
    const hist = charHistogram("a b\tc\nd");
    expect(hist.has(" ")).toBe(false);
    expect(hist.has("\t")).toBe(false);
    expect(hist.has("\n")).toBe(false);
    expect(hist.size).toBe(4);
  });

  it("returns an empty map for an empty string", () => {
    const hist = charHistogram("");
    expect(hist.size).toBe(0);
  });

  it("is case-sensitive", () => {
    const hist = charHistogram("Aa");
    expect(hist.get("A")).toBe(1);
    expect(hist.get("a")).toBe(1);
  });

  it("counts punctuation and digits", () => {
    const hist = charHistogram("a1a1!");
    expect(hist.get("a")).toBe(2);
    expect(hist.get("1")).toBe(2);
    expect(hist.get("!")).toBe(1);
  });
});

describe("topN", () => {
  it("returns entries sorted by count descending", () => {
    const hist = charHistogram("aaabbc");
    const result = topN(hist, 3);
    expect(result).toEqual([
      { key: "a", count: 3 },
      { key: "b", count: 2 },
      { key: "c", count: 1 },
    ]);
  });

  it("truncates to n entries", () => {
    const hist = charHistogram("aaabbc");
    const result = topN(hist, 1);
    expect(result).toEqual([{ key: "a", count: 3 }]);
  });

  it("breaks ties by ascending key for determinism", () => {
    const hist = charHistogram("badc");
    const result = topN(hist, 4);
    expect(result).toEqual([
      { key: "a", count: 1 },
      { key: "b", count: 1 },
      { key: "c", count: 1 },
      { key: "d", count: 1 },
    ]);
  });

  it("returns an empty array for an empty histogram", () => {
    const hist = charHistogram("");
    expect(topN(hist, 5)).toEqual([]);
  });

  it("returns an empty array when n is 0", () => {
    const hist = charHistogram("aabbcc");
    expect(topN(hist, 0)).toEqual([]);
  });

  it("returns all entries when n exceeds the histogram size", () => {
    const hist = charHistogram("ab");
    const result = topN(hist, 10);
    expect(result).toHaveLength(2);
  });

  it("throws a RangeError for a negative n", () => {
    const hist = charHistogram("a");
    expect(() => topN(hist, -1)).toThrow(RangeError);
  });
});
