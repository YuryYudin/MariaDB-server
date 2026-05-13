#!/usr/bin/env bash
# present.sh: print a chat-friendly summary from
# $MREVIEW_WORK_DIR/report.md (everything up to but not including the
# "## Per-agent appendix" section).
#
# For github_pr targets, also write $MREVIEW_WORK_DIR/github-draft.md
# (same content as the chat summary) and print a ready-to-paste
# `gh pr review` command pointing at it.
#
# Inputs (env):
#   MREVIEW_WORK_DIR  required; must contain report.md (non-empty) and
#                     optionally target.json (used to detect github_pr).
#
# Output:
#   stdout: chat summary, optionally followed by a separator + draft
#           file path + a `gh pr review` command for github_pr targets.
#   $MREVIEW_WORK_DIR/github-draft.md  (github_pr targets only)
#
# Exit codes:
#   0   ok
#   64  MREVIEW_WORK_DIR not set
#   70  report.md missing or empty
set -euo pipefail

if [ -z "${MREVIEW_WORK_DIR:-}" ]; then
  echo "present.sh: MREVIEW_WORK_DIR must be set" >&2
  exit 64
fi

WORK_DIR="$MREVIEW_WORK_DIR"
REPORT="$WORK_DIR/report.md"

if [ ! -s "$REPORT" ]; then
  echo "no report at $REPORT" >&2
  exit 70
fi

# Extract everything up to (but not including) the "## Per-agent appendix"
# heading. If the heading is absent, the whole file is printed.
extract_summary() {
  awk '/^## Per-agent appendix/ {exit} {print}' "$REPORT"
}

extract_summary

# Decide whether this is a github_pr target. Absence of target.json or jq
# parse failure -> treat as non-PR target.
TARGET_JSON="$WORK_DIR/target.json"
TARGET_TYPE=""
if [ -f "$TARGET_JSON" ]; then
  TARGET_TYPE="$(jq -r '.type // ""' "$TARGET_JSON" 2>/dev/null || true)"
fi

if [ "$TARGET_TYPE" = "github_pr" ]; then
  DRAFT="$WORK_DIR/github-draft.md"
  extract_summary > "$DRAFT"

  PR_NUMBER="$(jq -r '.pr_number // ""' "$TARGET_JSON" 2>/dev/null || true)"
  REPO="$(jq -r '.repo // ""' "$TARGET_JSON" 2>/dev/null || true)"

  echo ""
  echo "---"
  echo "Draft GitHub review at $DRAFT"
  echo "gh pr review $PR_NUMBER --repo $REPO --comment --body-file $DRAFT"
fi
