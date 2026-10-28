---
name: layout-defense
description: レイアウト崩れの防止と修正（Defensive CSS・Bootstrap 5 の症状→原因→修正表、Playwright 横溢れ検査）。「はみ出る」「崩れる」「スマホで崩れる」「揃わない」「横スクロールが出る」、画面の新規作成・変更前、デザインレビュー時に参照。
---

# layout-defense — レイアウト崩れの防止と修正

> 原則集ではなくワークフロー。AI は正常系データで画面を組むので、「壊れる入力」を前提に組み、複数幅で機械検証してから終える。

## いつ使う

- 画面を新規作成・変更する前（implementer）: §1 ①〜③
- デザインレビュー・コードレビュー（designer / reviewer）: §3
- E2E（auto-test / qa）: §1 ④
- 「ズレる・はみ出る・崩れる」の相談: `references/troubleshooting.md` の症状表

## 1. ワークフロー

### ① フレームワークとバージョンを特定する（推測で書かない）

```bash
grep -o '"bootstrap": *"[^"]*"' package.json       # フロントは Bootstrap 5（main.tsx で import）
grep -o '"tailwindcss": *"[^"]*"' package.json     # 入っているが @tailwind ディレクティブが無く、ユーティリティは生成されない
grep -rn "@tailwind" src/ index.html               # 0 件なら Tailwind クラスを書いても効かない
```

テックプットのフロントは **Bootstrap 5 + 自作 CSS**（`src/index.css` のデザイントークン、`src/styles/{components,pages}/*.css`）。Tailwind のクラスを新規に書かない。バックエンドの旧 ERB 側は Bootstrap 4 系なので版を確認してから。

### ② 既存のユーティリティ・共通コンポーネントを探す

新しい CSS を書く前に、同じ画面種（一覧・詳細・フォーム・モーダル）の既存実装と `src/styles/` の自作クラスを grep する。「新規 CSS は最小限」「`style={{}}` を書かない」を守る。

### ③ 最小変更で組む — 実装前の 5 問

1. この flex / grid の子は、内容が 2 倍の長さになっても縮めるか？ → 縮む側に `min-width: 0`（Bootstrap: `.mw-0` は無いので自作クラスか `.text-truncate` と併用）
2. 320px でこの横並びは折り返すか、横スクロール容器に入るか？ → `.flex-wrap` か外側 div に `.overflow-auto` / `.table-responsive`
3. 幅・高さに固定 px を書いていないか？ → `max-width: 100%` / `.w-100 .w-md-auto`
4. 件数が 0 / 1 / 100 のとき間隔と幅はどうなるか？ → `.gap-*`、空状態 UI
5. 長い URL・全角長文・空文字・404 画像を入れたか？ → `.text-truncate` / `.text-break` / `object-fit: cover`

「症状 → まず疑う」早見:

| 症状 | まず疑う |
|---|---|
| はみ出す・`text-truncate` が効かない・select が横幅を押し広げる | flex 子の `min-width: auto` → `min-width: 0` |
| 表・カードがスマホで画面を押し広げる | 横スクロール容器が無い → 外側 div に `.table-responsive` / `overflow-x: auto` |
| ボタン群が狭幅で横に溢れる | `.flex-wrap` 未指定 |
| スマホで固定幅が溢れる | `width: 300px` → `max-width: 100%` |
| 重なる・隠れる | stacking context と DOM 順 → 後に描画 + `z-index` 明示 |
| クラスを付けたのに効かない | Tailwind クラスを書いている（生成されない）/ Bootstrap の版違い |

### ④ 複数幅 × 壊れる入力で検証する

`scripts/overflow_check.spec.ts` を `@playwright/test` のあるディレクトリにコピーして実行する（フロントの依存には無いので、別ディレクトリに `npm i -D @playwright/test` して回す）。

```bash
LAYOUT_BASE_URL=http://localhost:5173 LAYOUT_PATHS=/,/dashboard,/admin/articles npx playwright test overflow_check.spec.ts
# 既定 viewport: 320,375,768,1024,1440 / ログイン済みで回すなら LAYOUT_STORAGE_STATE=auth.json
```

判定は `document.documentElement.scrollWidth <= clientWidth + 1`。`html/body` の `overflow-x: hidden` は検査を無効化するので先に fail させる。`mcp__playwright__*` で手動確認するときも同じ式を `browser_evaluate` で取る。データは `references/troubleshooting.md` §2「壊れる入力」から最低 1 つ入れる。

### ⑤ 証跡を残して報告する

「どの幅で」「どのデータで」「`scrollWidth` / `clientWidth` がいくつで」通ったかを書く。「見た目を確認した」だけの報告は不可。

## 2. 禁止する応急処置（レビューで差し戻す）

| 応急処置 | なぜ駄目か | 代わりに |
|---|---|---|
| 親に `overflow: hidden` で溢れを隠す | 原因が残り、内容が見切れる | `min-width: 0` / `flex-wrap` / 外側の `overflow-x: auto` |
| `body { overflow-x: hidden }` | 全画面の横溢れを隠すだけ。iOS で壊れる | 溢れている要素を直す |
| `width: 437px` の決め打ち | 別のデータ・幅で再発 | `max-width: 100%` / `min-*` |
| `d-none d-md-block` で問題要素をモバイルから消す | 機能欠落 | 折返し・横スクロール容器 |
| `z-index: 9999` / `!important` 連発 | stacking context の問題は解決しない | DOM 順 + 明示的な z-index |
| `style={{}}` で幅指定 | 規約違反 | 共通クラス（CSS 変数の受け渡しのみ例外） |
| サーバ側で文字数を切る | データ改変。別画面で不足 | `text-truncate` / `line-clamp` |

## 3. レビュー用チェックリスト（designer / reviewer）

- [ ] flex / grid の縮む側に `min-width: 0`（または `minmax(0,1fr)`）があるか
- [ ] 横並びに `flex-wrap` か、横長要素の外側に `overflow-x: auto` があるか
- [ ] 固定 px の幅・高さが無いか
- [ ] 長文・空・0 件・100 件の状態が設計されているか
- [ ] モバイルの input が 16px 以上、タップ領域 44px 以上か
- [ ] 画像に `object-fit` と `max-width: 100%` があるか
- [ ] `overflow: hidden` / `z-index: 9999` / `!important` / inline style の応急処置が無いか
- [ ] 320 / 375 / 768 / 1024 / 1440px の検証結果（`scrollWidth` 数値）が報告にあるか

## 4. references

| ファイル | 内容 |
|---|---|
| `references/troubleshooting.md` | 症状 / 確認箇所 / 典型原因 / 優先修正 / 禁止する応急処置 / 検証条件 の表。壊れる入力リスト |
| `references/defensive-checklist.md` | Defensive CSS を症状別に、素 CSS / Bootstrap / Tailwind の 3 列で |
| `scripts/overflow_check.spec.ts` | Playwright: 5 幅 × 各ページで横溢れを機械判定し、はみ出し要素を添付 |
