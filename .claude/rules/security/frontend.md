---
paths:
  - "src/lib/**"
  - "src/**/*.tsx"
  - "package.json"
  - "vite.config.*"
---

# フロントのセキュリティ規則

## トークン

- 保存・取得・削除は 1 つのモジュール（トークン保管層）に閉じる。新しい localStorage キーを増やさない
- トークンを URL クエリ・ハッシュ・ログ・エラーメッセージに出さない
- 401 の扱いは共通のインターセプタに任せる。各画面で独自にリダイレクトしない
- httpOnly Cookie への移行方向に逆行しない（トークンを別の場所にコピーしない）

## XSS

- `dangerouslySetInnerHTML` / `innerHTML` を新設しない。Markdown は sanitize を通す（例: react-markdown + rehype-sanitize）。sanitize を外す変更は P1
- ユーザー入力（本文・コメント・プロフィール・外部 URL など）を HTML として描く箇所は経路を 1 つに集約する
- 外部 URL（動画埋め込みなど）はホストを許可リストで検証してから iframe に渡す

## 認可は API 側が本体

- ルートガードは UX。本当の境界はバックエンドの認証・認可と所有 / テナントスコープ
- 「ナビから消した」「ボタンを disabled にした」は認可ではない。順次解放などはサーバが 403 を返すところまで作る
- 一般ユーザーの操作で `user_id` や `tenant_id` をリクエストに載せない（サーバが認証主体から決める）

## 依存

- 依存を足したら `npm audit --omit=dev` を回し、high が増えていないことを確認する。`npm audit fix --force` は使わない
- 新規パッケージは実在・最終リリース・DL 数を確認する。既存依存でできないか先に見る
- バンドラ設定（例: Vite の `server.host`）の を `0.0.0.0` にする変更、proxy の追加はレビューで理由を書く

## 環境変数

- `VITE_` 接頭辞の変数はビルド成果物に埋め込まれ、ブラウザから読める。秘密（API キー等）を `VITE_*` に置かない
- `.env.development.local` はコミットしない。`.env.example` に名前だけ
