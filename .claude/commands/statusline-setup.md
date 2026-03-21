# Claude Code ステータスライン設定ガイド

Claude Code の画面下部に **モデル情報・レートリミット・外部API使用量** を表示するカスタムステータスラインのセットアップ手順。

## 表示内容

```
🤖 Opus 4.6 │ 📊 45% │ ✏️ +120/-30
📁 myproject │ 🔀 feature-branch
⏱ 5h  ▰▰▰▰▱▱▱▱▱▱  40%  ~3:00pm
🗓️ 7d  ▰▰▱▱▱▱▱▱▱▱  20%  ~3/15 4:00pm
💳 extra  ▰▱▱▱▱▱▱▱▱▱  5%  $2.50/$50.00
⏱ CX5h  ▱▱▱▱▱▱▱▱▱▱  0%  ~2:00am
🗓️ CX7d  ▱▱▱▱▱▱▱▱▱▱  0%  ~3/18 3:00pm
🖱️ Cursor  ▰▰▰▰▰▰▰▰▰▰  100%  $23/$20  ~3/18
💎 Gemini  ¥12.5 (3枚/5回) [計算]
```

- **1行目**: モデル名+バージョン │ コンテキスト使用率 │ 変更行数
- **2行目**: ディレクトリ名 │ Gitブランチ
- **3行目**: Anthropic 5時間レートリミット（プログレスバー + % + リセット時刻JST）
- **4行目**: Anthropic 7日レートリミット（同上）
- **5行目**: extra_usage 追加クレジット（有効時のみ。使用額/上限ドル表示）
- **6-7行目**: Codex CLI レートリミット（キャッシュ存在時のみ表示）
- **8行目**: Cursor 使用量（個人の使用率% + 支出/上限 + 請求サイクル終了日）
- **9行目**: Gemini API請求サイクル累計（円 + 画像枚数/API呼出回数 + ソース[計算/API]。常に表示）

## 前提条件

- macOS（`date -jf` / `security` コマンドを使用）
- `jq` がインストール済み（`brew install jq`）
- Claude Code の OAuth ログイン済み（`claude login`）

## アーキテクチャ

```
SessionStart / Stop hook
        ↓
  fetch-usage.sh ──→ /tmp/claude-usage-cache.json        (Anthropic)
  fetch-codex-usage.sh ──→ /tmp/codex-usage-cache.json   (Codex)
  fetch-cursor-usage.sh ──→ /tmp/cursor-usage-cache.json (Cursor)
  fetch-gemini-usage.sh ──→ ~/.claude/gemini-usage-cache.json の api_cost_jpy を更新
        ↑                    （BigQuery Billing Export経由。未設定時はスキップ）

Gemini API呼び出しスクリプト（Node.js）
        ↓
  gemini-usage-tracker.js ──→ ~/.claude/gemini-usage-cache.json の calc_cost_jpy を積算
        ↑ usageMetadata のトークン数 × 料金テーブルでリアルタイム計算

ステータスライン更新ごと
        ↓
  statusline-command.sh ──→ 4つのキャッシュを読み取り → 表示
        ↑ Gemini: api_cost_jpy があればそちらを優先表示 [API]、なければ calc_cost_jpy [計算]
```

API取得と表示を分離することで、表示が高速かつ API への負荷が最小。

### Gemini コスト追跡の仕組み（ハイブリッド方式）

| レイヤー | ソース | 精度 | リアルタイム性 |
|---------|--------|------|-------------|
| `calc_cost_jpy` | usageMetadata × 料金テーブル | ±5% | リアルタイム |
| `api_cost_jpy` | BigQuery Billing Export | 正確 | 24〜48時間遅延 |

- ローカル計算値は常に積算される（Gemini API呼び出しのたびに即更新）
- BigQuery実額はhookで定期取得（5分クールダウン）
- ステータスラインは `api_cost_jpy` を優先し、なければ `calc_cost_jpy` を表示
- Google AI Studio APIキー経由の呼び出しはCloud Monitoringに記録されないため、
  BigQuery Billing Exportが実額取得の唯一の手段

## ファイル構成

```
~/.claude/
├── statusline-command.sh        # 表示スクリプト（毎回呼ばれる）
├── fetch-usage.sh               # Anthropic API 取得（hook から）
├── fetch-codex-usage.sh         # Codex API 取得（hook から）
├── fetch-cursor-usage.sh        # Cursor API 取得（hook から）
├── fetch-gemini-usage.sh        # BigQuery実額取得（hook から。未設定時はスキップ）
├── gemini-usage-config.json     # Gemini設定（サイクル日・為替レート・BQテーブル）
├── gemini-usage-cache.json      # Gemini使用量キャッシュ（計算値+API実額）
└── settings.json                # Claude Code 設定（hook・statusLine）

<プロジェクト>/
└── scripts/
    └── gemini-usage-tracker.js  # Gemini使用量トラッカーモジュール（Node.js）
```

---

## Step 1: `statusline-command.sh` を作成

```bash
cat > ~/.claude/statusline-command.sh << 'STATUSLINE_EOF'
#!/bin/bash
# Claude Code ステータスライン（幅適応型）
# ターミナル幅に応じて自動的に行を分割し、truncateされないようにする
# 構成: モデル情報 + レートリミット（3〜8行）

INPUT=$(cat)

# --- ターミナル幅を取得（padding分を差し引いた利用可能幅） ---
PADDING=4
SAFETY_MARGIN=14  # 絵文字幅の推定誤差 + Claude Codeレンダラーの余白を吸収
# tmux内では tput cols がターミナル全体幅を返すため、ペイン幅を優先
COLS=$(tmux display-message -p '#{pane_width}' 2>/dev/null)
[ -z "$COLS" ] || [ "$COLS" -le 0 ] 2>/dev/null && COLS=$(tput cols 2>/dev/null || echo 80)
[ "$COLS" -le 0 ] 2>/dev/null && COLS=80
AVAIL=$((COLS - PADDING * 2 - SAFETY_MARGIN))

# jqで各値を取得（パース失敗時のデフォルト値を保証）
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"'
2>/dev/null) || MODEL="?"
MODEL_ID=$(echo "$INPUT" | jq -r '.model.id // ""' 2>/dev/null)
# claude-opus-4-6 → 4.6, claude-sonnet-4-6 → 4.6, claude-haiku-4-5-20251001 → 4.5
VERSION=$(echo "$MODEL_ID" | sed -E 's/^claude-[a-z]+-([0-9]+)-([0-9]+).*/\1.\2/')
[ -n "$VERSION" ] && [ "$VERSION" != "$MODEL_ID" ] && case "$MODEL" in *"$VERSION"*) ;; *) MODEL="${MODEL} ${VERSION}" ;; esac
USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage //
 0' 2>/dev/null | cut -d. -f1) || USED_PCT=0
[ -z "$USED_PCT" ] && USED_PCT=0
LINES_ADDED=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0'
2>/dev/null) || LINES_ADDED=0
[ -z "$LINES_ADDED" ] && LINES_ADDED=0
LINES_REMOVED=$(echo "$INPUT" | jq -r '.cost.total_lines_removed //
0' 2>/dev/null) || LINES_REMOVED=0
[ -z "$LINES_REMOVED" ] && LINES_REMOVED=0

# Gitブランチ取得
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
BRANCH=""
if [ -n "$CWD" ]; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)
fi

# --- カラーリング関数 ---
color_for_pct() {
  local pct=$1
  if [ "$pct" -lt 50 ]; then
    echo "38;2;151;201;195"  # #97C9C3 緑
  elif [ "$pct" -lt 80 ]; then
    echo "38;2;229;192;123"  # #E5C07B 黄
  else
    echo "38;2;224;108;117"  # #E06C75 赤
  fi
}

# --- プログレスバー生成 ---
progress_bar() {
  local pct=$1
  local filled=$(( pct / 10 ))
  local empty=$(( 10 - filled ))
  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar+="▰"; done
  for (( i=0; i<empty; i++ )); do bar+="▱"; done
  echo "$bar"
}

# --- ANSIエスケープ ---
RESET="\033[0m"
GRAY="\033[38;2;74;88;92m"  # #4A585C

# --- 表示幅を推定（ANSIコード除去 + 絵文字を2セル幅として補正） ---
estimate_display_width() {
  local plain
  plain=$(printf '%b' "$1" | sed $'s/\033\\[[0-9;]*m//g')
  plain=$(printf '%s' "$plain" | sed $'s/\xef\xb8\x8f//g')
  local char_count emoji_extra
  char_count=$(printf '%s' "$plain" | wc -m | tr -d ' ')
  emoji_extra=$(printf '%s' "$plain" | grep -oE '🤖|📁|🔀|📊|✏|⏱|🗓|💳' | wc -l | tr -d ' ')
  echo $(( char_count + emoji_extra ))
}

# === 情報行を構築（2行固定レイアウト） ===
CTX_COLOR="\033[$(color_for_pct "$USED_PCT")m"
SEP=" ${GRAY}│${RESET} "

# 1行目: モデル │ コンテキスト │ 変更行数
LINE_INFO="🤖 ${MODEL}${SEP}${CTX_COLOR}📊 ${USED_PCT}%${RESET}${SEP}✏️ +${LINES_ADDED}/-${LINES_REMOVED}"

# 2行目: フォルダ │ ブランチ
LINE_LOC=""
[ -n "$CWD" ] && LINE_LOC="📁 ${CWD##*/}"
if [ -n "$BRANCH" ]; then
  [ -n "$LINE_LOC" ] && LINE_LOC="${LINE_LOC}${SEP}🔀 ${BRANCH}" || LINE_LOC="🔀 ${BRANCH}"
fi

INFO_LINES=("$LINE_INFO")
[ -n "$LINE_LOC" ] && INFO_LINES+=("$LINE_LOC")

# === Anthropic レートリミット取得 ===
CACHE="/tmp/claude-usage-cache.json"
CACHE_TTL=360

get_usage() {
  if [ -f "$CACHE" ]; then
    cat "$CACHE"
    return 0
  fi
  return 1
}

# リセット時刻のフォーマット（ISO8601 UTC → JST 表示）
format_reset_time() {
  local iso_time="$1"
  local label="$2"
  if [ -z "$iso_time" ] || [ "$iso_time" = "null" ]; then
    echo ""
    return
  fi
  local epoch
  epoch=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%S" "${iso_time%%.*}" "+%s" 2>/dev/null)
  if [ -z "$epoch" ]; then
    echo "Resets ?"
    return
  fi
  local time_part
  time_part=$(TZ="Asia/Tokyo" date -jf "%s" "$epoch" "+%-I:%M%p" 2>/dev/null)
  time_part=$(echo "$time_part" | tr '[:upper:]' '[:lower:]')

  if [[ "$label" == *h ]]; then
    echo "~${time_part}"
  else
    local date_part
    date_part=$(TZ="Asia/Tokyo" date -jf "%s" "$epoch" "+%-m/%-d" 2>/dev/null)
    echo "~${date_part} ${time_part}"
  fi
}

# レートリミット行を生成
format_rate_line() {
  local emoji="$1"
  local label="$2"
  local utilization="$3"
  local reset_time="$4"

  if [ -z "$utilization" ] || [ "$utilization" = "null" ]; then
    echo -e "${emoji} ${label}  (データ取得不可)"
    return
  fi

  local pct
  pct=$(echo "$utilization" | awk '{printf "%d", $1}')
  local color="\033[$(color_for_pct "$pct")m"
  local bar
  bar=$(progress_bar "$pct")
  local reset_str
  reset_str=$(format_reset_time "$reset_time" "$label")
  [ -n "$reset_str" ] && reset_str="  ${reset_str}"

  echo -e "${emoji} ${label}  ${color}${bar}  ${pct}%${RESET}${reset_str}"
}

# === Anthropic レートリミット行 ===
USAGE_JSON=$(get_usage 2>/dev/null)

if [ -n "$USAGE_JSON" ]; then
  FIVE_HOUR_UTIL=$(echo "$USAGE_JSON" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  FIVE_HOUR_RESET=$(echo "$USAGE_JSON" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
  SEVEN_DAY_UTIL=$(echo "$USAGE_JSON" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
  SEVEN_DAY_RESET=$(echo "$USAGE_JSON" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

  LINE2=$(format_rate_line "⏱" "5h" "$FIVE_HOUR_UTIL" "$FIVE_HOUR_RESET")
  LINE3=$(format_rate_line "🗓️" "7d" "$SEVEN_DAY_UTIL" "$SEVEN_DAY_RESET")

  # extra_usage（追加使用クレジット）
  EXTRA_ENABLED=$(echo "$USAGE_JSON" | jq -r '.extra_usage.is_enabled // empty' 2>/dev/null)
  if [ "$EXTRA_ENABLED" = "true" ]; then
    EXTRA_USED=$(echo "$USAGE_JSON" | jq -r '.extra_usage.used_credits // 0' 2>/dev/null)
    EXTRA_LIMIT=$(echo "$USAGE_JSON" | jq -r '.extra_usage.monthly_limit // 0' 2>/dev/null)
    EXTRA_UTIL=$(echo "$USAGE_JSON" | jq -r '.extra_usage.utilization // empty' 2>/dev/null)
    LINE4=$(format_rate_line "💳" "extra" "$EXTRA_UTIL" "")
    # 使用額/上限（creditsは100で割ってドル換算）
    if [ -n "$EXTRA_USED" ] && [ "$EXTRA_USED" != "null" ] && [ "$EXTRA_USED" != "0" ]; then
      LINE4+="  \$$(printf '%s' "$EXTRA_USED" | awk '{printf "%.2f", $1/100}')/\$$(printf '%s' "$EXTRA_LIMIT" | awk '{printf "%.2f", $1/100}')"
    fi
  fi
else
  LINE2=$(echo -e "⏱ 5h  (データ取得不可)")
  LINE3=$(echo -e "📅 7d  (データ取得不可)")
fi

# === Gemini API 使用量（日次・円） ===
GEMINI_CACHE="/tmp/gemini-usage-cache.json"
GEMINI_COST=0
GEMINI_CALLS=0
GEMINI_IMGS=0

if [ -f "$GEMINI_CACHE" ]; then
  GEMINI_JSON=$(cat "$GEMINI_CACHE")
  GEMINI_DATE=$(echo "$GEMINI_JSON" | jq -r '.date // empty' 2>/dev/null)
  TODAY=$(date "+%Y-%m-%d")
  if [ "$GEMINI_DATE" = "$TODAY" ]; then
    GEMINI_COST=$(echo "$GEMINI_JSON" | jq -r '.total_cost_jpy // 0' 2>/dev/null)
    GEMINI_CALLS=$(echo "$GEMINI_JSON" | jq -r '.calls // 0' 2>/dev/null)
    GEMINI_IMGS=$(echo "$GEMINI_JSON" | jq -r '.total_images // 0' 2>/dev/null)
  fi
fi
LINE_GEMINI="💎 Gemini  ¥${GEMINI_COST} (${GEMINI_IMGS}枚/${GEMINI_CALLS}回)"

# === Codex CLI レートリミット ===
CODEX_CACHE="/tmp/codex-usage-cache.json"

# Unixエポック秒 → ISO8601 UTC 変換
epoch_to_iso() {
  local epoch="$1"
  [ -z "$epoch" ] || [ "$epoch" = "null" ] && return
  TZ=UTC date -jf "%s" "$epoch" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null
}

# ウィンドウ秒数 → ラベル変換（例: 3600→1h, 86400→1d）
format_window_label() {
  local secs="$1"
  if [ -z "$secs" ] || [ "$secs" = "null" ]; then
    echo "?"
    return
  fi
  if [ "$secs" -ge 86400 ]; then
    echo "$((secs / 86400))d"
  else
    echo "$((secs / 3600))h"
  fi
}

LINE_CX1=""
LINE_CX2=""

if [ -f "$CODEX_CACHE" ]; then
  CODEX_JSON=$(cat "$CODEX_CACHE")
  if [ -n "$CODEX_JSON" ]; then
    CX_PRI_PCT=$(echo "$CODEX_JSON" | jq -r '.primary.used_percent // empty' 2>/dev/null)
    CX_PRI_RESET=$(echo "$CODEX_JSON" | jq -r '.primary.resets_at // empty' 2>/dev/null)
    CX_PRI_WIN=$(echo "$CODEX_JSON" | jq -r '.primary.window_seconds // empty' 2>/dev/null)
    CX_SEC_PCT=$(echo "$CODEX_JSON" | jq -r '.secondary.used_percent // empty' 2>/dev/null)
    CX_SEC_RESET=$(echo "$CODEX_JSON" | jq -r '.secondary.resets_at // empty' 2>/dev/null)
    CX_SEC_WIN=$(echo "$CODEX_JSON" | jq -r '.secondary.window_seconds // empty' 2>/dev/null)

    CX_PRI_LABEL="CX$(format_window_label "$CX_PRI_WIN")"
    CX_SEC_LABEL="CX$(format_window_label "$CX_SEC_WIN")"
    CX_PRI_RESET_ISO=$(epoch_to_iso "$CX_PRI_RESET")
    CX_SEC_RESET_ISO=$(epoch_to_iso "$CX_SEC_RESET")

    LINE_CX1=$(format_rate_line "⏱" "$CX_PRI_LABEL" "$CX_PRI_PCT" "$CX_PRI_RESET_ISO")
    LINE_CX2=$(format_rate_line "🗓️" "$CX_SEC_LABEL" "$CX_SEC_PCT" "$CX_SEC_RESET_ISO")
  fi
fi

# === Cursor 使用量 ===
CURSOR_CACHE="/tmp/cursor-usage-cache.json"
LINE_CURSOR=""

if [ -f "$CURSOR_CACHE" ]; then
  CURSOR_JSON=$(cat "$CURSOR_CACHE")
  if [ -n "$CURSOR_JSON" ]; then
    CUR_INCLUDED=$(echo "$CURSOR_JSON" | jq -r '.included_spend_cents // 0' 2>/dev/null)
    CUR_LIMIT=$(echo "$CURSOR_JSON" | jq -r '.limit_cents // 0' 2>/dev/null)
    # ダッシュボードと同じ計算: min(includedSpend/limit*100, 100)
    CUR_TOTAL_PCT=$(echo "$CUR_INCLUDED $CUR_LIMIT" | awk '{if($2>0) printf "%.1f", ($1/$2)*100; else print "0"}')
    CUR_CYCLE_END=$(echo "$CURSOR_JSON" | jq -r '.billing_cycle_end // empty' 2>/dev/null)

    if [ -n "$CUR_TOTAL_PCT" ] && [ "$CUR_TOTAL_PCT" != "null" ]; then
      CUR_PCT_INT=$(echo "$CUR_TOTAL_PCT" | awk '{printf "%d", $1}')
      CUR_COLOR="\033[$(color_for_pct "$CUR_PCT_INT")m"
      CUR_BAR=$(progress_bar "$CUR_PCT_INT")
      CUR_TOTAL_SPEND=$(echo "$CURSOR_JSON" | jq -r '.total_spend_cents // 0' 2>/dev/null)
      CUR_SPEND_DOLLAR=$(echo "$CUR_TOTAL_SPEND" | awk '{printf "%.0f", $1/100}')
      CUR_LIMIT_DOLLAR=$(echo "$CUR_LIMIT" | awk '{printf "%.0f", $1/100}')

      # リセット時刻（エポックミリ秒→JST）
      CUR_RESET=""
      if [ -n "$CUR_CYCLE_END" ] && [ "$CUR_CYCLE_END" != "null" ]; then
        CUR_EPOCH=$((CUR_CYCLE_END / 1000))
        CUR_RESET_DATE=$(TZ="Asia/Tokyo" date -jf "%s" "$CUR_EPOCH" "+%-m/%-d" 2>/dev/null)
        [ -n "$CUR_RESET_DATE" ] && CUR_RESET="  ~${CUR_RESET_DATE}"
      fi

      LINE_CURSOR="🖱️ Cursor  ${CUR_COLOR}${CUR_BAR}  ${CUR_PCT_INT}%${RESET}  \$${CUR_SPEND_DOLLAR}/\$${CUR_LIMIT_DOLLAR}${CUR_RESET}"
    fi
  fi
fi

# === 出力 ===
# 情報セグメント行（動的分割済み）
for line in "${INFO_LINES[@]}"; do
  echo -e "$line"
done
# Anthropic レートリミット行
echo -e "$LINE2"
echo -e "$LINE3"
[ -n "$LINE4" ] && echo -e "$LINE4"
# Codex レートリミット行
[ -n "$LINE_CX1" ] && echo -e "$LINE_CX1"
[ -n "$LINE_CX2" ] && echo -e "$LINE_CX2"
# Cursor 使用量行
[ -n "$LINE_CURSOR" ] && echo -e "$LINE_CURSOR"
# Gemini API使用量行
[ -n "$LINE_GEMINI" ] && echo -e "$LINE_GEMINI"
STATUSLINE_EOF
chmod +x ~/.claude/statusline-command.sh
```

---

## Step 2: `fetch-usage.sh` を作成（Anthropic Usage API）

```bash
cat > ~/.claude/fetch-usage.sh << 'FETCH_EOF'
#!/bin/bash
# Usage API データを取得してキャッシュに保存
# SessionStart / Stop hook から呼ばれる

CACHE="/tmp/claude-usage-cache.json"
LOCK="/tmp/claude-usage-fetch.lock"
COOLDOWN=30

# クールダウン: 直近30秒以内に取得済みならスキップ
if [ -f "$LOCK" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$lock_age" -lt "$COOLDOWN" ]; then
    exit 0
  fi
fi
touch "$LOCK"

# macOSキーチェーンからOAuthトークン取得
token_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
[ -z "$token_json" ] && exit 0

access_token=$(echo "$token_json" | jq -r '.claudeAiOauth.accessToken // .accessToken // empty')
[ -z "$access_token" ] && exit 0

# usage API呼び出し（ベータヘッダー必須）
tmpfile="/tmp/claude-usage-response.tmp"
hdrfile="/tmp/claude-usage-headers.tmp"
http_code=$(curl -s --max-time 3 -o "$tmpfile" -D "$hdrfile" -w "%{http_code}" \
  -H "Authorization: Bearer $access_token" \
  -H "anthropic-beta: oauth-2025-04-20" \
  "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

usage=""
[ -f "$tmpfile" ] && usage=$(cat "$tmpfile")
rm -f "$tmpfile" "$hdrfile"

if [ "$http_code" = "200" ] && [ -n "$usage" ]; then
  echo "$usage" > "$CACHE"
  rm -f /tmp/claude-usage-debug.json
else
  retry_after=""
  [ -f "$hdrfile" ] && retry_after=$(grep -i "retry-after" "$hdrfile" | head -1 | tr -d '\r' | sed 's/[^:]*: *//')
  echo '{"error":"fetch_failed","http_code":"'"$http_code"'","retry_after":"'"$retry_after"'","timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > /tmp/claude-usage-debug.json
fi
FETCH_EOF
chmod +x ~/.claude/fetch-usage.sh
```

**キャッシュ構造** (`/tmp/claude-usage-cache.json`):
```json
{
  "five_hour": { "utilization": 40.5, "resets_at": "2026-03-12T06:00:00.000Z" },
  "seven_day": { "utilization": 20.1, "resets_at": "2026-03-15T07:00:00.000Z" },
  "extra_usage": { "is_enabled": true, "used_credits": 250, "monthly_limit": 5000, "utilization": 5.0 }
}
```

---

## Step 3: `fetch-codex-usage.sh` を作成（Codex CLI Usage API）

```bash
cat > ~/.claude/fetch-codex-usage.sh << 'CODEX_EOF'
#!/bin/bash
# Codex CLI Usage API データを取得してキャッシュに保存
# SessionStart / Stop hook から呼ばれる

CACHE="/tmp/codex-usage-cache.json"
LOCK="/tmp/codex-usage-fetch.lock"
COOLDOWN=30

# クールダウン
if [ -f "$LOCK" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  if [ "$lock_age" -lt "$COOLDOWN" ]; then
    exit 0
  fi
fi
touch "$LOCK"

# 認証情報取得（ファイルフォールバック: ~/.codex/auth.json）
AUTH_FILE="${CODEX_HOME:-$HOME/.codex}/auth.json"
access_token=""
account_id=""

if [ -f "$AUTH_FILE" ]; then
  access_token=$(jq -r '.tokens.access_token // empty' "$AUTH_FILE")
  account_id=$(jq -r '.tokens.account_id // empty' "$AUTH_FILE")
fi

# キーチェーンからも試行
if [ -z "$access_token" ]; then
  codex_home="${CODEX_HOME:-$HOME/.codex}"
  resolved_home=$(cd "$codex_home" 2>/dev/null && pwd || echo "$codex_home")
  store_key="cli|$(echo -n "$resolved_home" | shasum -a 256 | cut -c1-16)"
  keyring_json=$(security find-generic-password -s "Codex Auth" -a "$store_key" -w 2>/dev/null)
  if [ -n "$keyring_json" ]; then
    access_token=$(echo "$keyring_json" | jq -r '.tokens.access_token // empty')
    account_id=$(echo "$keyring_json" | jq -r '.tokens.account_id // empty')
  fi
fi

[ -z "$access_token" ] && exit 0

# Usage API呼び出し
tmpfile="/tmp/codex-usage-response.tmp"
curl_headers=(-H "Authorization: Bearer $access_token")
[ -n "$account_id" ] && curl_headers+=(-H "ChatGPT-Account-Id: $account_id")

http_code=$(curl -s --max-time 3 -o "$tmpfile" -w "%{http_code}" \
  "${curl_headers[@]}" \
  "https://chatgpt.com/backend-api/wham/usage" 2>/dev/null)

if [ "$http_code" = "200" ] && [ -f "$tmpfile" ]; then
  jq '{
    primary: {
      used_percent: .rate_limit.primary_window.used_percent,
      resets_at: .rate_limit.primary_window.reset_at,
      window_seconds: .rate_limit.primary_window.limit_window_seconds
    },
    secondary: {
      used_percent: .rate_limit.secondary_window.used_percent,
      resets_at: .rate_limit.secondary_window.reset_at,
      window_seconds: .rate_limit.secondary_window.limit_window_seconds
    },
    plan_type: .plan_type,
    limit_reached: .rate_limit.limit_reached
  }' "$tmpfile" > "$CACHE" 2>/dev/null
fi
rm -f "$tmpfile"
CODEX_EOF
chmod +x ~/.claude/fetch-codex-usage.sh
```

**キャッシュ構造** (`/tmp/codex-usage-cache.json`):
```json
{
  "primary": { "used_percent": 0, "resets_at": 1741862400, "window_seconds": 18000 },
  "secondary": { "used_percent": 0, "resets_at": 1742313600, "window_seconds": 604800 },
  "plan_type": "plus",
  "limit_reached": false
}
```

---

## Step 3.5: `fetch-cursor-usage.sh` を作成（Cursor Usage API）

Cursor IDE の使用量を gRPC Connect protocol で取得する。Cursor アプリ内部の `DashboardService` エンドポイントを使用。

```bash
cat > ~/.claude/fetch-cursor-usage.sh << 'CURSOR_EOF'
#!/bin/bash
# Cursor Usage API データを取得してキャッシュに保存
# SessionStart / Stop hook から呼ばれる
# gRPC Connect protocol で DashboardService を呼び出す

CACHE="/tmp/cursor-usage-cache.json"
LOCK="/tmp/cursor-usage-fetch.lock"
COOLDOWN=60

if [ -f "$LOCK" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  [ "$lock_age" -lt "$COOLDOWN" ] && exit 0
fi
touch "$LOCK"

# キーチェーンからアクセストークン取得
access_token=$(security find-generic-password -s "cursor-access-token" -a "cursor-user" -w 2>/dev/null)
[ -z "$access_token" ] && exit 0

# GetCurrentPeriodUsage (gRPC Connect protocol)
usage_tmp="/tmp/cursor-usage-response.tmp"
http_code=$(curl -s --max-time 5 -o "$usage_tmp" -w "%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $access_token" \
  -H "Content-Type: application/json" \
  -H "Connect-Protocol-Version: 1" \
  -d '{}' \
  "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage" 2>/dev/null)

if [ "$http_code" = "200" ] && [ -f "$usage_tmp" ]; then
  # GetPlanInfo も取得
  plan_tmp="/tmp/cursor-plan-response.tmp"
  curl -s --max-time 5 -o "$plan_tmp" \
    -X POST \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -H "Connect-Protocol-Version: 1" \
    -d '{}' \
    "https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo" 2>/dev/null

  # キャッシュ形式に統合
  jq -s '
    {
      plan_name: (.[1].planInfo.planName // "?"),
      included_cents: (.[1].planInfo.includedAmountCents // 0),
      price: (.[1].planInfo.price // "?"),
      billing_cycle_start: .[0].billingCycleStart,
      billing_cycle_end: .[0].billingCycleEnd,
      total_spend_cents: (.[0].planUsage.totalSpend // 0),
      included_spend_cents: (.[0].planUsage.includedSpend // 0),
      bonus_spend_cents: (.[0].planUsage.bonusSpend // 0),
      limit_cents: (.[0].planUsage.limit // 0),
      auto_pct: (.[0].planUsage.autoPercentUsed // 0),
      api_pct: (.[0].planUsage.apiPercentUsed // 0),
      total_pct: (.[0].planUsage.totalPercentUsed // 0),
      fetched_at: now | todate
    }
  ' "$usage_tmp" "$plan_tmp" > "$CACHE" 2>/dev/null

  rm -f "$plan_tmp"
fi
rm -f "$usage_tmp"
CURSOR_EOF
chmod +x ~/.claude/fetch-cursor-usage.sh
```

**前提条件**:
- Cursor IDE がインストール済みでログイン済み
- macOS キーチェーンに `cursor-access-token` が存在すること（Cursor ログイン時に自動保存される）

**API エンドポイント**:

| エンドポイント | プロトコル | 内容 |
|-------------|----------|------|
| `aiserver.v1.DashboardService/GetCurrentPeriodUsage` | gRPC Connect (POST + JSON) | 使用量・%・支出額 |
| `aiserver.v1.DashboardService/GetPlanInfo` | gRPC Connect (POST + JSON) | プラン名・上限・請求サイクル |

> **注意**: これらは Cursor アプリ内部で使用される非公開 API。Cursor のバンドルソース
> (`/Applications/Cursor.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js`)
> から gRPC サービス定義を逆引きして特定した。将来のアップデートで変更される可能性がある。

**キャッシュ構造** (`/tmp/cursor-usage-cache.json`):
```json
{
  "plan_name": "Team",
  "included_cents": 2000,
  "price": "$40/mo",
  "billing_cycle_start": "1771414738000",
  "billing_cycle_end": "1773833938000",
  "total_spend_cents": 2257,
  "included_spend_cents": 2000,
  "bonus_spend_cents": 257,
  "limit_cents": 2000,
  "auto_pct": 0,
  "api_pct": 28.21,
  "total_pct": 28.21,
  "fetched_at": "2026-03-12T04:23:38Z"
}
```

**表示の計算方法**:
- **使用率%**: `min(included_spend_cents / limit_cents * 100, 100)`（ダッシュボードと同じ計算）
- **支出額**: `total_spend_cents / 100`（bonusSpend含む実額。上限超過が見える）
- **上限**: `limit_cents / 100`（プラン付属の個人枠）
- **リセット日**: `billing_cycle_end`（エポックミリ秒→JST変換）

---

## Step 4: Gemini API使用量トラッカー

Gemini APIを呼ぶNode.jsスクリプトに組み込むトラッカーモジュール。`@google/generative-ai` のレスポンスから `usageMetadata` を取得してコスト（円）を**請求サイクル単位**で積算する。

### 4a. トラッカーモジュール

```javascript
// <プロジェクト>/scripts/gemini-usage-tracker.js
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { homedir } from "os";
import { join } from "path";

const CACHE_DIR = join(homedir(), ".claude");
const CACHE_PATH = join(CACHE_DIR, "gemini-usage-cache.json");
const CONFIG_PATH = join(CACHE_DIR, "gemini-usage-config.json");

// Gemini API料金テーブル（USD per unit）
const PRICING = {
  "gemini-3.1-flash-image": {
    input_per_1m_tokens: 0.10,
    output_per_1m_tokens: 0.40,
    per_image_output: 0.0315,
  },
  "gemini-2.5-pro-preview-06-05": {
    input_per_1m_tokens: 1.25,
    output_per_1m_tokens: 10.00,
    per_image_output: 0.04,
  },
  "gemini-2.0-flash": {
    input_per_1m_tokens: 0.10,
    output_per_1m_tokens: 0.40,
    per_image_output: 0.0315,
  },
  default: {
    input_per_1m_tokens: 0.50,
    output_per_1m_tokens: 2.00,
    per_image_output: 0.04,
  },
};

function loadConfig() {
  const defaults = { billing_cycle_start_day: 1, usd_to_jpy: 150 };
  if (!existsSync(CONFIG_PATH)) return defaults;
  try { return { ...defaults, ...JSON.parse(readFileSync(CONFIG_PATH, "utf-8")) }; }
  catch { return defaults; }
}

function currentBillingPeriod(startDay) {
  const now = new Date();
  let year = now.getFullYear(), month = now.getMonth() + 1;
  if (now.getDate() < startDay) { month -= 1; if (month === 0) { month = 12; year -= 1; } }
  return `${year}-${String(month).padStart(2,"0")}-${String(startDay).padStart(2,"0")}`;
}

export function trackGeminiUsage(response, model, hasImageOutput = false) {
  try {
    const usageMetadata = response.response?.usageMetadata;
    if (!usageMetadata) return;

    const config = loadConfig();
    const pricing = PRICING[model] || PRICING["default"];
    const inputTokens = usageMetadata.promptTokenCount || 0;
    const outputTokens = usageMetadata.candidatesTokenCount || 0;

    const totalCostJpy = (
      (inputTokens / 1_000_000) * pricing.input_per_1m_tokens +
      (outputTokens / 1_000_000) * pricing.output_per_1m_tokens +
      (hasImageOutput ? pricing.per_image_output : 0)
    ) * config.usd_to_jpy;

    const period = currentBillingPeriod(config.billing_cycle_start_day);
    let cache = { period, total_input_tokens: 0, total_output_tokens: 0,
                  total_images: 0, calc_cost_jpy: 0, api_cost_jpy: null,
                  api_fetched_at: null, calls: 0 };

    mkdirSync(CACHE_DIR, { recursive: true });
    if (existsSync(CACHE_PATH)) {
      try {
        const existing = JSON.parse(readFileSync(CACHE_PATH, "utf-8"));
        if (existing.period === period) cache = { ...cache, ...existing };
      } catch {}
    }

    cache.period = period;
    cache.total_input_tokens += inputTokens;
    cache.total_output_tokens += outputTokens;
    cache.total_images += hasImageOutput ? 1 : 0;
    cache.calc_cost_jpy = Math.round((cache.calc_cost_jpy + totalCostJpy) * 100) / 100;
    cache.calls += 1;
    cache.last_updated = new Date().toISOString();

    writeFileSync(CACHE_PATH, JSON.stringify(cache, null, 2));
  } catch (error) {
    console.error(`[gemini-tracker] エラー: ${error.message}`);
  }
}
```

**使い方**: Gemini API呼び出し後に `trackGeminiUsage(response, modelName, true)` を呼ぶだけ。

### 4b. 設定ファイル

```bash
cat > ~/.claude/gemini-usage-config.json << 'EOF'
{
  "billing_cycle_start_day": 1,
  "usd_to_jpy": 150
}
EOF
```

- `billing_cycle_start_day`: GCPの請求サイクル開始日（毎月1日なら `1`）
- `usd_to_jpy`: USD→JPY換算レート（ローカル計算で使用）
- `bigquery_billing_table`: BigQuery Billing Exportテーブル名（後述のStep 6で設定）

### 4c. `fetch-gemini-usage.sh`（BigQuery実額取得）

```bash
cat > ~/.claude/fetch-gemini-usage.sh << 'GEMINI_EOF'
#!/bin/bash
# BigQuery Billing Export から Gemini API の実際の請求額を取得
# 設定: ~/.claude/gemini-usage-config.json の bigquery_billing_table
# 未設定の場合はスキップ（ローカル計算値にフォールバック）

CACHE="$HOME/.claude/gemini-usage-cache.json"
CONFIG="$HOME/.claude/gemini-usage-config.json"
LOCK="/tmp/gemini-usage-fetch.lock"
COOLDOWN=300

if [ -f "$LOCK" ]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK" 2>/dev/null || echo 0) ))
  [ "$lock_age" -lt "$COOLDOWN" ] && exit 0
fi
touch "$LOCK"

[ -f "$CONFIG" ] || exit 0
BQ_TABLE=$(jq -r '.bigquery_billing_table // empty' "$CONFIG" 2>/dev/null)
[ -z "$BQ_TABLE" ] && exit 0
command -v bq &>/dev/null || exit 0

CYCLE_DAY=$(jq -r '.billing_cycle_start_day // 1' "$CONFIG" 2>/dev/null)
TODAY_DAY=$(date "+%-d")
if [ "$TODAY_DAY" -lt "$CYCLE_DAY" ] 2>/dev/null; then
  PERIOD_START=$(date -v-1m "+%Y-%m-$(printf '%02d' "$CYCLE_DAY")")
else
  PERIOD_START=$(date "+%Y-%m-$(printf '%02d' "$CYCLE_DAY")")
fi

# 請求アカウントがJPY建ての場合、costは直接円で返る
API_COST_JPY=$(bq query --nouse_legacy_sql --format=json --max_rows=1 \
  "SELECT ROUND(SUM(cost + IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 2) as total_cost
   FROM \`$BQ_TABLE\`
   WHERE service.description = 'Gemini API'
     AND usage_start_time >= TIMESTAMP('$PERIOD_START')
     AND usage_start_time < CURRENT_TIMESTAMP()" 2>/dev/null \
  | jq -r '.[0].total_cost // empty' 2>/dev/null)

if [ -n "$API_COST_JPY" ] && [ "$API_COST_JPY" != "null" ] && [ -f "$CACHE" ]; then
  jq --argjson cost "$API_COST_JPY" \
     --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
     '.api_cost_jpy = $cost | .api_fetched_at = $ts' \
     "$CACHE" > "${CACHE}.tmp" 2>/dev/null && mv "${CACHE}.tmp" "$CACHE"
fi
GEMINI_EOF
chmod +x ~/.claude/fetch-gemini-usage.sh
```

**キャッシュ構造** (`~/.claude/gemini-usage-cache.json`):
```json
{
  "period": "2026-03-01",
  "billing_cycle_start_day": 1,
  "total_input_tokens": 5000,
  "total_output_tokens": 300,
  "total_images": 2,
  "calc_cost_jpy": 4.77,
  "api_cost_jpy": null,
  "api_fetched_at": null,
  "calls": 2,
  "last_updated": "2026-03-12T10:30:00.000Z"
}
```

- `calc_cost_jpy`: usageMetadata × 料金テーブルの計算値（リアルタイム更新）
- `api_cost_jpy`: BigQuery Billing Exportからの実額（fetch-gemini-usage.shが更新。未設定時はnull）
- ステータスラインは `api_cost_jpy` を優先し、なければ `calc_cost_jpy` を `[計算]` 表示

---

## Step 5: `settings.json` を設定

既存の `settings.json` に以下を追記・マージする。

> **注意**: 既存の `hooks` や設定がある場合は上書きせず、該当キーを追加・マージすること。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/fetch-usage.sh", "timeout": 5 },
          { "type": "command", "command": "bash ~/.claude/fetch-codex-usage.sh", "timeout": 5 },
          { "type": "command", "command": "bash ~/.claude/fetch-cursor-usage.sh", "timeout": 5 },
          { "type": "command", "command": "bash ~/.claude/fetch-gemini-usage.sh", "timeout": 10 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/fetch-usage.sh &", "timeout": 1 },
          { "type": "command", "command": "bash ~/.claude/fetch-codex-usage.sh &", "timeout": 1 },
          { "type": "command", "command": "bash ~/.claude/fetch-cursor-usage.sh &", "timeout": 1 },
          { "type": "command", "command": "bash ~/.claude/fetch-gemini-usage.sh &", "timeout": 1 }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh 2>/dev/null | sed 's/\\\\x1b\\\\[[0-9;]*m//g'",
    "padding": 4
  }
}
```

**ポイント**:
- `SessionStart`: セッション開始時にデータを取得（最大5〜10秒待機）
- `Stop`: 各応答完了後にバックグラウンドで取得（応答をブロックしない）
- `fetch-gemini-usage.sh`: BigQuery未設定時は即座にexit 0（影響なし）
- `sed` によるANSI除去: Claude Codeレンダラーがカラーコードを正しく処理しない場合の安全策
- `padding: 4`: ステータスライン表示領域を確保

---

## Step 6: BigQuery Billing Export セットアップ（オプション）

Gemini APIの**実際の請求額**をステータスラインに表示するには、BigQuery Billing Exportの設定が必要。未設定でもローカル計算値 `[計算]` で動作する。

### セットアップ手順

1. **BigQuery APIを有効化**
   ```bash
   gcloud services enable bigquery.googleapis.com
   ```

2. **GCP Console で Billing Export を有効化**
   - [GCP Console → Billing → Billing Export](https://console.cloud.google.com/billing/export) にアクセス
   - 「BigQuery Export」タブ → 「標準の使用料金」を「有効」にする
   - データセット名を指定（例: `billing_export`）
   - プロジェクトを選択

3. **24〜48時間待つ**（初回データ蓄積に時間がかかる）

4. **テーブル名を確認**
   ```bash
   bq ls YOUR_PROJECT_ID:billing_export
   # 出力例: gcp_billing_export_v1_0155BA_C409C8_543227
   ```

5. **設定ファイルに追記**
   ```bash
   # ~/.claude/gemini-usage-config.json
   {
     "billing_cycle_start_day": 1,
     "usd_to_jpy": 150,
     "bigquery_billing_table": "YOUR_PROJECT_ID.billing_export.gcp_billing_export_v1_XXXXXX_XXXXXX_XXXXXX"
   }
   ```

6. **動作確認**
   ```bash
   bash ~/.claude/fetch-gemini-usage.sh
   cat ~/.claude/gemini-usage-cache.json | jq '.api_cost_jpy, .api_fetched_at'
   ```

### なぜBigQuery Export が必要か

Google Cloud には「APIで請求額を直接取得する」エンドポイントが存在しない。特に：
- **Cloud Monitoring API**: Google AI Studio APIキー経由の呼び出しはメトリクスが蓄積されない
- **Cloud Billing API**: 請求アカウント情報のみ。コスト明細はない
- **BigQuery Billing Export**: 唯一の公式な詳細コストデータソース

BigQuery Exportを有効にすると、サービス別・SKU別のコストがBigQueryテーブルに蓄積される。`fetch-gemini-usage.sh` はこのテーブルから「Gemini API」のコストを合計する。

---

## 動作確認

```bash
# 手動テスト（キャッシュが空でも基本行は表示される）
echo '{}' | bash ~/.claude/statusline-command.sh 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'

# キャッシュ内容確認
cat /tmp/claude-usage-cache.json | jq .
cat /tmp/codex-usage-cache.json | jq .
cat /tmp/gemini-usage-cache.json | jq .

# API取得が失敗している場合のデバッグ
cat /tmp/claude-usage-debug.json
```

---

## トラブルシューティング

### ステータスライン自体が表示されない

`settings.json` の `statusLine` に `"type": "command"` が必須。省略すると Settings Error になる。

### レートリミットが「データ取得不可」のまま

1. API が 429 Rate Limited → しばらく待つ（30秒クールダウンで連続呼び出し防止済み）
2. OAuthトークンが取得できていない → `claude login` で再ログイン
   ```bash
   security find-generic-password -s "Claude Code-credentials" -w | jq .claudeAiOauth.accessToken
   ```

### Codex行が表示されない

Codex CLIにログインしていない、または `~/.codex/auth.json` が存在しない。Codex未使用なら表示されないのが正常。

### Cursor行が表示されない

Cursor IDE にログインしていない、またはキーチェーンにトークンがない。確認方法:
```bash
security find-generic-password -s "cursor-access-token" -a "cursor-user" -w | head -c 20
```
トークンが取得できなければ Cursor IDE を起動してログインし直す。

### Gemini行が ¥0 のまま

Gemini APIを使ったスクリプト（画像生成等）を実行するまで ¥0 が表示される。これは正常動作。

### Gemini行が常に [計算] のまま

BigQuery Billing Export が未設定。Step 6 のセットアップを行えば `[API]` 表示に切り替わる。ローカル計算値でも ±5% の精度があるため、未設定でも実用上問題ない。

### BigQuery クエリがエラーになる

- テーブル名が正しいか確認: `bq ls PROJECT_ID:DATASET_NAME`
- gcloud認証が有効か確認: `gcloud auth application-default print-access-token`
- BigQuery APIが有効か確認: `gcloud services list --enabled | grep bigquery`

### 時刻がおかしい（JST変換ズレ）

APIはUTCで時刻を返す。`TZ=UTC date -jf` でパースしないと9時間ずれる。

### multi-lineが1行しか出ない

`padding` の値を増やす（行数分必要）。8行出力なら `"padding": 4` 以上を指定。

---

## 設計上の注意

1. すべてのスクリプトは `#!/bin/bash` で動作する
2. macOS固有: `date -jf`, `security find-generic-password`, `stat -f %m`
3. Linux移植時は `date -d`, `secret-tool`, `stat -c %Y` 等に変更が必要
4. curlは `--max-time 3` でタイムアウトを短く設定（ステータスライン更新をブロックしない）
5. フックのSessionStartでは同期実行（timeout: 5）、Stopでは `&` でバックグラウンド実行（timeout: 1）
6. ステータスラインスクリプト内では**絶対にAPI呼び出しをしない**（速度と安定性のため）
