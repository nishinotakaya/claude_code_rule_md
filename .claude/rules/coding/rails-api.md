---
paths:
  - "app/**/*.rb"
  - "config/routes.rb"
  - "lib/**/*.rb"
---

# Rails API の規則（teac-output-new）

## コントローラ

- `Api::V1::BaseController` を継承し、namespace（`Users` / `Admin` / `Manager`）でロールを決める。`before_action :authenticate_<role>!` は namespace の基底に置き、`only:` で抜け穴を作らない
- 取得は `Current.tenant` の default_scope か認証主体の relation 起点（`current_user.learnings.find`）。`unscoped` を書くなら理由をコメントに残し、直後に明示の `where(tenant_id:)`
- 受講生 API は「誰の記録か」を `current_user` から決める。`params[:user_id]` を使わない
- 副作用のある操作は POST / PATCH / DELETE。GET に副作用を持たせない
- `params.permit` で受ける。update は params に無いキーを触らない（`|| 初期値` で merge しない）
- 失敗の返し方は既存に合わせる: 401 `render_unauthorized`、403 `{ error: '権限がありません' }`、404 `render_not_found('記事')`、422 `{ errors: [...] }`。`raise` で 500 にしない
- 表示整形（日付・ラベル・集計）をコントローラに書かない。モデルか `*_json` 用の小さなメソッドへ

## レスポンス（`*_json`）

- キーは camelCase、`id` は `record.id.to_s`、日時は `iso8601`。既存の `user_json` / `admin_json` と同じ流儀
- 包みは `{ article: {...} }` / `{ articles: [...] }`。作成は `status: :created`
- フロントの `src/lib/*Api.ts` の interface と 1 対 1。キーを足すのは互換、改名・削除は非互換（フロント PR とセットで、バックエンドは足すだけにする）
- 一覧は `order(:position, :id)` のように固定ソート。全件が要る一覧（順次解放の判定）はページ分割しない

## モデル

- 新しいテーブルは `tenant_id` を持ち、`Article` と同じ型: `belongs_to :tenant` / `scope :in_current_tenant` / `default_scope { in_current_tenant }` / `before_validation :set_tenant_from_owner`
- 別レコードを紐付ける関連（記事にコース・記事にカテゴリー）は、相手が同じテナントかをバリデーションで検証する
- 論理値は `?`、破壊的・DB を変えるメソッドは `!`。`get_data` ではなく `fetch_active_lessons` / `find_by_email`
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

- `namespace :api { namespace :v1 { namespace :admin ... } }` の配下に置く（`/admin/` `/manager/` がフロントのトークン切替条件）
- `resources` は `only:` で使うアクションだけ。使わないルートを残さない
- 旧 ERB 側のルート（`/users/*` `/admins/*`）を壊さない

## 旧 ERB 画面を触るとき

- ERB に `<script>` `<style>` `style="..."` を書かない。JS は `app/javascript`、CSS は stylesheets へ
- 表示ロジックは helper / decorator へ。view に `Klass.new` や複雑な条件分岐を書かない
- Devise の認証（`authenticate_user!` / `authenticate_admin!`）と API の JWT は別系統。混ぜない

## 命名（`naming.md` の補足）

- `users.each { |u| }` を書かない。`|user|`
- 引数はキーワード引数で意味を持たせる（`call(tenant:, article_id:)`）
- コメントは 1 行。WHAT の言い換えを書かない
