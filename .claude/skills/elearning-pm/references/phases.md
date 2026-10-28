# フェーズ別スコープ

各フェーズの「バックエンド」「フロント」は、そのフェーズで触ってよい範囲の上限。ここに無いものを足したくなったら範囲変更として止める。
API・テーブルの名前は案。Phase 0 の設計書（`tech-put-app/docs/e-learning/architecture.md`）で確定したら、そちらを正としてこのファイルを直す。

## 目次

- Phase 0 要件確定
- Phase 1 掲載の有無と受講（歩く骨格）
- Phase 2 コース
- Phase 3 カテゴリー
- Phase 4 学習進捗
- Phase 5 仕上げ

---

## Phase 0 要件確定

ゴール: 下の未確定事項に答えが付き、4 文書が `tech-put-app/docs/e-learning/` に確定している。コードは書かない。

| # | 決めること | 推奨（理由） |
|---|---|---|
| Q1 | 「e-learning 掲載の有無」をどう持つか | 既存 `articles.article_type`（`e-learning` / `normal`）を使い続ける。旧 ERB と seed がこの値に依存している。専用の真偽カラムへ分ける案は影響が広いので採らない |
| Q2 | 順次解放（前のレッスンを完了しないと次が読めない）を残すか | 残す。旧 ERB の既存仕様。判定はサーバ側で行う |
| Q3 | 記事 1 件が属するコースの数 | 1 つ（`articles.course_id`）。順番と順次解放が単純になる |
| Q4 | e-learning 記事はコース必須か | 必須。既存 e-learning 記事はテナントごとの既定コースへ移す。旧 ERB フォームからの投稿も既定コースへ入れる |
| Q5 | 記事とカテゴリーの関係 | 多対多。現行のダミー表示に「HTML,CSS」と複数付いた例がある |
| Q6 | カテゴリーを受講生の通常記事にも付けるか | Phase 3 では e-learning 記事だけ。通常記事への展開は別件 |
| Q7 | 管理者自身の完了記録（`learnings.admin_id`）を React 側でも使うか | 使わない。管理者は受講状況を見る側に徹する。既存の管理者行は残す |
| Q8 | 完了の取り消し・再受講を許すか | 許さない。順次解放と進捗率の計算が単純になる |
| Q9 | 公開の単位 | コース単位の `published` だけ。レッスン単位の下書き・公開期間は作らない。非公開に戻しても完了記録は消さない |
| Q10 | 進捗率の分母 | 公開中コースの現在のレッスン数。レッスンを足すと率は下がる |
| Q11 | フロントにテストランナー（Vitest）を入れるか | このフェーズ群では入れない。受講生のリポジトリへの依存追加になるため別件。代わりに各フェーズで Playwright 通過を必須にする |
| Q12 | 旧 ERB の e-learning 画面の扱い | 並行稼働させる。各フェーズの完了ゲートで 500 にならないことを確認し、導線を外すかは Phase 5 で決める |
| Q13 | 各リポジトリのベースブランチ | フロント `origin/main`、バックエンド `origin/feature/React`。着手時に PR #288 の状態を確認する |

---

## Phase 1 掲載の有無と受講（歩く骨格）

ゴール: 管理者が記事フォームで「e-learning に掲載する / しない」を選べる。受講生が実データの e-learning 一覧からレッスンを開き、完了を付けると次のレッスンが開く。

バックエンド:
- `learnings` の健全化を最初にやる。①重複・孤児（記事や受講生が消えた行）・テナント不整合を件数で調べる → ②補正内容を CTO 経由で社長に見せて承認を得る → ③`tenant_id` 追加と埋め戻し、一意インデックス `(learner_id, learned_article_id)`、外部キー
- `Article`: `article_type` を `e-learning` / `normal` / nil に制限。`has_many :learnings` に `foreign_key: :learned_article_id, dependent: :destroy`
- 受講生の記事 API: `article_params` から `article_type` を外す。`GET /api/v1/articles` は e-learning 記事を返さない
- 管理者の記事 API: `GET /api/v1/admin/articles?article_type=e-learning` で絞り込める
- 新規 `GET /api/v1/lessons`（e-learning 記事を順番どおりに、`completed` と `locked` 付きで）、`GET /api/v1/lessons/:id`（本文付き。`locked` なら 403）
- `POST /api/v1/learnings`: e-learning 記事以外と `locked` のレッスンを拒否する。同じレッスンへ 2 回送っても 1 行のまま
- `GET /api/v1/admin/learnings`: 自テナントの記録だけ返す

フロント:
- `src/pages/admins/article/New.tsx`, `Edit.tsx`: 掲載有無のセレクト。新規は未選択から始め、選ぶまで投稿できない（旧 ERB と同じ）。`Index.tsx`: e-learning バッジ
- `src/lib/lessonApi.ts`（新規）、`src/pages/users/DashboardPage.tsx` を API 化、`src/pages/users/lesson/Show.tsx`（新規）と `/lessons/:id` ルート、完了ボタン

受け入れ基準の候補:
- 受講生トークンで `article_type: 'e-learning'` を送っても e-learning 記事にならない
- 1 件目だけ `locked: false`。1 件目を完了すると 2 件目が `locked: false` になる
- `locked` のレッスンは API を直接叩いても本文が返らない
- 完了済みのレッスンは `locked` にならない
- 他テナントの e-learning 記事・完了記録が一覧にも詳細にも出ない
- 受講生の記事一覧に e-learning 記事が混ざらない
- 旧 ERB の `/users/learnings` が開き、完了を付けられる

範囲外: コース、カテゴリー、進捗率、記事一覧のページネーション

---

## Phase 2 コース

ゴール: 管理者がコースを作り、レッスンを入れて並べ替えられる。受講生はコースを選んでレッスンを順に進める。順次解放はコース単位になる。

バックエンド:
- テーブル `courses`（`tenant_id`, `title`, `description`, `position`, `published`）。`articles` に `course_id`, `course_position`
- 移行: テナントごとに既定コースを 1 つ作り、既存 e-learning 記事を作成日時順に入れる。テナントを明示して回す
- `Course` は `Article` と同じテナント分離の型で書く。記事にコースを付けるとき、コースが同じテナントかをモデルで検証する
- コース未指定の e-learning 記事は既定コースの末尾へ入る（旧 ERB フォーム対策）
- 順番: 並べ替え API がコース内の `course_position` を 1 から振り直す。並びは `course_position, id` の順で安定させる。一意インデックスを張るかは設計書で決める（MySQL は遅延制約が無く、張ると振り直しが 2 段階になる）
- 管理者 `/api/v1/admin/courses` の CRUD、レッスン並べ替え `PATCH /api/v1/admin/courses/:id/lesson_order`
- 管理者の記事 API が `course_id` を受け取る（normal のとき nil）
- 受講生 `GET /api/v1/courses`（公開中のみ）、`GET /api/v1/courses/:id`（レッスン一覧を `completed` / `locked` 付きで）。`lessons` の JSON に `courseId` を足す

フロント:
- 管理者: `/admin/courses` 一覧・新規・編集・並べ替え。サイドバーにコースを追加。記事フォームにコース選択
- 受講生: `/dashboard` をコース一覧へ、`/courses/:id` をレッスン一覧へ。`src/lib/courseApi.ts`（新規）

受け入れ基準の候補:
- 非公開コースとそのレッスンは受講生に見えない（一覧・詳細・直 URL とも）
- コース A の 1 件目が未完了でも、コース B の 1 件目は読める
- 並べ替え後の順番で `locked` が決まる。完了済みのレッスンは並べ替え後も読める
- 移行後、既存 e-learning 記事が全件どこかのコースに入っている
- 他テナントのコースを ID 指定しても 404。他テナントのコース ID を記事に付けられない
- 旧 ERB のフォームから e-learning 記事を投稿できる

範囲外: カテゴリー、進捗率、コースごとの受講者割り当て（全受講生が全公開コースを見られる前提）

---

## Phase 3 カテゴリー

ゴール: 管理者がカテゴリーを作り、レッスンに複数付けられる。受講生はカテゴリーを見て絞り込める。

バックエンド:
- テーブル `categories`（`tenant_id`, `name`。一意 `(tenant_id, name)`）、`article_categories`（一意 `(article_id, category_id)`、両側に外部キー）
- 紐付けるとき、記事とカテゴリーが同じテナントかをモデルで検証する
- 管理者 `/api/v1/admin/categories` の CRUD。記事 API が `category_ids` を受け取る
- 受講生 `GET /api/v1/categories`。`lessons` と `courses/:id` の JSON に `categories: [{ id, name }]`。`GET /api/v1/lessons?category_id=`

フロント:
- 管理者: `/admin/categories` 管理画面。記事フォームにカテゴリー複数選択
- 受講生: レッスンカードにカテゴリー表示（ハードコードの置き換え）、絞り込み。`src/lib/categoryApi.ts`（新規）

受け入れ基準の候補:
- 同じテナントで同名のカテゴリーは作れない。別テナントなら作れる
- 他テナントのカテゴリー ID を記事に付けようとすると拒否される
- 使用中のカテゴリーを消したときの挙動が仕様書どおり（消せない、または紐付けごと消える）
- 絞り込んでも `locked` の判定は変わらない

範囲外: 通常記事へのカテゴリー付与、カテゴリーの階層、進捗率

---

## Phase 4 学習進捗

ゴール: 受講生が自分のコース進捗率を見られる。管理者が受講生別・コース別の受講状況を見られる。

バックエンド:
- `learnings` に `completed_at`
- `GET /api/v1/courses` に `lessonCount` / `completedCount`
- 管理者 `GET /api/v1/admin/users/:user_id/learnings`（受講生別）、`GET /api/v1/admin/courses/:id/progress`（コース別）

フロント:
- 受講生: コースカードに進捗バー、完了したコースの表示
- 管理者: `/admin/dashboard`（サイドバー「e-learning」）を受講状況一覧へ。ユーザー詳細に進捗

受け入れ基準の候補:
- 進捗率の分母は Q10 の決定どおり
- 削除されたレッスンの完了記録が率に混ざらない
- 管理者は他テナントの受講生の進捗を見られない

範囲外: 修了証、通知、学習時間の計測

---

## Phase 5 仕上げ

ゴール: 通しで動かした証跡と、講師・受講生が再現できるデータが揃っている。

- `db/seeds.rb`: コース・カテゴリー・レッスン・完了記録の標準データ
- Playwright で通し（管理者がコース作成→レッスン投稿→受講生が受講→管理者が進捗確認）を PC とスマホ幅で
- 動作確認書（`dousa-kakunin`）
- 旧 ERB の e-learning 画面の導線を残すか外すかを Q12 に沿って決め、実施する
- `tech-put-app/CLAUDE.md` のバックエンドポート表記と README のルート一覧を実装に合わせる

範囲外: 新機能
