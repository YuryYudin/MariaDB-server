---
name: mreview
description: Code-review orchestration for MariaDB Server. Reviews uncommitted/staged changes, local commits, ranges, branches, or GitHub PRs against the project rulebook and reviewer profiles. Three strictness tiers (quick/standard/deep). Produces a verdict + structured findings report.
---

# mreview — MariaDB code-review orchestration

Drives one review pass over a diff — local working tree, a commit, a range, a branch, or a GitHub PR — by dispatching `pr-review-toolkit` agents in parallel against the project's `.claude/review/*.md` rulebook and optional `.claude/reviewers/<name>.md` profiles, then synthesising their output into a single structured report with a verdict.

This skill is invocable on its own and is also the canonical implementation that `mfix` Phase 7.5 delegates to.

Read [`DESIGN.md`](DESIGN.md) for the rationale behind every phase, the rulebook→path mapping, the auto-elevation thresholds, and the four-run validation plan. The body below is the operational reference.

## When to invoke

| Form | Meaning |
|---|---|
| `mreview` | Auto-detect target from working-tree state |
| `mreview --staged` | Staged diff only (pre-commit review) |
| `mreview --working` | Uncommitted diff only |
| `mreview <SHA>` | Single local commit (7–40 hex chars) |
| `mreview A..B` | Local commit range |
| `mreview HEAD~3..HEAD` | Last 3 commits |
| `mreview <branch>` | Branch vs auto-detected merge-base |
| `mreview 4869` | GitHub PR (assumed `MariaDB/server`) |
| `mreview MariaDB/server#4869` | GitHub PR with explicit repo |
| `mreview https://github.com/.../pull/N` | GitHub PR by URL |
| `mreview MDEV-23676` | Lookup the PR for the MDEV via `gh pr list --search` |

Strictness tiers (mutually exclusive, default is `--standard`):

| Tier | Agents | Wall time |
|---|---|---|
| `--quick` | `code-reviewer` | ~3 min |
| `--standard` | `code-reviewer` + `silent-failure-hunter` | ~7 min |
| `--deep` | All five `pr-review-toolkit` agents | ~12 min |

Auto-elevations apply on top of the chosen tier when the diff is large enough — they're not suppressible. See [`lib/tier-agents.sh`](lib/tier-agents.sh) for the exact thresholds.

Profile control:

- `--profile <name>` — force-load `.claude/reviewers/<name>.md`. Overrides auto-detection.
- `--no-profile` — skip profile auto-detection for this run.

GitHub-PR-only:

- `--post` — after producing the draft, ask before posting via `gh pr review`. Default is to leave the draft on disk for manual editing.

## Preconditions

This skill must run in a context where the `Agent` tool is available — i.e. the main conversation (or any agent that itself has subagent dispatch). If `Agent` isn't reachable, Phase 3 will block. Confirm before starting: if you can't see `Agent` in the tool list, stop and tell the user. `gh` CLI is required only for `github_pr`/`mdev_lookup` targets; `jq` is required for every target.

## Hard rules

- **One Skill invocation = one target.** Don't chain `mreview` calls. If you need to review three PRs, invoke the skill three times.
- **Stop-gates are absolute.** Every phase below ends with a deliverable check. If the deliverable file isn't on disk, STOP and report which check failed — do not "best effort" the next phase from memory.
- **Never fabricate findings.** Only report what an agent wrote or a rulebook line cites. The synthesis step is mechanical; do not paraphrase findings into something stronger than what the agent said.
- **Don't sleep/poll while agents run.** They fire in parallel via a single Agent-tool batch; the Skill tool's harness blocks until all return. No `sleep`, no `until` loops.
- **The rulebook on disk is authoritative.** Helpers read `$WORK_DIR/rulebook/*.md` (cached from `${MFIX_REVIEW_REF:-main}` at Phase 0). Do not consult any other copy of the rulebook for this run, even if the working tree has uncommitted edits to it.

## Workflow (6 gated phases)

```
0. Setup       → rulebook + profiles cached under $WORK_DIR
1. Resolve     → target classified; diff materialized to disk
2. Inspect     → touched paths → rulebook subset; profiles selected
3. Dispatch    → pr-review-toolkit agents fire in parallel
4. Synthesize  → agent reports merged into one structured report
5. Present     → chat summary + (PR target) GitHub draft
```

Every phase below names the helper to invoke, its inputs, the deliverable file(s) it produces, and the stop-gate to enforce before moving on.

---

## Phase 0 — Setup

### Determine the target-id

The `target-id` is a filesystem-safe label used to name `$WORK_DIR`. Derive it from the user's argument **before** running any helper:

| User input | target-id |
|---|---|
| GH PR (`4869`, URL, `owner/repo#N`) | the PR number, e.g. `4869` |
| `MDEV-NNNNN` lookup | the resolved PR number (after Phase 1d) — for Phase 0 use the MDEV string literally as a placeholder; the helpers don't care |
| Single commit SHA | the 7-char short SHA |
| Range `A..B` / `HEAD~N..HEAD` | sanitized branch name (`tr / _`), or `HEAD-range` |
| Branch name | the sanitized branch name |
| `--staged` / `--working` / no arg | timestamp `YYYYMMDD-HHMMSS` (a stable per-invocation label) |

The target-id is **not** functionally significant — it only names a cache directory under `$HOME/.cache/mreview/`. If you pick wrong, the only consequence is that the cache lives at a slightly awkward path.

### Run the helper

```sh
WORK_DIR=$(bash .claude/skills/mreview/lib/setup-workdir.sh <target-id>)
export MREVIEW_WORK_DIR="$WORK_DIR"
```

`setup-workdir.sh` is idempotent. It:

- creates `$WORK_DIR` (default `$HOME/.cache/mreview/<target-id>`, overridable via `MREVIEW_WORK_DIR`),
- caches `.claude/review/*.md` into `$WORK_DIR/rulebook/`,
- caches `.claude/reviewers/*.md` into `$WORK_DIR/profiles/`,
- creates an empty `$WORK_DIR/agents/`,
- prints `$WORK_DIR` to stdout.

Both caches come from `${MFIX_REVIEW_REF:-main}`, so any later branch switch can't make them disappear.

### Deliverable check

```sh
test -s "$WORK_DIR/rulebook/checklist.md" || { echo "Phase 0 failed: rulebook not cached" >&2; exit 1; }
```

If this fails the rulebook is not present on `${MFIX_REVIEW_REF:-main}` in this clone. STOP and report — there is nothing the rest of the skill can do without it.

**Setting `MREVIEW_WORK_DIR` is mandatory** because the synthesize and present helpers read it from the environment. Don't drop the `export`.

---

## Phase 1 — Resolve target

### Run the helper

```sh
bash .claude/skills/mreview/lib/resolve-target.sh "<user-arg>"
```

Pass the user's argument verbatim. For the no-argument case, call `resolve-target.sh` with no positional argument — it routes to `lib/auto-detect.sh` internally.

Routing inside `resolve-target.sh` (priority order, first match wins):

| Input pattern | Routes to | Effect |
|---|---|---|
| `https://github.com/.../pull/N` | `lib/fetch-pr.sh <owner/repo> <N>` | Downloads diff + `pr-meta.json` + `pr-existing-comments.json` via `gh` |
| `<owner>/<repo>#<N>` | `lib/fetch-pr.sh` | Same as above |
| `4869` (1–6 digit int) | `lib/fetch-pr.sh MariaDB/server 4869` | Assumes `MariaDB/server` |
| `MDEV-NNNNN` | `lib/mdev-to-pr.sh` → `lib/fetch-pr.sh` | `gh pr list --search MDEV-NNNNN`; if exactly one match, fetches it. Multiple matches → exits non-zero with the list. |
| 7–40 hex chars | `git show <sha>` → `diff.patch` | Single-commit review |
| contains `..` | `git diff A..B` → `diff.patch` | Range |
| `--staged` | `git diff --cached` → `diff.patch` | Pre-commit review |
| `--working` / `--working-tree` | `git diff` → `diff.patch` | Working-tree review |
| Matches local branch | `git diff <base>..<branch>` | `base = git merge-base <branch> origin/main` (or `origin/<closest-release>`) |
| (no argument) | `lib/auto-detect.sh` | Picks one of the above based on `git status` |

Regardless of source, the diff is **materialized** to `$WORK_DIR/diff.patch` — the single artifact downstream agents read. The helper also writes:

- `$WORK_DIR/target.json` — structured target description (`{type, id, base, head, branch, repo, pr_number?}`)
- `$WORK_DIR/touched-paths.txt` — newline-separated list of files in the diff
- For GH-PR targets: `$WORK_DIR/pr-meta.json` and `$WORK_DIR/pr-existing-comments.json`

### Deliverable check

```sh
test -s "$WORK_DIR/diff.patch" || { echo "Phase 1: empty diff" >&2; exit 1; }
jq -e . "$WORK_DIR/target.json" >/dev/null \
  || { echo "Phase 1: target.json invalid" >&2; exit 1; }
test -f "$WORK_DIR/touched-paths.txt" \
  || { echo "Phase 1: touched-paths.txt missing" >&2; exit 1; }
```

`resolve-target.sh` exits **66** when the diff is empty (nothing to review). That's a user-actionable error — see "Common failures" below.

---

## Phase 2 — Inspect

Three sub-steps, run in order. Each reads the output of the previous one.

### 2a — Derive touched-area labels

```sh
bash .claude/skills/mreview/lib/derive-areas.sh "$WORK_DIR/touched-paths.txt" \
  > "$WORK_DIR/touched-areas.txt"
```

Output is a sorted, unique list of area labels (`sql/`, `storage/innobase/`, `mysql-test/main/`, `plugin/`, `cmake/`, …). Used by the rulebook selector and by the agents themselves.

### 2b — Select rulebook subset

```sh
MREVIEW_DIFF="$WORK_DIR/diff.patch" \
  bash .claude/skills/mreview/lib/select-rulebook.sh "$WORK_DIR/touched-areas.txt" \
  > "$WORK_DIR/loaded-rulebook.txt"
```

`select-rulebook.sh` always emits the project-wide baseline (`checklist.md`, `commit-and-process.md`, `coding-style.md`, `anti-patterns.md`) plus area-specific files (`innodb.md`, `testing.md`, `build-and-cmake.md`, `logging-and-errors.md`, `api-and-architecture.md`, `correctness-and-security.md`). It also peeks at `$MREVIEW_DIFF` for security-elevation cues (auth/ACL/bounds-check patterns) and pulls `correctness-and-security.md` in when they fire.

### 2c — Select reviewer profiles

```sh
bash .claude/skills/mreview/lib/select-profiles.sh <profile-flags> \
  > "$WORK_DIR/loaded-profiles.txt"
```

`<profile-flags>` is one of:

- *(empty)* — auto-detect from `$WORK_DIR/pr-meta.json` (GH-PR targets) or emit no profiles (local targets)
- `--profile <name>` — force-load exactly that one profile
- `--no-profile` — emit an empty list

`select-profiles.sh` exits **69** if `--profile <name>` names a profile file that's not in `$WORK_DIR/profiles/`.

### Deliverable check

```sh
test -f "$WORK_DIR/loaded-rulebook.txt" \
  || { echo "Phase 2: loaded-rulebook.txt missing" >&2; exit 1; }
test -f "$WORK_DIR/loaded-profiles.txt" \
  || { echo "Phase 2: loaded-profiles.txt missing" >&2; exit 1; }
```

`loaded-profiles.txt` may legitimately be empty (e.g. `--no-profile`, or a local target with no auto-detection). `loaded-rulebook.txt` always has at least the four baseline files.

### Print a brief inspection summary to chat

> Touching: `<comma-separated areas from touched-areas.txt>`.
> Rulebook: `<N>` files (`<basename list>`).
> Profiles: `<M>` (`<basename list, or "none">`).

This is the only chat output between Phase 0 and Phase 5 — keep it short.

---

## Phase 3 — Dispatch

The single most important phase to get right.

### Compute the agent list

```sh
bash .claude/skills/mreview/lib/tier-agents.sh <tier> \
       "$WORK_DIR/diff.patch" \
       "$WORK_DIR/touched-paths.txt" \
     > "$WORK_DIR/dispatch.txt"
echo "<tier>" > "$WORK_DIR/tier.txt"
```

`<tier>` is the tier name without the leading `--` (`quick`, `standard`, or `deep`; default is `standard` if the user didn't pass a tier flag). `tier-agents.sh` adds auto-elevations on top of the base set:

- `pr-test-analyzer` forced on if `touched-paths.txt` has ≥10 `mysql-test/*.{test,result}` lines.
- `comment-analyzer` forced on if `diff.patch` has ≥30 net added comment lines.
- `type-design-analyzer` forced on if `diff.patch` introduces ≥1 new type declaration.

Announce any elevations in chat: *"auto-elevation: enabling `pr-test-analyzer` (touched 14 test files)."*

Write the chosen tier to `$WORK_DIR/tier.txt` so `synthesize.sh` can pick it up later (it embeds the tier in the report's summary line).

### Fire the agents in parallel

For **every** agent name listed in `dispatch.txt`, fire a `pr-review-toolkit:<agent>` agent via the Agent tool. All of them go out in **one message with multiple Agent tool calls** — that's what makes them parallel. Do not call them sequentially.

Common prompt template (substitute the agent's basename for `<agent-name>`):

```
You are reviewing a MariaDB Server change for a code-review pass.

Inputs (all under $WORK_DIR; absolute paths preferred):
  Diff:              $WORK_DIR/diff.patch
  Target metadata:   $WORK_DIR/target.json
  Touched paths:     $WORK_DIR/touched-paths.txt
  Touched areas:     $WORK_DIR/touched-areas.txt
  Rulebook subset:   files listed in $WORK_DIR/loaded-rulebook.txt,
                     each readable as $WORK_DIR/rulebook/<name>
  Profiles:          files listed in $WORK_DIR/loaded-profiles.txt
                     (may be empty), each at $WORK_DIR/profiles/<name>
  PR metadata:       $WORK_DIR/pr-meta.json           (present only for GH PR targets)
  Existing comments: $WORK_DIR/pr-existing-comments.json  (present only for GH PR targets)

Apply the rulebook and (if any) profiles as your authoritative source of project
norms. Do NOT invent rules that aren't in the rulebook.

For each finding, emit exactly one line of this shape:
  - **<Severity>** [<path>:<line>] <one-sentence body> (cited from <rulebook>:<section>)

Severity vocabulary (use exactly these four words):
  Blocker     — would cause this PR to be rejected at review
  Important   — maintainer will likely request the change
  Nit         — pure preference; reviewer may mention but won't hold the PR
  Praise      — notable positive observation worth encouraging

Write your full report to:
  $WORK_DIR/agents/<agent-name>.md
…where <agent-name> is the basename matching your subagent_type's tail
(e.g. "code-reviewer.md" for pr-review-toolkit:code-reviewer).
```

Substitute `$WORK_DIR` with the actual absolute path when constructing the prompt — agents start with no environment from the orchestrator.

### Deliverable check

After every Agent call returns, verify:

```sh
while read -r name; do
  test -s "$WORK_DIR/agents/$name.md" \
    || { echo "Phase 3: agent $name produced no output" >&2; missing="$missing $name"; }
done < "$WORK_DIR/dispatch.txt"
[ -n "${missing:-}" ] && { echo "missing: $missing" >&2; exit 1; }
```

If any agent's report is missing or empty, **STOP** and report which ones — do not synthesize a partial result. The right next step is to retry the missing agents (Common failures table below).

---

## Phase 4 — Synthesize

```sh
bash .claude/skills/mreview/lib/synthesize.sh
```

`synthesize.sh` reads `$MREVIEW_WORK_DIR` from the environment (set in Phase 0). It:

- parses every `agents/*.md` for lines matching the structured-finding shape,
- groups by severity (`Blocker > Important > Nit > Praise`),
- dedupes near-identical findings from different agents (same `path:line ± 3`, same severity, similar body) and appends `(also flagged by <other-agent>)`,
- derives a verdict from blocker count (`≥1 → request-changes`; `0 blockers + ≥1 Important → approve-with-changes`; `0/0 → approve`),
- writes `$WORK_DIR/report.md` with the structure: Verdict line, Summary, Blockers, Important, Nits, Praise, Per-agent appendix (verbatim raw agent reports concatenated).

There is no second-pass LLM call — this is a mechanical merge.

### Deliverable check

```sh
test -s "$WORK_DIR/report.md" \
  || { echo "Phase 4: report.md missing or empty" >&2; exit 1; }
grep -q '^\*\*Verdict:' "$WORK_DIR/report.md" \
  || { echo "Phase 4: report.md has no Verdict line" >&2; exit 1; }
```

---

## Phase 5 — Present

```sh
bash .claude/skills/mreview/lib/present.sh
```

`present.sh` reads `$MREVIEW_WORK_DIR/report.md` and:

- prints the chat-friendly summary to stdout (Verdict + Summary + Blockers + Important; Nits/Praise/appendix omitted to stay scannable),
- for GH-PR targets (`type == "github_pr"` in `target.json`), writes `$WORK_DIR/github-draft.md` and prints a ready-to-paste `gh pr review <N> --comment --body-file <path>` command.

**Relay stdout verbatim to the user.** This is the only deliverable the user sees in chat — don't paraphrase it.

### Deliverable check

```sh
test -s "$WORK_DIR/report.md"
# For github_pr targets only:
case "$(jq -r .type "$WORK_DIR/target.json")" in
  github_pr)
    test -s "$WORK_DIR/github-draft.md" \
      || { echo "Phase 5: github-draft.md missing" >&2; exit 1; }
    ;;
esac
```

`present.sh` exits 70 if `report.md` is missing or empty. That means Phase 4 silently failed; back up and re-check.

---

## Rationalizations to resist

| Rationalization | Counter |
|---|---|
| "I'll just run `--quick` for everything to save time." | `--quick` misses the silent-failure-hunter pass. Iter-1 of the mfix dry-run produced a numerically-verified silent-corruption bug that `--standard` caught in 7 min. Use `--standard` as default unless you have a strong reason. |
| "Auto-elevations are overzealous; I'll suppress them." | The elevations fire on objective thresholds (≥10 test files, ≥30 comment lines, ≥1 new type). If they fire, the diff is large enough to need the extra agent. There is no `--no-elevate`. |
| "The reviewer profile contradicts the rulebook — I'll just ignore the profile." | Profile + rulebook are layered: rulebook is the project norm, profile is the *individual reviewer*'s preferences within that norm. When they conflict, mention both in the report and let the contributor decide. Do not silently drop one. |
| "GH PR has a CLA-bot failure; skip review." | Architectural / correctness review is still useful even when the PR is blocked on process. Run mreview; mention CLA in the report's process notes. |
| "The MDEV→PR lookup returned zero results — let me review the JIRA description instead." | mreview reviews diffs, not JIRAs. If there's no PR, STOP and suggest `mfix` (which handles JIRAs) instead. |

## Common failures and recovery

| Failure | Cause | Recovery |
|---|---|---|
| `resolve-target.sh` exits 66 ("empty diff") | Working tree clean and no other arg supplied; or `--staged` with nothing staged; or `A..B` with `A == B`. | Check `git status` / `git diff --cached`. If the user meant `--staged`, suggest `--working`; if they meant `--working`, suggest `--staged`. Make sure there is actually a change to review. |
| Agent's `agents/<name>.md` missing or empty after dispatch | The Agent tool returned without writing the file (timeout, the agent forgot, an internal error). | Re-dispatch that specific agent with the same prompt; do not retry the whole tier. After one retry, if still missing, report which agent failed and let the user decide whether to synthesize on partial output. |
| `mdev-to-pr.sh` returns multiple PRs for one MDEV | Common when an MDEV has parallel fixes on multiple release branches. | Print the list (PR number, branch, title) and ask the user to pick one. Re-invoke `mreview <chosen-pr-number>` with the explicit number. |
| `select-profiles.sh` exits 69 ("profile not found") | `--profile <name>` named a file that isn't under `$WORK_DIR/profiles/`. | List `$WORK_DIR/profiles/` for the user; suggest re-running with one of the available names or `--no-profile`. |
| `fetch-pr.sh` fails on `github_pr` target | `gh` is not authenticated, or the repo is private and `gh` lacks scope. | Suggest `gh auth login` (and `gh auth refresh -s read:org` if cross-org). Don't try to substitute a non-`gh` fetch path — the helper relies on `gh pr view --json` shape. |
| `setup-workdir.sh` fails: rulebook not on `${MFIX_REVIEW_REF:-main}` | The clone was forked before `.claude/review/` was added, or the ref is wrong. | Fetch the upstream that has the rulebook, or set `MFIX_REVIEW_REF` to a commit-ish that does. The skill is not usable without the rulebook. |
| `synthesize.sh` produces `report.md` with no findings at all | All agents wrote reports but none emitted a structured-finding line. | Check `agents/*.md` for free-form prose without the `- **Severity** [path:line] …` shape. Re-prompt the affected agents with an explicit reminder about the finding shape. |

---

## File layout under `$WORK_DIR`

```
$WORK_DIR/
├── target.json              # structured target description
├── diff.patch               # the diff (single source of truth)
├── touched-paths.txt        # files in the diff
├── touched-areas.txt        # derived area labels (Phase 2a)
├── pr-meta.json             # gh pr view --json (PR targets only)
├── pr-existing-comments.json
├── loaded-rulebook.txt      # rulebook files passed to agents (Phase 2b)
├── loaded-profiles.txt      # profiles passed to agents (Phase 2c)
├── dispatch.txt             # agent names fired (Phase 3)
├── tier.txt                 # tier chosen (Phase 3)
├── rulebook/*.md            # cached .claude/review/*.md
├── profiles/*.md            # cached .claude/reviewers/*.md
├── agents/                  # raw per-agent reports
│   ├── code-reviewer.md
│   ├── silent-failure-hunter.md
│   └── …
├── report.md                # final merged report (Phase 4)
└── github-draft.md          # GitHub review draft (Phase 5, PR targets only)
```

`$WORK_DIR` defaults to `$HOME/.cache/mreview/<target-id>` and is overridable via `MREVIEW_WORK_DIR`. Old work dirs are not auto-cleaned.

---

## Pointers

- [`DESIGN.md`](DESIGN.md) — design rationale, decision tree, and severity definitions.
- [`SKILL_VALIDATION.md`](SKILL_VALIDATION.md) — four-run validation log (smoke test, broken-commit detection, fresh-subagent self-sufficiency, mfix integration). Populated by Tasks 13–17.
- [`lib/`](lib/) — the helper scripts each phase calls. Read these when the skill's behavior is unclear; they are the executable spec.
- [`.claude/review/README.md`](../../review/README.md) — the rulebook itself; the agents apply this, not anything Claude paraphrases at runtime.
