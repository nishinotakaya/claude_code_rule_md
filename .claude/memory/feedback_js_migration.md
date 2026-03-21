---
name: JS移行ルールと注意点
description: 旧Sprockets→新esbuild/Propshaft移行時のJS対応ルールと既知の落とし穴
type: feedback
---

## esbuildバンドル構成

全legacyファイルは`app/javascript/application.ts`でimportして1つのバンドルにまとめる。

**Why:** Propshaftは`//= require`ディレクティブを処理しない。Sprockets依存のファイルは動かない。

**How to apply:** 新しいlegacy JSファイルを追加したら必ずapplication.tsにimportを追加する。

---

## ページガード必須ルール

全legacyファイルの`$(function(){...})`先頭で必ずページ固有要素チェックを入れること。

```typescript
$(function() {
  if ($('#page-specific-element').length === 0) return;
  // ...
});
```

**Why:** 全ファイルが1つのapplication.jsにバンドルされるため、全ページで全ファイルのハンドラが実行される。ガードがないと別ページのボタンに誤反応する。

**How to apply:** `.js-validate`などの汎用クラスを使うファイルは特に注意。ページ固有のform id・data属性・ボタンクラスでガードする。

---

## 非推奨jQuery呼び出しの修正

| 旧（非推奨） | 新（推奨） |
|---|---|
| `$el.submit()` | `$el.trigger('submit')` |
| `$el.click()` | `$el.trigger('click')` |
| `$el.change()` | `$el.trigger('change')` |
| `.click(fn)` | `.on('click', fn)` |
| `.change(fn)` | `.on('change', fn)` |
| `form.submit()` (native) | `$(form).trigger('submit')` |

---

## Bootstrap collapse動作させるには

kareki/loan layoutに`bootstrap.min.js`を必ず含めること。Propshaft環境では`bootstrap-sprockets-custom.js`の`//= require`は無効。

**Why:** Bootstrap 3のcollapse/accordion/navbarはJSが必要。Sprocketsで読み込んでいた旧実装と異なり、Propshaftでは明示的にscriptタグで読み込む必要がある。

対象レイアウト: `kareki.html.slim`, `loan.html.slim`, `application.html.slim`, `insurance.html.slim`（insuranceは既に含まれていた）

---

## tilt 2.7.0 + coffee_script問題

`lib/coffee_script.rb`にスタブを置いてある。削除しないこと。

**Why:** tilt 2.7.0がSlimの`javascript:`ブロックをコンパイルする際、全テンプレートハンドラをlazy_loadし、その中のcoffee_scriptを要求する。coffee-scriptgemが未インストールのためLoadError発生。スタブでモジュールを定義することで回避。

---

## Discard gemの`discard_column`設定が効かない問題

`self.discard_column = :deleted_at`が機能しない（Rails 8 + Discard 1.4.0の問題）。

**Fix:** `default_scope { kept }` → `default_scope { where(deleted_at: nil) }` に直接書き換える。

対象モデル: KarekiErrorFile, KarekiFile, KarekiThumbnail, KarekiMaster

---

## Docker hot-patch手順

Dockerはbind mountなしのため、ファイル変更後は必ずコピーが必要。

```bash
# コントローラ/モデル/ビュー
docker compose cp <local_path> web:/rails/<container_path>

# JS変更時
yarn build
docker compose cp app/assets/builds/application.js web:/rails/app/assets/builds/application.js
docker compose cp app/assets/builds/application.js.map web:/rails/app/assets/builds/application.js.map
```

---

## kareki_common.js / kareki_filter.js

`app/javascript/legacy/kareki_common.js` - tooltipとdownloadFile関数をwindowに公開
`app/javascript/legacy/kareki_filter.js` - .js-clear-btnハンドラ

両ファイルは`application.ts`の先頭でimportされている。`window.downloadFile`は`common_page_init.ts`のラベルツールダウンロードで使用。
