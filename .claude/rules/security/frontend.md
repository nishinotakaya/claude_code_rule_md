---
paths:
  - "src/lib/**"
  - "src/**/*.tsx"
  - "package.json"
  - "vite.config.ts"
---

# フロントのセキュリティ規則（tech-put-app）

## トークン

- 保存・取得・削除は `src/lib/api.ts` の `tokenStorage` に閉じる。新しい localStorage キーを増やさない
- トークンを URL クエリ・ハッシュ・ログ・エラーメッセージに出さない
- 401 の扱いは `api.ts` のインターセプタに任せる。各画面で独自にリダイレクトしない
- httpOnly Cookie への移行方向に逆行しない（トークンを別の場所にコピーしない）

## XSS

- `dangerouslySetInnerHTML` / `innerHTML` を新設しない。Markdown は react-markdown + rehype-sanitize を通す。sanitize を外す変更は P1
- ユーザー入力（記事本文・つぶやき・プロフィール・YouTube URL）を HTML として描く箇所は経路を 1 つに集約する
- 外部 URL（YouTube 埋め込み）はホストを許可リストで検証してから iframe に渡す

## 認可は API 側が本体

- `useRequireAdmin` 等のルートガードは UX。本当の境界はバックエンドの `authenticate_*!` と所有 / テナントスコープ
- 「ナビから消した」「ボタンを disabled にした」は認可ではない。順次解放などはサーバが 403 を返すところまで作る
- 受講生の操作で `user_id` や `tenant_id` をリクエストに載せない（サーバが JWT から決める）

## 依存

- 依存を足したら `npm audit --omit=dev` を回し、high が増えていないことを確認する。`npm audit fix --force` は使わない
- 新規パッケージは実在・最終リリース・DL 数を確認する。既存依存（axios / localforage / react-markdown）でできないか先に見る
- `vite.config.ts` の `server.host` を `0.0.0.0` にする変更、proxy の追加はレビューで理由を書く

## 環境変数

- `VITE_` 接頭辞の変数はビルド成果物に埋め込まれ、ブラウザから読める。秘密（API キー等）を `VITE_*` に置かない
- `.env.development.local` はコミットしない。`.env.example` に名前だけ
