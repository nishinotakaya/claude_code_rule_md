# tech-put-app（フロント）の事実

> 実コードと食い違ったら実コードを正とし、このファイルを直す。共通の事実（ロール・API 契約・テナント契約・テストアカウント）は `techput-overview.md`。

## 技術と検証

| 項目 | 値 |
|---|---|
| ランタイム | React 18.2 / Vite 4 / TypeScript 4.9（`moduleResolution: node`） |
| ルーティング | react-router-dom 7 |
| HTTP | axios（`src/lib/api.ts` の 1 インスタンス。各 API は `src/lib/*Api.ts`） |
| UI | Bootstrap 5 + FontAwesome（`main.tsx` で import）+ 自作 CSS（`src/index.css` のデザイントークン、`src/styles/{components,pages}/*.css`） |
| Tailwind | `package.json` と postcss に入っているが `@tailwind` ディレクティブが無く **ユーティリティは生成されない**。新規に Tailwind クラスを書かない |
| ローカル保存 | localforage / IndexedDB（`src/utils/indexedDB.ts`） |
| Markdown | react-markdown + rehype-sanitize（sanitize を外さない） |
| 機械検証 | `npm run build` = `tsc && vite build`。**ESLint もテストランナーも無い**。型エラーはビルドで止まる |
| 画面検証 | Playwright（`/auto-test`）。PC 1440 幅とスマホ 375 幅 |

## ディレクトリ

```
src/
  pages/{users,admins,managers}/    ← ロール別ページ
  components/{user,admin,manager}/  ← ロール別コンポーネント。Layout は UserLayout / AdminLayout / ManagerLayout
  lib/api.ts                        ← axios インスタンス・tokenStorage・インターセプタ
  lib/*Api.ts                       ← API クライアント（型 = バックエンドの *_json と一致させる）
  hooks/                            ← useRequireAuth / useRequireAdmin / useRequireManager / useTenantPath
  utils/indexedDB.ts
  styles/{components,pages}/*.css
  index.css                         ← デザイントークン
```

新しいページはロールのディレクトリに置き、対応する Layout に載せる。横断の部品だけ `components/` 直下か `shared/`。

## 認証の仕組み（`src/lib/api.ts`）

- トークンは localStorage に `user_token` / `admin_token` / `manager_token`（+ `user_tenant_id`）。読み書きは `tokenStorage` に閉じる。新しいキーを増やさない
- リクエストインターセプタが URL に `/admin/` か `/manager/` を含むかでトークンを選ぶ。**管理者 API は `/admin/` 配下、マネージャー API は `/manager/` 配下** に置かないと受講生トークンが付く
- 401 を受けると `tokenStorage.clearAll()` して `/admin/login` / `/manager/login` / `/tenant/:id/users/login` へ遷移する
- httpOnly Cookie への移行は TODO として `api.ts` に書いてある。新規コードはその方向に逆行しない（トークンを URL やクエリに出さない）

## ルート

| ロール | ログイン | ログイン後 |
|---|---|---|
| 受講生 | `/tenant/:tenantId/users/login` | `/dashboard` など（URL に tenantId は無い。`user_tenant_id` と `useTenantPath` で補う） |
| 管理者 | `/admin/login` | `/admin/*` |
| マネージャー | `/manager/login` | `/manager/*` |

固定パスは動的パス（`/:id`）より前に置く。認可ガードは `useRequireAuth` / `useRequireAdmin` / `useRequireManager`。ナビから消すだけでは守れない（API 側の認可が本体）。

## 環境変数

- `VITE_API_URL`（`.env.development.local`、git 管理外）。無いと `api.ts` の既定値 `http://localhost:3000/api/v1` が使われ、バックエンドのポート（`docker-compose.yml` の 3013）とズレる
- 変数を足したら `.env.example` に名前だけ追加する

## git

- origin `1107t/tech-put-app`、統合先 `main`。別 remote（`tetu5473`）があるので push 先を必ず `git remote -v` で確認する
- 作業ブランチの prefix は既存の慣習どおり `feature/` と `fix/`
- `.gitignore` が `.claude/` `CLAUDE.md` `claude_code_rule_md` `teac-output-new` を除外している。ルール一式は `install.sh` で配備し、コミットしない
- バックエンドと対になる変更は **バックエンド PR が `develop`（または `PROGRESS.md` のベース）に入ってから** フロント PR を出す

## 既知の注意

- フロントの `CLAUDE.md` に書かれていたバックエンドのポート 3001 は古い。`../teac-output-new/docker-compose.yml` を見る
- `Users` 向け一覧 API はテナント default_scope が効くブランチ（`feature/React` 系）とそうでないブランチ（`develop`）がある。バックエンドの対象ブランチを `PROGRESS.md` で確認してから画面を作る
