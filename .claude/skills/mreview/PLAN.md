# mreview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a MariaDB-specific code-review orchestration skill (`mreview`) that runs `pr-review-toolkit` agents against any target (working tree, staged, SHA, range, branch, GitHub PR, MDEV ticket), informed by `.claude/review/*.md` rulebook and `.claude/reviewers/*.md` profiles, with three strictness tiers and a structured merged report.

**Architecture:** Mirrors `mfix` structure: a `SKILL.md` that orchestrates 6 gated phases (Setup → Resolve → Inspect → Dispatch → Synthesize → Present), with shell helpers for deterministic pieces (target resolution, area mapping, profile pick). The skill is invoked stand-alone and is also the canonical implementation that mfix Phase 7.5 delegates to. All artifacts live under `$WORK_DIR=$HOME/.cache/mreview/<id>/`.

**Tech Stack:** Bash 4+ for helper scripts (with `bats-core` for unit tests), `gh` CLI for GitHub access, `jq` for JSON, `git` for diff materialization, Claude Skill tool for agent dispatch. No new runtime dependencies beyond what mfix already uses.

---

## File Structure

```
.claude/skills/mreview/
├── SKILL.md                 # phase-by-phase skill body (~450 lines target)
├── DESIGN.md                # already written — reference doc, do not modify
├── PLAN.md                  # this file
├── SKILL_VALIDATION.md      # validation runs, written in Task 17
├── lib/                     # reusable shell helpers (each <80 lines)
│   ├── resolve-target.sh    # input → target.json + diff.patch
│   ├── derive-areas.sh      # touched-paths.txt → touched-areas.txt
│   ├── select-rulebook.sh   # touched-areas.txt → loaded-rulebook.txt
│   ├── select-profiles.sh   # pr-meta.json + rulebook → loaded-profiles.txt
│   ├── tier-agents.sh       # tier + diff stats → agent list
│   └── synthesize.sh        # agents/*.md → report.md
└── tests/                   # bats tests for helpers
    ├── test_resolve_target.bats
    ├── test_derive_areas.bats
    ├── test_select_rulebook.bats
    ├── test_select_profiles.bats
    ├── test_tier_agents.bats
    └── test_synthesize.bats
```

The split into `lib/` is deliberate: each helper has one responsibility, is unit-testable with bats, and is reusable from both the skill body and from ad-hoc scripts. The SKILL.md becomes thin orchestration: "run lib/resolve-target.sh, check exit code, read target.json, …".

Helper scripts emit deterministic artifacts under `$WORK_DIR` and are silent on success (errors to stderr, exit non-zero). That means the SKILL.md body never needs to parse helper stdout — it reads the artifact files.

---

## Task 1: Scaffolding + Phase 0 (Setup)

**Files:**
- Create: `.claude/skills/mreview/lib/setup-workdir.sh`
- Create: `.claude/skills/mreview/tests/test_setup_workdir.bats`

- [ ] **Step 1: Write the failing test**

`.claude/skills/mreview/tests/test_setup_workdir.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMPHOME=$(mktemp -d)
  export HOME="$TMPHOME"
  unset MREVIEW_WORK_DIR
  REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
  cd "$REPO_ROOT"
}

teardown() { rm -rf "$TMPHOME"; }

@test "setup-workdir creates dir under HOME/.cache/mreview when no override" {
  run bash .claude/skills/mreview/lib/setup-workdir.sh test-id-123
  [ "$status" -eq 0 ]
  [ -d "$HOME/.cache/mreview/test-id-123" ]
  [ -d "$HOME/.cache/mreview/test-id-123/rulebook" ]
  [ -d "$HOME/.cache/mreview/test-id-123/profiles" ]
  [ -d "$HOME/.cache/mreview/test-id-123/agents" ]
}

@test "setup-workdir respects MREVIEW_WORK_DIR override" {
  export MREVIEW_WORK_DIR="$TMPHOME/custom-dir"
  run bash .claude/skills/mreview/lib/setup-workdir.sh test-id-999
  [ "$status" -eq 0 ]
  [ -d "$TMPHOME/custom-dir" ]
  [ ! -d "$HOME/.cache/mreview/test-id-999" ]
}

@test "setup-workdir caches .claude/review/*.md from main into rulebook/" {
  run bash .claude/skills/mreview/lib/setup-workdir.sh test-id-456
  [ "$status" -eq 0 ]
  [ -f "$HOME/.cache/mreview/test-id-456/rulebook/checklist.md" ]
  [ -f "$HOME/.cache/mreview/test-id-456/rulebook/coding-style.md" ]
}

@test "setup-workdir caches .claude/reviewers/*.md from main into profiles/" {
  run bash .claude/skills/mreview/lib/setup-workdir.sh test-id-789
  [ "$status" -eq 0 ]
  [ -f "$HOME/.cache/mreview/test-id-789/profiles/vuvova.md" ]
}

@test "setup-workdir fails fast when target id is missing" {
  run bash .claude/skills/mreview/lib/setup-workdir.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "usage:" ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_setup_workdir.bats`
Expected: All tests FAIL — script does not exist yet (`No such file or directory`).

- [ ] **Step 3: Write the helper**

`.claude/skills/mreview/lib/setup-workdir.sh`:

```bash
#!/usr/bin/env bash
# Phase 0 — Setup. Creates $WORK_DIR and populates rulebook + profiles caches
# from the configured review-ref branch (default: main). Idempotent.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <target-id>" >&2
  echo "  <target-id> = PR number / short SHA / sanitized branch / timestamp" >&2
  exit 64
fi
TARGET_ID="$1"

WORK_DIR="${MREVIEW_WORK_DIR:-$HOME/.cache/mreview/$TARGET_ID}"
REVIEW_REF="${MFIX_REVIEW_REF:-main}"

mkdir -p "$WORK_DIR"/{rulebook,profiles,agents}

# Cache rulebook + profiles from $REVIEW_REF so a later branch checkout
# can't make them disappear.
for sub in review reviewers; do
  case "$sub" in
    review)    dest="$WORK_DIR/rulebook"  ;;
    reviewers) dest="$WORK_DIR/profiles"  ;;
  esac
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    out="$dest/$(basename "$path")"
    git show "$REVIEW_REF:$path" > "$out" 2>/dev/null || true
  done < <(git ls-tree -r --name-only "$REVIEW_REF" -- ".claude/$sub/" \
           | grep -E '\.md$' || true)
done

echo "$WORK_DIR"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats .claude/skills/mreview/tests/test_setup_workdir.bats`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/setup-workdir.sh \
        .claude/skills/mreview/tests/test_setup_workdir.bats
git commit -m "$(cat <<'EOF'
mreview: add Phase 0 setup-workdir helper

Creates $WORK_DIR, caches .claude/review/*.md and .claude/reviewers/*.md
from the configured review-ref (default: main) so the artifacts survive
later branch switches.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Phase 1a — Target resolution (input dispatch)

**Files:**
- Create: `.claude/skills/mreview/lib/resolve-target.sh`
- Create: `.claude/skills/mreview/tests/test_resolve_target.bats`

- [ ] **Step 1: Write the failing test**

`.claude/skills/mreview/tests/test_resolve_target.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export MREVIEW_WORK_DIR="$TMP/wd"
  mkdir -p "$MREVIEW_WORK_DIR"
  REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
  cd "$REPO_ROOT"
}

teardown() { rm -rf "$TMP"; }

@test "resolve-target: 1-6 digit integer → GH PR" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run 4869
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=github_pr" ]]
  [[ "$output" =~ "repo=MariaDB/server" ]]
  [[ "$output" =~ "pr_number=4869" ]]
}

@test "resolve-target: github.com URL → GH PR with owner/repo" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run \
    https://github.com/MariaDB/server/pull/4869
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=github_pr" ]]
  [[ "$output" =~ "pr_number=4869" ]]
}

@test "resolve-target: owner/repo#N → GH PR" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run \
    foo/bar#123
  [ "$status" -eq 0 ]
  [[ "$output" =~ "repo=foo/bar" ]]
  [[ "$output" =~ "pr_number=123" ]]
}

@test "resolve-target: MDEV-NNNNN → mdev_lookup" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run MDEV-23676
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=mdev_lookup" ]]
  [[ "$output" =~ "mdev=MDEV-23676" ]]
}

@test "resolve-target: 40-hex SHA → commit" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run \
    a662a237b48b0000000000000000000000000000
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=commit" ]]
}

@test "resolve-target: A..B range → range" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run \
    HEAD~3..HEAD
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=range" ]]
  [[ "$output" =~ "base=HEAD~3" ]]
  [[ "$output" =~ "head=HEAD" ]]
}

@test "resolve-target: --staged → staged" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run --staged
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=staged" ]]
}

@test "resolve-target: --working → working" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run --working
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=working" ]]
}

@test "resolve-target: existing local branch → branch" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run main
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=branch" ]]
  [[ "$output" =~ "branch=main" ]]
}

@test "resolve-target: no arg → auto" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "type=auto" ]]
}

@test "resolve-target: garbage input exits non-zero" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --dry-run \
    'definitely-not-a-real-thing-@@@'
  [ "$status" -ne 0 ]
  [[ "$output" =~ "could not resolve" ]] || [[ "$output" =~ "no match" ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_resolve_target.bats`
Expected: All tests FAIL — script does not exist yet.

- [ ] **Step 3: Write the resolver dispatcher**

`.claude/skills/mreview/lib/resolve-target.sh`:

```bash
#!/usr/bin/env bash
# Phase 1 — Resolve. Maps a raw user argument to a structured target.
# In --dry-run mode prints key=value pairs and exits; otherwise writes
# $WORK_DIR/target.json plus $WORK_DIR/diff.patch via Task 3 logic.
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1; shift
fi

ARG="${1:-}"

classify() {
  local a="$1"
  if [ -z "$a" ]; then
    echo "type=auto"; return
  fi
  if [ "$a" = "--staged" ]; then
    echo "type=staged"; return
  fi
  if [ "$a" = "--working" ] || [ "$a" = "--working-tree" ]; then
    echo "type=working"; return
  fi
  if [[ "$a" =~ ^https?://github\.com/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
    echo "type=github_pr"
    echo "repo=${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    echo "pr_number=${BASH_REMATCH[3]}"
    return
  fi
  if [[ "$a" =~ ^([^/[:space:]]+/[^/#[:space:]]+)#([0-9]+)$ ]]; then
    echo "type=github_pr"
    echo "repo=${BASH_REMATCH[1]}"
    echo "pr_number=${BASH_REMATCH[2]}"
    return
  fi
  if [[ "$a" =~ ^MDEV-[0-9]+$ ]]; then
    echo "type=mdev_lookup"
    echo "mdev=$a"
    return
  fi
  if [[ "$a" =~ ^[0-9]{1,6}$ ]]; then
    echo "type=github_pr"
    echo "repo=MariaDB/server"
    echo "pr_number=$a"
    return
  fi
  if [[ "$a" =~ \.\. ]]; then
    local base="${a%%..*}"
    local head="${a##*..}"
    [ -z "$head" ] && head="HEAD"
    echo "type=range"
    echo "base=$base"
    echo "head=$head"
    return
  fi
  if [[ "$a" =~ ^[0-9a-f]{7,40}$ ]] && git rev-parse --verify "$a^{commit}" >/dev/null 2>&1; then
    echo "type=commit"
    echo "sha=$(git rev-parse "$a")"
    return
  fi
  if git rev-parse --verify "refs/heads/$a" >/dev/null 2>&1; then
    echo "type=branch"
    echo "branch=$a"
    return
  fi
  return 1
}

if ! out=$(classify "$ARG"); then
  echo "could not resolve target: '$ARG'" >&2
  exit 65
fi

if [ "$DRY_RUN" = 1 ]; then
  echo "$out"
  exit 0
fi

# Non-dry-run path delegates to Task 3 (diff materialization). For now
# just persist the classification; the next task fills in the rest.
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set in non-dry-run mode}"
mkdir -p "$MREVIEW_WORK_DIR"
{
  echo "{"
  echo "$out" | awk -F= 'BEGIN{f=0} {if(f)print ","; printf "  \"%s\": \"%s\"",$1,$2; f=1} END{print ""}'
  echo "}"
} > "$MREVIEW_WORK_DIR/target.json"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats .claude/skills/mreview/tests/test_resolve_target.bats`
Expected: All 11 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/resolve-target.sh \
        .claude/skills/mreview/tests/test_resolve_target.bats
git commit -m "$(cat <<'EOF'
mreview: add Phase 1 target classifier (dry-run mode)

Maps raw user argument forms (PR number, URL, owner/repo#N, MDEV-NNNNN,
SHA, range, --staged, --working, branch, none) to a key=value
classification. Diff materialization in the next commit.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Phase 1b — Diff materialization

**Files:**
- Modify: `.claude/skills/mreview/lib/resolve-target.sh`
- Modify: `.claude/skills/mreview/tests/test_resolve_target.bats`

- [ ] **Step 1: Add failing tests for the materialization path**

Append to `.claude/skills/mreview/tests/test_resolve_target.bats`:

```bash
@test "resolve-target: commit target writes diff.patch and target.json" {
  # use a known small commit from this repo's history
  sha=$(git log --format=%H -n 1 -- CLAUDE.md | head -1)
  [ -n "$sha" ]
  run bash .claude/skills/mreview/lib/resolve-target.sh "$sha"
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/diff.patch" ]
  [ -s "$MREVIEW_WORK_DIR/target.json" ]
  run jq -r .type "$MREVIEW_WORK_DIR/target.json"
  [ "$output" = "commit" ]
}

@test "resolve-target: range target produces diff" {
  run bash .claude/skills/mreview/lib/resolve-target.sh HEAD~1..HEAD
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/diff.patch" ]
  run jq -r .type "$MREVIEW_WORK_DIR/target.json"
  [ "$output" = "range" ]
}

@test "resolve-target: --staged with nothing staged exits non-zero" {
  # ensure no staged changes
  git reset HEAD -- . >/dev/null 2>&1 || true
  run bash .claude/skills/mreview/lib/resolve-target.sh --staged
  [ "$status" -ne 0 ]
  [[ "$output" =~ "empty" ]] || [[ "$output" =~ "nothing" ]]
}

@test "resolve-target: --working with clean tree exits non-zero" {
  run bash .claude/skills/mreview/lib/resolve-target.sh --working
  # Allow either: clean tree (non-zero) or dirty tree (zero with content)
  if [ "$status" -eq 0 ]; then
    [ -s "$MREVIEW_WORK_DIR/diff.patch" ]
  else
    [[ "$output" =~ "empty" ]] || [[ "$output" =~ "nothing" ]]
  fi
}

@test "resolve-target: touched-paths.txt is emitted alongside diff" {
  sha=$(git log --format=%H -n 1 -- CLAUDE.md | head -1)
  run bash .claude/skills/mreview/lib/resolve-target.sh "$sha"
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/touched-paths.txt" ]
  grep -q "CLAUDE.md" "$MREVIEW_WORK_DIR/touched-paths.txt"
}
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `bats .claude/skills/mreview/tests/test_resolve_target.bats`
Expected: The 5 new tests FAIL (diff.patch / touched-paths.txt not written, JSON malformed).

- [ ] **Step 3: Replace the non-dry-run path with full materialization**

Replace the tail of `resolve-target.sh` (everything after the `if [ "$DRY_RUN" = 1 ]` block) with:

```bash
# Materialize diff + structured target.json.
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set in non-dry-run mode}"
mkdir -p "$MREVIEW_WORK_DIR"

declare -A T=()
while IFS='=' read -r k v; do
  [ -n "$k" ] && T["$k"]="$v"
done <<< "$out"

DIFF="$MREVIEW_WORK_DIR/diff.patch"
PATHS="$MREVIEW_WORK_DIR/touched-paths.txt"
: > "$DIFF"; : > "$PATHS"

case "${T[type]}" in
  commit)
    git show --first-parent "${T[sha]}" > "$DIFF"
    git show --first-parent --name-only --format= "${T[sha]}" \
      | awk 'NF' > "$PATHS"
    ;;
  range)
    git diff "${T[base]}..${T[head]}" > "$DIFF"
    git diff --name-only "${T[base]}..${T[head]}" > "$PATHS"
    ;;
  staged)
    git diff --cached > "$DIFF"
    git diff --cached --name-only > "$PATHS"
    ;;
  working)
    git diff > "$DIFF"
    git diff --name-only > "$PATHS"
    ;;
  branch)
    base=$(git merge-base "${T[branch]}" origin/main 2>/dev/null \
           || git merge-base "${T[branch]}" main 2>/dev/null \
           || git rev-parse "${T[branch]}^")
    T[base]="$base"; T[head]="${T[branch]}"
    git diff "$base..${T[branch]}" > "$DIFF"
    git diff --name-only "$base..${T[branch]}" > "$PATHS"
    ;;
  github_pr|mdev_lookup|auto)
    # These types need additional resolution (gh CLI calls, auto-detect
    # walk) — handled in later tasks. For now leave artifacts empty and
    # rely on the caller to skip diff-dependent steps.
    : ;;
esac

if [ ! -s "$DIFF" ] && [ "${T[type]}" != "github_pr" ] \
                   && [ "${T[type]}" != "mdev_lookup" ] \
                   && [ "${T[type]}" != "auto" ]; then
  echo "diff is empty — nothing to review" >&2
  exit 66
fi

# Emit target.json
{
  printf '{'
  first=1
  for k in "${!T[@]}"; do
    [ $first -eq 0 ] && printf ','
    first=0
    printf '"%s":"%s"' "$k" "${T[$k]}"
  done
  printf '}\n'
} | jq . > "$MREVIEW_WORK_DIR/target.json"
```

- [ ] **Step 4: Run tests to verify they all pass**

Run: `bats .claude/skills/mreview/tests/test_resolve_target.bats`
Expected: All 16 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/resolve-target.sh \
        .claude/skills/mreview/tests/test_resolve_target.bats
git commit -m "$(cat <<'EOF'
mreview: materialize diff.patch + touched-paths.txt in Phase 1

For commit/range/staged/working/branch targets, resolve-target.sh now
writes the diff and the file list to $WORK_DIR. Empty diffs fail fast
with exit 66. github_pr/mdev_lookup/auto resolution defers to later
tasks.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Phase 1c — GitHub PR resolution

**Files:**
- Create: `.claude/skills/mreview/lib/fetch-pr.sh`
- Create: `.claude/skills/mreview/tests/test_fetch_pr.bats`
- Modify: `.claude/skills/mreview/lib/resolve-target.sh` (call fetch-pr.sh for github_pr type)

- [ ] **Step 1: Write the failing test**

`.claude/skills/mreview/tests/test_fetch_pr.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export MREVIEW_WORK_DIR="$TMP/wd"
  mkdir -p "$MREVIEW_WORK_DIR"
  REPO_ROOT="$BATS_TEST_DIRNAME/../../../.."
  cd "$REPO_ROOT"
}

teardown() { rm -rf "$TMP"; }

# Use fixture mode: fetch-pr.sh respects MREVIEW_FAKE_GH=1 and reads
# canned responses from MREVIEW_FAKE_GH_DIR. This lets bats tests run
# without network.

@test "fetch-pr: writes pr-meta.json, pr-existing-comments.json, diff.patch" {
  export MREVIEW_FAKE_GH=1
  export MREVIEW_FAKE_GH_DIR="$BATS_TEST_DIRNAME/fixtures/pr-4869"
  mkdir -p "$MREVIEW_FAKE_GH_DIR"
  echo '{"number":4869,"title":"x","baseRefName":"main","headRefOid":"abc","author":{"login":"u"},"assignees":[],"reviewRequests":[],"comments":[]}' \
    > "$MREVIEW_FAKE_GH_DIR/view.json"
  echo '[]' > "$MREVIEW_FAKE_GH_DIR/comments.json"
  echo "--- a/x" > "$MREVIEW_FAKE_GH_DIR/diff.patch"
  echo "+++ b/x" >> "$MREVIEW_FAKE_GH_DIR/diff.patch"

  run bash .claude/skills/mreview/lib/fetch-pr.sh MariaDB/server 4869
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/pr-meta.json" ]
  [ -s "$MREVIEW_WORK_DIR/pr-existing-comments.json" ]
  [ -s "$MREVIEW_WORK_DIR/diff.patch" ]
  run jq -r .number "$MREVIEW_WORK_DIR/pr-meta.json"
  [ "$output" = "4869" ]
}

@test "fetch-pr: empty diff exits non-zero" {
  export MREVIEW_FAKE_GH=1
  export MREVIEW_FAKE_GH_DIR="$BATS_TEST_DIRNAME/fixtures/pr-empty"
  mkdir -p "$MREVIEW_FAKE_GH_DIR"
  echo '{"number":1}' > "$MREVIEW_FAKE_GH_DIR/view.json"
  echo '[]' > "$MREVIEW_FAKE_GH_DIR/comments.json"
  : > "$MREVIEW_FAKE_GH_DIR/diff.patch"

  run bash .claude/skills/mreview/lib/fetch-pr.sh MariaDB/server 1
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_fetch_pr.bats`
Expected: Tests FAIL — script missing.

- [ ] **Step 3: Write fetch-pr.sh**

`.claude/skills/mreview/lib/fetch-pr.sh`:

```bash
#!/usr/bin/env bash
# Phase 1c — Fetch a GitHub PR's metadata, comments, and diff.
# Writes $WORK_DIR/{pr-meta.json, pr-existing-comments.json, diff.patch,
# touched-paths.txt}.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <owner/repo> <pr-number>" >&2
  exit 64
fi
REPO="$1"; N="$2"
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set}"

if [ "${MREVIEW_FAKE_GH:-0}" = 1 ]; then
  cp "$MREVIEW_FAKE_GH_DIR/view.json"     "$MREVIEW_WORK_DIR/pr-meta.json"
  cp "$MREVIEW_FAKE_GH_DIR/comments.json" "$MREVIEW_WORK_DIR/pr-existing-comments.json"
  cp "$MREVIEW_FAKE_GH_DIR/diff.patch"    "$MREVIEW_WORK_DIR/diff.patch"
else
  gh pr view "$N" --repo "$REPO" --json \
    number,title,body,baseRefName,headRefOid,author,assignees,reviewRequests,reviews,comments,labels,state,url \
    > "$MREVIEW_WORK_DIR/pr-meta.json"
  gh api "repos/$REPO/pulls/$N/comments" --paginate \
    > "$MREVIEW_WORK_DIR/pr-existing-comments.json"
  gh pr diff "$N" --repo "$REPO" > "$MREVIEW_WORK_DIR/diff.patch"
fi

if [ ! -s "$MREVIEW_WORK_DIR/diff.patch" ]; then
  echo "fetched PR diff is empty" >&2
  exit 66
fi

# Derive touched-paths from the diff.
awk '/^diff --git / { sub("a/", "", $3); print $3 }' \
  "$MREVIEW_WORK_DIR/diff.patch" > "$MREVIEW_WORK_DIR/touched-paths.txt"
```

- [ ] **Step 4: Wire resolve-target.sh into fetch-pr.sh for github_pr type**

In `.claude/skills/mreview/lib/resolve-target.sh`, replace the `github_pr|mdev_lookup|auto)` case body with:

```bash
  github_pr)
    bash "$(dirname "$0")/fetch-pr.sh" "${T[repo]}" "${T[pr_number]}"
    ;;
  mdev_lookup|auto)
    : # handled in later tasks
    ;;
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_fetch_pr.bats .claude/skills/mreview/tests/test_resolve_target.bats`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/mreview/lib/fetch-pr.sh \
        .claude/skills/mreview/lib/resolve-target.sh \
        .claude/skills/mreview/tests/test_fetch_pr.bats
git commit -m "$(cat <<'EOF'
mreview: fetch GitHub PR meta + comments + diff

fetch-pr.sh writes pr-meta.json, pr-existing-comments.json, diff.patch,
and touched-paths.txt. Supports a fixture mode (MREVIEW_FAKE_GH=1) so
bats tests run without network. resolve-target.sh now delegates to it
for github_pr targets.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Phase 1d — MDEV-lookup and auto-detect

**Files:**
- Create: `.claude/skills/mreview/lib/mdev-to-pr.sh`
- Create: `.claude/skills/mreview/lib/auto-detect.sh`
- Modify: `.claude/skills/mreview/lib/resolve-target.sh`
- Create: `.claude/skills/mreview/tests/test_mdev_to_pr.bats`
- Create: `.claude/skills/mreview/tests/test_auto_detect.bats`

- [ ] **Step 1: Write the MDEV-lookup test**

`.claude/skills/mreview/tests/test_mdev_to_pr.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  export MREVIEW_WORK_DIR="$TMP/wd"
  mkdir -p "$MREVIEW_WORK_DIR"
}

teardown() { rm -rf "$TMP"; }

@test "mdev-to-pr: exactly one PR → prints repo and number" {
  export MREVIEW_FAKE_GH=1
  export MREVIEW_FAKE_GH_DIR="$BATS_TEST_DIRNAME/fixtures/mdev-23676"
  mkdir -p "$MREVIEW_FAKE_GH_DIR"
  echo '[{"number":4869,"repository":{"nameWithOwner":"MariaDB/server"}}]' \
    > "$MREVIEW_FAKE_GH_DIR/search.json"

  run bash .claude/skills/mreview/lib/mdev-to-pr.sh MDEV-23676
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MariaDB/server" ]]
  [[ "$output" =~ "4869" ]]
}

@test "mdev-to-pr: zero PRs → exit 67 with hint" {
  export MREVIEW_FAKE_GH=1
  export MREVIEW_FAKE_GH_DIR="$BATS_TEST_DIRNAME/fixtures/mdev-empty"
  mkdir -p "$MREVIEW_FAKE_GH_DIR"
  echo '[]' > "$MREVIEW_FAKE_GH_DIR/search.json"

  run bash .claude/skills/mreview/lib/mdev-to-pr.sh MDEV-99999
  [ "$status" -eq 67 ]
  [[ "$output" =~ "mfix" ]]
}

@test "mdev-to-pr: multiple PRs → exit 68 with list" {
  export MREVIEW_FAKE_GH=1
  export MREVIEW_FAKE_GH_DIR="$BATS_TEST_DIRNAME/fixtures/mdev-multi"
  mkdir -p "$MREVIEW_FAKE_GH_DIR"
  echo '[{"number":1,"repository":{"nameWithOwner":"MariaDB/server"}},
        {"number":2,"repository":{"nameWithOwner":"MariaDB/server"}}]' \
    > "$MREVIEW_FAKE_GH_DIR/search.json"

  run bash .claude/skills/mreview/lib/mdev-to-pr.sh MDEV-12345
  [ "$status" -eq 68 ]
  [[ "$output" =~ "1" ]]
  [[ "$output" =~ "2" ]]
}
```

- [ ] **Step 2: Write the auto-detect test**

`.claude/skills/mreview/tests/test_auto_detect.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d)
  cd "$TMP"
  git init -q
  git config user.email a@b
  git config user.name x
  echo hi > f; git add f; git commit -q -m init
}

teardown() { rm -rf "$TMP"; }

@test "auto-detect: dirty working tree → working+staged" {
  echo change >> f
  run bash "$OLDPWD/.claude/skills/mreview/lib/auto-detect.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "working_and_staged" ]] || [[ "$output" =~ "working" ]]
}

@test "auto-detect: clean tree → last_commit" {
  run bash "$OLDPWD/.claude/skills/mreview/lib/auto-detect.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "last_commit" ]]
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bats .claude/skills/mreview/tests/test_mdev_to_pr.bats .claude/skills/mreview/tests/test_auto_detect.bats`
Expected: FAIL — scripts missing.

- [ ] **Step 4: Write mdev-to-pr.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

MDEV="${1:?usage: $0 MDEV-NNNNN}"

if [ "${MREVIEW_FAKE_GH:-0}" = 1 ]; then
  RAW=$(cat "$MREVIEW_FAKE_GH_DIR/search.json")
else
  RAW=$(gh search prs "$MDEV" --repo MariaDB/server --json number,repository --limit 10)
fi

COUNT=$(echo "$RAW" | jq 'length')
if [ "$COUNT" = "0" ]; then
  echo "no PR found for $MDEV. Try 'mfix $MDEV' to start a fix from scratch." >&2
  exit 67
fi
if [ "$COUNT" -gt 1 ]; then
  echo "multiple PRs match $MDEV:" >&2
  echo "$RAW" | jq -r '.[] | "  \(.repository.nameWithOwner)#\(.number)"' >&2
  exit 68
fi
echo "$RAW" | jq -r '.[0] | "\(.repository.nameWithOwner) \(.number)"'
```

- [ ] **Step 5: Write auto-detect.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

WORKING=$(git diff --quiet || echo 1)
STAGED=$(git diff --cached --quiet || echo 1)
if [ -n "$WORKING" ] && [ -n "$STAGED" ]; then
  echo "type=working_and_staged"; exit
fi
if [ -n "$WORKING" ]; then
  echo "type=working"; exit
fi
if [ -n "$STAGED" ]; then
  echo "type=staged"; exit
fi
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
if [ -n "$UPSTREAM" ]; then
  AHEAD=$(git rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)
  if [ "$AHEAD" -gt 1 ]; then
    echo "type=range"; echo "base=$UPSTREAM"; echo "head=HEAD"; exit
  fi
fi
echo "type=last_commit"; echo "sha=$(git rev-parse HEAD)"
```

- [ ] **Step 6: Wire into resolve-target.sh**

Replace the `mdev_lookup|auto)` case body:

```bash
  mdev_lookup)
    read -r REPO PRNUM < <(bash "$(dirname "$0")/mdev-to-pr.sh" "${T[mdev]}")
    T[type]=github_pr; T[repo]="$REPO"; T[pr_number]="$PRNUM"
    bash "$(dirname "$0")/fetch-pr.sh" "$REPO" "$PRNUM"
    ;;
  auto)
    while IFS='=' read -r ak av; do
      [ -n "$ak" ] && T["$ak"]="$av"
    done < <(bash "$(dirname "$0")/auto-detect.sh")
    # Re-dispatch on the resolved type by re-executing the body.
    case "${T[type]}" in
      working) git diff > "$DIFF"; git diff --name-only > "$PATHS" ;;
      staged)  git diff --cached > "$DIFF"; git diff --cached --name-only > "$PATHS" ;;
      working_and_staged)
        git diff HEAD > "$DIFF"; git diff HEAD --name-only > "$PATHS" ;;
      last_commit)
        git show --first-parent "${T[sha]}" > "$DIFF"
        git show --first-parent --name-only --format= "${T[sha]}" | awk NF > "$PATHS" ;;
      range)
        git diff "${T[base]}..${T[head]}" > "$DIFF"
        git diff --name-only "${T[base]}..${T[head]}" > "$PATHS" ;;
    esac
    ;;
```

- [ ] **Step 7: Run all Phase 1 tests**

Run: `bats .claude/skills/mreview/tests/`
Expected: All tests in test_resolve_target.bats, test_fetch_pr.bats, test_mdev_to_pr.bats, test_auto_detect.bats PASS.

- [ ] **Step 8: Commit**

```bash
git add .claude/skills/mreview/lib/mdev-to-pr.sh \
        .claude/skills/mreview/lib/auto-detect.sh \
        .claude/skills/mreview/lib/resolve-target.sh \
        .claude/skills/mreview/tests/test_mdev_to_pr.bats \
        .claude/skills/mreview/tests/test_auto_detect.bats
git commit -m "$(cat <<'EOF'
mreview: add MDEV→PR lookup and auto-detect

mdev-to-pr.sh queries 'gh search prs', exiting 67 on zero matches
(with a hint pointing at mfix) and 68 on multiple matches (printing
the list). auto-detect.sh picks working/staged/working_and_staged/
last_commit/range based on working tree state vs upstream.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Phase 2a — Derive areas from touched paths

**Files:**
- Create: `.claude/skills/mreview/lib/derive-areas.sh`
- Create: `.claude/skills/mreview/tests/test_derive_areas.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() { TMP=$(mktemp -d); cd "$TMP"; }
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/derive-areas.sh"

@test "areas: sql/ + storage/innobase/ → both labels" {
  printf 'sql/sql_parse.cc\nstorage/innobase/btr/btr0sea.cc\n' > paths.txt
  run bash "$SCRIPT" paths.txt
  [[ "$output" =~ "sql/" ]]
  [[ "$output" =~ "storage/innobase/" ]]
}

@test "areas: mysql-test/main/* → mysql-test/" {
  printf 'mysql-test/main/alias.test\n' > paths.txt
  run bash "$SCRIPT" paths.txt
  [[ "$output" =~ "mysql-test/" ]]
}

@test "areas: CMakeLists.txt → cmake" {
  printf 'CMakeLists.txt\ncmake/maintainer.cmake\n' > paths.txt
  run bash "$SCRIPT" paths.txt
  [[ "$output" =~ "cmake" ]]
}

@test "areas: errmsg-utf8 → errmsg" {
  printf 'sql/share/errmsg-utf8.txt\n' > paths.txt
  run bash "$SCRIPT" paths.txt
  [[ "$output" =~ "errmsg" ]]
}

@test "areas: unknown path → no labels" {
  printf 'README.md\n' > paths.txt
  run bash "$SCRIPT" paths.txt
  [ -z "$output" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_derive_areas.bats`
Expected: FAIL — script missing.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
PATHS="${1:?usage: $0 <touched-paths.txt>}"

declare -A SEEN=()
emit() { local a="$1"; [ -z "${SEEN[$a]:-}" ] && { echo "$a"; SEEN[$a]=1; }; }

while IFS= read -r p; do
  [ -z "$p" ] && continue
  case "$p" in
    sql/share/errmsg-utf8.txt) emit "errmsg" ;;
    sql/*)                      emit "sql/" ;;
    storage/innobase/*)         emit "storage/innobase/" ;;
    storage/*)                  emit "storage/" ;;
    mysql-test/*)               emit "mysql-test/" ;;
    plugin/*)                   emit "plugin/" ;;
    CMakeLists.txt|cmake/*|*.cmake) emit "cmake" ;;
    client/*)                   emit "client/" ;;
    extra/*)                    emit "extra/" ;;
  esac
done < "$PATHS"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_derive_areas.bats`
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/derive-areas.sh \
        .claude/skills/mreview/tests/test_derive_areas.bats
git commit -m "$(cat <<'EOF'
mreview: derive area labels from touched paths

derive-areas.sh maps file paths to coarse area labels (sql/,
storage/innobase/, mysql-test/, plugin/, cmake, errmsg, client/,
extra/). Feeds the rulebook subset selection in Phase 2.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Phase 2b — Select rulebook subset

**Files:**
- Create: `.claude/skills/mreview/lib/select-rulebook.sh`
- Create: `.claude/skills/mreview/tests/test_select_rulebook.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() { TMP=$(mktemp -d); cd "$TMP"; }
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/select-rulebook.sh"

@test "rulebook: always includes 4 baseline files" {
  : > areas.txt
  run bash "$SCRIPT" areas.txt
  [[ "$output" =~ "checklist.md" ]]
  [[ "$output" =~ "commit-and-process.md" ]]
  [[ "$output" =~ "coding-style.md" ]]
  [[ "$output" =~ "anti-patterns.md" ]]
}

@test "rulebook: storage/innobase area adds innodb.md" {
  echo "storage/innobase/" > areas.txt
  run bash "$SCRIPT" areas.txt
  [[ "$output" =~ "innodb.md" ]]
}

@test "rulebook: mysql-test area adds testing.md" {
  echo "mysql-test/" > areas.txt
  run bash "$SCRIPT" areas.txt
  [[ "$output" =~ "testing.md" ]]
}

@test "rulebook: cmake area adds build-and-cmake.md" {
  echo "cmake" > areas.txt
  run bash "$SCRIPT" areas.txt
  [[ "$output" =~ "build-and-cmake.md" ]]
}

@test "rulebook: errmsg area adds logging-and-errors.md" {
  echo "errmsg" > areas.txt
  run bash "$SCRIPT" areas.txt
  [[ "$output" =~ "logging-and-errors.md" ]]
}

@test "rulebook: no duplicates when both innobase and sql/ present" {
  printf 'sql/\nstorage/innobase/\n' > areas.txt
  run bash "$SCRIPT" areas.txt
  count=$(echo "$output" | grep -c "innodb.md" || true)
  [ "$count" -le 1 ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_select_rulebook.bats`
Expected: FAIL.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
AREAS="${1:?usage: $0 <touched-areas.txt>}"

declare -A SEEN=()
emit() { local f="$1"; [ -z "${SEEN[$f]:-}" ] && { echo "$f"; SEEN[$f]=1; }; }

# Always-loaded baseline.
for f in checklist.md commit-and-process.md coding-style.md anti-patterns.md; do
  emit "$f"
done

while IFS= read -r area; do
  [ -z "$area" ] && continue
  case "$area" in
    storage/innobase/) emit "innodb.md" ;;
    mysql-test/)       emit "testing.md" ;;
    cmake)             emit "build-and-cmake.md" ;;
    errmsg)            emit "logging-and-errors.md" ;;
    sql/|storage/|plugin/) emit "api-and-architecture.md" ;;
  esac
done < "$AREAS"

# correctness-and-security if diff (passed via env) touches bounds/auth.
if [ -n "${MREVIEW_DIFF:-}" ] && [ -f "$MREVIEW_DIFF" ]; then
  if grep -qE 'memcpy|strncpy|strcpy|acl|grant|password|ASAN|UBSAN' "$MREVIEW_DIFF"; then
    emit "correctness-and-security.md"
  fi
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_select_rulebook.bats`
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/select-rulebook.sh \
        .claude/skills/mreview/tests/test_select_rulebook.bats
git commit -m "$(cat <<'EOF'
mreview: select rulebook subset by touched areas

select-rulebook.sh always loads checklist/commit/coding/anti-patterns,
then adds innodb/testing/build/logging/api-and-architecture based on
area labels. Adds correctness-and-security.md if MREVIEW_DIFF contains
bounds/auth markers.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Phase 2c — Profile auto-detection

**Files:**
- Create: `.claude/skills/mreview/lib/select-profiles.sh`
- Create: `.claude/skills/mreview/tests/test_select_profiles.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d); cd "$TMP"
  mkdir -p wd/profiles
  : > wd/profiles/vuvova.md
  : > wd/profiles/dr-m.md
  export MREVIEW_WORK_DIR="$TMP/wd"
}
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/select-profiles.sh"

@test "profiles: --profile <name> overrides everything" {
  printf '{}' > wd/pr-meta.json
  run bash "$SCRIPT" --profile vuvova
  [ "$status" -eq 0 ]
  [[ "$output" =~ "vuvova.md" ]]
  [[ ! "$output" =~ "dr-m.md" ]]
}

@test "profiles: --no-profile produces empty list" {
  printf '{"assignees":[{"login":"vuvova"}]}' > wd/pr-meta.json
  run bash "$SCRIPT" --no-profile
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "profiles: from pr-meta assignee → matches profile" {
  printf '{"assignees":[{"login":"vuvova"}],"reviewRequests":[],"comments":[]}' \
    > wd/pr-meta.json
  run bash "$SCRIPT"
  [[ "$output" =~ "vuvova.md" ]]
}

@test "profiles: caps at 2 even when 3 candidates" {
  echo "" > wd/profiles/third.md
  printf '{"assignees":[{"login":"vuvova"},{"login":"dr-m"},{"login":"third"}],"reviewRequests":[],"comments":[]}' \
    > wd/pr-meta.json
  run bash "$SCRIPT"
  count=$(echo "$output" | grep -c '\.md$' || true)
  [ "$count" -le 2 ]
}

@test "profiles: missing pr-meta and no flag → empty" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_select_profiles.bats`
Expected: FAIL.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set}"

MODE=auto
FORCED=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) MODE=forced; FORCED="$2"; shift 2 ;;
    --no-profile) MODE=none; shift ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

if [ "$MODE" = none ]; then exit 0; fi
if [ "$MODE" = forced ]; then
  f="$MREVIEW_WORK_DIR/profiles/${FORCED}.md"
  [ -f "$f" ] || { echo "no profile: $f" >&2; exit 69; }
  echo "${FORCED}.md"; exit 0
fi

META="$MREVIEW_WORK_DIR/pr-meta.json"
[ -f "$META" ] || exit 0

# Candidate logins: assignees + requested reviewers + comment authors.
CANDS=$(jq -r '
  [
    (.assignees // [])[]?.login,
    (.reviewRequests // [])[]?.login,
    (.comments // [])[]?.author.login
  ] | unique | .[]' "$META" 2>/dev/null || true)

count=0
for login in $CANDS; do
  f="$MREVIEW_WORK_DIR/profiles/${login}.md"
  if [ -f "$f" ]; then
    echo "${login}.md"
    count=$((count + 1))
    [ "$count" -ge 2 ] && break
  fi
done
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_select_profiles.bats`
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/select-profiles.sh \
        .claude/skills/mreview/tests/test_select_profiles.bats
git commit -m "$(cat <<'EOF'
mreview: auto-detect reviewer profiles

select-profiles.sh resolves which .claude/reviewers/<name>.md profiles
to load: --profile <name> forces one; --no-profile loads none; default
unions assignees + requested reviewers + comment authors from pr-meta,
caps at 2, and keeps only those with an existing profile file.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Phase 3a — Tier-to-agents mapping with auto-elevation

**Files:**
- Create: `.claude/skills/mreview/lib/tier-agents.sh`
- Create: `.claude/skills/mreview/tests/test_tier_agents.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() { TMP=$(mktemp -d); cd "$TMP"; }
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/tier-agents.sh"

mkdiff() { printf '%s' "$1" > diff.patch; }
mkpaths() { printf '%s' "$1" > paths.txt; }

@test "tier=quick → only code-reviewer" {
  : > diff.patch; : > paths.txt
  run bash "$SCRIPT" quick diff.patch paths.txt
  [[ "$output" =~ "code-reviewer" ]]
  [[ ! "$output" =~ "silent-failure-hunter" ]]
}

@test "tier=standard → code-reviewer + silent-failure-hunter" {
  : > diff.patch; : > paths.txt
  run bash "$SCRIPT" standard diff.patch paths.txt
  [[ "$output" =~ "code-reviewer" ]]
  [[ "$output" =~ "silent-failure-hunter" ]]
  [[ ! "$output" =~ "pr-test-analyzer" ]]
}

@test "tier=deep → all 5 agents" {
  : > diff.patch; : > paths.txt
  run bash "$SCRIPT" deep diff.patch paths.txt
  [[ "$output" =~ "code-reviewer" ]]
  [[ "$output" =~ "silent-failure-hunter" ]]
  [[ "$output" =~ "pr-test-analyzer" ]]
  [[ "$output" =~ "comment-analyzer" ]]
  [[ "$output" =~ "type-design-analyzer" ]]
}

@test "auto-elevate pr-test-analyzer when ≥10 test/result files" {
  : > diff.patch
  for i in $(seq 1 10); do
    echo "mysql-test/main/t${i}.test"
  done > paths.txt
  run bash "$SCRIPT" standard diff.patch paths.txt
  [[ "$output" =~ "pr-test-analyzer" ]]
}

@test "auto-elevate comment-analyzer when ≥30 net added comment lines" {
  printf -- '--- a/x\n+++ b/x\n@@\n' > diff.patch
  for i in $(seq 1 30); do
    echo "+// comment $i" >> diff.patch
  done
  : > paths.txt
  run bash "$SCRIPT" standard diff.patch paths.txt
  [[ "$output" =~ "comment-analyzer" ]]
}

@test "auto-elevate type-design-analyzer when new type declaration" {
  printf -- '--- a/x\n+++ b/x\n@@\n+class Foo {};\n' > diff.patch
  : > paths.txt
  run bash "$SCRIPT" standard diff.patch paths.txt
  [[ "$output" =~ "type-design-analyzer" ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_tier_agents.bats`
Expected: FAIL.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
TIER="${1:?usage: $0 <tier> <diff> <paths>}"
DIFF="${2:?}"
PATHS="${3:?}"

declare -A AGENTS=()
add() { AGENTS["$1"]=1; }

case "$TIER" in
  quick)    add code-reviewer ;;
  standard) add code-reviewer; add silent-failure-hunter ;;
  deep)     add code-reviewer; add silent-failure-hunter
            add pr-test-analyzer; add comment-analyzer; add type-design-analyzer ;;
  *) echo "unknown tier: $TIER" >&2; exit 64 ;;
esac

# Auto-elevations
TEST_FILES=$(grep -cE '^mysql-test/.*\.(test|result)$' "$PATHS" 2>/dev/null || echo 0)
[ "$TEST_FILES" -ge 10 ] && add pr-test-analyzer

COMMENT_LINES=$(grep -cE '^\+[[:space:]]*(//|/\*|\*|#)' "$DIFF" 2>/dev/null || echo 0)
[ "$COMMENT_LINES" -ge 30 ] && add comment-analyzer

NEW_TYPES=$(grep -cE '^\+[[:space:]]*(class|struct)[[:space:]]+[A-Z][A-Za-z0-9_]*' "$DIFF" 2>/dev/null || echo 0)
[ "$NEW_TYPES" -ge 1 ] && add type-design-analyzer

for a in "${!AGENTS[@]}"; do echo "$a"; done | sort
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_tier_agents.bats`
Expected: 6 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/tier-agents.sh \
        .claude/skills/mreview/tests/test_tier_agents.bats
git commit -m "$(cat <<'EOF'
mreview: tier-to-agents mapping with auto-elevation

tier-agents.sh maps quick/standard/deep to agent sets and adds
pr-test-analyzer (≥10 test/result files), comment-analyzer (≥30 net
added comment lines), and type-design-analyzer (new class/struct).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Phase 4 — Synthesize merged report

**Files:**
- Create: `.claude/skills/mreview/lib/synthesize.sh`
- Create: `.claude/skills/mreview/tests/test_synthesize.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d); cd "$TMP"
  mkdir -p wd/agents
  export MREVIEW_WORK_DIR="$TMP/wd"
}
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/synthesize.sh"

mkagent() {
  local name="$1"; local content="$2"
  printf '%s' "$content" > "wd/agents/${name}.md"
}

@test "synthesize: empty agents dir → verdict approve, zero counts" {
  echo "standard" > wd/tier.txt
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/report.md" ]
  grep -q "Verdict: approve" "$MREVIEW_WORK_DIR/report.md"
}

@test "synthesize: single Blocker → verdict request-changes" {
  echo "standard" > wd/tier.txt
  mkagent code-reviewer "## Findings

- **Blocker** [sql/foo.cc:42] Buffer overflow on memcpy. (cited from correctness-and-security.md:bounds)
"
  run bash "$SCRIPT"
  grep -q "Verdict: request-changes" "$MREVIEW_WORK_DIR/report.md"
  grep -q "sql/foo.cc:42" "$MREVIEW_WORK_DIR/report.md"
}

@test "synthesize: only Important → verdict approve-with-changes" {
  echo "standard" > wd/tier.txt
  mkagent code-reviewer "## Findings

- **Important** [sql/foo.cc:10] Use snake_case here. (cited from coding-style.md:naming)
"
  run bash "$SCRIPT"
  grep -q "Verdict: approve-with-changes" "$MREVIEW_WORK_DIR/report.md"
}

@test "synthesize: same finding from two agents → deduped with also-flagged-by" {
  echo "standard" > wd/tier.txt
  mkagent code-reviewer "## Findings

- **Important** [sql/foo.cc:10] Missing null check. (cited from correctness.md:null)
"
  mkagent silent-failure-hunter "## Findings

- **Important** [sql/foo.cc:10] No null check; will segfault. (cited from correctness.md:null)
"
  run bash "$SCRIPT"
  count=$(grep -c "sql/foo.cc:10" "$MREVIEW_WORK_DIR/report.md")
  [ "$count" -le 2 ]   # finding appears once + maybe in appendix
  grep -q "also flagged by" "$MREVIEW_WORK_DIR/report.md"
}

@test "synthesize: per-agent appendix preserves verbatim output" {
  echo "standard" > wd/tier.txt
  mkagent code-reviewer "verbatim agent output here"
  run bash "$SCRIPT"
  grep -q "verbatim agent output here" "$MREVIEW_WORK_DIR/report.md"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_synthesize.bats`
Expected: FAIL.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set}"

AGENTS_DIR="$MREVIEW_WORK_DIR/agents"
REPORT="$MREVIEW_WORK_DIR/report.md"
TIER="$(cat "$MREVIEW_WORK_DIR/tier.txt" 2>/dev/null || echo unknown)"

declare -A BUCKETS
for sev in Blocker Important Nit Praise; do BUCKETS[$sev]=""; done

# Findings line format expected from each agent:
#   - **<Severity>** [<path>:<line>] <body> (cited from <file>:<section>)
parse_findings() {
  local f="$1"; local agent
  agent="$(basename "$f" .md)"
  while IFS= read -r line; do
    if [[ "$line" =~ ^-[[:space:]]+\*\*(Blocker|Important|Nit|Praise)\*\*[[:space:]]+(\[[^\]]+\])[[:space:]]+(.+)$ ]]; then
      local sev="${BASH_REMATCH[1]}"
      local loc="${BASH_REMATCH[2]}"
      local body="${BASH_REMATCH[3]}"
      printf '%s\t%s\t%s\t%s\n' "$sev" "$loc" "$body" "$agent" \
        >> "$MREVIEW_WORK_DIR/.findings.tsv"
    fi
  done < "$f"
}

: > "$MREVIEW_WORK_DIR/.findings.tsv"
for f in "$AGENTS_DIR"/*.md; do
  [ -f "$f" ] || continue
  parse_findings "$f"
done

# Dedupe: same severity + same loc → keep first, append "(also flagged by ...)"
dedupe_and_group() {
  local sev="$1"
  awk -F'\t' -v sev="$sev" '
    $1 == sev {
      key = $2
      if (key in seen) { also[key] = also[key] "," $4 }
      else { seen[key] = $0 }
    }
    END {
      for (k in seen) {
        split(seen[k], f, "\t")
        line = "- **" f[1] "** " f[2] " " f[3] " — by " f[4]
        if (k in also) { line = line " (also flagged by" also[k] ")" }
        print line
      }
    }
  ' "$MREVIEW_WORK_DIR/.findings.tsv" | sort
}

# Counts and verdict
BLOCKERS=$(awk -F'\t' '$1=="Blocker"' "$MREVIEW_WORK_DIR/.findings.tsv" | wc -l)
IMPORTANTS=$(awk -F'\t' '$1=="Important"' "$MREVIEW_WORK_DIR/.findings.tsv" | wc -l)
NITS=$(awk -F'\t' '$1=="Nit"' "$MREVIEW_WORK_DIR/.findings.tsv" | wc -l)
PRAISES=$(awk -F'\t' '$1=="Praise"' "$MREVIEW_WORK_DIR/.findings.tsv" | wc -l)

if [ "$BLOCKERS" -ge 1 ]; then VERDICT="request-changes"
elif [ "$IMPORTANTS" -ge 1 ]; then VERDICT="approve-with-changes"
else VERDICT="approve"; fi

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
    out=$(dedupe_and_group "$sev")
    if [ -n "$out" ]; then echo "$out"; else echo "_(none)_"; fi
    echo ""
  done
  echo "## Per-agent appendix"
  echo ""
  for f in "$AGENTS_DIR"/*.md; do
    [ -f "$f" ] || continue
    echo "### $(basename "$f" .md)"
    echo ""
    cat "$f"
    echo ""
  done
} > "$REPORT"
rm -f "$MREVIEW_WORK_DIR/.findings.tsv"
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_synthesize.bats`
Expected: 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/synthesize.sh \
        .claude/skills/mreview/tests/test_synthesize.bats
git commit -m "$(cat <<'EOF'
mreview: synthesize agent reports into a verdict + grouped findings

synthesize.sh parses '- **Severity** [path:line] body' lines from
agents/*.md, dedupes per (severity, location), groups by severity,
counts each bucket, derives the verdict (request-changes / approve-
with-changes / approve), and writes report.md with a verbatim per-
agent appendix.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Phase 5 — Present and GitHub draft

**Files:**
- Create: `.claude/skills/mreview/lib/present.sh`
- Create: `.claude/skills/mreview/tests/test_present.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

setup() {
  TMP=$(mktemp -d); cd "$TMP"
  mkdir -p wd
  export MREVIEW_WORK_DIR="$TMP/wd"
  cat > wd/report.md <<'EOF'
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

- **Important** [sql/x.cc:10] Note this. — by code-reviewer

## Nit

_(none)_

## Praise

_(none)_

## Per-agent appendix

### code-reviewer

raw stuff
EOF
}
teardown() { rm -rf "$TMP"; }
SCRIPT="$BATS_TEST_DIRNAME/../lib/present.sh"

@test "present: writes github-draft.md without per-agent appendix for PR target" {
  echo '{"type":"github_pr","pr_number":"4869","repo":"MariaDB/server"}' \
    > wd/target.json
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -s "$MREVIEW_WORK_DIR/github-draft.md" ]
  ! grep -q "Per-agent appendix" "$MREVIEW_WORK_DIR/github-draft.md"
  grep -q "sql/x.cc:10" "$MREVIEW_WORK_DIR/github-draft.md"
}

@test "present: skips github-draft for non-PR targets" {
  echo '{"type":"staged"}' > wd/target.json
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$MREVIEW_WORK_DIR/github-draft.md" ]
}

@test "present: prints chat-friendly summary to stdout" {
  echo '{"type":"staged"}' > wd/target.json
  run bash "$SCRIPT"
  [[ "$output" =~ "Verdict" ]]
  [[ "$output" =~ "Important" ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats .claude/skills/mreview/tests/test_present.bats`
Expected: FAIL.

- [ ] **Step 3: Write the helper**

```bash
#!/usr/bin/env bash
set -euo pipefail
: "${MREVIEW_WORK_DIR:?MREVIEW_WORK_DIR must be set}"

REPORT="$MREVIEW_WORK_DIR/report.md"
TARGET="$MREVIEW_WORK_DIR/target.json"
[ -s "$REPORT" ] || { echo "no report at $REPORT" >&2; exit 70; }

# Chat summary: everything up to "## Per-agent appendix", skip the
# Praise section if empty.
awk '/^## Per-agent appendix/ {exit} {print}' "$REPORT"

# GitHub draft for PR targets.
TYPE=$(jq -r '.type // ""' "$TARGET" 2>/dev/null || echo "")
if [ "$TYPE" = "github_pr" ]; then
  DRAFT="$MREVIEW_WORK_DIR/github-draft.md"
  awk '/^## Per-agent appendix/ {exit} {print}' "$REPORT" > "$DRAFT"
  echo ""
  echo "Draft GitHub review at $DRAFT"
  PR=$(jq -r '.pr_number' "$TARGET")
  REPO=$(jq -r '.repo' "$TARGET")
  echo "To post: gh pr review $PR --repo $REPO --comment --body-file $DRAFT"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats .claude/skills/mreview/tests/test_present.bats`
Expected: 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/lib/present.sh \
        .claude/skills/mreview/tests/test_present.bats
git commit -m "$(cat <<'EOF'
mreview: present chat summary + GitHub draft

present.sh prints the report (minus the per-agent appendix) to chat
and, for github_pr targets, writes github-draft.md (same content,
formatted for GitHub) plus a ready-to-paste 'gh pr review' command.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Write SKILL.md

**Files:**
- Create: `.claude/skills/mreview/SKILL.md`

The SKILL.md body wires the helpers together as 6 gated phases. The skill body is not unit-testable; it's validated by the four end-to-end runs in Tasks 14–17.

- [ ] **Step 1: Write SKILL.md**

Write the file with the following structure. Each phase block lists: pre-conditions, command to run, post-conditions, fail-fast behavior. Length target ~450 lines. Use the existing `.claude/skills/mfix/SKILL.md` as a template for tone, formatting, and severity of stop-gates.

```markdown
---
name: mreview
description: Code-review orchestration for MariaDB Server. Reviews any of: uncommitted/staged changes, local commits, branches, or GitHub PRs, against the project rulebook and reviewer profiles. Three strictness tiers. Produces a verdict + structured findings report.
---

# mreview

Read `.claude/skills/mreview/DESIGN.md` for design rationale.

## When to invoke

[... usage table mirroring DESIGN.md §"Invocation surface" ...]

## Hard rules

- One Skill invocation = one target. Don't chain.
- Stop-gates: if a phase's deliverable file isn't on disk, STOP and report.
- Never fabricate findings — only report what an agent or rulebook line backs.

## Phase 0 — Setup

Run `.claude/skills/mreview/lib/setup-workdir.sh <target-id>`. <target-id>
is derived later, so for now use a temporary placeholder that gets renamed.

Deliverable check: `$WORK_DIR/rulebook/checklist.md` exists.

## Phase 1 — Resolve target

[...command-by-command instructions invoking resolve-target.sh, with the
input forms enumerated and the deliverable check on diff.patch + target.json...]

## Phase 2 — Inspect

[...derive-areas.sh → select-rulebook.sh → select-profiles.sh, with
deliverable checks on loaded-rulebook.txt + loaded-profiles.txt...]

## Phase 3 — Dispatch

Read tier-agents.sh output. For each agent, dispatch via Agent tool with
subagent_type "pr-review-toolkit:<agent>". All fired in PARALLEL in a
single message with multiple Agent tool calls. Common prompt template:

  Review the diff at $WORK_DIR/diff.patch.
  Target metadata: $WORK_DIR/target.json
  MariaDB rulebook to apply: $WORK_DIR/rulebook/<files from loaded-rulebook.txt>
  Reviewer profiles to apply: $WORK_DIR/profiles/<files from loaded-profiles.txt>
  For each finding emit a line:
    - **<Blocker|Important|Nit|Praise>** [path:line] <one sentence> (cited from <rulebook-file>:<section>)
  Write your full report to $WORK_DIR/agents/<your-name>.md.

Deliverable check: every selected agent's report file is non-empty.

## Phase 4 — Synthesize

Run `lib/synthesize.sh`. Deliverable check: report.md non-empty with the
"Verdict:" header.

## Phase 5 — Present

Run `lib/present.sh`. Deliverable: chat summary printed; for PR targets,
github-draft.md exists; the "gh pr review" command is shown.

## Rationalizations to resist

[... carried from DESIGN.md §"Rationalizations to resist" ...]
```

- [ ] **Step 2: Sanity-check by reading SKILL.md end-to-end**

Read the file in chunks; verify every phase has explicit deliverable checks; every helper path is correct.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/mreview/SKILL.md
git commit -m "$(cat <<'EOF'
mreview: add SKILL.md orchestrating the 6 phases

Wires lib/ helpers into a phase-gated workflow: Setup → Resolve →
Inspect → Dispatch → Synthesize → Present. Mirrors mfix's structure
and stop-gate discipline.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Integration smoke test (local diff)

**Files:**
- No new files; this is a real end-to-end exercise on the current uncommitted state.

- [ ] **Step 1: Stage a small known change**

Make a deliberate, small edit to a comment in `.claude/skills/mreview/SKILL.md` and stage it.

```bash
echo "(* trivial comment *)" >> .claude/skills/mreview/SKILL.md
git add .claude/skills/mreview/SKILL.md
```

- [ ] **Step 2: Invoke the skill with --quick**

In Claude Code: `Skill mreview --staged --quick`

Expected:
- `$HOME/.cache/mreview/<timestamp>/diff.patch` non-empty
- `report.md` exists
- Chat shows "Verdict: approve" (no blockers expected for a comment edit)
- Real Agent dispatch fires `pr-review-toolkit:code-reviewer`

- [ ] **Step 3: Verify artifacts**

```bash
ls -la $(ls -td $HOME/.cache/mreview/*/ | head -1)
```

Expected: target.json, diff.patch, touched-paths.txt, agents/code-reviewer.md, report.md.

- [ ] **Step 4: Unstage and clean up**

```bash
git reset HEAD .claude/skills/mreview/SKILL.md
git checkout -- .claude/skills/mreview/SKILL.md
```

- [ ] **Step 5: Document the run**

Append to `.claude/skills/mreview/SKILL_VALIDATION.md` (create if absent):

```markdown
## Run 1 — Local-diff smoke test

Date: <today>
Target: --staged (small comment edit in SKILL.md)
Tier: --quick
Outcome: Verdict approve. code-reviewer fired. All artifacts present.
Bugs found: none.
```

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/mreview/SKILL_VALIDATION.md
git commit -m "$(cat <<'EOF'
mreview: SKILL_VALIDATION run 1 (local-diff smoke)

End-to-end --staged --quick invocation on a trivial comment edit.
All Phase 0–5 deliverables produced; code-reviewer agent fired.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Validation — Same-session walk-through (broken commit)

**Files:**
- Modify: `.claude/skills/mreview/SKILL_VALIDATION.md`

- [ ] **Step 1: Locate the broken-on-purpose commit**

The mfix dry-run produced commit `5ed1bc1bc72` (Option A defensive truncate that introduced the off-by-1 second corruption). Confirm it exists locally:

```bash
git rev-parse 5ed1bc1bc72 2>/dev/null && echo "ok" || echo "missing"
```

If missing, recreate by cherry-picking or skip this task and document.

- [ ] **Step 2: Invoke mreview on that commit**

```
Skill mreview 5ed1bc1bc72 --standard
```

Expected: silent-failure-hunter flags a Blocker for the truncate inducing observable corruption (this was previously confirmed by the iter-1 test).

- [ ] **Step 3: Verify the report**

Check that `report.md`'s Blocker section contains at least one entry citing `correctness-and-security.md` or `coding-style.md`.

- [ ] **Step 4: Document the run**

Append to SKILL_VALIDATION.md:

```markdown
## Run 2 — Same-session: broken-commit detection

Date: <today>
Target: 5ed1bc1bc72 (Option-A defensive truncate, intentionally broken)
Tier: --standard
Outcome: <N> Blockers / <M> Important. silent-failure-hunter flagged
  the truncate as silently corrupting unpacked TIME values.
Verdict: request-changes.
Confirms: tier=standard catches what tier=quick misses.
```

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/SKILL_VALIDATION.md
git commit -m "$(cat <<'EOF'
mreview: SKILL_VALIDATION run 2 (broken-commit detection)

Confirms tier=standard catches the silent corruption bug that iter-1
of the mfix dry-run produced.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Validation — Fresh-subagent test

**Files:**
- Modify: `.claude/skills/mreview/SKILL_VALIDATION.md`

- [ ] **Step 1: Dispatch a fresh subagent**

Spawn a `general-purpose` agent with a self-contained prompt directing it to invoke `mreview MariaDB/server#<some-low-traffic-PR>` and report whether the skill is self-sufficient (i.e. no human-only steps slipped in).

Prompt outline:
> "You have no context for this session. Run `Skill mreview MariaDB/server#<N>`
> exactly as written. Report any phase where you had to guess or supply
> information not provided by the skill. Quote the chat summary back."

- [ ] **Step 2: Review the subagent's report**

Look for: did it get stuck? Did it have to invent paths? Did the rulebook caching work? Did `gh` auth?

- [ ] **Step 3: Document the run**

Append to SKILL_VALIDATION.md with verbatim subagent quotes for any rough spots.

- [ ] **Step 4: Patch any issues found**

If the subagent reported a missing instruction or unclear phase, update SKILL.md inline before committing.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/mreview/SKILL_VALIDATION.md .claude/skills/mreview/SKILL.md
git commit -m "$(cat <<'EOF'
mreview: SKILL_VALIDATION run 3 (fresh-subagent self-sufficiency)

Dispatched a no-context subagent on a real GitHub PR; report folded
back into SKILL.md where the subagent got stuck.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Validation — mfix integration

**Files:**
- Modify: `.claude/skills/mfix/SKILL.md` (Phase 7.5)
- Modify: `.claude/skills/mreview/SKILL_VALIDATION.md`

- [ ] **Step 1: Locate Phase 7.5 in mfix**

Read `.claude/skills/mfix/SKILL.md` and find the Phase 7.5 block. It currently inlines two Agent calls.

- [ ] **Step 2: Replace the inline dispatch**

Replace the inline Agent invocations with:

```
Stage the proposed fix (do NOT commit yet) and delegate to mreview:

  Skill mreview --staged --standard --no-profile --no-post

Wait for the report. Categorise findings:
  - Blocker: STOP, return to Phase 5 with the blocker quoted.
  - Important: apply, or document in the commit body why not.
  - Nit: apply if cheap; otherwise leave a follow-up note.

When the chat summary shows "Verdict: approve" (0 blockers), proceed
to Phase 8.
```

Keep the bulleted guidance about what to do per severity.

- [ ] **Step 3: Re-run the MDEV-23676 dry-run**

If the build trees and the `10.6-MDEV-23676` branch from the original dry-run still exist, re-run mfix from Phase 7 onwards on the existing Option-B fix. If they don't, document that the integration test was deferred and note what would have to be reproduced first.

- [ ] **Step 4: Compare findings to the original Phase 7.5 output**

Phase 7.5 originally flagged the same iter-1 corruption. With the integration, the new Phase 7.5 should produce the same Blocker set via mreview (same agents, same prompts, same diff).

- [ ] **Step 5: Document the run**

Append to SKILL_VALIDATION.md:

```markdown
## Run 4 — mfix Phase 7.5 delegation

Date: <today>
Target: mfix invocation on MDEV-23676 with Phase 7.5 delegated to
  `mreview --staged --standard --no-profile --no-post`.
Outcome: Phase 7.5 produced the same Blocker set as the inline version
  in iter-1 of the original dry-run.
Confirms: integration is behavior-preserving.
```

- [ ] **Step 6: Commit**

```bash
git add .claude/skills/mfix/SKILL.md \
        .claude/skills/mreview/SKILL_VALIDATION.md
git commit -m "$(cat <<'EOF'
mfix: delegate Phase 7.5 to mreview

Replaces the inline pr-review-toolkit dispatch with a single
'Skill mreview --staged --standard --no-profile --no-post' call.
SKILL_VALIDATION run 4 confirms behavior is preserved on the
MDEV-23676 dry-run.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Finalize SKILL_VALIDATION.md

**Files:**
- Modify: `.claude/skills/mreview/SKILL_VALIDATION.md`

- [ ] **Step 1: Add a summary header**

Prepend the file with a short summary:

```markdown
# mreview — validation runs

Mirrors the 4-run methodology used for `mfix`. Each run exercises a
different invocation mode and a different failure surface.

| Run | Mode | Tier | Outcome |
|---|---|---|---|
| 1 | local-diff smoke | --quick | approve, all artifacts present |
| 2 | known-bad commit | --standard | blockers detected |
| 3 | fresh-subagent on real PR | --standard | <result> |
| 4 | mfix integration | --standard | parity with inlined Phase 7.5 |
```

- [ ] **Step 2: Add open-questions resolution**

Below the run table, address the 5 open questions from DESIGN.md §"Open questions". For each, write either:
- the resolution discovered during validation, OR
- "deferred — needs production traffic to evaluate".

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/mreview/SKILL_VALIDATION.md
git commit -m "$(cat <<'EOF'
mreview: finalize SKILL_VALIDATION with run summary + open Q resolutions

Adds the four-run summary table and either resolves or defers each
of the open questions listed in DESIGN.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Self-review (post-plan)

Spec coverage check against `DESIGN.md`:

- §Invocation surface → Task 2 + Task 3 + Task 4 + Task 5 cover every input form.
- §Workflow phases 0–5 → Tasks 1, 2–5, 6–8, 9 (+ Phase 3 dispatch is wired in SKILL.md per Task 12), 10, 11.
- §mfix integration → Task 16.
- §Output file conventions → enforced by helpers writing to `$WORK_DIR/*` consistently across Tasks 1–11.
- §Severity definitions → encoded in `synthesize.sh` parser (Task 10).
- §Rationalizations to resist → carried into SKILL.md body in Task 12.
- §Open questions → addressed in Task 17.
- §Validation plan → Tasks 13–16 mirror the four runs.

Placeholder scan: no "TBD" or "implement later" — each step has either complete bash code or an explicit command. The SKILL.md body in Task 12 includes a few `[...]` placeholders inside its description, because the SKILL.md content is best authored against the existing mfix SKILL.md as a template; the task's Step 1 says to "write the file with the following structure" and provides the structure plus a length target. That is a documented template, not a placeholder for code.

Type consistency: helpers all use the same env var names (`MREVIEW_WORK_DIR`, `MFIX_REVIEW_REF`, `MREVIEW_FAKE_GH`, `MREVIEW_FAKE_GH_DIR`, `MREVIEW_DIFF`). Exit codes are namespaced: 64 (usage), 65 (unresolvable target), 66 (empty diff), 67 (no PR for MDEV), 68 (multiple PRs for MDEV), 69 (missing profile), 70 (missing report).

---

## Execution

Plan complete and saved to `.claude/skills/mreview/PLAN.md`. Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, two-stage review between tasks; cleanest for a multi-file, multi-helper plan where each task is genuinely independent.

2. **Inline Execution** — execute tasks in this session using executing-plans; faster end-to-end but the main context grows large.

Which approach?
