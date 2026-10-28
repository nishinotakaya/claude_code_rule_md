#!/bin/bash
# ルール一式を対象リポジトリへ配備する。既定は dry-run（差分表示のみ）。--apply で書き込む。
# 追加・上書きだけを行い、削除はしない。tasks/ と PR テンプレートは対象に無いときだけ置く。
set -euo pipefail

usage() { echo "usage: $0 <target-repo-dir> [--apply]" >&2; exit 1; }

target_dir="${1:-}"
mode="${2:-}"
[ -n "$target_dir" ] || usage
[ -d "$target_dir" ] || { echo "対象ディレクトリがありません: $target_dir" >&2; exit 1; }
[ -z "$mode" ] || [ "$mode" = "--apply" ] || usage

source_dir="$(cd "$(dirname "$0")" && pwd)"
rsync_flags=(-a --itemize-changes --exclude '.DS_Store')
[ "$mode" = "--apply" ] || rsync_flags+=(--dry-run)

echo "== 配備元: $source_dir ($(git -C "$source_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?'))"
echo "== 配備先: $target_dir"
[ "$mode" = "--apply" ] || echo "== dry-run（--apply を付けると書き込む）"

# 常に同期（上書きあり・削除なし）
rsync "${rsync_flags[@]}" "$source_dir/CLAUDE.md" "$target_dir/CLAUDE.md"
rsync "${rsync_flags[@]}" "$source_dir/.claude/" "$target_dir/.claude/"

# 対象に無いときだけ置く
for optional_path in "tasks/todo.md" "tasks/lessons.md" ".github/pull_request_template.md"; do
  if [ -e "$target_dir/$optional_path" ]; then
    echo "skip (exists): $optional_path"
  elif [ "$mode" = "--apply" ]; then
    mkdir -p "$(dirname "$target_dir/$optional_path")"
    rsync "${rsync_flags[@]}" "$source_dir/$optional_path" "$target_dir/$optional_path"
  else
    echo ">f+++++++++ $optional_path (新規)"
  fi
done

if [ "$mode" = "--apply" ]; then
  chmod +x "$target_dir/.claude/hooks/"*.sh
  echo "== 完了。対象リポで claude を起動し /develop が出ることを確認してください"
fi
