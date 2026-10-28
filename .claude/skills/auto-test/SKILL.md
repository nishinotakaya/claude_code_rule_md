---
name: auto-test
description: Playwright E2E 動作確認の実行ルール。「自動テスト」「動作確認して」「Playwright で確認して」「スクショ付きでテスト」「E2E レポート作って」で参照。
user-invocable: true
---

# 動作確認（Playwright E2E）

「動作確認して」「テストして」「テストレポート作って」と言われたら、実際にブラウザを開いて操作し、結果を報告する。要点は `.claude/rules/testing/e2e-playwright.md`。

## プロジェクト設定

| 項目 | 値 |
|---|---|
| 起動 URL（フロント・バックエンド） | `.claude/rules/project/overview.md` の構成表 |
| API 向き先 | フロントの環境変数ファイル。ずれていたらユーザーに直してもらう |
| ログイン URL・テストアカウント | `overview.md` のロールと URL、seed ファイルの場所 |
| ツール | `mcp__playwright__*`（既定）。ログイン済みセッションが要る外部サイトだけ Chrome 拡張 |

seed アカウントはローカル開発 DB 専用。

## 実行フロー

### 1. 対象の確認
- テスト対象の機能・画面、ロール（`overview.md` のロール一覧）、項目（CRUD / 権限 / 表示 / フロー）
- 受け入れ基準が文書（仕様書・Issue 等）にあればそれを項目にする

### 2. 事前確認

```bash
curl -s -o /dev/null -w "%{http_code}\n" <フロントの起動 URL>
curl -s -o /dev/null -w "%{http_code}\n" <API のログイン URL>   # 405 や 404 でも応答すれば OK
```

テストデータが要るなら `rails runner` か DB 管理ツール で事前投入する。本番データは書き換えない。

### 3. 操作
- PC 幅 1440×900 とスマホ幅 375×812 の両方
- 受け入れ基準を 1 項目ずつ操作し、OK / NG / 未確認 を分ける
- 画面ごとに `document.documentElement.scrollWidth` と `clientWidth` を取り、横溢れがあれば数値を記録する（`/layout-defense` §1 ④）
- ダイアログハンドラは 1 回だけ登録。`waitForTimeout` は操作後 500〜2000ms
- エラー時は Console と Network（4xx / 5xx）を読む

### 4. 証跡

```
docs/test_evidence/<機能名>/
  ├── <テストID>_<内容>.png     ← 例: U1_item_list_pc.png / U1_item_list_sp.png
  ├── results.json
  └── TEST_REPORT.md
```

`docs/` 配下なのでコミットしない。

### 5. TEST_REPORT.md

```markdown
# <機能名> テストレポート

**実施日**: YYYY-MM-DD / **ブランチ**: front <branch> / back <branch>
**環境**: <フロントの URL> → <API の URL>（`overview.md`） / **ツール**: Playwright (Chromium)

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
