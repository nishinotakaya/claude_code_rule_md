---
paths:
  - "src/**/*.css"
  - "src/**/*.tsx"
  - "index.html"
---

# CSS とレイアウトの規則（tech-put-app）

## 使うもの・使わないもの

| 使う | 使わない |
|---|---|
| Bootstrap 5 のユーティリティ・コンポーネント | Tailwind のクラス（`@tailwind` が無く生成されない。見た目に効かない） |
| `src/index.css` のデザイントークン（CSS 変数） | 色・余白の生値の直書き |
| `src/styles/components/*.css` `src/styles/pages/*.css` の既存クラス | `style={{}}`（CSS 変数の受け渡しだけ例外） |
| 新規クラスは既存ファイルの流儀で最小限 | `!important`・`z-index: 9999`・`overflow: hidden` で隠す応急処置 |

新しい CSS を書く前に、同じ画面種（一覧・詳細・フォーム・モーダル）の既存クラスを grep する。

## 組む前の 5 問（`/layout-defense` §1 ③）

1. flex / grid の子は内容が 2 倍になっても縮むか → 縮む側に `min-width: 0`
2. 320px で横並びは折り返すか、横スクロール容器に入るか → `.flex-wrap` / `.table-responsive` / `overflow-x: auto`
3. 固定 px の幅・高さを書いていないか → `max-width: 100%`
4. 件数 0 / 1 / 100 で間隔と幅はどうなるか → `.gap-*`、空状態 UI
5. 長い URL・全角長文・空文字・404 画像を入れたか → `.text-truncate` / `.text-break` / `object-fit: cover`

## 検証

- PC 1440×900 とスマホ 375 幅の両方を Playwright で開く
- `document.documentElement.scrollWidth <= clientWidth + 1` を各画面で確認し、数値を報告に書く
- `html` / `body` に `overflow-x: hidden` を足して横溢れを隠さない

## 禁止する応急処置

| 応急処置 | 代わりに |
|---|---|
| 親に `overflow: hidden` | `min-width: 0` / `flex-wrap` / 外側の `overflow-x: auto` |
| `width: 437px` の決め打ち | `max-width: 100%` / `min-*` |
| `d-none d-md-block` で問題要素をスマホから消す | 折返し・横スクロール容器 |
| サーバ側で文字数を切る | `text-truncate` / `line-clamp` |

## アクセシビリティ

- モバイルの input は 16px 以上、タップ領域 44px 以上
- 画像に `alt`、アイコンボタンに `aria-label`
- 色だけで状態を伝えない（文言かアイコンを添える）
