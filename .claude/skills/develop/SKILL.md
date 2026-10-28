---
name: develop
description: 実装タスク開始時の開発フロー（PDCA・6ロール・10ステップ）。3ステップ以上の実装タスクで必ず実行する。
user-invocable: true
---

# 開発フロー（PDCA・6 ロール体制）

実装タスク開始時に必ずこのフローを実行する。

- **指揮系統**: 社長（ユーザー）→ CTO（メインセッション）→ PM（サブエージェント）→ 作業員（`.claude/agents/` の designer / implementer / tester / reviewer / qa / researcher）。コードを書くのは implementer だけ
- **要件が未確定の新機能**（業務フロー・権限境界・データ契約・外部連携を新設する）は STEP 1 の前に要件・仕様・設計を文章で確定し、社長の承認を取る。e-learning は `/elearning-pm` が上流文書とフェーズを持っている
- 局所的なバグ修正・互換的な小改修はこのフローの STEP 1〜2 を短く済ませ、STEP 5〜7 を省かない

## ステップ別の詳細（`.claude/rules/step/`。常時読込済み）

| ファイル | 内容 |
|---|---|
| `.claude/rules/step/workflow-overview.md` | 6 ロールの責務・ブランチ構造・デザイナー起動判断・委任状の型 |
| `.claude/rules/step/plan.md` | STEP 1〜2（要件理解・影響範囲） |
| `.claude/rules/step/design.md` | STEP 3 で UI がある場合 |
| `.claude/rules/step/test.md` | STEP 4.5（テスト先行） |
| `.claude/rules/step/implement.md` | STEP 5（worktree 隔離の実装） |
| `.claude/rules/step/review.md` | STEP 6〜7（レビュー・修正） |
| `.claude/rules/step/deploy-qa.md` | STEP 8〜10（マージ・デプロイ・QA） |
| `.claude/rules/step/retro.md` | STEP 10（振り返り） |

## 10 ステップ

| STEP | 担当 | やること |
|---|---|---|
| 1 要件理解 | PM | 「何を・なぜ・どこまで」を確定。曖昧点は実装前に確認。重要な設計判断は `/dual-ai` |
| 2 影響範囲 | PM + researcher | 変更対象ファイル・呼び出し元・後続処理・既存テストへの影響。フロントとバックエンドの両方に跨るなら API 契約の差分を先に書く |
| 3 技術設計 | PM + designer | 最小変更・最大効果。API / データフロー。UI がある場合は UI/UX 方針（`/layout-defense` §1） |
| 4 タスク分解 | PM | 小ステップ化・完了条件・並列可能な作業を `tasks/todo.md` に。バックエンド PR → フロント PR の順 |
| 4.5 テスト先行 | tester | インターフェース定義からテストを書く（バックエンドは request spec。フロントはテストランナーが無いので受け入れ基準を Playwright 手順に落とす） |
| 5 実装 | implementer | 1 ファイルずつ。既存コードを読んでから書く。不要な変更・リファクタをしない。worktree で隔離 |
| 6 セルフレビュー | reviewer | 規約準拠。**セキュリティは `/security-baseline` §1 を回す**（コントローラ・routes・多テナントは到達可能性表を実装前に書く）。デバッグコード除去 |
| 7 テスト | tester | 変更箇所・エッジケース・異常系・既存機能の非破壊。`bundle exec rspec` / `npm run build` を自分で回す |
| 8 統合確認 | PM | 整合性・ログ・エラーハンドリング。フロントの型とバックエンドの `*_json` が一致しているか |
| 9 デプロイ準備 | PM | 環境変数・設定。**新規秘密情報が git 管理下に無いこと**（`gitleaks git --staged`。値は出力しない）。マイグレーション・ロールバック手順 |
| 10 QA・エビデンス | qa | ローカル / ステージング / 本番で Playwright 確認・スクショ・ログ保存・完了報告 |

## 実行ルール

- **壊す前に調べる**（既存コードを読んでから変更）/ **根本原因を突き止める** / **最小変更** / **美を追求** / **自分で完遂**（コマンド・動作確認・テストを自分でやりきる）
- サブエージェントの起動数は最小限。「並列 5 体」より「的確な 1 体」（`.claude/rules/core/token-saving.md`）

## 完了前チェック

- [ ] 要件を満たす
- [ ] 既存機能を壊していない（rspec / build が緑。画面は Playwright で確認）
- [ ] セキュリティリスクなし（`/security-baseline` の DoD）
- [ ] 秘密情報をコミットしていない
- [ ] 不要なファイル・コードなし（デバッグ出力・一時スクリプト）
- [ ] `tasks/lessons.md` に学びがあれば追記した
