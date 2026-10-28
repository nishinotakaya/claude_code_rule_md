# teac-output-new（バックエンド）の事実

> 実コードと食い違ったら実コードを正とし、このファイルを直す。共通の事実（ロール・API 契約・テナント契約・テストアカウント）は `techput-overview.md`。

## 技術と検証

| 項目 | 値 |
|---|---|
| ランタイム | Rails 6.1.3 / Ruby 3.0.3（`.ruby-version`）/ MySQL 8 / Puma。**README の Rails 7.0.8 / Ruby 3.3 は実体と違う。Gemfile を正とする** |
| 2 つの顔 | `api/v1`（JSON API。React フロントが使う）と、旧 ERB 画面（webpacker + Devise。`/users/*` `/admins/*`）。旧画面を 500 にしない |
| 認証（API） | JWT HS256・24h・秘密は `ENV['SECRET_KEY_BASE']`（`JwtHelper`）。`Api::V1::BaseController < ActionController::API` に `authenticate!` / `authenticate_user!` / `authenticate_admin!` / `authenticate_manager!` |
| 共通レンダラ | `render_unauthorized`（401 `{error:'認証が必要です'}`）/ `render_not_found(resource)`（404）/ `render_bad_request` / `user_json` `admin_json` `manager_json` |
| テスト | RSpec（`spec/requests/api/v1/{admin,auth,manager,users}`）、factory_bot、faker、database_cleaner、simplecov。`.rspec` は `--format documentation` |
| 静的検査 | rubocop + rubocop-rspec（`NewCops: enable`、日本語コメント可）、brakeman、bullet（test で raise） |
| CI | **無い**。`bundle exec rspec` / `rubocop` / `brakeman -q --no-pager` / `bundler-audit check --update` を PR 前に自分で回す |

## Docker

| サービス | ホスト側 | 備考 |
|---|---|---|
| app | `127.0.0.1:3013` → 3000 | 3000 / 3001 は他アプリが使うため避けている（`docker-compose.yml` のコメント） |
| db（MySQL 8） | `3312` → 3306 | `DB_NAME` をブランチごとに env で切り替えられる |
| adminer | `127.0.0.1:8080` | サーバ `db` / `root` / `password` / `development_db` |
| webpacker | 3035 | 旧 ERB 画面用 |

env は `.env` + `dev.env`（git 管理外）。変数を足したら `.env.example` に名前だけ。

## テナント（`feature/React` 系のブランチ）

- `Current`（ActiveSupport::CurrentAttributes）の `tenant` を `Api::V1::BaseController#authenticate!` が `@current_user&.tenant || @current_admin&.tenant` でセットする。manager は nil
- モデルは `belongs_to :tenant` / `scope :in_current_tenant` / `default_scope { in_current_tenant }` / `before_validation :set_tenant_from_owner`（`Article` が型）
- **`origin/develop` にはテナントのコードが無い**（`feature/React` と分岐している）。どちらをベースにするかは `PROGRESS.md` で確認し、両方に跨る変更は先に方針を決める
- `develop` の `Users::ArticlesController#index` は `Article.order(...)` の素呼び、`set_article` は `Article.find_by`。テナント default_scope が無いブランチでは全テナントが見える前提で読む

## API 契約（`techput-overview.md` の補足）

- コントローラは `Api::V1::{Users,Admin,Manager}::*`。namespace でロールが決まる（`/admin/` `/manager/` はフロントのトークン切替条件）
- `params.permit` で受け、snake_case。レスポンスは `*_json` メソッドで camelCase・`id.to_s`・`iso8601` に整える
- 失敗: 422 `{ errors: record.errors.full_messages }`、403 `{ error: '権限がありません' }`、404 `render_not_found('記事')`
- 作成は 201。一覧は順番カラム・id で固定ソート

## CORS（`config/initializers/cors.rb`）

development は `localhost` の正規表現、production は `ENV['FRONTEND_ORIGIN']` の完全一致、`credentials: false`。`*` と部分一致を増やさない。

## デプロイ

`heroku.yml`（JawsDB）がある。本番 DB に触る操作（`db:migrate` 以外）は実行前に影響を文章化して承認を取る。`db:drop` / `db:reset` / `db:schema:load` は禁止。

## git

- origin `nishinotakay/teac-output-new`、統合先 `develop`。e-learning は `PROGRESS.md` 先頭のベース（`origin/feature/React`）
- 作業ブランチの prefix は既存の多数派 `fix/` と `feat/`（`feature/` も残っているが新規では使わない）
- `.claude/` `CLAUDE.md` はコミットしない。ルール一式は `install.sh` で配備
- フロントと対になる変更はバックエンド PR を先に出し、旧フロントのままでも動く変更に限る（フィールドは足すだけ。改名・削除しない）
