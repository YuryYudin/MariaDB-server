#!/usr/bin/env bash
# Plain-bash test for lib/select-profiles.sh. Each case creates a fresh
# $WORK_DIR via mktemp -d, writes fixtures under $WORK_DIR/profiles/,
# and a pr-meta.json when needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/select-profiles.sh"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }

assert_contains_line() {
  local out=$1 needle=$2
  while IFS= read -r line; do
    if [ "$line" = "$needle" ]; then
      return 0
    fi
  done <<< "$out"
  fail "expected output to contain line '$needle', got: $out"
  return 1
}

assert_not_contains_line() {
  local out=$1 needle=$2
  while IFS= read -r line; do
    if [ "$line" = "$needle" ]; then
      fail "expected output NOT to contain line '$needle', got: $out"
      return 1
    fi
  done <<< "$out"
  return 0
}

assert_line_count() {
  local out=$1 want=$2 c=0
  while IFS= read -r line; do
    [ -n "$line" ] && c=$((c+1))
  done <<< "$out"
  if [ "$c" -ne "$want" ]; then
    fail "expected $want line(s), got $c. output: $out"
    return 1
  fi
  return 0
}

new_workdir() {
  local d
  d=$(mktemp -d)
  mkdir -p "$d/profiles"
  printf '%s' "$d"
}

# ----- tests -----

case_start "1: --profile vuvova with profiles/vuvova.md present -> emit vuvova.md"
WD=$(new_workdir)
: > "$WD/profiles/vuvova.md"
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --profile vuvova)
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "vuvova.md"
assert_line_count "$out" 1
rm -rf "$WD"
pass

case_start "2: --profile vuvova without profile file -> exit 69, stderr 'no profile'"
WD=$(new_workdir)
err_tmp=$(mktemp)
rc=0
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --profile vuvova 2>"$err_tmp") || rc=$?
assert_eq "$rc" "69"
err=$(cat "$err_tmp")
case "$err" in
  *"no profile"*) ;;
  *) fail "expected stderr to contain 'no profile', got: $err" ;;
esac
rm -rf "$WD" "$err_tmp"
pass

case_start "3: --no-profile -> empty output, exit 0 (with pr-meta present)"
WD=$(new_workdir)
: > "$WD/profiles/vuvova.md"
cat > "$WD/pr-meta.json" <<'JSON'
{"assignees":[{"login":"vuvova"}]}
JSON
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --no-profile)
rc=$?
assert_eq "$rc" "0"
assert_line_count "$out" 0
rm -rf "$WD"
pass

case_start "4: auto-detect from pr-meta.json assignees -> emit vuvova.md"
WD=$(new_workdir)
: > "$WD/profiles/vuvova.md"
cat > "$WD/pr-meta.json" <<'JSON'
{"assignees":[{"login":"vuvova"}]}
JSON
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "vuvova.md"
assert_line_count "$out" 1
rm -rf "$WD"
pass

case_start "5: cap at 2 -- 3 logins all with profiles -> emit exactly 2"
WD=$(new_workdir)
: > "$WD/profiles/alice.md"
: > "$WD/profiles/bob.md"
: > "$WD/profiles/carol.md"
cat > "$WD/pr-meta.json" <<'JSON'
{
  "assignees":[{"login":"alice"}],
  "reviewRequests":[{"login":"bob"}],
  "comments":[{"author":{"login":"carol"}}]
}
JSON
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_line_count "$out" 2
rm -rf "$WD"
pass

case_start "6: no pr-meta.json, no flag -> empty output, exit 0"
WD=$(new_workdir)
out=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_line_count "$out" 0
rm -rf "$WD"
pass

case_start "7: unknown flag --xyz -> exit 64"
WD=$(new_workdir)
rc=0
MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --xyz >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
rm -rf "$WD"
pass

case_start "8: --profile foo AND --no-profile -> exit 64 (mutually exclusive)"
WD=$(new_workdir)
: > "$WD/profiles/foo.md"
rc=0
MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --profile foo --no-profile >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
rm -rf "$WD"
pass

case_start "9: MREVIEW_WORK_DIR unset -> exit 64"
rc=0
(unset MREVIEW_WORK_DIR; bash "$SCRIPT") >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
