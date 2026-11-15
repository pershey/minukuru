// Pythonの内容審査ツールと同じ形式で、問題・正解・素材・審査を結び付ける。
type Row = Record<string, unknown>;
function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const row = value as Row;
    return `{${Object.keys(row).sort().map((k) => `${JSON.stringify(k)}:${canonical(row[k])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}
async function digest(value: string): Promise<string> {
  const result = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(result)].map((n) => n.toString(16).padStart(2, "0")).join("");
}
export async function reviewBatchFingerprint(drafts: Row[], reviews: Row[]): Promise<string> {
  const byID = new Map(reviews.map((r) => [r.draftId, r]));
  if (byID.size !== reviews.length) throw new Error("Duplicate reviews");
  const lines = [];
  for (const draft of [...drafts].sort((a, b) => String(a.draftId) < String(b.draftId) ? -1 : 1)) {
    const draftFingerprint = await digest(canonical({question: draft.question, sourceSnapshot: draft.sourceSnapshot ?? {},
      provider: draft.provider ?? null, model: draft.model ?? null}));
    const source = byID.get(draft.draftId) ?? {};
    const review: Row = {};
    for (const key of ["reviewStage", "reviewerKind", "reviewerModel", "similarityRatio", "review"]) review[key] = source[key] ?? null;
    const hash = await digest(canonical({draftFingerprint, review}));
    lines.push(`${draft.draftId}\t${draft.generatedQuestionId}\t${hash}`);
  }
  return await digest(lines.join("\n"));
}
