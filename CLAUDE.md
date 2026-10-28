# テックプット 開発ルール

> 正本の関係: このファイル = 絶対ルールと入口。細則は `.claude/rules/`（自動読込）、長い手順は `.claude/skills/`（`/develop` 等で呼ぶ）。
> ここに書いた事実と実コードが食い違ったら **実コードを正** とし、このファイルを直す。

## 絶対ルール

- **自分で実行できることはすべて自分でやる。** コマンド・ビルド・テスト・動作確認は自分で完遂し、「実行してください」と返さない。例外は認証情報の入力・ブラウザのログイン操作・物理デバイスだけ
- **壊す前に調べる。** 既存コードを読み、呼び出し元と後続処理を grep してから変える。根本原因を直し、一時しのぎをしない。最小変更
- **AI が書いたものを無検証で採用しない。** ビルド・テスト・画面で確かめてから「できた」と言う。「テスト済み」と「構文のみ確認」を分けて報告する
- **破壊的操作は承認を取ってから。** DB の作り直し・`git reset --hard`・`rm -rf`・force push は、消えるものと戻せないものを文章で示して「実行して」を得てから。`.claude/hooks/guard-bash.sh` がブロックしたら回避せず止まる
- **秘密情報を書かない。** `.env`・トークン・パスワードをコード・コミット・チャット・PR に出さない。出してよいのはパス・行番号・種別・有無だけ

## 必須ルール（入口）

- 3 ステップ以上の実装は `/develop` から入る。新規機能で要件が未確定なら、実装前に要件・仕様を文章で確定する
- git 操作の前に `.claude/rules/git/` を守る。ステージングはファイル名を明示し、`docs/` `.claude/` `tmp/` `log/` はコミットしない
- 「レビューして」は `/code-review`。「動作確認して」は Playwright で実際に画面を開いて確認し、結果を報告する
- 重要な設計判断（方針変更・DB 変更・API 変更・複数案の選択）は `/dual-ai` で Codex の第二意見を取る
- 命名を略さない。`u` / `tmp` / `data` / `res` のような名前を使わず、意図が読める名前を付ける。1〜2 文字は 3 行以内のスコープのみ

## 体制

社長（ユーザー）→ CTO（メインセッション: 計画・検収・マージ）→ PM（サブ）→ 作業員（`.claude/agents/` の designer / implementer / tester / reviewer / qa / researcher）。
コードを書くのは implementer だけ。どのステップで誰を呼ぶかは `/develop` が決める。

## このリポジトリ（teac-output-new / バックエンド）

| 項目 | 値 |
|---|---|
| 技術 | Rails 6.1 / Ruby 3.0.3 / MySQL 8 / RSpec / JWT（`api/v1`）+ Devise（旧 ERB 画面）。README の Rails 7 / Ruby 3.3 は古い |
| 起動 | `docker compose up -d`。ホスト側ポートは `docker-compose.yml` の `ports` を正とする（2026-10 時点 3013） |
| 検証 | `bundle exec rspec` / `bundle exec rubocop` / `bundle exec brakeman -q`。CI は無いので自分で回す |
| 統合先 | `origin/develop`（origin `nishinotakay/teac-output-new`）。e-learning は `feature/React` 系。作業ブランチは `feat/<内容>` / `fix/<内容>` |
| 多テナント | `Current.tenant` をログイン主体から決め、モデルは `default_scope { in_current_tenant }`。マイグレーション・seed では nil |
| 相手側 | フロント `../tech-put-app` の型と `*_json` を一致させる。先にバックエンド PR（旧フロントのままでも動く変更に限る） |

詳細は `.claude/rules/project/backend.md`。`app/` `spec/` `db/migrate/` を触ると Rails / RSpec / マイグレーション / 認可の規則が追加で読み込まれる。
