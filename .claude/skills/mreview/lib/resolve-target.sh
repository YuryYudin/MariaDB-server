#!/usr/bin/env bash
# Phase 1 — Resolve target. Classifies a raw user argument into a structured
# target description. In --dry-run mode, prints key=value lines to stdout and
# exits. In non-dry-run mode (Task 3), it materializes $WORK_DIR/target.json,
# $WORK_DIR/diff.patch and $WORK_DIR/touched-paths.txt.
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

# ---------- non-dry-run path: materialize artifacts ----------

if [[ -z "${MREVIEW_WORK_DIR:-}" ]]; then
  echo "resolve-target.sh: MREVIEW_WORK_DIR is not set" >&2
  exit 64
fi
WORK_DIR="$MREVIEW_WORK_DIR"
mkdir -p "$WORK_DIR"

# Parse KV_LINES into an associative array T.
declare -A T=()
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  T["$key"]="$val"
done <<<"$KV_LINES"

TYPE="${T[type]:-}"

# write_target_json: write $WORK_DIR/target.json from associative array T.
write_target_json() {
  local args=() k
  for k in "${!T[@]}"; do
    args+=(--arg "$k" "${T[$k]}")
  done
  jq -n "${args[@]}" '$ARGS.named' > "$WORK_DIR/target.json"
}

# Stage artifacts to .tmp files and mv on success so a failing git command
# leaves WORK_DIR clean instead of half-written placeholders.
DIFF_TMP="$WORK_DIR/diff.patch.$$"
PATHS_TMP="$WORK_DIR/touched-paths.txt.$$"
trap 'rm -f "$DIFF_TMP" "$PATHS_TMP"' EXIT

case "$TYPE" in
  commit)
    SHA="${T[sha]}"
    write_target_json
    git show --first-parent "$SHA" > "$DIFF_TMP"
    git show --first-parent --name-only --format= "$SHA" | awk 'NF' > "$PATHS_TMP"
    mv "$DIFF_TMP" "$WORK_DIR/diff.patch"
    mv "$PATHS_TMP" "$WORK_DIR/touched-paths.txt"
    ;;
  range)
    BASE="${T[base]}"
    HEAD_REF="${T[head]}"
    write_target_json
    git diff "${BASE}..${HEAD_REF}" > "$DIFF_TMP"
    git diff --name-only "${BASE}..${HEAD_REF}" | awk 'NF' > "$PATHS_TMP"
    mv "$DIFF_TMP" "$WORK_DIR/diff.patch"
    mv "$PATHS_TMP" "$WORK_DIR/touched-paths.txt"
    ;;
  staged)
    write_target_json
    git diff --cached > "$DIFF_TMP"
    git diff --cached --name-only | awk 'NF' > "$PATHS_TMP"
    mv "$DIFF_TMP" "$WORK_DIR/diff.patch"
    mv "$PATHS_TMP" "$WORK_DIR/touched-paths.txt"
    ;;
  working)
    write_target_json
    git diff > "$DIFF_TMP"
    git diff --name-only | awk 'NF' > "$PATHS_TMP"
    mv "$DIFF_TMP" "$WORK_DIR/diff.patch"
    mv "$PATHS_TMP" "$WORK_DIR/touched-paths.txt"
    ;;
  branch)
    BRANCH="${T[branch]}"
    # Compute merge-base: origin/main, then main, then <branch>^.
    BASE=""
    if BASE=$(git merge-base "$BRANCH" origin/main 2>/dev/null); then
      :
    elif BASE=$(git merge-base "$BRANCH" main 2>/dev/null); then
      :
    elif BASE=$(git rev-parse --verify --quiet "${BRANCH}^" 2>/dev/null); then
      :
    else
      echo "resolve-target.sh: cannot determine merge-base for branch '$BRANCH'" >&2
      exit 1
    fi
    T[base]="$BASE"
    write_target_json
    git diff "${BASE}..${BRANCH}" > "$DIFF_TMP"
    git diff --name-only "${BASE}..${BRANCH}" | awk 'NF' > "$PATHS_TMP"
    mv "$DIFF_TMP" "$WORK_DIR/diff.patch"
    mv "$PATHS_TMP" "$WORK_DIR/touched-paths.txt"
    ;;
  github_pr)
    write_target_json
    LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
    bash "$LIB_DIR/fetch-pr.sh" "${T[repo]}" "${T[pr_number]}"
    exit 0
    ;;
  mdev_lookup|auto)
    # Deferred: dispatch is handled by Task 5.
    # Task 5 will write diff.patch and touched-paths.txt for these types.
    write_target_json
    exit 0
    ;;
  *)
    echo "resolve-target.sh: unknown classified type '$TYPE'" >&2
    exit 1
    ;;
esac

# Empty-diff fast fail (only for the locally-resolvable types above).
# A commit can produce a non-empty `git show` header (commit metadata) while
# touching no files at all — so require BOTH the diff body AND the path list
# to be non-empty.
if [[ ! -s "$WORK_DIR/diff.patch" || ! -s "$WORK_DIR/touched-paths.txt" ]]; then
  echo "diff is empty — nothing to review" >&2
  exit 66
fi

exit 0
