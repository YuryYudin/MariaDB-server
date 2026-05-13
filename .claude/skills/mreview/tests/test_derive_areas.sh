#!/usr/bin/env bash
# Plain-bash test for lib/derive-areas.sh. Each case writes a tmp
# touched-paths.txt, runs the script, and asserts on stdout.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/derive-areas.sh"

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

write_input() {
  # $1: tmp file path; remaining args: lines to write.
  local f=$1; shift
  : > "$f"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$f"
  done
}

# ----- tests -----

case_start "1: sql/*  + storage/innobase/* -> both labels, neither duplicated"
TMP=$(mktemp)
write_input "$TMP" "sql/sql_parse.cc" "sql/sql_select.cc" \
  "storage/innobase/btr/btr0sea.cc" "storage/innobase/handler/ha_innodb.cc"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "sql/"
assert_contains_line "$out" "storage/innobase/"
assert_count "$out" "sql/" 1
assert_count "$out" "storage/innobase/" 1
rm -f "$TMP"
pass

case_start "2: mysql-test/* -> mysql-test/"
TMP=$(mktemp)
write_input "$TMP" "mysql-test/main/alias.test"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "mysql-test/"
rm -f "$TMP"
pass

case_start "3: CMakeLists.txt + cmake/*.cmake -> cmake (once)"
TMP=$(mktemp)
write_input "$TMP" "CMakeLists.txt" "cmake/maintainer.cmake"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "cmake"
assert_count "$out" "cmake" 1
rm -f "$TMP"
pass

case_start "4: sql/share/errmsg-utf8.txt -> errmsg only (not sql/)"
TMP=$(mktemp)
write_input "$TMP" "sql/share/errmsg-utf8.txt"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "errmsg"
assert_not_contains_line "$out" "sql/"
rm -f "$TMP"
pass

case_start "5: README.md -> empty output"
TMP=$(mktemp)
write_input "$TMP" "README.md"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_eq "$out" ""
rm -f "$TMP"
pass

case_start "6: storage/innobase/x.cc + storage/myisam/y.cc -> both innobase and storage"
TMP=$(mktemp)
write_input "$TMP" "storage/innobase/x.cc" "storage/myisam/y.cc"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "storage/innobase/"
assert_contains_line "$out" "storage/"
rm -f "$TMP"
pass

case_start "7: plugin/auth_pam/pam.c -> plugin/"
TMP=$(mktemp)
write_input "$TMP" "plugin/auth_pam/pam.c"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_contains_line "$out" "plugin/"
rm -f "$TMP"
pass

case_start "8: empty input file -> exit 0, empty output"
TMP=$(mktemp)
: > "$TMP"
out=$(bash "$SCRIPT" "$TMP")
rc=$?
assert_eq "$rc" "0"
assert_eq "$out" ""
rm -f "$TMP"
pass

case_start "9: missing arg -> exit 64"
out=$(bash "$SCRIPT" 2>/dev/null || true)
rc=0
bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
