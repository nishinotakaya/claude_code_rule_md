# Rails / Ruby の観点（teac-output-new）

> N+1 は bullet（test で raise）、SQL インジェクションは brakeman が担当。rubocop は入っているが CI が無いので、回した結果を「動作確認」に書く。

## 4.1 クエリ
- 不要な `to_a` で全件メモリ展開していないか
- 「なぜここで `includes` が必要か」の設計判断（検出自体は bullet）
- `sanitize_sql_like` を通しているか（LIKE 検索）

## 4.2 トランザクション ★機械化不能
- 複数テーブル更新が 1 つの `transaction` に入っているか
- 「この 2 つの更新は同一トランザクションであるべきか」は業務知識。AI の主戦場

## 4.3 置き場所 ★機械化不能
- Controller に表示ロジック・整形ロジックが漏れていないか
- `*_json` の形が既存と揃っているか（camelCase・`id.to_s`・`iso8601`・包み）
- フロントの interface と一致しているか。改名・削除が入っていたら旧フロントが壊れる（P1）

## 4.4 マイグレーション
- `add_column` のデフォルト値、本番データへの影響、`rollback` で戻せるか
- `NOT NULL` 後付けのバックフィル順序
- データ移行がマイグレーションに混ざっていないか。テナントを明示しているか

## 4.5 認可境界の到達可能性表 ★コントローラ / routes が差分にあれば必ず作る

| アクション | HTTP | 認証 | ロール | 所有 / テナントスコープ | 副作用 |
|---|---|---|---|---|---|

- ロール列が空欄のアクションは P1。「隠しているだけ」は認可の欠落
- 所有スコープ列は `find` だけでなく `new` / `where` / `update_all` / 一覧も見る。`unscoped` と `tenant_id: params[...]` は未スコープ扱い
- 紐付け / 解除の対になる更新は両方向を並べてスコープが対称か見る
- 副作用列が空でないアクションが GET なら P1
- 受講生 API が `params[:user_id]` を見ていたら P1

## 4.6 フォーム ⇔ permit ⇔ サーバー検証 ⇔ 保存 の同値性

| フロントが送るもの | permit | サーバー検証 | 保存 |
|---|---|---|---|

- update が `params[:x] || 初期値` で merge していたら、項目名だけの PATCH で他の設定が初期値に戻る → P1
- 同じモデルを 2 つの namespace（admin / manager）から更新するなら、検証はモデル 1 本に寄っているか
- `*_attributes` の `id` を差し替えて関連先をすげ替えられないか
- `only:` にあるのにアクションが無い、ボタン撤去済みで route が残る

## 4.7 テナント
- 新テーブルに `tenant_id` と default_scope があるか。`Article` と同じ型か
- `Current.tenant` が nil の経路（rake・seed・マイグレーション・manager）で全件に書いていないか
- 紐付け先が同じテナントかのバリデーションがあるか

## 4.8 テスト（request spec）
- 401 / 403 / 他テナント 404 **かつ DB 不変** / 正常系 が揃っているか
- `JwtHelper.encode` のロールが対象 namespace と合っているか
- `skip` / `xit` / 弱いアサーションが増えていないか

## 4.9 旧 ERB 画面
- `/users/learnings` `/admins/learnings` など旧画面が 500 にならないか（モデルの変更が波及する）
- ERB に `<script>` `<style>` `style=""` を足していないか
