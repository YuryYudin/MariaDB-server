#!/usr/bin/env bash
# tier-agents.sh: map a strictness tier + diff statistics to the list
# of pr-review-toolkit agents to dispatch.
#
# Usage:
#   tier-agents.sh <tier> <diff-file> <paths-file>
#
# <tier>       one of: quick, standard, deep
# <diff-file>  unified diff (may be missing/empty)
# <paths-file> list of touched paths, one per line (may be missing/empty)
#
# Output: one agent name per line on stdout, sorted alphabetically.
#
# Tier base sets:
#   quick    -> code-reviewer
#   standard -> code-reviewer, silent-failure-hunter
#   deep     -> code-reviewer, silent-failure-hunter, pr-test-analyzer,
#               comment-analyzer, type-design-analyzer
#
# Auto-elevations (applied on top of the base set, deduped):
#   + pr-test-analyzer     if <paths-file> has >=10 lines matching
#                          ^mysql-test/.*\.(test|result)$
#   + comment-analyzer     if <diff-file> has >=30 net added comment lines
#                          (lines matching ^\+[[:space:]]*(//|/\*|\*|#))
#   + type-design-analyzer if <diff-file> has >=1 line matching
#                          ^\+[[:space:]]*(class|struct)[[:space:]]+
#                          [A-Z][A-Za-z0-9_]*
#
# Exit codes:
#   0  ok
#   64 usage error / unknown tier
set -euo pipefail

usage() {
  echo "usage: tier-agents.sh <tier> <diff-file> <paths-file>" >&2
  exit 64
}

[ $# -eq 3 ] || usage

tier=$1
diff_file=$2
paths_file=$3

# Collect agents in an associative-like list, dedup at the end.
agents=()

case "$tier" in
  quick)
    agents+=("code-reviewer")
    ;;
  standard)
    agents+=("code-reviewer" "silent-failure-hunter")
    ;;
  deep)
    agents+=("code-reviewer" "silent-failure-hunter" \
             "pr-test-analyzer" "comment-analyzer" "type-design-analyzer")
    ;;
  *)
    usage
    ;;
esac

# Auto-elevation: >=10 mysql-test test/result files in touched paths.
test_count=0
if [ -n "$paths_file" ] && [ -f "$paths_file" ]; then
  test_count=$(grep -cE '^mysql-test/.*\.(test|result)$' "$paths_file" || true)
fi
if [ "$test_count" -ge 10 ]; then
  agents+=("pr-test-analyzer")
fi

# Auto-elevation: >=30 added comment lines in diff.
comment_count=0
if [ -n "$diff_file" ] && [ -f "$diff_file" ]; then
  comment_count=$(grep -cE '^\+[[:space:]]*(//|/\*|\*|#)' "$diff_file" || true)
fi
if [ "$comment_count" -ge 30 ]; then
  agents+=("comment-analyzer")
fi

# Auto-elevation: at least one new class/struct definition in diff.
type_count=0
if [ -n "$diff_file" ] && [ -f "$diff_file" ]; then
  type_count=$(grep -cE \
    '^\+[[:space:]]*(class|struct)[[:space:]]+[A-Z][A-Za-z0-9_]*' \
    "$diff_file" || true)
fi
if [ "$type_count" -ge 1 ]; then
  agents+=("type-design-analyzer")
fi

# Emit deduped, sorted.
printf '%s\n' "${agents[@]}" | sort -u
