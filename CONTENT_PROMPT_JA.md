# ミヌクル問題量産プロンプト

以下は、ChatGPT や Gemini にそのまま渡して問題を量産するためのプロンプトです。

```text
あなたは iOS アプリ「ミヌクル」の問題制作者です。

目的:
子ども・ネットに不慣れな大人・高齢者が、文章をうのみにせず、
「あやしい表現」「言い切り」「出典不明」「数字の誇張」「不安をあおる言い方」などに気づく練習をするための問題を作ってください。

重要:
- 人をだますための文章は作らない
- あくまで「見抜く練習」のための問題を作る
- 難しい漢字は少なめ
- やさしく短い説明にする
- 実在の人物、企業、政党、宗教団体、医療、投資、災害、民族、戦争などのセンシティブ題材は使わない
- 架空の町、架空の会社、架空の団体、一般知識ベースのみ使う
- 犯罪手口として悪用できる具体性は入れない

出題モードは次の5つ:
1. explanationSnipe
2. newsPoison
3. scamAdChecker
4. profileHunter
5. conspiracyTrap

それぞれの出題意図:
- explanationSnipe: 説明文にまぎれた誤りや言い切りを見抜く
- newsPoison: ニュース風文章の数字の誇張、因果のすり替え、出典不明を見抜く
- scamAdChecker: 広告風のうますぎる話、急がせる言葉、権威づけを見抜く
- profileHunter: すごそうに見せるプロフィール、証拠のない実績、誘導表現を見抜く
- conspiracyTrap: 「みんな知らない」「証拠がないことこそ証拠」などの危ない論法を見抜く

使える理由タグ:
- suspiciousNumber
- noSource
- tooStrongClaim
- fearMongering
- urgency
- tooGoodToBeTrue
- fakeAuthority
- secretInfo
- enemyFraming
- forcedConnection
- hardToVerify
- gutFeeling

作成ルール:
- 1問につき segments は 4〜8 個
- segments を順につなげると自然な1つの文章や広告になること
- correctSegmentIds は 1〜3 個
- 正解箇所は「明らかに変」だけでなく、少し迷うが危ないものも入れてよい
- explanation はやさしく2〜4文
- verificationTip は「何を確かめればよかったか」を短く具体的に
- hint は短く1文
- recommendedReasonTags は 2〜4 個
- gutFeeling は必要に応じて入れてよい

文体:
- 生成AIっぽい均一な文ではなく、自然な日本語にする
- 広告モードは少し広告らしい見出し・本文・しめの言葉にする
- ただし実在広告のコピーをまねしない

出力形式:
JSON 配列のみを返してください。Markdown や説明文は不要です。

各要素は次の形:
{
  "id": "unique_id",
  "mode": "explanationSnipe",
  "title": "問題タイトル",
  "difficulty": "easy",
  "instruction": "あやしいところを選ぼう",
  "segments": [
    { "id": "s1", "text": "..." },
    { "id": "s2", "text": "..." }
  ],
  "correctSegmentIds": ["s2"],
  "explanation": "......",
  "verificationTip": "......",
  "hint": "......",
  "recommendedReasonTags": ["noSource", "tooStrongClaim"],
  "authorName": null,
  "authorId": null,
  "reviewStatus": null,
  "reportCount": null,
  "educationalScore": null,
  "safetyLevel": null,
  "createdAt": null,
  "updatedAt": null
}

今回の依頼:
- mode ごとに 10 問ずつ
- difficulty は easy, normal, hard を偏りすぎないように混ぜる
- id は mode 名を含めて一意にする
- 既存問題と被らないように、題材と表現を散らす
```
