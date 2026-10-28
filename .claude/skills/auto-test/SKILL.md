---
name: auto-test
description: Playwright E2E 動作確認の実行ルール（テックプット向け）。「自動テスト」「動作確認して」「Playwright で確認して」「スクショ付きでテスト」「E2E レポート作って」で参照。
user-invocable: true
---

# 動作確認（Playwright E2E）

「動作確認して」「テストして」「テストレポート作って」と言われたら、実際にブラウザを開いて操作し、結果を報告する。要点は `.claude/rules/testing/e2e-playwright.md`。

## プロジェクト設定

| 項目 | 値 |
|---|---|
| フロント | `cd tech-put-app && npm run dev` → `http://localhost:5173` |
| バックエンド | `cd teac-output-new && docker compose up -d`。ホスト側ポートは `docker-compose.yml` の `ports`（2026-10 時点 `127.0.0.1:3013`） |
| API 向き先 | `tech-put-app/.env.development.local` の `VITE_API_URL`（例 `http://localhost:3013/api/v1`）。無ければ `src/lib/api.ts` の既定値 `http://localhost:3000/api/v1` が使われてズレる。ユーザーに直してもらう |
| 受講生ログイン | `/tenant/<tenantId>/users/login`。`test_user0@gmail.com`〜`test_user29@gmail.com` / `password` |
| 管理者ログイン | `/admin/login`。`test_admin@gmail.com` / `password` |
| マネージャーログイン | `/manager/login`。アカウントは `db/seeds.rb` を確認 |
| DB | Adminer `http://localhost:8080`（サーバ `db` / `root` / `password` / `development_db`） |
| ツール | `mcp__playwright__*`（既定）。ログイン済みセッションが要る外部サイトだけ Chrome 拡張 |

seed アカウントはローカル開発 DB 専用。tenantId は Adminer か `rails runner 'puts Tenant.first.id'` で取る。

## 実行フロー

### 1. 対象の確認
- テスト対象の機能・画面、ロール（受講生 / 管理者 / マネージャー）、項目（CRUD / 権限 / 表示 / フロー）
- 受け入れ基準が文書（`docs/e-learning/phases.md` 等）にあればそれを項目にする

### 2. 事前確認

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5173/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3013/api/v1/auth/login   # 405 や 404 でも応答すれば OK
```

テストデータが要るなら `rails runner` か Adminer で事前投入する。本番データは書き換えない。

### 3. 操作
- PC 幅 1440×900 とスマホ幅 375×812 の両方
- 受け入れ基準を 1 項目ずつ操作し、OK / NG / 未確認 を分ける
- 画面ごとに `document.documentElement.scrollWidth` と `clientWidth` を取り、横溢れがあれば数値を記録する（`/layout-defense` §1 ④）
- ダイアログハンドラは 1 回だけ登録。`waitForTimeout` は操作後 500〜2000ms
- エラー時は Console と Network（4xx / 5xx）を読む

### 4. 証跡

```
docs/test_evidence/<機能名>/
  ├── <テストID>_<内容>.png     ← 例: U1_lesson_list_pc.png / U1_lesson_list_sp.png
  ├── results.json
  └── TEST_REPORT.md
```

`docs/` 配下なのでコミットしない。

### 5. TEST_REPORT.md

```markdown
# <機能名> テストレポート

**実施日**: YYYY-MM-DD / **ブランチ**: front <branch> / back <branch>
**環境**: localhost:5173 → localhost:3013 / **ツール**: Playwright (Chromium)

## サマリー
| 結果 | 件数 |
|---|---|
| OK | X |
| NG | Y |
| 未確認 | Z |

## 項目
#### <テストID>: <テスト名> ✅ / ❌ / ⏸
<操作・期待・実際。幅・データ・scrollWidth>
<img src="<png>" width="600">
```

### 6. 失敗時
- 原因を分析し、コードの問題なら implementer に戻す（qa は直さない）
- テスト手順の問題なら直して再実行
- NG は NG と報告する。自動で直して「通った」と言わない

## 注意
- URL・ポートをハードコードしない。`docker-compose.yml` と `.env.development.local` から毎回確認する
- 「見た目を確認した」だけの報告は不可。どの幅で・どのデータで・何が表示されたかを書く
- HTTP 200 を「中身が正しい」の根拠にしない。保存系は再取得して値を見る
- 作成したテストデータは可能な範囲で片付ける
