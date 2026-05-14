#!/usr/bin/env bash
# detect-structural-concerns.sh: scan a unified diff for likely structural
# issues (DRY violation, copy-paste across hunks) and emit one finding per
# line to stdout.
#
# Usage:
#   detect-structural-concerns.sh <diff-file>
#
# The output is passed verbatim to the structural-review pass in each agent's
# prompt as a "prior-detection" hint. Heuristics intentionally favour
# false-positives over false-negatives — the agent is responsible for
# confirming or dismissing each concern.
#
# Exit codes:
#   0  no concerns found
#   1  at least one concern found
#   64 usage error
set -euo pipefail

if [ $# -lt 1 ] || [ -z "${1:-}" ]; then
  echo "usage: $0 <diff-file>" >&2
  exit 64
fi

DIFF="$1"
if [ ! -s "$DIFF" ]; then
  exit 0
fi

found=0

# -----------------------------------------------------------------------------
# Heuristic 1 (S1/S5): repeated added lines.
#
# Any non-trivial '+' line that appears >= 3 times in the diff is a likely
# copy-paste signal. Three repetitions is the typical signature of "I added the
# same cleanup to three sibling methods instead of extracting a helper" — the
# MDEV-23676 family of regressions.
DUPES=$(
  awk '
    /^\+\+\+/ { next }
    /^\+/ {
      line = $0
      sub(/^\+/, "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      if (length(line) < 10) next
      if (line ~ /^(\/\/|\/\*|\*|#|}|\)|return;|break;|continue;)$/) next
      print line
    }
  ' "$DIFF" | sort | uniq -c | awk '$1 >= 3' | sort -rn
)

if [ -n "$DUPES" ]; then
  found=1
  echo "S1 (likely DRY violation): the following + lines appear 3+ times across the diff."
  echo "    Possible copy-paste of a 3-way pattern across sibling methods."
  echo "    Check whether the sibling code already factors this into a helper."
  echo "$DUPES" | head -10 | sed 's/^/    /'
  echo ""
fi

# -----------------------------------------------------------------------------
# Heuristic 2 (S5): a single non-trivial '+' line that appears exactly twice
# is a weaker but still useful copy-paste signal — flag it as a softer concern.
TWICES=$(
  awk '
    /^\+\+\+/ { next }
    /^\+/ {
      line = $0
      sub(/^\+/, "", line)
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      if (length(line) < 16) next
      if (line ~ /^(\/\/|\/\*|\*|#|}|\)|return;|break;|continue;)$/) next
      print line
    }
  ' "$DIFF" | sort | uniq -c | awk '$1 == 2' | sort -rn | head -5
)

if [ -n "$TWICES" ]; then
  found=1
  echo "S5 (possible copy-paste): the following non-trivial + lines appear exactly twice."
  echo "    Lower-confidence than S1 but worth a look."
  echo "$TWICES" | sed 's/^/    /'
  echo ""
fi

# -----------------------------------------------------------------------------
# Heuristic 3 (S3): commit-message-vs-code mismatch markers.
# This script only sees the diff, so we can't see the commit body directly.
# But if the diff is itself "claims-to-mirror" inside a comment, flag it.
MIRROR_COMMENTS=$(
  grep -nE '^\+.*\<(mirror|mirroring|matches|same as|in the style of|equivalent to)\>' "$DIFF" \
    | head -5 || true
)

if [ -n "$MIRROR_COMMENTS" ]; then
  found=1
  echo "S3 (claim to verify): diff contains 'mirror'/'matches'/'equivalent' wording."
  echo "    Verify that the cited reference (sibling code, prior MDEV) ACTUALLY"
  echo "    matches in both SHAPE and FACTORING, not just the function name."
  echo "$MIRROR_COMMENTS" | sed 's/^/    /'
  echo ""
fi

# -----------------------------------------------------------------------------
# Heuristic 4 (S2): the diff modifies multiple methods on the same class with
# matching name patterns. Detect Foo::Bar_*() with N >= 2 distinct Bar_*
# additions, signalling a "patched N sibling methods" pattern.
CLASS_SIBLING_HITS=$(
  awk '
    /^\+\+\+/ { next }
    /^[ +-]/ {
      # function-definition lines look like  bool Foo::Bar(...
      if (match($0, /[A-Z][A-Za-z_0-9]+::[A-Z][A-Za-z_0-9]+/)) {
        sym = substr($0, RSTART, RLENGTH)
        split(sym, parts, "::")
        klass = parts[1]; method = parts[2]
        key = klass
        seen_method[klass, method] = 1
      }
    }
    END {
      for (k in seen_method) {
        split(k, kk, SUBSEP)
        klass_count[kk[1]]++
      }
      for (klass in klass_count) {
        if (klass_count[klass] >= 2) {
          print klass " (" klass_count[klass] " methods)"
        }
      }
    }
  ' "$DIFF" | sort -u
)

if [ -n "$CLASS_SIBLING_HITS" ]; then
  found=1
  echo "S2/S6 (sibling-pattern check): the diff modifies 2+ methods on the same class(es)."
  echo "    Check sibling classes (analogous Type_handler, Item, handler) for the"
  echo "    accepted factoring of this same pattern. Match BOTH the shape and the"
  echo "    factoring; do not inline a cleanup that the sibling extracts, or vice"
  echo "    versa, without an explicit justification."
  echo "$CLASS_SIBLING_HITS" | sed 's/^/    /'
  echo ""
fi

# -----------------------------------------------------------------------------
[ "$found" = 1 ] && exit 1 || exit 0
