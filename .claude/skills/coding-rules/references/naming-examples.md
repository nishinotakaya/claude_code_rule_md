# 命名の悪い例 vs 良い例（実例）

## メソッド名

```ruby
# ❌ NG
def get_data(id)        # 何の data？
def chk(c)              # 何を check？引数 c は何？
def proc_arr(arr)       # arr って何の配列？
def calc(x, y)          # 何の計算？

# ✅ OK
def find_article(article_id)
def admin?(account)
def normalize_lesson_orders(lessons)
def calculate_progress_rate(completed_count, total_count)
```

```ts
// ❌ NG
const getUsers = async () => api.get('/admin/users')   // get なのに API を叩く
const d = res.data
const handle = () => {}

// ✅ OK
const fetchUsers = async () => api.get('/admin/users')
const userRows = response.data.users
const handleSubmitArticle = () => {}
```

## ブロック・ループ変数は必ずフルネーム

```ruby
users.each do |u|         # ❌
items.each { |i| ... }    # ❌
@records.each do |r|      # ❌

users.each do |user|                 # ✅
items.each { |item| ... }            # ✅
lesson_progresses.each do |lesson_progress|  # ✅（長くてもフルで書く）
```

```ts
articles.map(a => a.title)             // ❌
articles.map(article => article.title) // ✅
```

**Why**: 1〜2 文字の省略名は読み手に思い出させるコストがかかる。`e` は `error` か `event` か `entry` か曖昧。IDE 補完が効くので長くても書くコストは変わらない。

**例外**（慣用的な短い名前）:

```ruby
users.each_with_index do |user, idx|   # idx は慣用
hash.each do |key, value|              # key / value は慣用
```

```ts
items.reduce((total, item) => total + item.price, 0)  // total / item はフル
```

主変数（`user`, `item`）はフルネーム原則を守る。

## 引数・変数

| 観点 | ❌ | ✅ |
|---|---|---|
| キーワード引数 | `def call(a, b, c)` | `def call(tenant:, article_id:, with_discarded: false)` |
| 引数名は呼び出し側からも読める | `def search(p)` | `def search(keyword:)` |
| スコープが短くても省略しない | `r = User.find(id); r.name` | `record = User.find(id); record.name` |
| 型が分かる名前 | `data = ...` | `article_rows = ...` / `member_count = ...` |
| temp も意味を持たせる | `tmp = ...` | `unsorted_records = ...` |
| bool に意味を持たせる | `flg = true` | `completed = true` / `hasActiveCourse = true` |
| React state | `const [data, setData]` | `const [articles, setArticles]` |

## ファイル名

| ❌ | ✅ |
|---|---|
| `utils.ts` / `helper.rb` / `common.css` | `dateFormat.ts` / `tenant_scoping.rb` / `article-card.css` |
| `Page2.tsx` / `NewComponent.tsx` | `AdminCoursesPage.tsx` / `LessonCard.tsx` |
