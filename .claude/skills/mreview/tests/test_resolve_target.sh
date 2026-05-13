#!/usr/bin/env bash
# Plain-bash test for lib/resolve-target.sh (dry-run classifier).
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
assert_status_zero() { [ "$1" -eq 0 ] || { fail "expected exit 0, got $1"; return 1; }; }
assert_contains() {
  case "$1" in
    *"$2"*) return 0 ;;
    *) fail "expected output to contain '$2', got: $1"; return 1 ;;
  esac
}
assert_not_contains() {
  case "$1" in
    *"$2"*) fail "expected output NOT to contain '$2', got: $1"; return 1 ;;
    *) return 0 ;;
  esac
}
assert_matches() {
  # $1 = string, $2 = ERE pattern
  if [[ "$1" =~ $2 ]]; then
    return 0
  fi
  fail "expected '$1' to match /$2/"
  return 1
}

cd "$REPO_ROOT"

SCRIPT="$LIB_DIR/resolve-target.sh"

# ----- tests -----

case_start "1: bare PR number -> github_pr on MariaDB/server"
out=$(bash "$SCRIPT" --dry-run 4869)
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=github_pr"
assert_contains "$out" "repo=MariaDB/server"
assert_contains "$out" "pr_number=4869"
pass

case_start "2: GitHub PR URL -> github_pr with parsed repo/N"
out=$(bash "$SCRIPT" --dry-run "https://github.com/MariaDB/server/pull/4869")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=github_pr"
assert_contains "$out" "repo=MariaDB/server"
assert_contains "$out" "pr_number=4869"
pass

case_start "3: owner/repo#N -> github_pr with explicit repo"
out=$(bash "$SCRIPT" --dry-run "foo/bar#123")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=github_pr"
assert_contains "$out" "repo=foo/bar"
assert_contains "$out" "pr_number=123"
pass

case_start "4: MDEV-NNNNN -> mdev_lookup"
out=$(bash "$SCRIPT" --dry-run "MDEV-23676")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=mdev_lookup"
assert_contains "$out" "mdev=MDEV-23676"
pass

case_start "5: real local SHA -> type=commit with 40-char sha"
HEAD_SHA=$(git rev-parse HEAD)
out=$(bash "$SCRIPT" --dry-run "$HEAD_SHA")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=commit"
# Extract the sha= line and verify it's 40 hex chars
sha_line=$(printf '%s\n' "$out" | grep '^sha=' || true)
sha_val="${sha_line#sha=}"
assert_matches "$sha_val" '^[0-9a-fA-F]{40}$'
assert_eq "$sha_val" "$HEAD_SHA"
pass

case_start "6: HEAD~3..HEAD -> type=range with base/head"
out=$(bash "$SCRIPT" --dry-run "HEAD~3..HEAD")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=range"
assert_contains "$out" "base=HEAD~3"
assert_contains "$out" "head=HEAD"
pass

case_start "7: --staged -> type=staged"
out=$(bash "$SCRIPT" --dry-run --staged)
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=staged"
pass

case_start "8: --working -> type=working"
out=$(bash "$SCRIPT" --dry-run --working)
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=working"
pass

case_start "9: existing local branch 'main' -> type=branch"
out=$(bash "$SCRIPT" --dry-run main)
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=branch"
assert_contains "$out" "branch=main"
pass

case_start "10: no arg -> type=auto"
out=$(bash "$SCRIPT" --dry-run)
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=auto"
pass

case_start "11: garbage input -> exit 65, stderr contains 'could not resolve'"
rc=0
out=$(bash "$SCRIPT" --dry-run "definitely-not-a-real-thing-@@@" 2>&1) || rc=$?
assert_eq "$rc" "65"
assert_contains "$out" "could not resolve"
pass

case_start "12: 'main..' -> type=range with base=main, head=HEAD"
out=$(bash "$SCRIPT" --dry-run "main..")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=range"
assert_contains "$out" "base=main"
assert_contains "$out" "head=HEAD"
pass

case_start "13: 'A...B' (3-dot) -> exit 65, 'could not resolve'"
rc=0
out=$(bash "$SCRIPT" --dry-run "A...B" 2>&1) || rc=$?
assert_eq "$rc" "65"
assert_contains "$out" "could not resolve"
pass

case_start "14: '..HEAD' (empty base) -> exit 65"
rc=0
out=$(bash "$SCRIPT" --dry-run "..HEAD" 2>&1) || rc=$?
assert_eq "$rc" "65"
assert_contains "$out" "could not resolve"
pass

case_start "15: '..' alone -> exit 65"
rc=0
out=$(bash "$SCRIPT" --dry-run ".." 2>&1) || rc=$?
assert_eq "$rc" "65"
assert_contains "$out" "could not resolve"
pass

case_start "16: pr_number=0 -> exit 65"
rc=0
out=$(bash "$SCRIPT" --dry-run 0 2>&1) || rc=$?
assert_eq "$rc" "65"
assert_contains "$out" "could not resolve"
pass

case_start "17: URL with .git suffix -> repo without .git"
out=$(bash "$SCRIPT" --dry-run "https://github.com/MariaDB/server.git/pull/4869")
status=$?
assert_status_zero "$status"
assert_contains "$out" "type=github_pr"
assert_contains "$out" "repo=MariaDB/server"
assert_not_contains "$out" "repo=MariaDB/server.git"
assert_contains "$out" "pr_number=4869"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
