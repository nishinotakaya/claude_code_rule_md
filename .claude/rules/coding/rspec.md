---
paths:
  - "spec/**/*.rb"
---

# RSpec の規則

## 置き場所と形

- API は request spec: `spec/requests/` 配下に API の構成に合わせて置き、既存の spec を型にする
- 認証は既存の認証ヘルパー（例: トークン発行ヘルパーで Bearer ヘッダを作る）を使い、各 spec で再実装しない
- factory_bot で作る。多テナントの場合は factory で tenant を明示し、他テナントのレコードも 1 件作っておく
- 1 example 1 観点。`describe 'POST /api/v1/admin/articles'` → `context '管理者のとき'` → `it '201 と記事を返す'`
- 入力 → 期待値が 1 画面で読める。長い準備は `let` / factory / ヘルパーへ

## 必ず書く観点（API を足したら）

| 観点 | 期待 |
|---|---|
| 未認証（Bearer なし / 期限切れ） | 401 |
| ロール違い（一般ユーザーのトークンで管理者 API 等） | 401 か 403（既存の返し方に合わせる） |
| 他テナントのレコード | 404 **かつ DB 不変**（`reload` して値が変わっていない） |
| 正常系 | ステータス・包み・キー命名・ID の型（`overview.md` の API 契約どおり） |
| バリデーション失敗 | 422 と `errors` 配列 |
| 一覧の並び | 順番カラム・id の順 |
| 一般ユーザーの更新系 | `user_id` を送っても本人の記録だけが変わる |

拒否系だけでなく正常系も 1 本書く（「全部 403」の実装がテストを通らないように）。

## 禁止

- 通すためにアサーションを弱める（`eq` → `be_truthy`）、`skip` / `xit` / `pending` を足す、期待値を実装に合わせる
- プロダクトコードを spec の都合で変える。バグを見つけたら「どのテストがなぜ落ちるか」を報告する
- `sleep` で待つ。`Timecop` / `travel_to` を使う
- テスト間で状態を共有する（database_cleaner の設定を崩さない）

## 実行

```bash
bundle exec rspec                                  # 全体
bundle exec rspec spec/requests/<範囲>              # 範囲
bundle exec rspec --only-failures                  # 直前の失敗だけ
```

- bullet 等で N+1 を test で raise させる設定なら、ここで落ちる
- 失敗したら出力を添えて報告する。フォーマットはプロジェクトの `.rspec` に従い、長いログは `grep -E 'Failure|Error' | head` で絞る
- rubocop-rspec の指摘（`RSpec/ExampleLength` 等）は既存の設定に従う。無視する場合は `.rubocop.yml` に理由を書く
