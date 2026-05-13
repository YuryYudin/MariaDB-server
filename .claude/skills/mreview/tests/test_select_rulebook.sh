#!/usr/bin/env bash
# Plain-bash test for lib/select-rulebook.sh. Each case writes a tmp
# touched-areas.txt, runs the script, and asserts on stdout.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/select-rulebook.sh"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }

# assert_contains_line: output ($1) must contain line exactly equal to $2.
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

# assert_not_contains_line: output ($1) must NOT contain line exactly equal to $2.
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

# assert_count: count of lines in output ($1) equal to needle ($2) must be $3.
assert_count() {
  local out=$1 needle=$2 want=$3 c=0
  while IFS= read -r line; do
    [ "$line" = "$needle" ] && c=$((c+1))
  done <<< "$out"
  if [ "$c" -ne "$want" ]; then
    fail "expected '$needle' to appear $want time(s), got $c. output: $out"
    return 1
  fi
  return 0
}

# assert_line_count: total non-empty lines in output ($1) must be $2.
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

write_input() {
  # $1: tmp file path; remaining args: lines to write.
  local f=$1; shift
  : > "$f"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$f"
  done
}

# ----- tests -----

case_start "1: empty areas file -> exactly the 4 baseline files"
TMP=$(mktemp)
: > "$TMP"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "checklist.md"
assert_contains_line "$out" "commit-and-process.md"
assert_contains_line "$out" "coding-style.md"
assert_contains_line "$out" "anti-patterns.md"
assert_line_count "$out" 4
rm -f "$TMP"
pass

case_start "2: areas storage/innobase/ -> baseline + innodb.md + api-and-architecture.md"
TMP=$(mktemp)
write_input "$TMP" "storage/innobase/"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "checklist.md"
assert_contains_line "$out" "commit-and-process.md"
assert_contains_line "$out" "coding-style.md"
assert_contains_line "$out" "anti-patterns.md"
assert_contains_line "$out" "innodb.md"
rm -f "$TMP"
pass

case_start "3: areas mysql-test/ -> baseline + testing.md"
TMP=$(mktemp)
write_input "$TMP" "mysql-test/"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "checklist.md"
assert_contains_line "$out" "commit-and-process.md"
assert_contains_line "$out" "coding-style.md"
assert_contains_line "$out" "anti-patterns.md"
assert_contains_line "$out" "testing.md"
assert_not_contains_line "$out" "api-and-architecture.md"
rm -f "$TMP"
pass

case_start "4: areas cmake -> baseline + build-and-cmake.md"
TMP=$(mktemp)
write_input "$TMP" "cmake"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "checklist.md"
assert_contains_line "$out" "commit-and-process.md"
assert_contains_line "$out" "coding-style.md"
assert_contains_line "$out" "anti-patterns.md"
assert_contains_line "$out" "build-and-cmake.md"
assert_not_contains_line "$out" "api-and-architecture.md"
rm -f "$TMP"
pass

case_start "5: areas errmsg -> baseline + logging-and-errors.md"
TMP=$(mktemp)
write_input "$TMP" "errmsg"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "checklist.md"
assert_contains_line "$out" "commit-and-process.md"
assert_contains_line "$out" "coding-style.md"
assert_contains_line "$out" "anti-patterns.md"
assert_contains_line "$out" "logging-and-errors.md"
assert_not_contains_line "$out" "api-and-architecture.md"
rm -f "$TMP"
pass

case_start "6: sql/ AND storage/innobase/ -> innodb.md + api-and-architecture.md, innodb.md once"
TMP=$(mktemp)
write_input "$TMP" "sql/" "storage/innobase/"
out=$(unset MREVIEW_DIFF; bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "innodb.md"
assert_contains_line "$out" "api-and-architecture.md"
assert_count "$out" "innodb.md" 1
assert_count "$out" "api-and-architecture.md" 1
rm -f "$TMP"
pass

case_start "7: MREVIEW_DIFF with memcpy diff -> correctness-and-security.md emitted"
TMP=$(mktemp)
: > "$TMP"
DIFF_TMP=$(mktemp)
printf '%s\n' "+  memcpy(buf, src, n);" > "$DIFF_TMP"
out=$(MREVIEW_DIFF="$DIFF_TMP" bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "correctness-and-security.md"
rm -f "$TMP" "$DIFF_TMP"
pass

case_start "8: MREVIEW_DIFF with no triggers -> no correctness-and-security.md"
TMP=$(mktemp)
: > "$TMP"
DIFF_TMP=$(mktemp)
printf '%s\n' "+  // a friendly comment" "+  int x= 1;" > "$DIFF_TMP"
out=$(MREVIEW_DIFF="$DIFF_TMP" bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_not_contains_line "$out" "correctness-and-security.md"
rm -f "$TMP" "$DIFF_TMP"
pass

case_start "9: MREVIEW_DIFF set to non-existent file -> no entry, no error"
TMP=$(mktemp)
: > "$TMP"
NONEXISTENT="/tmp/select-rulebook-nonexistent-$$.diff"
rm -f "$NONEXISTENT"
out=$(MREVIEW_DIFF="$NONEXISTENT" bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_not_contains_line "$out" "correctness-and-security.md"
rm -f "$TMP"
pass

case_start "10: missing arg -> exit 64"
rc=0
bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
