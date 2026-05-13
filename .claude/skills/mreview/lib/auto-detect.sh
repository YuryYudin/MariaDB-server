#!/usr/bin/env bash
# Phase 1d — Auto-detect a review target when the user supplied no arg.
#
# Emits key=value lines on stdout (same shape as resolve-target.sh --dry-run).
# Decision tree (first match wins):
#   1. Dirty + staged  -> type=working_and_staged
#   2. Dirty only      -> type=working
#   3. Staged only     -> type=staged
#   4. Clean, upstream tracked, ahead by >=2 -> type=range, base=<upstream>, head=HEAD
#   5. Otherwise (clean tree)                -> type=last_commit, sha=<HEAD>
set -euo pipefail

# Working tree state: 0 = clean, 1 = dirty.
WORKING_DIRTY=0
git diff --quiet || WORKING_DIRTY=1

STAGED=0
git diff --cached --quiet || STAGED=1

if [ "$WORKING_DIRTY" -eq 1 ] && [ "$STAGED" -eq 1 ]; then
  echo "type=working_and_staged"
  exit 0
fi

if [ "$WORKING_DIRTY" -eq 1 ]; then
  echo "type=working"
  exit 0
fi

if [ "$STAGED" -eq 1 ]; then
  echo "type=staged"
  exit 0
fi

# Clean tree. Check upstream + ahead count.
UPSTREAM=""
if UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
  AHEAD=$(git rev-list --count "${UPSTREAM}..HEAD" 2>/dev/null || echo 0)
  if [ "$AHEAD" -ge 2 ]; then
    echo "type=range"
    echo "base=$UPSTREAM"
    echo "head=HEAD"
    exit 0
  fi
fi

HEAD_SHA=$(git rev-parse HEAD)
echo "type=last_commit"
echo "sha=$HEAD_SHA"
exit 0
