import fixture from "../../../content_factory/sample_data/review_fingerprint_fixture.json" with { type: "json" };
import { reviewBatchFingerprint } from "./review_fingerprint.ts";

Deno.test("Pythonとホスト版で審査証跡が一致する", async () => {
  const result = await reviewBatchFingerprint(fixture.drafts, fixture.reviews);
  if (result !== fixture.expected) throw new Error(`Fingerprint mismatch: ${result}`);
});

Deno.test("正解と審査内容の変更で保存済み判定が無効になる", async () => {
  const changed = structuredClone(fixture);
  changed.drafts[0].question.correctSegmentIds = ["s1"];
  const result = await reviewBatchFingerprint(changed.drafts, changed.reviews);
  if (result === fixture.expected) throw new Error("Changed answer was not detected");
  const changedReview = structuredClone(fixture);
  changedReview.reviews[0].review.qualityEvidence.findingNotes += " 未確認の条件があります。";
  if (await reviewBatchFingerprint(changedReview.drafts, changedReview.reviews) === fixture.expected) {
    throw new Error("Changed review was not detected");
  }
});
