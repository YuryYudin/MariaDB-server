#!/usr/bin/env bash
# Plain-bash test for lib/tier-agents.sh. Each case constructs the
# inputs it needs via mktemp/printf and invokes the script.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/tier-agents.sh"

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

# Create an empty diff and paths file pair; echo "diff paths"
empty_pair() {
  local d p
  d=$(mktemp)
  p=$(mktemp)
  printf '%s %s' "$d" "$p"
}

# ----- tests -----

case_start "1: tier=quick with empty inputs -> just code-reviewer"
read -r D P <<<"$(empty_pair)"
out=$(bash "$SCRIPT" quick "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "code-reviewer"
assert_line_count "$out" 1
rm -f "$D" "$P"
pass

case_start "2: tier=standard with empty inputs -> code-reviewer + silent-failure-hunter"
read -r D P <<<"$(empty_pair)"
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "code-reviewer"
assert_contains_line "$out" "silent-failure-hunter"
assert_line_count "$out" 2
rm -f "$D" "$P"
pass

case_start "3: tier=deep with empty inputs -> all 5 agents"
read -r D P <<<"$(empty_pair)"
out=$(bash "$SCRIPT" deep "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "code-reviewer"
assert_contains_line "$out" "silent-failure-hunter"
assert_contains_line "$out" "pr-test-analyzer"
assert_contains_line "$out" "comment-analyzer"
assert_contains_line "$out" "type-design-analyzer"
assert_line_count "$out" 5
rm -f "$D" "$P"
pass

case_start "4: tier=quick with 10 mysql-test files -> includes pr-test-analyzer"
D=$(mktemp)
P=$(mktemp)
for i in 1 2 3 4 5 6 7 8 9 10; do
  printf 'mysql-test/main/t%d.test\n' "$i" >> "$P"
done
out=$(bash "$SCRIPT" quick "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "code-reviewer"
assert_contains_line "$out" "pr-test-analyzer"
assert_line_count "$out" 2
rm -f "$D" "$P"
pass

case_start "5: tier=standard with 9 test files -> NO pr-test-analyzer"
D=$(mktemp)
P=$(mktemp)
for i in 1 2 3 4 5 6 7 8 9; do
  printf 'mysql-test/main/t%d.test\n' "$i" >> "$P"
done
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_not_contains_line "$out" "pr-test-analyzer"
assert_line_count "$out" 2
rm -f "$D" "$P"
pass

case_start "6: tier=standard with 30 added comment lines -> includes comment-analyzer"
D=$(mktemp)
P=$(mktemp)
for i in $(seq 1 30); do
  printf '+// comment %d\n' "$i" >> "$D"
done
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "comment-analyzer"
rm -f "$D" "$P"
pass

case_start "7: tier=standard with 29 added comment lines -> NO comment-analyzer"
D=$(mktemp)
P=$(mktemp)
for i in $(seq 1 29); do
  printf '+// comment %d\n' "$i" >> "$D"
done
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_not_contains_line "$out" "comment-analyzer"
assert_line_count "$out" 2
rm -f "$D" "$P"
pass

case_start "8: tier=standard with '+class Foo {};' -> includes type-design-analyzer"
D=$(mktemp)
P=$(mktemp)
printf '+class Foo {};\n' > "$D"
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "type-design-analyzer"
rm -f "$D" "$P"
pass

case_start "9: tier=standard with '+ struct bar_t {}' (lowercase) -> NO type-design-analyzer"
D=$(mktemp)
P=$(mktemp)
printf '+ struct bar_t {}\n' > "$D"
out=$(bash "$SCRIPT" standard "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_not_contains_line "$out" "type-design-analyzer"
assert_line_count "$out" 2
rm -f "$D" "$P"
pass

case_start "10: unknown tier 'garbage' -> exit 64"
D=$(mktemp)
P=$(mktemp)
rc=0
bash "$SCRIPT" garbage "$D" "$P" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
rm -f "$D" "$P"
pass

case_start "11: missing arg -> exit 64"
rc=0
bash "$SCRIPT" quick >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

case_start "12: tier=deep with all triggers -> exactly 5 agents, no duplicates"
D=$(mktemp)
P=$(mktemp)
for i in $(seq 1 12); do
  printf 'mysql-test/main/t%d.test\n' "$i" >> "$P"
done
for i in $(seq 1 35); do
  printf '+// comment %d\n' "$i" >> "$D"
done
printf '+class Foo {};\n' >> "$D"
printf '+struct Bar {};\n' >> "$D"
out=$(bash "$SCRIPT" deep "$D" "$P")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "code-reviewer"
assert_contains_line "$out" "silent-failure-hunter"
assert_contains_line "$out" "pr-test-analyzer"
assert_contains_line "$out" "comment-analyzer"
assert_contains_line "$out" "type-design-analyzer"
assert_line_count "$out" 5
rm -f "$D" "$P"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
