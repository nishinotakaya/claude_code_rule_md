# Defensive CSS チェックリスト（25 tips → 症状別の判定表）

出典: Ahmad Shadeed「Defensive CSS」 https://defensivecss.dev/tips/（2026-09-01 時点 25 tips）。本文は要約・言い換え。原文の図解は出典を参照。
使い方: **症状の列から引く**。優先修正は「素 CSS」を正とし、Bootstrap 4.1 / Tailwind v4 の列はそのクラスへの翻訳。「禁止する応急処置」は見た目だけ直して原因を残す手（レビューで差し戻す）。

## A. 幅・折返し・はみ出し（実害の 8 割はここ）

| # | tip | 症状 | 典型原因 | 優先修正（素 CSS） | Bootstrap 4.1 | Tailwind v4 | 禁止する応急処置 | 検証条件 |
|---|---|---|---|---|---|---|---|---|
| A1 | Minimum Content Size In CSS Flexbox | `truncate` が効かない / flex 子が縮まず親からはみ出す / select が長い選択肢で横幅を押し広げる | flex 子の `min-width` 既定は `auto`（内容幅より縮まない） | 縮む側の flex 子に `min-width: 0`（縦は `min-height: 0`） | ユーティリティ無し → stylesheet に `.min-w-0 { min-width: 0; }` を定義して付ける | `min-w-0`（必要なら `max-w-full` 併用） | 親に `overflow: hidden`、子に固定 `width` | 最長データで `scrollWidth <= clientWidth` |
| A2 | Minimum Content Size In CSS grid | grid の 1 列が内容幅で膨らみ他列を潰す / はみ出す | `1fr` の最小値は `auto`（= min-content） | `minmax(0, 1fr)` か子に `min-width: 0` | grid 非対応。`.row > .col` なら col に `.min-w-0` | `grid-cols-N` は `minmax(0,1fr)` を生成するので安全。任意値で `1fr` を書くときだけ `minmax(0,1fr)` にする | `overflow: hidden` | 同上 |
| A3 | Flexbox Wrapping | 狭幅でボタン群・タグが横に押し出され画面外へ | flex 親の `flex-wrap` 既定は `nowrap` | `flex-wrap: wrap` + `gap` | `.d-flex.flex-wrap`（gap 無し → 子に `.mr-2.mb-2`） | `flex flex-wrap gap-2` | 子に固定幅を足して無理に収める / `overflow: hidden` | 320px で 2 行に折り返す |
| A4 | Long Content | 長い氏名・URL・全角長文が枠を突き破る | 折返し / 切詰め方針が未指定 | 複数行: `overflow-wrap: anywhere`。1 行: `white-space: nowrap; overflow: hidden; text-overflow: ellipsis`。N 行: `-webkit-line-clamp` | `.text-truncate`（親に幅か `.min-w-0` が要る）。`.text-break` は 4.3+ なので 4.1.3 は自作 | `truncate` / `line-clamp-2` / `break-words`（v4.1+ は `wrap-anywhere`） | サーバ側で文字数を切る / 固定 px 幅 | 英数字 40 文字連結 + 全角 60 文字を流す |
| A5 | Fixed sizes | 文字量が増えると枠から溢れる・見切れる（高さ固定カード等） | `height` / `width` の固定 | `min-height` / `min-width` に置換、幅は `max-width: 100%` | 固定 `.h-100` を避け `.mw-100`。min-height は自作 | `min-h-24` / `w-full max-w-md`（`h-24` 固定は避ける） | `overflow: hidden` で切る / font-size を縮めて詰める | 内容量 3 倍 |
| A6 | CSS grid fixed values | サイドバー+本文の grid が狭幅で横スクロール | `grid-template-columns: 250px 1fr` の固定値 | `minmax(min(250px, 100%), 1fr)` / `repeat(auto-fit, minmax(min(250px,100%), 1fr))` | `.col-md-3` + `.col-md-9`（md 未満で縦積み） | `grid-cols-1 md:grid-cols-[250px_1fr]` | `overflow-x: hidden` | 320px |
| A7 | Auto-fit vs Auto-fill | 件数 1 のときカードが横一杯に伸びて巨大化 | `auto-fit` は空トラックを潰して伸ばす | 幅を保つなら `auto-fill` | `.col-md-4` 固定なら無関係 | `grid-cols-[repeat(auto-fill,minmax(16rem,1fr))]` | 後付け `max-width` | 件数 1 と 10 |
| A8 | Using space-between | 件数が少ないと間隔が異常に広い | `justify-content: space-between` は件数依存 | `gap` で固定間隔、末尾寄せは `margin-left: auto` | `.justify-content-between` を避け `.mr-2` + `.ml-auto` | `gap-4` + `ml-auto` | 空の spacer div | 件数 1 / 2 / 10 |
| A9 | Component Spacing | アイコンと文字・アバターと名前が密着 / 衝突 | 余白を空白文字や親幅に依存 | 要素間に `gap` か `margin-inline-start` | `.mr-2` | `gap-2` | `&nbsp;` | 名前 30 文字 |
| A10 | Default flexbox stretching | flex 行内の画像・ボタンが縦に伸びて歪む | `align-items: stretch` 既定 | `align-items: flex-start`（または子に `align-self`） | `.align-items-start` / `.align-self-start` | `items-start` / `self-start` | 子に固定 height | 隣の要素が 3 行になる |
| A11 | Button minimum width | 「OK」「はい」など短いラベルのボタンが極端に小さい | 内容幅依存 | `min-width: 6rem`（並ぶボタンは同幅） | 自作 `.btn-min` | `min-w-24` | ラベルに全角スペース詰め | 「OK」と「キャンセルして戻る」を並べる |

## B. 画像・メディア

| # | tip | 症状 | 典型原因 | 優先修正（素 CSS） | Bootstrap 4.1 | Tailwind v4 | 禁止する応急処置 | 検証条件 |
|---|---|---|---|---|---|---|---|---|
| B1 | Image Distortion | 画像が縦横比を崩して潰れる | `width` + `height` 指定で `object-fit` 無し | `object-fit: cover`（+ `aspect-ratio`） | `.img-fluid`。object-fit は自作 | `object-cover aspect-video` | 画像を加工して合わせる | 縦長・横長 2 枚 |
| B2 | Image maximum width | 大きい画像がコンテナ幅を超えて横スクロール | `img` に `max-width` 無し | ベースに `img { max-width: 100%; height: auto; }` | `.img-fluid` | Preflight が `max-width:100%` を付与（無効化していなければ） | 個別に width 固定 | 2000px 幅の画像 |
| B3 | Text over image | 画像の読込失敗・明るい画像で文字が読めない | 背景色 fallback とオーバーレイ無し | `background-color` を必ず併記 + グラデーションオーバーレイ | `.bg-dark` + 自作 overlay | `bg-gray-900 bg-[url(...)]` + `bg-linear-to-t from-black/60` | `text-shadow` だけ | 画像 URL を 404 にする |
| B4 | Image inner border | 白背景ロゴ・アバターが背景に溶けて境界が消える | 画像自身の余白色 | `outline: 1px solid rgb(0 0 0 / .1); outline-offset: -1px`（img は疑似要素不可） | `.border` | `ring-1 ring-inset ring-black/10` | 画像を再加工 | 白ロゴ |
| B5 | Background repeat | 大画面で背景画像がタイル状に繰り返す | `background-repeat` 既定 `repeat` | `background-repeat: no-repeat; background-size: cover` | 自作 | `bg-no-repeat bg-cover` | 画像を巨大化 | 2560px 幅 |

## C. スクロール・固定・重なり

| # | tip | 症状 | 典型原因 | 優先修正（素 CSS） | Bootstrap 4.1 | Tailwind v4 | 禁止する応急処置 | 検証条件 |
|---|---|---|---|---|---|---|---|---|
| C1 | Scrollbars on demand | 内容が少なくても常にバーが出る / 横に長い表が画面を押し広げる | `overflow: scroll` or 未指定 | `overflow-y: auto`。横長の表・カンバンは **要素の外側の div** に `overflow-x: auto` | `.table-responsive`（`.overflow-auto` は 4.4+ なので 4.1.3 は自作） | `overflow-x-auto`（容器） / `overflow-y-auto` | `overflow: hidden` で見切る / `body { overflow-x: hidden }` で全体を隠す | 12 列の表を 375px |
| C2 | Scroll chaining | モーダル内を末尾までスクロールすると背面ページが動く | overscroll の伝播 | `overscroll-behavior: contain`（モーダル・ドロワー・ドロップダウン） | 自作 | `overscroll-contain` | body の `overflow:hidden` を JS で付け外しだけ | iPhone 幅で末尾まで指スクロール |
| C3 | Scrollbar gutter | スクロールバーの出現で左右にガタつく（layout shift） | バー幅の予約無し | `scrollbar-gutter: stable` | 自作 | `[scrollbar-gutter:stable]` | `overflow-y: scroll` 常時表示 | 件数が増減するリスト |
| C4 | Position sticky with CSS Grid | grid / flex 内の sticky サイドバーが張り付かない | `align-items: stretch` で高さが伸び切り、動く余地が無い | sticky 要素に `align-self: start` | `.align-self-start` + `.sticky-top` | `sticky top-0 self-start` | `position: fixed` に逃げる | 長い本文でスクロール |
| C5 | Vertical media queries | 高さの低い画面で固定ヘッダ・フッタ・サイドバー項目が重なる | 幅だけでブレークポイント判定 | `@media (min-height: 600px)` の中でだけ固定配置 | 自作 | `[@media(min-height:600px)]:sticky`（任意バリアント） | `position: fixed` 固定 | 1024×500 |

## D. 入力・タッチ・その他

| # | tip | 症状 | 典型原因 | 優先修正（素 CSS） | Bootstrap 4.1 | Tailwind v4 | 禁止する応急処置 | 検証条件 |
|---|---|---|---|---|---|---|---|---|
| D1 | Input zoom on iOS Safari | iPhone で input にフォーカスすると画面がズームして崩れる | input の `font-size` < 16px | `input, select, textarea { font-size: 16px; }`（モバイル） | `.form-control` 既定 1rem=16px。`.form-control-sm`（14px）は注意 | `text-base`（input に `text-sm` を付けない） | viewport の `maximum-scale=1` | iPhone 15 エミュレーション |
| D2 | Accidental hover on mobile | タップ後にホバー色が残る / ホバーで開くメニューがタッチで操作不能 | `:hover` をタッチ端末にも適用 | `@media (hover: hover) { :hover {...} }` | 自作 | v4 の `hover:` は既定で `@media (hover: hover)` 内 → 追加対応不要 | JS でタッチ判定 | 375px タッチエミュレーション |
| D3 | CSS Variable Fallback | 変数未定義でサイズ・色が消える | `var(--x)` に fallback 無し | `var(--x, 1rem)` | SCSS 変数中心なので該当薄 | 任意値でも `var(--gap, 1rem)` | `!important` | 変数定義を消して表示 |
| D4 | Grouping vendor selectors | placeholder 等のスタイルが特定ブラウザで効かない | `::-webkit-input-placeholder, ::-moz-placeholder` を 1 ルールにまとめると未対応セレクタで **ルール全体が無効** | ベンダーごとに別ルール（または標準 `::placeholder` のみ） | — | `placeholder:` バリアント | — | Firefox / Safari |

## 実装前の 5 問（AI が正常系だけで組むのを防ぐ）

1. この flex / grid の子は、内容が **2 倍の長さ** になっても縮めるか？（→ A1 / A2）
2. 320px でこの横並びは **折り返す** か **横スクロール容器** に入るか？（→ A3 / C1）
3. 幅・高さに **固定 px** を書いていないか？（→ A5 / A6）
4. 件数が **0 / 1 / 100** のときに間隔と幅はどうなるか？（→ A7 / A8）
5. 画像・select・長い URL・全角長文・空文字を入れたか？（→ A4 / B1 / B2）
