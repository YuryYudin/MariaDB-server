#!/usr/bin/env bash
# Plain-bash test for lib/fetch-pr.sh, using MREVIEW_FAKE_GH=1 so no real
# `gh` calls are made.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }
assert_file_nonempty() { [ -s "$1" ] || { fail "empty/missing file: $1"; return 1; }; }
assert_status_zero() { [ "$1" -eq 0 ] || { fail "expected exit 0, got $1"; return 1; }; }
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) fail "expected output to contain '$2', got: $1"; return 1 ;;
  esac
}

SCRIPT="$LIB_DIR/fetch-pr.sh"

# Helper: write a complete, valid fixture set into $1.
write_fixture() {
  local dir="$1"
  cat >"$dir/view.json" <<'JSON'
{"number":4869,"title":"x","body":"","baseRefName":"main","headRefOid":"abc","author":{"login":"u"},"assignees":[],"reviewRequests":[],"reviews":[],"comments":[],"labels":[],"state":"OPEN","url":"https://github.com/MariaDB/server/pull/4869"}
JSON
  printf '[]\n' >"$dir/comments.json"
  cat >"$dir/diff.patch" <<'PATCH'
diff --git a/sql/foo.cc b/sql/foo.cc
--- a/sql/foo.cc
+++ b/sql/foo.cc
@@ -1 +1 @@
-old
+new
PATCH
}

# ----- tests -----

case_start "1: fetch succeeds with fixture -> meta + comments + diff + touched-paths"
WD=$(mktemp -d)
FX=$(mktemp -d)
write_fixture "$FX"
rc=0
err=$(MREVIEW_WORK_DIR="$WD" MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" MariaDB/server 4869 2>&1 >/dev/null) || rc=$?
assert_status_zero "$rc"
assert_file_nonempty "$WD/pr-meta.json"
assert_file_nonempty "$WD/pr-existing-comments.json"
assert_file_nonempty "$WD/diff.patch"
assert_file_nonempty "$WD/touched-paths.txt"
if [ -s "$WD/pr-meta.json" ] && jq -e . "$WD/pr-meta.json" >/dev/null 2>&1; then
  num=$(jq -r .number "$WD/pr-meta.json")
  assert_eq "$num" "4869"
else
  fail "pr-meta.json is not valid JSON"
fi
touched=$(cat "$WD/touched-paths.txt")
assert_contains "$touched" "sql/foo.cc"
rm -rf "$WD" "$FX"
pass

case_start "2: empty diff in fixture -> exit 66, stderr 'fetched PR diff is empty'"
WD=$(mktemp -d)
FX=$(mktemp -d)
write_fixture "$FX"
: >"$FX/diff.patch"   # truncate to empty
rc=0
err=$(MREVIEW_WORK_DIR="$WD" MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" MariaDB/server 4869 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "66"
assert_contains "$err" "fetched PR diff is empty"
# Final artifacts must not exist (mv happens after the check).
[ ! -e "$WD/diff.patch" ] || fail "diff.patch should not exist after empty-diff failure"
[ ! -e "$WD/touched-paths.txt" ] || fail "touched-paths.txt should not exist after empty-diff failure"
rm -rf "$WD" "$FX"
pass

case_start "3: no args -> exit 64 (usage)"
WD=$(mktemp -d)
rc=0
err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "64"
assert_contains "$err" "usage:"
rm -rf "$WD"
pass

case_start "4: MREVIEW_WORK_DIR unset -> exit 64"
rc=0
err=$(env -u MREVIEW_WORK_DIR bash "$SCRIPT" foo/bar 1 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "64"
assert_contains "$err" "MREVIEW_WORK_DIR"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
