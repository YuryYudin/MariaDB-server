#!/usr/bin/env bash
# synthesize.sh: merge per-agent reports under $MREVIEW_WORK_DIR/agents/*.md
# into a single $MREVIEW_WORK_DIR/report.md.
#
# Each agent report is free-form Markdown, but every line of the form:
#   - **<Severity>** [<path>:<line>] <body> (cited from <source>)
# is treated as a structured finding. Severity is one of:
#   Blocker / Important / Nit / Praise
#
# Findings with the SAME severity AND same [location] from DIFFERENT agents
# are deduped: the first encountered is kept, and "(also flagged by <other>)"
# is appended to its rendered line.
#
# Verdict is derived from counts:
#   >=1 Blocker                  -> request-changes
#   0 Blockers, >=1 Important    -> approve-with-changes
#   otherwise                    -> approve
#
# Inputs (env):
#   MREVIEW_WORK_DIR  required; must contain an agents/ subdirectory
#                     (may be empty); optionally a tier.txt file.
#
# Output:
#   $MREVIEW_WORK_DIR/report.md
#
# Exit codes:
#   0   ok
#   64  MREVIEW_WORK_DIR not set
set -euo pipefail

if [ -z "${MREVIEW_WORK_DIR:-}" ]; then
  echo "synthesize.sh: MREVIEW_WORK_DIR must be set" >&2
  exit 64
fi

WORK_DIR="$MREVIEW_WORK_DIR"
AGENTS_DIR="$WORK_DIR/agents"
REPORT="$WORK_DIR/report.md"
FINDINGS_TSV="$WORK_DIR/.findings.tsv"

if [ -f "$WORK_DIR/tier.txt" ]; then
  TIER="$(head -n1 "$WORK_DIR/tier.txt")"
else
  TIER="unknown"
fi
[ -n "$TIER" ] || TIER="unknown"

# Parse each agent's findings into a single TSV:
#   severity \t location \t body \t agent
: > "$FINDINGS_TSV"

parse_findings() {
  local f="$1" agent line
  agent="$(basename "$f" .md)"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^-[[:space:]]+\*\*(Blocker|Important|Nit|Praise)\*\*[[:space:]]+(\[[^]]+\])[[:space:]]+(.+)$ ]]; then
      local sev="${BASH_REMATCH[1]}"
      local loc="${BASH_REMATCH[2]}"
      local body="${BASH_REMATCH[3]}"
      printf '%s\t%s\t%s\t%s\n' "$sev" "$loc" "$body" "$agent" \
        >> "$FINDINGS_TSV"
    fi
  done < "$f"
}

if [ -d "$AGENTS_DIR" ]; then
  # Sort filenames so the "first encountered" agent is deterministic.
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    parse_findings "$f"
  done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' | sort)
fi

# Counts per severity bucket. Counts unique (severity, location) pairs:
# a finding flagged by two agents at the same location counts once, since
# it is rendered as one merged line with "(also flagged by ...)".
count_severity() {
  local sev="$1"
  awk -F'\t' -v sev="$sev" '
    $1 == sev {
      if (!($2 in seen)) { seen[$2] = 1; c++ }
    }
    END { print c+0 }
  ' "$FINDINGS_TSV"
}

BLOCKERS=$(count_severity Blocker)
IMPORTANTS=$(count_severity Important)
NITS=$(count_severity Nit)
PRAISES=$(count_severity Praise)

if [ "$BLOCKERS" -ge 1 ]; then
  VERDICT="request-changes"
elif [ "$IMPORTANTS" -ge 1 ]; then
  VERDICT="approve-with-changes"
else
  VERDICT="approve"
fi

# Dedupe + render one section's findings, sorted by location.
# Same (severity, location) from different agents -> first wins, others
# are appended as "(also flagged by ...)".
dedupe_and_render() {
  local sev="$1"
  awk -F'\t' -v sev="$sev" '
    $1 == sev {
      key = $2
      if (key in seen) {
        if (also[key] == "") {
          also[key] = $4
        } else {
          also[key] = also[key] ", " $4
        }
      } else {
        order[++n] = key
        seen[key] = $0
      }
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        split(seen[k], f, "\t")
        line = "- **" f[1] "** " f[2] " " f[3] " \xe2\x80\x94 by " f[4]
        if (k in also && also[k] != "") {
          line = line " (also flagged by " also[k] ")"
        }
        print line
      }
    }
  ' "$FINDINGS_TSV" | LC_ALL=C sort
}

{
  echo "# mreview report"
  echo ""
  echo "**Verdict: $VERDICT**"
  echo ""
  echo "## Summary"
  echo ""
  echo "- Tier: $TIER"
  echo "- Blockers: $BLOCKERS"
  echo "- Important: $IMPORTANTS"
  echo "- Nits: $NITS"
  echo "- Praise: $PRAISES"
  echo ""
  for sev in Blocker Important Nit Praise; do
    echo "## $sev"
    echo ""
    rendered=$(dedupe_and_render "$sev")
    if [ -n "$rendered" ]; then
      echo "$rendered"
    else
      echo "_(none)_"
    fi
    echo ""
  done
  echo "## Per-agent appendix"
  echo ""
  if [ -d "$AGENTS_DIR" ]; then
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      echo "### $(basename "$f" .md)"
      echo ""
      cat "$f"
      echo ""
    done < <(find "$AGENTS_DIR" -maxdepth 1 -type f -name '*.md' | sort)
  fi
} > "$REPORT"

rm -f "$FINDINGS_TSV"
