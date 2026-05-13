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

# ----- non-dry-run materialization tests (Task 3) -----

# Each test gets a fresh MREVIEW_WORK_DIR for isolation.

case_start "A: HEAD sha (no --dry-run) -> target.json + diff.patch + touched-paths.txt"
WD=$(mktemp -d)
HEAD_SHA=$(git rev-parse HEAD)
rc=0
err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" "$HEAD_SHA" 2>&1 >/dev/null) || rc=$?
assert_status_zero "$rc"
[ -s "$WD/target.json" ] || fail "target.json missing or empty"
[ -s "$WD/diff.patch" ] || fail "diff.patch missing or empty"
[ -s "$WD/touched-paths.txt" ] || fail "touched-paths.txt missing or empty"
# Validate JSON and .type
if jq -e . "$WD/target.json" >/dev/null 2>&1; then
  t=$(jq -r .type "$WD/target.json")
  assert_eq "$t" "commit"
else
  fail "target.json is not valid JSON"
fi
rm -rf "$WD"
pass

case_start "B: HEAD~1..HEAD (no --dry-run) -> type=range, diff non-empty"
WD=$(mktemp -d)
rc=0
err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" "HEAD~1..HEAD" 2>&1 >/dev/null) || rc=$?
assert_status_zero "$rc"
[ -s "$WD/diff.patch" ] || fail "diff.patch missing or empty"
if jq -e . "$WD/target.json" >/dev/null 2>&1; then
  t=$(jq -r .type "$WD/target.json")
  assert_eq "$t" "range"
  b=$(jq -r .base "$WD/target.json")
  h=$(jq -r .head "$WD/target.json")
  assert_eq "$b" "HEAD~1"
  assert_eq "$h" "HEAD"
else
  fail "target.json is not valid JSON"
fi
rm -rf "$WD"
pass

case_start "C: --staged with nothing staged -> exit 66, 'diff is empty'"
# Run against a throwaway repo so we never touch the user's working tree.
TMP_REPO=$(mktemp -d)
WD=$(mktemp -d)
sub_status=0
out_and_err=$(
  cd "$TMP_REPO"
  git init --quiet
  git config user.email t@t
  git config user.name t
  echo init > a
  git add a
  git -c commit.gpgsign=false commit --quiet -m init
  # Nothing is staged now.
  rc=0
  err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --staged 2>&1 >/dev/null) || rc=$?
  printf 'rc=%s\n' "$rc"
  printf 'err=%s\n' "$err"
) || sub_status=$?
[ "$sub_status" -eq 0 ] || fail "subshell exited non-zero: $sub_status"
rc=$(printf '%s\n' "$out_and_err" | sed -n 's/^rc=//p')
err=$(printf '%s\n' "$out_and_err" | sed -n 's/^err=//p')
assert_eq "$rc" "66"
assert_contains "$err" "diff is empty"
# target.json must still be written before the empty-diff check.
[ -s "$WD/target.json" ] || fail "target.json should be written even on empty-diff exit"
rm -rf "$WD" "$TMP_REPO"
pass

case_start "D: --working (tolerant) -> rc==0 with diff.patch OR rc==66 'diff is empty'"
WD=$(mktemp -d)
rc=0
err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" --working 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  [ -e "$WD/diff.patch" ] || fail "rc=0 but diff.patch missing"
elif [ "$rc" -eq 66 ]; then
  assert_contains "$err" "diff is empty"
else
  fail "unexpected rc=$rc, stderr: $err"
fi
rm -rf "$WD"
pass

case_start "E: HEAD sha -> touched-paths.txt matches 'git show --name-only --format= HEAD'"
WD=$(mktemp -d)
HEAD_SHA=$(git rev-parse HEAD)
MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" "$HEAD_SHA" >/dev/null 2>&1
# Reference list using the same --first-parent setting the script uses.
expected=$(git show --first-parent --name-only --format= "$HEAD_SHA" | sed '/^$/d' | sort -u)
actual=$(sed '/^$/d' "$WD/touched-paths.txt" | sort -u)
assert_eq "$actual" "$expected"
# At least one path
nlines=$(printf '%s\n' "$actual" | sed '/^$/d' | wc -l)
[ "$nlines" -ge 1 ] || fail "expected >=1 touched path, got $nlines"
rm -rf "$WD"
pass

case_start "F: MREVIEW_WORK_DIR unset -> exit 64"
rc=0
# unset MREVIEW_WORK_DIR for this invocation only via 'env -u'.
err=$(env -u MREVIEW_WORK_DIR bash "$SCRIPT" "$(git rev-parse HEAD)" 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "64"
assert_contains "$err" "MREVIEW_WORK_DIR"
pass

case_start "G: root commit with no file changes -> exit 66"
TMP_REPO=$(mktemp -d)
WD=$(mktemp -d)
sub_status=0
out_and_err=$(
  cd "$TMP_REPO"
  git init --quiet
  git config user.email t@t
  git config user.name t
  git -c commit.gpgsign=false commit --allow-empty --quiet -m empty
  empty_sha=$(git rev-parse HEAD)
  rc=0
  err=$(MREVIEW_WORK_DIR="$WD" bash "$SCRIPT" "$empty_sha" 2>&1 >/dev/null) || rc=$?
  printf 'rc=%s\n' "$rc"
  printf 'err=%s\n' "$err"
) || sub_status=$?
[ "$sub_status" -eq 0 ] || fail "subshell exited non-zero: $sub_status"
rc=$(printf '%s\n' "$out_and_err" | sed -n 's/^rc=//p')
assert_eq "$rc" "66"
rm -rf "$WD" "$TMP_REPO"
pass

case_start "H: github_pr via fixture -> target.json, diff.patch, touched-paths.txt all populated"
WD=$(mktemp -d)
FX=$(mktemp -d)
cat >"$FX/view.json" <<'JSON'
{"number":4869,"title":"x","body":"","baseRefName":"main","headRefOid":"abc","author":{"login":"u"},"assignees":[],"reviewRequests":[],"reviews":[],"comments":[],"labels":[],"state":"OPEN","url":"https://github.com/MariaDB/server/pull/4869"}
JSON
printf '[]\n' >"$FX/comments.json"
cat >"$FX/diff.patch" <<'PATCH'
diff --git a/sql/foo.cc b/sql/foo.cc
--- a/sql/foo.cc
+++ b/sql/foo.cc
@@ -1 +1 @@
-old
+new
PATCH
rc=0
err=$(MREVIEW_WORK_DIR="$WD" MREVIEW_FAKE_GH=1 MREVIEW_FAKE_GH_DIR="$FX" \
        bash "$SCRIPT" 4869 2>&1 >/dev/null) || rc=$?
assert_status_zero "$rc"
[ -s "$WD/target.json" ] || fail "target.json missing or empty"
[ -s "$WD/diff.patch" ] || fail "diff.patch missing or empty"
[ -s "$WD/touched-paths.txt" ] || fail "touched-paths.txt missing or empty"
if jq -e . "$WD/target.json" >/dev/null 2>&1; then
  t=$(jq -r .type "$WD/target.json")
  assert_eq "$t" "github_pr"
else
  fail "target.json is not valid JSON"
fi
rm -rf "$WD" "$FX"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
