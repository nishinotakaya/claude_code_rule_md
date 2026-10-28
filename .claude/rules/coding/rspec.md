---
paths:
  - "spec/**/*.rb"
---

# RSpec の規則（teac-output-new）

## 置き場所と形

- API は request spec: `spec/requests/api/v1/{users,admin,manager}/<resource>_spec.rb`。`spec/requests/api/v1/admin/user_articles_spec.rb` を型にする
- 認証は `JwtHelper.encode(id:, role:)` で Bearer ヘッダを作る。ヘルパーがあればそれを使い、各 spec で再実装しない
- factory_bot で作る。`tenant` を持つモデルは factory で tenant を明示し、他テナントのレコードも 1 件作っておく
- 1 example 1 観点。`describe 'POST /api/v1/admin/courses'` → `context '管理者のとき'` → `it '201 とコースを返す'`
- 入力 → 期待値が 1 画面で読める。長い準備は `let` / factory / ヘルパーへ

## 必ず書く観点（API を足したら）

| 観点 | 期待 |
|---|---|
| 未認証（Bearer なし / 期限切れ） | 401 |
| ロール違い（user トークンで admin API 等） | 401 か 403（既存の返し方に合わせる） |
| 他テナントのレコード | 404 **かつ DB 不変**（`reload` して値が変わっていない） |
| 正常系 | ステータス・包み（`{ articles: [] }`）・キーが camelCase・`id` が文字列 |
| バリデーション失敗 | 422 と `errors` 配列 |
| 一覧の並び | 順番カラム・id の順 |
| 受講生の更新系 | `user_id` を送っても本人の記録だけが変わる |

拒否系だけでなく正常系も 1 本書く（「全部 403」の実装がテストを通らないように）。

## 禁止

- 通すためにアサーションを弱める（`eq` → `be_truthy`）、`skip` / `xit` / `pending` を足す、期待値を実装に合わせる
- プロダクトコードを spec の都合で変える。バグを見つけたら「どのテストがなぜ落ちるか」を報告する
- `sleep` で待つ。`Timecop` / `travel_to` を使う
- テスト間で状態を共有する（database_cleaner の設定を崩さない）

## 実行

```bash
bundle exec rspec                                  # 全体
bundle exec rspec spec/requests/api/v1/admin       # 範囲
bundle exec rspec --only-failures                  # 直前の失敗だけ
```

- bullet が test で raise するので、N+1 があればここで落ちる
- 失敗したら出力を添えて報告する。`--format documentation` のまま読み、長いログは `grep -E 'Failure|Error' | head` で絞る
- rubocop-rspec の指摘（`RSpec/ExampleLength` 等）は既存の設定に従う。無視する場合は `.rubocop.yml` に理由を書く
