# mreview — design spec

**Status**: approved (brainstorming complete; pre-implementation).
**Date**: 2026-05-13.
**Authoring conversation**: live session that produced `.claude/skills/mfix/`, `.claude/review/`, and `.claude/reviewers/vuvova.md`.

## Purpose

`mreview` is a MariaDB-specific code-review orchestration skill. It reviews any of:

- the current uncommitted / staged working-tree state,
- one or more local commits (SHA, range, or branch tip vs origin merge-base),
- a GitHub pull request (by number, URL, or `MDEV-NNNNN` lookup),

…against the project's `.claude/review/*.md` rulebook plus any matching `.claude/reviewers/<name>.md` profile, by dispatching `pr-review-toolkit` agents in a configurable strictness tier and synthesising their output into a single structured report.

The skill is invocable on its own ("/mreview" with optional args) **and** is the canonical implementation that `mfix` Phase 7.5 will delegate to.

## Why this exists (problem statement)

Three concrete gaps in the current setup:

1. **mfix's Phase 7.5 inlines the agent dispatch.** That logic isn't reusable; if you want to review a PR you didn't fix yourself, you can't reach it. Reviewing your own staged work without the rest of the mfix workflow is also awkward.
2. **The `pr-review-toolkit:review-pr` skill** is a generic meta-skill that doesn't know about MariaDB's rulebook, reviewer profiles, or the area-owner table. Using it loses everything we've built in `.claude/review/` and `.claude/reviewers/`.
3. **Reviewing someone else's PR** (e.g. via GitHub) currently means hand-fetching the diff, hand-choosing agents, and hand-merging their findings. There's no consolidated workflow.

`mreview` fills these gaps as one skill with a thin, target-agnostic interface.

## Out of scope

- New-feature design reviews. Use `superpowers:brainstorming` instead.
- Reviewing out-of-tree code, vendored submodules, or third-party engines whose review process lives elsewhere (Connector/C, wsrep-lib).
- Performance / benchmark review. Different tooling, not in scope here.
- Replacing `pr-review-toolkit:review-pr` for non-MariaDB projects — that skill stays as the generic option.

## Invocation surface

```
mreview                          # auto-detect target from working-tree state
mreview --staged                 # staged diff only (pre-commit review)
mreview --working                # uncommitted diff only
mreview <SHA>                    # single local commit (7-40 hex)
mreview A..B                     # local commit range
mreview HEAD~3..HEAD             # last 3 commits
mreview <branch>                 # branch vs auto-detected base (origin/main / origin/<release>)
mreview 4869                     # GitHub PR (assumed MariaDB/server)
mreview MariaDB/server#4869      # GitHub PR with explicit repo
mreview https://github.com/...   # GitHub PR by URL
mreview MDEV-23676               # gh pr list --search MDEV-23676 → review the matching PR

# Strictness tier (mutually exclusive):
--quick      # code-reviewer only (~3 min)
--standard   # code-reviewer + silent-failure-hunter (default, ~7 min)
--deep       # all 5 pr-review-toolkit agents in parallel (~12 min)

# Profile control:
--profile <name>   # force load .claude/reviewers/<name>.md
--no-profile       # skip auto-loaded profiles for this run

# GitHub-PR-target only:
--post             # skip "draft + confirm" — post review comment immediately
                   #   (still requires gh auth)
```

### Auto-detect (no args)

```
working tree dirty                            → uncommitted + staged combined
working tree clean, ahead of upstream         → HEAD vs upstream merge-base
working tree clean, on upstream-tracking br.  → last commit only
ambiguous (e.g. no upstream tracked)          → STOP, list candidates, ask user
```

## Workflow phases

Six gated phases. Stop-gate rule: if a phase's deliverable isn't in hand, the skill stops and reports — no guessing.

```
0. Setup     → rulebook cached, working dir created
1. Resolve   → target identified, diff materialized to disk
2. Inspect   → touched-path → topic rulebook subset; reviewer profiles selected
3. Dispatch  → pr-review-toolkit agents fired in parallel per tier
4. Synthesize → agent reports merged into one structured report
5. Present   → chat summary + report file + (for GH PR) draft `gh pr review` body
```

### Phase 0 — Setup

Mirrors mfix's Phase 0. Caches `.claude/review/*.md` and `.claude/reviewers/*.md` from `$MFIX_REVIEW_REF` (default `main`) into `$WORK_DIR/rulebook/` and `$WORK_DIR/profiles/`. Survives any later branch switch.

`$WORK_DIR` resolution:

```
${MREVIEW_WORK_DIR:-$HOME/.cache/mreview/<id>}
```

…where `<id>` is:
- the PR number for a GH PR target,
- the short SHA for a single-commit target,
- the branch name (sanitized) for a range/branch target,
- the timestamp `YYYYMMDD-HHMMSS` for working-tree/staged targets.

The work dir is the durable location for the diff, the report, and the per-agent appendices.

**Phase 0 deliverable**: `$WORK_DIR` exists, `$WORK_DIR/rulebook/*.md` and `$WORK_DIR/profiles/*.md` populated, sanity check passed.

### Phase 1 — Resolve target

Decision tree (priority order — first match wins):

| Pattern | Resolution |
|---|---|
| `4869` (1–6 digit int) | GH PR `MariaDB/server#4869` |
| `https?://github\.com/.+/pull/N` | parse owner/repo/N |
| `<owner>/<repo>#<N>` | explicit GH PR |
| `MDEV-NNNNN` | `gh pr list --search 'MDEV-NNNNN'` → if exactly one PR, use it; if zero, STOP with "no PR found for this MDEV — try `mfix` instead?"; if multiple, list and ask user |
| 7–40 hex chars | `git show <sha>` (must resolve in current repo) |
| contains `..` | range — `git diff A..B` |
| `--staged` | `git diff --cached` |
| `--working` / `--working-tree` | `git diff` (uncommitted) |
| matches a known local branch name | `<branch>..HEAD` if branch is checked-out parent, else `<base>..<branch>` where base = `git merge-base <branch> origin/main` (or `origin/<closest-release>`) |
| no arg | auto-detect per the table above |

Once resolved, the **diff is materialized** to `$WORK_DIR/diff.patch` regardless of source. This is the single artifact downstream agents read. Also written:

- `$WORK_DIR/target.json` — structured target description (`{type, id, base, head, branch, repo, pr_number?}`)
- `$WORK_DIR/touched-paths.txt` — newline-separated list of files in the diff
- `$WORK_DIR/touched-areas.txt` — derived area labels (`sql/`, `storage/innobase/`, `mysql-test/main/`, `plugin/`, `cmake/`, …)
- For GH PR targets: `$WORK_DIR/pr-meta.json` (full `gh pr view --json …` output) + `$WORK_DIR/pr-existing-comments.json`.

**Phase 1 deliverable**: `target.json` written, `diff.patch` materialized non-empty, touched-paths enumerated.

### Phase 2 — Inspect

Path-to-rulebook mapping (applied to `touched-paths.txt` to build the rulebook subset the agents will receive):

| Touched path pattern | Rulebook files loaded |
|---|---|
| any | `checklist.md`, `commit-and-process.md`, `coding-style.md`, `anti-patterns.md` (always) |
| `storage/innobase/*` | `innodb.md` |
| `mysql-test/*` | `testing.md` |
| `CMakeLists.txt`, `cmake/*` | `build-and-cmake.md` |
| `sql/share/errmsg-utf8.txt`, any `sql_print_*` change | `logging-and-errors.md` |
| any change involving `Item*`, `Type_handler*`, on-disk format, plugin API headers | `api-and-architecture.md` |
| any change that adds bounds checks, sanitizer fixes, or auth/ACL code | `correctness-and-security.md` |

**Profile auto-detection** (GH PR targets only):

```
1. From pr-meta.json, read assignee + requested_reviewers + comment authors.
2. From rulebook/commit-and-process.md, look up the area-owner for each
   touched-areas entry. (Fuzzy match against the reviewer-area table.)
3. Union the candidate names.
4. For each candidate, check if profiles/<name>.md exists. Keep matches.
5. Cap at 2 profiles (avoids contradictory advice between reviewers with
   different cast/test/comment preferences).
6. If --profile <name> is set, that ONE profile is used (overrides 1-5).
7. If --no-profile is set, the loaded set is empty.
```

For local targets (no PR meta), profile loading is `none` unless `--profile` is set.

**Phase 2 deliverable**: `$WORK_DIR/loaded-rulebook.txt` (list of rulebook files for the agents), `$WORK_DIR/loaded-profiles.txt` (list of profile files), brief inspection summary printed to chat.

### Phase 3 — Dispatch

Agents to fire per tier:

| Tier | Agents | Wall time |
|---|---|---|
| `--quick` | `pr-review-toolkit:code-reviewer` | ~3 min |
| `--standard` (default) | `code-reviewer` + `silent-failure-hunter` | ~7 min |
| `--deep` | All 5: above + `pr-test-analyzer` + `comment-analyzer` + `type-design-analyzer` | ~12 min |

Auto-elevations regardless of tier (announced in chat when triggered):

- `pr-test-analyzer` forced on if `touched-paths.txt` has ≥10 `mysql-test/*.test` or `mysql-test/*.result` lines.
- `comment-analyzer` forced on if `git diff --stat $WORK_DIR/diff.patch` shows ≥30 net added comment lines.
- `type-design-analyzer` forced on if `git grep -n '^[[:space:]]*\(class\|struct\) [A-Z]' $WORK_DIR/diff.patch` finds ≥1 new type declaration.

All selected agents fire in **parallel** with one prompt template each. Common payload sent to every agent:

```
Diff:               $WORK_DIR/diff.patch
Target metadata:    $WORK_DIR/target.json
Rulebook subset:    paths listed in $WORK_DIR/loaded-rulebook.txt
Profiles:           paths listed in $WORK_DIR/loaded-profiles.txt
PR meta (if any):   $WORK_DIR/pr-meta.json
Existing comments:  $WORK_DIR/pr-existing-comments.json
Report output path: $WORK_DIR/agents/<agent-name>.md
```

Each agent's prompt instructs it to use the **same severity vocabulary** (Blocker / Important / Nit / Praise) and the **same finding shape** (`[path:line] <one-sentence>` + `cited from <rulebook-file>:<section>` + agent name) so the synthesis step is mechanical.

**Phase 3 deliverable**: every selected agent's `$WORK_DIR/agents/<name>.md` exists with the expected structure.

### Phase 4 — Synthesize

Mechanical merge — no second-pass LLM call.

```
1. Read each $WORK_DIR/agents/<name>.md
2. For each finding, extract: severity, path:line, body, cited rulebook, agent
3. Group by severity (Blocker > Important > Nit > Praise)
4. Dedupe near-identical findings from different agents (same path:line ± 3,
   same severity, similar body): keep the most specific, append "(also flagged
   by <other-agent>)"
5. Sort within each severity by path then line
6. Write $WORK_DIR/report.md with structure:
     - Verdict (auto from blocker count: ≥1 → request-changes; 0 blockers but
       ≥1 important → approve-with-changes; 0/0 → approve)
     - Summary (counts, time, tier, profiles, rulebook)
     - Blockers / Important / Nits / Praise
     - Per-agent appendix (verbatim agent reports concatenated)
```

**Phase 4 deliverable**: `$WORK_DIR/report.md` written and well-formed.

### Phase 5 — Present

```
1. Print chat summary: Verdict + Summary + Blockers + Important
   (skip nits/praise/appendix in chat — keep it scannable)
2. Print pointer to $WORK_DIR/report.md for full text
3. For GH PR targets:
   a. Write $WORK_DIR/github-draft.md — same as report.md minus per-agent
      appendix, formatted for GitHub Markdown
   b. Print "Draft GitHub review at $WORK_DIR/github-draft.md"
   c. If --post: ask "Post this draft to PR #N as a review comment? (y/N)"
      - yes: `gh pr review <N> --comment --body-file $WORK_DIR/github-draft.md`
      - no: leave the draft for manual editing
   d. If not --post: just print the gh command for the user to run themselves
```

**Phase 5 deliverable**: chat summary printed, report file exists, GitHub draft
exists (for PR targets), invocation completed.

## mfix integration

`.claude/skills/mfix/SKILL.md` Phase 7.5 currently inlines:

```python
Agent(subagent_type="pr-review-toolkit:code-reviewer", prompt="...")  # parallel
Agent(subagent_type="pr-review-toolkit:silent-failure-hunter", prompt="...")
```

The replacement (mfix Phase 7.5 becomes):

```
Stage the changes (don't commit yet) and invoke mreview:

  Skill mreview --staged --tier=standard --no-profile --no-post

Wait for the report. Categorise findings:
  - Blocker: stop, return to Phase 5
  - Important: apply or document why not (in the commit message body)
  - Nit: apply if cheap, otherwise note for follow-up

When the report shows 0 blockers, proceed to Phase 8.
```

The `mreview` args are the same in Skill invocation as on the CLI — the
positional `--staged` / `--working` / `<SHA>` / `<branch>` / `<PR>` forms work
identically whether typed by a human or composed by another skill.

This collapses ~50 lines of inline-agent-dispatch in mfix into one Skill invocation, leaves orchestration in mreview, and means future improvements (auto-elevation, profile auto-detect, GitHub posting) come along for free.

mfix's `SKILL_VALIDATION.md` does not need to change — the validation findings still apply, they just describe what mreview now does under the hood.

## Output file conventions

All artifacts under `$WORK_DIR`:

```
$WORK_DIR/
├── target.json             # structured description of what's being reviewed
├── diff.patch              # the diff (single source of truth for agents)
├── touched-paths.txt       # newline-separated file list
├── touched-areas.txt       # derived area labels
├── pr-meta.json            # gh pr view --json output (PR targets only)
├── pr-existing-comments.json   # existing reviews/comments (PR targets only)
├── loaded-rulebook.txt     # which rulebook files the agents received
├── loaded-profiles.txt     # which profiles were loaded (auto + manual)
├── rulebook/*.md           # cached copies of .claude/review/*.md
├── profiles/*.md           # cached copies of .claude/reviewers/*.md
├── agents/                 # raw per-agent reports
│   ├── code-reviewer.md
│   ├── silent-failure-hunter.md
│   └── …
├── report.md               # final merged report (Phase 4)
└── github-draft.md         # GitHub PR review draft (Phase 5, PR targets only)
```

`$WORK_DIR` defaults to `$HOME/.cache/mreview/<id>/`, overridable via `MREVIEW_WORK_DIR`. Old work dirs are not auto-cleaned; that's a user concern.

## Severity definitions

Carried over from the existing `.claude/review/README.md` legend so the agents, the rulebook, and the mreview output all use the same vocabulary:

- **Blocker**: would cause the PR to be rejected at review (correctness, security, replication wire-format, architecture-rejection, missing tests, missing CLA). 0 of these = mergeable; ≥1 = must fix.
- **Important**: maintainer will likely request the change but may accept follow-up. Style with strong project consensus, test convention, log wording.
- **Nit**: pure preference. Reviewer may mention but won't hold the PR.
- **Praise**: notable positive observation. Encourages the pattern in future PRs.

## Rationalizations to resist (skill-body content)

Same shape as mfix's table; these are the ones specific to mreview:

| Rationalization | Counter |
|---|---|
| "I'll just run `--quick` for everything to save time." | `--quick` misses the silent-failure-hunter pass. Iter-1 of the mfix dry-run produced a numerically-verified silent-corruption bug that `--standard` caught in 7 min. Use `--standard` as default unless you have a strong reason. |
| "Auto-elevations are overzealous; I'll suppress them." | The elevations fire on objective thresholds (≥10 test files, ≥30 comment lines, new type). If they fire, the diff is large enough to need the extra agent. There's no `--no-elevate`. |
| "The reviewer profile contradicts the rulebook — ignore it." | Profile + rulebook are layered: rulebook is the project norm, profile is the *individual reviewer*'s preferences within that norm. When they conflict, mention both in the report and let the contributor decide. Do not silently drop one. |
| "GH PR has a CLA bot failure; skip review." | Architectural / correctness review is still useful even when the PR is blocked on process. Run mreview; mention CLA in the report's "process notes" section. |
| "The MDEV→PR lookup returned zero results, so the bug isn't in a PR yet — let me review the JIRA instead." | mreview reviews diffs, not JIRAs. If there's no PR, stop and suggest mfix (which handles JIRAs) instead. |

## Open questions / things to validate during implementation

1. **Diff size threshold**. The diff materialized for some large PRs can exceed agent context budgets. Investigate whether the agents fail gracefully or need pre-truncation. (mfix's Phase 7.5 didn't hit this on MDEV-23676 but might on a multi-file refactor.)
2. **MDEV→PR resolution ambiguity**. Some MDEVs have multiple PRs (one per branch). Decide whether to review all of them or only the most recent / most active. Initial proposal: list and ask if >1.
3. **`gh pr review --comment` rate limiting**. If `--post` is used repeatedly, watch for GitHub rate limits on review comments. Not v1-blocking but worth a note.
4. **Profile contradictions**. The "cap at 2 profiles" rule is a guess. Validate against a PR with vuvova + dr-m both reviewing — do their preferences actually conflict in practice?
5. **Auto-elevation thresholds (10/30/1)**. These are guesses. Tune after the first 5–10 invocations.

## Validation plan

Mirror the four validation runs we did for `mfix`:

1. **Same-session walk-through**: invoke mreview on the existing `5ed1bc1bc72` (the broken-on-purpose Option-A dry-run commit) — confirm the same iter-1 blockers fire.
2. **Fresh-subagent test**: dispatch a subagent on `mreview --target=PR#<some-MDEV-38034-equivalent>` and see whether the skill is self-sufficient.
3. **Local-diff test**: invoke mreview on the actual unstaged state during a real fix-in-progress. Confirm chat-only flow is usable.
4. **mfix integration test**: replace mfix Phase 7.5 with the mreview delegation; re-run the MDEV-23676 dry-run; confirm Phase 7.5 still catches what it caught before.

A `SKILL_VALIDATION.md` will be added alongside `SKILL.md` documenting these runs.

## File layout

```
.claude/skills/mreview/
├── SKILL.md              # the skill body (~400-500 lines target)
├── DESIGN.md             # this document
├── SKILL_VALIDATION.md   # validation runs (written after implementation)
└── resolve-target.sh     # (optional) reusable target-resolution helper script
```

The skill body links back to this DESIGN.md for the rationale behind specific choices.

## Lineage notes

This design synthesises lessons from:

- `.claude/skills/mfix/SKILL.md` Phase 7.5 (the inline pattern this generalises)
- `.claude/skills/mfix/SKILL_VALIDATION.md` (proven 4-run validation methodology)
- `.claude/review/*.md` (the rulebook the agents apply)
- `.claude/reviewers/vuvova.md` (the first reviewer profile; pattern for future profiles)
- `pr-review-toolkit:review-pr` skill (the generic baseline mreview specialises)

Once `SKILL.md` is written, the design here becomes reference material; future skill edits should update it.
