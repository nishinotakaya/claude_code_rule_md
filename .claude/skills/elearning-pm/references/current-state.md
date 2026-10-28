# e-learning 現状（2026-09-30 実コード確認）

フェーズ着手前に、触る行だけ実コードと突き合わせる。食い違ったら実コードを正とし、このファイルを直してから進める。

確認時のブランチ: フロント `feature/user-videos` / バックエンド `feature/React`

## バックエンド `teac-output-new`（Rails 6.1 / Ruby 3.0.3 / MySQL / RSpec）

| 対象 | 場所 | 現状 |
|---|---|---|
| e-learning 掲載の有無 | `articles.article_type`（string, null 可） | `'e-learning'` なら掲載。旧 ERB フォームの選択肢は `e-learning` / `normal`。値の検証なし。管理者が作成・更新するときだけ presence 必須 |
| 完了記録 | `learnings`（`learner_id`, `admin_id`, `learned_article_id`, `completed`） | `tenant_id` なし・一意制約なし・外部キーなし・カラムは integer。`User#learning_status` / `Admin#learning_status` / `completed?(article)` |
| 記事→完了記録の関連 | `app/models/article.rb` の `has_many :learnings` | 外部キー未指定のため `article_id` を探しに行くが、カラムは `learned_article_id`。**呼ぶと落ちる**。`dependent` も無く、記事を消すと完了記録が孤児になる |
| 受講生 API | `app/controllers/api/v1/users/learnings_controller.rb` | `GET /api/v1/learnings`（自分の完了記録）, `POST /api/v1/learnings`（`article_id`, `completed`）。**e-learning 以外の記事にも完了を付けられる** |
| 管理者 API | `app/controllers/api/v1/admin/learnings_controller.rb` | `GET /api/v1/admin/learnings` は `Learning` 全件（テナントで絞られていない）, `POST` は管理者自身の完了記録 |
| 記事 API（受講生） | `app/controllers/api/v1/users/articles_controller.rb` | `article_params` が `article_type` を permit。**受講生が e-learning 記事を作れる**。index は e-learning 記事も混ぜて全件返す |
| 記事 API（管理者） | `app/controllers/api/v1/admin/articles_controller.rb` | CRUD あり。`article_type` を受け取り `articleType` で返す。index は全件・絞り込みなし |
| テナント分離 | `app/models/article.rb`, `tweet.rb`, `user.rb`, `admin.rb`, `current.rb` | `belongs_to :tenant` + `default_scope { in_current_tenant }` + `before_validation :set_tenant_from_owner`。`Current.tenant` は `Api::V1::BaseController#authenticate!` がセット |
| コース・カテゴリー | — | テーブル・モデル・API とも存在しない（`folders` は受講生個人の記事整理用で別物） |
| 旧 ERB 画面 | `app/controllers/{users,admins}/learnings_controller.rb`, `app/views/users/learnings/index.html.erb` | **順次解放**: 1 件目、または直前の記事が完了済みのときだけ「記事を読む」が押せる。10 件ページネーション |
| テスト | `spec/requests/api/v1/` | `auth/`, `admin/users`, `admin/user_articles`, `admin/user_posts` のみ。learnings・articles の API spec は無い。factory は `articles` `learnings` `tenants` あり |
| seed | `db/seeds.rb` | `article_type: 'e-learning'` の記事 5 件（admin_id 1） |

起動: `docker compose up -d`（サービス名 `app`, コンテナ名 `docker-rails-service`）。
ホスト側ポートは `docker-compose.yml` の `ports` を正とする（確認時 `3013:3000`。`tech-put-app/CLAUDE.md` の 3001 は古い）。
フロントの向き先は `VITE_API_URL`（`.env.local` は読まない。ずれていたらユーザーに直してもらう）。

## フロント `tech-put-app`（React 18 / Vite / TypeScript / Bootstrap 5 / axios）

| 対象 | 場所 | 現状 |
|---|---|---|
| 受講生 e-learning 一覧 | `src/pages/users/DashboardPage.tsx`（`/dashboard`） | レッスン 4 件をハードコード。API 未接続。`category` は文字列の飾り |
| レッスン詳細 | — | 「記事を見る」が `/lessons/:id` へ飛ぶが `src/Routes.tsx` に定義が無く 404 |
| 管理者の記事フォーム | `src/pages/admins/article/New.tsx`, `Edit.tsx` | `articleType` を state に持ち既定 `"e-learning"`。**選ぶ UI が無い**ので管理者記事は必ず e-learning になる |
| 管理者 e-learning | `src/components/admin/AdminSidebar.tsx` → `/admin/dashboard` | `AdminDashboardPage.tsx` は「ログイン成功！」の仮画面 |
| API クライアント | `src/lib/api.ts`, `adminApi.ts`, `articleApi.ts` | URL に `/admin/` を含むと管理者トークン、それ以外は受講生トークン。learnings・courses・categories のクライアント関数は無い。`Article` 型に `articleType` が無い |
| 共通部品 | `src/components/user/UserLayout.tsx`, `MarkdownView.tsx`, `ArticleEditor.tsx`, `src/components/admin/AdminLayout.tsx`, `PageSpinner.tsx`, `PageError.tsx`, `src/lib/useRequireAdmin.ts` | 新画面はこれらを使う。新しいレイアウトを作らない |
| テスト | `package.json` | **テストランナー無し**（scripts は dev / build / preview のみ）。機械検証は `npm run build`（tsc）と Playwright |

## API の書き方（既存に合わせる）

- レスポンスのキーは camelCase、id は文字列（`article.id.to_s`）、日時は `iso8601`
- 成功: `{ article: {...} }` / `{ articles: [...] }`。作成は 201
- 失敗: 422 `{ errors: [..] }`、403 `{ error: '権限がありません' }`、404 `render_not_found('記事')`、401 `render_unauthorized`
- リクエストは snake_case（フロントが `sub_title` のように変換して送る）
- request spec は `JwtHelper.encode(id:, role:)` で `Authorization: Bearer` を組む（`spec/requests/api/v1/admin/user_articles_spec.rb` が手本）
