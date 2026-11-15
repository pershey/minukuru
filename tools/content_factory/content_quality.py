"""内容審査の証跡を、問題・根拠・解答に結び付ける共通処理。"""
from __future__ import annotations

import hashlib
import json
from datetime import date
from typing import Any

POLICY_VERSION = "content-quality-v1"
REVIEW_AI_PROVIDERS = ("openai", "gemini", "claude")
CHECK_NAMES = ("answerValidity", "evidenceGrounding", "ageAppropriateness", "explanationAlignment", "actionability")


def fingerprint(value: Any) -> str:
    def normalize(item):
        if isinstance(item, dict):
            return {k: normalize(v) for k, v in item.items()}
        if isinstance(item, list):
            return [normalize(v) for v in item]
        if isinstance(item, float) and item.is_integer():
            return int(item)
        return item
    return hashlib.sha256(json.dumps(normalize(value), ensure_ascii=False, sort_keys=True,
                                     allow_nan=False, separators=(",", ":")).encode()).hexdigest()


def draft_fingerprint(draft: dict) -> str:
    return fingerprint({"question": draft["question"], "sourceSnapshot": draft.get("sourceSnapshot", {}),
                        "provider": draft.get("provider"), "model": draft.get("model")})


def blind_question(question: dict) -> dict:
    # semantic、ヒント、解説、学習目標は正解を示すため渡さない。
    return {
        key: question[key]
        for key in ("id", "mode", "title", "instruction", "segments", "responseType", "audience")
        if key in question
    } | {"answerChoices": [{"id": c["id"], "text": c["text"]} for c in question.get("answerChoices", [])]}


BLIND_ANSWER_SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["selectedSegmentIds", "selectedChoiceId", "answerable", "hasAlternativeAnswer", "summary"],
    "properties": {
        "selectedSegmentIds": {"type": "array", "items": {"type": "string"}, "maxItems": 3, "uniqueItems": True},
        "selectedChoiceId": {"type": ["string", "null"]},
        "answerable": {"type": "boolean"},
        "hasAlternativeAnswer": {"type": "boolean"},
        "summary": {"type": "string", "minLength": 10, "maxLength": 500},
    },
}


def semantic_schema(review_schema: dict) -> dict:
    score_schema = json.loads(json.dumps(review_schema))
    score_schema["properties"].pop("qualityEvidence", None)
    return {
        "type": "object", "additionalProperties": False,
        "required": ["review", "checks", "findingNotes"],
        "properties": {
            "review": score_schema,
            "checks": {"type": "object", "additionalProperties": False, "required": list(CHECK_NAMES),
                       "properties": {k: {"type": "string", "enum": ["pass", "fail", "uncertain"]} for k in CHECK_NAMES}},
            "findingNotes": {"type": "string", "minLength": 20, "maxLength": 1200},
        },
    }


def validate_brief(brief: dict, catalog: dict) -> list[str]:
    errors = []
    if not isinstance(brief, dict):
        return ["編集用の学習目標と根拠がありません。"]
    for key in ("learningObjective", "evidenceNotes"):
        if not isinstance(brief.get(key), str) or len(brief[key].strip()) < 8:
            errors.append(f"編集用の {key} が不足しています。")
    if brief.get("factBasis") not in ("fictionalScenario", "primarySources"):
        errors.append("架空の場面内で判断する問題か、外部の事実を確認する問題かを指定してください。")
    sources = {s["id"]: s for s in catalog.get("sources", [])}
    ids = brief.get("sourceIds")
    if not isinstance(ids, list) or not ids:
        errors.append("根拠資料のIDがありません。")
    else:
        for source_id in ids:
            source = sources.get(source_id) if isinstance(source_id, str) else None
            if not source:
                errors.append("登録されていない根拠資料です。")
                continue
            try:
                checked = date.fromisoformat(source.get("checkedAt", ""))
                if checked > date.today():
                    raise ValueError()
            except (ValueError, TypeError):
                errors.append("根拠資料の確認日が不正です。")
            if not source.get("url", "").startswith("https://") or not source.get("reviewedSummary"):
                errors.append("根拠資料のURLまたは確認した要点がありません。")
            if brief.get("factBasis") == "primarySources" and source.get("scope") != "factual":
                errors.append("教育方針の資料だけで外部の事実を確認済みにはできません。")
    return errors


def answer_matches(question: dict, answer: dict) -> bool:
    if not isinstance(answer, dict):
        return False
    if answer.get("answerable") is not True or answer.get("hasAlternativeAnswer") is not False:
        return False
    selected = answer.get("selectedSegmentIds")
    if not isinstance(selected, list) or not all(isinstance(item, str) for item in selected) or len(selected) != len(set(selected)):
        return False
    if question.get("responseType", "selectSegments") == "singleChoice":
        choices = {choice["id"] for choice in question.get("answerChoices", [])}
        return (not selected and question.get("correctChoiceId") in choices
                and answer.get("selectedChoiceId") == question.get("correctChoiceId"))
    return (bool(question["correctSegmentIds"]) and answer.get("selectedChoiceId") is None
            and set(selected) == set(question["correctSegmentIds"]))


def quality_blockers(draft: dict, result: dict, catalog: dict) -> list[str]:
    if not isinstance(result, dict):
        return ["内容審査の形式が不正です。"]
    evidence = result.get("qualityEvidence")
    if not isinstance(evidence, dict) or evidence.get("policyVersion") != POLICY_VERSION:
        return ["新しい内容審査の証跡がありません。"]
    blockers = validate_brief(evidence.get("brief"), catalog)
    if evidence.get("draftFingerprint") != draft_fingerprint(draft):
        blockers.append("内容審査後に問題または素材が変更されています。")
    if evidence.get("catalogFingerprint") != fingerprint(catalog):
        blockers.append("内容審査後に根拠資料が変更されています。")
    brief = evidence.get("brief")
    source_ids = brief.get("sourceIds") if isinstance(brief, dict) else []
    source_ids = source_ids if isinstance(source_ids, list) else []
    expected_sources = [s for s in catalog.get("sources", []) if s["id"] in source_ids]
    if evidence.get("references") != expected_sources:
        blockers.append("審査に使った資料と現在の参照資料が一致しません。")
    solver = evidence.get("solver") if isinstance(evidence.get("solver"), dict) else {}
    reviewer = evidence.get("reviewer") if isinstance(evidence.get("reviewer"), dict) else {}
    for role in (solver, reviewer):
        if role.get("provider") not in REVIEW_AI_PROVIDERS or not role.get("model"):
            blockers.append("内容審査のモデル情報が不足しています。")
    generator = (draft.get("provider"), draft.get("model"))
    if not all(generator):
        blockers.append("作成元のモデル情報が不足しています。")
    if generator == (solver.get("provider"), solver.get("model")):
        blockers.append("作成モデルと別のモデルで解き直してください。")
    if not answer_matches(draft["question"], solver.get("answer", {})):
        blockers.append("正解を伏せた解答が一致しないか、答えが曖昧です。")
    checks = evidence.get("checks") if isinstance(evidence.get("checks"), dict) else {}
    if any(checks.get(k) != "pass" for k in CHECK_NAMES):
        blockers.append("正解・根拠・対象年齢・解説・次の行動の審査が完了していません。")
    if not isinstance(evidence.get("findingNotes"), str) or len(evidence["findingNotes"].strip()) < 20:
        blockers.append("内容審査の確認メモが不足しています。")
    return blockers


def publication_blockers(draft: dict, row: dict, catalog: dict) -> list[str]:
    blockers = quality_blockers(draft, row.get("review", {}), catalog)
    if draft["question"].get("id") != draft["generatedQuestionId"]:
        blockers.append("問題本体と下書きの問題IDが一致しません。")
    if row.get("generatedQuestionId") != draft["generatedQuestionId"]:
        blockers.append("審査対象の問題IDが一致しません。")
    if row.get("reviewStage") != "human_review" or row.get("reviewerKind") != "manual":
        blockers.append("人による最終確認がありません。")
    result = row.get("review") if isinstance(row.get("review"), dict) else {}
    if result.get("action") != "accept" or result.get("passed") is not True:
        blockers.append("最終判定が採用ではありません。")
    return blockers
