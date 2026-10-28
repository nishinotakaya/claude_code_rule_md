---
paths:
  - "app/controllers/**"
  - "app/models/**"
  - "config/routes.rb"
  - "config/initializers/cors.rb"
---

# 認可とテナント境界（teac-output-new）

> 「ナビに出していない」「フロントでボタンを隠した」は認可ではない。URL を直接叩けば届く。手順の詳細は `/security-baseline`。

## コントローラ / routes を足したら、先に表を書く

| アクション | HTTP | 認証 | ロール | 所有 / テナントスコープ | 副作用 |
|---|---|---|---|---|---|

- ロール列が空（`authenticate!` だけ）のアクションは P1
- 所有スコープ列は `find` だけでなく `new` / `where` / `update_all` / 一覧も見る。`Model.unscoped` と `tenant_id: params[...]` は未スコープ扱い
- 副作用列が空でないアクションが GET なら P1
- 表は PR 本文か `docs/reviews/` に貼る

## 必ず守る 7 行

1. `Current.tenant` はログイン主体（`@current_user&.tenant || @current_admin&.tenant`）から決める。URL・パラメータ・ヘッダの `tenant_id` を信用しない
2. `unscoped` を書くなら理由をコメントに残し、直後に明示の `where(tenant_id:)` を付ける
3. 受講生の更新系は `current_user.xxx.find`。`params[:user_id]` で本人を決めない
4. 別レコードの紐付け（記事にコース・記事にカテゴリー）は、相手が同じテナントかをモデルで検証する
5. 紐付け / 解除の `update_all` は両方向を同じスコープで対称に書く
6. manager（テナント管理）と admin（講師）の namespace を混ぜない。上位ロールを自動で通さない
7. 認証は既定で全部にかけ、外すものだけ `skip_before_action` で明示する（`auth/login` だけ）。パス前方一致の条件付き `before_action` を書かない

## JWT

- 署名鍵は `ENV['SECRET_KEY_BASE']`。リテラルを置かない
- `authenticate_admin!` 等は `role` と対象テーブルの両方で判定する。`id` が一致しても `role` が違えば弾く
- 有効期限を延ばす・リフレッシュを足す変更は、失効手段（パスワード変更・削除後に旧トークンを無効にする）とセットで

## CORS

`config/initializers/cors.rb` は production で `ENV['FRONTEND_ORIGIN']` の完全一致・`credentials: false`。`*` と部分一致正規表現を足さない。`credentials: true` にするなら Cookie 認証への移行と CSRF 対策をセットで。

## テスト（request spec）

`find` を 1 行足したら、「他人 / 他テナントのレコードで 403 / 404 **かつ DB 不変**」を 1 本足す。テストが無い認可は認可ではない。最小セットは `/security-baseline` の `references/role-boundary.md` §5。

## 兄弟アクションの同値性

片方にガードを足したら、同じリソースを触る兄弟（`update` に足したなら `destroy` / `show` / 一覧）を全部列挙し、欠落を件数とパスで報告する。直すのは依頼された 1 つでよい。

## 秘密

- `.env` / `dev.env` / `master.key` / `credentials/*.key` を `git ls-files` に出さない
- ログ・例外メッセージ・通知にトークンや個人情報を流さない（`logger.info(params.inspect)` を書かない）
- 報告では秘密の値を出さない（パス・行番号・種別・有無だけ）
