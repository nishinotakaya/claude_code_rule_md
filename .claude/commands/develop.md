# 開発フロー・ワークフロールール

タスクを実行する際、以下のワークフローとコア原則に従うこと。

---

## 概要

10ステップ・6ロール体制の開発フロー。詳細は各ファイルを参照。

| Step | 内容 | 詳細ファイル |
|------|------|-------------|
| — | 6ロール体制・ブランチ構造 | [workflow-overview.md](../rules/workflow-overview.md) |
| 1-2 | Plan（計画）・Assess（影響分析） | [step-plan.md](../rules/step-plan.md) |
| 2.5 | Design（UI/UX設計） | [step-design.md](../rules/step-design.md) |
| 3 | Write Tests（テスト記述・TDD） | [step-test.md](../rules/step-test.md) |
| 4-5 | Implement（実装）・Test（品質ゲート） | [step-implement.md](../rules/step-implement.md) |
| 6-7 | Review（レビュー）・Fix（修正） | [step-review.md](../rules/step-review.md) |
| 8-9 | Merge・Deploy & QA | [step-deploy-qa.md](../rules/step-deploy-qa.md) |
| 10 | Retro（振り返り・PDCA） | [step-retro.md](../rules/step-retro.md) |
| — | コア原則・補則 | [core-principles.md](../rules/core-principles.md) |
| — | デュアルAI意思決定 | [dual-ai.md](../rules/dual-ai.md) |

## クイックリファレンス

```
PM (メインエージェント)
  ├─ 1. Plan        → 要件定義・技術設計・規約抽出・Codexセカンドオピニオン
  ├─ 2. Assess      → 影響範囲分析・リスク評価
  ├─ 2.5 Design     → UI/UX設計（UI変更時のみ）
  ├─ 3. Write Tests → TDD: テスト先行記述
  ├─ 4. Implement   → worktree隔離で実装
  ├─ 5. Test        → 品質ゲート実行
  ├─ 6. Review      → コード + デザインレビュー（並列）
  ├─ 7. Fix         → 違反修正 → Step 5 に戻る
  ├─ 8. Merge       → develop → main
  ├─ 9. Deploy & QA → デプロイ + DRBFM + E2E + エビデンス + LINE通知
  └─ 10. Retro      → 振り返り → lessons.md → 規約改善
```
