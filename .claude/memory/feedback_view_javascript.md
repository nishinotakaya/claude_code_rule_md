---
name: No inline JavaScript in views - move to JS files
description: Inline javascript: blocks in Slim views should be moved to dedicated JS files
type: feedback
---

Slimビューに `javascript:` ブロックを残してはいけない。必ずJSファイル（app/javascript/legacy/ 等）に移動する。

**Why:** コードが分散してメンテナンスしにくい。テストもできない。旧systemもSprockets経由でJSファイルに分離していた。

**How to apply:** viewにインラインJSを書くのではなく、app/javascript/legacy/ 配下に対応するJSファイルを作成し、application.ts から import する。
