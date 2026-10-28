# ワークフロー概要 — 6 ロール体制・ブランチ構造

## 6 ロール体制

```
CTO（メインセッション）── 計画の承認・検収・マージ・デプロイ・社長との対話
  └─ PM（サブエージェント）── 要件整理・影響分析・設計・タスク分解・進行管理
       ├─ 1. Plan / Assess   ← PM（調査は researcher に出す）
       ├─ 2. Design          ← designer（UI 変更がある場合のみ）
       ├─ 3. Write Tests     ← tester（インターフェース定義からテストを書く。実装前なので全件 FAIL が正常）
       ├─ 4. Implement       ← implementer（isolation: "worktree"）
       ├─ 5. Quality Gate    ← Bash: rspec / rubocop / npm run build
       ├─ 6. Review          ← reviewer + designer（並列）
       ├─ 7. Fix             ← implementer で修正 → 5 に戻る
       ├─ 8. Merge           ← CTO: PR 作成 → ベースブランチへ
       ├─ 9. Deploy & QA     ← CTO: デプロイ → qa: Playwright 確認 + 証跡
       └─ 10. Retro          ← PM: tasks/lessons.md 更新 → ルール改善
```

## ブランチ構造

```
main / develop（統合先。リポジトリごとに .claude/rules/project/ で定義）
  ├── <prefix>/xxx  ← implementer（worktree 隔離）
  └── <prefix>/yyy
```

prefix はリポジトリの慣習に合わせる（フロント `feature/` `fix/`、バックエンド `feat/` `fix/`）。

## 各ロールの責務

| ロール | 読むべきもの | やること | やらないこと |
|---|---|---|---|
| **CTO**（メイン） | `/develop` `/git-rules` | 計画承認、検収、マージ、デプロイ、社長との対話 | コード実装、テスト記述、全件レビュー |
| **PM**（サブ） | `/develop` `.claude/rules/` | 要件整理、影響分析、設計、タスク分解、作業員への委任、完了報告 | コード実装 |
| designer | `/layout-defense` | UI 仕様策定、デザインレビュー | コード実装 |
| implementer | 計画から受け取る + `.claude/rules/coding/` | コード変更（worktree 上でコミット） | テスト記述、規約チェック、仕様判断 |
| tester | 計画から受け取る | テストコード記述・実行・結果報告 | 実装コード変更 |
| reviewer | `/code-review` `/security-baseline` | 規約・セキュリティ・品質の指摘 | コード修正 |
| qa | `/auto-test` | Playwright 動作確認、証跡保存、レポート | コード修正、デプロイ |
| researcher | — | コード探索・原因究明・影響範囲の事実確認 | 実装・修正 |

## デザイナーの適用判断

| 変更内容 | designer 起動 |
|---|---|
| UI コンポーネントの新規作成 | 必須 |
| 既存 UI のレイアウト・見た目変更 | 必須 |
| API・バックエンドのみの変更 | スキップ |
| テスト・リファクタリングのみ | スキップ |
| 文言の変更のみ | 推奨 |

## 委任の型（PM → 作業員）

プロンプトには必ず次を含める。作業員は CLAUDE.md と `.claude/rules/` を自動で読むが、会話の文脈は持たない。

```
## 目的（何を・なぜ）
## 許可された変更範囲（ファイル・ディレクトリ）／範囲外（触らないもの）
## 仕様（インターフェース定義・API 契約・受け入れ基準）
## 制約（壊してはいけないもの・関連する規約の抜粋）
## 完了条件（実行すべきコマンドと期待結果）
## 報告形式
```
