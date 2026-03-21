# kareki リビルド指示書

> **起票日:** 2026-03-17
> **ユーザー指示原文（抜粋）:**
> 「別ディレクトリで上記のkarekiシステム新しく作ってもらって良い？
> Ruby, Rails のバージョンは最新でサーバーはUbuntuの1番新しいバージョン
> デザインは絶対に変えないでね！
> 処理もリファクタリングはしても良いけど中身は絶対に変えないで、
> かつ、ディレクトリ構想とかもしっかり考えてね。
> 使い方とか考えて、jQueryはTypeScriptに変更で」

---

## 絶対ルール

| ルール | 内容 |
|--------|------|
| **デザイン変更禁止** | Bootstrap 3 グリッド・クラス名・Slim テンプレートの HTML 構造を一切変えない |
| **機能変更禁止** | ビジネスロジック・承認フロー・ステータス遷移を変えない（リファクタリングのみ可） |
| **DB 変更禁止** | MySQL / Oracle / SQL Server の接続設定・テーブル構造を変えない |
| **Sidekiq ジョブ互換** | ジョブのシグネチャ・引数・キュー名を変えない |
| **Oracle 読み取り専用** | `app/models/jtm/` への write 追加禁止 |

---

## 前提・制約

| 項目 | 現状 | 目標 |
|------|------|------|
| Rails | 4.2.4 | 8.x (latest stable) |
| Ruby | ~2.2 | 3.3.x or 3.4.x (latest stable) |
| サーバー OS | — | Ubuntu 24.04 LTS (Noble) |
| JS ツール | Sprockets + jQuery | jsbundling-rails (esbuild) + TypeScript |
| CSS | bootstrap-sass (Bootstrap 3) | Bootstrap 3 維持（yarn add bootstrap@3） |
| DB | MySQL / Oracle / SQL Server | **変更なし** |
| レイアウト | 現行 Slim テンプレート | **変更なし**（外見・操作感を完全に保つ） |
| 検索 | 同期フォームサブミット | 非同期化・高速化（Phase 4） |
| 新プロジェクト場所 | — | `/Users/nishinotakaya/tamahome/kareki/kareki_next` |

---

## ディレクトリ構成方針

```
kareki_next/
├── app/
│   ├── controllers/
│   │   ├── kareki/          # 家歴（現行と同じ名前空間）
│   │   ├── loan/            # 融資管理
│   │   ├── insurance/       # 火災保険
│   │   └── api/             # Webhook
│   ├── models/
│   │   ├── mysql/           # MySQL モデル（zeitwerk collapse で名前空間なし）
│   │   ├── jtm/             # Oracle モデル（読み取り専用・collapse）
│   │   ├── sqlserver/       # SQL Server モデル（collapse）
│   │   └── hash/            # ActiveHash コード値オブジェクト
│   ├── javascript/          # ← NEW（旧 assets/javascripts から移動）
│   │   ├── application.ts   # エントリーポイント
│   │   ├── modules/         # TypeScript 化済みモジュール
│   │   └── legacy/          # 移行前の JS（allowJs: true で共存）
│   ├── services/
│   ├── workers/             # Sidekiq ジョブ（現行と同じ 43 本）
│   ├── views/               # Slim テンプレート（変更なし）
│   ├── mailers/
│   └── decorators/
├── config/
│   ├── database.yml         # MySQL / Oracle / SQL Server 設定（変更なし）
│   ├── environments/
│   ├── initializers/
│   │   └── zeitwerk.rb      # collapse 設定
│   └── settings.yml
├── db/
│   └── migrate/             # MySQL マイグレーション（現行から流用）
├── docs/                    # 概要書・手順書（現行から流用）
├── lib/
│   └── tasks/               # Rake タスク
├── test/
├── Dockerfile               # Ubuntu 24.04 LTS ベース
├── docker-compose.yml
└── .ruby-version            # 3.3.x or 3.4.x
```

---

## フェーズ構成

```
Phase 1: 新規プロジェクト作成 + gem 互換性確認
Phase 2: JS ツール構築（jsbundling/esbuild + TypeScript）
Phase 3: 既存コードの移植（モデル・コントローラ・ビュー）
Phase 4: 検索高速化（Stimulus + Turbo Streams / ransack）
```

---

## Phase 1: 新規プロジェクト作成

### 1-1. バージョン指定

```bash
# Ruby 最新 stable をインストール
rbenv install 3.3.7   # または 3.4.x 最新
cd /Users/nishinotakaya/tamahome/kareki/kareki_next
rbenv local 3.3.7

# Rails 8.x 新規作成
gem install rails -v '~> 8.0'
rails new kareki_next \
  --database=mysql \
  --javascript=esbuild \
  --css=bootstrap \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-solid
```

### 1-2. DB アダプタの互換性確認（最優先）

```ruby
# Gemfile
gem 'ruby-oci8', '>= 2.2.7'
gem 'activerecord-oracle_enhanced-adapter', '~> 7.0'
gem 'composite_primary_keys', '>= 14.0'
gem 'activerecord-sqlserver-adapter', '~> 8.0'
gem 'tiny_tds', '~> 2.1'
gem 'mysql2', '~> 0.5'
```

### 1-3. 旧 gem の置き換え方針

| 旧 gem | 新 gem / 方針 |
|--------|-------------|
| `coffee-rails` | 削除（TypeScript に移行） |
| `uglifier` | 削除（esbuild が minify） |
| `jquery-rails` | `yarn add jquery` |
| `jquery_ujs` | `rails-ujs`（または Turbo で不要に） |
| `kakurenbo-puti` | `discard` gem |
| `refile` / `refile-mini_magick` | `active_storage` + `image_processing` |
| `settingslogic` | `config` gem |
| `draper` | Rails 8 対応版 or presenter クラスを自前実装 |
| `sidekiq ~> 5.2` | `sidekiq ~> 7.x` |
| `sinatra ~> 1.4` | `sinatra ~> 4.x`（Sidekiq Web UI 用） |
| `bootstrap-sass` | `yarn add bootstrap@3` |
| `icheck-rails` | `yarn add icheck` |
| `select2-rails` | `yarn add select2` |
| `kaminari` | 継続 or `pagy`（高速化目的） |
| `chart-js-rails` | `yarn add chart.js` |

### 1-4. zeitwerk オートローダー対応

```ruby
# config/initializers/zeitwerk.rb
Rails.autoloaders.main.collapse(Rails.root.join('app/models/mysql'))
Rails.autoloaders.main.collapse(Rails.root.join('app/models/jtm'))
Rails.autoloaders.main.collapse(Rails.root.join('app/models/sqlserver'))
Rails.autoloaders.main.collapse(Rails.root.join('app/models/hash'))
```

### 1-5. Sidekiq（Solid Queue は使わない）

```ruby
# Gemfile
gem 'sidekiq', '~> 7.0'
```

---

## Phase 2: JS ツール切り替え

### 2-1. TypeScript 設定

```bash
yarn add --dev typescript @types/jquery
npx tsc --init
```

`tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": false,
    "allowJs": true,
    "checkJs": false,
    "outDir": "./app/assets/builds",
    "baseUrl": "./app/javascript"
  },
  "include": ["app/javascript/**/*"],
  "exclude": ["node_modules"]
}
```

### 2-2. エントリーポイント

```typescript
// app/javascript/application.ts
import $ from 'jquery'
import 'bootstrap'

declare global {
  interface Window { $: typeof $; jQuery: typeof $ }
}
window.$ = window.jQuery = $

// 移行前の JS は legacy/ に置いてそのまま動かす
import './legacy/kareki_common'
import './legacy/kareki_filter'
import './legacy/loan_boxes/resend_enable'
```

### 2-3. jQuery → TypeScript 変換対応表

| jQuery | TypeScript (Vanilla) |
|--------|---------------------|
| `$(function() {...})` | `document.addEventListener('DOMContentLoaded', () => {...})` |
| `$('.btn').click(fn)` | `document.querySelector('.btn')?.addEventListener('click', fn)` |
| `$('input').prop('checked', false)` | `(el as HTMLInputElement).checked = false` |
| `$.ajax({...})` | `fetch()` + `async/await` |
| `$('#modal').modal('show')` | Bootstrap JS API |

---

## Phase 3: 既存コードの移植

- コントローラ・モデル・ビュー・ワーカー・メーラーをそのままコピー
- ビジネスロジックは変更しない
- リファクタリングのみ可（変数名・メソッド抽出・N+1 解消など）
- Slim テンプレートは一切変更しない

---

## Phase 4: 検索高速化

### 4-1. DBインデックス追加（即効性あり）

```ruby
add_index :loan_summaries, [:kouji_code, :deleted_at]
add_index :box_insurance_rates, [:eigyousyo_code, :ym]
```

### 4-2. Turbo Streams 非同期検索

```slim
= form_tag search_path, method: :get, data: { turbo_frame: 'search-results' } do
  ...
turbo-frame id="search-results"
  = render 'results', boxes: @boxes
```

### 4-3. ransack 導入

```ruby
gem 'ransack'
```

---

## Docker / Ubuntu 24.04 LTS 構成

```dockerfile
# Dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
  curl git build-essential libssl-dev \
  libmysqlclient-dev libpq-dev \
  ruby3.3 ruby3.3-dev \
  nodejs yarn

WORKDIR /app
COPY . .
RUN bundle install && yarn install
```

```yaml
# docker-compose.yml
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      RAILS_ENV: production
  sidekiq:
    build: .
    command: bundle exec sidekiq
```

---

## 各フェーズの品質ゲート

1. `bin/rails test` 全件 PASS
2. 既存画面とのスクリーンショット比較（レイアウト変化なし）
3. 検索応答時間の計測
4. Oracle / SQL Server 接続確認

---

## 禁止事項

- HTML 構造・Bootstrap クラス名の変更
- ビジネスロジック・ステータス遷移の変更
- Oracle / SQL Server 接続設定の変更
- Sidekiq ジョブのシグネチャ変更
- `app/models/jtm/` への write 追加

---

## 参考リンク

- Rails アップグレードガイド: https://guides.rubyonrails.org/upgrading_ruby_on_rails.html
- jsbundling-rails: https://github.com/rails/jsbundling-rails
- Turbo Handbook: https://turbo.hotwired.dev/handbook/introduction
- Stimulus Handbook: https://stimulus.hotwired.dev/handbook/introduction
- ransack: https://github.com/activerecord-hackery/ransack
