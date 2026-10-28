# レイアウト崩れ トラブルシュート表

使い方: **症状から引き、「確認箇所」を見て、「優先修正」を上から順に試す**。「禁止する応急処置」を使った修正はレビューで差し戻す。ズレを直したら最下部のルールに従って **1 行追加**する（この表は育てる資産）。

## 0. 修正の順番（Discourse `css-repair.md` の「Overflow repair checklist」を要約）

寸法を決め打ちする前に、この順で試す:

1. flex / grid の子に `min-width: 0`（縮まない子は大抵これ）
2. grid は `minmax(0, 1fr)`
3. `max-width: 100%` / `max-height: 100%` で **容器側**に制約させる（幅を推測して書かない）
4. `overflow-wrap: anywhere` / `flex-wrap: wrap` / `table-layout: fixed` / ellipsis を **意図して**使う
5. スクロールは **内容を所有する容器**に付ける。`html { overflow-y: scroll }` / `body { overflow: scroll|hidden }` で辻褄を合わせるのは疑う（iOS で特に壊れる）

## 1. 症状表

| 症状 | 確認箇所 | 典型原因 | 優先修正 | 禁止する応急処置 | 検証条件 | 実例 |
|---|---|---|---|---|---|---|
| カード・パネルが横に溢れる／省略記号（ellipsis）が効かない | 溢れている要素の **親が flex か**、子の computed `min-width` | flex 子の `min-width: auto` | 子に `min-w-0`（BS4: 自作 `.min-w-0`）、必要なら `flex-wrap` | 親 `overflow-hidden`、子 `w-[Npx]` | 最長データで `scrollWidth <= clientWidth` | 勤怠 91ca1d1（請求書プレビュー）、7aa365e（select が横幅を押し広げる: `min-w-0 max-w-full`）、2026-09-04 修正: ProgressPage シート連携 input・KanbanBoard/TaskCard の select（select は**最長 option 幅まで広がる**仕様） |
| 表・カンバン・横長リストがスマホで画面を押し広げる | 要素の **外側**に `overflow-x` 容器があるか | 横スクロール容器が無い／要素自身に付けている | 外側 div に `overflow-x-auto`（BS4: `.table-responsive`）+ `w-full max-w-full` | `body { overflow-x: hidden }` | 375px で表が容器内スクロール、ページは横スクロール無し | 勤怠 af5f2fe（進捗カンバン・対応ログ） |
| ボタン群・タグ・フィルタが狭幅で横にはみ出す | 親 flex の `flex-wrap` | 既定 nowrap | 親 `flex-wrap gap-2`、潰したくない要素 `shrink-0`、改行させない文言 `whitespace-nowrap` | 子に固定幅、`overflow-hidden` | 320px で 2 行に折返し | 勤怠 6462881（サイドバー・ヘッダ）、2026-09-04 修正: BusinessExpensesPage 月ナビ行 `flex-wrap gap-y-2`、BacklogActivitiesPage タブ行は折返しでなく `overflow-x-auto`（タブは 1 行維持） |
| 固定幅の要素（`w-72`・`width: 300px`）がスマホで溢れる | 幅指定にブレークポイント接頭辞があるか | 固定幅がモバイルにも適用 | `w-full sm:w-72`（BS4: `.w-100` + `.col-md-4`） | `hidden sm:block` で消す | 320 / 375px | 勤怠 af5f2fe |
| 長い氏名・URL・全角長文が枠を突き破る | テキスト要素の `overflow-wrap` / `white-space` | 折返し方針未指定 | `break-words` / `wrap-anywhere` / 1 行省略 / `line-clamp-2`（BS4: `.text-truncate` + 親 `.min-w-0`） | サーバ側で文字数カット | 英数字 40 文字連結 + 全角 60 文字 | 勤怠 0f30fce（ドーナツのお題）、f2dd0bd（ユーザー一覧 1 行省略 + `max-w-[7rem]`）、2026-09-04 修正: FolderSaveButtons（非有界の OS フォルダ名 × nowrap → `max-w-full break-words`） |
| サイドバー・モーダル・トーストが重なる／背面に隠れる | stacking context（`transform` / `opacity` / `position` を持つ祖先）、DOM 順 | z-index だけで解決しようとしている | 重ねる要素を **DOM の後**に置き `fixed` + `z-*` を明示、背面オーバーレイ `fixed inset-0` | `z-[9999]` | 375px でサイドバー開閉 | 勤怠 6462881（サイドバーのオーバーレイ化） |
| 高さ固定のカードで内容が見切れる | `height` / `max-height` 固定 | 内容量を想定していない | `min-height` に変更、内側スクロールなら `min-h-0 overflow-y-auto` | `overflow-hidden` で切る、font-size 縮小 | 内容量 3 倍 | 勤怠 0f30fce |
| 縦 flex の内側だけスクロールさせたい | 親 `flex-col` の高さ、子の `min-height` | 子の `min-height: auto` | 親 `h-dvh flex flex-col`、子 `flex-1 min-h-0 overflow-y-auto` | `h-screen`（アドレスバーで溢れる） | iPhone 15 | — |
| `.row` の中身が左右 15px はみ出す（Bootstrap） | `.row` 直下に `.col` 以外があるか、`.col` に margin があるか | 負 margin の相殺が崩れている | 3 層構造に戻す、`.col` の margin を内側要素へ | `.row { margin: 0 }` | 320px | 旧 ERB 画面の inline style 箇所 |
| 列が次の行に落ちる（Bootstrap） | 同一 `.row` の合計列数、`.col` の横 margin / border | 12 超過、または margin で幅超過 | 合計を 12 以下に、margin を除去 | `width: 24%` 等の上書き | md / lg 幅 | — |
| Bootstrap 3 で高さ違いの列が横に引っかかる | float ベースか（3） | float の回り込み | `.clearfix.visible-sm-block` でリセット、または 4 の flex | `height` 固定で揃える | 各ブレークポイント | Bootstrap 3 の旧画面 |
| 説明のつかないズレ（クラスが効かない） | Bootstrap の **バージョン**と読込経路（gem と npm の二重導入、3/4 混在）、4.1.3 に無いユーティリティ（`gap-*` / `overflow-*` / `text-break`） | 存在しないクラスを書いている、CSS の二重定義 | 正しい版のクラスに置換、自作クラスを stylesheet に追加 | inline style | — | `bootstrap-3-4.md` §2 |
| 件数が少ないと間隔が異常に広い | `justify-content: space-between` | 件数依存の配分 | `gap` + `ml-auto` | 空の spacer | 件数 1 / 2 / 10 | — |
| 1 件だけのときカードが横一杯に伸びる | `repeat(auto-fit, ...)` | auto-fit が空トラックを潰す | `auto-fill` | `max-width` 後付け | 件数 1 / 10 | — |
| 画像が歪む／巨大 | `object-fit`、`max-width` | 未指定 | `object-cover aspect-video max-w-full`（BS4: `.img-fluid`） | 画像加工 | 縦長・横長・2000px | — |
| スクロールバーの出現でガタつく | `scrollbar-gutter` | 予約無し | `scrollbar-gutter: stable` | `overflow-y: scroll` 常時 | 件数増減 | — |
| iPhone で入力時にズーム | input の `font-size` | 16px 未満 | `text-base`（BS4: `.form-control-sm` を避ける） | `maximum-scale=1` | iPhone 15 | — |
| モーダル内スクロールが背面に伝播 | `overscroll-behavior` | 未指定 | `overscroll-contain` | body の overflow を JS で付け外しのみ | 末尾まで指スクロール | — |
| 帳票 PDF の行ズレ・1 枚に収まらない | `.tlf` / print CSS | **この skill の範囲外** | `pdf-template` skill（thinreports）、`@page` / `break-inside: avoid` | — | — | 勤怠 d527835 / 8d1bdd2 |

## 2. 「壊れる入力」リスト（実装前に流し込む）

AI は正常系のサンプルデータで画面を組む。以下を **必ず** 1 つ以上入れて確認する。

- 長さ: 氏名 30 文字（全角）、英数字 40 文字連結（URL・ID・メールアドレス）、空文字、`null`
- 文字種: 全角スペース、絵文字、改行無しの長文、翻訳後 1.5 倍の文言
- 件数: 0 / 1 / 100（一覧・タグ・ボタン群・select の選択肢）
- 幅: 320 / 375 / 768 / 1024 / 1440px、ウルトラワイドは 50% ズームで代用
- 高さ: 1024×500（固定ヘッダ・フッタが重ならないか）
- 状態: バリデーションエラー表示中、権限によるボタン増減、ローディング（スケルトンは実寸）
- 環境: iOS Safari（アドレスバー・safe-area・input ズーム）、フォント読込後の再配置、Turbo Frame 内での部分描画、モーダル・ポータル
- 画像: 縦長・横長・404
- データ状態: **条件付きで出現する UI ブロック**（例: ワークスペース種別で出るシート連携欄）を表示状態にして確認する。非表示のままだと棚卸しをすり抜ける（2026-09-04 の /progress@320 で実証）
- 前提: ルート font-size の変更（例: `html { font-size: 19px }` を設定している案件）。rem 由来の幅がデフォルト 16px 計算と変わるため、px の直感で判断しない

## 3. DevTools での診断手順（MDN「Debugging CSS」+ Chrome Flex/Grid overlay）

1. 症状の要素を選択 → **親をひとつずつ上る**。どの階層で幅が想定を超えたかを Computed の `width` で特定
2. その階層の Computed で `display` / `min-width` / `flex-shrink` / `overflow` / `white-space` を見る（`min-width: auto` + `flex-shrink: 1` の組合せが最頻）
3. Elements パネルの **flex / grid バッジ**でオーバーレイを出し、トラック・ギャップ・折返しを目視
4. Styles で **競合しているルール**（打ち消し線）と出所（Bootstrap 本体か自作か inline か）を確認
5. Device toolbar で 320 / 375 / 768 を切替、`document.documentElement.scrollWidth` と `clientWidth` をコンソールで比較
6. 直したら `scripts/overflow_check.spec.ts` を回し、はみ出し要素一覧が空になったことを確認

## 4. 追記ルール

- ズレを直したら、上の表に **症状 / 確認箇所 / 典型原因 / 優先修正 / 禁止する応急処置 / 検証条件 / 実例（プロジェクト + コミット hash）** の 1 行を足す
- 既存行と同じ原因なら「実例」列にコミットを追記するだけにする（行を増やさない）
