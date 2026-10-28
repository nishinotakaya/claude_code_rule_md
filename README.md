# Claude Code ルール集

任意のリポジトリに配備して Claude Code で開発するための、プロジェクト非依存のルール一式。
対象リポジトリの直下にコピーして使う（`.claude/` と `CLAUDE.md` を `.gitignore` している場合は、配備しても差分に出ない）。

## 使い方

1. `install.sh` で対象リポジトリに配備する（下記「配備」）
2. 配備後、最初に `.claude/rules/project/overview.md` を埋める（構成・起動・検証コマンド・統合先・API 契約・テストアカウントの場所）
3. 複数リポジトリ（例: フロントとバックエンド）で開発する場合は、同じ一式を全部に配備する。技術固有の規則（React / Rails / RSpec / マイグレーション）は `paths:` 付きで、該当ファイルを触ったときだけ読み込まれるため、混ざっていても常時読込は増えない

## 3 層構成（読み込まれ方が違う）

| 層 | 場所 | 読み込み | 書くもの |
|---|---|---|---|
| 1 | `CLAUDE.md` | 会話開始時に常時 | 絶対ルール・入口（短く）。プロジェクト固有の事実は `rules/project/overview.md` |
| 2 | `.claude/rules/<分類>/<topic>.md` | 常時。`paths:` 付きは該当ファイルを触ったときだけ | 短い規則。1 ファイル 1 テーマ |
| 3 | `.claude/skills/<name>/SKILL.md` + `references/` | `/<name>` で呼んだとき・関連作業のとき | 長い手順・チェックリスト・実例 |

常時読込の総量を抑えるため、技術固有の規則（React / Rails / RSpec / マイグレーション）は `paths:` で範囲を限定し、長い手順は skills に置く。`rules/step/` は常時読込（約 20KB）。

```
CLAUDE.md
ONBOARDING.md                         ← 初日の手順
install.sh                            ← 対象リポへの配備（既定 dry-run）
.github/pull_request_template.md      ← 対象リポに無ければ配備
.claude/
  settings.json                       ← 破壊操作の deny・フック・Playwright MCP
  hooks/guard-bash.sh                 ← 危険な git / DB 操作をブロック
  rules/
    core/      mindset / task-management / token-saving
    git/       branch-strategy / commit-rules / pull-request
    coding/    naming / comments / readable-code / refactoring / react-typescript / css-layout / rails-api / rspec / migration
    security/  baseline / frontend / rails-authz
    review/    code-review
    testing/   e2e-playwright
    project/   overview（配備先ごとに埋めるテンプレート）
    step/      workflow-overview / plan / design / test / implement / review / deploy-qa / retro（/develop の各ステップ詳細）
  skills/
    develop/           10 ステップ開発フロー（/develop。詳細は rules/step/）
    code-review/       レビュー観点・トーン・報告形式・GitHub 投稿
    coding-rules/      命名・コメントの実例
    security-baseline/ 認可・認証境界・ロール境界・テナント境界
    dual-ai/           Codex セカンドオピニオン
    auto-test/         Playwright E2E
    layout-defense/    レイアウト崩れ防止
    post-mistakes/     事故台帳と着手前チェック
    md-report/         調査・作業の md 化
  agents/
    designer / implementer / tester / reviewer / qa / researcher
tasks/
  todo.md / lessons.md
```

## 配備

```bash
git clone <このリポジトリの URL> /tmp/claude-rules
/tmp/claude-rules/install.sh /path/to/target-repo               # 差分表示のみ
/tmp/claude-rules/install.sh /path/to/target-repo --apply       # 配備
```

- `install.sh` は上書きと追加だけを行い、**削除はしない**。`tasks/` と `.github/pull_request_template.md` は対象に無いときだけ置く
- 配備後、対象リポで `claude` を起動し `/develop` が出ることを確認する
- 長期的には対象リポの `.gitignore` から `.claude/` と `CLAUDE.md` を外してコミット管理に移す方が drift しない（要レビュアー合意）

## 旧構成からの変更

- `CLAUDE.md` を `.claude/commands/` からリポジトリ直下へ（commands 配下では自動読込されない）
- `.claude/rules/` を分類別サブフォルダに再編（core / git / coding / security / review / testing / project / step）。旧 `step-*.md` と `workflow-overview.md` は `rules/step/` へ
- `.claude/commands/develop.md` を `.claude/skills/develop/SKILL.md` に統合（slash コマンドは skills に統合済み）
- `.claude/memory/` を削除（他案件固有のメモだった。教訓は `tasks/lessons.md` に一本化）
- `.claude/skills/auto-test.md` を `auto-test/SKILL.md` 形式に修正
- Codex の呼び出しを `--skip-git-repo-check --sandbox read-only` に修正（旧 `--full-auto` は信頼ディレクトリ外で失敗する）
- 特定プロジェクトに無い仕組み（外部サービス連携など）への依存を削除
- 追加: エージェント定義 6 種、guard-bash フック、PR テンプレート、ONBOARDING、install.sh、セキュリティ基盤、レビューのトーン規約、レイアウト防御、事故台帳、トークン節約、プロジェクト固有の事実を埋めるテンプレート（`rules/project/overview.md`: 構成・API 契約・テナント契約・テストアカウントの場所）

## 汎用化

- 特定プロダクト向けだった内容（ポート・API 契約・テナント契約・テストアカウント・段階実装の PM 手順）をルール集から外し、`rules/project/overview.md` のテンプレートに置き換えた。プロダクト固有の事実は、各プロダクトのリポジトリ側で管理する
