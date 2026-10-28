# Claude Code ルール集（テックプット仕様）

テックプット（フロント `tech-put-app` / バックエンド `teac-output-new`）で Claude Code を使って開発するためのルール一式。
対象リポジトリの直下にコピーして使う（両リポジトリとも `.claude/` と `CLAUDE.md` を `.gitignore` しているため）。

## ブランチ

| ブランチ | 中身 | 配備先 |
|---|---|---|
| `main` | 汎用版（旧構成のまま） | — |
| `feat/techput-common` | 両リポ共通のルール・スキル・エージェント | 直接は使わない |
| `feat/techput-frontend` | common + React/TypeScript 固有 | `tech-put-app/` |
| `feat/techput-backend` | common + Rails API 固有 | `teac-output-new/` |

共通部分を直すときは **`feat/techput-common` で直してから、frontend / backend の両方へ `git merge feat/techput-common`** する。
frontend / backend で直接 common のファイルを触ると、もう片方に反映されず食い違う。

## 3 層構成（読み込まれ方が違う）

| 層 | 場所 | 読み込み | 書くもの |
|---|---|---|---|
| 1 | `CLAUDE.md` | 会話開始時に常時 | 絶対ルール・入口・このリポジトリの事実（短く） |
| 2 | `.claude/rules/<分類>/<topic>.md` | 常時。`paths:` 付きは該当ファイルを触ったときだけ | 短い規則。1 ファイル 1 テーマ |
| 3 | `.claude/skills/<name>/SKILL.md` + `references/` | `/<name>` で呼んだとき・関連作業のとき | 長い手順・チェックリスト・実例 |

常時読込の総量を抑えるため、技術固有の規則（React / Rails / RSpec / マイグレーション）は `paths:` で範囲を限定し、長い手順は skills に置く。

```
CLAUDE.md
ONBOARDING.md                         ← インターンの初日手順
install.sh                            ← 対象リポへの配備（既定 dry-run）
.github/pull_request_template.md      ← 対象リポに無ければ配備
.claude/
  settings.json                       ← 破壊操作の deny・フック・Playwright MCP
  hooks/guard-bash.sh                 ← 危険な git / DB 操作をブロック
  rules/
    core/      mindset / task-management / token-saving
    git/       branch-strategy / commit-rules / pull-request
    coding/    naming / comments / readable-code / refactoring (+ 技術固有は各ブランチ)
    security/  baseline (+ frontend.md / rails-authz.md は各ブランチ)
    review/    code-review
    testing/   e2e-playwright
    project/   techput-overview (+ frontend.md / backend.md は各ブランチ)
  skills/
    develop/           10 ステップ開発フロー（/develop）
    code-review/       レビュー観点・トーン・報告形式・GitHub 投稿
    coding-rules/      命名・コメントの実例
    security-baseline/ 認可・認証境界・ロール境界・テナント境界
    dual-ai/           Codex セカンドオピニオン
    auto-test/         Playwright E2E
    layout-defense/    レイアウト崩れ防止
    post-mistakes/     事故台帳と着手前チェック
    md-report/         調査・作業の md 化
    elearning-pm/      e-learning 段階実装の PM 手順
  agents/
    designer / implementer / tester / reviewer / qa / researcher
tasks/
  todo.md / lessons.md
```

## 配備

```bash
git clone -b feat/techput-frontend https://github.com/nishinotakaya/claude_code_rule_md.git /tmp/rules-frontend
/tmp/rules-frontend/install.sh /path/to/tech-put-app            # 差分表示のみ
/tmp/rules-frontend/install.sh /path/to/tech-put-app --apply    # 配備
```

- `install.sh` は上書きと追加だけを行い、**削除はしない**。`tasks/` と `.github/pull_request_template.md` は対象に無いときだけ置く
- 配備後、対象リポで `claude` を起動し `/develop` が出ることを確認する
- 長期的には対象リポの `.gitignore` から `.claude/` と `CLAUDE.md` を外してコミット管理に移す方が drift しない（要レビュアー合意）

## 旧構成（main）からの変更

- `CLAUDE.md` を `.claude/commands/` からリポジトリ直下へ（commands 配下では自動読込されない）
- `.claude/rules/` を分類別サブフォルダに再編。develop の step ファイルは `.claude/skills/develop/references/` へ移動（常時読込から外す）
- `.claude/commands/develop.md` を `.claude/skills/develop/SKILL.md` に統合（slash コマンドは skills に統合済み）
- `.claude/memory/` を削除（他案件固有のメモだった。教訓は `tasks/lessons.md` に一本化）
- `.claude/skills/auto-test.md` を `auto-test/SKILL.md` 形式に修正
- Codex の呼び出しを `--skip-git-repo-check --sandbox read-only` に修正（旧 `--full-auto` は信頼ディレクトリ外で失敗する）
- Firebase / DRBFM / LINE 通知など、このプロジェクトに存在しない仕組みへの依存を削除
- 追加: エージェント定義 6 種、guard-bash フック、PR テンプレート、ONBOARDING、install.sh、セキュリティ基盤、レビューのトーン規約、レイアウト防御、事故台帳、トークン節約、テックプット固有の事実（ポート・API 契約・テナント契約・テストアカウント）
