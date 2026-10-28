---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
---

# React / TypeScript の規則

## 型

- `any` を書かない。外から来る値は `unknown` で受けて narrow する。`as` は最小限
- API の型は API クライアント層の interface に置き、バックエンドのレスポンス整形と 1 対 1 で一致させる（`rules/project/overview.md` の API 契約）。片方だけ変えない
- `Omit<T, ...> & {...}` のような難読型には名前を付ける
- `tsc` が通ることが最低線。lint が無いプロジェクトでは、未使用変数・暗黙 any は自分で見る

## コンポーネント

- 関数コンポーネント + hooks。ファイル名 = コンポーネント名（PascalCase）。1 ファイル 1 コンポーネント（小さな補助部品は同居可）
- ロード中 / 空 / エラー / 成功の 4 状態を必ず描く。空フォームが一瞬見える「ちらつき」を出さない
- ユーザー操作（submit / delete）のエラーは画面に出す。`catch` で握りつぶさない。`console.log` を残さない
- 「追加用」「編集用」を別コンポーネントにしない。違いが文言だけなら 1 つを mode で切り替える
- 新しいページは既存の共通レイアウトに載せる。レイアウト自体は極力触らない

## hooks と副作用

- `useEffect` の依存配列を正しく書く（lint が無いプロジェクトでは手で確認）。fetch・ResizeObserver は `useEffect`。`useLayoutEffect` は描画前の同期 DOM 測定だけ
- 認可ガードは既存のものを使う。独自に localStorage を読んで判定しない
- データ取得は API クライアント層経由。コンポーネントから HTTP クライアントや `fetch` を直接呼ばない

## API クライアント

- 共通の HTTP インスタンスを使う。ロール別 API のパス接頭辞はトークン切替の条件になる（`overview.md`）
- リクエスト / レスポンスのキー命名変換が要る場合は、クライアント関数の中に閉じる
- `get` を名前に使うのは同期で軽い取得だけ。API を叩く関数は `fetchXxx` / `createXxx` / `updateXxx` / `deleteXxx`
- 意味を変えた API は、呼び出し元と **その直後にチェーンしている処理**（成功時に続けて呼ぶ別 API・再取得）を全部 grep する

## ルーティング

- 固定パスを動的パス（`/:id`）より前に置く。「閲覧」と「編集」を同じパスにしない
- 多テナントの場合: URL に載せるテナント識別子の扱いは既存のヘルパーに揃える（`overview.md`）

## 永続化（IndexedDB / localStorage）

- DB 接続はモジュール内シングルトン。毎呼び出しで `open` しない
- `put` は全置換。更新時に既存フィールド（`createdAt` など）を落とさない
- 並び順を id に依存させない（`createdAt` で明示ソート）
- localStorage にキーを増やすときは、キーの定義を 1 箇所に置く

## 命名（`naming.md` の補足）

- state は中身の名前（`const [articles, setArticles]`。`data` / `list` にしない）
- イベントハンドラは `handleXxx`、boolean は `isXxx` / `hasXxx` / `canXxx`
- `.map(a => ...)` のような 1 文字のコールバック引数を書かない
