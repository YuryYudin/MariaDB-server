#!/usr/bin/env bash
# Plain-bash test for lib/present.sh. Each case builds its own
# $WORK_DIR via mktemp, writes target.json + report.md as needed,
# runs present.sh, and asserts against stdout / files / exit codes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/present.sh"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() {
  if [ "$1" != "$2" ]; then
    fail "expected '$2' got '$1'"
    return 1
  fi
}

assert_contains() {
  local haystack=$1 needle=$2
  if ! printf '%s' "$haystack" | grep -q -- "$needle"; then
    fail "expected output to contain '$needle'. Content:"
    printf '%s\n' "$haystack" | sed 's/^/    /' >&2
    return 1
  fi
}

assert_not_contains() {
  local haystack=$1 needle=$2
  if printf '%s' "$haystack" | grep -q -- "$needle"; then
    fail "expected output NOT to contain '$needle'. Content:"
    printf '%s\n' "$haystack" | sed 's/^/    /' >&2
    return 1
  fi
}

assert_file_grep() {
  local file=$1 pattern=$2
  if ! grep -q -- "$pattern" "$file"; then
    fail "expected $file to match '$pattern'. Content:"
    sed 's/^/    /' "$file" >&2
    return 1
  fi
}

assert_file_not_grep() {
  local file=$1 pattern=$2
  if grep -q -- "$pattern" "$file"; then
    fail "expected $file NOT to match '$pattern'. Content:"
    sed 's/^/    /' "$file" >&2
    return 1
  fi
}

# Write a synthesized report.md to $1 with appendix at the end.
write_sample_report() {
  local f=$1
  cat > "$f" <<'EOF'
# mreview report

**Verdict: approve-with-changes**

## Summary

- Tier: standard
- Blockers: 0
- Important: 1
- Nits: 0
- Praise: 0

## Blocker

_(none)_

## Important

- **Important** [sql/foo.cc:10] Missing null check. — by code-reviewer

## Nit

_(none)_

## Praise

_(none)_

## Per-agent appendix

### code-reviewer

verbatim agent output here
EOF
}

fresh_workdir() {
  WD=$(mktemp -d)
  export MREVIEW_WORK_DIR="$WD"
}

cleanup_workdir() {
  local d=$1
  rm -rf "$d"
  unset MREVIEW_WORK_DIR
}

# ----- tests -----

case_start "1: staged target -> stdout has Verdict, no appendix, no github-draft.md"
fresh_workdir
cat > "$WD/target.json" <<'EOF'
{"type": "staged"}
EOF
write_sample_report "$WD/report.md"
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_contains "$out" '\*\*Verdict:'
  assert_not_contains "$out" 'Per-agent appendix'
  assert_not_contains "$out" 'gh pr review'
  assert_not_contains "$out" 'Draft GitHub review'
  if [ -e "$WD/github-draft.md" ]; then
    fail "expected $WD/github-draft.md NOT to exist"
  fi
fi
cleanup_workdir "$WD"
pass

case_start "2: github_pr target -> stdout has gh command, github-draft.md exists and excludes appendix"
fresh_workdir
cat > "$WD/target.json" <<'EOF'
{"type": "github_pr", "pr_number": "4869", "repo": "MariaDB/server"}
EOF
write_sample_report "$WD/report.md"
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_contains "$out" 'Draft GitHub review at'
  assert_contains "$out" 'gh pr review 4869 --repo MariaDB/server'
  assert_contains "$out" '--comment'
  assert_contains "$out" '--body-file'
  if [ ! -s "$WD/github-draft.md" ]; then
    fail "expected $WD/github-draft.md to exist and be non-empty"
  else
    assert_file_grep "$WD/github-draft.md" '\*\*Verdict:'
    assert_file_not_grep "$WD/github-draft.md" 'Per-agent appendix'
    assert_file_not_grep "$WD/github-draft.md" 'verbatim agent output here'
  fi
fi
cleanup_workdir "$WD"
pass

case_start "3: report.md missing -> exit 70"
fresh_workdir
cat > "$WD/target.json" <<'EOF'
{"type": "staged"}
EOF
rc=0
err=$(bash "$SCRIPT" 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "70"
assert_contains "$err" 'no report at'
cleanup_workdir "$WD"
pass

case_start "4: report.md empty -> exit 70"
fresh_workdir
cat > "$WD/target.json" <<'EOF'
{"type": "staged"}
EOF
: > "$WD/report.md"
rc=0
err=$(bash "$SCRIPT" 2>&1 >/dev/null) || rc=$?
assert_eq "$rc" "70"
assert_contains "$err" 'no report at'
cleanup_workdir "$WD"
pass

case_start "5: MREVIEW_WORK_DIR unset -> exit 64"
unset MREVIEW_WORK_DIR || true
rc=0
bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

case_start "6: target.json missing -> treat as non-PR (no github-draft.md, no gh command)"
fresh_workdir
write_sample_report "$WD/report.md"
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_contains "$out" '\*\*Verdict:'
  assert_not_contains "$out" 'Per-agent appendix'
  assert_not_contains "$out" 'gh pr review'
  assert_not_contains "$out" 'Draft GitHub review'
  if [ -e "$WD/github-draft.md" ]; then
    fail "expected $WD/github-draft.md NOT to exist"
  fi
fi
cleanup_workdir "$WD"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
