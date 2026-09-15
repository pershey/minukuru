#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any
from urllib import error, parse, request

import jsonschema

from review_workflow import ReviewWorkflowError, compile_review_outputs, read_decision_file

ROOT = Path(__file__).resolve().parents[2]
FACTORY_DIR = ROOT / "content_factory"
SCHEMA_DIR = FACTORY_DIR / "schemas"
PROMPT_DIR = FACTORY_DIR / "prompts"
APP_QUESTIONS_PATH = ROOT / "MinukuruApp" / "Resources" / "questions.json"

DEFAULT_OPENAI_MODEL = os.getenv("MINUKURU_OPENAI_MODEL")
DEFAULT_GEMINI_MODEL = os.getenv("MINUKURU_GEMINI_MODEL")
SIMILARITY_THRESHOLD = 0.86

SAFE_NAME_PATTERN = re.compile(r"[ぁ-んァ-ヶ一-龯A-Za-z0-9]")
PUNCTUATION_PATTERN = re.compile(r"[ 　\t\r\n、。・,.!！?？「」（）()【】『』:：;；\-ー]")
EXCLAMATION_PATTERN = re.compile(r"[!！]{2,}")
REALWORLD_RISK_PATTERN = re.compile(
    r"(LINE|インスタ|Instagram|TikTok|Amazon|楽天|PayPay|YouTube|iPhone|Android|ビットコイン|NISA|FX)",
    re.IGNORECASE,
)


@dataclass
class ExistingQuestion:
    id: str
    title: str
    mode: str
    combined_text: str


class PipelineError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not path.exists():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False))
            handle.write("\n")


def append_jsonl_row(path: Path, row: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(row, ensure_ascii=False))
        handle.write("\n")


def sql_json_literal(payload: Any) -> str:
    text = json.dumps(payload, ensure_ascii=False)
    tag = "minukuru_json"
    while f"${tag}$" in text:
        tag += "_x"
    return f"${tag}${text}${tag}$::jsonb"


def sql_string_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_nullable_text(value: str | None) -> str:
    if value is None or value == "":
        return "null"
    return sql_string_literal(value)


def validate_payload(payload: Any, schema_path: Path) -> None:
    schema = read_json(schema_path)
    jsonschema.validate(payload, schema)


def validate_jsonl(path: Path, schema_path: Path) -> None:
    for index, row in enumerate(read_jsonl(path), start=1):
        try:
            validate_payload(row, schema_path)
        except jsonschema.ValidationError as exc:
            raise PipelineError(f"{path.name} line {index} is invalid: {exc.message}") from exc


def openai_strict_schema(schema: dict[str, Any]) -> dict[str, Any]:
    def convert(node: Any, required: bool = True) -> Any:
        if not isinstance(node, dict):
            return node

        converted = {key: value for key, value in node.items() if key != "$schema"}

        if converted.get("type") == "object" or "properties" in converted:
            original_properties = converted.get("properties", {})
            original_required = set(converted.get("required", []))
            converted_properties = {
                key: convert(value, required=key in original_required) for key, value in original_properties.items()
            }
            converted["type"] = "object"
            converted["properties"] = converted_properties
            converted["required"] = list(converted_properties.keys())
            converted["additionalProperties"] = False
        elif converted.get("type") == "array" and "items" in converted:
            converted["items"] = convert(converted["items"], required=True)
        else:
            for keyword in ("anyOf", "oneOf", "allOf"):
                if keyword in converted:
                    converted[keyword] = [convert(item, required=True) for item in converted[keyword]]

        if required:
            return converted

        return {
            "anyOf": [
                converted,
                {"type": "null"},
            ]
        }

    return convert(schema)


def strip_null_fields(payload: Any) -> Any:
    if isinstance(payload, dict):
        return {
            key: strip_null_fields(value)
            for key, value in payload.items()
            if value is not None
        }
    if isinstance(payload, list):
        return [strip_null_fields(value) for value in payload if value is not None]
    return payload


def normalize_text(text: str) -> str:
    lowered = text.lower()
    lowered = PUNCTUATION_PATTERN.sub("", lowered)
    return lowered


def tokenize(text: str) -> set[str]:
    cleaned = re.sub(r"[^0-9A-Za-zぁ-んァ-ヶ一-龯]+", " ", text)
    tokens = [token for token in cleaned.lower().split() if token]
    if tokens:
        return set(tokens)
    fallback = "".join(ch for ch in cleaned if SAFE_NAME_PATTERN.match(ch))
    if not fallback:
        return set()
    return {fallback[i : i + 2] for i in range(max(1, len(fallback) - 1))}


def combined_similarity(a: str, b: str) -> float:
    norm_a = normalize_text(a)
    norm_b = normalize_text(b)
    if not norm_a or not norm_b:
        return 0.0
    seq_ratio = SequenceMatcher(None, norm_a, norm_b).ratio()
    tokens_a = tokenize(a)
    tokens_b = tokenize(b)
    if tokens_a and tokens_b:
        jaccard = len(tokens_a & tokens_b) / max(1, len(tokens_a | tokens_b))
    else:
        jaccard = 0.0
    return round(max(seq_ratio, jaccard), 4)


def question_to_text(question: dict[str, Any]) -> str:
    segments = " ".join(segment["text"] for segment in question["segments"])
    return f"{question['title']} {segments} {question['explanation']} {question['verificationTip']}"


def manifest_questions(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, dict):
        questions = payload.get("questions", [])
    elif isinstance(payload, list):
        questions = payload
    else:
        raise PipelineError("manifest の JSON は配列または questions を持つ object である必要があります。")

    if not isinstance(questions, list):
        raise PipelineError("manifest の questions は配列である必要があります。")
    return questions


def load_manifest_questions(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise PipelineError(f"manifest が見つかりません: {path}")
    return manifest_questions(read_json(path))


def merge_questions(base_questions: list[dict[str, Any]], overlay_questions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    for question in base_questions:
        merged[question["id"]] = question
    for question in overlay_questions:
        merged[question["id"]] = question
    return list(merged.values())


def file_checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generated_question_id_for_task(task: dict[str, Any]) -> str:
    access_tier = str(task["accessTier"]).strip().lower()
    blueprint_slug = str(task["blueprint"]["slug"]).strip().lower()
    task_suffix = str(task["taskId"]).split("-")[0].lower()
    return f"{access_tier}-{blueprint_slug}-{task_suffix}"


def existing_questions_from_manifest(path: Path) -> list[ExistingQuestion]:
    if not path.exists():
        return []
    questions = manifest_questions(read_json(path))
    rows: list[ExistingQuestion] = []
    for question in questions:
        rows.append(
            ExistingQuestion(
                id=question["id"],
                title=question["title"],
                mode=question["mode"],
                combined_text=question_to_text(question),
            )
        )
    return rows


def top_similar_questions(question: dict[str, Any], existing_questions: list[ExistingQuestion], limit: int = 3) -> list[dict[str, Any]]:
    current_text = question_to_text(question)
    scored = []
    for existing in existing_questions:
        ratio = combined_similarity(current_text, existing.combined_text)
        if ratio <= 0:
            continue
        scored.append(
            {
                "id": existing.id,
                "title": existing.title,
                "mode": existing.mode,
                "similarityRatio": ratio,
            }
        )
    scored.sort(key=lambda row: row["similarityRatio"], reverse=True)
    return scored[:limit]


def hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def build_source_hash(source_example: dict[str, Any]) -> str:
    base = "|".join(
        [
            source_example["sourceChannel"],
            source_example["title"],
            source_example["redactedExcerpt"],
        ]
    )
    return hash_text(base)


def load_prompt(name: str) -> str:
    return (PROMPT_DIR / name).read_text(encoding="utf-8").strip()


def resolve_model(provider: str, explicit_model: str | None) -> str:
    if explicit_model:
        return explicit_model
    if provider == "openai" and DEFAULT_OPENAI_MODEL:
        return DEFAULT_OPENAI_MODEL
    if provider == "gemini" and DEFAULT_GEMINI_MODEL:
        return DEFAULT_GEMINI_MODEL
    raise PipelineError(
        f"{provider} 用の model が未指定です。--model か環境変数を設定してください。"
    )


def prompt_list(items: list[str]) -> str:
    return "\n".join(f"- {item}" for item in items) if items else "- なし"


def audience_tone_rules(audience_tone: str) -> str:
    if audience_tone == "childFriendly":
        return """- 子ども向けに、むずかしい漢字や言い回しを減らす
- phoneticTitle, phoneticInstruction, phoneticHint, phoneticExplanation, phoneticVerificationTip をできるだけ入れる
- segments の各 phoneticText もできるだけ入れる
- 解説は「こわい」より「たしかめてみよう」に寄せる"""
    if audience_tone == "seniorFriendly":
        return """- 高齢者にも読みやすいように、1文を短めにする
- 強いカタカナ語や業界用語を避ける
- phoneticTitle と phoneticText を優先して入れる
- verificationTip は手順を 1 から 2 個に絞って具体的に書く"""
    return """- 一般向けに、自然で落ち着いた言い回しにする
- phonetic 系の項目は、読みやすさが上がるときだけ入れる"""


def build_generation_user_prompt(
    source_example: dict[str, Any],
    blueprint: dict[str, Any],
    batch_label: str,
    existing_titles: list[str],
) -> str:
    return f"""以下の素材と制作方針から、ミヌクルの premium 問題を 1 問だけ作成してください。

## バッチ情報
- batchLabel: {batch_label}

## 素材
- sourceKind: {source_example["sourceKind"]}
- sourceChannel: {source_example["sourceChannel"]}
- title: {source_example["title"]}
- redactedExcerpt:
{source_example["redactedExcerpt"]}

## 素材メモ
{source_example.get("referenceNotes", "なし")}

## 使いたい信号
{prompt_list(source_example.get("signalTags", []))}

## blueprint
- slug: {blueprint["slug"]}
- name: {blueprint["name"]}
- mode: {blueprint["mode"]}
- accessTier: {blueprint["accessTier"]}
- contentFlavor: {blueprint["contentFlavor"]}
- targetDifficulty: {blueprint["targetDifficulty"]}
- audienceTone: {blueprint["audienceTone"]}

## 使いたいフック
{prompt_list(blueprint.get("hookTypes", []))}

## 推奨理由タグ
{prompt_list(blueprint.get("redFlagTags", []))}

## generatorNotes
{blueprint["generatorNotes"]}

## realismConstraints
{json.dumps(blueprint.get("realismConstraints", {}), ensure_ascii=False)}

## audienceTone の補足
{audience_tone_rules(blueprint["audienceTone"])}

## 既存タイトル例
{prompt_list(existing_titles[:8])}

## 追加ルール
- 問題は premium 向けなので、無料問題より一段だけリアルにする
- 実在の人名、企業名、政党名、宗教名、商品名、投資商品名は避ける
- 実在の詐欺広告をそのままコピーしない
- セグメントは短く、タップしやすい文の長さにする
- correctSegmentIds は 1 から 3 個
- explanation は説教にしない
- verificationTip は「何で確かめるか」を具体的に書く
- recommendedReasonTags は本文の怪しさと一致させる
- accessTier は {blueprint["accessTier"]}、contentFlavor は {blueprint["contentFlavor"]} に固定する
- mode は {blueprint["mode"]} に固定する
- difficulty は {blueprint["targetDifficulty"]} を基本線にする
"""


def post_json(url: str, headers: dict[str, str], payload: dict[str, Any]) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    req = request.Request(url, data=data, headers=headers, method="POST")
    try:
        with request.urlopen(req, timeout=120) as response:
            body = response.read().decode("utf-8")
    except error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise PipelineError(f"HTTP {exc.code} for {url}: {detail}") from exc
    except error.URLError as exc:
        raise PipelineError(f"Network error for {url}: {exc}") from exc
    try:
        return json.loads(body)
    except json.JSONDecodeError as exc:
        raise PipelineError(f"Failed to parse JSON response from {url}: {body[:500]}") from exc


def call_openai_json(
    model: str,
    system_prompt: str,
    user_prompt: str,
    schema_name: str,
    schema: dict[str, Any],
    temperature: float | None,
) -> dict[str, Any]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise PipelineError("OPENAI_API_KEY が設定されていません。")

    strict_schema = openai_strict_schema(schema)
    payload: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": schema_name,
                "schema": strict_schema,
                "strict": True,
            },
        },
    }
    if temperature is not None:
        payload["temperature"] = temperature

    response = post_json(
        "https://api.openai.com/v1/chat/completions",
        {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        payload,
    )

    try:
        content = response["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as exc:
        raise PipelineError(f"OpenAI response shape was unexpected: {response}") from exc
    if not isinstance(content, str):
        raise PipelineError(f"OpenAI structured output was not a string JSON payload: {content}")
    return strip_null_fields(json.loads(content))


def call_gemini_json(
    model: str,
    system_prompt: str,
    user_prompt: str,
    schema: dict[str, Any],
    temperature: float | None,
) -> dict[str, Any]:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise PipelineError("GEMINI_API_KEY が設定されていません。")

    generation_config: dict[str, Any] = {
        "responseMimeType": "application/json",
        "responseJsonSchema": schema,
    }
    if temperature is not None:
        generation_config["temperature"] = temperature

    payload = {
        "systemInstruction": {
            "parts": [{"text": system_prompt}]
        },
        "contents": [
            {
                "role": "user",
                "parts": [{"text": user_prompt}],
            }
        ],
        "generationConfig": generation_config,
    }
    response = post_json(
        f"https://generativelanguage.googleapis.com/v1beta/models/{parse.quote(model)}:generateContent",
        {
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        payload,
    )

    try:
        content = response["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as exc:
        raise PipelineError(f"Gemini response shape was unexpected: {response}") from exc
    if not isinstance(content, str):
        raise PipelineError(f"Gemini structured output was not a string JSON payload: {content}")
    return strip_null_fields(json.loads(content))


def ensure_question_invariants(question: dict[str, Any]) -> None:
    segment_ids = [segment["id"] for segment in question["segments"]]
    if len(segment_ids) != len(set(segment_ids)):
        raise PipelineError("segments の id が重複しています。")
    unknown_ids = [segment_id for segment_id in question["correctSegmentIds"] if segment_id not in segment_ids]
    if unknown_ids:
        raise PipelineError(f"correctSegmentIds に存在しない segment id があります: {unknown_ids}")


def local_review(question: dict[str, Any], existing_questions: list[ExistingQuestion]) -> dict[str, Any]:
    concerns: list[str] = []
    revision_advice: list[str] = []
    duplicate_signals: list[str] = []
    matched_signals: list[str] = []

    segments = question["segments"]
    segment_lengths = [len(segment["text"]) for segment in segments]
    explanation = question["explanation"]
    verification_tip = question["verificationTip"]
    hint = question["hint"]

    realism_score = 76
    safety_score = 92
    learning_score = 78
    uniqueness_score = 85
    segment_clarity_score = 82

    if len(segments) < 3 or len(segments) > 6:
        segment_clarity_score -= 25
        concerns.append("セグメント数が多すぎるか少なすぎます。")
        revision_advice.append("3 から 6 セグメントに収めてください。")

    if any(length > 110 for length in segment_lengths):
        segment_clarity_score -= 12
        concerns.append("セグメントが長く、タップ学習に向きにくいです。")
        revision_advice.append("1 セグメントを 1 文に近い長さへ縮めてください。")

    if EXCLAMATION_PATTERN.search(question_to_text(question)):
        realism_score -= 8
        concerns.append("強調記号が多く、作り物っぽく見えます。")
        revision_advice.append("感嘆符や過剰な強調を減らしてください。")

    if len(question["correctSegmentIds"]) > 3:
        segment_clarity_score -= 20
        learning_score -= 10
        concerns.append("正解箇所が多すぎて学習ポイントがぼけています。")
        revision_advice.append("本当に怪しい箇所は 1 から 3 個に絞ってください。")

    if len(explanation) < 30:
        learning_score -= 12
        concerns.append("解説が短く、なぜ怪しいかが十分に伝わりません。")
        revision_advice.append("解説に『なぜ怪しいか』を一文足してください。")

    if len(verification_tip) < 24 or not re.search(r"(公式|出典|案内|説明|比べ|確認|調べ)", verification_tip):
        learning_score -= 10
        concerns.append("確認方法がやや抽象的です。")
        revision_advice.append("何を見れば確認できるかを具体的に書いてください。")

    if len(hint) < 8:
        learning_score -= 4
        revision_advice.append("ヒントは一段だけ具体的にすると遊びやすくなります。")

    if REALWORLD_RISK_PATTERN.search(question_to_text(question)):
        safety_score -= 24
        concerns.append("実在サービスや投資っぽい単語に寄りすぎています。")
        revision_advice.append("実在名や投資・商品名を避け、構造だけを残してください。")

    if question["contentFlavor"] == "realWorld":
        matched_signals.append("realWorld")
        if question["mode"] in {"scamAdChecker", "profileHunter"}:
            realism_score += 4
        else:
            realism_score -= 2
            revision_advice.append("現実モードらしい媒体感が出るよう、語り口を寄せてください。")

    top_matches = top_similar_questions(question, existing_questions, limit=3)
    highest_similarity = top_matches[0]["similarityRatio"] if top_matches else 0.0
    if highest_similarity >= 0.92:
        uniqueness_score = min(uniqueness_score, 45)
        realism_score -= 5
        duplicate_signals.append(f"既存問題とかなり近いです ({highest_similarity:.2f})")
        concerns.append("既存問題と近すぎて premium の新鮮さが弱いです。")
        revision_advice.append("町名、構図、怪しい論点の組み合わせを変えてください。")
    elif highest_similarity >= 0.82:
        uniqueness_score = min(uniqueness_score, 64)
        duplicate_signals.append(f"既存問題とやや近いです ({highest_similarity:.2f})")
        revision_advice.append("タイトルか導入の型を少し変えると差別化できます。")

    if question["recommendedReasonTags"]:
        matched_signals.extend(question["recommendedReasonTags"][:3])

    realism_score = max(0, min(100, realism_score))
    safety_score = max(0, min(100, safety_score))
    learning_score = max(0, min(100, learning_score))
    uniqueness_score = max(0, min(100, uniqueness_score))
    segment_clarity_score = max(0, min(100, segment_clarity_score))

    composite_score = round(
        realism_score * 0.28
        + safety_score * 0.32
        + learning_score * 0.22
        + uniqueness_score * 0.10
        + segment_clarity_score * 0.08
    )

    if safety_score < 65:
        action = "reject"
        passed = False
    elif highest_similarity >= 0.92:
        action = "revise"
        passed = False
    elif question["contentFlavor"] == "realWorld" and safety_score < 90:
        action = "needs_human"
        passed = False
    elif composite_score >= 78 and safety_score >= 86 and learning_score >= 70 and uniqueness_score >= 65:
        action = "accept"
        passed = True
    else:
        action = "revise"
        passed = False

    summary = (
        f"realism={realism_score}, safety={safety_score}, learning={learning_score}, "
        f"uniqueness={uniqueness_score}, segmentClarity={segment_clarity_score}, "
        f"similarity={highest_similarity:.2f}"
    )

    return {
        "passed": passed,
        "action": action,
        "realismScore": realism_score,
        "safetyScore": safety_score,
        "learningScore": learning_score,
        "uniquenessScore": uniqueness_score,
        "segmentClarityScore": segment_clarity_score,
        "compositeScore": composite_score,
        "matchedSignals": sorted(set(matched_signals)),
        "concerns": concerns,
        "duplicateSignals": duplicate_signals,
        "revisionAdvice": revision_advice,
        "summary": summary,
        "_localHighestSimilarity": highest_similarity,
        "_topSimilarQuestions": top_matches,
    }


def build_review_user_prompt(
    question: dict[str, Any],
    local_review_result: dict[str, Any],
    top_matches: list[dict[str, Any]],
) -> str:
    ai_safe_local = {
        key: value
        for key, value in local_review_result.items()
        if not key.startswith("_")
    }
    return f"""以下の draft 問題を、ミヌクルの premium 問題としてレビューしてください。

## 問題 JSON
{json.dumps(question, ensure_ascii=False, indent=2)}

## ローカル重複チェック
{json.dumps(top_matches, ensure_ascii=False, indent=2)}

## ローカル一次評価
{json.dumps(ai_safe_local, ensure_ascii=False, indent=2)}

## 判定の前提
- より安全な方を優先する
- 「人をだます精度」ではなく「見抜き学習としての価値」を見る
- duplicateSignals には、似ている点を短く書く
- revisionAdvice には、直す方向を具体的に書く
"""


def merge_ai_review(ai_review: dict[str, Any], local_review_result: dict[str, Any]) -> dict[str, Any]:
    highest_similarity = local_review_result["_localHighestSimilarity"]
    top_matches = local_review_result["_topSimilarQuestions"]

    merged = dict(ai_review)
    merged["duplicateSignals"] = sorted(
        set(ai_review.get("duplicateSignals", [])) | set(local_review_result.get("duplicateSignals", []))
    )
    merged["concerns"] = sorted(
        set(ai_review.get("concerns", [])) | set(local_review_result.get("concerns", []))
    )
    merged["revisionAdvice"] = sorted(
        set(ai_review.get("revisionAdvice", [])) | set(local_review_result.get("revisionAdvice", []))
    )
    merged["matchedSignals"] = sorted(
        set(ai_review.get("matchedSignals", [])) | set(local_review_result.get("matchedSignals", []))
    )

    uniqueness_score = min(int(merged["uniquenessScore"]), int(local_review_result["uniquenessScore"]))
    safety_score = min(int(merged["safetyScore"]), int(local_review_result["safetyScore"]))
    segment_clarity_score = min(int(merged["segmentClarityScore"]), int(local_review_result["segmentClarityScore"]))
    learning_score = min(int(merged["learningScore"]), int(local_review_result["learningScore"]))
    realism_score = min(int(merged["realismScore"]), int(local_review_result["realismScore"]) + 8)

    composite_score = round(
        realism_score * 0.28
        + safety_score * 0.32
        + learning_score * 0.22
        + uniqueness_score * 0.10
        + segment_clarity_score * 0.08
    )

    action = merged["action"]
    passed = bool(merged["passed"])
    if highest_similarity >= 0.92:
        action = "revise"
        passed = False
    if safety_score < 65:
        action = "reject"
        passed = False
    if composite_score < 78:
        passed = False
        if action == "accept":
            action = "revise"

    merged.update(
        {
            "passed": passed,
            "action": action,
            "realismScore": realism_score,
            "safetyScore": safety_score,
            "learningScore": learning_score,
            "uniquenessScore": uniqueness_score,
            "segmentClarityScore": segment_clarity_score,
            "compositeScore": composite_score,
            "_localHighestSimilarity": highest_similarity,
            "_topSimilarQuestions": top_matches,
        }
    )
    return merged


def build_generation_batch(args: argparse.Namespace) -> None:
    sources = read_jsonl(Path(args.sources))
    blueprints = read_json(Path(args.blueprints))
    existing_questions = existing_questions_from_manifest(Path(args.existing_manifest))
    validate_jsonl(Path(args.sources), SCHEMA_DIR / "source_example.schema.json")
    jsonschema.validate(blueprints, {"type": "array"})
    for blueprint in blueprints:
        validate_payload(blueprint, SCHEMA_DIR / "pattern_blueprint.schema.json")

    rng = random.Random(args.seed)
    batch_label = args.batch_label or f"batch-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    tasks: list[dict[str, Any]] = []

    for blueprint in blueprints:
        matching_sources = [
            source
            for source in sources
            if blueprint["mode"] in source["modeCandidates"]
            and source["sourceChannel"] in blueprint["sourceChannels"]
            and (blueprint["contentFlavor"] != "realWorld" or source["allowRealWorldFlavor"])
        ]
        if not matching_sources:
            continue
        rng.shuffle(matching_sources)
        existing_titles = [row.title for row in existing_questions if row.mode == blueprint["mode"]]
        for source_example in matching_sources[: args.per_blueprint]:
            user_prompt = build_generation_user_prompt(source_example, blueprint, batch_label, existing_titles)
            task = {
                "taskId": str(uuid.uuid4()),
                "batchLabel": batch_label,
                "sourceExample": source_example,
                "blueprint": blueprint,
                "mode": blueprint["mode"],
                "accessTier": blueprint["accessTier"],
                "contentFlavor": blueprint["contentFlavor"],
                "targetDifficulty": blueprint["targetDifficulty"],
                "userPrompt": user_prompt,
            }
            validate_payload(task, SCHEMA_DIR / "generation_task.schema.json")
            tasks.append(task)

    write_jsonl(Path(args.out), tasks)
    print(f"Wrote {len(tasks)} generation tasks to {args.out}")


def run_supabase_sql(sql: str, output: str = "json") -> dict[str, Any] | str:
    command = [
        "supabase",
        "db",
        "query",
        "--linked",
        "-o",
        output,
        sql,
    ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        env={**os.environ, "SUPABASE_TELEMETRY_DISABLED": "1"},
        check=False,
    )
    if result.returncode != 0:
        raise PipelineError(result.stderr.strip() or result.stdout.strip() or "supabase db query failed")
    stdout = result.stdout.strip()
    if output == "json":
        try:
            return json.loads(stdout)
        except json.JSONDecodeError as exc:
            raise PipelineError(f"supabase db query の JSON 解析に失敗しました: {stdout[:500]}") from exc
    return stdout


def source_examples_sql_rows(path: Path) -> list[dict[str, Any]]:
    rows = read_jsonl(path)
    prepared = []
    for row in rows:
        validate_payload(row, SCHEMA_DIR / "source_example.schema.json")
        prepared.append(
            {
                "externalKey": row["id"],
                "sourceKind": row["sourceKind"],
                "sourceChannel": row["sourceChannel"],
                "title": row["title"],
                "rawExcerpt": row["rawExcerpt"],
                "redactedExcerpt": row["redactedExcerpt"],
                "referenceNotes": row.get("referenceNotes"),
                "modeCandidates": row["modeCandidates"],
                "signalTags": row["signalTags"],
                "realismScore": row.get("realismScore", 75),
                "sensitivityFlags": row.get("sensitivityFlags", []),
                "realismNotes": row.get("realismNotes", ""),
                "allowRealWorldFlavor": row["allowRealWorldFlavor"],
                "sourceHash": row.get("sourceHash") or build_source_hash(row),
                "collectedAt": row.get("collectedAt"),
            }
        )
    return prepared


def pattern_blueprints_sql_rows(path: Path) -> list[dict[str, Any]]:
    rows = read_json(path)
    prepared = []
    for row in rows:
        validate_payload(row, SCHEMA_DIR / "pattern_blueprint.schema.json")
        prepared.append(
            {
                "externalKey": row["id"],
                "slug": row["slug"],
                "name": row["name"],
                "mode": row["mode"],
                "accessTier": row["accessTier"],
                "contentFlavor": row["contentFlavor"],
                "sourceChannels": row["sourceChannels"],
                "hookTypes": row["hookTypes"],
                "redFlagTags": row["redFlagTags"],
                "targetDifficulty": row["targetDifficulty"],
                "audienceTone": row["audienceTone"],
                "generatorNotes": row["generatorNotes"],
                "realismConstraints": row.get("realismConstraints", {}),
            }
        )
    return prepared


def build_sync_sources_sql(source_rows: list[dict[str, Any]]) -> str:
    return f"""
with source_payload as (
  select jsonb_array_elements({sql_json_literal(source_rows)}) as row
), upsert_sources as (
  insert into admin.source_examples (
    external_key,
    source_kind,
    source_channel,
    title,
    raw_excerpt,
    redacted_excerpt,
    reference_notes,
    mode_candidates,
    signal_tags,
    safety_status,
    ingestion_status,
    realism_score,
    sensitivity_flags,
    extracted_signals,
    allow_real_world_flavor,
    source_hash,
    collected_at
  )
  select
    row->>'externalKey',
    row->>'sourceKind',
    row->>'sourceChannel',
    row->>'title',
    row->>'rawExcerpt',
    row->>'redactedExcerpt',
    nullif(row->>'referenceNotes', ''),
    coalesce(array(select jsonb_array_elements_text(row->'modeCandidates')), '{{}}'::text[]),
    coalesce(array(select jsonb_array_elements_text(row->'signalTags')), '{{}}'::text[]),
    'approved',
    'normalized',
    coalesce((row->>'realismScore')::int, 75),
    coalesce(row->'sensitivityFlags', '[]'::jsonb),
    jsonb_build_object(
      'realismNotes', coalesce(row->>'realismNotes', ''),
      'signalTags', coalesce(row->'signalTags', '[]'::jsonb)
    ),
    coalesce((row->>'allowRealWorldFlavor')::boolean, false),
    row->>'sourceHash',
    nullif(row->>'collectedAt', '')::timestamptz
  from source_payload
  on conflict (external_key) do update
  set source_kind = excluded.source_kind,
      source_channel = excluded.source_channel,
      title = excluded.title,
      raw_excerpt = excluded.raw_excerpt,
      redacted_excerpt = excluded.redacted_excerpt,
      reference_notes = excluded.reference_notes,
      mode_candidates = excluded.mode_candidates,
      signal_tags = excluded.signal_tags,
      safety_status = excluded.safety_status,
      ingestion_status = excluded.ingestion_status,
      realism_score = excluded.realism_score,
      sensitivity_flags = excluded.sensitivity_flags,
      extracted_signals = excluded.extracted_signals,
      allow_real_world_flavor = excluded.allow_real_world_flavor,
      source_hash = excluded.source_hash,
      collected_at = excluded.collected_at
  returning 1
)
select count(*) as synced_sources from upsert_sources;
"""


def build_reconcile_blueprints_sql(blueprint_rows: list[dict[str, Any]]) -> str:
    return f"""
with blueprint_payload as (
  select jsonb_array_elements({sql_json_literal(blueprint_rows)}) as row
), blueprint_matches as (
  select
    row,
    ext.id as external_row_id,
    slugged.id as slug_row_id
  from blueprint_payload
  left join admin.pattern_blueprints ext
    on ext.external_key = row->>'externalKey'
  left join admin.pattern_blueprints slugged
    on slugged.slug = row->>'slug'
), reassigned_blueprint_refs as (
  update admin.question_drafts d
  set blueprint_id = match.slug_row_id
  from blueprint_matches match
  where match.external_row_id is not null
    and match.slug_row_id is not null
    and match.external_row_id <> match.slug_row_id
    and d.blueprint_id = match.external_row_id
  returning 1
), deleted_conflicting_blueprints as (
  delete from admin.pattern_blueprints pb
  using blueprint_matches match
  where match.external_row_id is not null
    and match.slug_row_id is not null
    and match.external_row_id <> match.slug_row_id
    and pb.id = match.external_row_id
  returning 1
), attached_blueprints as (
  update admin.pattern_blueprints existing
  set external_key = payload.row->>'externalKey'
  from blueprint_payload payload
  where existing.slug = payload.row->>'slug'
    and (
      existing.external_key is null
      or existing.external_key = payload.row->>'externalKey'
    )
  returning 1
)
select
  (select count(*) from reassigned_blueprint_refs) as reassigned_blueprint_refs,
  (select count(*) from deleted_conflicting_blueprints) as deleted_conflicting_blueprints,
  (select count(*) from attached_blueprints) as attached_blueprints;
"""


def build_upsert_blueprints_sql(blueprint_rows: list[dict[str, Any]]) -> str:
    return f"""
with blueprint_payload as (
  select jsonb_array_elements({sql_json_literal(blueprint_rows)}) as row
), upsert_blueprints as (
  insert into admin.pattern_blueprints (
    external_key,
    slug,
    name,
    mode,
    access_tier,
    content_flavor,
    source_channels,
    hook_types,
    red_flag_tags,
    target_difficulty,
    audience_tone,
    generator_notes,
    realism_constraints,
    active
  )
  select
    row->>'externalKey',
    row->>'slug',
    row->>'name',
    row->>'mode',
    row->>'accessTier',
    row->>'contentFlavor',
    coalesce(array(select jsonb_array_elements_text(row->'sourceChannels')), '{{}}'::text[]),
    coalesce(array(select jsonb_array_elements_text(row->'hookTypes')), '{{}}'::text[]),
    coalesce(array(select jsonb_array_elements_text(row->'redFlagTags')), '{{}}'::text[]),
    row->>'targetDifficulty',
    row->>'audienceTone',
    row->>'generatorNotes',
    coalesce(row->'realismConstraints', '{{}}'::jsonb),
    true
  from blueprint_payload
  on conflict (external_key) do update
  set slug = excluded.slug,
      name = excluded.name,
      mode = excluded.mode,
      access_tier = excluded.access_tier,
      content_flavor = excluded.content_flavor,
      source_channels = excluded.source_channels,
      hook_types = excluded.hook_types,
      red_flag_tags = excluded.red_flag_tags,
      target_difficulty = excluded.target_difficulty,
      audience_tone = excluded.audience_tone,
      generator_notes = excluded.generator_notes,
      realism_constraints = excluded.realism_constraints,
      active = excluded.active
  returning 1
)
select count(*) as synced_blueprints from upsert_blueprints;
"""


def sync_reference_data(args: argparse.Namespace) -> None:
    source_rows = source_examples_sql_rows(Path(args.sources))
    blueprint_rows = pattern_blueprints_sql_rows(Path(args.blueprints))
    sources_result = run_supabase_sql(build_sync_sources_sql(source_rows), output="json")
    reconcile_result = run_supabase_sql(build_reconcile_blueprints_sql(blueprint_rows), output="json")
    blueprints_result = run_supabase_sql(build_upsert_blueprints_sql(blueprint_rows), output="json")
    combined = {
        "rows": [
            {
                "synced_sources": sources_result.get("rows", [{}])[0].get("synced_sources", 0),
                "reassigned_blueprint_refs": reconcile_result.get("rows", [{}])[0].get("reassigned_blueprint_refs", 0),
                "deleted_conflicting_blueprints": reconcile_result.get("rows", [{}])[0].get("deleted_conflicting_blueprints", 0),
                "attached_blueprints": reconcile_result.get("rows", [{}])[0].get("attached_blueprints", 0),
                "synced_blueprints": blueprints_result.get("rows", [{}])[0].get("synced_blueprints", 0),
            }
        ]
    }
    print(json.dumps(combined, ensure_ascii=False, indent=2))


def drafts_sql_rows(path: Path) -> list[dict[str, Any]]:
    rows = read_jsonl(path)
    prepared = []
    for row in rows:
        validate_payload(row["question"], SCHEMA_DIR / "quiz_question.schema.json")
        ensure_question_invariants(row["question"])
        prepared.append(
            {
                "externalKey": row["draftId"],
                "taskExternalKey": row.get("taskId"),
                "draftBatchLabel": row["batchLabel"],
                "sourceExampleExternalKey": row.get("sourceExampleId"),
                "blueprintExternalKey": row.get("blueprintExternalKey"),
                "blueprintSlug": row.get("blueprintSlug"),
                "provider": row.get("provider"),
                "modelName": row.get("model"),
                "mode": row["mode"],
                "accessTier": row["accessTier"],
                "contentFlavor": row["contentFlavor"],
                "lifecycleStatus": row.get("lifecycleStatus", "generated"),
                "generatedQuestionId": row["generatedQuestionId"],
                "normalizedTextHash": hash_text(question_to_text(row["question"])),
                "sourceSnapshot": row.get("sourceSnapshot", {}),
                "generationContext": row.get("generationContext", {}),
                "questionPayload": row["question"],
            }
        )
    return prepared


def build_import_drafts_sql(draft_rows: list[dict[str, Any]]) -> str:
    return f"""
with payload as (
  select jsonb_array_elements({sql_json_literal(draft_rows)}) as row
), upserted as (
  insert into admin.question_drafts (
    external_key,
    task_external_key,
    draft_batch_label,
    source_example_id,
    blueprint_id,
    provider,
    model_name,
    mode,
    access_tier,
    content_flavor,
    lifecycle_status,
    generated_question_id,
    normalized_text_hash,
    source_snapshot,
    generation_context,
    question_payload
  )
  select
    row->>'externalKey',
    nullif(row->>'taskExternalKey', ''),
    row->>'draftBatchLabel',
    (select id from admin.source_examples where external_key = row->>'sourceExampleExternalKey'),
    coalesce(
      (select id from admin.pattern_blueprints where external_key = nullif(row->>'blueprintExternalKey', '')),
      (select id from admin.pattern_blueprints where slug = row->>'blueprintSlug')
    ),
    nullif(row->>'provider', ''),
    nullif(row->>'modelName', ''),
    row->>'mode',
    row->>'accessTier',
    row->>'contentFlavor',
    coalesce(nullif(row->>'lifecycleStatus', ''), 'generated'),
    row->>'generatedQuestionId',
    row->>'normalizedTextHash',
    coalesce(row->'sourceSnapshot', '{{}}'::jsonb),
    coalesce(row->'generationContext', '{{}}'::jsonb),
    row->'questionPayload'
  from payload
  on conflict (external_key) do update
  set task_external_key = excluded.task_external_key,
      draft_batch_label = excluded.draft_batch_label,
      source_example_id = excluded.source_example_id,
      blueprint_id = excluded.blueprint_id,
      provider = excluded.provider,
      model_name = excluded.model_name,
      mode = excluded.mode,
      access_tier = excluded.access_tier,
      content_flavor = excluded.content_flavor,
      lifecycle_status = excluded.lifecycle_status,
      generated_question_id = excluded.generated_question_id,
      normalized_text_hash = excluded.normalized_text_hash,
      source_snapshot = excluded.source_snapshot,
      generation_context = excluded.generation_context,
      question_payload = excluded.question_payload
  returning 1
)
select count(*) as synced_drafts from upserted;
"""


def import_drafts(args: argparse.Namespace) -> None:
    rows = drafts_sql_rows(Path(args.drafts))
    sql = build_import_drafts_sql(rows)
    result = run_supabase_sql(sql, output="json")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def reviews_sql_rows(path: Path) -> list[dict[str, Any]]:
    rows = read_jsonl(path)
    prepared = []
    for row in rows:
        validate_payload(row["review"], SCHEMA_DIR / "review_result.schema.json")
        prepared.append(
            {
                "reviewExternalKey": row.get("reviewId"),
                "draftExternalKey": row["draftId"],
                "generatedQuestionId": row.get("generatedQuestionId"),
                "reviewStage": row["reviewStage"],
                "reviewerKind": row["reviewerKind"],
                "reviewerModel": row.get("reviewerModel"),
                "similarityRatio": row.get("similarityRatio"),
                "reviewPayload": row["review"],
                "notes": row["review"].get("summary"),
                "createdAt": row.get("createdAt"),
            }
        )
    return prepared


def build_insert_reviews_sql(review_rows: list[dict[str, Any]]) -> str:
    return f"""
with payload as (
  select jsonb_array_elements({sql_json_literal(review_rows)}) as row
), inserted as (
  insert into admin.review_runs (
    external_key,
    draft_id,
    review_stage,
    reviewer_kind,
    reviewer_model,
    passed,
    action,
    realism_score,
    safety_score,
    learning_score,
    uniqueness_score,
    segment_clarity_score,
    similarity_ratio,
    review_payload,
    notes,
    created_at
  )
  select
    nullif(row->>'reviewExternalKey', ''),
    d.id,
    row->>'reviewStage',
    row->>'reviewerKind',
    nullif(row->>'reviewerModel', ''),
    coalesce((row->'reviewPayload'->>'passed')::boolean, false),
    row->'reviewPayload'->>'action',
    (row->'reviewPayload'->>'realismScore')::int,
    (row->'reviewPayload'->>'safetyScore')::int,
    (row->'reviewPayload'->>'learningScore')::int,
    (row->'reviewPayload'->>'uniquenessScore')::int,
    (row->'reviewPayload'->>'segmentClarityScore')::int,
    nullif(row->>'similarityRatio', '')::numeric,
    row->'reviewPayload',
    nullif(row->>'notes', ''),
    coalesce(nullif(row->>'createdAt', '')::timestamptz, now())
  from payload
  join admin.question_drafts d
    on d.external_key = row->>'draftExternalKey'
  on conflict (external_key) where external_key is not null do nothing
  returning draft_id
)
select count(*) as imported_reviews from inserted;
"""


def build_refresh_drafts_from_reviews_sql(review_rows: list[dict[str, Any]]) -> str:
    return f"""
with payload as (
  select jsonb_array_elements({sql_json_literal(review_rows)}) as row
), affected_drafts as (
  select distinct d.id
  from payload
  join admin.question_drafts d
    on d.external_key = row->>'draftExternalKey'
), latest_reviews as (
  select distinct on (rr.draft_id)
    rr.draft_id,
    rr.passed,
    rr.action,
    rr.realism_score,
    rr.safety_score,
    rr.learning_score,
    rr.uniqueness_score,
    rr.review_stage,
    rr.review_payload
  from admin.review_runs rr
  join affected_drafts ad
    on ad.id = rr.draft_id
  order by rr.draft_id, rr.created_at desc
), updated as (
  update admin.question_drafts d
  set lifecycle_status = case
        when latest.action = 'reject' then 'rejected'
        when latest.action = 'accept' and latest.review_stage = 'human_review' then 'approved'
        when latest.action = 'accept' then 'ai_reviewed'
        when latest.action = 'needs_human' then 'human_reviewed'
        else 'generated'
      end,
      realism_score = latest.realism_score,
      safety_score = latest.safety_score,
      learning_score = latest.learning_score,
      uniqueness_score = latest.uniqueness_score,
      composite_score = (
        latest.realism_score * 0.28 +
        latest.safety_score * 0.32 +
        latest.learning_score * 0.22 +
        latest.uniqueness_score * 0.10 +
        coalesce((latest.review_payload->>'segmentClarityScore')::int, 80) * 0.08
      )::numeric(5,2)
  from latest_reviews latest
  where d.id = latest.draft_id
  returning d.id
)
select count(*) as updated_drafts from updated;
"""


def import_reviews(args: argparse.Namespace) -> None:
    rows = reviews_sql_rows(Path(args.reviews))
    inserted_result = run_supabase_sql(build_insert_reviews_sql(rows), output="json")
    updated_result = run_supabase_sql(build_refresh_drafts_from_reviews_sql(rows), output="json")
    combined = {
        "rows": [
            {
                "imported_reviews": inserted_result.get("rows", [{}])[0].get("imported_reviews", 0),
                "updated_drafts": updated_result.get("rows", [{}])[0].get("updated_drafts", 0),
            }
        ]
    }
    print(json.dumps(combined, ensure_ascii=False, indent=2))


def export_ready_manifest(args: argparse.Namespace) -> None:
    content_flavor_filter = (
        ""
        if args.content_flavor == "all"
        else f"\n  and content_flavor = '{args.content_flavor}'"
    )
    sql = f"""
select
  draft_id,
  generated_question_id,
  mode,
  access_tier,
  content_flavor,
  question_payload,
  realism_score,
  safety_score,
  learning_score,
  uniqueness_score,
  composite_score,
  similarity_ratio,
  latest_action,
  latest_passed,
  reviewed_at
from admin.ready_publish_candidates
where latest_action = 'accept'
  and latest_passed = true
  and coalesce(composite_score, 0) >= {int(args.min_composite)}
  and coalesce(safety_score, 0) >= {int(args.min_safety)}
  and coalesce(realism_score, 0) >= {int(args.min_realism)}
  and coalesce(learning_score, 0) >= {int(args.min_learning)}
  and coalesce(similarity_ratio, 0) <= {float(args.max_similarity)}
  and access_tier = '{args.access_tier}'
{content_flavor_filter}
order by reviewed_at desc nulls last
limit {int(args.limit)};
"""
    result = run_supabase_sql(sql, output="json")
    rows = result.get("rows", [])
    now = utc_now()
    questions = []
    report_rows = []
    for row in rows:
        question = row["question_payload"]
        question["reviewStatus"] = "approved"
        question["authorName"] = "content-factory"
        question["authorId"] = "supabase-ready-candidate"
        question["educationalScore"] = int(row["learning_score"])
        question["safetyLevel"] = max(1, min(5, 5 - int(row["safety_score"] / 20)))
        question["reportCount"] = 0
        question["createdAt"] = now
        question["updatedAt"] = now
        questions.append(question)
        report_rows.append(
            {
                "draftId": row["draft_id"],
                "questionId": row["generated_question_id"],
                "mode": row["mode"],
                "contentFlavor": row["content_flavor"],
                "compositeScore": row["composite_score"],
                "safetyScore": row["safety_score"],
                "realismScore": row["realism_score"],
                "learningScore": row["learning_score"],
                "uniquenessScore": row["uniqueness_score"],
                "similarityRatio": row["similarity_ratio"],
                "reviewedAt": row["reviewed_at"],
            }
        )

    if args.base_manifest:
        base_questions = load_manifest_questions(Path(args.base_manifest))
        questions = merge_questions(base_questions, questions)

    manifest = {
        "schemaVersion": 1,
        "contentVersion": args.content_version,
        "updatedAt": now,
        "questions": questions,
    }
    write_json(Path(args.out), manifest)
    if args.report:
        write_json(Path(args.report), report_rows)
    print(f"Wrote {len(questions)} ready questions to {args.out}")


def validate_fixtures(args: argparse.Namespace) -> None:
    validate_jsonl(Path(args.sources), SCHEMA_DIR / "source_example.schema.json")
    blueprints = read_json(Path(args.blueprints))
    jsonschema.validate(blueprints, {"type": "array"})
    for blueprint in blueprints:
        validate_payload(blueprint, SCHEMA_DIR / "pattern_blueprint.schema.json")

    for draft in read_jsonl(Path(args.drafts)):
        validate_payload(draft["question"], SCHEMA_DIR / "quiz_question.schema.json")
        ensure_question_invariants(draft["question"])

    print("Validated source examples, blueprints, and sample drafts.")


def run_generation(args: argparse.Namespace) -> None:
    tasks_path = Path(args.tasks)
    output_path = Path(args.out)
    tasks = read_jsonl(tasks_path)
    validate_jsonl(tasks_path, SCHEMA_DIR / "generation_task.schema.json")
    question_schema = read_json(SCHEMA_DIR / "quiz_question.schema.json")
    system_prompt = load_prompt("generator_system_ja.md")
    model = resolve_model(args.provider, args.model)
    limited_tasks = tasks[: args.limit or None]

    existing_rows = read_jsonl(output_path)
    completed_task_ids = {row.get("taskId") for row in existing_rows if row.get("taskId")}
    rows: list[dict[str, Any]] = list(existing_rows)
    pending_tasks = [task for task in limited_tasks if task["taskId"] not in completed_task_ids]

    if existing_rows:
        print(f"Resuming with {len(existing_rows)} existing drafts from {output_path}")

    if not pending_tasks:
        print(f"No pending tasks. {len(rows)} drafts are already saved in {output_path}")
        return

    total_tasks = len(limited_tasks)
    for task in pending_tasks:
        index = len(rows) + 1
        if args.provider == "openai":
            question = call_openai_json(
                model=model,
                system_prompt=system_prompt,
                user_prompt=task["userPrompt"],
                schema_name="minukuru_quiz_question",
                schema=question_schema,
                temperature=args.temperature,
            )
        elif args.provider == "gemini":
            question = call_gemini_json(
                model=model,
                system_prompt=system_prompt,
                user_prompt=task["userPrompt"],
                schema=question_schema,
                temperature=args.temperature,
            )
        else:
            raise PipelineError("run-generation は openai か gemini を指定してください。")

        question["id"] = generated_question_id_for_task(task)
        question["mode"] = task["mode"]
        question["accessTier"] = task["accessTier"]
        question["contentFlavor"] = task["contentFlavor"]

        validate_payload(question, SCHEMA_DIR / "quiz_question.schema.json")
        ensure_question_invariants(question)

        row = {
            "draftId": f"draft-{task['taskId']}",
            "taskId": task["taskId"],
            "batchLabel": task["batchLabel"],
            "provider": args.provider,
            "model": model,
            "mode": task["mode"],
            "accessTier": task["accessTier"],
            "contentFlavor": task["contentFlavor"],
            "sourceExampleId": task["sourceExample"]["id"],
            "blueprintExternalKey": task["blueprint"]["id"],
            "blueprintSlug": task["blueprint"]["slug"],
            "generatedQuestionId": question["id"],
            "question": question,
            "sourceSnapshot": task["sourceExample"],
            "generationContext": {
                "promptHash": hash_text(task["userPrompt"]),
                "blueprint": task["blueprint"]["slug"],
            },
            "createdAt": utc_now(),
        }
        rows.append(row)
        append_jsonl_row(output_path, row)
        if args.delay_seconds:
            time.sleep(args.delay_seconds)
        print(f"[{index}/{total_tasks}] generated {question['id']}")

    print(f"Wrote {len(rows)} generated drafts to {args.out}")


def run_review(args: argparse.Namespace) -> None:
    drafts = read_jsonl(Path(args.drafts))
    existing_questions = existing_questions_from_manifest(Path(args.existing_manifest))
    review_schema = read_json(SCHEMA_DIR / "review_result.schema.json")
    system_prompt = load_prompt("reviewer_system_ja.md")
    model = None if args.provider == "rulebased" else resolve_model(args.provider, args.model)
    rows: list[dict[str, Any]] = []

    for index, draft in enumerate(drafts[: args.limit or None], start=1):
        question = draft["question"]
        validate_payload(question, SCHEMA_DIR / "quiz_question.schema.json")
        ensure_question_invariants(question)

        local_result = local_review(question, existing_questions)

        if args.provider == "rulebased":
            final_review = local_result
            review_stage = "generation_self_check"
            reviewer_kind = "rulebased"
            reviewer_model = "local-heuristics"
        else:
            user_prompt = build_review_user_prompt(question, local_result, local_result["_topSimilarQuestions"])
            if args.provider == "openai":
                ai_review = call_openai_json(
                    model=model,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    schema_name="minukuru_review_result",
                    schema=review_schema,
                    temperature=args.temperature,
                )
            elif args.provider == "gemini":
                ai_review = call_gemini_json(
                    model=model,
                    system_prompt=system_prompt,
                    user_prompt=user_prompt,
                    schema=review_schema,
                    temperature=args.temperature,
                )
            else:
                raise PipelineError("run-review の provider は rulebased/openai/gemini のいずれかです。")

            validate_payload(ai_review, SCHEMA_DIR / "review_result.schema.json")
            final_review = merge_ai_review(ai_review, local_result)
            review_stage = "ai_review"
            reviewer_kind = args.provider
            reviewer_model = model

        row = {
            "reviewId": str(uuid.uuid4()),
            "draftId": draft["draftId"],
            "generatedQuestionId": draft["generatedQuestionId"],
            "reviewStage": review_stage,
            "reviewerKind": reviewer_kind,
            "reviewerModel": reviewer_model,
            "similarityRatio": final_review.pop("_localHighestSimilarity", 0.0),
            "topSimilarQuestions": final_review.pop("_topSimilarQuestions", []),
            "review": final_review,
            "createdAt": utc_now(),
        }
        rows.append(row)
        if args.delay_seconds and args.provider != "rulebased":
            time.sleep(args.delay_seconds)
        print(f"[{index}/{len(drafts)}] reviewed {draft['generatedQuestionId']} -> {row['review']['action']}")

    write_jsonl(Path(args.out), rows)
    print(f"Wrote {len(rows)} review rows to {args.out}")


def approved_questions_and_report(
    drafts_path: Path,
    reviews_path: Path,
    min_composite: int,
    min_safety: int,
    min_realism: int,
    min_learning: int,
    max_similarity: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    drafts = {row["draftId"]: row for row in read_jsonl(drafts_path)}
    reviews = {row["draftId"]: row for row in read_jsonl(reviews_path)}

    approved_questions: list[dict[str, Any]] = []
    report_rows: list[dict[str, Any]] = []
    now = utc_now()

    for draft_id, draft in drafts.items():
        review = reviews.get(draft_id)
        if not review:
            continue

        result = review["review"]
        passes_thresholds = (
            result["passed"]
            and result["compositeScore"] >= min_composite
            and result["safetyScore"] >= min_safety
            and result["realismScore"] >= min_realism
            and result["learningScore"] >= min_learning
            and review["similarityRatio"] <= max_similarity
        )

        report_rows.append(
            {
                "draftId": draft_id,
                "questionId": draft["generatedQuestionId"],
                "action": result["action"],
                "passed": result["passed"],
                "compositeScore": result["compositeScore"],
                "safetyScore": result["safetyScore"],
                "realismScore": result["realismScore"],
                "learningScore": result["learningScore"],
                "uniquenessScore": result["uniquenessScore"],
                "similarityRatio": review["similarityRatio"],
            }
        )

        if not passes_thresholds:
            continue

        question = dict(draft["question"])
        question["reviewStatus"] = "approved"
        question["authorName"] = "content-factory"
        question["authorId"] = f"{draft['provider']}:{draft['model']}"
        question["educationalScore"] = int(result["learningScore"])
        question["safetyLevel"] = max(1, min(5, 5 - int(result["safetyScore"] / 20)))
        question["reportCount"] = 0
        question["createdAt"] = now
        question["updatedAt"] = now
        approved_questions.append(question)

    return approved_questions, report_rows


def assemble_manifest(args: argparse.Namespace) -> None:
    published_questions, report_rows = approved_questions_and_report(
        drafts_path=Path(args.drafts),
        reviews_path=Path(args.reviews),
        min_composite=args.min_composite,
        min_safety=args.min_safety,
        min_realism=args.min_realism,
        min_learning=args.min_learning,
        max_similarity=args.max_similarity,
    )

    if args.base_manifest:
        base_questions = load_manifest_questions(Path(args.base_manifest))
        published_questions = merge_questions(base_questions, published_questions)

    manifest = {
        "schemaVersion": 1,
        "contentVersion": args.content_version,
        "updatedAt": now,
        "questions": published_questions,
    }

    write_json(Path(args.out), manifest)
    if args.report:
        write_json(Path(args.report), report_rows)
    print(f"Wrote manifest with {len(published_questions)} questions to {args.out}")


def build_manifest_set(args: argparse.Namespace) -> None:
    approved_questions, report_rows = approved_questions_and_report(
        drafts_path=Path(args.drafts),
        reviews_path=Path(args.reviews),
        min_composite=args.min_composite,
        min_safety=args.min_safety,
        min_realism=args.min_realism,
        min_learning=args.min_learning,
        max_similarity=args.max_similarity,
    )
    base_questions = load_manifest_questions(Path(args.base_manifest))
    now = utc_now()

    free_base_questions = [
        question for question in base_questions
        if question.get("accessTier", "free") == "free"
        and question.get("contentFlavor", "standard") != "realWorld"
    ]
    generated_free_questions = [
        question for question in approved_questions
        if question.get("accessTier", "free") == "free"
        and question.get("contentFlavor", "standard") != "realWorld"
    ]
    premium_questions = [
        question for question in approved_questions
        if question.get("accessTier", "free") == "premium"
    ]

    free_questions = merge_questions(free_base_questions, generated_free_questions)
    full_questions = merge_questions(base_questions, approved_questions)

    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    free_manifest = {
        "schemaVersion": 1,
        "contentVersion": f"{args.content_version_prefix}-free",
        "updatedAt": now,
        "questions": free_questions,
    }
    premium_manifest = {
        "schemaVersion": 1,
        "contentVersion": f"{args.content_version_prefix}-premium",
        "updatedAt": now,
        "questions": premium_questions,
    }
    full_manifest = {
        "schemaVersion": 1,
        "contentVersion": f"{args.content_version_prefix}-full",
        "updatedAt": now,
        "questions": full_questions,
    }

    write_json(output_dir / "free_manifest.json", free_manifest)
    write_json(output_dir / "premium_manifest.json", premium_manifest)
    write_json(output_dir / "full_manifest.json", full_manifest)
    write_json(output_dir / "review_report.json", report_rows)
    write_json(
        output_dir / "manifest_set_summary.json",
        {
            "generatedAt": now,
            "freeQuestionCount": len(free_questions),
            "premiumQuestionCount": len(premium_questions),
            "fullQuestionCount": len(full_questions),
            "reportRowCount": len(report_rows),
            "contentVersionPrefix": args.content_version_prefix,
        },
    )
    print(f"Wrote free/premium/full manifest set to {output_dir}")


def stage_manifest(args: argparse.Namespace) -> None:
    manifest_path = Path(args.manifest)
    if not manifest_path.exists():
        raise PipelineError(f"manifest が見つかりません: {manifest_path}")

    checksum = file_checksum(manifest_path)
    release_at_value = "now()" if args.release_at == "now" else f"{sql_nullable_text(args.release_at)}::timestamptz"
    sql = f"""
insert into admin.question_manifests (
  distribution_channel,
  content_version,
  storage_bucket,
  storage_path,
  checksum,
  status,
  release_at,
  notes
)
values (
  {sql_string_literal(args.distribution_channel)},
  {sql_string_literal(args.content_version)},
  {sql_string_literal(args.bucket)},
  {sql_string_literal(args.storage_path)},
  {sql_string_literal(checksum)},
  {sql_string_literal(args.status)},
  {release_at_value},
  {sql_nullable_text(args.notes)}
)
on conflict (content_version) do update
set distribution_channel = excluded.distribution_channel,
    storage_bucket = excluded.storage_bucket,
    storage_path = excluded.storage_path,
    checksum = excluded.checksum,
    status = excluded.status,
    release_at = excluded.release_at,
    notes = excluded.notes
returning distribution_channel, content_version, storage_bucket, storage_path, status, release_at, checksum;
"""
    result = run_supabase_sql(sql, output="json")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def set_publish_schedule(args: argparse.Namespace) -> None:
    sql = f"""
update admin.runtime_config
set value = jsonb_build_object(
  'cron', {sql_string_literal(args.cron)},
  'timezone', {sql_string_literal(args.timezone)}
)
where key = 'content_publish_schedule';

select admin.reschedule_content_publish_job();

select value
from admin.runtime_config
where key = 'content_publish_schedule';
"""
    result = run_supabase_sql(sql, output="json")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def publish_now(args: argparse.Namespace) -> None:
    del args
    result = run_supabase_sql("select * from admin.publish_due_manifest();", output="json")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def remote_status(args: argparse.Namespace) -> None:
    del args
    sql = """
select jsonb_build_object(
  'sourceCount', (select count(*) from admin.source_examples),
  'blueprintCount', (select count(*) from admin.pattern_blueprints),
  'draftCount', (select count(*) from admin.question_drafts),
  'reviewCount', (select count(*) from admin.review_runs),
  'readyCount', (
    select count(*)
    from admin.ready_publish_candidates
    where latest_action = 'accept'
      and latest_passed = true
  ),
  'schedule', (
    select value
    from admin.runtime_config
    where key = 'content_publish_schedule'
  ),
  'publishedManifests', (
    select coalesce(jsonb_agg(meta order by meta->>'distributionChannel'), '[]'::jsonb)
    from (
      select jsonb_build_object(
        'distributionChannel', distribution_channel,
        'contentVersion', content_version,
        'storageBucket', storage_bucket,
        'storagePath', storage_path,
        'updatedAt', updated_at
      ) as meta
      from (
        select * from public.get_published_manifest_metadata('free')
        union all
        select * from public.get_published_manifest_metadata('premium')
        union all
        select * from public.get_published_manifest_metadata('full')
      ) manifests
    ) rows
  ),
  'cronJob', (
    select to_jsonb(job_row)
    from (
      select jobname, schedule, active
      from cron.job
      where jobname = 'minukuru_publish_content'
      limit 1
    ) job_row
  )
) as status;
"""
    result = run_supabase_sql(sql, output="json")
    print(json.dumps(result, ensure_ascii=False, indent=2))


def prepare_human_review(args: argparse.Namespace) -> None:
    drafts = read_jsonl(Path(args.drafts))
    ai_reviews = read_jsonl(Path(args.reviews))
    tasks = read_jsonl(Path(args.tasks))
    decisions = read_decision_file(Path(args.decisions))
    validate_payload(decisions, SCHEMA_DIR / "human_review_decisions.schema.json")
    outputs = compile_review_outputs(
        drafts,
        ai_reviews,
        tasks,
        decisions,
        require_complete=args.require_complete,
    )

    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    paths = {
        "approved": output_dir / "approved_drafts.jsonl",
        "reviews": output_dir / "human_reviews.jsonl",
        "regenerate": output_dir / "regeneration_tasks.jsonl",
        "rejected": output_dir / "rejected_drafts.jsonl",
        "pending": output_dir / "pending_drafts.jsonl",
        "summary": output_dir / "decision_summary.json",
    }
    write_jsonl(paths["approved"], outputs["acceptedDrafts"])
    write_jsonl(paths["reviews"], outputs["humanReviews"])
    write_jsonl(paths["regenerate"], outputs["regenerationTasks"])
    write_jsonl(paths["rejected"], outputs["rejectedDrafts"])
    write_jsonl(paths["pending"], outputs["pendingDrafts"])
    write_json(paths["summary"], outputs["summary"])

    for row in outputs["humanReviews"]:
        validate_payload(row["review"], SCHEMA_DIR / "review_result.schema.json")
    validate_jsonl(paths["regenerate"], SCHEMA_DIR / "generation_task.schema.json")

    if args.sync:
        review_rows = reviews_sql_rows(paths["reviews"])
        inserted_result = run_supabase_sql(build_insert_reviews_sql(review_rows), output="json")
        updated_result = run_supabase_sql(build_refresh_drafts_from_reviews_sql(review_rows), output="json")
        print(json.dumps({"inserted": inserted_result, "updated": updated_result}, ensure_ascii=False, indent=2))

    print(json.dumps(outputs["summary"], ensure_ascii=False, indent=2))
    print(f"Wrote human review outputs to {output_dir}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Minukuru content factory pipeline")
    subparsers = parser.add_subparsers(dest="command", required=True)

    build_batch = subparsers.add_parser("build-generation-batch", help="素材と blueprint から生成タスクを作る")
    build_batch.add_argument("--sources", default=str(FACTORY_DIR / "sample_data" / "source_examples.jsonl"))
    build_batch.add_argument("--blueprints", default=str(FACTORY_DIR / "sample_data" / "pattern_blueprints.json"))
    build_batch.add_argument("--existing-manifest", default=str(APP_QUESTIONS_PATH))
    build_batch.add_argument("--per-blueprint", type=int, default=2)
    build_batch.add_argument("--seed", type=int, default=42)
    build_batch.add_argument("--batch-label")
    build_batch.add_argument("--out", default=str(FACTORY_DIR / "output" / "generation_tasks.jsonl"))
    build_batch.set_defaults(func=build_generation_batch)

    validate = subparsers.add_parser("validate-fixtures", help="sample data と schema の整合を確認する")
    validate.add_argument("--sources", default=str(FACTORY_DIR / "sample_data" / "source_examples.jsonl"))
    validate.add_argument("--blueprints", default=str(FACTORY_DIR / "sample_data" / "pattern_blueprints.json"))
    validate.add_argument("--drafts", default=str(FACTORY_DIR / "sample_data" / "sample_drafts.jsonl"))
    validate.set_defaults(func=validate_fixtures)

    sync_reference = subparsers.add_parser("sync-reference-data", help="source_examples と pattern_blueprints を Supabase に同期する")
    sync_reference.add_argument("--sources", default=str(FACTORY_DIR / "sample_data" / "source_examples.jsonl"))
    sync_reference.add_argument("--blueprints", default=str(FACTORY_DIR / "sample_data" / "pattern_blueprints.json"))
    sync_reference.set_defaults(func=sync_reference_data)

    generate = subparsers.add_parser("run-generation", help="OpenAI か Gemini で問題 draft を生成する")
    generate.add_argument("--tasks", default=str(FACTORY_DIR / "output" / "generation_tasks.jsonl"))
    generate.add_argument("--provider", choices=["openai", "gemini"], required=True)
    generate.add_argument("--model")
    generate.add_argument("--temperature", type=float)
    generate.add_argument("--delay-seconds", type=float, default=0.0)
    generate.add_argument("--limit", type=int)
    generate.add_argument("--out", default=str(FACTORY_DIR / "output" / "generated_drafts.jsonl"))
    generate.set_defaults(func=run_generation)

    import_drafts_parser = subparsers.add_parser("import-drafts", help="generated drafts を Supabase に取り込む")
    import_drafts_parser.add_argument("--drafts", default=str(FACTORY_DIR / "sample_data" / "sample_drafts.jsonl"))
    import_drafts_parser.set_defaults(func=import_drafts)

    review = subparsers.add_parser("run-review", help="draft 問題にレビューをかける")
    review.add_argument("--drafts", default=str(FACTORY_DIR / "sample_data" / "sample_drafts.jsonl"))
    review.add_argument("--existing-manifest", default=str(APP_QUESTIONS_PATH))
    review.add_argument("--provider", choices=["rulebased", "openai", "gemini"], default="rulebased")
    review.add_argument("--model")
    review.add_argument("--temperature", type=float)
    review.add_argument("--delay-seconds", type=float, default=0.0)
    review.add_argument("--limit", type=int)
    review.add_argument("--out", default=str(FACTORY_DIR / "output" / "reviews.jsonl"))
    review.set_defaults(func=run_review)

    import_reviews_parser = subparsers.add_parser("import-reviews", help="review 結果を Supabase に取り込む")
    import_reviews_parser.add_argument("--reviews", default=str(FACTORY_DIR / "output" / "reviews.jsonl"))
    import_reviews_parser.set_defaults(func=import_reviews)

    human_review = subparsers.add_parser(
        "prepare-human-review",
        help="レビュー画面の判定から人手レビュー結果と再生成タスクを作る",
    )
    human_review.add_argument("--drafts", required=True)
    human_review.add_argument("--reviews", required=True)
    human_review.add_argument("--tasks", required=True)
    human_review.add_argument("--decisions", required=True)
    human_review.add_argument("--out-dir", required=True)
    human_review.add_argument("--require-complete", action="store_true")
    human_review.add_argument("--sync", action="store_true", help="人手レビュー結果を Supabase に同期する")
    human_review.set_defaults(func=prepare_human_review)

    assemble = subparsers.add_parser("assemble-manifest", help="review を通った draft から manifest を作る")
    assemble.add_argument("--drafts", default=str(FACTORY_DIR / "sample_data" / "sample_drafts.jsonl"))
    assemble.add_argument("--reviews", default=str(FACTORY_DIR / "output" / "reviews.jsonl"))
    assemble.add_argument("--content-version", default=f"premium-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
    assemble.add_argument("--min-composite", type=int, default=78)
    assemble.add_argument("--min-safety", type=int, default=86)
    assemble.add_argument("--min-realism", type=int, default=72)
    assemble.add_argument("--min-learning", type=int, default=70)
    assemble.add_argument("--max-similarity", type=float, default=SIMILARITY_THRESHOLD)
    assemble.add_argument("--base-manifest")
    assemble.add_argument("--out", default=str(FACTORY_DIR / "output" / "premium_manifest.json"))
    assemble.add_argument("--report", default=str(FACTORY_DIR / "output" / "premium_manifest_report.json"))
    assemble.set_defaults(func=assemble_manifest)

    manifest_set = subparsers.add_parser("build-manifest-set", help="free / premium / full の配信用 manifest をまとめて作る")
    manifest_set.add_argument("--drafts", default=str(FACTORY_DIR / "sample_data" / "sample_drafts.jsonl"))
    manifest_set.add_argument("--reviews", default=str(FACTORY_DIR / "output" / "reviews.jsonl"))
    manifest_set.add_argument("--base-manifest", default=str(APP_QUESTIONS_PATH))
    manifest_set.add_argument("--content-version-prefix", default=f"release-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
    manifest_set.add_argument("--min-composite", type=int, default=78)
    manifest_set.add_argument("--min-safety", type=int, default=86)
    manifest_set.add_argument("--min-realism", type=int, default=72)
    manifest_set.add_argument("--min-learning", type=int, default=70)
    manifest_set.add_argument("--max-similarity", type=float, default=SIMILARITY_THRESHOLD)
    manifest_set.add_argument("--out-dir", default=str(FACTORY_DIR / "output" / "manifest_set"))
    manifest_set.set_defaults(func=build_manifest_set)

    export_ready = subparsers.add_parser("export-ready-manifest", help="Supabase の ready candidates から manifest を組み立てる")
    export_ready.add_argument("--content-version", default=f"premium-ready-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
    export_ready.add_argument("--access-tier", default="premium")
    export_ready.add_argument("--content-flavor", default="standard", choices=["standard", "realWorld", "all"])
    export_ready.add_argument("--min-composite", type=int, default=78)
    export_ready.add_argument("--min-safety", type=int, default=86)
    export_ready.add_argument("--min-realism", type=int, default=72)
    export_ready.add_argument("--min-learning", type=int, default=70)
    export_ready.add_argument("--max-similarity", type=float, default=SIMILARITY_THRESHOLD)
    export_ready.add_argument("--limit", type=int, default=200)
    export_ready.add_argument("--base-manifest")
    export_ready.add_argument("--out", default=str(FACTORY_DIR / "output" / "ready_manifest.json"))
    export_ready.add_argument("--report", default=str(FACTORY_DIR / "output" / "ready_manifest_report.json"))
    export_ready.set_defaults(func=export_ready_manifest)

    stage_manifest_parser = subparsers.add_parser("stage-manifest", help="storage に置いた manifest を question_manifests に staged 登録する")
    stage_manifest_parser.add_argument("--manifest", required=True)
    stage_manifest_parser.add_argument("--content-version", required=True)
    stage_manifest_parser.add_argument("--storage-path", required=True)
    stage_manifest_parser.add_argument("--bucket", default="minukuru-content")
    stage_manifest_parser.add_argument("--distribution-channel", default="full", choices=["free", "premium", "full"])
    stage_manifest_parser.add_argument("--status", default="staged", choices=["draft", "staged"])
    stage_manifest_parser.add_argument("--release-at", default="now")
    stage_manifest_parser.add_argument("--notes")
    stage_manifest_parser.set_defaults(func=stage_manifest)

    schedule_parser = subparsers.add_parser("set-publish-schedule", help="公開 cron を更新して pg_cron を再設定する")
    schedule_parser.add_argument("--cron", required=True)
    schedule_parser.add_argument("--timezone", default="Asia/Tokyo")
    schedule_parser.set_defaults(func=set_publish_schedule)

    publish_now_parser = subparsers.add_parser("publish-now", help="release_at を過ぎた staged manifest を即時 publish する")
    publish_now_parser.set_defaults(func=publish_now)

    remote_status_parser = subparsers.add_parser("remote-status", help="Supabase 側の content factory / publish 状態を確認する")
    remote_status_parser.set_defaults(func=remote_status)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except (PipelineError, ReviewWorkflowError, jsonschema.ValidationError, KeyError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
