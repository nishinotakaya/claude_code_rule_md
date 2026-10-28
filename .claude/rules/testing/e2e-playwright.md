# 動作確認（Playwright E2E）

「動作確認して」「ブラウザで見て」と言われたら、実際にブラウザを開いて操作し、結果を報告する。手順の詳細は `/auto-test`。

## 前提

| 項目 | 値 |
|---|---|
| フロント | `npm run dev` → `http://localhost:5173` |
| バックエンド | `docker compose up -d`（`teac-output-new/`）。ホスト側ポートは `docker-compose.yml` の `ports` を正とする（2026-10 時点 `127.0.0.1:3013` → コンテナ 3000） |
| API 向き先 | `tech-put-app/.env.development.local` の `VITE_API_URL`。ずれていたらユーザーに直してもらう |
| 受講生ログイン | `/tenant/<tenantId>/users/login`。seed アカウント `test_user0@gmail.com`〜`test_user29@gmail.com` / `password` |
| 管理者ログイン | `/admin/login`。`test_admin@gmail.com` / `password` |
| マネージャーログイン | `/manager/login`（アカウントは seed を確認） |
| DB 管理 | Adminer `http://localhost:8080`（サーバ `db` / `root` / `password` / `development_db`） |

seed アカウントはローカル開発 DB 専用。本番・ステージングには存在しない。

## 実行

- 先に `curl -s -o /dev/null -w "%{http_code}" <URL>` で両サーバーが応答することを確認する
- PC 幅（1440×900）とスマホ幅（375 幅）の両方で見る。横スクロールが出たら `scrollWidth` / `clientWidth` の数値を添えて報告する
- 受け入れ基準を 1 項目ずつ操作し、OK / NG / 未確認 を分ける
- ダイアログハンドラは 1 回だけ登録する。`waitForTimeout` は操作後 500〜2000ms
- フロントにテストランナーは無い。機械検証は `npm run build`（tsc）と Playwright の 2 本

## 証跡

- `docs/test_evidence/<機能名>/` に `<テストID>_<内容>.png`・`results.json`・`TEST_REPORT.md`（コミットしない）
- 報告には「どの幅で・どのデータで・何が表示されたか」を書く。「見た目を確認した」だけの報告は不可
- 作成したテストデータは可能な範囲で片付ける。本番データは書き換えない
