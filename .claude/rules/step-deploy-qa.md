# Step 8-9: Merge（マージ）・Deploy & QA（デプロイ・品質保証）

## Step 8. Merge — develop → main へマージ

全チェック通過後、worktree ブランチを develop にマージし、続けて main にマージする。

```bash
# worktree → develop
git checkout develop
git merge --no-ff <worktree-branch> -m "Merge <worktree-branch>: <変更の要約>"

# develop → main
git checkout main
git merge --no-ff develop -m "Release: <リリース内容の要約>"
git push origin main
git checkout develop         # 作業ブランチに戻る
```

マージ後、worktree ブランチは自動クリーンアップされる（Task ツールの仕様）。
手動で残っている場合は `git branch -d <branch>` で削除する。

## Step 9. Deploy & QA — デプロイ + 本番QA + エビデンス保存 + 完了報告

main へのマージ後、デプロイ → ヘルスチェック → DRBFM分析 → QAテスト → エビデンス保存 → 完了報告を一連で実施する。

```
9.1 Deploy        ← PM: デプロイ実行
9.2 Health Check  ← PM: ビルドログ・ヘルスチェック確認
9.3 DRBFM + Prep  ← QAエージェント: 変更点分析 → 心配点洗い出し → テストシナリオ導出 + qa-scenarios.yml の smoke シナリオ選定
9.4 QA Execute    ← QAエージェント: DRBFM由来 + 既存シナリオのE2Eテスト + スクリーンショット取得
9.5 Evidence Store← QAエージェント: Firebase Storage + Firestore に保存（DRBFM分析YAMLを含む）
9.6 QA Report     ← QAエージェント → PM: DRBFM分析結果 + テスト結果レポート返却
9.7 Notify        ← PM: LINE Bot で完了報告 or 失敗通知
```

### 9.1 Deploy — デプロイ実行

プロジェクトのデプロイルール（`/deploy-rules` 等）に従い、デプロイを実行する。

### 9.2 Health Check — ヘルスチェック

デプロイ完了後、PM が以下を確認する:

1. ビルドログにエラーがないこと
2. デプロイステータスが正常であること
3. ヘルスチェックエンドポイント（あれば）が応答すること

失敗した場合はデプロイをロールバックし、ユーザーに報告する。

### 9.3 DRBFM + QA Prep — 変更点分析 + テストシナリオ準備

PM がQAエージェントを Task ツールで起動する。QAエージェントは以下を実施する:

1. **DRBFM変更点分析**: `/DRBFM` スキルに従い、git diff から変更点・変化点を抽出し、影響分析マトリクスで心配点を洗い出す
2. **テストシナリオ導出**: 心配点から追加テストシナリオを導出する（DRBFM由来シナリオ）
3. **既存シナリオ選定**: `qa-scenarios.yml` から smoke シナリオ（全デプロイ必須）+ 変更関連の feature シナリオを選定

**既存シナリオの選定基準:**

| カテゴリ | 実行タイミング |
|---------|--------------|
| `smoke` | **全デプロイで必須** |
| `feature` | 変更に関連するシナリオを選定 |
| `regression` | PM 判断（大規模変更・リスクが高い場合） |

### 9.4–9.6 QA Execute / Evidence Store / QA Report

**QAエージェント起動プロンプトテンプレート:**

```
デプロイ後のDRBFM分析 + QAテストを実施してください。

## 前提
まず /DRBFM スキルファイルを読み込んでください:
Read <WORKING_DIR>/

## プロジェクト情報
- プロジェクト名: <project_name>
- 本番URL: <base_url>
- ベースコミット (前回デプロイ): <base_commit>
- デプロイコミット: <deploy_commit>
- デプロイ内容の要約: <deploy_summary>

## Phase 1: DRBFM変更点分析
/DRBFM の「QAエージェントのDRBFM実施プロセス」に従い実施:
1. git diff <base_commit>..<deploy_commit> で変更点・変化点を抽出
2. 影響分析マトリクスを作成
3. 心配点を洗い出し（分析フィルタ6項目を全適用）
4. 心配点からテストシナリオを導出
5. DRBFM分析シート（YAML）を作成

## Phase 2: テスト実行
以下のテストを順次実行:
A. DRBFM由来のテストシナリオ（Phase 1 で導出）
B. 既存テストシナリオ（下記参照）

<qa-scenarios.yml から選定したシナリオをYAML形式で貼付>

各テスト項目ごとに:
1. chrome-devtools MCP でページ遷移・操作を実行
2. 期待結果を確認
3. スクリーンショットを取得 (mcp__chrome-devtools__take_screenshot)
4. pass / fail を判定
5. Firebase Storage にスクリーンショットをアップロード
6. Firestore にテスト結果を記録

## Phase 3: エビデンス保存
- DRBFM分析シート（YAML）を Firebase Storage に保存
- テスト結果を Firestore に保存（drbfm_analysis フィールドを含む）

## Firebase 設定
- GCP プロジェクト: gen-lang-client-0181310850
- Storage バケット: gen-lang-client-0181310850-qa-evidence
- Storage パス: qa-evidence/<project_name>/<YYYY-MM-DD>/<test_run_id>/<order>-<scenario_id>.png
- DRBFM分析パス: qa-evidence/<project_name>/<YYYY-MM-DD>/<test_run_id>/drbfm-analysis.yml
- Firestore コレクション: qa_test_runs

## 出力形式
テスト完了後、以下のレポートを返却:

### DRBFM分析サマリー
- 変更点数 / 心配点数 / 高リスク心配点数
- 導出テストシナリオ数
- 主要な心配点と推奨対応の一覧

### テスト結果サマリー
- テストラン ID
- 総件数 / 合格数 / 失敗数
- 各テスト項目の結果一覧 (scenario_id, name, status, screenshot_url, source: drbfm|existing)
- 失敗項目の詳細 (expected vs actual)
```

### QAシナリオ定義ファイル（qa-scenarios.yml）

各プロジェクトルートに `qa-scenarios.yml` を配置する。

```yaml
project: OnclassRAG
base_url: https://onclass-rag.onrender.com

scenarios:
  - id: top-page-access
    name: トップページ表示確認
    category: smoke  # smoke | feature | regression
    steps:
      - action: navigate
        url: "{{base_url}}"
      - action: wait_for
        selector: "main"
      - action: screenshot
    expected: "main 要素が表示されていること"

  - id: login-flow
    name: ログインフロー確認
    category: smoke
    steps:
      - action: navigate
        url: "{{base_url}}/login"
      - action: wait_for
        selector: "form"
      - action: fill
        selector: "#email"
        value: "test@example.com"
      - action: fill
        selector: "#password"
        value: "{{env.TEST_PASSWORD}}"
      - action: click
        selector: "button[type='submit']"
      - action: wait_for
        selector: "[data-testid='dashboard']"
      - action: screenshot
    expected: "ダッシュボードが表示されていること"
```

**カテゴリ定義:**
- `smoke`: 基本的な疎通確認。全デプロイで必ず実行
- `feature`: 特定機能の動作確認。変更に関連するシナリオを選定して実行
- `regression`: 回帰テスト。PM判断で大規模変更時に実行

### Firebase データモデル

**Firestore コレクション設計:**

```
qa_test_runs/{test_run_id}
  ├── project: string
  ├── environment: "production"
  ├── deploy_commit: string
  ├── deploy_summary: string
  ├── started_at: timestamp
  ├── completed_at: timestamp
  ├── total_count: number
  ├── pass_count: number
  ├── fail_count: number
  ├── status: "pass" | "fail"
  │
  └── results/{result_id}          # サブコレクション
        ├── order: number
        ├── scenario_id: string
        ├── scenario_name: string
        ├── category: string
        ├── status: "pass" | "fail" | "error"
        ├── expected: string
        ├── actual: string
        ├── screenshot_url: string
        ├── screenshot_path: string
        └── executed_at: timestamp
```

**Firebase Storage パス設計:**

```
qa-evidence/{project_name}/{YYYY-MM-DD}/{test_run_id}/{order}-{scenario_id}.png
```

バケット: `gen-lang-client-0181310850-qa-evidence` (asia-northeast1)

### Firebase 操作コードスニペット（QAエージェント用）

**Firebase Admin SDK 初期化（ADC認証）:**

```typescript
import { initializeApp, applicationDefault } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import { getStorage } from 'firebase-admin/storage'

const app = initializeApp({
  credential: applicationDefault(),
  storageBucket: 'gen-lang-client-0181310850-qa-evidence',
})

const db = getFirestore(app)
const bucket = getStorage(app).bucket()
```

**Storage: スクリーンショットアップロード + 署名付きURL生成:**

```typescript
import * as fs from 'fs'

async function uploadScreenshot(
  localPath: string,
  storagePath: string
): Promise<{ url: string; path: string }> {
  const file = bucket.file(storagePath)
  await file.save(fs.readFileSync(localPath), {
    contentType: 'image/png',
    metadata: { cacheControl: 'public, max-age=31536000' },
  })

  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + 365 * 24 * 60 * 60 * 1000,
  })

  return { url, path: storagePath }
}
```

**Firestore: テストラン・結果ドキュメント作成:**

```typescript
import { FieldValue } from 'firebase-admin/firestore'

async function createTestRun(params: {
  testRunId: string
  project: string
  deployCommit: string
  deploySummary: string
}) {
  await db.collection('qa_test_runs').doc(params.testRunId).set({
    project: params.project,
    environment: 'production',
    deploy_commit: params.deployCommit,
    deploy_summary: params.deploySummary,
    started_at: FieldValue.serverTimestamp(),
    completed_at: null,
    total_count: 0,
    pass_count: 0,
    fail_count: 0,
    status: 'pending',
  })
}

async function addTestResult(testRunId: string, result: {
  order: number
  scenarioId: string
  scenarioName: string
  category: string
  status: 'pass' | 'fail' | 'error'
  expected: string
  actual: string
  screenshotUrl: string
  screenshotPath: string
}) {
  await db
    .collection('qa_test_runs')
    .doc(testRunId)
    .collection('results')
    .add({
      order: result.order,
      scenario_id: result.scenarioId,
      scenario_name: result.scenarioName,
      category: result.category,
      status: result.status,
      expected: result.expected,
      actual: result.actual,
      screenshot_url: result.screenshotUrl,
      screenshot_path: result.screenshotPath,
      executed_at: FieldValue.serverTimestamp(),
    })
}

async function completeTestRun(testRunId: string, counts: {
  total: number
  pass: number
  fail: number
}) {
  await db.collection('qa_test_runs').doc(testRunId).update({
    completed_at: FieldValue.serverTimestamp(),
    total_count: counts.total,
    pass_count: counts.pass,
    fail_count: counts.fail,
    status: counts.fail === 0 ? 'pass' : 'fail',
  })
}
```

### 9.7 Notify — LINE による完了報告

QAエージェントからレポートを受け取った後、PM が LINE Bot（`mcp__line-bot__push_text_message`）でユーザーに報告を送信する。

**QAテストが全て合格した場合** — 報告内容:
- デプロイしたプロジェクト名
- 変更内容の要約
- QAテスト結果（全項目合格、件数）
- 本番環境の確認URL（該当する場合）

**QAテストに失敗した場合** — LINE で失敗内容を報告し、修正対応に入る。自動で修正せず、まずユーザーに状況を通知すること。報告内容:
- 失敗したシナリオの一覧
- 各失敗項目の expected vs actual
- スクリーンショットURL（エビデンス）
