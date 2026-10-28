# 命名規則

> 大原則: 誰が見てもわかる名前。省略しない、曖昧にしない、意図がコードから読み取れること。

## 共通

| 観点 | ❌ | ✅ |
|---|---|---|
| 省略しない | `cnt` / `res` / `cur_acc` / `btn` | `count` / `response` / `current_account` / `submit_button` |
| ブロック・ループ変数も省略しない | `users.each { \|u\| }` / `items.map(i => ...)` | `users.each { \|user\| }` / `items.map(item => ...)` |
| 意図を表す | `data` / `item` / `info` / `tmp` | `article_rows` / `lesson_card` / `customer_info` / `unsorted_records` |
| コレクションは複数形 | 配列を返す `article` | `articles`（配列）/ `article`（1 件） |
| 真偽値は問いの形 | `flag` / `is_not_active` | `completed` / `can_edit` / Ruby は `active?` |
| 重い処理に `get` を使わない | `getUsers()` が API を叩く | `fetchUsers()` / `loadUsers()`。`get` は同期で軽い取得だけ |
| 単位・状態を名前に入れる | `delay` / `token` | `delay_seconds` / `raw_token`（未検証） |
| 引数はキーワードで意味を持たせる | `call(a, b, true)` | `call(account:, partner_id:, with_discarded: true)` |

- 1〜2 文字の名前は **3 行以内のスコープ**、数学的慣習（`x, y`）、慣用（`id`, `url`, `key, value`, `idx`）だけ許容
- 1 つの概念に複数の名前を付けない（`count` と `cnt` を混在させない）
- 新しい名前を発明する前に `grep -rn "<概念>" src/ app/` で既存の呼び方を確認し、同じ概念は同じ語を使う
- Ruby: 破壊的・DB を変えるメソッドは `!`、論理値は `?`。`get_data` ではなく `fetch_active_records` / `find_by_email`
- TypeScript: 関数は動詞始まり、コンポーネントは PascalCase、hooks は `useXxx`、型は名詞（`Omit<T, ...> & {...}` の難読型には名前を付ける）
- ファイル名 = 役割名。`utils.ts` / `helper.rb` のような中身が予測できない名前を作らない

実例集: `/coding-rules` の `references/naming-examples.md`
