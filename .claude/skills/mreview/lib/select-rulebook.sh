#!/usr/bin/env bash
# select-rulebook.sh: pick which rulebook markdown files (under
# .claude/review/) apply to a review run, based on a touched-areas.txt
# file produced by derive-areas.sh.
#
# Usage: select-rulebook.sh <touched-areas.txt>
# Emits one filename (basename only) per line on stdout. The caller
# looks each up under $WORK_DIR/rulebook/<name>.
#
# Optional $MREVIEW_DIFF env var: if set and the file exists, scan it
# for memcpy/strncpy/strcpy/acl/grant/password/ASAN/UBSAN markers
# (case-insensitive). If any match, also emit correctness-and-security.md.
#
# Exit 64 on missing arg.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: select-rulebook.sh <touched-areas.txt>" >&2
  exit 64
fi

input=$1

# Collect output deduped, preserving first-emit order.
emitted=""
emit() {
  local name=$1
  case "$emitted" in
    *"|$name|"*) return 0 ;;
  esac
  emitted="${emitted}|$name|"
  printf '%s\n' "$name"
}

# Baseline files (always emitted).
emit "checklist.md"
emit "commit-and-process.md"
emit "coding-style.md"
emit "anti-patterns.md"

# Area-specific additions.
if [ -r "$input" ]; then
  saw_sql_storage_plugin=0
  while IFS= read -r area || [ -n "$area" ]; do
    [ -z "$area" ] && continue
    case "$area" in
      "storage/innobase/")
        emit "innodb.md"
        saw_sql_storage_plugin=1
        ;;
      "mysql-test/")
        emit "testing.md"
        ;;
      "cmake")
        emit "build-and-cmake.md"
        ;;
      "errmsg")
        emit "logging-and-errors.md"
        ;;
      "sql/"|"storage/"|"plugin/")
        saw_sql_storage_plugin=1
        ;;
    esac
  done < "$input"

  if [ "$saw_sql_storage_plugin" -eq 1 ]; then
    emit "api-and-architecture.md"
  fi
fi

# Optional diff scan for correctness/security triggers.
if [ -n "${MREVIEW_DIFF:-}" ] && [ -r "${MREVIEW_DIFF}" ]; then
  if grep -iE 'memcpy|strncpy|strcpy|acl|grant|password|ASAN|UBSAN' \
       "$MREVIEW_DIFF" >/dev/null 2>&1; then
    emit "correctness-and-security.md"
  fi
fi
