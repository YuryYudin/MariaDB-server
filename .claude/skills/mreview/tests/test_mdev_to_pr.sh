#!/usr/bin/env bash
# Plain-bash test for lib/mdev-to-pr.sh, using MREVIEW_FAKE_GH=1 so no real
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
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) fail "expected output to contain '$2', got: $1"; return 1 ;;
  esac
}

SCRIPT="$LIB_DIR/mdev-to-pr.sh"

# ----- tests -----

case_start "1: single match -> stdout '<repo> <N>', exit 0"
FX=$(mktemp -d)
cat >"$FX/search.json" <<'JSON'
[{"number":4869,"repository":{"nameWithOwner":"MariaDB/server"}}]
JSON
rc=0
out=$(MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" MDEV-23676 2>/dev/null) || rc=$?
assert_eq "$rc" "0"
assert_eq "$out" "MariaDB/server 4869"
rm -rf "$FX"
pass

case_start "2: zero matches -> exit 67, stderr 'no PR found' + mfix hint"
FX=$(mktemp -d)
printf '[]\n' >"$FX/search.json"
rc=0
err=$(MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" MDEV-99999 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "67"
assert_contains "$err" "no PR found for MDEV-99999"
assert_contains "$err" "mfix"
rm -rf "$FX"
pass

case_start "3: multiple matches -> exit 68, stderr lists both"
FX=$(mktemp -d)
cat >"$FX/search.json" <<'JSON'
[
  {"number":4869,"repository":{"nameWithOwner":"MariaDB/server"}},
  {"number":5001,"repository":{"nameWithOwner":"MariaDB/server"}}
]
JSON
rc=0
err=$(MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" MDEV-23676 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "68"
assert_contains "$err" "multiple PRs match MDEV-23676"
assert_contains "$err" "MariaDB/server#4869"
assert_contains "$err" "MariaDB/server#5001"
rm -rf "$FX"
pass

case_start "4: usage error (no arg) -> exit 64"
rc=0
err=$(bash "$SCRIPT" 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "64"
assert_contains "$err" "usage:"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
