from __future__ import annotations
import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from benchmark import benchmark_draft, evaluate_reviews, load_records, validate_benchmark
from content_quality import answer_matches, blind_question, publication_blockers, quality_blockers
from pipeline import approved_questions_and_report, build_parser, build_refresh_drafts_from_reviews_sql, openai_strict_schema, run_review
from review_workflow import ReviewWorkflowError, batch_fingerprint, compile_review_outputs
from test_review_workflow import ai_review, decisions, draft, task

ROOT = Path(__file__).resolve().parents[3]
CATALOG = json.loads((ROOT / "content_factory/quality/reference_catalog.json").read_text())


class ContentQualityTests(unittest.TestCase):
    def test_reference_set_has_thirty_child_questions_and_discriminating_answers(self):
        self.assertEqual(validate_benchmark()["questionCount"], 30)
        semantics = {c["semantic"] for r in load_records() for c in r["question"].get("answerChoices", [])
                     if c["id"] == r["question"].get("correctChoiceId")}
        self.assertTrue({"noIssueFound", "insufficientInformation", "verifySource", "pause", "consultTrustedPerson"} <= semantics)

    def test_blind_prompt_hides_answer_key_hints_and_choice_semantics(self):
        q = next(r["question"] for r in load_records() if r["question"]["responseType"] == "singleChoice")
        visible = blind_question(q)
        for key in ("correctChoiceId", "correctSegmentIds", "explanation", "hint", "recommendedReasonTags", "attentionPoint"):
            self.assertNotIn(key, visible)
        self.assertTrue(all(set(c) == {"id", "text"} for c in visible["answerChoices"]))

    def test_rule_check_cannot_be_accepted_as_a_content_review(self):
        review = ai_review()
        review["review"].pop("qualityEvidence")
        payload = decisions("accept")
        payload["batchFingerprint"] = batch_fingerprint([draft()], [review])
        with self.assertRaisesRegex(ReviewWorkflowError, "内容審査"):
            compile_review_outputs([draft()], [review], [task()], payload)

    def test_changed_answer_key_or_reading_requires_another_review(self):
        for key, value in (("correctSegmentIds", ["s1"]), ("phoneticExplanation", "もとの せつめいとは べつの いみです。")):
            changed = draft()
            changed["question"][key] = value
            self.assertTrue(quality_blockers(changed, ai_review()["review"], CATALOG))
            self.assertNotEqual(batch_fingerprint([changed], [ai_review()]), batch_fingerprint([draft()], [ai_review()]))

    def test_changed_model_review_invalidates_saved_human_decision(self):
        changed = ai_review()
        changed["review"]["qualityEvidence"]["checks"]["answerValidity"] = "uncertain"
        with self.assertRaisesRegex(ReviewWorkflowError, "更新されています"):
            compile_review_outputs([draft()], [changed], [task()], decisions("accept"))

    def test_uncertain_semantics_and_disagreement_block_publication(self):
        for change in ("criterion", "disagreement", "same_model", "unknown_source"):
            review = ai_review()
            evidence = review["review"]["qualityEvidence"]
            if change == "criterion":
                evidence["checks"]["evidenceGrounding"] = "uncertain"
            elif change == "disagreement":
                evidence["solver"]["answer"]["selectedSegmentIds"] = ["s1"]
            elif change == "same_model":
                evidence["solver"] |= {"provider": draft()["provider"], "model": draft()["model"]}
            else:
                evidence["brief"]["sourceIds"] = ["unknown"]
            self.assertTrue(quality_blockers(draft(), review["review"], CATALOG), change)

    def test_changed_catalog_invalidates_evidence(self):
        changed = copy.deepcopy(CATALOG)
        changed["sources"][0]["reviewedSummary"] += " 確認した範囲を更新。"
        self.assertTrue(quality_blockers(draft(), ai_review()["review"], changed))

    def test_educational_source_cannot_verify_external_factual_claims(self):
        review = ai_review()
        review["review"]["qualityEvidence"]["brief"]["factBasis"] = "primarySources"
        self.assertTrue(quality_blockers(draft(), review["review"], CATALOG))

    def test_only_bound_semantic_review_followed_by_human_accept_can_publish(self):
        self.assertTrue(publication_blockers(draft(), ai_review(), CATALOG))
        compiled = compile_review_outputs([draft()], [ai_review()], [task()], decisions("accept"))
        human = compiled["humanReviews"][0]
        self.assertEqual(publication_blockers(draft(), human, CATALOG), [])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "drafts").write_text(json.dumps(draft()) + "\n")
            for review, expected in ((ai_review(), 0), (human, 1)):
                (root / "reviews").write_text(json.dumps(review) + "\n")
                questions, _ = approved_questions_and_report(root / "drafts", root / "reviews", 78, 86, 72, 70, .92)
                self.assertEqual(len(questions), expected)

    def test_same_batch_duplicates_are_flagged_in_both_directions(self):
        first = benchmark_draft(load_records()[0])
        second = copy.deepcopy(first)
        second["draftId"] += "-copy"
        second["generatedQuestionId"] += "-copy"
        second["question"]["id"] += "-copy"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "drafts").write_text("\n".join(json.dumps(d) for d in (first, second)))
            args = build_parser().parse_args(["run-review", "--drafts", str(root / "drafts"),
                "--existing-manifest", str(root / "absent"), "--out", str(root / "reviews")])
            run_review(args)
            reviews = [json.loads(line) for line in (root / "reviews").read_text().splitlines()]
            self.assertEqual([r["review"]["action"] for r in reviews], ["revise", "revise"])

    def test_preflight_missing_solver_makes_no_paid_api_calls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "drafts").write_text(json.dumps(benchmark_draft(load_records()[0])) + "\n")
            args = build_parser().parse_args(["run-review", "--provider", "openai", "--model", "review-model",
                "--drafts", str(root / "drafts"), "--out", str(root / "reviews")])
            with patch("pipeline.call_openai_json") as call:
                with self.assertRaisesRegex(RuntimeError, "solver-model"):
                    run_review(args)
                call.assert_not_called()

    def test_blind_answer_then_semantic_review_produce_bound_evidence(self):
        source = benchmark_draft(load_records()[0])
        score = copy.deepcopy(ai_review()["review"])
        score.pop("qualityEvidence")
        blind = {"selectedSegmentIds": source["question"]["correctSegmentIds"], "selectedChoiceId": None,
                 "answerable": True, "hasAlternativeAnswer": False, "summary": "期限に注意し、すぐに申し込まず条件を確認します。"}
        judgment = {"review": score, "checks": ai_review()["review"]["qualityEvidence"]["checks"],
                    "findingNotes": "架空の案内の条件、正解、解説と確認行動が対応することを確認しました。"}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "drafts").write_text(json.dumps(source) + "\n")
            args = build_parser().parse_args(["run-review", "--provider", "openai", "--model", "review-model",
                "--solver-model", "solver-model", "--drafts", str(root / "drafts"),
                "--existing-manifest", str(root / "absent"), "--out", str(root / "reviews")])
            with patch("pipeline.call_openai_json", side_effect=[blind, judgment]) as call:
                run_review(args)
                self.assertEqual(call.call_count, 2)
                first_payload = json.loads(call.call_args_list[0].kwargs["user_prompt"])
                self.assertNotIn("correctSegmentIds", first_payload)
            row = json.loads((root / "reviews").read_text())
            self.assertEqual(quality_blockers(source, row["review"], CATALOG), [])
            self.assertTrue(publication_blockers(source, row, CATALOG))

    def test_wire_schema_omits_unsupported_composition_but_keeps_original_validation(self):
        schema = json.loads((ROOT / "content_factory/schemas/quiz_question.schema.json").read_text())
        wire = openai_strict_schema(schema)
        self.assertNotIn("allOf", wire)
        self.assertIn("allOf", schema)

    def test_benchmark_requires_actual_complete_bound_measurements(self):
        with self.assertRaises(ValueError):
            evaluate_reviews(load_records(), [])

    def test_legacy_rule_checks_are_not_labelled_ai_reviewed(self):
        sql = build_refresh_drafts_from_reviews_sql([])
        self.assertIn("latest.review_stage = 'ai_review'", sql)
        self.assertNotIn("when latest.action = 'accept' then 'ai_reviewed'", sql)


if __name__ == "__main__":
    unittest.main()
