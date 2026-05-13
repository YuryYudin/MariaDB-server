#!/usr/bin/env bash
# select-profiles.sh: pick which reviewer profile markdown files apply
# to a review run. Profiles live under .claude/reviewers/<login>.md and
# are cached at $MREVIEW_WORK_DIR/profiles/<login>.md by setup-workdir.sh.
#
# Usage:
#   select-profiles.sh                   # auto-detect from pr-meta.json
#   select-profiles.sh --profile <name>  # force one profile
#   select-profiles.sh --no-profile      # emit nothing
#
# Output: one filename (basename only, e.g. "vuvova.md") per line.
# The caller looks each up under $MREVIEW_WORK_DIR/profiles/<name>.
#
# Exit codes:
#   0  ok (possibly empty output)
#   64 usage error / $MREVIEW_WORK_DIR unset
#   69 --profile named a profile that is not cached
set -euo pipefail

usage() {
  echo "usage: select-profiles.sh [--profile <name> | --no-profile]" >&2
  exit 64
}

profile=""
no_profile=0

while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      [ $# -ge 2 ] || usage
      profile=$2
      shift 2
      ;;
    --no-profile)
      no_profile=1
      shift
      ;;
    *)
      usage
      ;;
  esac
done

# --profile and --no-profile are mutually exclusive.
if [ -n "$profile" ] && [ "$no_profile" -eq 1 ]; then
  usage
fi

if [ -z "${MREVIEW_WORK_DIR:-}" ]; then
  echo "MREVIEW_WORK_DIR not set" >&2
  exit 64
fi

cache_dir="$MREVIEW_WORK_DIR/profiles"

# Mode: --no-profile -> emit nothing.
if [ "$no_profile" -eq 1 ]; then
  exit 0
fi

# Mode: --profile <name> -> require the cached file.
if [ -n "$profile" ]; then
  path="$cache_dir/$profile.md"
  if [ -f "$path" ]; then
    printf '%s\n' "$profile.md"
    exit 0
  fi
  echo "no profile: $path" >&2
  exit 69
fi

# Mode: auto-detect from pr-meta.json.
meta="$MREVIEW_WORK_DIR/pr-meta.json"
if [ ! -s "$meta" ]; then
  exit 0
fi

emitted=0
while IFS= read -r login; do
  [ -z "$login" ] && continue
  [ "$emitted" -ge 2 ] && break
  if [ -f "$cache_dir/$login.md" ]; then
    printf '%s\n' "$login.md"
    emitted=$((emitted+1))
  fi
done < <(jq -r '
  [
    (.assignees // [])[]?.login,
    (.reviewRequests // [])[]?.login,
    (.comments // [])[]?.author.login
  ] | unique | .[]' "$meta")
