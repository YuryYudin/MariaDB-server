#!/usr/bin/env bash
# Plain-bash test for lib/setup-workdir.sh.
# Pattern: print PASS/FAIL per case, count totals, exit non-zero on any fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }
assert_dir() { [ -d "$1" ] || { fail "missing dir: $1"; return 1; }; }
assert_no_dir() { [ ! -d "$1" ] || { fail "unexpected dir exists: $1"; return 1; }; }
assert_file_nonempty() { [ -s "$1" ] || { fail "empty/missing file: $1"; return 1; }; }
assert_status_zero() { [ "$1" -eq 0 ] || { fail "expected exit 0, got $1"; return 1; }; }
assert_status_nonzero() { [ "$1" -ne 0 ] || { fail "expected non-zero exit, got 0"; return 1; }; }
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) fail "expected output to contain '$2', got: $1"; return 1 ;;
  esac
}

cd "$REPO_ROOT"

REVIEW_REF="${MFIX_REVIEW_REF:-main}"

# ----- tests -----

case_start "setup-workdir creates dir under HOME/.cache/mreview when no override"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-123 >/dev/null
)
status=$?
assert_status_zero "$status"
assert_dir "$TMPHOME/.cache/mreview/test-id-123"
assert_dir "$TMPHOME/.cache/mreview/test-id-123/rulebook"
assert_dir "$TMPHOME/.cache/mreview/test-id-123/profiles"
assert_dir "$TMPHOME/.cache/mreview/test-id-123/agents"
pass
rm -rf "$TMPHOME"

case_start "setup-workdir respects MREVIEW_WORK_DIR override and does NOT create default path"
TMPHOME=$(mktemp -d)
CUSTOM="$TMPHOME/custom-dir"
(
  HOME="$TMPHOME" MREVIEW_WORK_DIR="$CUSTOM" \
    bash "$LIB_DIR/setup-workdir.sh" test-id-999 >/dev/null
)
status=$?
assert_status_zero "$status"
assert_dir "$CUSTOM"
assert_dir "$CUSTOM/rulebook"
assert_dir "$CUSTOM/profiles"
assert_dir "$CUSTOM/agents"
assert_no_dir "$TMPHOME/.cache/mreview/test-id-999"
pass
rm -rf "$TMPHOME"

case_start "setup-workdir caches the full set of .claude/review/*.md from review-ref into rulebook/"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-456 >/dev/null
)
status=$?
assert_status_zero "$status"
RULEBOOK="$TMPHOME/.cache/mreview/test-id-456/rulebook"
if assert_dir "$RULEBOOK"; then
  expected=$(git ls-tree -r --name-only "$REVIEW_REF" -- .claude/review/ \
             | grep -E '\.md$' | xargs -n1 basename | sort)
  actual=$(ls "$RULEBOOK" | sort)
  assert_eq "$actual" "$expected"
  # every cached file must be non-empty
  for f in $actual; do
    assert_file_nonempty "$RULEBOOK/$f"
  done
fi
pass
rm -rf "$TMPHOME"

case_start "setup-workdir caches the full set of .claude/reviewers/*.md from review-ref into profiles/"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-789 >/dev/null
)
status=$?
assert_status_zero "$status"
PROFILES="$TMPHOME/.cache/mreview/test-id-789/profiles"
if assert_dir "$PROFILES"; then
  expected=$(git ls-tree -r --name-only "$REVIEW_REF" -- .claude/reviewers/ \
             | grep -E '\.md$' | xargs -n1 basename | sort)
  actual=$(ls "$PROFILES" | sort)
  assert_eq "$actual" "$expected"
  for f in $actual; do
    assert_file_nonempty "$PROFILES/$f"
  done
fi
pass
rm -rf "$TMPHOME"

case_start "setup-workdir fails fast when target id is missing (usage to stderr)"
TMPHOME=$(mktemp -d)
out_file=$(mktemp)
err_file=$(mktemp)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" >"$out_file" 2>"$err_file"
)
status=$?
stderr_content=$(cat "$err_file")
assert_status_nonzero "$status"
assert_contains "$stderr_content" "usage:"
assert_no_dir "$TMPHOME/.cache/mreview"
pass
rm -rf "$TMPHOME" "$out_file" "$err_file"

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
