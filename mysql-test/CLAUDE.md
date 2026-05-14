---
applies-to: main
last-verified: 2026-05-14
source-of-truth: mysql-test/
---

# `mysql-test/` — Claude agent overview

MTR (the **MariaDB Test Run** framework) is MariaDB's integration test suite. A `.test` file is a script of SQL plus mysqltest directives (`--source`, `--echo`, `--error`, `--replace_regex`, `--exec`, `--let`, …); the driver spawns its own `mariadbd` instances in `var/` under the build directory, runs the script through the `mariadb-test` client, captures every line of stdout, and diffs it byte-for-byte against the expected `.result` file. A mismatch is a test failure. MTR owns the entire server lifecycle for the run — it does **not** use any system-installed `mariadbd` and will not collide with one.

The driver lives at [`mysql-test/mariadb-test-run.pl`](mariadb-test-run.pl) (~5800 lines of Perl). Legacy aliases `mtr`, `mysql-test-run`, and `mysql-test-run.pl` continue to work. Tests are invoked from the **build directory**, not the source tree:

```sh
cd <build>/mysql-test
./mtr alias                              # short-name lookup
./mtr main.alias                         # qualified suite.test
./mtr suite/rpl/t/rpl_invoked_features   # by relative path
./mtr rpl.rpl_invoked_features,mix       # with a named combination
```

> **Testing review rules (canonical):** [`.claude/review/testing.md`](../.claude/review/testing.md) — load before adding a new test or modifying an existing one.
> **Project-wide style and review rules:** [`.claude/review/README.md`](../.claude/review/README.md)
> **README in this directory:** [`mysql-test/README`](README) — short usage notes for system-installed test packages.

---

## Directory layout

| Path | Purpose |
|---|---|
| [`mysql-test/main/`](main/) | Server-core tests (3000+). The default suite. `.test` and `.result` files live **side by side** (no separate `t/` / `r/`). |
| [`mysql-test/suite/<name>/`](suite/) | Themed suites — `rpl/`, `innodb/`, `binlog/`, `galera/`, `encryption/`, `parts/`, `sys_vars/`, `funcs_1/`, `mariabackup/`, `wsrep/`, `versioning/`, `vcol/`, `json/`, … (50+ suites). Each typically has `t/` (test files), `r/` (result files), optionally `disabled.def`. |
| [`mysql-test/std_data/`](std_data/) | Shared fixture data: binlog dumps, key files, certificates, sample CSVs, encrypted tablespaces. |
| [`mysql-test/include/`](include/) | `.inc` helper files (~632 of them). Skip guards (`have_*.inc`), wait helpers (`wait_*.inc`), assertion helpers (`assert_*.inc`), replication boilerplate (`master-slave.inc`, `reset_master.inc`). |
| [`mysql-test/collections/`](collections/) | Named lists of tests for CI: `default.daily`, `default.push`, `default.weekly`, `default.experimental`, `smoke_test`. Plus skip lists: `disabled-daily.list`, `disabled-per-push.list`, `disabled-weekly.list`, `skip_list_ubsan.txt`. |
| [`mysql-test/lib/`](lib/), [`mysql-test/extra/`](extra/) | Driver internals (Perl modules: `My::Debugger`, `My::Config`, `My::SafeProcess`, …). Rarely edited. |
| [`mysql-test/mariadb-test-run.pl`](mariadb-test-run.pl) | The driver. |
| [`mysql-test/valgrind.supp`](valgrind.supp), [`asan.supp`](asan.supp), [`lsan.supp`](lsan.supp), [`purify.supp`](purify.supp) | Sanitizer / valgrind suppression files. |
| `storage/<engine>/mysql-test/` | Engine-bundled suites auto-discovered by mtr (e.g. `storage/innobase/mysql-test/innodb/`, `storage/maria/mysql-test/maria/`, `storage/rocksdb/mysql-test/rocksdb/`). |
| `plugin/<name>/mysql-test/` | Plugin-bundled suites. |

---

## File naming and conventions

| File | Format | Purpose |
|---|---|---|
| `<name>.test` | mysqltest script | The test logic. |
| `<name>.result` | expected output | Record/replay diff target. **Edited only by `./mtr --record`** in normal workflow. Reviewers reject hand-edited `.result` files. [`testing.md`](../.claude/review/testing.md) §"`mtr --record` — never hand-edit `.result`". |
| `<name>-master.opt` | one-line server args | Per-test `mariadbd` arguments (e.g. `--default-storage-engine=Aria --loose-server-audit-events=connect`). Restarting the server is expensive — keep restarts to a minimum, see [`testing.md`](../.claude/review/testing.md) §"Don't restart unnecessarily" (PR4633). |
| `<name>-slave.opt` | one-line server args | Slave-side args for replication tests. |
| `<name>.combinations` | multi-section INI | Combination matrix — runs the test once per `[name]` section. Example, [`mysql-test/main/innodb_ext_key.combinations`](main/innodb_ext_key.combinations): `[on] optimizer_switch=extended_keys=on / [off] optimizer_switch=extended_keys=off`. |
| `<name>,combo.rdiff` | unified diff | Per-combination delta from the base `.result` (e.g. `innodb_ext_key,on,unoptimized.rdiff`). |
| `<name>-master.sh` / `-slave.sh` | shell | Pre-test setup hooks. Rare; use only when an `.opt` file isn't enough. |
| `disabled.def` | list | Per-suite disabled-test registry — `testname : MDEV-NNNNN comment`. Reviewers require an MDEV reference; see [`testing.md`](../.claude/review/testing.md) §"`mtr --record` …" and the rulebook on disabling tests. |

Two project naming rules ([`testing.md`](../.claude/review/testing.md) §"Naming and placement"):

- **Prefix new test files with the subsystem name** so `--do-test=<prefix>` selectors work (PR4710: `mysql_<name>.test` for `mysql` client tests; `binlog_<name>.test` in the binlog suite).
- **Prefer extending an existing file** over creating a new combination + test pair for a single regression case (PR4706, PR4789).

---

## A `.test` file: 30-second tour

A real, complete debug-only example — [`mysql-test/main/alter_table_debug.test`](main/alter_table_debug.test):

```
--source include/have_debug.inc

--echo #
--echo # Start of 10.5 tests
--echo #

--echo #
--echo # MDEV-19612 Split ALTER related data type specific code in sql_table.cc to Type_handler
--echo #

SET sql_mode='STRICT_ALL_TABLES,STRICT_TRANS_TABLES,NO_ZERO_DATE';
CREATE TABLE t1 (a INT);
ALTER TABLE t1 ALGORITHM=COPY, ADD b INT NOT NULL;
DROP TABLE t1;
...
--echo #
--echo # End of 10.5 tests
--echo #
```

Key shape conventions ([`testing.md`](../.claude/review/testing.md) §"Headers and footers"):

- **Skip guards first** (`--source include/have_debug.inc`, `--source include/have_innodb.inc`, …).
- **`--echo` MDEV header**, not a `#` source comment — `--echo` lines land in the `.result` file and survive merges (PR4711, PR4789, PR4804).
- **`--echo # End of <maj.min> tests` footer** (one line, matching the file's existing footer style; PR4711, PR4743, PR4904). The marker matches the **target branch's** version (PR4569, PR4714).
- **Terminate the file with a trailing newline** (PR4810, PR4829, PR4867).
- SQL command parts UPCASE, identifiers lowercase ([`testing.md`](../.claude/review/testing.md) §"Test style").

---

## Common include files

The 600+ `.inc` files in [`mysql-test/include/`](include/) are the building blocks; reach for these instead of hand-rolling:

| Include | Purpose |
|---|---|
| [`have_innodb.inc`](include/have_innodb.inc), [`have_partition.inc`](include/have_partition.inc), [`have_perfschema.inc`](include/have_perfschema.inc) | Skip if the engine/feature isn't compiled in. |
| [`have_debug.inc`](include/have_debug.inc), [`have_debug_sync.inc`](include/have_debug_sync.inc) | Skip on non-debug builds. Add **both** when using DEBUG_SYNC (PR4765). |
| [`not_embedded.inc`](include/not_embedded.inc), [`not_windows.inc`](include/not_windows.inc) | Skip in modes that can't run the test (PR4606, PR4904, PR4998). |
| [`master-slave.inc`](include/master-slave.inc), [`reset_master.inc`](include/reset_master.inc), [`rpl_end.inc`](include/rpl_end.inc) | Replication topology setup/teardown. Prefer over inline `RESET MASTER` (PR4771). |
| [`wait_condition.inc`](include/wait_condition.inc) | Busy-wait until `$wait_condition` SQL returns 1. **Use this, not `SLEEP(N)`** ([`testing.md`](../.claude/review/testing.md) §"Synchronisation: never `sleep`"). Generous timeouts — 60s, not 2s (PR4874). |
| [`assert_grep.inc`](include/assert_grep.inc), [`search_pattern_in_file.inc`](include/search_pattern_in_file.inc) | Verify log/file contents. |
| [`kill_and_restart_mysqld.inc`](include/kill_and_restart_mysqld.inc) | Crash-recovery test boilerplate (PR4446 — preferred over `count_sessions.inc` + manual kill). |

When a reviewer suggests a specific helper, use the exact one they cited — the rulebook collects these as code suggestions.

---

## Recording results

```
./mtr --record main.alter_table_debug    # rewrites mysql-test/main/alter_table_debug.result
```

- After **every behaviour-changing patch**, re-record affected `.result` files across **every** suite — buildbot must be clean before merge (PR4569, PR4632, PR4678, PR4712).
- **Diff the recorded output** before committing. Auto-record on a buggy patch silently bakes the bug into `.result`. PR4706 gkodinov: "Please don't just copy the lines. Please compile and actually run the test before pushing a new version."
- For tests with a `.combinations` file, `--record` updates each combination's `.result` / `.rdiff` independently. mtr runs one worker only in `--record` mode (driver enforces this around line 1604 of `mariadb-test-run.pl`).
- Never hand-edit a `.result` to "fix" a failing test. Reviewers spot it ([`testing.md`](../.claude/review/testing.md) §"Result files").

---

## Common runtime flags

Run `./mtr --help` for the full list (very long). The ones you'll actually use:

| Flag | Purpose |
|---|---|
| `--parallel=N` / `--parallel=auto` | N parallel workers (auto = one per CPU). |
| `--mem[=DIR]` | vardir on tmpfs / ramdisk. Significantly faster. Ignored on Windows. |
| `--big-test` | include slow tests; pass **twice** to run *only* big tests. |
| `--record` | (re)generate `.result` (single-worker). |
| `--force` | don't stop on failure; **twice** = continue past first failed command within a test. |
| `--manual-gdb` / `--gdb` | attach gdb (manual = wait for you to attach; `--gdb` runs server under gdb). |
| `--rr` | record under Mozilla `rr` for reverse-debugging (see [`mysql-test/lib/My/Debugger.pm`](lib/My/Debugger.pm) line 80 for the wrapper). |
| `--valgrind` | run under valgrind; suppressions in [`valgrind.supp`](valgrind.supp). |
| `--extern socket=/path/sock` | run against an already-running server (test names required; many tests can't run this way). |
| `--suite=<list>` | run only the listed suites. |
| `--combination=<name>` | run only the named combination of a `.combinations` test. |
| `<test> --mariadbd=--<opt>` | append an extra server arg for this run (e.g. `./mtr alias --mariadbd=--loose-foo=bar`). |
| `--do-test=<regex>` | filter tests by regex on the name. |

Deeper rr / gdb / sanitizer usage is covered in `.claude/reference/debug-tooling.md` (Phase 5).

---

## DEBUG_SYNC patterns

For race-condition repros, MTR drives `SET DEBUG_SYNC='name SIGNAL go';` / `'name WAIT_FOR go';` from the test script. Available only in Debug builds.

- **Test prerequisite:** `--source include/have_debug_sync.inc` and `--source include/have_debug.inc` together (PR4765 dr-m: "I'd add both, so that the test will be more efficiently skipped on non-debug builds"). The `have_debug_sync.inc` skip is a runtime check against `information_schema.session_variables`.
- **Pattern:** session A runs a statement that hits a named sync point and signals; session B (on a second `--connect`) waits on the signal, runs verification, then signals A to continue. Cross-engine fault injection (`SET debug_dbug='+d,<keyword>';`) uses the same `have_debug.inc` gate but no DEBUG_SYNC.
- **Find templates by example:** `grep -l DEBUG_SYNC mysql-test/main/*.test` — dozens of patterns. Start with [`mysql-test/main/debug_sync.test`](main/debug_sync.test) or [`mysql-test/main/backup_lock_debug.test`](main/backup_lock_debug.test).
- **Never ship a DEBUG_SYNC test without `have_debug_sync.inc`** — it will pass locally on Debug and fail every non-debug build in CI.
- **No `SELECT SLEEP(N)` as a synchronisation primitive** ([`testing.md`](../.claude/review/testing.md) §"Synchronisation: never `sleep`": PR4421, PR4765, PR4804, PR4998). Use DEBUG_SYNC, `wait_condition.inc`, or `--ping` (com_ping).

---

## Skip lists & disabled tests

Several files name tests to skip:

| File | Scope |
|---|---|
| `mysql-test/<suite>/disabled.def` | Per-suite. Format: `testname : MDEV-NNNNN <reason>`. Reviewers **require** an MDEV reference. |
| [`mysql-test/collections/disabled-per-push.list`](collections/disabled-per-push.list), [`disabled-daily.list`](collections/disabled-daily.list), [`disabled-weekly.list`](collections/disabled-weekly.list) | Collection-level skip lists scoped to a CI cadence. |
| [`mysql-test/collections/skip_list_ubsan.txt`](collections/skip_list_ubsan.txt) | UBSan-build-only skips. |

Disabling discipline (cite [`testing.md`](../.claude/review/testing.md)): every disabled test needs an MDEV link and a date. "Temporarily disabled" with no ticket is a review reject. When a fix lands, the test is re-enabled in the same PR as the fix.

---

## Where new tests go (per task type)

| Task | Test goes to | Naming |
|---|---|---|
| New built-in SQL function | `mysql-test/main/` (alphabetical area), often extending an existing `func_<group>.test` | `func_<group>.test` for new file; otherwise append (PR4706, PR4811) |
| New system variable (server) | `mysql-test/suite/sys_vars/t/<sysvar>_basic.test` + `.result` | `<full-sysvar-name>_basic.test` |
| InnoDB sysvar | `mysql-test/suite/sys_vars/t/innodb_<name>_basic.test` (visibility/range) **and** a functional test under `storage/innobase/mysql-test/innodb/<name>.test` | 90+ `innodb_*_basic.test` already exist as templates |
| Replication feature | `mysql-test/suite/rpl/t/rpl_<name>.test` | Add a `.combinations` only if RBR+SBR+MIXED actually differ |
| Optimizer regression | `mysql-test/main/<area>.test` or a new `mdev<NNN>.test` | Reference MDEV in `--echo #` header |
| New error message | Append to a relevant existing `.test` covering the code path; record `.result` | Verify the **exact** identifier appears (PR4342, PR4884) |
| Status variable (replication) | `mysql-test/suite/rpl/`, **not** `sys_vars` (PR4904) | `rpl_<name>.test` |
| InnoDB regression | `storage/innobase/mysql-test/innodb/` (auto-discovered) | Match the suite's existing prefix |

Subsystem suffix matters: when a test is logically a `binlog_` test, it goes in the `binlog` suite with a `binlog_` prefix; reviewers will move it (PR4766, PR4904).

---

## Pitfalls (with real MDEVs / PRs)

Most of these are single bullets from [`.claude/review/testing.md`](../.claude/review/testing.md); load the file for the full discussion.

- **A test is required** for every bug-fix PR — the test must fail without the fix and pass with it. "Why no test?" is the most common review comment (PR4549, PR4691, PR4717, PR4739, PR4913, PR4982). [`testing.md`](../.claude/review/testing.md) §"A test is required".
- **Minimal repro, deterministic data.** Strip irrelevant joins/columns/sysvars; use **two rows per table** so the const-table short-circuit doesn't hide the bug; use `data1-data2-data3` rather than random-looking strings (PR4505, PR4687, PR4883). §"Minimal repro, deterministic data".
- **Self-contained tests.** Don't piggy-back on another test's tables; clean up with `DROP TABLE` / `--remove_file` / `RESET *` (PR4601, PR4710, PR4829). §"Self-contained — don't piggy-back".
- **`--echo # MDEV-NNNNN …` header and `--echo # End of <maj.min> tests` footer** — and the version number matches the **target branch**, not where you developed (PR4569, PR4711, PR4714, PR4904).
- **Prepared-statement and stored-procedure variants are not optional** for any new SQL feature. RECURSIVE CTEs got coverage for `{explain, plain, procedure, prepared statement}` × `{update, delete}` (PR4433). [`sql/CLAUDE.md`](../sql/CLAUDE.md) §"Prepared statements & re-execution" repeats this rule from the SQL side.
- **Don't compare nondeterministic output** (timestamps, addresses, process IDs, paths). Use `--replace_regex` / `--replace_column` (PR4455). **But don't mask the data being tested** — a regex that strips the value defeats the assertion (PR4829).
- **No `SLEEP()`, no `--sleep N`** — use DEBUG_SYNC, `wait_condition.inc`, or `--ping`. Sleeps are flaky in CI (PR4421, PR4765, PR4804, PR4998).
- **`wait_condition.inc` needs a generous timeout** — 60s, not the default 2s. CI machines are slow (PR4874).
- **`--source include/not_embedded.inc`** when the test needs a separate client process (most engine tests can't run in embedded mode; PR4606, PR4904, PR4998). Use `--loose-` prefix on `.opt` files when the option may not exist in embedded mode (PR4697).
- **No paths from your dev machine in `.result`** — reviewers spot them (PR4047).
- **`mtr.add_suppression()` must be narrow** — broad regexes hide unrelated errors (PR4342).
- **No invisible characters in `.result` / `.test`** — confirm clean UTF-8/ASCII (PR4581).
- **Buildbot is mandatory.** GitHub Actions / AppVeyor / GitLab CI are subsets. All buildbot platforms (amd64-gcc / -clang / -msan / -tsan / -ubsan / -asan, aarch64, ppc64le, s390x, Windows, macOS) must be green before merge (PR4811, PR4869, PR4918). [`testing.md`](../.claude/review/testing.md) §"Buildbot is mandatory".

---

## See also

- Root [`CLAUDE.md`](../CLAUDE.md) §"Testing" — high-level overview and the two test layers (MTR + unit).
- [`.claude/review/testing.md`](../.claude/review/testing.md) — **canonical MTR review wisdom**. Every rule above is cited from here.
- [`.claude/review/commit-and-process.md`](../.claude/review/commit-and-process.md) — branch policy and what tests must accompany a commit.
- [`sql/CLAUDE.md`](../sql/CLAUDE.md) — when a test is exercising server-side code.
- [`storage/innobase/CLAUDE.md`](../storage/innobase/CLAUDE.md) — when the test is for InnoDB (auto-discovered `innodb*` suites under `storage/innobase/mysql-test/`).
- [`mysql-test/README`](README) — short usage notes for system-installed packages.
- Forward references (not yet written):
  - [`.claude/playbooks/add-mtr-test.md`](../.claude/playbooks/add-mtr-test.md) (Phase 3) — concrete "where does my test go + how to record it" walk-through.
  - [`.claude/reference/glossary.md`](../.claude/reference/glossary.md) (Phase 2) — definitions for `.opt`, `.combinations`, `.rdiff`, "suite", combinations matrix vocabulary.
  - [`.claude/reference/debug-tooling.md`](../.claude/reference/debug-tooling.md) (Phase 5) — deeper rr/gdb/sanitizer usage from inside an mtr run.

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `f80c2f418bf` (branch `main`).
- **Files surveyed:**
  - `ls mysql-test/` (17 entries); `ls mysql-test/include/ | wc -l` → 632; `ls mysql-test/suite/` → 50 suites; `ls mysql-test/collections/` — confirmed all paths in the §"Directory layout" table.
  - **Not present in tree**: `skip_list_msan.txt` / `skip_list_asan.txt` / `skip_list_tsan.txt` (only `skip_list_ubsan.txt` is collection-level; the other sanitizers' skips live in suite-level `disabled.def`).
  - [`mysql-test/main/alter_table_debug.test`](main/alter_table_debug.test) — the 30-second-tour example (real, small, canonical header + footer).
  - [`mysql-test/main/innodb_ext_key.combinations`](main/innodb_ext_key.combinations) — `.combinations` shape.
  - [`mysql-test/include/have_debug_sync.inc`](include/have_debug_sync.inc) — confirmed runtime `information_schema` check.
  - [`mysql-test/mariadb-test-run.pl`](mariadb-test-run.pl) (~5800 lines) + [`mysql-test/lib/My/Debugger.pm`](lib/My/Debugger.pm) — confirmed `--rr`, `--gdb`, `--manual-gdb`, `--valgrind`, `--mem`, `--parallel`, `--record` (Debugger.pm:80 `rr =>`; mariadb-test-run.pl:1604 single-worker `--record`).
  - [`mysql-test/main/disabled.def`](main/disabled.def) — `name : reason` format.
  - [`.claude/review/testing.md`](../.claude/review/testing.md) — every cited MDEV / PR.
  - [`.claude/docs-plan/PLAN.md`](../.claude/docs-plan/PLAN.md) — outline and forward-reference paths.
- **Deliberately excluded:** the full mysqltest directive reference (upstream KB at https://mariadb.com/kb/en/mariadb/mysqltest/); per-suite tour; driver-internal Perl code (`lib/My/*`); unit tests (`unittest/` — out of scope, see root [`CLAUDE.md`](../CLAUDE.md) §"Testing").
- **Refresh procedure:** when a new collection list / skip-list appears under [`collections/`](collections/), update §"Skip lists & disabled tests"; when [`.claude/review/testing.md`](../.claude/review/testing.md) gains a section, fold into §"Pitfalls"; when [`mariadb-test-run.pl`](mariadb-test-run.pl) gains a notable user-facing flag, update §"Common runtime flags"; bump `last-verified`; re-run the Phase-1 validation prompt against a fresh subagent.
