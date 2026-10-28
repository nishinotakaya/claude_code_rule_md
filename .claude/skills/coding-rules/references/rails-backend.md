# Rails バックエンド規律（認可・SQL・OO / DRY）

要点は `.claude/rules/coding/rails-api.md` と `.claude/rules/security/rails-authz.md` が自動で読み込まれる。ここは実例。

## 認可・更新・フォームの規律

| 規律 | ❌ | ✅ |
|---|---|---|
| 取得・作成・更新は認証主体 / テナント起点 | `Learning.where(user_id: params[:user_id])` / `Article.unscoped.find(id)` | `current_user.learnings` / `Article.find(id)`（default_scope が効く） |
| namespace ごとにロールガード | `authenticate!` だけ。フロントで隠す | `Api::V1::Admin::BaseController` に `before_action :authenticate_admin!` |
| 副作用のある操作は POST | `GET /lessons/:id/complete` | `post :complete` |
| params に無いキーは触らない | `params[:x] \|\| 初期値` で merge | `params.key?(:x)` のときだけ更新。項目名だけの PATCH で他設定が消えないテスト |
| フロントが送る全キーをサーバーで検証 | フロントの `required` だけ | モデルのバリデーション |
| 使わないルートを残さない | ボタン撤去済みの `destroy` が route に残る | `only:` から外し「削除ルートは無い」をテストで固定 |
| ロジックの置き場 | view / `*_json` で集計 | model → controller → view の順で上に置く |

## SQL / クエリ

```ruby
# ❌ N+1
@articles = Article.all
@articles.each { |article| article.category.name }

# ✅ includes
@articles = Article.includes(:category)

# ❌ SQL injection
Article.where("title LIKE '%#{params[:keyword]}%'")

# ✅ プレースホルダ
Article.where('title LIKE ?', "%#{Article.sanitize_sql_like(params[:keyword])}%")
```

## オブジェクト指向 / DRY

> 同じパターンが 3 箇所以上で繰り返されたら抽出する。処理は変えない。1 箇所変更 → 全体反映。

1. **コントローラ共通フローは concern に**: 「認証 → テナント解決 → 取得 → 整形 → render」が複数コントローラで重複したら `app/controllers/concerns/` へ。block（yield）で固有の追加データを差し込めるようにする
2. **`*_json` の重複は 1 本に**: 同じモデルの JSON 整形が users / admin の両方にあるなら、モデルかシリアライザ 1 本にして両方から呼ぶ
3. **横断的なコンテキストは専用クラスに**: `Current.tenant` の解決のような横断処理を各所で再実装しない
4. **抽出の判断基準**: 3 箇所以上で同一の制御フロー / `if/else` の引数差 < 共通部分 なら抽出。名前は似ているが処理が違うものを無理に抽出しない
5. **リファクタの鉄則**: 動作を変えない（エラーメッセージ・ステータス・レスポンス形式・トランザクション境界は不変）。ついでの修正は別コミット。抽出後は呼び出し全パスを rspec と実機で確認してから終える
