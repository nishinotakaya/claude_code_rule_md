# コミット規約

## 対象の決め方

- **ステージングはファイルパスを明示する。** `git add` にドット・`-A`・`--all` を渡さない（`.claude/hooks/guard-bash.sh` がブロックする）
- 含めるもの: 実行ロジック・設定・マイグレーション・テスト（`app/` `config/` `db/migrate/` `lib/` `spec/` `src/` など）
- 含めないもの: `docs/` `.claude/` `tmp/` `log/`、スクショ、調査メモ。ユーザーが明示したときだけ `ALLOW_DOCS_COMMIT=1` を付けて含める
- 判断基準は「これはロジックに影響する実行コードか」
- 1 コミット = 1 つの論理的変更。ついでの修正・リファクタは別コミット

## メッセージ

```
<type>: <概要（日本語可）>

<詳細（任意。なぜそうしたか）>

Co-Authored-By: Claude <モデル名> <noreply@anthropic.com>
```

| type | 使いどころ |
|---|---|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | 動作を変えない整理 |
| `chore` | 設定・依存・ビルド |
| `docs` | ドキュメントのみ |
| `test` | テストのみ |
| `style` | 整形のみ |
| `perf` | 性能改善 |

改行を保つため、メッセージは heredoc で渡す。

## 禁止と要確認

| 操作 | 扱い |
|---|---|
| `main` / `develop` への force push | 禁止 |
| `git commit --no-verify`（`-n`） | 禁止 |
| `git reset --hard` / `git checkout .` / `git clean -f` | 確認なし実行禁止。影響を示して承認を得る |
| 作業ブランチへの force push | ユーザーの明示があれば可。remote とブランチ名を両方書く |
| `rails db:drop` / `db:reset` / `db:schema:load` / `DROP TABLE` | 禁止。開発 DB でも消えるデータがある |

## コミット前チェック

- [ ] `git diff --staged` で意図したファイルだけか見た
- [ ] `.env`・鍵・トークンが差分に無い（`gitleaks git --staged --redact --exit-code 1` が 0 件）
- [ ] `console.log` / `binding.pry` / `debugger` が残っていない
- [ ] メッセージが変更内容を正確に表している
- [ ] `.env` は `.gitignore` 済み。変数名だけの `.env.example` を更新した（変数を足したとき）
