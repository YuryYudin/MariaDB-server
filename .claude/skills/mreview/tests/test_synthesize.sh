#!/usr/bin/env bash
# Plain-bash test for lib/synthesize.sh. Each case builds its own
# $WORK_DIR via mktemp, populates agents/ (and optionally tier.txt),
# runs synthesize.sh, and asserts against report.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/synthesize.sh"

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

assert_grep() {
  local file=$1 pattern=$2
  if ! grep -q -- "$pattern" "$file"; then
    fail "expected $file to match '$pattern'. Content:"
    sed 's/^/    /' "$file" >&2
    return 1
  fi
}

assert_not_grep() {
  local file=$1 pattern=$2
  if grep -q -- "$pattern" "$file"; then
    fail "expected $file NOT to match '$pattern'. Content:"
    sed 's/^/    /' "$file" >&2
    return 1
  fi
}

# Set up a fresh work dir with an empty agents/ subdir, exported.
# Sets WD (caller-visible) and exports MREVIEW_WORK_DIR. Must NOT be
# invoked in a subshell ($(...)) — the export would be lost.
fresh_workdir() {
  WD=$(mktemp -d)
  mkdir -p "$WD/agents"
  export MREVIEW_WORK_DIR="$WD"
}

cleanup_workdir() {
  local d=$1
  rm -rf "$d"
  unset MREVIEW_WORK_DIR
}

# ----- tests -----

case_start "1: empty agents dir -> verdict approve, zero counts, all sections (none)"
fresh_workdir
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" '\*\*Verdict: approve\*\*'
  assert_grep "$WD/report.md" '^- Blockers: 0$'
  assert_grep "$WD/report.md" '^- Important: 0$'
  assert_grep "$WD/report.md" '^- Nits: 0$'
  assert_grep "$WD/report.md" '^- Praise: 0$'
  # Each of the four severity sections should show the placeholder.
  count=$(grep -c '^_(none)_$' "$WD/report.md" || true)
  if [ "$count" -ne 4 ]; then
    fail "expected 4 '_(none)_' placeholders, got $count"
  fi
fi
cleanup_workdir "$WD"
pass

case_start "2: single Blocker from code-reviewer -> verdict request-changes"
fresh_workdir
cat > "$WD/agents/code-reviewer.md" <<'EOF'
## Findings

- **Blocker** [sql/foo.cc:42] Buffer overflow on memcpy. (cited from correctness-and-security.md:bounds)
EOF
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" '\*\*Verdict: request-changes\*\*'
  assert_grep "$WD/report.md" '^- Blockers: 1$'
  assert_grep "$WD/report.md" 'sql/foo.cc:42'
  assert_grep "$WD/report.md" 'by code-reviewer'
fi
cleanup_workdir "$WD"
pass

case_start "3: only Important findings -> verdict approve-with-changes"
fresh_workdir
cat > "$WD/agents/code-reviewer.md" <<'EOF'
## Findings

- **Important** [sql/foo.cc:10] Use snake_case here. (cited from coding-style.md:naming)
EOF
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" '\*\*Verdict: approve-with-changes\*\*'
  assert_grep "$WD/report.md" '^- Blockers: 0$'
  assert_grep "$WD/report.md" '^- Important: 1$'
fi
cleanup_workdir "$WD"
pass

case_start "4: same (severity, location) from two agents -> deduped with also-flagged-by"
fresh_workdir
cat > "$WD/agents/code-reviewer.md" <<'EOF'
## Findings

- **Important** [sql/foo.cc:10] Missing null check. (cited from correctness.md:null)
EOF
cat > "$WD/agents/silent-failure-hunter.md" <<'EOF'
## Findings

- **Important** [sql/foo.cc:10] No null check; will segfault. (cited from correctness.md:null)
EOF
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" '^- Important: 1$'
  assert_grep "$WD/report.md" 'also flagged by'
  # Extract just the Important section (between "## Important" and the
  # next "## " heading) and count finding lines starting with "- **".
  section=$(awk '
    /^## Important[[:space:]]*$/ { inside=1; next }
    /^## / && inside { exit }
    inside { print }
  ' "$WD/report.md")
  finding_lines=$(printf '%s\n' "$section" | grep -c '^- \*\*Important\*\*' || true)
  if [ "$finding_lines" -ne 1 ]; then
    fail "expected exactly 1 Important finding line, got $finding_lines"
    echo "Section content:" >&2
    printf '%s\n' "$section" | sed 's/^/    /' >&2
  fi
fi
cleanup_workdir "$WD"
pass

case_start "5: per-agent appendix preserves verbatim agent output"
fresh_workdir
printf 'verbatim agent output here\n' > "$WD/agents/code-reviewer.md"
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" 'verbatim agent output here'
  assert_grep "$WD/report.md" '^### code-reviewer$'
fi
cleanup_workdir "$WD"
pass

case_start "6: tier.txt=standard -> '- Tier: standard' appears in Summary"
fresh_workdir
echo "standard" > "$WD/tier.txt"
out=$(bash "$SCRIPT" 2>&1)
rc=$?
assert_eq "$rc" "0"
if [ "$rc" -eq 0 ]; then
  assert_grep "$WD/report.md" '^- Tier: standard$'
fi
cleanup_workdir "$WD"
pass

case_start "7: MREVIEW_WORK_DIR unset -> exit 64"
unset MREVIEW_WORK_DIR || true
rc=0
bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "64"
pass

# ----- summary -----
echo "---"
echo "$((total-fails))/$total passed"
exit "$fails"
