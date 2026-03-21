---
name: Required JavaScript libraries (matching old kareki)
description: JS/CSS libraries needed to match old kareki app - iCheck, datetimepicker, moment, etc.
type: project
---

旧karekiシステムと同じJSライブラリ構成が必要。

**Why:** 旧システム(kareki/app/assets/javascripts/application.js)はSprockets経由で以下をロード。新システム(kareki_next)はesbuild+npmで同等のライブラリが必要。

**How to apply:** npm install で追加、application.ts で import、CSS は vendor/ に配置またはpublic/に静的配置。

## npm packages (package.json dependencies)
- `icheck@1.0.2` - チェックボックス/ラジオボタンスタイリング
- `moment@2.x` - 日付ライブラリ
- `moment/locale/ja` - 日本語ロケール
- `eonasdan-bootstrap-datetimepicker@4.x` - 日付ピッカー
- `dropzone@6.x` - ファイルアップロード
- `select2@4.x` - セレクトボックス
- `chart.js@2.x` - グラフ

## application.ts imports (順序重要)
```typescript
import $ from "jquery"
window.$ = window.jQuery = $
import "bootstrap"
import "moment"
import "moment/locale/ja"
import "eonasdan-bootstrap-datetimepicker"
import "icheck"
import "dropzone"
import "select2"
```

## CSS配置
- iCheck CSS+画像: `public/icheck/flat/` と `public/icheck/square/` (静的ファイル、URLを相対パスで保持)
- datetimepicker CSS: `app/assets/stylesheets/vendor/bootstrap-datetimepicker.min.css`
- select2 CSS: `app/assets/stylesheets/vendor/select2.min.css`
- application.scss: `@use "vendor/bootstrap-datetimepicker.min"` と `@use "vendor/select2.min"` を追加

## レイアウトファイル (insurance/kareki/loan layout)
iCheck CSSをheadで読み込む:
```slim
link rel="stylesheet" href="/icheck/flat/flat.css"
link rel="stylesheet" href="/icheck/flat/blue.css"
link rel="stylesheet" href="/icheck/flat/green.css"
link rel="stylesheet" href="/icheck/flat/red.css"
link rel="stylesheet" href="/icheck/square/square.css"
...
```

## JS更新後の手順
1. `npm run build` で app/assets/builds/application.js を生成
2. コンテナにコピー: `docker cp app/assets/builds/application.js container:/rails/app/assets/builds/`
3. CSS変更時: `bundle exec rails dartsass:build` 実行
4. `docker restart` でPropshaftキャッシュクリア

## CoffeeScript → JavaScript変換済みビューファイル
以下のファイルの `coffee:` ブロックを全て `javascript:` に変換済み:
- kareki/karekibox/show.html.slim
- kareki/scanbox/index.html.slim
- kareki/search/index.html.slim
- kareki/errorbox/index.html.slim
- loan/scanbox/index.html.slim
- loan/box/show.html.slim
- loan/search/index.html.slim
- loan/summary/index.html.slim
- loan/errorbox/index.html.slim
- insurance/box/show.html.slim
- insurance/search/index.html.slim
