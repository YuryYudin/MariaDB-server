---
applies-to: main
last-verified: 2026-05-14
source-of-truth: .claude/, CLAUDE.md, sql/CLAUDE.md, storage/innobase/CLAUDE.md, mysql-test/CLAUDE.md
---

# Keyword index for Claude agents

Reverse index from concept / search term → where it's discussed. Different from the [glossary](glossary.md) (term → definition); this is term → location. When you don't know which file covers a topic, look it up here.

Grouped by domain. Alphabetical within each group. Entries cite `<file>` and where useful `§"<section>"`.

---

## Server core (sql/)

- **ACL / privileges** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"ACL & privileges"; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Auth / ACL".
- **`ALTER TABLE`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Tables, fields, types".
- **`Create_func` / `Create_func_arg1` / `Create_native_func`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" (factory table) and "Choosing an `Item_func` base class".
- **`current_thd`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"THD lifecycle".
- **`DBUG_ENTER` / `DBUG_RETURN` / `DBUG_PRINT`** — [glossary.md](glossary.md) §"DBUG"; root [`CLAUDE.md`](../../CLAUDE.md) §"Things to be aware of".
- **`enum_sql_command`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Command dispatch & THD".
- **error message wording** — [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md) §"Message wording"; [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"`my_error()` vs `push_warning_printf()` vs `sql_print_error()`".
- **`errmsg-utf8.txt`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Errors & messages"; [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md) §"Error codes / errmsg-utf8.txt".
- **`fix_fields` / `Item::fix_fields`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution"; §"Items (expressions)".
- **`func_name()` / `get_copy()`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution".
- **handlerton / handler** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Storage-engine API"; [glossary.md](glossary.md).
- **Item / `Item_func` / `Item_int_func` / `Item_real_func`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" (with base-class picker).
- **`item_create.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)".
- **`JOIN::optimize` / `JOIN::exec`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Optimizer & executor"; §"Where to start".
- **`LEX` / `LEX_STRING` / `LEX_CSTRING`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Parser & lexer"; [glossary.md](glossary.md).
- **`MEM_ROOT` / `thd->mem_root` / `stmt_arena`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap"; forward ref [`memory-management.md`](memory-management.md) (Phase 5).
- **`my_error()` vs `push_warning_printf()` vs `sql_print_error()`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"`my_error()` vs `push_warning_printf()` vs `sql_print_error()`"; [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md).
- **NULL handling** — [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"NULL handling".
- **`OLD_VALUE()` / `Item_old_field`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers & paired `Field` pointers".
- **paired pointers** (`ptr` / `ptr_old`, `null_ptr` / `null_ptr_old`) — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers & paired `Field` pointers".
- **parser changes** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Parser & lexer"; §"Where to start"; forward ref `sql/docs/parser.md` (Phase 4).
- **plugin host / `sql_plugin.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Plugin host".
- **prepared statements / re-execution** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution"; [`.claude/review/testing.md`](../review/testing.md) §"Cover every documented branch".
- **`PROTECT_STATEMENT_MEMROOT`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution".
- **`record[0]` / `record[1]`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers & paired `Field` pointers".
- **`RETURNING` (`UPDATE ... RETURNING`, `INSERT ... RETURNING`)** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers" (the `OLD_VALUE()` interaction).
- **stored programs / `sp_head` / `sp_pcontext`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Stored programs"; forward ref `sql/docs/stored-programs.md` (Phase 5).
- **`sys_vars.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"System variables"; §"Where to start"; forward ref `.claude/playbooks/add-system-variable.md` (Phase 3).
- **`THD` lifecycle** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"THD lifecycle".
- **`Type_handler` / `sql_type.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Tables, fields, types".

## InnoDB (storage/innobase/)

- **buffer pool** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Buffer pool & I/O subsystem".
- **`buf_page_get_gen()`** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Buffer pool & I/O subsystem".
- **`dberr_t`** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"`dberr_t` propagation".
- **`dict_sys` (latch)** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Pitfalls"; [`.claude/review/innodb.md`](../review/innodb.md).
- **`ha_innodb.cc`** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"The SQL ↔ InnoDB bridge"; §"Where to start".
- **InnoDB style sub-dialect** — [`.claude/review/innodb.md`](../review/innodb.md) §"The InnoDB style sub-dialect".
- **InnoDB sysvar wiring** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Where to start" (sysvar row) and §"Pitfalls" (3-places-must-agree rule).
- **latch hierarchy / locking order** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy & locking discipline".
- **log archiving (MDEV-37949)** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Redo log (log0*) — gotchas".
- **`log_sys` latch** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy"; [`.claude/review/innodb.md`](../review/innodb.md) §"Performance discipline".
- **`mtr_t` (mini-transaction)** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"`mtr_t` — mini-transactions".
- **on-disk page format / version compatibility** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"On-disk page format & version compatibility"; [`.claude/review/innodb.md`](../review/innodb.md) §"On-disk / page format".
- **page latches / `srw_lock` / `ssux_lock` / `sux_lock`** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy".
- **redo log** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Redo log (log0*) — gotchas"; [`.claude/review/innodb.md`](../review/innodb.md) §"Redo log discipline".
- **`space_id` / `page_no`** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Pitfalls"; §"Buffer pool".
- **transaction / `trx_t` / MVCC** — [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Subdirectory map" (trx/); §"Where to start".

## Testing (mysql-test/)

- **`.combinations` files** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"File naming and conventions".
- **`.opt` / `-master.opt`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"File naming and conventions".
- **`.rdiff`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"File naming and conventions".
- **`.test` file shape** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"A `.test` file: 30-second tour"; [`.claude/playbooks/add-mtr-test.md`](../playbooks/add-mtr-test.md) §"Steps".
- **add an MTR test (workflow)** — [`.claude/playbooks/add-mtr-test.md`](../playbooks/add-mtr-test.md).
- **`--big-test`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common runtime flags".
- **`--echo` headers between sub-sections** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"A `.test` file: 30-second tour".
- **`--error <ER_*>`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"mysqltest directive cheat-sheet".
- **`--gdb` / `--manual-gdb` / `--rr`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common runtime flags".
- **`--mem`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common runtime flags".
- **`--record`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Recording results".
- **`--replace_regex` / `--replace_column`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"mysqltest directive cheat-sheet".
- **DEBUG_SYNC patterns** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns"; root [`CLAUDE.md`](../../CLAUDE.md).
- **disabled tests / `disabled.def`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Skip lists & disabled tests"; [`.claude/review/testing.md`](../review/testing.md) §"Disabled / skip lists".
- **`End of <maj.min> tests` footer** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"A `.test` file: 30-second tour".
- **`have_*.inc` (include files)** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common include files".
- **`mtr`** — [glossary.md](glossary.md); [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md).
- **PS / SP test variants** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton"; [`.claude/review/testing.md`](../review/testing.md) §"Cover every documented branch".
- **`wait_condition.inc`** — [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common include files"; §"mysqltest directive cheat-sheet" (the don't-use-`--sleep` rule).

## Replication

- **binlog / `log_event*.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication".
- **GTID** — [glossary.md](glossary.md) §"Replication & WSREP"; [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication".
- **parallel applier** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication"; [glossary.md](glossary.md).
- **RBR / SBR / MIXED / `binlog_format`** — [glossary.md](glossary.md).
- **replication wire format** — [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Replication / binlog wire format".
- **semisync** — [glossary.md](glossary.md); [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication".
- **WSREP / Galera / `wsrep-lib`** — [glossary.md](glossary.md); [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication"; [`.claude/review/innodb.md`](../review/innodb.md) §"Galera / WSREP".
- **`wsrep_dummy.cc`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication"; [glossary.md](glossary.md).

## Memory, threading, errors

- **`alloc_root`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap".
- **error log writers (`sql_print_*`)** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"`my_error()` …"; [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md) §"Logging functions".
- **OOM handling** — [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md); forward ref [`error-handling.md`](error-handling.md) (Phase 5).
- **`my_malloc` / `my_free`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap".
- **`my_safe_alloca`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap".
- **`mysql_mutex_t` / `SAFE_MUTEX`** — root [`CLAUDE.md`](../../CLAUDE.md) §"Things to be aware of"; forward ref [`threading-and-locks.md`](threading-and-locks.md) (Phase 5).
- **`Sql_condition` / `Diagnostics_area` / `Warning_info`** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Errors & messages"; [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md).

## Build, sanitizers, CI

- **ASAN / UBSAN / TSAN / MSAN** — root [`CLAUDE.md`](../../CLAUDE.md) §"Build"; [glossary.md](glossary.md); [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Sanitizer hygiene"; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Sanitizer-driven failures".
- **`BUILD/compile-*` scripts** — root [`CLAUDE.md`](../../CLAUDE.md) §"Build"; [glossary.md](glossary.md).
- **CMake style** — [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"CMake style"; root [`CLAUDE.md`](../../CLAUDE.md) §"Build".
- **`CMAKE_BUILD_TYPE` (Debug / RelWithDebInfo / Release / MinSizeRel)** — root [`CLAUDE.md`](../../CLAUDE.md) §"Build"; [glossary.md](glossary.md).
- **CI surfaces (GitLab / AppVeyor / GH-Actions)** — root [`CLAUDE.md`](../../CLAUDE.md) §"CI"; [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"CI surfaces".
- **`MYSQL_MAINTAINER_MODE`** — root [`CLAUDE.md`](../../CLAUDE.md) §"Build"; [glossary.md](glossary.md).
- **packaging** — [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Packaging".
- **security-hardening flags** — [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Security hardening flags".
- **submodules** — root [`CLAUDE.md`](../../CLAUDE.md) §"Submodules"; [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Submodules"; [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Submodules".
- **third-party libraries — don't patch in-tree** — [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Third-party libraries".

## Coding style

- **Allman braces / 2-space indent / `a= 1;`** — [`CODING_STANDARDS.md`](../../CODING_STANDARDS.md); [`.claude/review/coding-style.md`](../review/coding-style.md) §"Critical baseline".
- **casts: C-style → constructor-style** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Casts"; [`.claude/review/anti-patterns.md`](../review/anti-patterns.md).
- **comments: when and how** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Comments".
- **don't touch what you're not changing** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Don't touch what you're not changing".
- **headers / generated files** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Headers / generated files".
- **naming (`THD *thd`, snake_case, no `long`/`ulong`)** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Naming"; root [`CLAUDE.md`](../../CLAUDE.md) §"Coding style".
- **removing things cleanly** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Removing things cleanly".
- **Yoda conditions** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Control flow"; [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Pitfalls".

## Process

- **AI-disclosure expectations** — [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"AI-disclosure expectations".
- **branch policy / maintained branches** — root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree"; [`branches-and-forward-merges.md`](branches-and-forward-merges.md).
- **buildbot** — [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"Buildbot".
- **CLA** — [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"CLA"; [glossary.md](glossary.md).
- **commit message style (50/72, MDEV prefix)** — [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"Commit message"; root [`CLAUDE.md`](../../CLAUDE.md).
- **forward-merge chain** — [`branches-and-forward-merges.md`](branches-and-forward-merges.md); [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"Branch targeting".
- **JIRA / MDEV** — [glossary.md](glossary.md); [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"JIRA / MDEV".
- **PR / pull request flow** — root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree"; [`.claude/review/commit-and-process.md`](../review/commit-and-process.md).
- **rebase, don't merge** — [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"Rebase, don't merge".
- **security policy** — root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree"; `SECURITY.md`.

## Workflows (skills)

- **bug-fix end-to-end** — [`.claude/skills/mfix/SKILL.md`](../skills/mfix/SKILL.md).
- **code review** — [`.claude/skills/mreview/SKILL.md`](../skills/mreview/SKILL.md).

## Anti-patterns the reviewers will reject

- **bitwise-OR of error-returning calls** — [`.claude/review/anti-patterns.md`](../review/anti-patterns.md) §"Sequencing / control flow".
- **buffer-overflow / OOB read** — [`.claude/review/anti-patterns.md`](../review/anti-patterns.md) §"Buffer / format-string bugs"; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Buffer / length validation".
- **`current_thd()` under hot latches** — [`.claude/review/innodb.md`](../review/innodb.md) §"Performance discipline".
- **double-free / use-after-free** — [`.claude/review/anti-patterns.md`](../review/anti-patterns.md) §"Lifetime / leaks"; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Lifetime / ownership".
- **heap alloc under `log_sys.latch`** — [`.claude/review/innodb.md`](../review/innodb.md) §"Performance discipline".
- **`ib::*` logger in new code** — [`.claude/review/innodb.md`](../review/innodb.md) §"Logging discipline"; [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Pitfalls".
- **mock-DB tests masking real divergence** — [`.claude/review/testing.md`](../review/testing.md).
- **printf / fprintf in server code** — [`.claude/review/logging-and-errors.md`](../review/logging-and-errors.md) §"Format-string and printf safety"; [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"`my_error()` …".
- **`std::unordered_map` / `std::function` in hot paths** — [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Internal containers preferred over STL"; [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Pitfalls".
- **swap-one-half-of-paired-data-structure** — [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers" (MDEV-39179 lesson).
- **Yoda conditions (`if (0 == x)`)** — [`.claude/review/coding-style.md`](../review/coding-style.md) §"Control flow".

## See also

- [`glossary.md`](glossary.md) — term → definition (this file is term → location).
- [`branches-and-forward-merges.md`](branches-and-forward-merges.md) — branch policy reference.
- [`.claude/review/README.md`](../review/README.md) — high-level index of the rulebook (file-level; this index is concept-level).
- The Phase-1 nested `CLAUDE.md` files: [`sql/CLAUDE.md`](../../sql/CLAUDE.md), [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md), [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md).

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** post `f80c2f418bf` (see `git log .claude/`).
- **Method:** extracted `^## ` and `^### ` headers from every doc under `.claude/review/`, `.claude/reference/`, the three nested `CLAUDE.md` files, and the root `CLAUDE.md`. Augmented with the specific search terms that surfaced as gaps during the MDEV-39179 end-to-end validation (`OLD_VALUE`, `record[1]`, `null_ptr_old`, "paired pointers", "swap-one-half").
- **Deliberately excluded:** any term that's only mentioned in passing (not the subject of a section). The index points to where the concept is *taught*, not every mention.
- **Refresh procedure:**
  - After landing a new doc, append its `## ` and `### ` headers as new entries.
  - When a fresh-subagent validation run identifies a "I didn't know where to look for X" gap, add X here with the destination found during that validation. This is the canonical place to capture "you should have looked here" signal.
  - Re-verify forward-reference paths (`(Phase N)`) as those phases land.
