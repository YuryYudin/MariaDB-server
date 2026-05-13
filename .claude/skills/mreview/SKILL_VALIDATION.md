# mreview — validation runs

Mirrors the 4-run methodology used for `mfix`. Each run exercises a different invocation mode and a different failure surface. Run details are appended as they happen; once all four are complete a summary table is added at the top.

## Run 1 — Local-diff smoke test

**Date**: 2026-05-13
**Target**: `--staged` (a 2-line HTML comment marker appended to `.claude/skills/mreview/SKILL.md`)
**Tier**: `--quick`
**Operator**: live session executing PLAN.md Task 13 end-to-end. Helpers invoked manually in sequence (Skill tool can't yet load the freshly-written skill; this is a known limitation, not a skill defect).

### Pipeline trace

| Phase | Command | Result |
|---|---|---|
| 0 | `lib/setup-workdir.sh 20260513-192217-smoke` | `$WORK_DIR=/home/ggtest/.cache/mreview/20260513-192217-smoke`. `rulebook/` populated (11 files), `profiles/` populated (1 file: `vuvova.md`), `agents/` created empty. |
| 1 | `lib/resolve-target.sh --staged` | `target.json={"type":"staged"}`, `diff.patch` = 10 lines, `touched-paths.txt` = `.claude/skills/mreview/SKILL.md`. |
| 2a | `lib/derive-areas.sh touched-paths.txt > touched-areas.txt` | Empty (markdown under `.claude/skills/`, not in any classified area). |
| 2b | `MREVIEW_DIFF=… lib/select-rulebook.sh touched-areas.txt > loaded-rulebook.txt` | 4 baseline files: `checklist.md`, `commit-and-process.md`, `coding-style.md`, `anti-patterns.md`. |
| 2c | `lib/select-profiles.sh --no-profile > loaded-profiles.txt` | Empty. |
| 3 | `lib/tier-agents.sh quick diff.patch touched-paths.txt > dispatch.txt` | One agent: `code-reviewer`. |
| 3 (dispatch) | Agent tool with `subagent_type=pr-review-toolkit:code-reviewer` and the common prompt template from `SKILL.md` | Wrote `agents/code-reviewer.md`, zero findings (nothing citable in the loaded rulebook for an HTML-comment addition to a markdown file). |
| 4 | `lib/synthesize.sh` | `report.md` produced: `**Verdict: approve**`, all counts 0, all severity sections show `_(none)_`. Per-agent appendix contains the verbatim agent report. |
| 5 | `lib/present.sh` | Printed the report to stdout (up to but not including the appendix). No `github-draft.md` created (target.type ≠ github_pr). |

### Outcome

- All Phase 0–5 deliverables produced.
- Real `pr-review-toolkit:code-reviewer` agent dispatched and produced a well-formed report.
- Verdict: `approve`. Consistent with the trivial content of the staged change.

### Bugs surfaced

None. The pipeline composed cleanly from helpers.

### Observations

- `MREVIEW_WORK_DIR` must be exported before phases 4 and 5 can read it. The skill body in `SKILL.md` already calls this out; relying on it being set is correct.
- The agent's filename matches the subagent_type suffix (`code-reviewer.md`); the synthesizer's basename parsing matches.

### Cleanup

The staged smoke marker was unstaged and reverted; `git diff --stat` confirms no residual changes to `SKILL.md`.

## Run 2 — Same-session: broken-commit detection

**Date**: 2026-05-13
**Target**: commit `5ed1bc1bc72` — "MDEV-23676 Truncate fractional precision in Time::to_native()", the Option-A defensive packed-form truncate that mfix iter-1 produced and that was rejected after silent-failure-hunter detected an off-by-1-second corruption on negative TIME inputs.
**Tier**: `--standard` (code-reviewer + silent-failure-hunter)
**Operator**: live session executing PLAN.md Task 14, helpers invoked manually.

### Pipeline trace

| Phase | Result |
|---|---|
| 0 | `$WORK_DIR=/home/ggtest/.cache/mreview/5ed1bc1bc72-validation`; rulebook (11 files) + profiles (1) cached from `main`. |
| 1 | `target.json={"type":"commit","sha":"5ed1bc1bc722…"}`; `diff.patch` 112 lines (`sql/sql_type.cc`, `mysql-test/main/type_time_hires.{test,result}`); `touched-paths.txt` 3 entries. |
| 2 | Areas: `mysql-test/`, `sql/`. Rulebook loaded: 6 files (4 baseline + `testing.md` + `api-and-architecture.md`). Profiles: none (`--no-profile`). |
| 3 | `tier-agents.sh standard` → `code-reviewer`, `silent-failure-hunter`. Dispatched in parallel. |
| 4 | Synthesize merged the two reports. |
| 5 | Chat summary printed. |

### Findings

| Severity | Count | Notable items |
|---|---:|---|
| Blocker | 2 | (a) Numerical off-by-1s corruption for negative TIME inputs, with worked example `-00:00:00.123456 → -00:00:01.123`, traced through `TIME_to_longlong_time_packed → MY_PACKED_TIME_GET_INT_PART/FRAC_PART → MY_PACKED_TIME_MAKE`. (b) The new MTR regression test outputs `NULL` and therefore never observes the corrupted value. |
| Important | 4 | (a) Preferred fix points at the existing `my_time_trunc()` helper. (b) Truncation site emits no warning. (c) Test marker `End of 10.6 tests` mismatched with the `main` branch the change is on. (d) C-style cast `(int)` in C++ code. |
| Nit | 1 | Narrowing cast at line 754. |
| Praise | 3 | Code comment quality, test minimality, JIRA-aligned reproducer. |

**Verdict**: `request-changes`.

### Conclusion

`--standard` tier surfaces what `--quick` would miss. The silent-failure-hunter agent reasoned at a deeper level than the original mfix iter-1 inline review — it cited the canonical helper to use, gave a full numerical trace, and noticed that the regression test does not even observe the bug. The verdict and findings are consistent with the human conclusion that drove Option-A → Option-B in the mfix dry-run.

### Bugs surfaced

None in the skill pipeline. One reminder: `MREVIEW_WORK_DIR` must be exported in the shell where Phases 4 and 5 run (already noted in Run 1 and in `SKILL.md`).

## Run 3 — Fresh-subagent self-sufficiency

**Date**: 2026-05-13
**Target**: commit `c8bfb4dbd298` ("MDEV-37949 fixup: possible GCC -Wconversion", 1-line diff in `storage/innobase/log/log0log.cc`)
**Tier**: `--standard`
**Operator**: a no-context `general-purpose` subagent given only `SKILL.md` and the target SHA.

### Outcome

Phases 0–2 executed cleanly with no ambiguity. The subagent dispatched a Phase 3 attempt but its harness did NOT expose the `Agent` tool (subagent contexts cannot dispatch sub-subagents), so it stopped at Phase 3 per the "Never fabricate findings" hard rule and produced a structured gap report instead of inventing agent output.

### Verdict on self-sufficiency

- Phases 0–2: ✅ self-sufficient.
- Phase 3+: blocked by harness, not by SKILL.md ambiguity.

### Action taken

Added a "Preconditions" section to `SKILL.md` directly above "Hard rules", stating that the skill requires the `Agent` tool to be available — i.e. it must run in the main conversation (or in an agent that itself has subagent dispatch). This documents the implicit assumption that this run surfaced.

### Other observations from the fresh subagent

- The target-id rule ("PR number / short SHA / sanitized branch / timestamp") was clear; the subagent picked `c8bfb4d` (short SHA) without prompting.
- The "no profile flags → run with no args" interpretation of `select-profiles.sh` was correct.
- The subagent reported Phase 1's deliverable check (target.json + diff.patch + touched-paths.txt) was easy to verify.
- No fabricated findings; no half-implementations.

## Run 4 — mfix Phase 7.5 integration

(populated by Task 16)
