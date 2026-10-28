# フロントエンドと依存関係

> いつ読むか: 依存を追加・更新する / `innerHTML`・`dangerouslySetInnerHTML` を書く / CSP を触るとき。

## 1. 依存の監視

- テックプットに Dependabot / CI は無い。依存を 1 つ足したらその場で `npm audit --omit=dev` を回して差分を見る
- 判定は **high の件数が増えていない** こと。「0 にする」を条件にしない（修正版が無い依存があると達成不能で形骸化する）
- `npm audit fix --force` は使わない（メジャー更新を勝手に入れる）
- Rails 側は `bundle exec bundler-audit check --update`
- 導入する場合の `.github/dependabot.yml`:

  ```yaml
  version: 2
  updates:
  - package-ecosystem: npm
    directory: "/"
    schedule:
      interval: weekly
  ```

## 2. XSS シンク

- `src/` で `dangerouslySetInnerHTML` / `innerHTML` を grep し、新設しない。現状の Markdown 描画は `react-markdown` + `rehype-sanitize`。sanitize を外す変更は P1
- ユーザー入力（記事本文・つぶやき・プロフィール）を HTML として描く箇所は、描画経路を 1 つに集約する
- XSS が 1 件通ると localStorage のトークンが抜ける（`auth-boundary.md` §4）

## 3. CSP

Rails は API で JSON しか返さないので、Rails 側に CSP を足しても SPA の HTML には効かない。HTML を配るホスト（Vercel / nginx）側の headers に入れる。

```jsonc
// vercel.json の例
"headers": [{ "source": "/(.*)", "headers": [
  { "key": "Content-Security-Policy", "value": "default-src 'self'; connect-src 'self' https://<API のオリジン>; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'; frame-src https://www.youtube.com; object-src 'none'; frame-ancestors 'none'; base-uri 'self'" },
  { "key": "X-Content-Type-Options", "value": "nosniff" }
]}]
```

YouTube 埋め込みがあるので `frame-src` が要る。入れたら実機で 1 画面開き Console の CSP 違反を確認する。

## 4. 新規パッケージの採用

- 実在するか（LLM が推薦するパッケージの数 % は実在しない）
- 最終リリースが 2 年以内か、週間 DL 数、メンテナ
- 同じことを既存依存（axios / localforage / react-markdown）でできないか
- 追加後に `npm audit --omit=dev` の差分
