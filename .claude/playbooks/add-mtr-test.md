---
applies-to: main
last-verified: 2026-05-14
source-of-truth: mysql-test/CLAUDE.md, .claude/review/testing.md
---

# Playbook: Add a new MTR test

**Use when:** you have added or changed behaviour in `sql/`, `storage/*`, or `plugin/*` that can be exercised through SQL — every bug-fix PR needs an MTR regression test ([`testing.md`](../review/testing.md) §"A test is required").
**Skip if:** the change is a pure refactor with no behaviour change, or you're modifying a C/C++ unit test (those use MyTAP under `unittest/`, not MTR — see root [`CLAUDE.md`](../../CLAUDE.md) §"Testing").
**Typical effort:** 30-60 minutes for a single-statement bug-fix test; 1-3 hours for multi-connection / replication / DEBUG_SYNC tests.

## Overview

MTR is record/replay against a `.result` file. You write a `.test` script (SQL + mysqltest directives), record its output with `./mtr --record`, then commit the test in the **same commit as the fix** so `git bisect` works. The two questions you spend the most time on are (1) which suite owns this and (2) extend an existing file or create a new one. Sections below answer both.

Always cross-load [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) (cheat-sheet, file shape, suite map) and [`.claude/review/testing.md`](../review/testing.md) (the rule set — every "do this" below is cited from there).

## Files you'll touch

| File | Role |
|---|---|
| `mysql-test/<suite>/t/<name>.test` (or `mysql-test/main/<name>.test`) | The mysqltest script. |
| `mysql-test/<suite>/r/<name>.result` (or `mysql-test/main/<name>.result`) | Recorded expected output. **Edited only via `./mtr --record`** in normal workflow ([`testing.md`](../review/testing.md) §"`mtr --record` — never hand-edit `.result`"). |
| `mysql-test/<suite>/t/<name>-master.opt` *(optional)* | One-line `mariadbd` arguments for this test. Use `--loose-` prefix for options that may not exist in embedded mode (PR4697). |
| `mysql-test/<suite>/t/<name>.combinations` *(optional)* | Multi-section combination matrix. Each `[name]` section is one run. |
| `mysql-test/<suite>/disabled.def` *(rare)* | Skip-list entry with mandatory MDEV reference. |

Note: `mysql-test/main/` is flat — `.test` and `.result` sit side-by-side, no `t/` / `r/` split.

## Steps

1. **Identify which suite owns the area.** Extends the per-task table in [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Where new tests go":

   | Topic | Suite |
   |---|---|
   | Server-core SQL (parser, optimizer, items, types) | [`mysql-test/main/`](../../mysql-test/main/) |
   | System variable visibility / range | [`mysql-test/suite/sys_vars/`](../../mysql-test/suite/sys_vars/) |
   | InnoDB functional behaviour | [`storage/innobase/mysql-test/innodb/`](../../storage/innobase/mysql-test/innodb/) (auto-discovered) |
   | InnoDB sysvar visibility | [`mysql-test/suite/sys_vars/`](../../mysql-test/suite/sys_vars/) **and** a functional test under `storage/innobase/mysql-test/innodb/` |
   | Replication (master/slave SQL behaviour) | [`mysql-test/suite/rpl/`](../../mysql-test/suite/rpl/) |
   | Binlog format / content | [`mysql-test/suite/binlog/`](../../mysql-test/suite/binlog/) |
   | Replication **status** variables | [`mysql-test/suite/rpl/`](../../mysql-test/suite/rpl/) — **not** `sys_vars` (PR4904) |
   | Encryption / key management | [`mysql-test/suite/encryption/`](../../mysql-test/suite/encryption/) |
   | Partitioning | [`mysql-test/suite/parts/`](../../mysql-test/suite/parts/) |
   | Galera | [`mysql-test/suite/galera/`](../../mysql-test/suite/galera/) (needs `--source include/have_wsrep.inc`) |
   | mariabackup | [`mysql-test/suite/mariabackup/`](../../mysql-test/suite/mariabackup/) |
   | GRANT / ACL | [`mysql-test/suite/grant/`](../../mysql-test/suite/grant/) |

   Wrong suite is a guaranteed review move (PR4766, PR4904).

2. **Decide: extend an existing test or create a new file?** Default to **extend** — reviewers consistently push back on small single-case new files (PR4706, PR4789, PR4811). Find the natural home:

   ```sh
   grep -lE '<feature>|<related-keyword>' mysql-test/main/*.test mysql-test/suite/*/t/*.test | head -10
   ```

   Examples: an `UPDATE ... RETURNING` bug → `mysql-test/main/update.test` (MDEV-39179 did this). A `CREATE TABLE` regression → `mysql-test/main/create.test`. A new function in the Oracle compat surface → `mysql-test/suite/compat/oracle/t/func_<name>.test`. Create a new file only for genuinely new features or for a crash repro that doesn't fit anywhere.

3. **Name the file** if creating new. Naming conventions ([`testing.md`](../review/testing.md) §"Naming and placement"):

   | Kind | Pattern | Notes |
   |---|---|---|
   | New function family | `func_<group>.test` | Lives in `mysql-test/main/`. |
   | New major feature | `<feature>.test` | E.g. `partition.test`, `vector.test`. |
   | New sysvar (visibility) | `<sysvar>_basic.test` | Always under `sys_vars/`. |
   | Per-bug crash repro | `<mdev-id>.test` | Only when it doesn't fit an existing file. |

   Subsystem-prefix rule: a binlog test is `binlog_<name>.test` so `./mtr --do-test=binlog_` selectors work (PR4710, PR4766).

4. **Write the `.test` file.** Shape (see [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"A `.test` file: 30-second tour" for a complete example):

   ```
   --source include/have_<feature>.inc      # skip guards first

   --echo #
   --echo # MDEV-NNNNN <one-line description>
   --echo #

   CREATE TABLE t1 (a INT, b INT);          # two rows minimum, see step 5
   INSERT INTO t1 VALUES (1, NULL), (2, 3);
   <the SQL that exercises the bug/feature>
   DROP TABLE t1;                            # clean up — PR4710

   --echo # End of 13.0 tests                # current main branch version, see VERSION
   ```

   Use `--echo` for the MDEV header, **not** a `#` source comment — `--echo` text lands in `.result` and survives merges (PR4711, PR4789, PR4804). For PS/SP-touching changes, copy the PS+SP skeleton from [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton" — both variants are mandatory (PR4433).

5. **Two rows minimum, nullable column when relevant.** The 1-row-is-const-table optimiser short-circuit silently makes broken tests pass (PR4505: *"Tables need to have two records to avoid the '1-row table is const table' code path."*). This is the same lesson the MDEV-39179 fix surfaced — see [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers". Recognisable data like `data1-data2-data3`, not pseudo-random gibberish (PR4883).

6. **`-master.opt` or `.combinations` decisions.**

   | Choose | When | Example |
   |---|---|---|
   | `<name>-master.opt` | A single set of server args needed for the whole test | `--default-storage-engine=Aria --loose-server-audit-events=connect` |
   | `<name>-slave.opt` | Slave-side args for an `rpl_` test | mirrors `-master.opt` |
   | `<name>.combinations` | Matrix runs (one `.test`, N `.result`s) | `[on] optimizer_switch=extended_keys=on / [off] optimizer_switch=extended_keys=off` (see [`mysql-test/main/innodb_ext_key.combinations`](../../mysql-test/main/innodb_ext_key.combinations)) |

   Restarting the server is expensive — keep `.opt` files lean (PR4633). Don't add a `.combinations` for a single regression case; extend an existing combination test instead (PR4706).

7. **Record the result.** From the **build directory**:

   ```sh
   cd <build>/mysql-test
   ./mtr --record <suite>.<test>       # e.g. ./mtr --record main.update
   ```

   `--record` runs single-worker (driver enforces this around line 1604 of [`mariadb-test-run.pl`](../../mysql-test/mariadb-test-run.pl)). **Diff the recorded output before committing** — auto-record on a buggy patch silently bakes the bug into `.result` (PR4706 gkodinov: *"Please don't just copy the lines. Please compile and actually run the test before pushing a new version."*).

8. **Run and verify.** Without `--record`:

   ```sh
   ./mtr <suite>.<test>                # must pass
   ./mtr --suite=<suite>               # surrounding suite — catches result-file collisions
   ```

   For replication tests, also exercise relevant `binlog_format` combinations: `./mtr --combination=row main.<test>` etc. when applicable. Verify the test **fails without your fix** (PR4549, PR4691) — revert your `sql/`/`storage/` change locally, re-run, confirm failure, then re-apply.

9. **Add to `disabled.def` if needed.** Only if the test is intentionally disabled (infrastructure not yet shipped, known intermittent). Format: `testname : MDEV-NNNNN <reason>` — the MDEV reference is mandatory ([`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Skip lists & disabled tests"). When the underlying fix lands, re-enable in the same PR.

10. **Commit.** The test goes in the **same commit** as the fix it covers. Reviewers reject "test in a separate commit" — it breaks `git bisect`. Commit message follows the project 50/72 rule with `MDEV-NNNNN ` prefix (root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree").

## Examples from past PRs

| MDEV | What | File touched | Notable |
|---|---|---|---|
| MDEV-39179 | `UPDATE ... RETURNING` NULL handling bug | Appended ~10 lines to [`mysql-test/main/update.test`](../../mysql-test/main/update.test) | Extended existing file; two-row table; `--echo # End of 13.0 tests` footer. Commit `9b325e1b7dc`. |
| MDEV-38202 | New read-only sysvar `init_rpl_role` | New [`mysql-test/suite/sys_vars/t/init_rpl_role_variable_basic.test`](../../mysql-test/suite/sys_vars/t/init_rpl_role_variable_basic.test) + `.opt` + `.result` | Standard `<sysvar>_basic` shape; needed `--source include/not_embedded.inc` (PR4904). Commit `1ca0cfacf5a`. |
| MDEV-22186 | InnoDB sysvar `innodb_buffer_pool_in_core_dump` | New sysvar test in `suite/sys_vars/` **and** functional test under `storage/innobase/mysql-test/innodb/` | The InnoDB-sysvar two-test pattern. Commit `b4bc43e5c19`. |
| MDEV-39500 | Replication regression (STRICT-mode slave) | Test under [`mysql-test/suite/rpl/`](../../mysql-test/suite/rpl/), not main | Replication-behaviour change → `rpl_` prefix mandatory. Commit `59dafb5f6c1`. |
| `innodb_ext_key.combinations` | Optimiser switch on/off matrix | [`mysql-test/main/innodb_ext_key.combinations`](../../mysql-test/main/innodb_ext_key.combinations) (extended file) | Canonical `.combinations` shape — 2 sections, one switch each. |

## Pitfalls and rejection patterns

Cite [`testing.md`](../review/testing.md) — these are real review rejections, not invented ones.

- **Test in a separate commit.** Bug-fix and its test share one commit. PR4549, PR4711 — breaks `git bisect`.
- **Single-row table.** Const-table short-circuit makes the test pass even when the bug is present. Use **two rows** (PR4505). See also [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers" for the MDEV-39179 case.
- **Missing PS/SP variant.** Every new SQL feature needs prepared-statement + stored-procedure coverage (PR4433). Skeleton: [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton".
- **Hand-editing `.result` to make a failure go away.** Use `./mtr --record` and **diff the output** (PR4455, PR4706, PR4712, PR4829).
- **Hard-coded timestamps / addresses / paths / PIDs.** Use `--replace_regex` / `--replace_column` (PR4455). But **don't mask the data being tested** — a regex stripping the value defeats the assertion (PR4829).
- **`--sleep N` or `SELECT SLEEP(N)` as synchronisation.** Use `--source include/wait_condition.inc` (with a 60s timeout — PR4874), `DEBUG_SYNC`, or `--ping`. Flaky CI is more expensive than the test (PR4421, PR4765, PR4804, PR4998).
- **Wrong version footer.** `--echo # End of <maj.min> tests` must match the **target branch**, not the branch you developed on. `End of 10.6 tests` on a `main` PR is a guaranteed reject (PR4569, PR4714, PR4904). For `main` today, `End of 13.0 tests` (see [`VERSION`](../../VERSION)).
- **`#` source-comment header instead of `--echo`.** `#` comments don't reach `.result` and get lost in merges (PR4711, PR4789, PR4804).
- **Wrong suite.** Replication status-var in `sys_vars/` (PR4904); `binlog_` test outside `binlog/` (PR4766); InnoDB test outside `storage/innobase/mysql-test/`.
- **Missing `DROP TABLE` / `--remove_file` / `RESET *` cleanup.** Subsequent tests inherit your fixtures and break unpredictably (PR4601, PR4710, PR4829).
- **Piggy-backing on another test's tables.** Tests must be self-contained — assume nothing, leave nothing behind (PR4601).
- **Missing `not_embedded.inc` when the test needs separate client connections** (PR4606, PR4904, PR4998). Use `--loose-` prefix on `.opt` options that may not exist in embedded mode (PR4697).
- **Broad `mtr.add_suppression()` regex** that swallows unrelated errors (PR4342).
- **Trailing whitespace / missing final newline.** Git complains, reviewers reject (PR4810, PR4829, PR4867).
- **Numeric error codes in `--error`.** Use the `ER_*` name — names are stable across versions, numbers aren't.

## Validation

The deliverable check:

```sh
cd <build>/mysql-test
./mtr <suite>.<test>            # must pass
./mtr --suite=<suite>           # must pass — catches result-file collisions
```

For replication tests with combinations: `./mtr --combination=row <suite>.<test>` etc. for each combination. Before submitting, **buildbot must be clean** across all platforms (amd64-gcc / -clang / -msan / -tsan / -ubsan / -asan, aarch64, ppc64le, s390x, Windows, macOS) — GitHub Actions / AppVeyor / GitLab CI are subsets (PR4811, PR4869, PR4918; [`testing.md`](../review/testing.md) §"Buildbot is mandatory").

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `c284c3789d3` (branch `main`).
- **Files surveyed:**
  - [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Directory layout", §"A `.test` file: 30-second tour", §"PS/SP variant skeleton", §"Recording results", §"Where new tests go", §"Skip lists & disabled tests" — cited heavily; not duplicated.
  - [`.claude/review/testing.md`](../review/testing.md) — every "pitfall" bullet cites a PR from here.
  - Root [`CLAUDE.md`](../../CLAUDE.md) §"Testing" — branch + commit-message conventions.
  - [`.claude/docs-plan/PLAN.md`](../docs-plan/PLAN.md) §"Phase 3 — Task 9" — the brief for this playbook.
  - [`.claude/reference/keyword-index.md`](../reference/keyword-index.md) — confirmed the playbook will be findable.
  - Real commits surveyed: `9b325e1b7dc` (MDEV-39179), `1ca0cfacf5a` (MDEV-38202), `b4bc43e5c19` (MDEV-22186), `59dafb5f6c1` (MDEV-39500), [`mysql-test/main/innodb_ext_key.combinations`](../../mysql-test/main/innodb_ext_key.combinations).
- **Deliberately excluded:** the full mysqltest directive reference (lives in [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"mysqltest directive cheat-sheet" and at https://mariadb.com/kb/), DEBUG_SYNC deep patterns (in [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns"), per-suite tour, unit-test (`unittest/`) workflow.
- **Refresh procedure:** when a new suite becomes hot or a PR introduces a new rejection pattern, add a row to §"Steps" step 1 / §"Pitfalls"; re-verify the `End of <maj.min>` example matches [`VERSION`](../../VERSION); bump `last-verified`.
