#!/usr/bin/env bash
# Plain-bash test for lib/setup-workdir.sh.
# Pattern: print PASS/FAIL per case, count totals, exit non-zero on any fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

fails=0
total=0

case_start() { echo "--- $1"; total=$((total+1)); }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); }
pass() { echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }
assert_dir() { [ -d "$1" ] || { fail "missing dir: $1"; return 1; }; }
assert_no_dir() { [ ! -d "$1" ] || { fail "unexpected dir exists: $1"; return 1; }; }
assert_file_nonempty() { [ -s "$1" ] || { fail "empty/missing file: $1"; return 1; }; }
assert_status_nonzero() { [ "$1" -ne 0 ] || { fail "expected non-zero exit, got 0"; return 1; }; }
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) fail "expected output to contain '$2', got: $1"; return 1 ;;
  esac
}

cd "$REPO_ROOT"

# ----- tests -----

case_start "setup-workdir creates dir under HOME/.cache/mreview when no override"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-123 >/dev/null
)
status=$?
if [ "$status" -eq 0 ] \
   && assert_dir "$TMPHOME/.cache/mreview/test-id-123" \
   && assert_dir "$TMPHOME/.cache/mreview/test-id-123/rulebook" \
   && assert_dir "$TMPHOME/.cache/mreview/test-id-123/profiles" \
   && assert_dir "$TMPHOME/.cache/mreview/test-id-123/agents"; then
  pass
else
  [ "$status" -eq 0 ] || fail "helper exited $status"
fi
rm -rf "$TMPHOME"

case_start "setup-workdir respects MREVIEW_WORK_DIR override and does NOT create default path"
TMPHOME=$(mktemp -d)
CUSTOM="$TMPHOME/custom-dir"
(
  HOME="$TMPHOME" MREVIEW_WORK_DIR="$CUSTOM" \
    bash "$LIB_DIR/setup-workdir.sh" test-id-999 >/dev/null
)
status=$?
if [ "$status" -eq 0 ] \
   && assert_dir "$CUSTOM" \
   && assert_dir "$CUSTOM/rulebook" \
   && assert_dir "$CUSTOM/profiles" \
   && assert_dir "$CUSTOM/agents" \
   && assert_no_dir "$TMPHOME/.cache/mreview/test-id-999"; then
  pass
else
  [ "$status" -eq 0 ] || fail "helper exited $status"
fi
rm -rf "$TMPHOME"

case_start "setup-workdir caches .claude/review/*.md from main into rulebook/"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-456 >/dev/null
)
status=$?
RULEBOOK="$TMPHOME/.cache/mreview/test-id-456/rulebook"
if [ "$status" -eq 0 ] \
   && assert_file_nonempty "$RULEBOOK/checklist.md" \
   && assert_file_nonempty "$RULEBOOK/coding-style.md"; then
  pass
else
  [ "$status" -eq 0 ] || fail "helper exited $status"
fi
rm -rf "$TMPHOME"

case_start "setup-workdir caches .claude/reviewers/*.md from main into profiles/"
TMPHOME=$(mktemp -d)
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" test-id-789 >/dev/null
)
status=$?
PROFILES="$TMPHOME/.cache/mreview/test-id-789/profiles"
if [ "$status" -eq 0 ] \
   && assert_file_nonempty "$PROFILES/vuvova.md"; then
  pass
else
  [ "$status" -eq 0 ] || fail "helper exited $status"
fi
rm -rf "$TMPHOME"

case_start "setup-workdir fails fast when target id is missing (usage to stderr)"
TMPHOME=$(mktemp -d)
out_file=$(mktemp)
err_file=$(mktemp)
set +e
(
  unset MREVIEW_WORK_DIR
  HOME="$TMPHOME" bash "$LIB_DIR/setup-workdir.sh" >"$out_file" 2>"$err_file"
)
status=$?
set -e
stderr_content=$(cat "$err_file")
if assert_status_nonzero "$status" \
   && assert_contains "$stderr_content" "usage:" \
   && assert_no_dir "$TMPHOME/.cache/mreview"; then
  pass
fi
rm -rf "$TMPHOME" "$out_file" "$err_file"

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
