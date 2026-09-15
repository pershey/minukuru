#!/usr/bin/env python3

from __future__ import annotations

import argparse
import html
import json
from collections import Counter
from pathlib import Path
from statistics import mean
from typing import Any

from review_workflow import batch_fingerprint


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def badge(label: str, value: str, tone: str = "default") -> str:
    return (
        f'<span class="badge badge-{tone}">'
        f'<span class="badge-label">{html.escape(label)}</span>'
        f'<span class="badge-value">{html.escape(value)}</span>'
        "</span>"
    )


def render_segments(question: dict[str, Any]) -> str:
    correct_ids = set(question.get("correctSegmentIds", []))
    items = []
    for segment in question.get("segments", []):
        is_correct = segment["id"] in correct_ids
        cls = "segment segment-correct" if is_correct else "segment"
        marker = "要注意" if is_correct else "本文"
        items.append(
            f'<li class="{cls}"><span class="segment-marker">{marker}</span>'
            f"<span>{html.escape(segment['text'])}</span></li>"
        )
    return "".join(items)


def render_answer_area(question: dict[str, Any]) -> str:
    if question.get("responseType", "selectSegments") != "singleChoice":
        return f'<ol class="segments">{render_segments(question)}</ol>'

    correct_choice_id = question.get("correctChoiceId")
    items = []
    for choice in question.get("answerChoices", []):
        is_correct = choice.get("id") == correct_choice_id
        cls = "segment segment-correct" if is_correct else "segment"
        marker = "正解" if is_correct else "選択肢"
        semantic = choice.get("semantic", "other")
        items.append(
            f'<li class="{cls}"><span class="segment-marker">{marker}</span>'
            f"<span>{html.escape(choice.get('text', ''))}</span>"
            f"<span class='muted'> {html.escape(semantic)}</span></li>"
        )
    return f'<ol class="segments">{"".join(items)}</ol>'


def render_reason_tags(question: dict[str, Any]) -> str:
    tags = question.get("recommendedReasonTags", [])
    if not tags:
        return '<span class="muted">なし</span>'
    return "".join(f'<span class="tag">{html.escape(tag)}</span>' for tag in tags)


def review_metrics(review_row: dict[str, Any]) -> dict[str, Any]:
    review = review_row.get("review", {})
    return {
        "passed": review.get("passed", False),
        "action": review.get("action") or "unknown",
        "composite": review.get("compositeScore", 0),
        "realism": review.get("realismScore", 0),
        "safety": review.get("safetyScore", 0),
        "learning": review.get("learningScore", 0),
        "uniqueness": review.get("uniquenessScore", 0),
        "clarity": review.get("segmentClarityScore", 0),
        "summary": review.get("summary", ""),
        "concerns": review.get("concerns", []),
        "advice": review.get("revisionAdvice", []),
        "matched": review.get("matchedSignals", []),
        "similarity": review_row.get("similarityRatio", 0),
    }


def render_card(draft_row: dict[str, Any], review_row: dict[str, Any] | None) -> str:
    question = draft_row["question"]
    metrics = review_metrics(review_row or {})
    mode = draft_row["mode"]
    flavor = draft_row["contentFlavor"]
    tone = "pass" if metrics["passed"] else "warn"
    concerns = review_row.get("review", {}).get("concerns", []) if review_row else []
    advice = review_row.get("review", {}).get("revisionAdvice", []) if review_row else []
    top_similar = review_row.get("topSimilarQuestions", []) if review_row else []

    similar_html = "".join(
        f"<li>{html.escape(item['title'])} "
        f"<span class='muted'>({html.escape(item['mode'])} / {item['similarityRatio']})</span></li>"
        for item in top_similar
    ) or "<li class='muted'>なし</li>"

    concerns_html = "".join(f"<li>{html.escape(item)}</li>" for item in concerns) or "<li class='muted'>なし</li>"
    advice_html = "".join(f"<li>{html.escape(item)}</li>" for item in advice) or "<li class='muted'>なし</li>"

    return f"""
    <article class="card" data-draft-id="{html.escape(draft_row['draftId'])}" data-mode="{html.escape(mode)}" data-flavor="{html.escape(flavor)}" data-action="{html.escape(metrics['action'])}" data-human-decision="pending">
      <div class="card-header">
        <div>
          <h2>{html.escape(question['title'])}</h2>
          <p class="meta">{html.escape(draft_row['generatedQuestionId'])}</p>
        </div>
        <div class="badges">
          {badge("モード", mode)}
          {badge("flavor", flavor)}
          {badge("対象", question.get("audience", "general"))}
          {badge("段階", question.get("learningStage", "challenge"))}
          {badge("観点", question.get("learningFocus", "evidence"))}
          {badge("判定", metrics["action"], tone)}
          {badge("総合", str(metrics["composite"]), tone)}
        </div>
      </div>

      <div class="grid">
        <section>
          <h3>問題文</h3>
          <p class="instruction">{html.escape(question['instruction'])}</p>
          {render_answer_area(question)}
        </section>

        <section>
          <h3>どこに注目するか</h3>
          <p>{html.escape(question.get('attentionPoint', '未入力'))}</p>
          <h3>なぜ気をつけるか</h3>
          <p>{html.escape(question['explanation'])}</p>
          <h3>次にどうするか</h3>
          <p>{html.escape(question['verificationTip'])}</p>
          <h3>ヒント</h3>
          <p>{html.escape(question['hint'])}</p>
        </section>
      </div>

      <div class="grid compact">
        <section>
          <h3>理由タグ</h3>
          <div class="tags">{render_reason_tags(question)}</div>
        </section>

        <section>
          <h3>レビュー指標</h3>
          <div class="metric-list">
            {badge("realism", str(metrics["realism"]))}
            {badge("safety", str(metrics["safety"]))}
            {badge("learning", str(metrics["learning"]))}
            {badge("uniqueness", str(metrics["uniqueness"]))}
            {badge("clarity", str(metrics["clarity"]))}
            {badge("similarity", f"{metrics['similarity']:.2f}")}
          </div>
          <p class="meta">{html.escape(metrics["summary"])}</p>
        </section>
      </div>

      <div class="grid compact">
        <section>
          <h3>懸念</h3>
          <ul>{concerns_html}</ul>
        </section>

        <section>
          <h3>修正メモ</h3>
          <ul>{advice_html}</ul>
        </section>
      </div>

      <details>
        <summary>生成素材と近い既存問題を見る</summary>
        <div class="grid compact">
          <section>
            <h3>元素材</h3>
            <p class="meta">{html.escape(draft_row['sourceSnapshot']['title'])}</p>
            <p>{html.escape(draft_row['sourceSnapshot']['redactedExcerpt'])}</p>
            <p class="meta">{html.escape(draft_row['sourceSnapshot'].get('referenceNotes', ''))}</p>
          </section>
          <section>
            <h3>近い既存問題</h3>
            <ul>{similar_html}</ul>
          </section>
        </div>
      </details>

      <section class="human-review" aria-label="人手レビュー">
        <div class="human-review-heading">
          <div>
            <h3>運営の判定</h3>
            <p class="meta">再生成・見送りを選ぶときは、次の生成に活かせるメモも入力してください。</p>
          </div>
          <span class="decision-status" data-decision-status>未判定</span>
        </div>
        <div class="decision-buttons" role="group" aria-label="この問題の判定">
          <button type="button" class="decision-button decision-accept" data-decision="accept">採用</button>
          <button type="button" class="decision-button decision-revise" data-decision="revise">再生成</button>
          <button type="button" class="decision-button decision-reject" data-decision="reject">見送り</button>
        </div>
        <label class="review-note-label">
          判定メモ
          <textarea class="review-note" rows="3" placeholder="例: 広告らしさを残しつつ、言い切りを1か所減らす"></textarea>
        </label>
      </section>
    </article>
    """


def build_dashboard(drafts: list[dict[str, Any]], reviews: list[dict[str, Any]], title: str) -> str:
    fingerprint = batch_fingerprint(drafts)
    review_by_draft = {row["draftId"]: row for row in reviews}
    mode_counts = Counter(row["mode"] for row in drafts)
    flavor_counts = Counter(row["contentFlavor"] for row in drafts)
    actions = Counter((review_by_draft.get(row["draftId"], {}).get("review", {}).get("action") or "unknown") for row in drafts)
    composite_scores = [
        review_by_draft[row["draftId"]]["review"]["compositeScore"]
        for row in drafts
        if row["draftId"] in review_by_draft and "review" in review_by_draft[row["draftId"]]
    ]
    avg_composite = round(mean(composite_scores), 1) if composite_scores else 0

    cards_html = "\n".join(render_card(row, review_by_draft.get(row["draftId"])) for row in drafts)

    mode_options = "".join(
        f'<option value="{html.escape(mode)}">{html.escape(mode)} ({count})</option>'
        for mode, count in sorted(mode_counts.items())
    )
    flavor_options = "".join(
        f'<option value="{html.escape(flavor)}">{html.escape(flavor)} ({count})</option>'
        for flavor, count in sorted(flavor_counts.items())
    )
    action_options = "".join(
        f'<option value="{html.escape(action)}">{html.escape(action)} ({count})</option>'
        for action, count in sorted(actions.items())
    )

    summary_badges = "".join(
        [
            badge("問題数", str(len(drafts)), "pass"),
            badge("平均総合", str(avg_composite), "default"),
            badge("standard", str(flavor_counts.get("standard", 0))),
            badge("realWorld", str(flavor_counts.get("realWorld", 0))),
        ]
    )
    dashboard_catalog = [
        {
            "draftId": row["draftId"],
            "generatedQuestionId": row["generatedQuestionId"],
        }
        for row in drafts
    ]
    dashboard_data = json.dumps(
        {
            "schemaVersion": 1,
            "batchFingerprint": fingerprint,
            "catalog": dashboard_catalog,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    ).replace("<", "\\u003c")

    return f"""<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
  <style>
    :root {{
      --bg: #f7f3eb;
      --card: #ffffff;
      --line: #e8dcc8;
      --text: #18345c;
      --muted: #667892;
      --accent: #ff7a59;
      --accent-soft: #fff0e5;
      --ok: #1f8f63;
      --ok-soft: #e7f6ef;
      --warn: #c4643c;
      --warn-soft: #fff4ec;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", sans-serif;
      background: linear-gradient(180deg, #fcfaf6 0%, var(--bg) 100%);
      color: var(--text);
    }}
    .shell {{
      max-width: 1200px;
      margin: 0 auto;
      padding: 32px 20px 80px;
    }}
    .hero {{
      background: rgba(255,255,255,0.92);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 28px;
      box-shadow: 0 20px 50px rgba(24, 52, 92, 0.08);
      margin-bottom: 20px;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: 36px;
      line-height: 1.2;
    }}
    p {{
      line-height: 1.7;
    }}
    .muted, .meta {{
      color: var(--muted);
    }}
    .meta {{
      font-size: 13px;
    }}
    .badges, .metric-list, .summary-badges, .tags {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }}
    .badge {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
      border-radius: 999px;
      padding: 8px 12px;
      font-size: 13px;
      border: 1px solid var(--line);
      background: #fff;
    }}
    .badge-pass {{
      background: var(--ok-soft);
      border-color: rgba(31, 143, 99, 0.18);
    }}
    .badge-warn {{
      background: var(--warn-soft);
      border-color: rgba(196, 100, 60, 0.18);
    }}
    .badge-label {{
      color: var(--muted);
    }}
    .badge-value {{
      font-weight: 700;
      color: var(--text);
    }}
    .filters {{
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 12px;
      margin-top: 18px;
    }}
    .filter {{
      background: rgba(255,255,255,0.9);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 12px;
    }}
    .filter label {{
      display: block;
      font-size: 13px;
      color: var(--muted);
      margin-bottom: 8px;
    }}
    .filter select, .filter input {{
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 10px 12px;
      font-size: 15px;
      background: white;
    }}
    .card {{
      background: rgba(255,255,255,0.94);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 24px;
      box-shadow: 0 16px 40px rgba(24, 52, 92, 0.06);
      margin-top: 18px;
    }}
    .card-header {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
      margin-bottom: 18px;
    }}
    .card-header h2 {{
      margin: 0 0 4px;
      font-size: 28px;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 20px;
      margin-top: 16px;
    }}
    .compact {{
      grid-template-columns: repeat(2, minmax(0, 1fr));
    }}
    section h3 {{
      margin: 0 0 10px;
      font-size: 16px;
    }}
    .instruction {{
      margin-top: 0;
      font-weight: 600;
    }}
    .segments {{
      padding-left: 0;
      list-style: none;
      display: grid;
      gap: 10px;
      margin: 0;
    }}
    .segment {{
      display: flex;
      gap: 10px;
      align-items: flex-start;
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 12px 14px;
      background: #fff;
    }}
    .segment-correct {{
      background: var(--accent-soft);
      border-color: rgba(255, 122, 89, 0.28);
    }}
    .segment-marker {{
      flex: 0 0 auto;
      font-size: 12px;
      line-height: 1;
      padding: 6px 8px;
      border-radius: 999px;
      background: rgba(24, 52, 92, 0.08);
      color: var(--muted);
      font-weight: 700;
    }}
    .segment-correct .segment-marker {{
      background: rgba(255, 122, 89, 0.16);
      color: var(--warn);
    }}
    .tag {{
      display: inline-flex;
      padding: 7px 10px;
      border-radius: 999px;
      background: rgba(24, 52, 92, 0.07);
      color: var(--text);
      font-size: 13px;
      font-weight: 600;
    }}
    details {{
      margin-top: 18px;
      border-top: 1px solid var(--line);
      padding-top: 16px;
    }}
    summary {{
      cursor: pointer;
      font-weight: 700;
    }}
    .hidden {{
      display: none;
    }}
    .review-toolbar {{
      position: sticky;
      top: 12px;
      z-index: 20;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin: 16px 0;
      padding: 14px 16px;
      background: rgba(24, 52, 92, 0.96);
      color: white;
      border-radius: 18px;
      box-shadow: 0 12px 30px rgba(24, 52, 92, 0.18);
    }}
    .decision-summary {{
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      font-weight: 700;
      font-size: 14px;
    }}
    .toolbar-actions {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }}
    .toolbar-button {{
      min-height: 42px;
      padding: 9px 14px;
      border: 1px solid rgba(255,255,255,0.35);
      border-radius: 12px;
      background: white;
      color: var(--text);
      font-weight: 700;
      cursor: pointer;
    }}
    .toolbar-button-secondary {{
      color: white;
      background: transparent;
    }}
    .human-review {{
      margin-top: 20px;
      padding-top: 20px;
      border-top: 2px solid var(--line);
    }}
    .human-review-heading {{
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: flex-start;
    }}
    .human-review-heading h3 {{
      margin-bottom: 2px;
    }}
    .decision-status {{
      flex: 0 0 auto;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(24, 52, 92, 0.08);
      color: var(--muted);
      font-size: 13px;
      font-weight: 700;
    }}
    .decision-buttons {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 10px;
      margin-top: 14px;
    }}
    .decision-button {{
      min-height: 48px;
      border: 1px solid var(--line);
      border-radius: 14px;
      background: white;
      color: var(--text);
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
    }}
    .decision-button.is-selected {{
      border-width: 2px;
      box-shadow: 0 0 0 3px rgba(24, 52, 92, 0.08);
    }}
    .decision-accept.is-selected {{ background: var(--ok-soft); border-color: var(--ok); }}
    .decision-revise.is-selected {{ background: var(--accent-soft); border-color: var(--accent); }}
    .decision-reject.is-selected {{ background: #f2f3f5; border-color: #66707f; }}
    .review-note-label {{
      display: grid;
      gap: 8px;
      margin-top: 14px;
      color: var(--muted);
      font-size: 13px;
      font-weight: 700;
    }}
    .review-note {{
      width: 100%;
      resize: vertical;
      min-height: 78px;
      border: 1px solid var(--line);
      border-radius: 14px;
      padding: 12px 14px;
      color: var(--text);
      background: white;
      font: inherit;
      font-size: 15px;
      line-height: 1.5;
    }}
    .card[data-human-decision="accept"] {{ border-color: rgba(31, 143, 99, 0.5); }}
    .card[data-human-decision="revise"] {{ border-color: rgba(255, 122, 89, 0.65); }}
    .card[data-human-decision="reject"] {{ opacity: 0.78; border-color: #a9afb8; }}
    .card[data-human-decision="accept"] .decision-status {{ background: var(--ok-soft); color: var(--ok); }}
    .card[data-human-decision="revise"] .decision-status {{ background: var(--accent-soft); color: var(--warn); }}
    .card[data-human-decision="reject"] .decision-status {{ background: #eef0f3; color: #59616e; }}
    @media (max-width: 820px) {{
      .filters, .grid, .compact, .card-header {{
        grid-template-columns: 1fr;
        display: grid;
      }}
      .card-header {{
        gap: 12px;
      }}
      h1 {{
        font-size: 28px;
      }}
      .card-header h2 {{
        font-size: 22px;
      }}
      .review-toolbar, .human-review-heading {{
        align-items: stretch;
        flex-direction: column;
      }}
      .decision-buttons {{
        grid-template-columns: 1fr;
      }}
    }}
  </style>
</head>
<body>
  <div class="shell">
    <div class="hero">
      <h1>{html.escape(title)}</h1>
      <p class="muted">生成済みのプレミアム問題を、モード・flavor・レビュー結果つきでまとめて確認できるレビュー画面です。</p>
      <div class="summary-badges">{summary_badges}</div>

      <div class="filters">
        <div class="filter">
          <label for="search">検索</label>
          <input id="search" type="search" placeholder="タイトル・本文で検索">
        </div>
        <div class="filter">
          <label for="mode-filter">モード</label>
          <select id="mode-filter">
            <option value="">すべて</option>
            {mode_options}
          </select>
        </div>
        <div class="filter">
          <label for="flavor-filter">flavor</label>
          <select id="flavor-filter">
            <option value="">すべて</option>
            {flavor_options}
          </select>
        </div>
        <div class="filter">
          <label for="action-filter">レビュー判定</label>
          <select id="action-filter">
            <option value="">すべて</option>
            {action_options}
          </select>
        </div>
        <div class="filter">
          <label for="human-filter">運営の判定</label>
          <select id="human-filter">
            <option value="">すべて</option>
            <option value="pending">未判定</option>
            <option value="accept">採用</option>
            <option value="revise">再生成</option>
            <option value="reject">見送り</option>
          </select>
        </div>
      </div>
    </div>

    <div class="review-toolbar" aria-label="レビュー操作">
      <div class="decision-summary" aria-live="polite">
        <span>未判定 <span id="pending-count">{len(drafts)}</span></span>
        <span>採用 <span id="accept-count">0</span></span>
        <span>再生成 <span id="revise-count">0</span></span>
        <span>見送り <span id="reject-count">0</span></span>
      </div>
      <div class="toolbar-actions">
        <button type="button" id="import-decisions" class="toolbar-button toolbar-button-secondary">判定を読込</button>
        <button type="button" id="export-decisions" class="toolbar-button">判定を保存</button>
        <input id="decision-file" type="file" accept="application/json,.json,.jsonl" hidden>
      </div>
    </div>

    <div id="cards">
      {cards_html}
    </div>
  </div>

  <script id="dashboard-data" type="application/json">{dashboard_data}</script>
  <script>
    const dashboardData = JSON.parse(document.getElementById('dashboard-data').textContent);
    const storageKey = `minukuru-review:${{dashboardData.batchFingerprint}}`;
    const search = document.getElementById('search');
    const modeFilter = document.getElementById('mode-filter');
    const flavorFilter = document.getElementById('flavor-filter');
    const actionFilter = document.getElementById('action-filter');
    const humanFilter = document.getElementById('human-filter');
    const cards = Array.from(document.querySelectorAll('.card'));
    const catalogByDraft = new Map(dashboardData.catalog.map(item => [item.draftId, item]));
    let decisions = {{}};

    function decisionLabel(value) {{
      return {{ accept: '採用', revise: '再生成', reject: '見送り', pending: '未判定' }}[value] || '未判定';
    }}

    function persistDecisions() {{
      localStorage.setItem(storageKey, JSON.stringify(decisions));
    }}

    function updateCard(card) {{
      const saved = decisions[card.dataset.draftId];
      const decision = saved?.decision || 'pending';
      card.dataset.humanDecision = decision;
      card.querySelector('[data-decision-status]').textContent = decisionLabel(decision);
      card.querySelectorAll('[data-decision]').forEach(button => {{
        button.classList.toggle('is-selected', button.dataset.decision === decision);
        button.setAttribute('aria-pressed', String(button.dataset.decision === decision));
      }});
      card.querySelector('.review-note').value = saved?.note || '';
    }}

    function updateCounts() {{
      const counts = {{ pending: 0, accept: 0, revise: 0, reject: 0 }};
      cards.forEach(card => {{ counts[card.dataset.humanDecision] += 1; }});
      Object.entries(counts).forEach(([key, value]) => {{
        document.getElementById(`${{key}}-count`).textContent = String(value);
      }});
    }}

    function saveDecision(card, decision) {{
      const item = catalogByDraft.get(card.dataset.draftId);
      const note = card.querySelector('.review-note').value.trim();
      decisions[card.dataset.draftId] = {{
        draftId: item.draftId,
        generatedQuestionId: item.generatedQuestionId,
        decision,
        note,
        decidedAt: new Date().toISOString()
      }};
      persistDecisions();
      updateCard(card);
      updateCounts();
      applyFilters();
    }}

    function loadSavedDecisions() {{
      try {{
        decisions = JSON.parse(localStorage.getItem(storageKey) || '{{}}');
      }} catch {{
        decisions = {{}};
      }}
      cards.forEach(updateCard);
      updateCounts();
    }}

    function applyFilters() {{
      const q = search.value.trim().toLowerCase();
      const mode = modeFilter.value;
      const flavor = flavorFilter.value;
      const action = actionFilter.value;
      const humanDecision = humanFilter.value;

      for (const card of cards) {{
        const text = card.innerText.toLowerCase();
        const okSearch = !q || text.includes(q);
        const okMode = !mode || card.dataset.mode === mode;
        const okFlavor = !flavor || card.dataset.flavor === flavor;
        const okAction = !action || card.dataset.action === action;
        const okHuman = !humanDecision || card.dataset.humanDecision === humanDecision;
        card.classList.toggle('hidden', !(okSearch && okMode && okFlavor && okAction && okHuman));
      }}
    }}

    cards.forEach(card => {{
      card.querySelectorAll('[data-decision]').forEach(button => {{
        button.addEventListener('click', () => saveDecision(card, button.dataset.decision));
      }});
      card.querySelector('.review-note').addEventListener('change', event => {{
        const saved = decisions[card.dataset.draftId];
        if (!saved) return;
        saved.note = event.target.value.trim();
        saved.decidedAt = new Date().toISOString();
        persistDecisions();
      }});
    }});

    document.getElementById('export-decisions').addEventListener('click', () => {{
      const rows = Object.values(decisions);
      const invalid = rows.find(row => ['revise', 'reject'].includes(row.decision) && !row.note.trim());
      if (invalid) {{
        const card = document.querySelector(`[data-draft-id="${{invalid.draftId}}"]`);
        card?.scrollIntoView({{ behavior: 'smooth', block: 'center' }});
        card?.querySelector('.review-note')?.focus();
        window.alert('再生成・見送りには、次の作業に使える判定メモを入力してください。');
        return;
      }}
      const payload = {{
        schemaVersion: 1,
        batchFingerprint: dashboardData.batchFingerprint,
        exportedAt: new Date().toISOString(),
        decisions: rows.sort((a, b) => a.draftId.localeCompare(b.draftId))
      }};
      const blob = new Blob([JSON.stringify(payload, null, 2) + '\\n'], {{ type: 'application/json' }});
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = 'human_review_decisions.json';
      link.click();
      URL.revokeObjectURL(link.href);
    }});

    document.getElementById('import-decisions').addEventListener('click', () => {{
      document.getElementById('decision-file').click();
    }});
    document.getElementById('decision-file').addEventListener('change', async event => {{
      const file = event.target.files[0];
      if (!file) return;
      try {{
        const payload = JSON.parse(await file.text());
        if (payload.batchFingerprint !== dashboardData.batchFingerprint) {{
          throw new Error('この画面とは別の問題バッチの判定ファイルです。');
        }}
        decisions = Object.fromEntries((payload.decisions || []).map(row => [row.draftId, row]));
        persistDecisions();
        cards.forEach(updateCard);
        updateCounts();
        applyFilters();
      }} catch (error) {{
        window.alert(`判定ファイルを読み込めませんでした。${{error.message || ''}}`);
      }} finally {{
        event.target.value = '';
      }}
    }});

    [search, modeFilter, flavorFilter, actionFilter, humanFilter].forEach(el => {{
      el.addEventListener('input', applyFilters);
      el.addEventListener('change', applyFilters);
    }});
    loadSavedDecisions();
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Minukuru review dashboard HTML")
    parser.add_argument("--drafts", required=True)
    parser.add_argument("--reviews", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--title", default="Minukuru Premium Review Dashboard")
    args = parser.parse_args()

    drafts = read_jsonl(Path(args.drafts))
    reviews = read_jsonl(Path(args.reviews))
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(build_dashboard(drafts, reviews, args.title), encoding="utf-8")
    print(f"Wrote dashboard to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
