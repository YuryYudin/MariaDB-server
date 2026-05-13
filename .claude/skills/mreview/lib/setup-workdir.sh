#!/usr/bin/env bash
# Phase 0 — Setup. Creates $WORK_DIR and populates rulebook + profiles caches
# from the configured review-ref branch (default: main). Idempotent.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <target-id>" >&2
  echo "  <target-id> = PR number / short SHA / sanitized branch / timestamp" >&2
  exit 64
fi
TARGET_ID="$1"

WORK_DIR="${MREVIEW_WORK_DIR:-$HOME/.cache/mreview/$TARGET_ID}"
REVIEW_REF="${MFIX_REVIEW_REF:-main}"

mkdir -p "$WORK_DIR"/{rulebook,profiles,agents}

# Cache rulebook + profiles from $REVIEW_REF so a later branch checkout
# can't make them disappear.
for sub in review reviewers; do
  case "$sub" in
    review)    dest="$WORK_DIR/rulebook"  ;;
    reviewers) dest="$WORK_DIR/profiles"  ;;
  esac
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    out="$dest/$(basename "$path")"
    git show "$REVIEW_REF:$path" > "$out" 2>/dev/null || true
  done < <(git ls-tree -r --name-only "$REVIEW_REF" -- ".claude/$sub/" \
           | grep -E '\.md$' || true)
done

echo "$WORK_DIR"
