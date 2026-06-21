#!/bin/bash
# Auto-sync ~/.claude with the shared remote. Throttled once per 24h.
# Only ever fast-forwards a clean tree; any local work disables it automatically.
# Opt out permanently with: touch ~/.claude/.no-sync
set -uo pipefail
D="$HOME/.claude"
STAMP="$D/.sync-stamp"

[ -f "$D/.no-sync" ] && exit 0
[ -d "$D/.git" ] || exit 0
[ -f "$STAMP" ] && [ -n "$(find "$STAMP" -mtime -1 2>/dev/null)" ] && exit 0
touch "$STAMP"

export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true GIT_SSH_COMMAND="ssh -oBatchMode=yes"
git -C "$D" fetch --quiet origin main 2>/dev/null || exit 0

LOCAL=$(git -C "$D" rev-parse HEAD 2>/dev/null) || exit 0
REMOTE=$(git -C "$D" rev-parse origin/main 2>/dev/null) || exit 0
[ "$LOCAL" = "$REMOTE" ] && exit 0

if [ -n "$(git -C "$D" status --porcelain)" ]; then
  echo "~/.claude: behind origin/main, working tree dirty -> skipping auto-sync."
  exit 0
fi
if ! git -C "$D" merge-base --is-ancestor "$LOCAL" "$REMOTE"; then
  echo "~/.claude: local commits not on origin/main -> skipping auto-sync. Push or reset by hand."
  exit 0
fi

git -C "$D" reset --hard --quiet "$REMOTE" || exit 0
echo "~/.claude: synced to $(git -C "$D" log -1 --format=%h). Restart Claude Code to load new settings/hooks."
