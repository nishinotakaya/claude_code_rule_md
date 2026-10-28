# コメントは 1 行 — ❌/✅ 実例

```ruby
# ❌ 2 行以上: 背景・出典・参照先まで盛り込む
# 完了済みレッスンは locked にしない。順次解放の判定はコース内の全件が要るため
# (仕様書 §3.2 準拠。LessonLockCalculator 参照)

# ✅ 1 行: 何のためかだけ
# 完了済みレッスンは locked にしない

# ❌ 出典・指摘元を書く
# テナント違いは 404 にする（PR#12 指摘。403 だと存在が分かるため）

# ✅
# テナント違いは存在を隠して 404

# ❌ 背景・経緯・用途まで盛り込む
# 管理者が記事を e-learning に載せたとき、既存の learnings を補正する。
# Phase 1 で article_type を導入したが旧データは未設定なので、ここで埋めている

# ✅
# 旧データの article_type 未設定を補正する
```

```ts
// ❌ WHAT の言い換え
// ユーザー一覧を取得する
const users = await fetchUsers()

// ✅ 非自明な WHY だけ
// 管理者 API はトークン切替のため URL に /admin/ を含める必要がある
const users = await api.get('/admin/users')

// ❌ インターフェースの各フィールドに同じ調子で説明
interface Lesson {
  id: string        // レッスン ID
  title: string     // タイトル
  locked: boolean   // ロック状態
}

// ✅ 名前で分かるものは無言、分からないものだけ 1 行
interface Lesson {
  id: string
  title: string
  locked: boolean   // サーバが順次解放を計算して返す。クライアントで再計算しない
}
```
