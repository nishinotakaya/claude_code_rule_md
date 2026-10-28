---
paths:
  - "app/**/*.rb"
  - "config/routes.rb"
  - "lib/**/*.rb"
---

# Rails API の規則

## コントローラ

- API の基底コントローラ（例: `Api::V1::BaseController`）を継承し、namespace でロールを決める（例: `Users` / `Admin` / `Manager`）。`before_action :authenticate_<role>!` は namespace の基底に置き、`only:` で抜け穴を作らない
- 取得は認証主体の relation 起点（例: `current_user.articles.find`）か、多テナントの場合はテナントの default_scope 起点。`unscoped` を書くなら理由をコメントに残し、直後に明示の `where(tenant_id:)`
- 一般ユーザー向け API は「誰の記録か」を `current_user` から決める。`params[:user_id]` を使わない
- 副作用のある操作は POST / PATCH / DELETE。GET に副作用を持たせない
- `params.permit` で受ける。update は params に無いキーを触らない（`|| 初期値` で merge しない）
- 失敗の返し方は `rules/project/overview.md` の API 契約と既存の共通レンダラに合わせる（401 / 403 / 404 / 422）。`raise` で 500 にしない
- 表示整形（日付・ラベル・集計）をコントローラに書かない。モデルかレスポンス整形用の小さなメソッドへ

## レスポンス

- キー命名・ID の型・日時形式・包みは `rules/project/overview.md` の API 契約と既存のレスポンス整形に合わせる（例: camelCase・`id.to_s`・`iso8601`・`{ article: {...} }`）。作成は `status: :created`
- フロントの型と 1 対 1。キーを足すのは互換、改名・削除は非互換（フロント PR とセットで、バックエンドは足すだけにする）
- 一覧は `order(:position, :id)` のように固定ソート。全件が要る一覧（順次解放の判定）はページ分割しない

## モデル

- 多テナントの場合: 新しいテーブルは `tenant_id` を持ち、既存の tenant 付きモデルと同じ型で書く（`belongs_to :tenant` / テナントの default_scope / 作成時に所有者のテナントを入れる）
- 別レコードを紐付ける関連は、相手が同じテナントかをバリデーションで検証する
- 論理値は `?`、破壊的・DB を変えるメソッドは `!`。`get_data` ではなく `fetch_active_records` / `find_by_email`
- コールバックで外部通知・メール・別テーブルの更新をしない（サービスか明示呼び出しへ）
- N+1 は `includes` / `preload`。bullet が test で raise するので rspec を回せば分かる

## クエリ

```ruby
# ❌ SQL injection
Article.where("title LIKE '%#{params[:keyword]}%'")

# ✅ プレースホルダ + sanitize_sql_like
Article.where('title LIKE ?', "%#{Article.sanitize_sql_like(params[:keyword])}%")
```

- 複数テーブルの更新は 1 つの `transaction` に入れる
- `update_all` / `delete_all` はスコープが default_scope 内か確認し、紐付け / 解除の両方向を対称に書く
- 不要な `to_a` で全件メモリ展開しない

## ルーティング

- ロール別の namespace 配下に置く（URL 接頭辞とフロントのトークン切替の対応は `overview.md`）
- `resources` は `only:` で使うアクションだけ。使わないルートを残さない
- 同じモデルを使う別の入口（旧画面・別 API）のルートを壊さない

## 旧画面（ERB）を触るとき

- ERB に `<script>` `<style>` `style="..."` を書かない。JS は `app/javascript`、CSS は stylesheets へ
- 表示ロジックは helper / decorator へ。view に `Klass.new` や複雑な条件分岐を書かない
- 旧画面のセッション認証と API のトークン認証が別系統なら混ぜない

## 命名（`naming.md` の補足）

- `users.each { |u| }` を書かない。`|user|`
- 引数はキーワード引数で意味を持たせる（`call(account:, article_id:)`）
- コメントは 1 行。WHAT の言い換えを書かない
