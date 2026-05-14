# Claude Documentation Rollout Plan

> **Goal:** Make Claude agents materially faster and more accurate at MariaDB Server work by adding nested per-subsystem CLAUDE.md files, reusable playbooks for common task categories, and cross-cutting reference docs — sized so each one is loaded only when relevant.

**Date:** 2026-05-14
**Owner:** this session and follow-ups
**Pre-reads:** the recommendations sent in chat earlier today; the existing `.claude/review/` rulebook; `CLAUDE.md` at the repo root.

---

## Scope (9 phases)

| Phase | Deliverables | Why this order |
|---|---|---|
| 1 | `sql/CLAUDE.md`, `storage/innobase/CLAUDE.md`, `mysql-test/CLAUDE.md` | 80% of agent-visit volume; highest token savings. |
| 2 | `.claude/reference/glossary.md`, `.claude/reference/branches-and-forward-merges.md` | Small, broadly cited; eliminates "what is X" questions. |
| 3 | Top 5 playbooks (sysvar, sql-function, error-message, mtr-test, forward-merge) | Cover ~50% of incoming work types. |
| 4 | Tier 2 deep references under `sql/docs/` (item-system, optimizer, replication, parser) | Loaded on demand from `sql/CLAUDE.md`. |
| 5 | Remaining `sql/docs/` (charset, ACL, SP) + cross-cutting refs (memory, errors, threading, debug) | Long tail; finishes the depth coverage. |
| 6 | `.claude/skills/mforward/` (optional) | Phase-gated workflow for forward-merges if the playbook isn't enough. |
| 7 | Lower-priority subsystem CLAUDE.md (`plugin/`, `client/`, `extra/mariabackup/`) | Only as need surfaces in practice. |
| 8 | mfix Phase 1 update — leverage nested CLAUDE.md instead of greping cold | Reduces mfix's per-bug token cost once nested docs exist. |
| 9 | Final mfix regression validation | Confirm Phase 8 didn't regress mfix on a known-MDEV. |

---

## Conventions (apply to every doc)

### Frontmatter

Every doc starts with this YAML frontmatter:

```yaml
---
applies-to: main
last-verified: 2026-05-14
source-of-truth: <code paths the doc summarises>
---
```

- `applies-to`: the branch this doc targets. mfix's rulebook-cache pattern (`${MFIX_REVIEW_REF:-main}`) already snapshots from `main` per-bug-fix, so docs target `main` by default.
- `last-verified`: the date someone last walked the doc against the code. Stale docs are worse than missing docs — this is the staleness check.
- `source-of-truth`: comma-separated list of the canonical code paths this doc summarises. The "what to grep when refreshing" pointer.

### Audit-trail section

Every doc ends with a `## How this doc was built` section:

- Files surveyed (with commit SHAs)
- Commands run to confirm structure
- What was deliberately excluded
- How to refresh (one-line update procedure)

Same pattern as `.claude/pr-research/vuvova/README.md`.

### Cross-references

- Subsystem CLAUDE.md → link to `sql/docs/<topic>.md` and `.claude/reference/<topic>.md` by relative path.
- Playbooks → link to the subsystem CLAUDE.md for "Where to look first" and the reference for "What X means".
- Reference docs → link to canonical code paths via `[name](sql/foo.cc)` style.
- Cite real MDEVs and PRs as examples — same pattern as `.claude/review/*.md`.

### Subsystem CLAUDE.md template

```
---frontmatter---

# <Subsystem name> — Claude agent overview

<1-paragraph: what this subsystem does, where it sits>

## Map of files

| Cluster | Files | Purpose |

## Key invariants
## Common patterns
## Where to start (per task)
## Pitfalls (cite MDEVs)
## See also (cross-references)
## How this doc was built
```

### Playbook template

```
---frontmatter---

# Playbook: <task name>

**Use when:** <one sentence>
**Skip if:** <one sentence>
**Typical effort:** <e.g., 1-3 hours>

## Overview
## Files you'll touch (with role)
## Steps (numbered, ordered)
## Examples from past PRs (cite MDEVs)
## Pitfalls and rejection patterns
## Validation
## How this doc was built
```

### Reference doc template

```
---frontmatter---

# Reference: <topic>

## TL;DR (3-5 bullets)
## Concepts
## Rules (the "must do / must not do" list, each cited)
## Recipes (small worked examples)
## See also
## How this doc was built
```

---

## Validation per deliverable

For every doc in Phase 1–5 (the load-bearing ones), run a **fresh-subagent self-sufficiency test** before accepting it:

1. Pick one realistic agent task that should be answerable from the doc alone.
2. Dispatch a no-context subagent. Provide ONLY the doc and the task; forbid reading anything else under `.claude/` or `sql/docs/`.
3. Have it execute or describe the steps.
4. Note any place the subagent had to guess, invent, or get stuck.
5. Fold corrections back into the doc inline. Re-test if changes are non-trivial.

Same pattern as `mreview/SKILL_VALIDATION.md` Run 3, which surfaced a real Agent-tool precondition gap.

Tier 6/7 docs (smaller subsystems, mforward skill) can skip the fresh-subagent test if effort isn't justified.

---

## Phase 1 — Nested CLAUDE.md for hot subsystems

### Task 1: `sql/CLAUDE.md`

**Length target:** 300-400 lines.
**Sources to survey:**
- `sql/` directory listing (551 files)
- Hot files identified in churn report: `sql_select.cc`, `sql_yacc.yy`, `sql_class.h`, `sql_lex.cc`, `sql_table.cc`, plus item*, opt_*, rpl_*, sp_*
- Root `CLAUDE.md` § "Code layout"
- `.claude/review/api-and-architecture.md`, `.claude/review/coding-style.md` (for invariants)
- Recent commit subjects in `sql/` (12 months)

**Outline:**
1. Frontmatter
2. 2-paragraph "what sql/ is for"
3. Map of file clusters (parser / dispatch / optimizer / items / table-field-types / handler / replication / SP / ACL / plugin host / WSREP) — each cluster a short table with files and one-sentence purpose
4. THD lifecycle and `current_thd` rule
5. Prepared-statement re-execution model (one of the most error-prone areas, per Item rewrite phases)
6. MEM_ROOT vs heap (when to use which)
7. `my_error()` vs `push_warning_printf()` vs `sql_print_error()` (with citation back to `.claude/review/logging-and-errors.md`)
8. Where to start, by task type:
   - Add a SQL function → see `[playbook](.claude/playbooks/add-sql-function.md)`
   - Add a sysvar → see `[playbook](.claude/playbooks/add-system-variable.md)`
   - Fix optimizer bug → see `[sql/docs/optimizer.md](sql/docs/optimizer.md)`
   - Replication change → see `[sql/docs/replication.md](sql/docs/replication.md)`
   - Parser change → see `[sql/docs/parser.md](sql/docs/parser.md)`
   - Stored programs → see `[sql/docs/stored-programs.md](sql/docs/stored-programs.md)`
9. Pitfalls (cite real MDEVs from `.claude/pr-research/`)
10. See also: `.claude/review/*.md`, root `CLAUDE.md`
11. How this doc was built

**Validation task:** dispatch a subagent with only this doc and ask: "I need to add a new built-in SQL function `BAR(x)` that returns `x*2`. Which files should I touch, in what order, and what's the typical structure?"

**Expected reaction:** subagent reads the file-map, follows the "add a SQL function" pointer, and proposes touching `item_create.cc` (factory), a new `Item_func_bar` subclass in an appropriate `item_*.{cc,h}` file, and a new mtr test. If the subagent gets lost or invents files, the doc has gaps.

### Task 2: `storage/innobase/CLAUDE.md`

**Length target:** 250-350 lines.
**Sources to survey:**
- `storage/innobase/` directory structure (263 files in 14+ subdirs)
- Hot files: `ha_innodb.cc`, `buf0buf.cc`, `fil0fil.cc`, `srv0start.cc`, `log0recv.cc`
- Existing internal docs in tree: check for `storage/innobase/README*` and `*.md`
- `.claude/review/innodb.md`

**Outline:**
1. Frontmatter
2. 2-paragraph "what InnoDB is in MariaDB"
3. Subdir map (buf/, fil/, log/, trx/, dict/, page/, btr/, row/, srv/, ibuf/, lock/, ut/, etc.)
4. The SQL↔InnoDB bridge (`ha_innodb.cc`, handlerton, conversions)
5. Latch hierarchy + lock-order rule (where to look; not paraphrase)
6. mtr_t (mini-transaction) conventions
7. `dberr_t` propagation and error mapping
8. Page format and version compatibility
9. Redo log format gotchas (with pointers — this is genuinely subtle)
10. Buffer-pool and I/O subsystem entry points
11. Where to start (per task type)
12. Pitfalls (cite MDEVs from churn data)
13. See also
14. How this doc was built

**Validation task:** "I need to add a new InnoDB system variable controlling buffer pool prefetch. What files do I touch and in what order?"

### Task 3: `mysql-test/CLAUDE.md`

**Length target:** 150-250 lines.
**Sources to survey:**
- `mysql-test/` directory structure
- `mysql-test/mariadb-test-run.pl` (the driver) — at least the option list
- Existing `mysql-test/README*` if any
- `.claude/review/testing.md`

**Outline:**
1. Frontmatter
2. 2-paragraph "how MTR works"
3. Directory layout (main/, suite/<name>/, std_data/, include/, collections/, disabled-lists)
4. Naming and file conventions (`.test`, `.result`, `-master.opt`, `.combinations`, `.rdiff`)
5. Common include files (`have_innodb.inc`, `have_debug.inc`, ...)
6. Recording results (`./mtr --record`)
7. Common runtime flags: `--big-test`, `--mem`, `--parallel`, `--rr`, `--gdb`, `--valgrind`, `--manual-gdb`, `--extern`
8. DEBUG_SYNC patterns + small examples
9. Skip-list discipline (`disabled.def`, `disabled-*.list`, `skip_list_ubsan.txt`)
10. Where new tests go (per task type)
11. Pitfalls (citing MDEVs from .claude/review/testing.md)
12. See also
13. How this doc was built

**Validation task:** "Write a test for a new SQL function `BAR(x)` that returns x*2. Cover the happy path, NULL handling, and run with a non-default sql_mode."

---

## Phase 2 — Cross-cutting reference (cheap, broad)

### Task 4: `.claude/reference/glossary.md`

**Length target:** 100-180 lines.

Definitions for: MDEV, JIRA workflow, WSREP, GTID, mariadbd vs mysqld, embedded server, "maintained branches" + their numbers, forward-merge chain, semisync, parallel replication, RBR/SBR/MIXED, "the rulebook", `.opt` vs `.combinations`, the `BUILD/` scripts, sanitizer abbreviations, `mtr` shorthand, `THD`, `MEM_ROOT`, prepared-statement vs stored-program memory, `MYSQL_TIME`, "native" format, `LEX_STRING`/`LEX_CSTRING`, "share" (TABLE_SHARE), DBUG, `--debug` flag forms.

### Task 5: `.claude/reference/branches-and-forward-merges.md`

**Length target:** 80-150 lines.

- The branch policy with concrete release numbers as of today's date
- The forward-merge chain (10.6 → 10.11 → 11.4 → 11.8 → 12.x → main)
- "Where does this fix belong" decision tree
- How to do a forward-merge mechanically (no-edit merge commits, conflict resolution norms — see `commit-and-process.md`)
- What to do when a merge needs intervention vs when to leave it
- Common merge-time mistakes (cite MDEVs)
- Cross-link to forward-merge playbook (Phase 3)

---

## Phase 3 — Top 5 playbooks

Each playbook follows the template above. Length target: 100-200 lines each.

### Task 6: `.claude/playbooks/add-system-variable.md`
Files: `sql/sys_vars.cc`, the using `.cc` file, optionally `handler.h` for a HA_* flag, a sysvar test in `mysql-test/suite/sys_vars/`.

### Task 7: `.claude/playbooks/add-sql-function.md`
Files: a new `Item_func_<name>` in an existing `item_*.cc` cluster, `item_create.cc` factory entry, `sql/sql_yacc.yy` only if a new keyword is needed, MTR test.

### Task 8: `.claude/playbooks/add-error-message.md`
Files: `sql/share/errmsg-utf8.txt`, the `my_error()` call site, the test `.result` file diffs.

### Task 9: `.claude/playbooks/add-mtr-test.md`
Where to put the test (suite vs main), naming, `.opt`/`.combinations` decisions, recording results, common include files, debugging a failing test.

### Task 10: `.claude/playbooks/forward-merge.md`
Mechanics, conflict resolution norms, when to involve a release manager, what the "Merge X into Y" commit body should and shouldn't contain.

---

## Phase 4 — Tier 2 deep references under `sql/docs/`

Each 200-400 lines. Loaded on demand from `sql/CLAUDE.md`.

### Task 11: `sql/docs/item-system.md`
Class hierarchy (`Item` → many), `fix_fields`, `val_*` family, `Type_handler` interaction, when to subclass which base, how `Item_cache` and `Item_ref` work.

### Task 12: `sql/docs/optimizer.md`
Phase ordering: parse → setup → fix_fields → JOIN::prepare → JOIN::optimize → ... → JOIN::exec. Materialization, semi-join flattening, derived-table merging, range optimizer entry, partition pruning. Pointers into `opt_*.cc`.

### Task 13: `sql/docs/replication.md`
Binlog format, log_event types, slave SQL thread structure, parallel applier model, GTID, WSREP integration, MIXED-mode pitfalls.

### Task 14: `sql/docs/parser.md`
`sql_yacc.yy` vs `sql_yacc_ora.yy` (Oracle compat), `lex.h` keyword tables, `gen_lex_hash.cc`/`gen_lex_token.cc` regeneration, how to add a keyword without breaking existing queries, %prec tricks for conflict resolution.

---

## Phase 5 — Remaining + cross-cutting refs

### Task 15: `sql/docs/stored-programs.md`
sp_head, pcontext, rcontext, instr, the compile-vs-execute model.

### Task 16: `sql/docs/acl-and-privileges.md`
The grant tables, in-memory ACL caches, role hierarchy, when ACL is rebuilt vs invalidated.

### Task 17: `sql/docs/charset-and-collation.md`
CHARSET_INFO, collation derivation rules, the `String` class, `m_ctype.h` API, common bug patterns.

### Task 18: `.claude/reference/memory-management.md`
MEM_ROOT, `alloc_root`, prepared-statement re-execution, PROTECT_STATEMENT_MEMROOT, `my_safe_alloca`, the "free vs hand-back" rule.

### Task 19: `.claude/reference/error-handling.md`
`my_error` vs `push_warning_printf` vs `sql_print_error` vs `print_to_log`, `Sql_condition`, error throwing vs setting, `THD::is_error()`, OOM handling.

### Task 20: `.claude/reference/threading-and-locks.md`
THD per-thread invariant, background threads, `mysql_mutex_*` vs raw pthread, `SAFE_MUTEX`, atomic helpers.

### Task 21: `.claude/reference/debug-tooling.md`
DBUG macros, `--debug=…` flag forms, DEBUG_SYNC, `BUILD/compile-*` scripts, mtr `--rr`/`--gdb`, useful gdb commands and pretty-printers, sanitizer triage.

---

## Phase 6 — Optional: `mforward` skill

Only build if the Phase 3 forward-merge playbook turns out to be insufficient.

If built, mirror `mfix`/`mreview` shape: phase-gated workflow with deliverable checks, `lib/` helpers, plain-bash tests, 4-run validation.

Decision gate: after running the playbook on 2-3 real forward-merges, decide if a skill is warranted.

---

## Phase 7 — Lower-priority subsystem CLAUDE.md

Only write when an agent actually visits these in anger. Candidates: `plugin/CLAUDE.md`, `client/CLAUDE.md`, `extra/mariabackup/CLAUDE.md`. Each ~100-200 lines.

Per-reviewer profiles (Tier 2 of the original mreview design): write after a real GH-PR run on a multi-reviewer PR surfaces profile-contradiction needs.

---

## Phase 8 — mfix Phase 1 update

Once Phase 1 docs are live, mfix Phase 1 ("Discover") currently spends tokens greping cold. Update it to:

1. Always read the affected subsystem's `CLAUDE.md` first (if it exists).
2. Then check `.claude/playbooks/` for a matching task type.
3. Only then do grep-based exploration.

Concrete edit: replace mfix `SKILL.md` Phase 1's exploration guidance with a two-step "load context, then explore" pattern. The context-loading step is a 1-line table lookup, not a research project.

---

## Phase 9 — mfix regression validation

After Phase 8 lands, re-run the canonical mfix dry-run from this codebase's history (MDEV-23676 is the gold-standard). Confirm:

- Same root cause identified
- Same fix family chosen (Option B via `my_time_trunc()`)
- Same Phase 7.5 outcome (Blocker if Option A; approve if Option B)

If the dry-run no longer produces the same Phase 5 reasoning, the mfix update has regressed. Investigate.

---

## Effort & sequencing

| Phase | Estimate (focused work) |
|---|---|
| 1 | 3-4 days (most of Phase 1 in this session is realistic if we drive through) |
| 2 | 1 day |
| 3 | 3-5 days (5 playbooks @ ~½-1 day each) |
| 4 | 4-6 days (4 deep references @ ~1-1.5 days each) |
| 5 | 5-7 days (7 docs @ ~½-1 day each) |
| 6 | 2-3 days if attempted |
| 7 | 1-2 days each, as needed |
| 8 | ½ day |
| 9 | ½ day |

**Suggested cadence:** land Phase 1 + Phase 2 in one session, validate, then take Phase 3 separately. Phases 4-5 can be parallelised if more than one of us is doing the work.

---

## Tracking

Tasks tracked in the session task list. As each doc lands, its commit subject names the phase: `docs(phase-1): add sql/CLAUDE.md`, `docs(phase-3): add add-sql-function playbook`, etc. Validation runs are documented either inline at the bottom of the doc (small) or as separate `*-validation.md` companions (large).
