---
name: feedback_test_report
description: Playwrightテスト実施後はスクリーンショット付きのMDレポートを保存する
type: feedback
---

Playwrightテストを実施したら、必ずスクリーンショット付きのMDレポートを保存する。

**Why:** ユーザーが「テスト結果はスクショ付きでmdファイルに保存してほしい」と指示した。

**How to apply:**
- 保存先: `docs/test/screenshots/comprehensive/test_report_{YYYY-MM-DD}.md`
- 内容: テスト項目・結果(✅/❌)・スクリーンショットの表（Markdown画像リンク）・修正した不具合一覧
- Playwrightテストを実行するたびに新しいレポートファイルを生成する
