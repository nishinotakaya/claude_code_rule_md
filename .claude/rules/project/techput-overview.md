# テックプット 全体像（両リポジトリ共通の事実）

講師（管理者）と受講生のための学習・コミュニティ SaaS。記事（Markdown）・e-learning・つぶやき・動画（YouTube）・コース。多テナント。

## 構成

| 役割 | リポジトリ | 技術 | 起動 |
|---|---|---|---|
| フロント | `tech-put-app`（origin `1107t/tech-put-app`、統合先 `main`） | React 18 / Vite 4 / TypeScript 4.9 / react-router-dom 7 / axios / Bootstrap 5 | `npm run dev` → :5173 |
| バックエンド | `teac-output-new`（origin `nishinotakay/teac-output-new`、統合先 `develop`。e-learning は `feature/React` 系） | Rails 6.1 / Ruby 3.0.3 / MySQL 8 / RSpec / JWT（API）+ Devise（旧 ERB 画面） | `docker compose up -d` → `docker-compose.yml` の ports を見る |

- 2 つのリポジトリは兄弟ディレクトリに置く前提（フロントの `CLAUDE.md` が `../teac-output-new` を参照）
- 両リポジトリとも CI（`.github/workflows`）は無い。フロントは lint もテストランナーも無い。機械検証は人が回す
- `teac-output-new/README.md` の技術スタック（Rails 7 / Ruby 3.3）は実体（Gemfile: Rails 6.1 / `.ruby-version`: 3.0.3）と食い違っている。Gemfile を正とする

## ロールと URL

| ロール | フロントの入口 | API | トークン |
|---|---|---|---|
| 受講生 user | `/tenant/:tenantId/users/login`（ログイン後の画面は `/dashboard` など tenantId なし） | `/api/v1/*`（`auth/login` 等） | `user_token` |
| 管理者 admin | `/admin/login` → `/admin/*` | `/api/v1/admin/*` | `admin_token` |
| マネージャー manager | `/manager/login` → `/manager/*`（テナント管理） | `/api/v1/manager/*` | `manager_token` |

フロントの `src/lib/api.ts` は URL に `/admin/` か `/manager/` を含むかでどのトークンを付けるか決める。**管理者 API は必ず `/admin/` 配下、マネージャー API は `/manager/` 配下に置く。**

## API 契約（既存に合わせる）

- レスポンスのキーは camelCase、`id` は文字列（`record.id.to_s`）、日時は `iso8601`
- 成功: `{ article: {...} }` / `{ articles: [...] }`。作成は 201
- 失敗: 422 `{ errors: [...] }`、403 `{ error: '権限がありません' }`、404 `render_not_found('記事')`、401 `render_unauthorized`
- リクエストは snake_case（フロントが `sub_title` のように変換して送る）
- 一覧の並びは順番カラム・id で固定する。順次解放など全件が要る一覧はページ分割しない
- フロントの型（`src/lib/*Api.ts` の interface）とバックエンドの `*_json` メソッドは常に一致させる。片方だけ変えない

## テナント契約

- 新しいテーブルは `tenant_id` を持ち、`Article` と同じ型で書く: `belongs_to :tenant` / `default_scope { in_current_tenant }` / 作成時に所有者のテナントを入れる
- `Current.tenant` は `Api::V1::BaseController#authenticate!` がログイン主体の `tenant_id` からセットする。URL やパラメータの `tenant_id` を信用しない。manager はテナントに紐付かず `nil`
- マイグレーション・seed・コンソール・rake では `Current.tenant` が `nil` で default_scope は全件を返す。データ移行はテナントを明示して回す
- 別レコードを紐付けるとき（記事にコース、記事にカテゴリー）は、相手が同じテナントかをモデルで検証する
- 受講生 API は「誰の記録か」を JWT の本人から決める。リクエストの `user_id` は使わない

## 変更の順番

バックエンド PR → フロント PR。バックエンド PR は旧フロントのままでも動く変更に限る（フィールドは足すだけ。改名・削除しない）。

## テストアカウント（ローカル seed 専用）

| 種別 | メール | パスワード |
|---|---|---|
| 受講生 | `test_user0@gmail.com`〜`test_user29@gmail.com` | `password` |
| 管理者 | `test_admin@gmail.com` | `password` |
| Adminer | サーバ `db` / ユーザー `root` / DB `development_db` | `password` |

## e-learning

段階実装（Phase 0〜5）の進め方は `/elearning-pm`。進捗の正本はフロント `docs/e-learning/PROGRESS.md`。
