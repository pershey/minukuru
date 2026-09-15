#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import json
import uuid
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


DECISION_VALUES = {"accept", "revise", "reject"}


class ReviewWorkflowError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def batch_fingerprint(drafts: list[dict[str, Any]]) -> str:
    lines = []
    for row in sorted(drafts, key=lambda item: item["draftId"]):
        question = row["question"]
        question_text = " ".join(
            [
                question["title"],
                " ".join(segment["text"] for segment in question["segments"]),
                question["explanation"],
                question["verificationTip"],
            ]
        )
        question_hash = hashlib.sha256(question_text.encode("utf-8")).hexdigest()
        lines.append(f"{row['draftId']}\t{row['generatedQuestionId']}\t{question_hash}")
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def read_decision_file(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise ReviewWorkflowError("判定ファイルが空です。")

    if text.startswith("{"):
        payload = json.loads(text)
        if not isinstance(payload, dict):
            raise ReviewWorkflowError("判定ファイルは object 形式である必要があります。")
        return payload

    decisions = [json.loads(line) for line in text.splitlines() if line.strip()]
    fingerprint = next(
        (row.get("batchFingerprint") for row in decisions if row.get("batchFingerprint")),
        None,
    )
    return {
        "schemaVersion": 1,
        "batchFingerprint": fingerprint,
        "exportedAt": utc_now(),
        "decisions": decisions,
    }


def validate_decisions(
    drafts: list[dict[str, Any]],
    payload: dict[str, Any],
    *,
    require_complete: bool,
) -> dict[str, dict[str, Any]]:
    expected_fingerprint = batch_fingerprint(drafts)
    actual_fingerprint = payload.get("batchFingerprint")
    if not actual_fingerprint:
        raise ReviewWorkflowError("判定ファイルに batchFingerprint がありません。レビュー画面から再出力してください。")
    if actual_fingerprint != expected_fingerprint:
        raise ReviewWorkflowError("判定対象の問題が更新されています。レビュー画面を再生成して判定し直してください。")

    draft_by_id = {row["draftId"]: row for row in drafts}
    decisions_by_draft: dict[str, dict[str, Any]] = {}
    for index, decision in enumerate(payload.get("decisions", []), start=1):
        if not isinstance(decision, dict):
            raise ReviewWorkflowError(f"判定 {index} は object 形式である必要があります。")

        draft_id = decision.get("draftId")
        action = decision.get("decision")
        if not draft_id or draft_id not in draft_by_id:
            raise ReviewWorkflowError(f"判定 {index} の draftId が対象バッチにありません。")
        if draft_id in decisions_by_draft:
            raise ReviewWorkflowError(f"同じ draftId の判定が重複しています: {draft_id}")
        if action not in DECISION_VALUES:
            raise ReviewWorkflowError(f"判定 {index} の decision は accept/revise/reject のいずれかにしてください。")

        draft = draft_by_id[draft_id]
        if decision.get("generatedQuestionId") != draft["generatedQuestionId"]:
            raise ReviewWorkflowError(f"問題IDが一致しません: {draft_id}")

        note = str(decision.get("note") or "").strip()
        if action in {"revise", "reject"} and not note:
            raise ReviewWorkflowError(f"再生成・見送りにはメモが必要です: {draft['generatedQuestionId']}")

        decisions_by_draft[draft_id] = {
            **decision,
            "note": note,
            "decidedAt": decision.get("decidedAt") or payload.get("exportedAt") or utc_now(),
        }

    if require_complete:
        pending = sorted(set(draft_by_id) - set(decisions_by_draft))
        if pending:
            raise ReviewWorkflowError(f"未判定の問題が {len(pending)} 問あります。")

    return decisions_by_draft


def manual_review_row(
    draft: dict[str, Any],
    ai_review: dict[str, Any],
    decision: dict[str, Any],
    fingerprint: str,
) -> dict[str, Any]:
    action = decision["decision"]
    note = decision["note"]
    base_review = dict(ai_review["review"])
    base_review["passed"] = action == "accept"
    base_review["action"] = action
    action_label = {"accept": "採用", "revise": "再生成", "reject": "見送り"}[action]
    base_review["summary"] = f"運営の人手レビューで「{action_label}」と判定しました。" + (f" メモ: {note}" if note else "")
    if action == "revise" and note:
        base_review["revisionAdvice"] = [*base_review.get("revisionAdvice", []), note]
    if action == "reject" and note:
        base_review["concerns"] = [*base_review.get("concerns", []), note]

    review_uuid = uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"minukuru:{fingerprint}:{draft['draftId']}:{action}:{decision['decidedAt']}:{note}",
    )
    return {
        "reviewId": str(review_uuid),
        "draftId": draft["draftId"],
        "generatedQuestionId": draft["generatedQuestionId"],
        "reviewStage": "human_review",
        "reviewerKind": "manual",
        "reviewerModel": "review-dashboard-v1",
        "similarityRatio": ai_review.get("similarityRatio", 0.0),
        "topSimilarQuestions": ai_review.get("topSimilarQuestions", []),
        "review": base_review,
        "createdAt": decision["decidedAt"],
    }


def revision_task(
    draft: dict[str, Any],
    task: dict[str, Any],
    decision: dict[str, Any],
    fingerprint: str,
) -> dict[str, Any]:
    note = decision["note"]
    revision_uuid = uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"minukuru-revision:{fingerprint}:{task['taskId']}:{decision['decidedAt']}:{note}",
    )
    revised = dict(task)
    revised["taskId"] = str(revision_uuid)
    revised["batchLabel"] = f"{task['batchLabel']}-revision"
    revised["userPrompt"] = (
        f"{task['userPrompt'].rstrip()}\n\n"
        "## 人手レビューからの修正指示\n"
        f"- 元の問題ID: {draft['generatedQuestionId']}\n"
        f"- 修正内容: {note}\n"
        "- 元の問題を言い換えるだけではなく、修正内容を反映した新しい問題として作り直す\n"
    )
    return revised


def compile_review_outputs(
    drafts: list[dict[str, Any]],
    ai_reviews: list[dict[str, Any]],
    tasks: list[dict[str, Any]],
    decision_payload: dict[str, Any],
    *,
    require_complete: bool = False,
) -> dict[str, Any]:
    fingerprint = batch_fingerprint(drafts)
    decisions = validate_decisions(drafts, decision_payload, require_complete=require_complete)
    ai_review_by_draft = {row["draftId"]: row for row in ai_reviews}
    task_by_id = {row["taskId"]: row for row in tasks}

    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    pending: list[dict[str, Any]] = []
    human_reviews: list[dict[str, Any]] = []
    regeneration_tasks: list[dict[str, Any]] = []

    for draft in drafts:
        decision = decisions.get(draft["draftId"])
        if not decision:
            pending.append(draft)
            continue

        ai_review = ai_review_by_draft.get(draft["draftId"])
        if not ai_review:
            raise ReviewWorkflowError(f"AIレビューがありません: {draft['generatedQuestionId']}")

        human_reviews.append(manual_review_row(draft, ai_review, decision, fingerprint))
        if decision["decision"] == "accept":
            accepted.append(draft)
        elif decision["decision"] == "reject":
            rejected.append(draft)
        else:
            task = task_by_id.get(draft.get("taskId"))
            if not task:
                raise ReviewWorkflowError(f"再生成元の task がありません: {draft['generatedQuestionId']}")
            regeneration_tasks.append(revision_task(draft, task, decision, fingerprint))

    return {
        "batchFingerprint": fingerprint,
        "acceptedDrafts": accepted,
        "rejectedDrafts": rejected,
        "pendingDrafts": pending,
        "humanReviews": human_reviews,
        "regenerationTasks": regeneration_tasks,
        "summary": {
            "generatedAt": utc_now(),
            "batchFingerprint": fingerprint,
            "totalDraftCount": len(drafts),
            "decisionCount": len(decisions),
            "acceptedCount": len(accepted),
            "regenerationCount": len(regeneration_tasks),
            "rejectedCount": len(rejected),
            "pendingCount": len(pending),
        },
    }
