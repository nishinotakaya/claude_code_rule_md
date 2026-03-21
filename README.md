# Claude Code ルール設定ファイル集

## 3つの主要ファイル

| ファイル | 役割 | 読み込み |
|---------|------|---------|
| `CLAUDE.md` | Claude Code の行動ルール・禁止事項を定義 | 会話開始時に自動 |
| `develop.md` | 開発フローの手順（10ステップ）を定義 | `/develop` で手動 |
| `MEMORY.md` | 過去の会話で学んだNG・注意点の目次 | 会話開始時に自動 |

## ディレクトリ構成

- `.claude/commands/` — スラッシュコマンドで呼び出すファイル
- `.claude/rules/` — develop.md から分割した詳細手順
- `.claude/memory/` — 蓄積されたフィードバック・プロジェクト情報
- `.claude/settings.json` — 権限・MCP サーバー設定
