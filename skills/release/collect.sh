#!/usr/bin/env bash
# Read-only release-context collector for the /release skill.
# Gathers everything needed to write a promotion commit message in ONE invocation:
# target/version detection, the changeset with authors, full bodies, file-stat for
# bodyless commits, and the last release-* commits as a format reference.
# Pure git reads — never commits, stages, tags, merges, or pushes. Safe to pre-approve.
#
# Usage: bash collect.sh [target-ref]
#   target-ref optional; auto-detected (uat if it exists, else main) when omitted.

set -euo pipefail

branch=$(git rev-parse --abbrev-ref HEAD)
version=${branch#dev-}

if [ "${1:-}" != "" ]; then
  target=$1
elif git show-ref --verify --quiet refs/heads/uat || git show-ref --verify --quiet refs/remotes/origin/uat; then
  target=uat
else
  target=main
fi

range="$target..HEAD"

echo "===== META ====="
echo "branch=$branch"
echo "version=$version"
echo "target=$target"
echo "count=$(git rev-list --count "$range")"

echo
echo "===== CHANGESET (author, subject; newest first) ====="
git log "$range" --no-merges --format='%h%x09%an%x09%s'

echo
echo "===== FULL BODIES (oldest first) ====="
git log "$range" --no-merges --reverse --format='----- %h %s -----%n%b'

echo
echo "===== BODYLESS COMMITS — FILE STAT (resolve their module from files) ====="
for h in $(git log "$range" --no-merges --format='%h'); do
  if [ -z "$(git log -1 --format='%b' "$h" | tr -d '[:space:]')" ]; then
    echo "----- $h $(git log -1 --format='%s' "$h") -----"
    git show --stat --format='' "$h" | grep -E '\|' || true
  fi
done

echo
echo "===== FORMAT REFERENCE — last 3 release-* commits on $target ====="
git log "$target" --first-parent --grep '^release-' -3 --format='----- %h -----%n%B'
