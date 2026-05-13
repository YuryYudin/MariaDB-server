#!/usr/bin/env bash
# Plain-bash test for lib/auto-detect.sh. Each case runs in a throwaway
# `git init` repo so the host repo's state is irrelevant.
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

SCRIPT="$LIB_DIR/auto-detect.sh"

# init_repo: create a throwaway repo with one initial commit, echo its path.
init_repo() {
  local d
  d=$(mktemp -d)
  (
    cd "$d"
    git init --quiet
    git config user.email t@t
    git config user.name t
    echo init > a
    git add a
    git -c commit.gpgsign=false commit --quiet -m init
  )
  echo "$d"
}

# ----- tests -----

case_start "1: clean tree, single commit -> type=last_commit, sha=<HEAD>"
REPO=$(init_repo)
out=$(cd "$REPO" && bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_contains "$out" "type=last_commit"
expected_sha=$(cd "$REPO" && git rev-parse HEAD)
assert_contains "$out" "sha=$expected_sha"
rm -rf "$REPO"
pass

case_start "2: dirty working tree, nothing staged -> type=working"
REPO=$(init_repo)
(
  cd "$REPO"
  echo modified >> a
)
out=$(cd "$REPO" && bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_contains "$out" "type=working"
case "$out" in
  *type=working_and_staged*) fail "expected 'type=working' (not 'working_and_staged')" ;;
esac
rm -rf "$REPO"
pass

case_start "3: staged, nothing dirty -> type=staged"
REPO=$(init_repo)
(
  cd "$REPO"
  echo newcontent > b
  git add b
)
out=$(cd "$REPO" && bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_contains "$out" "type=staged"
case "$out" in
  *type=working_and_staged*) fail "expected 'type=staged' (not 'working_and_staged')" ;;
esac
rm -rf "$REPO"
pass

case_start "4: both dirty AND staged -> type=working_and_staged"
REPO=$(init_repo)
(
  cd "$REPO"
  echo staged > b
  git add b
  echo unstaged >> a
)
out=$(cd "$REPO" && bash "$SCRIPT")
rc=$?
assert_eq "$rc" "0"
assert_contains "$out" "type=working_and_staged"
rm -rf "$REPO"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
