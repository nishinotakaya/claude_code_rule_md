# GitHub への投稿は「指摘の行に pending で入れる」

md にまとめて終わりにしない。指摘は必ず PR の該当行にインラインで、かつ pending（下書き）状態で置く。

- 行に紐づいていない指摘は、著者が「どのコードの話か」を探すところから始まる
- 総括コメント 1 本に全指摘を詰めると、対応済み / 未対応の管理ができない（インラインなら 1 件ずつ resolve できる）
- pending にすれば通知が飛ばない。ユーザーが中身を読んで、出す / 消す / 直すを決めてから submit できる

## 手順

1. 成果物 md を先に書く（`docs/reviews/PR<番号>-レビュー結果.md`）。事実確定はこちらで済ませる
2. 同じ内容を `comments[]` に分解して、1 指摘 = 1 インラインコメントにする
3. 文言を社長（ユーザー）に提示して確認を取る
4. `event` を付けずに POST する ← これだけで pending になる
5. 投稿後、`state` が `PENDING` であることを確認して URL を渡す
6. ユーザーが「投稿して」「そのまま出して」と明示したときだけ submit する

```bash
# comments[] は python で JSON 化する（本文に改行・バッククォート・絵文字が入るため）
python3 build_review.py > review.json

gh api --method POST repos/<owner>/<repo>/pulls/<番号>/reviews \
  --input review.json \
  --jq '{id, state, user: .user.login, html_url}'
# => {"state":"PENDING", ...} を必ず確認する
```

`review.json` の形:

```jsonc
{
  "commit_id": "<PR head の SHA>",   // gh api repos/O/R/pulls/N --jq .head.sha
  "body": "修正点の一覧（1 指摘 = 1 行）と確認結果 1〜2 行",
  "comments": [
    { "path": "src/lib/sort.ts", "line": 39, "side": "RIGHT", "body": "..." },
    { "path": "src/x.tsx", "start_line": 103, "start_side": "RIGHT",
      "line": 112, "side": "RIGHT", "body": "..." }
  ]
  // "event" を書かない。書くと即 submit されて通知が飛ぶ
}
```

| `event` | 結果 |
|---|---|
| 省略 | PENDING（下書き）。通知なし ← 既定 |
| `"COMMENT"` | 即 submit。通知が飛ぶ |
| `"REQUEST_CHANGES"` / `"APPROVE"` | 即 submit。承認状態も変わる |

## 踏み抜きやすい点

- `line` は「PR head 時点のファイル行番号」。position（diff 内オフセット）ではない
- diff のハンク内の行しか指定できない。変更していない行は 422 になる。既存コード（P0-pre）を指したいときは、ハンクに含まれる一番近い行に寄せて本文で「94 行目の〜」と書く。ハンクの範囲は `git diff <base>...<head> -- <file>` の `@@ -a,b +c,d @@` の `c 〜 c+d-1`
- 複数行に付けるなら `start_line` + `line`（両方 `side: "RIGHT"`）
- pending レビューは 1 PR につき 1 本まで。既にあると `user_id can only have one pending review per pull request` で失敗する → `gh api repos/O/R/pulls/N/reviews --jq '.[] | select(.state=="PENDING") | .id'` で確認し、`gh api --method DELETE repos/O/R/pulls/N/reviews/<id>` で消してから出し直す
- pending 中は `line` が `null` で返る（`position` に解決済みの値が入る）。異常ではない
- 本文をシェルの heredoc で組み立てない。必ず `json.dumps` を通す
- `subject_type: "file"` のファイル単位コメントは使わない（「どの行の話か分からない」）

## インラインに貼る本文のルール

- 文言の型は `.claude/rules/git/pull-request.md`（`⚠️ **要約（行番号）**` + 1〜2 文 + Before / After）
- P1 / P2 / P3 のラベルは貼らない。優先度は総評で言葉にする
- 地の文は設計・可読性で 150〜300 字、命名・コメントで 50〜150 字
- 「注意」「安全です」を文言に使わない。Before / After のコードを省かない

## md とインラインの役割分担

| | md（`docs/reviews/`） | インライン（pending） |
|---|---|---|
| 総評・集計行 | ○ | レビュー `body` に入れる |
| 各指摘の本体 | ○ | ○（同じ本文を使い回す） |
| 良い点・動作確認・却下した指摘 | ○ | レビュー `body` に入れる |
| 用途 | 記録・あとから読み返す | 著者が直す場所そのもの |
