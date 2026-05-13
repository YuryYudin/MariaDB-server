# mfix skill — first-run validation against MDEV-23676

**Date**: 2026-05-12. **Validator**: same-session walk-through (not a fresh subagent — see "Untested" below).

## Initial outcome (wrong) and corrected outcome

| Phase | Initial status | Corrected status | Notes |
|---|---|---|---|
| 1. Discover | ✅ Worked | ✅ Worked | `fetch-mdev.sh` returned clean JSON; description-mining surfaced regression commit, reproducers, linked MDEV-29924, stack trace. |
| 2. Plan | ✅ Worked | ✅ Worked | Target = 10.11 (lowest `fixVersion`); reviewer = vuvova (JIRA assignee); test home = `type_time_hires.{test,result}`; prior fix = `1a3859fff09` (MDEV-29924). |
| 3. Branch + build | ✅ Worked | ✅ Worked | `cmake -G Ninja … -t minbuild` ~12 min on 32 cores. |
| 4. Reproduce | ⚠️ "Doesn't crash on 10.11 → bug appears fixed" | ❌ **WRONG CONCLUSION** | 5 reproducer variations returned NULL on 10.11.17 — but the SAME repro crashed deterministically on origin/10.6.26 with the exact assertion + stack from Alice's 2025-07-30 comment. The bug is real and open; `fixVersions` describes where it should land, not where it currently reproduces. |

**The wrong initial conclusion was the most valuable finding.** A user push-back ("the bug is still open and accepted in the end?") forced a re-verification. Building `origin/10.6` reproduced the crash on the first try. This validates the *kind* of error the skill needs to defend against — and revealed that the original Phase 4 "Does not crash → report blocked" path was too permissive: it allowed declaring victory on the wrong branch.

## Skill updates applied as a result

### Phase 4 — replaced "Blocked outcomes" with "Reproducer doesn't fire" decision tree
The old text said "if it doesn't crash, comment on JIRA and stop." The new text says:
1. JIRA status is the ground truth — Confirmed means real, regardless of your local repro
2. Look in comments for the **exact crash revision** the reporter named
3. **Build the branch the reporter saw the crash on**, not just `fixVersions[0]`
4. If the bug only crashes on an older branch, document the "masking change" gap — the fix on `fixVersions[0]` will need either a different reproducer or a `DBUG_EXECUTE_IF` route
5. Never write a defensive patch for an unreproducible bug

### Rationalizations table — added two entries
- "The reproducer doesn't crash on my target branch, so the bug is fixed" — wrong on two counts (fixVersions ≠ current state; older branches commonly still crash).
- "The JIRA's Confirmed status is old, maybe it really is fixed" — senior-maintainer assignment is high-signal; trust the JIRA state more than your absent repro.

### The skill-anti-pattern note
Added an inline "Skill anti-pattern from validation run" callout in Phase 4 documenting *exactly the mistake I made* during the validation run, with both the false conclusion and the corrected one.

## Second-run validation — fresh subagent on MDEV-38034

After the MDEV-23676 walk-through and the corrected-conclusion fixes, a fresh subagent was dispatched on **MDEV-38034** (Critical InnoDB regression — `SET transaction_read_only=0` after `HANDLER OPEN` desyncs `thd->tx_read_only` from `trx->read_only`). The subagent had only `Read`/`Bash`/`Grep`/`Glob` tools and was instructed to walk Phases 1–5 honestly. It worked.

| Phase | Subagent outcome |
|---|---|
| 1. Discover | Worked. `fetch-mdev.sh` clean; jq extractions ran as-is; root cause identified from Marko Mäkelä's 2025-11-06 JIRA comment. |
| 2. Plan | Worked. Target 11.8 (lowest `fixVersions`); test home identified as `mysql-test/main/trans_read_only.test`, NOT `suite/innodb/` — see issue below. |
| 3. Branch + build | Worked. 6-min Ninja build with `-DWITH_INNODB_EXTRA_DEBUG=ON`. Hit one snag: an uncommitted `.claude/review/commit-and-process.md` modification (left over from the same-session walk-through) blocked the initial `git checkout`. |
| 4. Reproduce | Worked **first try**, no mutation needed. The JIRA's 6-statement reproducer crashed with the exact assertion at `row0ins.cc:3447`. |
| 5. Investigate | Worked. 90-minute investigation produced 4 fix options + chosen direction (tighten `check_tx_read_only` predicate in `sql/sys_vars.cc`). |

Five **substantial** skill issues found:

### Issue A (critical) — `.claude/review/` only on local `main`
The skill's whole rulebook (`checklist.md`, `commit-and-process.md`, `innodb.md`, …) was added in our local `main` commit `a662a237b48`. It is NOT on `origin/main` or any release branch. When Phase 3 runs `git checkout origin/11.8`, the entire `.claude/review/` directory disappears from the working tree. Every subsequent phase's "load X" reference becomes a dangling link.

**Fix applied**: added **Phase 0 — branch-portable rulebook setup**. Caches `.claude/review/*.md` from `$MFIX_REVIEW_REF` (default `main`) into `$WORK_DIR/rulebook/` via `git show`. Subsequent phase references resolve through that cache. Also added a sanity check that fails fast if the rulebook isn't on the chosen ref.

### Issue B (medium) — merge-commit "regression-introducing commits"
MDEV-38034's named regression commit is the 11.4→11.8 forward merge — reading it is useless. The skill said "read the regression-introducing commit end-to-end" without addressing this case.

**Fix applied**: Phase 1 now detects when the commit has two parents and instructs to look in JIRA comments for a narrower bisection, or `git bisect` on the merged-from branch between the merge base and the merge parent, or document and defer.

### Issue C (medium) — test-home heuristic over-weights stack location
The skill said "components + stack-trace files → test directory". For MDEV-38034 that would point at `suite/innodb/` because the crash is in `row0ins.cc`. The actual right home is `mysql-test/main/trans_read_only.test` because the *fix* is SQL-layer.

**Fix applied**: Phase 2 now states the exception explicitly: "when the bug is in SQL-layer state (THD/sysvars/parser/ACL) but the crash fires inside an engine, the test belongs near the fix-site code, not the crash-site code."

### Issue D (medium) — stack-trace line numbers drift
JIRA reported `row0ins.cc:3442`; current source has the assertion at `row0ins.cc:3447`. The skill's grep-by-`path:line` pattern in Phase 1 could mislead a strict reader.

**Fix applied**: Phase 1's notebook-capture step now says: "Treat line numbers as advisory — they routinely drift. The function and expression are stable; grep by those, not by line number." Same applied to the regression-test naming anchor.

### Issue E (small) — pre-checkout cleanliness + `mariadb-test-run.pl` name
Subagent hit a `git checkout` failure due to a stray uncommitted file, and noted that 10.x has a `mysql-test-run.pl` alias to remember.

**Fix applied**: Phase 3 now opens with a `git stash` snippet to clear the working tree before checkout. Phase 4's test-layout section now lists both `mariadb-test-run.pl` (11.x+) and `mysql-test-run.pl` (10.x) names. `--debug-server` warning hoisted to the test-layout section so it can't be missed.

## What the second-run validation got right

- **The subagent reached a defensible Phase-5 design note** without any human in the loop. 90 minutes from "MDEV number" to "I'd change `check_tx_read_only` in `sql/sys_vars.cc` and add a test in `mysql-test/main/trans_read_only.test`".
- **It refused to skip the linked-MDEV fetch** even when the description seemed complete — and the linked MDEVs turned out to confirm no prior fix existed.
- **It reproduced the bug on the first try** with no SQL mutation. The skill's instruction to use the JIRA description's exact reproducer is good.
- **It correctly distinguished**: even though the crash is in InnoDB, the bug is SQL-layer; even though `innodb.md` is comprehensive, it wasn't the right ruleset for this fix. The skill's "load InnoDB doc when touching `storage/innobase/*`" heuristic correctly excluded it.

## Skill issues discovered (ordered by impact)

### 1. Phase 1 — regression-introducing MDEV is in description text, not `.links[]`
**Impact**: medium. A fresh agent will miss the prior context if they only iterate `.links[]`.
**Evidence**: MDEV-23676's description names the regression commit `ae33ebe5b32a82629a40e51c8d6c6611842fbd03` (MDEV-23525). MDEV-23525 is *not* in JIRA's `issuelinks`.
**Fix**: add to Phase 1 deliverable: *"If the description names a regression-introducing commit, run `git log -1 --format='%H %s' <hash>` against `origin/<branch>` for each fix-version branch and extract the MDEV from the subject. Treat that MDEV as if it were a linked one."*

### 2. Phase 1 — no standardized location for the working notebook
**Impact**: low (operational hygiene). I used `/tmp/mfix-test/`. A fresh agent will invent a new ad-hoc path.
**Fix**: prescribe `WORK_DIR="${MFIX_WORK_DIR:-$HOME/.cache/mfix/$TICKET}"; mkdir -p "$WORK_DIR"` at the top of Phase 1. Have `fetch-mdev.sh` honour this if `$MFIX_WORK_DIR` is set (or just let the caller redirect output).

### 3. Phase 2 — reviewer-area table lacks "Temporal Types / Data types"
**Impact**: low (the "prefer JIRA assignee" rule resolved it correctly), but the lookup table is the more discoverable source.
**Evidence**: MDEV-23676 component is "Temporal Types"; nearest table row is "ACL / vector / charset / server core → vuvova". Works in practice but reads like a fuzzy match.
**Fix**: add a row to `.claude/review/commit-and-process.md`'s reviewer-area lookup table: **"Temporal types / Data types / Type system" → `vuvova`** (with historical credit to `bar` = Alexander Barkov for older context).

### 4. Phase 3 — skill doesn't recommend Ninja
**Impact**: medium (a 12-min build via Ninja becomes a 25-30 min build via Make on the same hardware).
**Fix**: in the cmake invocation, add `-G Ninja` if `ninja` is on `$PATH`. Mention this explicitly as a "performance default" sub-step.

### 5. Phase 3 — system-package deps aren't pre-validated
**Impact**: low for this run (everything was installed), but a fresh checkout on a clean VM could fail 5 min into the cmake configure on a missing `libssl-dev`.
**Fix**: add a Phase 3 prereq step listing the dpkg/rpm package names per distro family (Ubuntu/Debian: `cmake gcc g++ ninja-build libssl-dev libncurses-dev libpcre2-dev bison libsystemd-dev pkg-config`; Fedora: `yum-builddep -y mariadb-server`). Cite `.gitlab-ci.yml` for the canonical Fedora deps.

### 6. Phase 4 — `t/$T.test` advice is wrong for the `main/` suite
**Impact**: high — fresh agent will hit a "No such file or directory" and lose 30+ seconds figuring it out, possibly more if they don't realize the build dir has no `mysql-test/main`.
**Evidence**: I literally hit this. `mysql-test/main/` has no `t/` subdir (only secondary suites do). Tests live in the **source tree** (`mysql-test/main/`), but `mtr` runs from the **build tree** (`build-*/mysql-test/`).
**Fix**: replace
> "Drop the reproducer into `t/$T.test`"
with
> "Write the reproducer to `mysql-test/main/MDEV_NNNNN.test` (note: `main` suite uses no `t/` subdir; secondary suites like `mysql-test/suite/innodb/t/` do). Tests live in the source tree; `mtr` is run from the build tree's `mysql-test/` directory."

### 7. Phase 4 — `--debug-server` confusion
**Impact**: small. I ran `./mariadb-test-run.pl --suite=main mdev_23676` (no `--debug-server`) and the assertion would *still* have fired because we built with `CMAKE_BUILD_TYPE=Debug`. So `--debug-server` is technically redundant on a debug build. But the skill prescribes it.
**Fix**: clarify — `--debug-server` is the flag to use a *separately-built* `mariadbd-debug` (which doesn't exist in a single-Debug-build setup). For our standard flow, omit it.

### 8. Build-log location is implicit
**Impact**: low. I redirected the build to `$BUILD_DIR/build.log` myself; the skill's command (`cmake --build ... -j$(nproc) -t minbuild`) sends output to the terminal.
**Fix**: prescribe `> "$BUILD_DIR/build.log" 2>&1 &` + a separate "tail the log to monitor" hint.

### 9. Skill doesn't say what to do after "blocked: cannot reproduce"
**Impact**: medium. The skill explicitly defines this as a stop state but doesn't define the next step (comment on the JIRA? bisect? just stop?).
**Fix**: add a "Blocked outcomes" section explaining the three escalation choices: (a) comment on the JIRA with the negative-reproduction evidence and ask QA to re-confirm; (b) `git bisect` between the last known-bad rev (from JIRA comments) and current head to find the implicit fix and propose closing the JIRA; (c) stop and report to the user. The skill should recommend (a) as the default for a Confirmed JIRA where the original reporter is the project's QA lead.

### 10. Validation method itself
**Impact**: meta. I walked the skill myself in the same session that wrote it — I'm biased toward "of course it works." The writing-skills doc prescribes a *fresh subagent* baseline test. That hasn't happened.
**Fix**: spawn a subagent on a *different* MDEV (preferably an InnoDB one to also exercise the area-specific guidance) with only `Read`/`Bash`/`Grep`/`Glob` tools and the skill file. See where it gets stuck.

## What worked notably well

- **`fetch-mdev.sh`** as a single command produced exactly the structured JSON the downstream phases needed. Reusable.
- **The stop-gates** held. "Don't proceed without a reproducer" is the central correctness check, and it was easy to recognise when to invoke it.
- **The "load the right review-guide files" delegation** kept the skill body short — the rule files do the heavy lifting.
- **The rationalizations table** matched the temptations I felt (specifically: "I can see the bug from the stack — let me just patch it" was a real urge when reproducers didn't crash; the skill explicitly forbade that).

## Build artifacts preserved

- `../build-10.11-debug/` (~3 GB, debug-build object cache + linked binaries) — kept for any subsequent iteration.
- `/tmp/mfix-test/{mdev-23676,mdev-29924,mdev-23525}.json` — the fetched JIRA payloads.

## Third-run validation — full Phase 5–8 dry run on MDEV-23676

After Run #1 (same-session) and Run #2 (fresh subagent) findings were folded back into the skill, a third validation run exercised **all** remaining phases (5–8) on the working `10.6-MDEV-23676` branch, using Option A (defensive truncate in `Time::to_native()`) as a *pedagogical* fix to test the workflow itself rather than to ship.

| Phase | Result |
|---|---|
| 5. Investigate | Wrote design note (mechanism, regression source, prior fix, A/B/C options, choice + rationale, backport caveat). ~30 minutes of code reading. |
| 6. Apply fix | 14-line diff in `sql/sql_type.cc::Time::to_native()`. Truncate fractional part to declared `decimals` before `my_time_packed_to_binary()`. Incremental rebuild ~30 s. Reproducer crash gone on first try. |
| 7. Test | Promoted ad-hoc test into `mysql-test/main/type_time_hires.test` with proper `--echo # MDEV-23676 …` / `--echo # End of 10.6 tests` framing. `mtr --record` produced a clean diff. Wider local suite (12 time-tests + 5 group-by/func-group tests) green; no `.result` drift. |
| 8. Commit | Single squashed commit on `10.6-MDEV-23676`, subject 61 chars, body wrapped at 72. Commit message follows the project's "what was wrong / what causes it / what the fix does / what's NOT affected" structure. **No push, no PR.** |

### Skill issues found in Phases 6–8

- **Issue F (medium) — Phase 7 suite-enumeration**: hit "Could not find 'XYZ' in 'main' suite(s)" three times before finding the right test-file names (`greatest_least`/`innodb_misc` are not real names; `func_group`/`group_by`/`type_time` are). **Fix applied**: Phase 7 now suggests `ls mysql-test/main/ | grep -iE '<keyword>'` to enumerate first, and notes `mtr --do-test=<prefix>` as a forgiving alternative.

- **Issue G (medium) — End-of-version footer style**: `testing.md` (citing vuvova) says "one line, not three." But MDEV-29924's accepted fix and the existing `type_time_hires.test` use a 3-line `--echo #` / `--echo # End of M.m tests` / `--echo #` frame. Mixing within a file is worse than either. **Fix applied**: `testing.md` now clarifies "match the file's existing footer style" — the "one line" rule means no decorative `==`/`--` bars, not removing the frame.

- **Issue H (small) — sanity-probe the prior bug**: before Phase 7's wider suite, manually verified the *original* MDEV-23525 bug (string-vs-numeric MIN/MAX of TIME) stays fixed. The defensive truncate could in principle reintroduce that — it doesn't, but the test wasn't in the skill. **Fix applied**: Phase 6 now prompts "before Phase 7, also run a sanity probe against the bug the regression-introducing commit was *fixing*."

- **Issue I (small) — explicit length verification in Phase 8**: skill says "≤70 / ≤72" without showing how to verify. **Fix applied**: added the `git log -1 --format='%s' | awk '{print length}'` + `git log -1 --format='%b' | awk 'length>72'` one-liners.

- **Issue J (small) — ad-hoc → permanent test transition**: Phase 4 creates `mysql-test/main/MDEV_NNNNN.test`; Phase 7 wants the test in `type_time_hires.test`. The deletion + integration step was implicit. **Fix applied**: Phase 7 now opens with `rm -f mysql-test/main/${TICKET//-/_}*.test`, then "integrate into the existing test file identified in Phase 2, immediately before any trailing `--echo # End of X.Y tests` frame for an earlier branch."

### What Phase 6–8 got right

- **Incremental rebuild target** (`cmake --build "$BUILD_DIR" -j$(nproc) -t mariadbd`) was correct — only relinked the changed TU, ~30 s vs ~12 min full rebuild.
- **`mtr --record`** did exactly what the skill said it would: scanned the modified test, ran it, generated the new `.result` block in place. Diff was easy to read.
- **The commit-message template** wrote naturally: 61-char subject, body wrapped at 72, with the verbatim assertion + reproducer + mechanism + "what's NOT affected" structure.
- **The pre-checkout stash workflow** (added after Run #2) worked cleanly across the 10.6 ↔ main switches.

Total elapsed Phases 5–8: ~50 minutes including code reading.

## Fourth-run validation — automated review on the dry-run commit

After Runs #1–#3 the skill ended at Phase 8 with a clean local commit and no further review step. A fourth validation run dispatched the **pr-review-toolkit** agents on commit `5ed1bc1bc72` in parallel — exactly the gap a user pointed out when asking "did we run code review on top of that commit?"

| Agent | Verdict | Time |
|---|---|---|
| `pr-review-toolkit:code-reviewer` | **request-changes / block** | ~7 min |
| `pr-review-toolkit:silent-failure-hunter` | **correctness blocker confirmed numerically** | ~7 min |

### What the agents caught that my Phase-1-8 walk missed

1. **Negative-TIME data corruption (blocker, verified numerically).** My defensive truncate composed `MY_PACKED_TIME_MAKE(MY_PACKED_TIME_GET_INT_PART(tmp), (frac/divisor)*divisor)`. The two getter macros use inconsistent sign semantics (`>>` floors, `%` truncates toward zero); the composition is *not* the identity for negative inputs. The silent-failure-hunter built a C harness and verified that `-01:00:00.123456` truncated to 3 digits produces on-disk bytes `7F EF FE FB 32` which decode to `-01:00:01.123000` — off by one second. The canonical writer would produce `7F EF FF FB 32`.

2. **Replication byte divergence (blocker).** The same input via `Field_timef::store_TIME` produces different bytes from my path's output. `cmp_native` short-circuits on `memcmp`, so the two compare unequal. ROW replication propagates the wrong bytes; mixed-version STATEMENT replication can diverge.

3. **Architectural violation of project-documented rule (blocker).** I violated `.claude/review/api-and-architecture.md`'s **"don't widen utility APIs to accept invalid inputs — fix the caller"** rule that I wrote myself two days earlier. The Timestamp sibling path at `sql_type.cc:9363-9374` already does `tm.trunc(decimals)` at the caller before `to_native()`. The missing call site for the Time path is at `sql_type.cc:9326/9343` — that's where Option B's fix would live.

4. **Test inadequacy (important).** The regression test exercises only the assertion-doesn't-fire path. Every result is NULL. Negative-TIME corruption was never exercised. A defensive-truncate fix needs negative-TIME coverage; a caller-side metadata fix doesn't have this footgun.

5. **Pattern continuity violated (blocker).** The prior fix (MDEV-29924, same assertion, same assignee — vuvova) used B-style. Picking A in spite of that was rationalization on my part: "smaller is easier for me to write."

### Honest meta-finding

I picked Option A because it was *operator-easy*, not *project-correct*. My Phase-5 design note acknowledged that Option B was probably what vuvova would prefer, then implemented A anyway. The skill's Phase 5 said "consider asking" — too soft. **A single-operator walk through Phases 1–8 is not sufficient even with the rulebook loaded**: the rulebook is consulted at the right moment but the operator can still rationalize past it. The pr-review-toolkit agents have no operator bias and apply the rulebook mechanically.

### Skill updates from Run #4

- **Sharpened Phase 5**: added explicit *"sibling path already does B"* check (step 4), *"pattern continuity is a strong default"* (step 6), and a *"don't pick A just because A is smaller to write"* stop-gate (step 7). Phase 5 deliverable now requires articulating *why a sibling-pattern fix would be wrong for this case* if Option A is picked.
- **New mandatory Phase 7.5 — Automated review** with concrete `Agent(...)` calls for `pr-review-toolkit:code-reviewer` and `:silent-failure-hunter`, parallel dispatch, blocker triage, deliverable spec.
- **Workflow header** revised: now 9 phases (1, 2, 3, 4, 5, 6, 7, 7.5, 8) — explicit Phase 7.5 in the diagram.
- **Quick-reference table** has 7.5 row.
- **Rationalizations table** has three new entries: "Option A is smaller, skip JIRA discussion" / "Phase 7.5 is overkill, I read my own diff" / "test against bug's symptom, not fix's edge cases" — each citing the Run #4 measured outcome.

### What this means for the skill's design philosophy

The original mfix design said "the rulebook is what protects against bad decisions." Run #4 disproved that. The rulebook + operator self-discipline together is *not* enough; a separate set of eyes (even an automated one) is required. The skill now treats the pr-review-toolkit run as **as load-bearing as the build itself** — same severity as "Phase 4 must reproduce" or "Phase 7 must be green." Without it, you're shipping the bug you're trying to fix.

## Recommended next moves

1. ✅ Apply Run #1 high-impact skill fixes (target-branch verification, no-repro doesn't mean fixed) — done.
2. ✅ Run a fresh-subagent test on a different MDEV to find issues invisible from same-session — done (MDEV-38034).
3. ✅ Apply Run #2 critical fix (Phase 0 rulebook caching) — done.
4. ✅ Exercise Phases 5–8 end-to-end on a known-crashing reproducer to validate the test/commit workflow — done.
5. ✅ Run pr-review-toolkit agents against the dry-run commit; sharpen Phase 5 gate + add mandatory Phase 7.5 — done.
6. **Outstanding**: comment on MDEV-23676 with the analysis (bug crashes on 10.6 head; masked on 10.11; what to do about the fixVersions mismatch).
7. **Outstanding**: dispatch one more subagent test on a *replication* or *Galera* MDEV to exercise the reviewer-table routing in those areas, which no validation run has touched.
8. **Outstanding**: discard / amend the dry-run commit `5ed1bc1bc72` on `10.6-MDEV-23676` so the broken Option-A patch isn't preserved as if it were real. (Or amend it to Option B for a clean record.)
