# ロール境界・テナント境界（管理画面 / 多テナント機能）

> 前提: 「ナビに出していない」「ログイン後の遷移先が違う」は認可ではない。URL を直接叩けば届く。認可はルート × ロール × 所有（テナント）の 3 軸で、コントローラ側に機械的に書く。

## 1. 到達可能性表を先に書く

コントローラ（または namespace）を 1 つ追加・変更したら、コードを書く前にこの表を埋める。

| アクション | HTTP | 認証 | ロール | 所有 / テナントスコープ | 副作用 |
|---|---|---|---|---|---|
| `index` | GET | `authenticate_admin!` | admin | `Course.all`（default_scope でテナント） | 無 |
| `create` | POST | 同上 | admin | `Course.new`（`set_tenant_from_owner`） | 作成 |
| `complete` | POST | `authenticate_user!` | user | `current_user.learnings.find` | 更新 |

- **ロール列が「全ロール」のアクションは、なぜ全ロールでよいかを 1 行で書けること。** manager（テナント管理）が admin（講師）の画面に自動で入れるべきではない
- **副作用列が空でないアクションは GET にしない。** GET は CSRF 検証が効かず、img タグやプリフェッチで発火する
- 埋められない列があれば、それが指摘

## 2. ガードの置き場所

| 範囲 | 置き場所 |
|---|---|
| namespace 全体 | その namespace の BaseController に `before_action :authenticate_<role>!`（`Api::V1::Admin::*` は admin、`Manager::*` は manager） |
| 1 コントローラ | 先頭の `before_action`。`only:` で抜け穴を作らない |
| 弾き方 | `render_unauthorized`（401）/ 403 `{ error: '権限がありません' }` / 他テナントは 404。**500 にしない** |

`authenticate_*!` は認証、ロール判定はロール、所有は relation。3 つを 1 つのメソッドに混ぜない。

## 3. 認証主体を起点にする（テーブル起点を書かない）

| ❌ テーブル起点 | ✅ 認証主体 / テナント起点 |
|---|---|
| `Learning.where(user_id: params[:user_id])` | `current_user.learnings` |
| `Article.unscoped.find(params[:id])` | `Article.find(params[:id])`（default_scope が効く） |
| `Course.where(id: ids).update_all(...)` | `Course.where(id: ids)` は default_scope 内。ただし紐付け / 解除の両方向を同じスコープで |
| `Tenant.find(params[:tenant_id])` を admin が受ける | `current_admin.tenant` |

`update_all` を書くときは「付ける側」と「外す側」の両方を列挙し、スコープが対称か見る。

## 4. セッション失効

管理者の削除・パスワード変更・テナントの無効化の後に、既存トークンで引き続き操作できないことをテストで固定する。JWT は 24h 有効なので、失効を即時にしたいなら発行時刻 / バージョンの照合をサーバ側に置く。

## 5. テストの最小セット（コピーして使う）

新しい管理機能ではこの名前のテストが揃うまで完了にしない。

- 未ログイン（Bearer なし / 期限切れ）では 401
- ロール違いのトークン（user トークンで admin API、admin トークンで manager API）は 401 / 403
- 自テナントは一覧を表示できる / **一覧に他テナントのレコードが出ない**
- 他テナントのレコードは取得・編集できない（404 かつ **DB 不変**）
- 副作用アクションは GET では叩けない
- 紐付け解除で他テナントの紐付けは残る
- `*_attributes` の `id` を差し替えても関連先がすげ替わらない
- 削除ルートを撤去したなら「削除ルートは無い」をテストで固定する
- 受講生: 他人の学習記録は完了にできない（`user_id` パラメータを送っても本人の記録だけが変わる）

## 6. フォーム ⇔ permit ⇔ サーバー検証 ⇔ 保存 の同値性

JS を飛ばして POST される前提で、4 つを同じ集合にする。

| 症状 | 直し方 |
|---|---|
| フォームが N 行送るのにサーバー検証が N-1 行 | 行数の定数を 1 つにして form / validation で共有 |
| フォームに無いキーを `\|\| 初期値` で merge | params に無いキーは触らない（`key?` で判定）。項目名だけの PATCH で他設定が消えないテスト |
| 片側の namespace にだけサーバー検証がある | 検証をモデルに 1 本化し、両コントローラから呼ぶ |
| フォーム / API クライアントを別 namespace 用にコピー | 1 つを mode で共用 |
| ルートだけ残った `destroy` | `only:` から外し、テストで固定 |
