# 勤怠取消・下書きボタンアクション テストケース作成

**対象ブランチ**: `feature/SAP-3654/kintai_torikeshi_draft_btn_action`

以下のファイルと仕様を参照して、`docs/kintai/SAP-3654_勤怠申請移行_バッチ/` 配下に `kintai_btn_action_test_cases.md` を作成してください。

---

## 対象ファイル

- `app/controllers/kintai/kintai_controller.rb` — メインのコントローラ
- `app/views/kintai/kintai/index.html.erb` — 取消確認画面
- `app/views/kintai/kintai/draft.html.erb` — 下書き作成確認画面
- `app/views/kintai/kintai/draft_complete.html.erb` — 下書き作成完了画面
- `app/views/kintai/kintai/cancel.html.erb` — 取消完了画面
- `app/services/cancel_service.rb` — 取消APIサービス
- `config/routes.rb` — ルーティング定義

---

## ルーティング

| ルート名                    | パス                                                   | アクション            |
| ----------------------- | ---------------------------------------------------- | ---------------- |
| `kintai_cancel`         | `GET /jobcan/kintai/cancel/:jobcan_id/:cuid/:user_id` | `kintai#index`   |
| `kintai_cancel_cancel`  | `GET /jobcan/kintai/cancel_do/:jobcan_id/:cuid/:user_id` | `kintai#cancel`  |
| `kintai_draft`          | `GET /jobcan/kintai/draft/:jobcan_id/:cuid/:user_id`  | `kintai#draft`   |
| `kintai_draft_complete` | `GET /jobcan/kintai/draft_complete/:jobcan_id/:cuid/:user_id` | `kintai#draft_complete` |

---

## コントローラアクション仕様

### `index`（取消確認画面表示）

- `jobcan_id` + `cuid` で `JobcanRequest` を検索
- `cuid` が一致し `user_id` が存在する場合のみ `@jobcan_request` にセット
- それ以外は `@jobcan_request = nil`

ビュー表示条件:
- `@jobcan_request.status == '1'` → 「申請を取消します」ボタン表示
- `@jobcan_request.status == '2'` → 「承認済みを完了後取消します」ボタン表示
- `@jobcan_request.status` が `1`, `2` 以外 → 「この申請は取消できません」エラー
- `@jobcan_request == nil` → 「申請情報が取得できませんでした」エラー

### `draft`（下書き作成確認画面表示）

- `jobcan_request.status == '1'` の場合のみ `enqueue_update_request` を呼び出し
- `@jobcan_request` のセット条件は `index` と同じ

ビュー表示条件:
- `@jobcan_request.status == '2'` → 下書き作成確認ボタン表示
- `@jobcan_request.status != '2'` → 「予定申請が最終承認されていないため…」エラー
- `@jobcan_request == nil` → 「申請情報が取得できませんでした」エラー

### `draft_complete`（下書き作成実行）

- `JobcanRequest` が見つからない場合 → `kintai_draft_path` にリダイレクト（alert付き）
- 見つかった場合 → `KintaiDraftWorker.new.perform(jobcan_request.view_id)` を実行

### `cancel`（取消実行）

- `JobcanRequest` が見つからない場合 → `@jobcan_request = nil` で `index` をレンダリング
- `request_json['status'] == 2`（完了後取消）: `cancel_after_finish` を呼び出し、`status = '6'` に更新
- `request_json['status'] == 1`（取消）: `wf_user_id` を取得し `proxy_login` + `cancel` を呼び出し、`status = '4'` に更新
- その他 → `raise "申請書が取得できませんでした"`
- 成功時 → `UpdateRequestWorker` と `enqueue_update_request` を呼び出し、`cancel` ビューをレンダリング
- 例外発生時 → `@error_message` をセットし `index` を `422` でレンダリング

---

## テストケース作成の指示

以下の観点で網羅的なテストケース表（Markdown テーブル）を作成してください。

1. **正常系**: 各アクションが期待通りに動作するケース（status別）
2. **異常系・エラー系**: `JobcanRequest` が存在しない、ステータス不正、API失敗など
3. **セキュリティ**: `cuid` 不一致、`user_id` 不在時の挙動
4. **エンドツーエンド**: ボタン押下 → アクション実行 → ビュー/リダイレクトの流れ

フォーマットは既存のテストケースファイル（`docs/kintai/SAP-3654_勤怠申請移行_バッチ/kintai_draft_worker_test_cases.md`）を参考にしてください。

手動確認手順・確認用SQLクエリも含めてください。

---

## 関連JobcanStatusコード

| status | 意味      |
| ------ | ------- |
| 0      | 下書き     |
| 1      | 進行中（申請中）|
| 2      | 完了（承認済）|
| 3      | 差し戻し    |
| 4      | 取り消し    |
| 5      | 却下      |
| 6      | 完了後取消   |
