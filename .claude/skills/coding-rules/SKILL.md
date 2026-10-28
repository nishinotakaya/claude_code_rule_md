---
name: coding-rules
description: コーディング規約の実例集と PR 前チェックリスト（命名・コメント・分割・認可・SQL）。コードを書く前 / push 前 / レビュー時に参照。要点は .claude/rules/coding/ に自動で読み込まれる。
---

# コーディング規約（実例集と PR 前チェック）

> 要点は `.claude/rules/coding/{naming,comments,readable-code,refactoring}.md` が常時読み込まれる。ここは実例と、PR 前のチェックリスト。

## 参照ファイル

| ファイル | いつ読むか |
|---|---|
| `references/naming-examples.md` | メソッド名・ブロック変数の NG / OK を実例で見たいとき |
| `references/comment-examples.md` | コメントの ❌/✅ 実例を見たいとき |
| `references/rails-backend.md` | controller / フォーム / SQL を書くとき（バックエンドのブランチにある） |

## 要点（詳細は rules）

- **命名**: 省略しない・意図を表す・コレクションは複数形・真偽値は問いの形。ブロック変数もフルネーム（`users.each { |user| }`）
- **コメント**: 1 行。非自明な WHY と NOTE だけ。WHAT の言い換え・背景・出典は書かない
- **分割**: 1 ファイル = 1 役割。コピペは 2 回まで。「追加用」「編集用」を別々に作らない
- **動作を変えないリファクタ**: ついでの修正は別コミット
- **HTML に JS / CSS を直書きしない**: `<script>` `<style>` `style="..."` `style={{}}` は書かない。CSS 変数の受け渡しだけ例外
- **新規 CSS は最小限**: 既存クラス・フレームワークのユーティリティを再利用する

## ✅ チェックリスト（PR 前）

- [ ] メソッド名・引数名・変数名が「誰が見てもわかる名前」になっている（省略・曖昧・意図不明が無い）
- [ ] 既存コードの命名と整合している（同じ概念に新しい名前を発明していない）
- [ ] each / map / filter 等のブロック変数がフルネーム
- [ ] コメントが端的（WHAT の言い換え・長い docstring・背景説明が無い）
- [ ] HTML / JSX に `<script>` / `<style>` / `style="..."` / `style={{}}` を書いていない
- [ ] 新規 CSS を書いていない（既存クラス・ユーティリティを再利用）
- [ ] 共通部品（Layout・shared）の編集が機能差分のみ（ついで修正を含めていない）
- [ ] 認可ガードがある（API: `authenticate_*!` + ロール + 所有 / テナントスコープ。画面: ルートガード + 表示制御の二重）
- [ ] 取得・作成・更新が認証主体の relation か `Current.tenant` の default_scope 起点（`Model.unscoped` を理由なく書いていない）
- [ ] 更新は params に無いキーを触らない（`|| 初期値` で merge していない）
- [ ] フロントの型とバックエンドの `*_json` が一致している
- [ ] テストがある（特に認可・他テナントのテスト）
- [ ] バックエンド: `bundle exec rubocop` / `rspec` / `brakeman` が通る。フロント: `npm run build` が通る
- [ ] 秘密情報が差分に入っていない（`gitleaks git --staged --redact --exit-code 1` が 0 件）
- [ ] JS: `npm audit --omit=dev` の high 件数が増えていない
- [ ] ブランチ名がリポジトリの慣習に従っている

## 関連スキル

- `/code-review` — レビューの観点と伝え方
- `/security-baseline` — 認可・テナント境界・秘密の検査手順
- `/layout-defense` — 画面を組む前と後の検証
