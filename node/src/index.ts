/**
 * Public exports and a tiny CLI entry point.
 *
 * CLI usage: reads text from stdin, prints word count and a top-5
 * character-frequency table to stdout.
 */
export { wordCount, charHistogram, topN } from "./stats.js";
export type { RankedEntry } from "./stats.js";
export { formatTable } from "./format.js";

import { wordCount, charHistogram, topN } from "./stats.js";
import { formatTable } from "./format.js";

function readStdin(): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    process.stdin.on("data", (chunk: Buffer) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    process.stdin.on("error", reject);
  });
}

async function main(): Promise<void> {
  const text = await readStdin();
  const words = wordCount(text);
  const histogram = charHistogram(text);
  const top = topN(histogram, 5);

  process.stdout.write(`word count: ${words}\n`);
  process.stdout.write(formatTable(top));
  process.stdout.write("\n");
}

// Only run the CLI when this module is executed directly (not when imported).
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
