#!/usr/bin/env bash
# Claude Code statusLine script — oh-my-posh inspired
# Receives JSON on stdin; outputs a single status line.

input=$(cat)

cwd=$(echo "$input"       | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input"     | jq -r '.model.display_name // "?"')
total=$(echo "$input"    | jq -r '.context_window.context_window_size // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used=$(echo "$input"     | jq -r 'if .context_window.used_percentage and .context_window.context_window_size then (.context_window.used_percentage * .context_window.context_window_size / 100 | round) else empty end')
effort=$(echo "$input"    | jq -r '.effort.level // empty')
vim_mode=$(echo "$input"  | jq -r '.vim.mode // empty')
rl_pct=$(echo "$input"    | jq -r '.rate_limits.five_hour.used_percentage // empty')
w7_pct=$(echo "$input"    | jq -r '.rate_limits.seven_day.used_percentage // empty')

branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'
DIM='\033[2m'

# compact token formatter: 21335 -> 21k, 12166850 -> 12.1M
fmt_tok() {
  local n=${1:-0}
  if   [ "$n" -ge 1000000 ] 2>/dev/null; then echo "$(( n / 1000000 )).$(( (n % 1000000) / 100000 ))M"
  elif [ "$n" -ge 1000 ]    2>/dev/null; then echo "$(( n / 1000 ))k"
  else echo "$n"; fi
}

cwd_fwd="${cwd//\\//}"
home_fwd="${HOME//\\//}"
short_cwd="${cwd_fwd/#$home_fwd/~}"

ctx_part=""
if [ -n "$used" ] && [ -n "$total" ]; then
  used_k=$(( (used + 500) / 1000 ))
  total_k=$(( (total + 500) / 1000 ))
  pct_int=$(printf '%.0f' "${used_pct:-0}")
  if   [ "$pct_int" -ge 90 ]; then ctx_colour="$RED"
  elif [ "$pct_int" -ge 70 ]; then ctx_colour="$YELLOW"
  else                               ctx_colour="$GREEN"
  fi
  if   [ "$pct_int" -ge 88 ]; then ctx_icon="●"
  elif [ "$pct_int" -ge 62 ]; then ctx_icon="◕"
  elif [ "$pct_int" -ge 38 ]; then ctx_icon="◑"
  elif [ "$pct_int" -ge 12 ]; then ctx_icon="◔"
  else                              ctx_icon="○"
  fi
  ctx_part="${ctx_colour}${ctx_icon} ${used_k}k/${total_k}k${RESET}"
fi

rl_part=""
if [ -n "$rl_pct" ]; then
  rl_int=$(printf '%.0f' "$rl_pct")
  if   [ "$rl_int" -ge 90 ]; then rl_colour="$RED"
  elif [ "$rl_int" -ge 70 ]; then rl_colour="$YELLOW"
  else                              rl_colour="$DIM"
  fi
  rl_part="${rl_colour}5h:${rl_int}%${RESET}"
fi

w7_part=""
if [ -n "$w7_pct" ]; then
  w7_int=$(printf '%.0f' "$w7_pct")
  if   [ "$w7_int" -ge 90 ]; then w7_colour="$RED"
  elif [ "$w7_int" -ge 70 ]; then w7_colour="$YELLOW"
  else                              w7_colour="$DIM"
  fi
  w7_part="${w7_colour}7d:${w7_int}%${RESET}"
fi

effort_part=""
if [ -n "$effort" ]; then
  effort_part="${DIM}[${effort}]${RESET}"
fi

# Sum the gaps between consecutive events. Everything the machine does counts
# in full — model thinking/responding and tool execution, however long. Only
# *human* idle is dropped: the gap before a human prompt (you reading/typing/
# away) counts only when <= IDLE_GAP_SECS. A user entry is a human prompt when
# it has no toolUseResult; tool-result entries are machine work, counted fully.
# Cached by transcript mtime so the file is parsed only when it grows.
IDLE_GAP_SECS=60
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
secs=0
inp=0
out=0
ctok=0
cache_dir="$HOME/.claude/.thinking-cache"
mkdir -p "$cache_dir" 2>/dev/null
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  key=$(printf '%s' "$transcript" | md5sum 2>/dev/null | cut -d' ' -f1)
  [ -z "$key" ] && key=$(printf '%s' "$transcript" | cksum | tr -d ' ')
  cache_file="$cache_dir/$key"
  mtime=$(stat -c %Y "$transcript" 2>/dev/null || stat -f %m "$transcript" 2>/dev/null)
  data=""
  if [ -f "$cache_file" ]; then
    read -r c_mtime c_secs c_inp c_out c_ctok < "$cache_file"
    [ "$c_mtime" = "$mtime" ] && data="$c_secs $c_inp $c_out $c_ctok"
  fi
  if [ -z "$data" ]; then
    data=$(jq -R 'fromjson? // empty' "$transcript" 2>/dev/null | jq -s -r --argjson idle "$IDLE_GAP_SECS" '
      . as $all
      | ([ $all[]
            | select(.isSidechain != true and .isMeta != true)
            | select(.type=="user" or .type=="assistant")
            | select(.timestamp != null)
            | { human: (.type == "user" and .toolUseResult == null),
                ts: (.timestamp | sub("\\.[0-9]+";"") | (try fromdateiso8601 catch null)) }
            | select(.ts != null) ]) as $e
      | ([ range(1; ($e|length)) as $i
            | ($e[$i].ts - $e[$i-1].ts) as $d
            | if $e[$i].human
              then (if $d > 0 and $d <= $idle then $d else 0 end)
              else (if $d > 0 then $d else 0 end)
              end ] | add // 0) as $secs
      | ([ $all[] | select(.type=="assistant") | .message.usage // {} ]) as $u
      | ($u | map(.input_tokens // 0) | add // 0) as $inp
      | ($u | map(.output_tokens // 0) | add // 0) as $out
      | ($u | map(.cache_creation_input_tokens // 0) | add // 0) as $ctok
      | "\($secs) \($inp) \($out) \($ctok)"
    ' 2>/dev/null)
    [ -z "$data" ] && data="0 0 0 0"
    printf '%s %s\n' "$mtime" "$data" > "$cache_file"
  fi
  read -r secs inp out ctok <<< "$data"
fi

# floor against live API-duration so an in-progress turn never reads lower
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
api_s=$(( ${api_ms%.*} / 1000 ))
th_s=${secs:-0}
[ "$api_s" -gt "$th_s" ] 2>/dev/null && th_s=$api_s

think_part=""
if [ "${th_s:-0}" -gt 0 ] 2>/dev/null; then
  if [ "$th_s" -ge 3600 ]; then
    think_disp="$(( th_s / 3600 ))h $(( (th_s % 3600) / 60 ))m"
  elif [ "$th_s" -ge 60 ]; then
    think_disp="$(( th_s / 60 ))m $(( th_s % 60 ))s"
  else
    think_disp="${th_s}s"
  fi
  think_part="${DIM}🧠 ${think_disp}${RESET}"
fi

# cumulative tokens this session, split: input / output / cache
tok_part=""
if [ "$(( ${inp:-0} + ${out:-0} + ${ctok:-0} ))" -gt 0 ] 2>/dev/null; then
  tok_part="${DIM}♻️ $(fmt_tok "${ctok:-0}") ⏬ $(fmt_tok "${out:-0}") ⏫ $(fmt_tok "${inp:-0}")${RESET}"
fi

vim_part=""
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT)      vim_colour="$GREEN"   ;;
    NORMAL)      vim_colour="$BLUE"    ;;
    VISUAL*)     vim_colour="$MAGENTA" ;;
    *)           vim_colour="$DIM"     ;;
  esac
  vim_part="${vim_colour}${vim_mode}${RESET}"
fi

# Segment order: dir | branch | model | effort | ctx | 5h | 7d | vim
parts=""
parts="${BOLD}${CYAN}${short_cwd}${RESET}"

if [ -n "$branch" ]; then
  parts="${parts}  ${YELLOW}${branch}${RESET}"
fi

parts="${parts}  ${MAGENTA}${model}${RESET}"

if [ -n "$effort_part" ]; then
  parts="${parts} ${effort_part}"
fi

if [ -n "$think_part" ]; then
  parts="${parts}  ${think_part}"
fi

if [ -n "$tok_part" ]; then
  parts="${parts}  ${tok_part}"
fi

if [ -n "$ctx_part" ]; then
  parts="${parts}  ${ctx_part}"
fi

if [ -n "$rl_part" ] || [ -n "$w7_part" ]; then
  parts="${parts}  ${DIM}⏳${RESET}"
  [ -n "$rl_part" ] && parts="${parts} ${rl_part}"
  [ -n "$w7_part" ] && parts="${parts} ${w7_part}"
fi

if [ -n "$vim_part" ]; then
  parts="${parts}  ${vim_part}"
fi

printf "%b\n" "$parts"
