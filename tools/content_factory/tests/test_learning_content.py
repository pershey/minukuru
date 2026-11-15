from __future__ import annotations

import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[3]
QUESTIONS_PATH = ROOT / "MinukuruApp" / "Resources" / "learning_questions.json"
SCHEMA_PATH = ROOT / "content_factory" / "schemas" / "quiz_question.schema.json"


class LearningContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.questions = json.loads(QUESTIONS_PATH.read_text(encoding="utf-8"))
        cls.schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))

    def test_representative_questions_match_schema(self) -> None:
        validator = Draft202012Validator(self.schema)

        for question in self.questions:
            errors = sorted(validator.iter_errors(question), key=lambda error: list(error.path))
            self.assertEqual(
                errors,
                [],
                f"{question['id']}: " + "; ".join(error.message for error in errors),
            )

    def test_ids_and_answers_are_referentially_consistent(self) -> None:
        question_ids = [question["id"] for question in self.questions]
        self.assertEqual(len(question_ids), len(set(question_ids)))

        for question in self.questions:
            segment_ids = {segment["id"] for segment in question["segments"]}
            self.assertTrue(set(question["correctSegmentIds"]).issubset(segment_ids), question["id"])

            choices = {choice["id"]: choice for choice in question.get("answerChoices", [])}
            if question["responseType"] == "singleChoice":
                self.assertIn(question["correctChoiceId"], choices, question["id"])
                self.assertEqual(question["correctSegmentIds"], [], question["id"])
            else:
                self.assertGreaterEqual(len(question["correctSegmentIds"]), 1, question["id"])
                self.assertIsNone(question.get("correctChoiceId"), question["id"])

    def test_small_representative_curriculum_covers_required_learning_states(self) -> None:
        child_questions = [question for question in self.questions if question["audience"] == "child"]
        adult_questions = [question for question in self.questions if question["audience"] == "adult"]

        self.assertGreaterEqual(len(child_questions), 10)
        self.assertGreaterEqual(len(adult_questions), 3)
        self.assertTrue({"example", "practice", "action", "challenge"}.issubset(
            {question["learningStage"] for question in child_questions}
        ))
        self.assertTrue({"pause", "evidence", "verify", "consult"}.issubset(
            {question["learningFocus"] for question in child_questions}
        ))

    def test_child_questions_include_complete_reading_support(self) -> None:
        phonetic_fields = (
            "phoneticTitle",
            "phoneticInstruction",
            "phoneticExplanation",
            "phoneticVerificationTip",
            "phoneticHint",
            "phoneticAttentionPoint",
        )

        for question in self.questions:
            if question["audience"] != "child":
                continue
            for field in phonetic_fields:
                self.assertTrue(question.get(field), f"{question['id']}: {field}")
            for segment in question["segments"]:
                self.assertTrue(segment.get("phoneticText"), f"{question['id']}: {segment['id']}")
            for choice in question.get("answerChoices", []):
                self.assertTrue(choice.get("phoneticText"), f"{question['id']}: {choice['id']}")

    def test_uncertain_and_no_issue_answers_are_explicit_and_distinct(self) -> None:
        correct_semantics: set[str] = set()

        for question in self.questions:
            if question["responseType"] != "singleChoice":
                continue
            choices = {choice["id"]: choice for choice in question["answerChoices"]}
            correct_semantics.add(choices[question["correctChoiceId"]]["semantic"])

            if choices[question["correctChoiceId"]]["semantic"] == "noIssueFound":
                combined_explanation = question["explanation"] + question["verificationTip"]
                self.assertNotIn("絶対安全", combined_explanation, question["id"])

        self.assertIn("insufficientInformation", correct_semantics)
        self.assertIn("noIssueFound", correct_semantics)
        self.assertNotEqual("insufficientInformation", "noIssueFound")

    def test_action_questions_teach_more_than_one_next_step(self) -> None:
        action_questions = [question for question in self.questions if question["learningStage"] == "action"]
        action_semantics = set()

        for question in action_questions:
            choices = {choice["id"]: choice for choice in question["answerChoices"]}
            action_semantics.add(choices[question["correctChoiceId"]]["semantic"])

        self.assertIn("verifySource", action_semantics)
        self.assertIn("consultTrustedPerson", action_semantics)


if __name__ == "__main__":
    unittest.main()
