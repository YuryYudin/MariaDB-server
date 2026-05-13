#!/usr/bin/env bash
# Phase 1c — Fetch a GitHub PR's meta, comments, and diff into $MREVIEW_WORK_DIR.
#
# Writes:
#   $WORK_DIR/pr-meta.json              -- gh pr view --json ...
#   $WORK_DIR/pr-existing-comments.json -- gh api .../pulls/N/comments --paginate
#   $WORK_DIR/diff.patch                -- gh pr diff N
#   $WORK_DIR/touched-paths.txt         -- derived from diff.patch
#
# Fixture mode for tests (no network/auth required):
#   MREVIEW_FAKE_GH=1 + MREVIEW_FAKE_GH_DIR=<dir> containing
#     view.json, comments.json, diff.patch
set -euo pipefail

if [ $# -lt 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "usage: $0 <owner/repo> <pr-number>" >&2
  exit 64
fi

REPO="$1"
PR_NUMBER="$2"

if [[ -z "${MREVIEW_WORK_DIR:-}" ]]; then
  echo "fetch-pr.sh: MREVIEW_WORK_DIR is not set" >&2
  exit 64
fi
WORK_DIR="$MREVIEW_WORK_DIR"
mkdir -p "$WORK_DIR"

META_TMP="$WORK_DIR/pr-meta.json.$$"
COMMENTS_TMP="$WORK_DIR/pr-existing-comments.json.$$"
DIFF_TMP="$WORK_DIR/diff.patch.$$"
PATHS_TMP="$WORK_DIR/touched-paths.txt.$$"
trap 'rm -f "$META_TMP" "$COMMENTS_TMP" "$DIFF_TMP" "$PATHS_TMP"' EXIT

if [[ "${MREVIEW_FAKE_GH:-0}" = 1 ]]; then
  if [[ -z "${MREVIEW_FAKE_GH_DIR:-}" ]]; then
    echo "fetch-pr.sh: MREVIEW_FAKE_GH=1 but MREVIEW_FAKE_GH_DIR is not set" >&2
    exit 64
  fi
  cp "$MREVIEW_FAKE_GH_DIR/view.json"     "$META_TMP"
  cp "$MREVIEW_FAKE_GH_DIR/comments.json" "$COMMENTS_TMP"
  cp "$MREVIEW_FAKE_GH_DIR/diff.patch"    "$DIFF_TMP"
else
  gh pr view "$PR_NUMBER" --repo "$REPO" \
    --json number,title,body,baseRefName,headRefOid,author,assignees,reviewRequests,reviews,comments,labels,state,url \
    > "$META_TMP"
  gh api "repos/$REPO/pulls/$PR_NUMBER/comments" --paginate > "$COMMENTS_TMP"
  gh pr diff "$PR_NUMBER" --repo "$REPO" > "$DIFF_TMP"
fi

# Empty diff is a fast-fail: nothing to review.
if [[ ! -s "$DIFF_TMP" ]]; then
  echo "fetched PR diff is empty" >&2
  exit 66
fi

# Derive touched paths from the diff. The spec uses awk's $3 (the "a/<path>"
# field) with the "a/" prefix stripped.
awk '/^diff --git / { sub(/^a\//, "", $3); print $3 }' "$DIFF_TMP" > "$PATHS_TMP"

mv "$META_TMP"     "$WORK_DIR/pr-meta.json"
mv "$COMMENTS_TMP" "$WORK_DIR/pr-existing-comments.json"
mv "$DIFF_TMP"     "$WORK_DIR/diff.patch"
mv "$PATHS_TMP"    "$WORK_DIR/touched-paths.txt"

exit 0
