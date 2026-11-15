"""Claude Codeの契約ログインを使い、教材だけを2つの独立セッションで審査する。"""
from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

import jsonschema

MAX_QUESTIONS = 20


class ClaudeBatchError(RuntimeError):
    pass


def result_schema(item_schema: dict) -> dict:
    return {
        "type": "object", "additionalProperties": False, "required": ["results"],
        "properties": {"results": {"type": "array", "items": {
            **item_schema,
            "required": ["questionId", *item_schema["required"]],
            "properties": {"questionId": {"type": "string"}, **item_schema["properties"]},
        }}},
    }


def parse_batch(envelope: dict, model: str, schema: dict, expected_ids: list[str]) -> dict[str, dict]:
    if not isinstance(envelope, dict) or envelope.get("is_error") is not False or envelope.get("subtype") != "success":
        raise ClaudeBatchError("Claude Codeが審査を完了しませんでした。保存した応答を確認してください。")
    usage = envelope.get("modelUsage")
    if (not isinstance(usage, dict) or set(usage) != {model}
            or not isinstance(usage[model], dict) or usage[model].get("provider") != "firstParty"):
        raise ClaudeBatchError("Claude Codeの応答に、指定したモデルと一致する実行記録がありません。")
    payload = envelope.get("structured_output")
    jsonschema.validate(payload, schema)
    rows = payload["results"]
    by_id = {row["questionId"]: {k: v for k, v in row.items() if k != "questionId"} for row in rows}
    if set(by_id) != set(expected_ids) or len(rows) != len(expected_ids):
        raise ClaudeBatchError("Claude Codeの審査結果に問題IDの欠落・重複・余分な項目があります。")
    return by_id


def require_model_id(model: str) -> None:
    if not re.fullmatch(r"claude-[a-z]+(?:-[0-9]+){2,3}", model):
        raise ClaudeBatchError("Claude審査では別名を使わず、完全なモデルIDを指定してください。")


def run_claude_batch(
    model: str, system_prompt: str, items: list[dict], item_schema: dict, audit_path: Path
) -> dict[str, dict]:
    require_model_id(model)
    expected_ids = [x["questionId"] for x in items]
    if not 1 <= len(expected_ids) <= MAX_QUESTIONS or len(set(expected_ids)) != len(expected_ids):
        raise ClaudeBatchError(f"Claude審査には重複のない1〜{MAX_QUESTIONS}問を指定してください。")
    if audit_path.exists():
        raise ClaudeBatchError("Claude Codeの応答保存先が既にあります。新しい出力先を指定してください。")

    # APIキー、別アカウント用のプロバイダー、任意のAPI接続先を引き継がない。
    env = {k: v for k, v in os.environ.items() if not k.startswith(("ANTHROPIC_", "CLAUDE_CODE_USE_"))}
    env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
    env["MAX_STRUCTURED_OUTPUT_RETRIES"] = "0"
    schema = result_schema(item_schema)
    # リポジトリと資格情報に触れない新規セッションへ、必要な問題データだけ渡す。
    try:
        with tempfile.TemporaryDirectory(prefix="minukuru-claude-review-") as cwd:
            auth_result = subprocess.run(
                ["claude", "auth", "status"], cwd=cwd, env=env, timeout=10, capture_output=True, text=True,
            )
            auth = json.loads(auth_result.stdout)
            if auth_result.returncode or not isinstance(auth, dict) or auth.get("loggedIn") is not True or (
                auth.get("authMethod"), auth.get("apiProvider")
            ) != ("claude.ai", "firstParty"):
                raise ClaudeBatchError("Claude Codeの契約ログインを確認してください。")
            prompt = system_prompt + (
                "\n入力の全項目を処理し、resultsに問題ごとに1件出力してください。"
                "questionIdは入力を一字も変えずに使ってください。"
            )
            result = subprocess.run(
                [
                    "claude", "-p", "--safe-mode", "--strict-mcp-config", "--no-chrome",
                    "--tools", "", "--no-session-persistence", "--setting-sources", "",
                    "--permission-mode", "dontAsk", "--model", model, "--output-format", "json",
                    "--json-schema", json.dumps(schema), "--system-prompt", prompt,
                ],
                input=json.dumps(items, ensure_ascii=False),
                cwd=cwd, env=env, timeout=180, capture_output=True, text=True,
            )
        audit_path.parent.mkdir(parents=True, exist_ok=True)
        with audit_path.open("x", encoding="utf-8") as handle:
            handle.write(result.stdout)
        if result.returncode:
            raise ClaudeBatchError("Claude Codeの審査が終了しました。保存した応答を確認してください。")
        return parse_batch(json.loads(result.stdout), model, schema, expected_ids)
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        raise ClaudeBatchError("Claude Codeの接続か応答確認に失敗しました。再試行は行っていません。") from exc
