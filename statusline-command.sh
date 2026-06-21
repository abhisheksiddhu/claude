#!/usr/bin/env bash

input=$(cat)

eval "$(printf '%s' "$input" | jq -r '@sh "
cwd=\(.workspace.current_dir // .cwd // "?")
model=\(.model.display_name // "?")
total=\(.context_window.context_window_size // "")
used_pct=\(.context_window.used_percentage // "")
effort=\(.effort.level // "")
vim_mode=\(.vim.mode // "")
rl_pct=\(.rate_limits.five_hour.used_percentage // "")
w7_pct=\(.rate_limits.seven_day.used_percentage // "")
cost=\(.cost.total_cost_usd // "")
api_ms=\(.cost.total_api_duration_ms // 0)
transcript=\(.transcript_path // "")"' 2>/dev/null)"

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
RED='\033[31m'
BLUE='\033[34m'
DIM='\033[2m'

fmt_dur() {
  local s=${1:-0}
  if   [ "$s" -ge 3600 ]; then dur_out="$(( s / 3600 ))h $(( (s % 3600) / 60 ))m"
  elif [ "$s" -ge 60 ];   then dur_out="$(( s / 60 ))m $(( s % 60 ))s"
  else dur_out="${s}s"; fi
}

pct_colour() {
  if   [ "$1" -ge 90 ]; then col_out="$RED"
  elif [ "$1" -ge 70 ]; then col_out="$YELLOW"
  else col_out="$2"; fi
}

cwd_fwd="${cwd//\\//}"
home_fwd="${HOME//\\//}"
short_cwd="${cwd_fwd/#$home_fwd/~}"

branch=""
d="$cwd_fwd"
while [ -n "$d" ]; do
  if [ -e "$d/.git" ]; then
    if [ -d "$d/.git" ]; then
      git_head="$d/.git/HEAD"
    else
      read -r git_link < "$d/.git"
      git_head="${git_link#gitdir: }/HEAD"
    fi
    if [ -f "$git_head" ]; then
      read -r head_ref < "$git_head"
      case "$head_ref" in
        "ref: refs/heads/"*) branch="${head_ref#ref: refs/heads/}" ;;
        *) branch="${head_ref:0:7}" ;;
      esac
    fi
    break
  fi
  case "$d" in
    */*) d="${d%/*}" ;;
    *) break ;;
  esac
done

ctx_part=""
if [ -n "$used_pct" ] && [ -n "$total" ]; then
  printf -v pct_int '%.0f' "$used_pct"
  used_k=$(( (pct_int * total / 100 + 500) / 1000 ))
  total_k=$(( (total + 500) / 1000 ))
  if   [ "$pct_int" -ge 88 ]; then ctx_icon="●"
  elif [ "$pct_int" -ge 62 ]; then ctx_icon="◕"
  elif [ "$pct_int" -ge 38 ]; then ctx_icon="◑"
  elif [ "$pct_int" -ge 12 ]; then ctx_icon="◔"
  else                              ctx_icon="○"
  fi
  pct_colour "$pct_int" "$GREEN"
  ctx_part="${col_out}${ctx_icon} ${used_k}k/${total_k}k${RESET}"
fi

rl_part=""
if [ -n "$rl_pct" ]; then
  printf -v rl_int '%.0f' "$rl_pct"
  pct_colour "$rl_int" "$DIM"
  rl_part="${col_out}5h:${rl_int}%${RESET}"
fi

w7_part=""
if [ -n "$w7_pct" ]; then
  printf -v w7_int '%.0f' "$w7_pct"
  pct_colour "$w7_int" "$DIM"
  w7_part="${col_out}7d:${w7_int}%${RESET}"
fi

effort_part=""
[ -n "$effort" ] && effort_part="${DIM}[${effort}]${RESET}"

cost_part=""
if [ -n "$cost" ]; then
  printf -v cost_fmt '%.2f' "$cost"
  cost_part="${DIM}\$${cost_fmt}${RESET}"
fi

IDLE_CAP_SECS=900

STEP_JQ='
def epoch:
  (sub("\\.[0-9]+"; "") | fromdateiso8601)
  + (try (capture("\\.(?<f>[0-9]+)").f | "0." + . | tonumber) catch 0);
def kindof:
  if .type == "assistant" then "a"
  elif (.toolUseResult != null)
    or ((.message.content? | type) == "array" and (.message.content | any(.type? == "tool_result")))
  then "t"
  else "h" end;
reduce inputs as $l (
  {ts: ($ts | tonumber), kind: $kind, model: ($m | tonumber), tool: ($t | tonumber), bytes: 0, held: 0};
  (try ($l | fromjson) catch null) as $e
  | ($l | utf8bytelength + 1) as $len
  | if ($e | type) != "object" then .held += $len
    else
      .bytes += (.held + $len) | .held = 0
      | if $e.isSidechain != true and $e.isMeta != true
           and ($e.type == "user" or $e.type == "assistant") and $e.timestamp != null
        then ($e.timestamp | try epoch catch null) as $c
          | if $c == null then .
            else ($e | kindof) as $k
              | (if .ts > 0 and $c > .ts and ($c - .ts) <= $cap then $c - .ts else 0 end) as $g
              | (if $k == "a" then .model += $g elif $k == "t" then .tool += $g else . end)
              | .ts = $c | .kind = $k
            end
        else . end
    end
)
| "\(.bytes + ($off | tonumber)) \(.ts) \(.kind) \(.model) \(.tool)"'

update_cache() {
  local out
  out=$(tail -c +$(( off + 1 )) "$transcript" | jq -Rnr \
    --arg off "$off" --arg ts "$ts" --arg kind "$kind" --arg m "$m" --arg t "$t" \
    --argjson cap "$IDLE_CAP_SECS" \
    "$STEP_JQ" 2>/dev/null)
  if [ -n "$out" ]; then
    printf '%s\n' "$out" > "$cache_file"
    read -r off ts kind m t <<< "$out"
  fi
}

model_s=0
tool_s=0
partial=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  cache_dir="$HOME/.claude/.thinking-cache"
  mkdir -p "$cache_dir" 2>/dev/null
  tpath="${transcript//\\//}"
  key="${tpath##*/}"
  key="${key%.jsonl}"
  cache_file="$cache_dir/$key"
  off=0; ts=0; kind="-"; m=0; t=0
  [ -f "$cache_file" ] && read -r off ts kind m t < "$cache_file"
  if [ ! -f "$cache_file" ] || [ "$transcript" -nt "$cache_file" ]; then
    size=$(stat -c %s "$transcript" 2>/dev/null || stat -f %z "$transcript" 2>/dev/null || echo 0)
    if [ "$size" -lt "$off" ]; then off=0; ts=0; kind="-"; m=0; t=0; fi
    if [ "$size" -gt "$off" ]; then
      if [ $(( size - off )) -gt 4194304 ]; then
        lock="$cache_dir/$key.lock"
        if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +3 2>/dev/null)" ]; then
          rmdir "$lock" 2>/dev/null
        fi
        if mkdir "$lock" 2>/dev/null; then
          ( update_cache; rmdir "$lock" 2>/dev/null ) >/dev/null 2>&1 &
          disown 2>/dev/null
        fi
        partial="…"
      else
        update_cache
      fi
    fi
  fi
  model_s=${m%.*}
  tool_s=${t%.*}
fi

api_ms=${api_ms:-0}
api_s=$(( ${api_ms%.*} / 1000 ))
[ "$api_s" -gt "${model_s:-0}" ] && model_s=$api_s

time_part=""
if [ "${model_s:-0}" -gt 0 ] || [ "${tool_s:-0}" -gt 0 ]; then
  fmt_dur "${model_s:-0}"; model_disp="$dur_out"
  fmt_dur "${tool_s:-0}"; tool_disp="$dur_out"
  time_part="${DIM}🧠 ${model_disp} 🔧 ${tool_disp}${partial}${RESET}"
elif [ -n "$partial" ]; then
  time_part="${DIM}🧠 … 🔧 …${RESET}"
fi

vim_part=""
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT)  vim_colour="$GREEN"   ;;
    NORMAL)  vim_colour="$BLUE"    ;;
    VISUAL*) vim_colour="$MAGENTA" ;;
    *)       vim_colour="$DIM"     ;;
  esac
  vim_part="${vim_colour}${vim_mode}${RESET}"
fi

parts="${BOLD}${CYAN}${short_cwd}${RESET}"
[ -n "$branch" ]      && parts="${parts}  ${YELLOW}${branch}${RESET}"
parts="${parts}  ${MAGENTA}${model}${RESET}"
[ -n "$effort_part" ] && parts="${parts} ${effort_part}"
[ -n "$time_part" ]   && parts="${parts}  ${time_part}"
[ -n "$cost_part" ]   && parts="${parts}  ${cost_part}"
[ -n "$ctx_part" ]    && parts="${parts}  ${ctx_part}"
if [ -n "$rl_part" ] || [ -n "$w7_part" ]; then
  parts="${parts}  ${DIM}⏳${RESET}"
  [ -n "$rl_part" ] && parts="${parts} ${rl_part}"
  [ -n "$w7_part" ] && parts="${parts} ${w7_part}"
fi
[ -n "$vim_part" ] && parts="${parts}  ${vim_part}"

printf "%b\n" "$parts"
