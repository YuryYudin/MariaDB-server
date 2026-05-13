#!/usr/bin/env bash
# Phase 1d — Look up the GitHub PR(s) that match an MDEV ticket.
#
# Real mode: queries `gh search prs`. Fixture mode: reads
# $MREVIEW_FAKE_GH_DIR/search.json (a JSON array of
# {number, repository:{nameWithOwner}} objects).
#
# Exit codes:
#   0  exactly one match (stdout: "<owner/repo> <pr-number>")
#   64 usage error
#   67 zero matches
#   68 multiple matches
set -euo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "usage: $0 MDEV-NNNNN" >&2
  exit 64
fi

MDEV="$1"

if [[ "${MREVIEW_FAKE_GH:-0}" = 1 ]]; then
  if [[ -z "${MREVIEW_FAKE_GH_DIR:-}" ]]; then
    echo "mdev-to-pr.sh: MREVIEW_FAKE_GH=1 but MREVIEW_FAKE_GH_DIR is not set" >&2
    exit 64
  fi
  SEARCH_JSON=$(cat "$MREVIEW_FAKE_GH_DIR/search.json")
else
  SEARCH_JSON=$(gh search prs "$MDEV" --repo MariaDB/server \
                  --json number,repository --limit 10)
fi

COUNT=$(printf '%s' "$SEARCH_JSON" | jq 'length')

if [ "$COUNT" -eq 0 ]; then
  echo "no PR found for $MDEV. Try 'mfix $MDEV' to start a fix from scratch." >&2
  exit 67
fi

if [ "$COUNT" -gt 1 ]; then
  echo "multiple PRs match $MDEV:" >&2
  printf '%s' "$SEARCH_JSON" \
    | jq -r '.[] | "  \(.repository.nameWithOwner)#\(.number)"' >&2
  exit 68
fi

# Exactly one match.
printf '%s' "$SEARCH_JSON" \
  | jq -r '.[0] | "\(.repository.nameWithOwner) \(.number)"'
exit 0
