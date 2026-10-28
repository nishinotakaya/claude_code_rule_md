---
paths:
  - "db/migrate/**"
  - "db/schema.rb"
  - "db/seeds.rb"
---

# マイグレーションと seed の規則（teac-output-new）

## 書く前に

- 本番データへの影響（行数・ロック・デフォルト値の埋め方）を 1 行で書く
- 旧フロント・旧 ERB 画面が動き続けるか（カラムの改名・削除は非互換。足すだけにし、削除は別 PR で）
- `db:migrate` → `db:rollback` → `db:migrate` がローカルで通ることを確認してから PR に入れる

## 規則

- 新しいテーブルには `tenant_id`（`references :tenant, null: false, foreign_key: true, index`）。`Article` のテーブルと同じ形
- 外部キーには index。複合ユニーク（例: `[:course_id, :article_id]`）はテーブル定義で
- `NOT NULL` を既存テーブルに後付けするときは、デフォルト値かバックフィルを先に入れ、別マイグレーションで制約を足す
- `change` で戻せないものは `up` / `down` を書く
- データ移行をマイグレーションに混ぜない。要るなら rake タスクにして、**テナントを明示して回す**（マイグレーション中は `Current.tenant` が nil で default_scope が全件を返す）
- `db/schema.rb` は手で編集しない。生成結果をそのままコミットする（差分が意図した範囲だけか見る）
- 禁止: `db:drop` / `db:reset` / `db:schema:load`（開発 DB でも消えるデータがある。`.claude/hooks/guard-bash.sh` がブロックする）

## seed

- `db/seeds.rb` はローカル開発用。`test_user0@gmail.com`〜 / `test_admin@gmail.com` / `password` などのアカウントは本番に入れない
- seed にテナントを増やすときは、他テナントのデータが混ざらないよう `Current.tenant` をセットするか `tenant:` を明示する
- 冪等に書く（`find_or_create_by!`）。何度流しても同じ状態になる

## PR に書くこと

- マイグレーションの目的・影響行数・ロールバック手順
- 旧フロントで動作確認したか（フィールドを足しただけなら「影響なし」の根拠）
