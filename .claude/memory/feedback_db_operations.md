---
name: Prohibited DB operations
description: Never run db:schema:reset, db:reset, or migrate:reset - these drop all data
type: feedback
---

`db:schema:reset`、`db:reset`、`db:migrate:reset` は絶対に実行しない。

**Why:** 本番・開発データが消える。MySQLのboxデータも含め全テーブルがdropされるため回復不能な被害が出る。

**How to apply:** マイグレーション関連で問題が起きた場合は、個別の `db:migrate` や特定マイグレーションのみ実行する。resetコマンドは一切使わない。
