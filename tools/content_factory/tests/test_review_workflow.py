from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace


SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from render_review_dashboard import build_dashboard  # noqa: E402
from pipeline import prepare_human_review  # noqa: E402
from review_workflow import (  # noqa: E402
    ReviewWorkflowError,
    batch_fingerprint,
    compile_review_outputs,
)


def question() -> dict:
    return {
        "id": "premium-test-001",
        "mode": "scamAdChecker",
        "title": "限定案内",
        "difficulty": "normal",
        "instruction": "怪しいところを選んでください。",
        "segments": [
            {"id": "s1", "text": "通常の案内です。"},
            {"id": "s2", "text": "今だけ必ず得をします。"},
        ],
        "correctSegmentIds": ["s2"],
        "explanation": "言い切りに根拠がありません。",
        "verificationTip": "条件と出典を確認します。",
        "hint": "強い言い方に注目。",
        "recommendedReasonTags": ["tooStrongClaim"],
        "accessTier": "premium",
        "contentFlavor": "standard",
    }


def draft() -> dict:
    return {
        "draftId": "draft-001",
        "taskId": "task-001",
        "batchLabel": "batch-001",
        "provider": "openai",
        "model": "test-model",
        "mode": "scamAdChecker",
        "accessTier": "premium",
        "contentFlavor": "standard",
        "generatedQuestionId": "premium-test-001",
        "question": question(),
        "sourceSnapshot": {
            "title": "素材",
            "redactedExcerpt": "匿名化済みの素材です。",
            "referenceNotes": "テスト",
        },
    }


def ai_review() -> dict:
    return {
        "reviewId": "review-001",
        "draftId": "draft-001",
        "generatedQuestionId": "premium-test-001",
        "reviewStage": "generation_self_check",
        "reviewerKind": "rulebased",
        "reviewerModel": "local-heuristics",
        "similarityRatio": 0.1,
        "topSimilarQuestions": [],
        "review": {
            "passed": True,
            "action": "accept",
            "realismScore": 80,
            "safetyScore": 95,
            "learningScore": 85,
            "uniquenessScore": 90,
            "segmentClarityScore": 88,
            "compositeScore": 87,
            "matchedSignals": ["tooStrongClaim"],
            "concerns": [],
            "duplicateSignals": [],
            "revisionAdvice": [],
            "summary": "問題ありません。",
        },
        "createdAt": "2026-09-15T00:00:00Z",
    }


def task() -> dict:
    return {
        "taskId": "task-001",
        "batchLabel": "batch-001",
        "sourceExample": {"id": "source-001"},
        "blueprint": {"slug": "blueprint-001"},
        "mode": "scamAdChecker",
        "accessTier": "premium",
        "contentFlavor": "standard",
        "targetDifficulty": "normal",
        "userPrompt": "これは元の生成プロンプトです。十分な長さを持つテスト用の文章として用意しています。",
    }


def decisions(action: str, note: str = "") -> dict:
    drafts = [draft()]
    return {
        "schemaVersion": 1,
        "batchFingerprint": batch_fingerprint(drafts),
        "exportedAt": "2026-09-15T01:00:00Z",
        "decisions": [
            {
                "draftId": "draft-001",
                "generatedQuestionId": "premium-test-001",
                "decision": action,
                "note": note,
                "decidedAt": "2026-09-15T01:00:00Z",
            }
        ],
    }


class ReviewWorkflowTests(unittest.TestCase):
    def test_accept_creates_manual_review(self) -> None:
        result = compile_review_outputs([draft()], [ai_review()], [task()], decisions("accept"))

        self.assertEqual(result["summary"]["acceptedCount"], 1)
        self.assertEqual(result["summary"]["pendingCount"], 0)
        self.assertEqual(result["humanReviews"][0]["reviewStage"], "human_review")
        self.assertEqual(result["humanReviews"][0]["review"]["action"], "accept")

    def test_revise_creates_new_task_with_note(self) -> None:
        result = compile_review_outputs(
            [draft()],
            [ai_review()],
            [task()],
            decisions("revise", "言い切りを弱めて広告らしさを残す"),
        )

        revised = result["regenerationTasks"][0]
        self.assertNotEqual(revised["taskId"], "task-001")
        self.assertIn("言い切りを弱めて広告らしさを残す", revised["userPrompt"])
        self.assertEqual(result["humanReviews"][0]["review"]["action"], "revise")

    def test_stale_fingerprint_is_rejected(self) -> None:
        payload = decisions("accept")
        payload["batchFingerprint"] = "0" * 64

        with self.assertRaisesRegex(ReviewWorkflowError, "更新されています"):
            compile_review_outputs([draft()], [ai_review()], [task()], payload)

    def test_revise_requires_note(self) -> None:
        with self.assertRaisesRegex(ReviewWorkflowError, "メモが必要"):
            compile_review_outputs([draft()], [ai_review()], [task()], decisions("revise"))

    def test_dashboard_contains_decision_controls(self) -> None:
        output = build_dashboard([draft()], [ai_review()], "レビュー")

        self.assertIn('data-decision="accept"', output)
        self.assertIn('id="export-decisions"', output)
        self.assertIn(batch_fingerprint([draft()]), output)

    def test_dashboard_renders_single_choice_learning_metadata(self) -> None:
        choice_draft = draft()
        choice_draft["question"] = {
            **question(),
            "audience": "child",
            "learningStage": "action",
            "learningFocus": "verify",
            "responseType": "singleChoice",
            "correctSegmentIds": [],
            "answerChoices": [
                {"id": "a1", "text": "送ってきた人に聞く", "semantic": "other"},
                {"id": "a2", "text": "公式の案内を調べる", "semantic": "verifySource"},
            ],
            "correctChoiceId": "a2",
            "attentionPoint": "確認先を選びます。",
        }

        output = build_dashboard([choice_draft], [ai_review()], "レビュー")

        self.assertIn("公式の案内を調べる", output)
        self.assertIn("verifySource", output)
        self.assertIn("確認先を選びます。", output)
        self.assertIn("action", output)

    def test_prepare_command_writes_manifest_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            paths = {
                "drafts": root / "drafts.jsonl",
                "reviews": root / "reviews.jsonl",
                "tasks": root / "tasks.jsonl",
                "decisions": root / "decisions.json",
                "out": root / "out",
            }
            for key, rows in (("drafts", [draft()]), ("reviews", [ai_review()]), ("tasks", [task()])):
                paths[key].write_text(
                    "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows),
                    encoding="utf-8",
                )
            paths["decisions"].write_text(
                json.dumps(decisions("accept"), ensure_ascii=False),
                encoding="utf-8",
            )

            prepare_human_review(
                SimpleNamespace(
                    drafts=str(paths["drafts"]),
                    reviews=str(paths["reviews"]),
                    tasks=str(paths["tasks"]),
                    decisions=str(paths["decisions"]),
                    out_dir=str(paths["out"]),
                    require_complete=True,
                    sync=False,
                )
            )

            self.assertTrue((paths["out"] / "human_reviews.jsonl").exists())
            self.assertTrue((paths["out"] / "decision_summary.json").exists())
            summary = json.loads((paths["out"] / "decision_summary.json").read_text(encoding="utf-8"))
            self.assertEqual(summary["acceptedCount"], 1)


if __name__ == "__main__":
    unittest.main()
