# 教訓（tasks/lessons.md）

セッション開始時に読む。ユーザーから修正を受けたら「事象 → 原因 → 次からどうするか」を 1〜3 行で追記する。同じ型が 2 回出たら `.claude/skills/post-mistakes/` と該当ルールに昇格させる。

## 環境・設定の取り違え

- フロントの `CLAUDE.md` に書かれたバックエンドのポート（3001）と `teac-output-new/docker-compose.yml` のポート（3013）が食い違っていた → ドキュメントのポート・URL は古い前提で疑い、`docker-compose.yml` と `.env.development.local` の現物で確認する
- `teac-output-new/README.md` の技術スタック（Rails 7 / Ruby 3.3）は Gemfile（Rails 6.1 / Ruby 3.0.3）と違う → バージョンは Gemfile / `.ruby-version` / `package.json` を正とする
- フロントには Tailwind が `package.json` と postcss に入っているが `@tailwind` ディレクティブが無く、ユーティリティは生成されない → Tailwind クラスを書かない。Bootstrap 5 + 自作 CSS で組む

## テスト・検証

- フロントにテストランナーが無い → 「テストを書いて」は `npm run build`（tsc）と Playwright の操作手順に置き換える。受け入れ基準を画面で確かめる
- 多テナントの `default_scope { in_current_tenant }` はマイグレーション・seed・コンソールでは `Current.tenant` が nil で全件を返す → データ移行・補正はテナントを明示して回し、件数を先に報告してから実行する
- HTTP 200 や exit 0 は「中身が正しい」の根拠にならない → 保存系は再取得して値を見る。出力物は全行・全列を DB の実効値と突き合わせる

## コミュニケーション

- 「あり得る？」「やり方ある？」は相談であり実行指示ではない → 選択肢と推奨を返して止まる
- 「そのままでいいや」は修正不要の意味 → 再適用しない
- 「元に戻して」はコードか DB か文脈で判断する → 迷ったら対象を 1 行で確認する
- 意味を変えた API はフロントの呼び出し元と、その前後にチェーンしている処理を全部読む → 片側だけ直して値が戻る事故を防ぐ

## git

- `git add` にドット・`-A` を渡さない → ファイルパスを明示する。`docs/` `.claude/` はコミットしない
- コミットメッセージは heredoc で渡す → 改行とクォートが壊れない
