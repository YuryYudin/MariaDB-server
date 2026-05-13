#!/usr/bin/env bash
# Phase 0 — Setup. Creates $WORK_DIR and populates rulebook + profiles caches
# from the configured review-ref branch (default: main). Idempotent.
set -euo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "usage: $0 <target-id>" >&2
  echo "  <target-id> = PR number / short SHA / sanitized branch / timestamp" >&2
  exit 64
fi
TARGET_ID="$1"

case "$TARGET_ID" in
  */*|.*) echo "invalid target-id: $TARGET_ID" >&2; exit 64 ;;
esac

WORK_DIR="${MREVIEW_WORK_DIR:-$HOME/.cache/mreview/$TARGET_ID}"
REVIEW_REF="${MFIX_REVIEW_REF:-main}"

if ! git rev-parse --verify --quiet "$REVIEW_REF^{commit}" >/dev/null; then
  echo "setup-workdir: review ref not found: $REVIEW_REF" >&2
  echo "  (set MFIX_REVIEW_REF to an existing commit-ish; default is 'main')" >&2
  exit 1
fi

mkdir -p "$WORK_DIR"/{rulebook,profiles,agents}

# Cache rulebook + profiles from $REVIEW_REF so a later branch checkout
# can't make them disappear.
for sub in review reviewers; do
  case "$sub" in
    review)    dest="$WORK_DIR/rulebook"  ;;
    reviewers) dest="$WORK_DIR/profiles"  ;;
  esac
  git ls-tree -r --name-only "$REVIEW_REF" -- ".claude/$sub/" \
    | { grep -E '\.md$' || true; } \
    | while IFS= read -r path; do
        [ -z "$path" ] && continue
        out="$dest/$(basename "$path")"
        git show "$REVIEW_REF:$path" > "$out"
      done
done

echo "$WORK_DIR"
