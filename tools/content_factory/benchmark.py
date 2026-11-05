"""基準問題の整合検査、解答を伏せた入力の作成、実測結果との照合。"""
from __future__ import annotations
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
import jsonschema
from content_quality import answer_matches, draft_fingerprint, validate_brief

ROOT = Path(__file__).resolve().parents[2]
QUALITY = ROOT / "content_factory/quality"


def load_records():
    return json.loads((QUALITY / "gold_questions.json").read_text())["records"]


def benchmark_draft(record):
    q = record["question"]
    return {"draftId": "benchmark-" + q["id"], "generatedQuestionId": q["id"],
            "batchLabel": "content-quality-v1", "provider": "editorial", "model": "benchmark-v1",
            "mode": q["mode"], "accessTier": q["accessTier"], "contentFlavor": q["contentFlavor"],
            "question": q, "sourceSnapshot": {"editorialBrief": record["editorialBrief"]}}


def validate_benchmark():
    from pipeline import ensure_question_invariants
    records = load_records()
    schema = json.loads((ROOT / "content_factory/schemas/quiz_question.schema.json").read_text())
    catalog = json.loads((QUALITY / "reference_catalog.json").read_text())
    ids = [r["question"]["id"] for r in records]
    if len(ids) != 30 or len(set(ids)) != 30:
        raise ValueError("基準問題は重複のない30問としてください。")
    modes = Counter()
    briefs = json.loads((QUALITY / "editorial_briefs.json").read_text())
    for record in records:
        q = record["question"]
        jsonschema.validate(q, schema)
        ensure_question_invariants(q)
        if briefs.get(q["id"]) != record["editorialBrief"]:
            raise ValueError("基準問題と審査用の編集メモが一致しません: " + q["id"])
        if q["audience"] != "child" or record["labelStatus"] != "editorial_provisional":
            raise ValueError("基準問題は子供向けの編集基準候補です。検証済みと表示しないでください。")
        errors = validate_brief(record["editorialBrief"], catalog)
        if errors:
            raise ValueError(" / ".join(errors))
        answer = {**record["expectedAnswer"], "answerable": True, "hasAlternativeAnswer": False}
        if not answer_matches(q, answer):
            raise ValueError("基準解答が本文の正解設定と一致しません: " + q["id"])
        modes[q["mode"]] += 1
    if len(modes) != 5 or set(modes.values()) != {6}:
        raise ValueError("5モード各6問を基準にしてください。")
    return {"questionCount": len(records), "modes": dict(modes), "labelStatus": "editorial_provisional",
            "liveModelEvaluation": "not_run", "childUserTesting": "not_run"}


def evaluate_reviews(records, reviews):
    by_id = {r["generatedQuestionId"]: r for r in reviews}
    if len(by_id) != len(reviews) or set(by_id) != {r["question"]["id"] for r in records}:
        raise ValueError("基準問題すべての審査を、重複や余分な問題なしで指定してください。")
    groups = defaultdict(lambda: {"total": 0, "matched": 0})
    failures = []
    for record in records:
        q = record["question"]
        evidence = by_id[q["id"]]["review"].get("qualityEvidence", {})
        if evidence.get("draftFingerprint") != draft_fingerprint(benchmark_draft(record)):
            raise ValueError("審査した基準問題の内容が一致しません: " + q["id"])
        answer = evidence.get("solver", {}).get("answer", {})
        matched = answer_matches(q, answer)
        choice = next((c for c in q.get("answerChoices", []) if c["id"] == q.get("correctChoiceId")), {})
        group = choice.get("semantic", "selectSegments")
        groups[group]["total"] += 1
        groups[group]["matched"] += int(matched)
        if not matched:
            failures.append(q["id"])
    matched_count = len(records) - len(failures)
    return {"total": len(records), "matched": matched_count, "editorialAnswerAgreement": matched_count / len(records),
            "groups": dict(groups), "disagreements": failures,
            "limitations": "編集基準候補との一致率であり、子供の学習効果や専門家との一致率ではありません。"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["validate", "export-inputs", "evaluate"])
    parser.add_argument("--reviews")
    parser.add_argument("--out")
    args = parser.parse_args()
    summary = validate_benchmark()
    records = load_records()
    if args.command == "export-inputs":
        if not args.out:
            parser.error("--out が必要です。")
        path = Path(args.out)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(benchmark_draft(r), ensure_ascii=False) + "\n" for r in records))
    elif args.command == "evaluate":
        if not args.reviews:
            parser.error("--reviews が必要です。")
        reviews = [json.loads(line) for line in Path(args.reviews).read_text().splitlines() if line.strip()]
        summary = evaluate_reviews(records, reviews)
        if args.out:
            path = Path(args.out)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
