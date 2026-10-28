# 機械が潰す観点と、このプロジェクトで人が見る観点

> 差分を読む前にこれを読む。機械が確定判断できる観点はツールに任せ、AI の時間は機械に定義できない判断に使う。
> ただし **テックプットには CI も lint（フロント）も無い**。下の表で「導入済み」でないものは、導入するまで人が見る。

## 1. 機械が確定判断できる観点

| # | 観点 | ツール | テックプットでの状態 |
|---|---|---|---|
| 1 | `any` / `as` キャスト | typescript-eslint | **未導入**。人が見る |
| 2 | 空 catch `.catch(() => {})` | eslint / semgrep | **未導入**。人が見る |
| 3 | 1〜2 文字変数・ブロック引数の略号 | ast-grep / rubocop | バックエンドは rubocop のみ。フロントは人が見る |
| 4 | JSX インライン `style={{}}` | ast-grep | **未導入**。人が見る |
| 5 | `save` / `update` の戻り値握りつぶし | semgrep | **未導入**。人が見る |
| 6 | `useEffect` 依存配列漏れ | eslint `react-hooks/exhaustive-deps` | **未導入**。人が見る |
| 7 | SQL インジェクション / プレースホルダ | brakeman | Gemfile にある。`bundle exec brakeman -q` を回す |
| 8 | 未使用 export / 依存 | knip | 未導入 |
| 9 | 秘密情報の混入 | gitleaks | `gitleaks git --staged` を回す。既定ルールのリコールは約 5 割。`.env` の変数名だけの差分は手で見る |
| 10 | 既知 CVE | bundler-audit / `npm audit --omit=dev` | 手動実行 |
| 11 | N+1 | bullet（Gemfile にあり、test で raise） | rspec を回せば検出される。静的には取れない |

> brakeman が緑でも安全の証明にならない。秘密の混入・認可の欠落・テナント境界・平文保存は検出しない。

## 2. AI が見るべきこと（機械に定義できない）

1. **根本原因 vs 一時しのぎ** — 症状を潰しただけで原因に踏み込んでいないか
2. **トランザクション境界** — この 2 つの更新は同一トランザクションであるべきか
3. **Controller に表示ロジックが漏れていないか**
4. **UI 状態の網羅性** — ロード / 空 / エラー / 成功
5. **命名が実体とズレていないか** — `fetchUser` が User 以外を返す
6. **重複を共通化すべきか、将来別々に育つから残すべきか**
7. **テナント境界・認可の到達可能性** — `unscoped`、`tenant_id` をパラメータから受ける、ロール違いの直打ち
8. **API 契約の一致** — フロントの型とバックエンドの `*_json`

## 3. 推奨する導入（任意。入れたらこの表を更新する）

| 層 | ツール | 効果 |
|---|---|---|
| フロント lint | eslint + typescript-eslint + react-hooks | 上の #1 #2 #6 を機械化 |
| pre-commit | lefthook で変更ファイルだけ rubocop / eslint | コミット時に差し戻し |
| CI | GitHub Actions で rspec / rubocop / brakeman / `npm run build` | PR ごとに緑を確認 |

`rubocop` を変更ファイル指定で回すときは `--force-exclusion` を付ける（付けないと `AllCops/Exclude` が無視される）。

## 4. レビュー指摘のルール化

同じ指摘を 3 回書いたら、それはルールにできる。
- 事故防止 → テスト / フック化
- 判断ズレ → `.claude/rules/` に明文化
- 表現揺れ → チェックリスト化
ルール化したらこのファイルの表に追記し、SKILL.md の観点からは削除する。
