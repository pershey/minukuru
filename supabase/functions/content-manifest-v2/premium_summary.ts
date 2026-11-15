/** 購入画面向け。返す情報は配信中の有料問題数だけ。 */
export function premiumSummary(value: unknown): { standardCount: number; realWorldCount: number } {
  const rows = (value as { questions?: unknown } | null)?.questions;
  if (!Array.isArray(rows)) throw new Error("Invalid premium manifest.");
  let standardCount = 0;
  let realWorldCount = 0;
  const ids = new Set<string>();
  for (const row of rows) {
    if (!row || typeof row.id !== "string" || row.id === "" ||
        ids.has(row.id) || row.accessTier !== "premium") {
      throw new Error("Invalid premium question.");
    }
    ids.add(row.id);
    if (row.contentFlavor === "realWorld") realWorldCount++;
    else if (row.contentFlavor === "standard" || row.contentFlavor === undefined) standardCount++;
    else throw new Error("Invalid premium question flavor.");
  }
  return { standardCount, realWorldCount };
}
