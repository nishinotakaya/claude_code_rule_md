---
name: Oracle schema modification prohibition
description: Never add or remove columns from Oracle DB tables - they are read-only from this app's perspective
type: feedback
---

Oracleのテーブルへのカラム追加・削除は絶対にしない。

**Why:** Oracle DBはこのアプリから変更できないシステム（JTM側管理）。スキーマはOracle側で管理されており、Railsアプリはread/writeのみ。

**How to apply:** Oracleテーブル（JtmDb系モデル: t_kareki_files, t_kareki_error_files, t_kareki_master, t_kareki_thumbnail, t_kareki_kouji_status等）にカラムが存在しない場合は、Railsモデル側（discard_column設定等）で対応する。絶対にmigrationやSQL DDLでOracleテーブルを変更しない。
