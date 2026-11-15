import { premiumSummary } from "./premium_summary.ts";

Deno.test("購入前の概要は件数のみ返し教材の内容を含めない", () => {
  const response = premiumSummary({
    questions: [
      { id: "std", accessTier: "premium", contentFlavor: "standard", explanation: "非公開" },
      { id: "rw", accessTier: "premium", contentFlavor: "realWorld", segments: ["非公開"] },
      { id: "old", accessTier: "premium" },
    ],
    storagePath: "非公開",
  });
  if (JSON.stringify(response) !== '{"standardCount":2,"realWorldCount":1}') {
    throw new Error("概要の形式が不正です。");
  }
});

Deno.test("重複や有料以外の混入を概要に数えない", () => {
  const row = { id: "paid", accessTier: "premium", contentFlavor: "standard" };
  for (const rows of [[row, row], [{ ...row, accessTier: "free" }], [{ ...row, contentFlavor: "unknown" }]]) {
    try {
      premiumSummary({ questions: rows });
    } catch {
      continue;
    }
    throw new Error("不正な問題を数えました。");
  }
});
