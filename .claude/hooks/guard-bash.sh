#!/bin/bash
# PreToolUse guard for Bash tool.
# CLAUDE.md のコミット規約と破壊的コマンドを強制する。
# 正本: .claude/rules/git/commit-rules.md。ルールを変えるときは rules と本ファイルの両方を直す。
# 設計: fail-open（解析不能・想定外は必ず許可 exit 0）。危険パターンのみ exit 2 でブロック。
set +e

input=$(cat)
cmd=$(printf '%s' "$input" | /usr/bin/python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
' 2>/dev/null)

# コマンドが取れなければ許可
[ -z "$cmd" ] && exit 0

block() { echo "🚫 ブロック（CLAUDE.md規約/安全ガード）: $1" >&2; exit 2; }

# 1) git add . / -A / --all は禁止（ファイルパス明示指定ルール）
#    変種も塞ぐ: git -C <path> add . / git add ./ / git add -- . / git add :/
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?add[[:space:]]+(--[[:space:]]+)?(\.|\./|-A|--all|:/)([[:space:]]|$)'; then
  block "git add . / -A / --all（変種含む）は禁止。コミット対象はファイルパスを明示指定すること。"
fi

# 2) git add で docs/ ・ .claude/ を追加（コミット対象外）
#    ユーザーの明示指示がある時のみ ALLOW_DOCS_COMMIT=1 を付けて実行する（CLAUDE.md の例外規定と整合）
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+add[[:space:]].*(docs/|\.claude/)' \
   && ! printf '%s' "$cmd" | grep -q 'ALLOW_DOCS_COMMIT=1'; then
  block "docs/ ・ .claude/ はコミット対象外。ユーザーの明示指示がある場合のみ ALLOW_DOCS_COMMIT=1 を付けて再実行。"
fi

# 3) 破滅的 rm -rf
#    対象: / , /* , ~ , ~/直下 , $HOME , $HOME/直下 , /Users(2階層まで) , システム領域
#    引用符付きパス("~/foo")も検知するためクォートを剥いだ正規化版で判定する
cmd_noquote=$(printf '%s' "$cmd" | tr -d "\"'")
if printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]&;|(])rm[[:space:]]+(-[a-zA-Z]*[rfR]|--recursive|--force)'; then
  if printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]])(/|/\*)([[:space:]]|$)' \
     || printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]])(~|\$HOME)(/[^/[:space:]]+)?/?\*?([[:space:]]|$)' \
     || printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]])/Users(/[^/[:space:]]+){0,2}/?\*?([[:space:]]|$)' \
     || printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]])/(System|etc|usr|bin|sbin|Library|var)(/[^[:space:]]*)?([[:space:]]|$)'; then
    block "破壊的な rm -rf（ルート/ホーム/ホーム直下/システム領域）を検知。"
  fi
fi

# 3b) カレント全消し rm -rf * / ./* / .（ディレクトリ指定なしの裸ワイルドカード）
if printf '%s' "$cmd_noquote" | grep -Eq '(^|[[:space:]&;|(])rm[[:space:]]+(-[a-zA-Z]*[rfR]|--recursive|--force)[a-zA-Z-]*[[:space:]]+(\*|\./\*|\.)([[:space:]]|$)'; then
  block "カレントディレクトリ全消し（rm -rf * / ./* / .）を検知。対象ディレクトリを明示すること。"
fi

# 4) force push ガード。main/master に加え HEAD 指定（実体が main になり得る）もブロックし、
#    push 先ブランチを明示しない force push（カレントブランチ暗黙指定）もブロックする
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+push[^|;&]*[[:space:]](--force|--force-with-lease|-f)([[:space:]]|$)'; then
  if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]]|:|\+)(main|master|HEAD)([[:space:]]|$)'; then
    block "main/master/HEAD への force push を検知。"
  fi
  push_target_count=$(printf '%s' "$cmd" | grep -oE 'git[[:space:]]+push[^|;&]*' | head -1 | tr ' ' '\n' | grep -vE '^(git|push|-.*)?$' | wc -l | tr -d ' ')
  if [ "$push_target_count" -lt 2 ]; then
    block "push 先（remote とブランチ名）を明示しない force push を検知。両方を明示すること。"
  fi
fi

# 5) DB drop
if printf '%s' "$cmd" | grep -Eiq '(rails|rake|bin/rails)[[:space:]]+db:drop|DROP[[:space:]]+DATABASE'; then
  block "データベース削除（db:drop / DROP DATABASE）を検知。"
fi

# 6) DB 全消し系（reset / schema:load は既存データを破壊する）
if printf '%s' "$cmd" | grep -Eiq '(rails|rake|bin/rails)[[:space:]]+db:(reset|schema:load)|DROP[[:space:]]+TABLE'; then
  block "DB破壊系（db:reset / db:schema:load / DROP TABLE）を検知。"
fi

# 7) Fly の破壊操作（アプリ/マシン/ボリューム削除・シークレット削除）
if printf '%s' "$cmd" | grep -Eq '(fly|flyctl)[[:space:]]+(apps?|machines?|volumes?)[[:space:]]+destroy|(fly|flyctl)[[:space:]]+secrets[[:space:]]+unset'; then
  block "Fly の破壊操作（destroy / secrets unset）を検知。"
fi

# 8) Vercel のデプロイ/プロジェクト削除
if printf '%s' "$cmd" | grep -Eq 'vercel[[:space:]]+(rm|remove)([[:space:]]|$)'; then
  block "Vercel の削除操作（vercel rm/remove）を検知。"
fi

# 9) Heroku の破壊操作（DBリセット・アプリ削除）と TRUNCATE
if printf '%s' "$cmd" | grep -Eiq 'heroku[[:space:]]+pg:(reset|kill|killall)|heroku[[:space:]]+apps:destroy|TRUNCATE[[:space:]]+(TABLE[[:space:]])?[a-zA-Z_"`]'; then
  block "Heroku の破壊操作（pg:reset / apps:destroy）または TRUNCATE を検知。"
fi

# 10) コミットフックのスキップ（git-rules 絶対禁止）。短縮形 -n も塞ぐ
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+commit[^|;&]*([[:space:]]--no-verify|[[:space:]]-n)([[:space:]]|$)'; then
  block "git commit --no-verify / -n は禁止（フックをスキップしない）。"
fi

# 11) 確認なしの変更破棄（git-rules 要確認事項。必要ならユーザー明示指示のうえで）
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+reset[[:space:]]+(--hard|--merge)'; then
  block "git reset --hard/--merge は確認なし実行禁止。ユーザーの明示指示が必要。"
fi
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+(checkout|restore)[[:space:]]+(\.|--[[:space:]]+\.)([[:space:]]|$)'; then
  block "作業ツリー全体の変更破棄（checkout/restore .）を検知。対象ファイルを明示すること。"
fi

# 12) リモートスクリプトのパイプ実行（curl|sh 等）。インストーラを流す時はユーザー明示指示のうえ INSTALL_PIPE_OK=1
if printf '%s' "$cmd" | grep -Eq '(curl|wget)[^|;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)' \
   && ! printf '%s' "$cmd" | grep -q 'INSTALL_PIPE_OK=1'; then
  block "リモートスクリプトのパイプ実行（curl|sh 等）を検知。内容を確認し、必要なら INSTALL_PIPE_OK=1 を付けて再実行。"
fi

# 13) 未追跡ファイル全削除・stash 全消し・crontab 全消し
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*[fdx]'; then
  block "git clean -f/-d/-x（未追跡ファイル削除）を検知。ユーザーの明示指示が必要。"
fi
if printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+stash[[:space:]]+(clear|drop)([[:space:]]|$)'; then
  block "git stash clear/drop（退避の破棄）を検知。ユーザーの明示指示が必要。"
fi
if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]&;|(])crontab[[:space:]]+-r([[:space:]]|$)'; then
  block "crontab -r（cron 全消し）を検知。"
fi

# 14) DB の直接破壊（dropdb / redis flush）
if printf '%s' "$cmd" | grep -Eq '(^|[[:space:]&;|(])dropdb([[:space:]]|$)'; then
  block "dropdb（PostgreSQL データベース削除）を検知。"
fi
if printf '%s' "$cmd" | grep -Eiq 'redis-cli[^|;&]*flush(all|db)'; then
  block "redis-cli flushall/flushdb（Redis 全消去）を検知。"
fi

exit 0
