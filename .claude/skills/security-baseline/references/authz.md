# 認可（誰がどのレコードを触れるか）

> 前提: テックプットに認可フレームワーク（Pundit / CanCanCan）は無い。認可は手書き。入れる / 入れないの議論はしない。抜けを機械的に見つけて型を揃える。

## 1. 未スコープ find の棚卸し

```bash
# 全ヒット（コメント行を除外）
grep -rnE '\.(find|find_by|find_by_id)\(params\[' app/controllers --include='*.rb' | grep -v ':[0-9]*: *#'

# 要確認だけに絞る（明らかにスコープ済みの受け手を引く）
grep -rnE '\.(find|find_by|find_by_id)\(params\[' app/controllers --include='*.rb' | grep -v ':[0-9]*: *#' \
  | grep -vE 'current_user\.|current_admin\.|current_manager\.|@[a-z_]+\.[a-z_]+\.(find|find_by)\('

# default_scope を剥がしている箇所（最も危険な形。除外パターンに足さない）
grep -rn 'unscoped' app/ --include='*.rb'
```

**grep の結果を母集合として扱わない。** `@article_id = params[:id]` と変数に入れてから `find` する形はこのコマンドに出ない。出た行は §2 に進め、出なかった行は §2 の兄弟列挙で拾う。

テックプットでは `default_scope { in_current_tenant }` を持つモデルは `Article.find` でもテナント境界は効く。ただし **所有者境界（受講生 A が受講生 B の学習記録を触れないか）は別** なので、受講生向けの更新系は `current_user.xxx.find` にする。

## 2. 兄弟アクション同値性チェック

未スコープ find を 1 件見つけたら、そのモデルを解決している全箇所を列挙して防御レベルが揃っているかを見る。

1. 対象モデル名を決める（例 `Learning`）
2. 解決箇所を全部出す
   ```bash
   grep -rnE 'Learning\.(find|find_by|where|new|create|unscoped)' app/controllers --include='*.rb'
   ```
3. 各行をスコープ済み / 未スコープに振り分ける
4. `before_action :set_xxx` の中身も見る（本体に find が無くてもそこでスコープしている）
5. 集中管理された before_action は中身を読む。名前が `authorize` でも認証だけのことがある
6. 揃っていなければ片方だけ直さず、兄弟全部を列挙して報告する

## 3. 手書き認可の型

| 状況 | 置き場所 |
|---|---|
| 単一レコードの所有者判定 | find の直後。1 行の述語メソッド（`can_edit_article?(article)`）に切り出す |
| 兄弟アクションで使い回す | private 述語 1 本に寄せる。述語があるのにインラインで書き直したら drift の始まり |
| コントローラ共通のスコープ | `before_action` でスコープ済み ivar を作る |
| 全体のロール判定 | `Api::V1::BaseController` の `authenticate_admin!` / `authenticate_manager!` |
| 一覧と単体で同じ条件 | スコープを 1 本作って両方から呼ぶ。**一覧だけ絞って単体が素、が最頻出の抜け** |

**命名**: 「誰が何をできるか」が読める形（`can_submit?` / `can_edit_article?`）。`check` / `chk` / `auth?` は禁止。`authenticate_*` と `can_*?` を混ぜない。

未スコープ find を残す判断は「このリソースは全ユーザー共通である」をコード上のコメントで残したときだけ許される。

## 4. テスト

request spec で **403 / 404 と副作用ゼロを両方アサートする**。

```ruby
it '他テナントの記事は更新できず DB も変わらない' do
  patch "/api/v1/admin/articles/#{other_tenant_article.id}", params: { title: 'x' }, headers: admin_headers
  expect(response).to have_http_status(:not_found)
  expect(other_tenant_article.reload.title).not_to eq('x')
end
```

`expect(response).to have_http_status(:forbidden)` だけでは、403 を返しつつ更新は通っている実装を見逃す。正常系も 1 本書く（拒否だけ書くと「全部 403」の実装がテストを通る）。

**完了の定義**: `find(params[...])` を 1 行追加したら、「他人 / 他テナントのレコードで 403 / 404 かつ変化なし」のテストを 1 本追加する。テストが無い認可は認可ではない。
