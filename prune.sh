#!/bin/bash
# Prune ~/.claude bloat. Throttled once per 24h. Age-gated — never touches the live session.
set -uo pipefail
D="$HOME/.claude"
STAMP="$D/.prune-stamp"

# throttle: skip if pruned within the last 24h
if [ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mtime -1 2>/dev/null)" ]; then
  exit 0
fi

# Conversations: named (user-assigned custom-title) are important -> keep 30d.
# Unnamed get 5d retention. Empty ones (no assistant turn ever) hold nothing worth
# retaining -> 15m floor, enough to spare a session that just started.
# Each transcript's sidecar dir (<sessionId>/ holding subagents/ + tool-results/)
# is pruned with its transcript.
while IFS= read -r -d '' f; do
  sid="$(basename "$f" .jsonl)"
  dir="$(dirname "$f")/$sid"
  if grep -q '"type":"custom-title"' "$f" 2>/dev/null; then titled=1; else titled=0; fi

  if [ "$titled" -eq 0 ] \
     && ! grep -q '"type":"assistant"' "$f" 2>/dev/null \
     && [ -n "$(find "$f" -mmin +15 2>/dev/null)" ]; then
    rm -f "$f" 2>/dev/null || true
    [ -d "$dir" ] && rm -rf "$dir" 2>/dev/null || true
    continue
  fi

  if [ "$titled" -eq 1 ]; then age=30; else age=5; fi
  if [ -n "$(find "$f" -mtime +"$age" 2>/dev/null)" ]; then
    rm -f "$f" 2>/dev/null || true
    [ -d "$dir" ] && rm -rf "$dir" 2>/dev/null || true
  fi
done < <(find "$D/projects" -mindepth 2 -maxdepth 2 -type f -name '*.jsonl' -print0)

# Orphaned sidecar dirs whose transcript is already gone: 5d.
while IFS= read -r -d '' dir; do
  [ -f "$dir.jsonl" ] || { [ -n "$(find "$dir" -maxdepth 0 -mtime +5 2>/dev/null)" ] && rm -rf "$dir" 2>/dev/null || true; }
done < <(find "$D/projects" -mindepth 2 -maxdepth 2 -type d -print0 2>/dev/null)

find "$D/file-history" "$D/.thinking-cache" -type f -mtime +5 -delete 2>/dev/null || true
for c in paste-cache image-cache shell-snapshots session-env; do
  find "$D/$c" -type f -mtime +1 -delete 2>/dev/null || true
done
find "$D/projects" "$D/file-history" -type d -empty -delete 2>/dev/null || true

touch "$STAMP"
exit 0
