# 自動テスト（Playwright E2E）スキル

ユーザーが「自動テスト」「E2Eテスト」「テストして」「テストレポート作って」と依頼した際に実行するルール。

---

## プロジェクト設定（プロジェクトごとに書き換える）

| 項目 | 値 |
|---|---|
| **BASE URL** | `http://localhost:<ポート>` ← docker-compose.yml のポートマッピングから決定 |
| **ログインパス** | `/users/sign_in` ← プロジェクトの認証方式に応じて変更 |
| **認証方式** | Devise / 独自認証 など |
| **テストユーザー** | プロジェクトの seed データを確認 |
| **DB** | docker-compose.yml を確認 |

---

## トリガー

以下のキーワードで発動する:
- 「自動テストして」「自動テストお願い」
- 「E2Eテストして」
- 「Playwrightでテストして」
- 「テストしてスクショ撮って」
- 「テストレポート作って」

---

## 実行フロー

### 1. テスト対象の確認

ユーザーに以下を確認する（明確な場合は省略可）:
- テスト対象の機能・画面
- テストユーザー（管理者 / スタッフ / 特定ユーザー）
- テスト項目（CRUD / 権限 / 画面表示 / フロー）

### 2. テストスクリプト作成

**ファイル配置ルール:**

```
test_<機能名>.js                          ← プロジェクトルートに配置
docs/test_evidence/<機能名>/              ← スクショ・レポートの保存先
  ├── *.png                               ← スクリーンショット
  ├── results.json                        ← テスト結果JSON
  └── TEST_REPORT.md                      ← テストレポート
```

**命名規則:**
- スクリプト: `test_<機能名>.js`（例: `test_staff_crud.js`）
- スクショ: `<テストID>_<内容>.png`（例: `F1_menu_index.png`）
- レポート: `TEST_REPORT.md`

### 3. テスト実行

```bash
node test_<機能名>.js
```

- **BASE URL の決定方法**: `docker-compose.yml` のポートマッピングを確認して `http://localhost:<ホスト側ポート>` を設定する。ハードコードしない
- Docker コンテナが起動していることを確認してから実行する
- テスト前にアプリが応答するか `curl -s -o /dev/null -w "%{http_code}" <BASE_URL>` で確認する
- テストデータの準備が必要なら SQL or rails runner で事前投入する

### 4. TEST_REPORT.md 作成

テスト完了後、以下のフォーマットで `docs/test_evidence/<機能名>/TEST_REPORT.md` を作成する:

```markdown
# <機能名> テストレポート

**テスト実施日**: YYYY-MM-DD
**ブランチ**: <current branch>
**環境**: <実行環境（例: Docker localhost:XXXX）>
**テストツール**: Playwright (headless Chromium)

---

## テスト結果サマリー

| 結果 | 件数 |
|------|------|
| 成功 | **X** |
| 失敗 | **Y** |
| 合計 | **Z** |

---

## テスト項目

#### <テストID>: <テスト名> ✅ or ❌
<テスト内容の説明>

<img src="<スクリーンショットファイル名>" width="600">

---
（テスト項目ごとに繰り返し）
```

### 5. 失敗時の対応

- 失敗したテストの原因を分析する
- コードの問題であれば修正する
- テストスクリプトの問題であれば修正して再実行する
- 修正後、再テストして ALL GREEN を目指す

---

## テストスクリプトの構造ルール

```javascript
// 1. 必須インポート
const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// 2. 設定（プロジェクトごとに変更する）
// BASE: docker-compose.yml のポートマッピングから決定
// LOGIN_PATH: プロジェクトの認証方式に応じて変更（Devise, 独自認証など）
const BASE = 'http://localhost:<ポート>';  // docker-compose.yml を確認して設定
const LOGIN_PATH = '/ログインパス';         // 例: /users/sign_in, /login, /admin/login
const OUT_DIR = path.join(__dirname, 'docs', 'test_evidence', '<機能名>');

// 3. ダイアログハンドラは冒頭で1回だけ登録
page.on('dialog', d => d.accept().catch(() => {}));

// 4. 結果記録関数
function record(id, name, ok, note = '') { ... }

// 5. テスト実行（async/await）
// 6. 結果サマリー出力
// 7. results.json 保存
// 8. browser.close()
```

---

## 注意事項

- **URL・パスをハードコードしない**: BASE URL は `docker-compose.yml` のポートマッピングから、ログインパスはプロジェクトの認証方式から毎回確認して設定する
- テストは **headless: true**（GUIなし）で実行する
- viewport は **{ width: 1400, height: 900 }** を標準とする
- `waitForTimeout` は操作後に **500〜2000ms** 入れる
- ダイアログハンドラ（`page.on('dialog', ...)`）は**1回だけ登録**する（重複登録するとクラッシュ）
- テスト後のクリーンアップ（作成したテストデータの削除）は可能な範囲で行う
