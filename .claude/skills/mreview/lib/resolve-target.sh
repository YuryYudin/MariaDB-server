#!/usr/bin/env bash
# Phase 1 — Resolve target. Classifies a raw user argument into a structured
# target description. In --dry-run mode, prints key=value lines to stdout and
# exits. In non-dry-run mode (Task 3), it will materialize $WORK_DIR/target.json
# and $WORK_DIR/diff.patch.
set -euo pipefail

DRY_RUN=0
ARG=""

# Parse flags. Only --dry-run is special; --staged/--working/--working-tree
# are themselves valid target arguments and must NOT be consumed here.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --staged|--working|--working-tree)
      ARG="$1"
      shift
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]; then ARG="$1"; shift; fi
      ;;
    -h|--help)
      echo "usage: $0 [--dry-run] [<arg>]" >&2
      exit 64
      ;;
    -*)
      echo "usage: $0 [--dry-run] [<arg>]" >&2
      echo "unknown option: $1" >&2
      exit 64
      ;;
    *)
      if [[ -n "$ARG" ]]; then
        echo "usage: $0 [--dry-run] [<arg>]" >&2
        echo "too many positional arguments" >&2
        exit 64
      fi
      ARG="$1"
      shift
      ;;
  esac
done

# ---------- classification ----------
# Sets KV_LINES (newline-separated key=value pairs) for the resolved target,
# or exits non-zero with a message if classification fails.
KV_LINES=""

emit() { KV_LINES="${KV_LINES}${1}"$'\n'; }

classify() {
  local arg="$1"

  # 1. GitHub PR URL: https?://github.com/<owner>/<repo>/pull/<N>
  if [[ "$arg" =~ ^https?://github\.com/([^/]+)/([^/]+)/pull/([1-9][0-9]*)/?$ ]]; then
    local repo="${BASH_REMATCH[2]}"
    # Strip a trailing .git from the captured repo (URLs like
    # https://github.com/foo/bar.git/pull/1 are still valid GH URLs).
    repo="${repo%.git}"
    emit "type=github_pr"
    emit "repo=${BASH_REMATCH[1]}/${repo}"
    emit "pr_number=${BASH_REMATCH[3]}"
    return 0
  fi

  # 2. owner/repo#N
  if [[ "$arg" =~ ^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)#([1-9][0-9]*)$ ]]; then
    emit "type=github_pr"
    emit "repo=${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    emit "pr_number=${BASH_REMATCH[3]}"
    return 0
  fi

  # 3. MDEV-<digits>
  if [[ "$arg" =~ ^MDEV-[0-9]+$ ]]; then
    emit "type=mdev_lookup"
    emit "mdev=$arg"
    return 0
  fi

  # 4. 1-6 digit integer (1-999999, no leading zero) → GH PR on MariaDB/server
  #    (must come before SHA check, since "123456" is also valid hex)
  if [[ "$arg" =~ ^[1-9][0-9]{0,5}$ ]]; then
    emit "type=github_pr"
    emit "repo=MariaDB/server"
    emit "pr_number=$arg"
    return 0
  fi

  # 5. Range: strictly two-dot A..B form. Empty head defaults to HEAD.
  #    Three-dot A...B and empty base (..foo / ..) are rejected — they would
  #    otherwise be silently mangled by the previous %%..* / #*.. split.
  if [[ "$arg" =~ ^([^.][^.]*)\.\.([^.][^.]*)?$ ]]; then
    local base="${BASH_REMATCH[1]}"
    local head="${BASH_REMATCH[2]}"
    [[ -z "$head" ]] && head="HEAD"
    emit "type=range"
    emit "base=$base"
    emit "head=$head"
    return 0
  fi

  # 6. --staged
  if [[ "$arg" == "--staged" ]]; then
    emit "type=staged"
    return 0
  fi

  # 7. --working / --working-tree
  if [[ "$arg" == "--working" || "$arg" == "--working-tree" ]]; then
    emit "type=working"
    return 0
  fi

  # 8. 7-40 hex chars resolving as a commit
  if [[ "$arg" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    local sha
    if sha=$(git rev-parse --verify --quiet "${arg}^{commit}" 2>/dev/null); then
      emit "type=commit"
      emit "sha=$sha"
      return 0
    fi
  fi

  # 9. Local branch
  if git rev-parse --verify --quiet "refs/heads/$arg" >/dev/null 2>&1; then
    emit "type=branch"
    emit "branch=$arg"
    return 0
  fi

  # No match
  echo "could not resolve target: '$arg'" >&2
  exit 65
}

if [[ -z "$ARG" ]]; then
  emit "type=auto"
else
  classify "$ARG"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '%s' "$KV_LINES"
  exit 0
fi

# Non-dry-run path: filled in by Task 3 (materialize $WORK_DIR/target.json
# and $WORK_DIR/diff.patch from the classified target).
echo "resolve-target.sh: non-dry-run mode not yet implemented (Task 3)" >&2
exit 1
