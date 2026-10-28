---
name: security-baseline
description: セキュリティ実装・レビューの最低線（秘密の混入・未スコープ find・認証境界・ロール境界・テナント境界・フォーム⇔サーバー検証の同値性）。「セキュリティレビューして」「脆弱性を見て」「安全に実装して」「認証・認可」「秘密情報」で参照。
---

# セキュリティ基盤

> 目的: 「注意しましょう」を書かない。実際に空いている穴を file:line 単位で塞ぐ。要約は `.claude/rules/security/baseline.md`。

## 参照ファイル（該当する 1 枚だけ読む）

| ファイル | いつ読むか |
|---|---|
| `references/authz.md` | `find` / `where` / `update!` を書くとき、認可を実装・レビューするとき。棚卸しコマンドと手書き認可の型 |
| `references/role-boundary.md` | 管理画面・多テナント・ロール・紐付け / 解除・設定フォームの更新を書くとき。到達可能性表と認可テストの最小セット |
| `references/auth-boundary.md` | 新規エンドポイント・Webhook・CORS・トークン保存先 |
| `references/frontend-supply-chain.md` | `package.json`・依存の追加 / 更新、`innerHTML`、CSP |

## 0. 報告の規律

- **秘密の値は出力しない。** 出してよいのはパス / 行番号 / 種別 / 有無。`cat .env` を叩かない。`grep -n 'SECRET' .env | sed -E 's/=.*/=<伏せ>/'` で潰す
- **自分で実行できる棚卸しは自分でやる。** 「実行してください」と投げない
- **brakeman が緑でも安全の証明にならない。** 秘密の混入・認可の欠落・Webhook の署名検証・平文保存・テナント境界は検出しない。「brakeman は緑。上記は別途確認した」と書く

## 1. 実装前の確認

### 1.1 秘密をリポジトリに入れない

```bash
git ls-files | grep -E 'master\.key$|credentials/.*\.key$|secrets\.yml$|\.pem$|client_secret_.*\.json$|^\.env$|^dev\.env$'
```

1 件でも出たら実装を止めて報告する（値は出さない）。履歴に入った鍵は失効・再発行が本体で、履歴の書き換えは後。稼働中のセッションを切るので AI が勝手に実行しない。

### 1.2 `find(params[:id])` の直後に所有者 / テナントスコープがあるか

認証主体の relation 起点（`current_user.learnings.find`）か、`Current.tenant` の default_scope が効くモデルか、直後の明示チェックか。無いなら「なぜ無くてよいか（全テナント共通マスタ等）」をコメントで残す。無言の未スコープ find は、意図か漏れかを後から誰も判定できない。

### 1.3 新規エンドポイントの認証境界

- `before_action` をパス前方一致条件で書かない。既定で全部にかけ、外すものだけ `skip_before_action` で明示する
- `skip_before_action :verify_authenticity_token` を書いたら署名検証（HMAC + `secure_compare`）を併設する
- CORS は完全一致の許可リストだけ。`*` と部分一致正規表現を使わない（`config/initializers/cors.rb` の `ENV['FRONTEND_ORIGIN']` の形を保つ）
- トークンを URL クエリに置かない。localStorage の新しいキーを増やさない

### 1.4 ロール境界 — 「ナビに出さない」は認可ではない

namespace・コントローラを足したら、**到達可能性表（アクション × 認証 × ロール × 所有 / テナントスコープ × 副作用）を先に書く**。上位ロールを自動で通さない。副作用のある操作を GET にしない。→ `references/role-boundary.md`

### 1.5 テーブル起点の `new` / `where` / `update_all` を書かない

`find` だけでなく作成・一覧・一括更新も認証主体の relation か default_scope 起点。紐付け / 解除の `update_all` は両方向を同じスコープで対称に書く。

### 1.6 フォーム ⇔ permit ⇔ サーバー検証 ⇔ 保存 を同じ集合にする

JS を飛ばした POST が前提。params に無いキーは更新しない（`|| 初期値` で merge しない）。フォームが送る全行・全キーをサーバー側で検証する。

### 1.7 多テナント固有

- `Current.tenant` はログイン主体から決める。URL・パラメータ・ヘッダの `tenant_id` を信用しない
- `unscoped` を書いたら理由をコメントで残し、直後に明示の `where(tenant_id:)` を付ける
- マイグレーション・seed・rake・コンソールでは `Current.tenant` が nil。データ移行はテナントを明示して回す
- 別レコードの紐付け（記事にコース・記事にカテゴリー）は相手が同じテナントかをモデルで検証する
- 受講生 API は「誰の記録か」を JWT の本人から決める。リクエストの `user_id` は使わない

## 2. レビュー時 — 兄弟アクションの同値性

同じリソースを触る兄弟アクション（index / show / update / destroy、紐付け / 解除）を列挙し、防御レベルが揃っているかを見る。穴は「知らないから」ではなく「片方だけ書き忘れたから」空く。片方を直したら残りの欠落も件数とパスで報告する。

## 3. 完了の定義（DoD）

- [ ] `gitleaks git --staged --no-banner --redact --exit-code 1` が 0 件
- [ ] Rails: `bundle exec brakeman -q --no-pager` / `bundle exec bundler-audit check --update` が緑
- [ ] JS: `npm audit --omit=dev` の high が増えていない（ゼロにする、を条件にしない）
- [ ] `find` を追加したら、所有者違い・他テナントで 403 / 404 **かつ DB 不変** のテストがある
- [ ] 管理画面・多テナント: 到達可能性表を書き、上位ロールが入れない / 他テナントが一覧に出ない / 他テナントは編集不可かつ DB 不変 のテストがある
- [ ] 設定フォーム: 項目名だけの更新で他の設定が消えないテストと、フォームが送る全キーのサーバー検証がある
- [ ] 境界を外す変更（skip / CORS 追加）は、代替の検証を同じコミットで入れた

`gitleaks dir` は使わない（ログや node_modules を舐めて遅い）。`gitleaks git` を使う。

## 4. 役割分担

| スキル | 担当 |
|---|---|
| `code-review` | 指摘の書き方・優先度。レビュー時のシンク別の表は `code-review/references/security.md` |
| `coding-rules` | PR 前チェックリスト（§3 を接続する） |
| 本スキル | セキュリティの検査手順のみ |
