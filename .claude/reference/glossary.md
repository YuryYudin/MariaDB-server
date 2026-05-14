---
applies-to: main
last-verified: 2026-05-14
source-of-truth: .claude/, CLAUDE.md, VERSION, https://mariadb.com/kb/
---

# MariaDB glossary for Claude agents

Short definitions for MariaDB-specific terms that recur in the rulebook ([`.claude/review/`](../review/)), the nested CLAUDE.md files ([`sql/CLAUDE.md`](../../sql/CLAUDE.md), [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md), [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md)), and PR review threads. Entries are 1–4 lines; deeper material lives behind the linked docs.

Alphabetical within each section. Sections ordered roughly by "what an agent looks up first".

---

## Project & process

- **CLA** — Contributor License Agreement. Required for first-time contributors. See https://mariadb.org/cla/.
- **forward-merge chain** — `10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → main`. Fixes land on the oldest branch where the bug reproduces, then are forward-merged upward by the release team. See [`branches-and-forward-merges.md`](branches-and-forward-merges.md).
- **forward-port** — applying a fix to a newer branch by re-implementation (not `git merge`) because the surrounding code has diverged. See [`.claude/review/commit-and-process.md`](../review/commit-and-process.md).
- **JIRA** — MariaDB's bug tracker at https://jira.mariadb.org. The primary workflow; GitHub issues exist but are not canonical.
- **`main`** — the GitHub default branch. Where new features land first. Today (`VERSION` file): `MYSQL_VERSION_MAJOR=13 / MINOR=0 / PATCH=1 / SERVER_MATURITY=gamma`.
- **maintained branches** — per https://mariadb.org/about/#maintenance-policy. As of `last-verified` the remote-tracked release branches are `10.6`, `10.11`, `11.4`, `11.8`, `12.0`–`12.3`, plus `main`. End-of-life dates change; re-check with `git branch -r` and the policy page before assuming.
- **MDEV-NNNNN** — JIRA ticket prefix. Required on commit subjects and PR titles; the prefix exception lets the first line exceed 50 chars when needed. See [`.claude/review/commit-and-process.md`](../review/commit-and-process.md).
- **PR** — pull request at https://github.com/MariaDB/server. Submit as a fast-forwardable branch (rebase, don't merge).
- **rulebook** — shorthand for [`.claude/review/`](../review/), the distilled review-guidance set extracted from 6 months of PR feedback. Entry point: [`.claude/review/README.md`](../review/README.md). Quick checklist: [`.claude/review/checklist.md`](../review/checklist.md).
- **`VERSION` file** — at the repo root. Encodes the marketing version and maturity (`alpha`/`beta`/`gamma`/`stable`).

## Server, clients & test harness

- **DBUG / `--debug=…`** — the in-tree tracing facility under [`dbug/`](../../dbug/). `DBUG_ENTER` / `DBUG_RETURN` / `DBUG_PRINT` macros are pervasive in `sql/`. Available only in Debug builds (compiled out when `DBUG_OFF` is defined).
- **DEBUG_SYNC** — Debug-build cooperative-pause mechanism for reproducing races. `SET DEBUG_SYNC='name SIGNAL go';` / `WAIT_FOR`. See [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns".
- **embedded server** — `libmariadbd` (under [`libmysqld/`](../../libmysqld/)). Server linked as a library; only built with `WITH_EMBEDDED_SERVER=ON`.
- **mariadbd** — the server binary. Legacy alias: `mysqld`. Both names work; tests use both.
- **`mariadb` / `mariadb-dump` / `mariadb-admin` / `mariadb-test` / `mariadb-binlog` / …** — the renamed client tools under [`client/`](../../client/). Legacy `mysql*` symlinks are still installed.
- **MEM_ROOT** — arena allocator. Bulk-allocate, bulk-free. Lifetime tied to a statement (`thd->mem_root`), a prepared statement (`thd->stmt_arena->mem_root`), or longer-lived contexts. See [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap".
- **mtr / `mariadb-test-run.pl`** — the integration-test driver in [`mysql-test/`](../../mysql-test/). NOT to be confused with `mtr_t` (InnoDB mini-transaction). See [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md).
- **MyTAP** — the in-tree C/C++ unit-test framework under [`unittest/mytap/`](../../unittest/mytap/). Used by `unittest/**/*-t.c[c]` programs and surfaced through CTest.
- **prepared-statement re-execution** — items rewritten during optimization must be allocated on the right arena so the rewrite survives the next execution. See [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution".
- **THD** — per-connection (or per-background-thread) state object. The most-passed-around pointer in `sql/`. See [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"THD lifecycle & the `current_thd` rule".

## Replication & WSREP

- **binlog** — binary log of replicated events. [`sql/log.cc`](../../sql/log.cc), [`sql/log_event*.cc`](../../sql/).
- **GTID** — global transaction ID. MariaDB's format (different from MySQL's): `<domain>-<server_id>-<seq_no>`. See [`sql/rpl_gtid.cc`](../../sql/rpl_gtid.cc).
- **parallel applier** — multi-threaded slave-side execution in [`sql/rpl_parallel.cc`](../../sql/rpl_parallel.cc). Three modes: `optimistic`, `conservative`, `aggressive` (`slave_parallel_mode`).
- **RBR / SBR / MIXED** — row-based / statement-based / mixed replication. Configurable via `binlog_format`.
- **relay log** — the replica's local copy of the source's binlog. Materialized by the IO thread; replayed by the SQL thread.
- **semisync** — semi-synchronous replication. In-tree plugin: [`sql/semisync*.cc`](../../sql/).
- **WSREP** — write-set replication. Galera cluster integration. Provided by the `wsrep-lib` git submodule plus [`sql/wsrep_*.cc`](../../sql/). Off by default; build with `WITH_WSREP=ON`.
- **`wsrep_dummy.cc`** — the stub built when `WITH_WSREP=OFF`. References to WSREP-only functions must compile against this stub or stay behind `#ifdef WITH_WSREP`.

## Storage layer

- **Aria** — transactional MyISAM-replacement under [`storage/maria/`](../../storage/maria/). Used for internal/system tables.
- **`dberr_t`** — InnoDB's internal error type ([`storage/innobase/include/db0err.h`](../../storage/innobase/include/db0err.h)). Mapped to MySQL error codes by `convert_error_code_to_mysql()`. See [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"`dberr_t` propagation".
- **handler** — per-table-instance interface the server calls into. Every engine subclasses it. [`sql/handler.h`](../../sql/handler.h).
- **handlerton** — per-storage-engine singleton (capabilities, factory functions). [`sql/handler.h`](../../sql/handler.h).
- **InnoDB** — the default storage engine. See [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md).
- **MyISAM** — legacy non-transactional engine under [`storage/myisam/`](../../storage/myisam/). Maintenance-only.
- **MyRocks / RocksDB engine** — [`storage/rocksdb/`](../../storage/rocksdb/) (git submodule). Maintained by Facebook upstream; MariaDB has local glue.
- **`mtr_t`** — InnoDB's mini-transaction (not the test driver). Buffers redo records, holds latches, commits atomically. See [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"`mtr_t`".
- **page / extent / tablespace** — InnoDB on-disk units. Page = one disk block (default 16 KiB); extent = 64 contiguous pages; tablespace = a `.ibd` file (or system tablespace). See [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"On-disk page format".

## Types & strings

- **CHARSET_INFO** — per-charset+collation descriptor. [`include/m_ctype.h`](../../include/m_ctype.h), implementations in [`strings/`](../../strings/).
- **Item / `Item_*`** — every SQL expression is an `Item` subtree. See [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)".
- **LEX_STRING / LEX_CSTRING** — `{char *str; size_t length;}` pair (`CSTRING` is `const`-qualified). Replaces the bare-`char *` idiom. Charset is implicit from context.
- **MYSQL_TIME** — the in-memory date/time/datetime/timestamp value (`include/mysql/mysql_time.h`). Used across the type system and Connector/C.
- **"native" format** — the in-memory binary form a `Type_handler` knows how to read/write directly (vs. the textual SQL form). Show up in `Type_handler::Item_*_val_native_*` paths.
- **TABLE / TABLE_SHARE** — in-memory representation of a table. `TABLE_SHARE` is per-share (cached, refcounted); `TABLE` is per-open. [`sql/table.h`](../../sql/table.h).
- **Type_handler** — single dispatch point for "how does this SQL type behave". [`sql/sql_type.cc`](../../sql/sql_type.cc).

## Build, test & sanitizers

- **ASAN / TSAN / UBSAN / MSAN** — Address / Thread / Undefined-Behaviour / Memory sanitizer builds. CMake options `WITH_ASAN`, `WITH_TSAN`, `WITH_UBSAN`, `WITH_MSAN`. MSAN requires `libc++`. Sanitizer builds force `-Og` if no optimization level was set.
- **`BUILD/compile-*`** — curated shell wrappers under [`BUILD/`](../../BUILD/) that drive cmake with platform+flag presets, e.g. `BUILD/compile-pentium64-debug-max`, `BUILD/compile-pentium64-asan-max`.
- **CTest** — what `make test` runs: the `unittest/` TAP programs plus ABI checks. Does **not** invoke `mtr`.
- **Debug / RelWithDebInfo / Release / MinSizeRel** — CMake build types. Debug enables `DBUG_TRACE`, `ENABLED_DEBUG_SYNC`, `SAFE_MUTEX`, `SAFEMALLOC`, `TRASH_FREED_MEMORY`, `_GLIBCXX_DEBUG`, `PROTECT_STATEMENT_MEMROOT`. Non-Debug gets `-DDBUG_OFF`.
- **MariaDB Foundation / MariaDB Corporation / Codership / External Contribution** — PR author labels applied by [`.github/workflows/label_recent_prs.yaml`](../../.github/workflows/label_recent_prs.yaml).
- **`MYSQL_MAINTAINER_MODE`** — CMake option that enables `-Wall -Wextra -Wsuggest-override -Wvla -Wframe-larger-than=16384 …`. `AUTO` (default) = `-Werror` only in Debug.
- **rr** — Mozilla's reverse debugger. `mtr --rr` records; replay with `rr replay`. See [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common runtime flags".
- **`--big-test`** — `mtr` flag for slow tests. Pass twice (`--big-test --big-test`) to run **only** big tests.

## Misc that often confuses agents

- **`a= 1;`** vs **`a = 1;`** — server-side style is no space before `=`, single space after. Some plugins (notably Connect) use the conventional `a = 1`. See [`.claude/review/coding-style.md`](../review/coding-style.md).
- **`.combinations`** — per-test combination-matrix file. See [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"File naming and conventions".
- **`disabled.def`** — per-suite skip list with `name : MDEV-NNNNN reason` entries.
- **`.opt` / `-master.opt`** — one-line server-args file per test (e.g. `mytest-master.opt` carries args for the test's primary `mariadbd`).
- **`.rdiff`** — per-combination delta from the base `.result` file.
- **`THD *thd`** — pointer asterisk binds to the variable name, not the type. Project style.
- **Yoda condition** — `if (0 == err)`. Forbidden in this project; use `if (!err)`. See [`.claude/review/coding-style.md`](../review/coding-style.md).

---

## See also

- Root [`CLAUDE.md`](../../CLAUDE.md) — project-wide overview, build, branch policy, coding style.
- [`.claude/review/README.md`](../review/README.md) — the distilled rulebook index.
  - [`coding-style.md`](../review/coding-style.md), [`correctness-and-security.md`](../review/correctness-and-security.md), [`innodb.md`](../review/innodb.md), [`testing.md`](../review/testing.md), [`commit-and-process.md`](../review/commit-and-process.md), [`api-and-architecture.md`](../review/api-and-architecture.md), [`logging-and-errors.md`](../review/logging-and-errors.md), [`build-and-cmake.md`](../review/build-and-cmake.md), [`anti-patterns.md`](../review/anti-patterns.md).
- [`sql/CLAUDE.md`](../../sql/CLAUDE.md) — server-core map, THD lifecycle, MEM_ROOT, items.
- [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) — InnoDB latches, `mtr_t`, `dberr_t`, page format.
- [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) — `mtr` driver, directive cheat-sheet, DEBUG_SYNC, recording results.
- [`branches-and-forward-merges.md`](branches-and-forward-merges.md) — branch policy with concrete numbers and the forward-merge mechanics.
- [`keyword-index.md`](keyword-index.md) — reverse index from concept to where it's discussed.
- [`memory-management.md`](memory-management.md), [`error-handling.md`](error-handling.md), [`threading-and-locks.md`](threading-and-locks.md), [`debug-tooling.md`](debug-tooling.md) — cross-cutting reference docs.

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `adb772f3811` (branch `main`).
- **Sources surveyed:**
  - [`VERSION`](../../VERSION) → `13.0.1 gamma`.
  - `git branch -r` → maintained release branches list (`10.6`, `10.11`, `11.4`, `11.8`, `12.0`–`12.3`, plus `main`).
  - The three Phase-1 nested docs ([`sql/CLAUDE.md`](../../sql/CLAUDE.md), [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md), [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md)) for cross-reference targets.
  - [`.claude/review/`](../review/) — every rulebook file, for terms-of-art the rules already cite.
  - Root [`CLAUDE.md`](../../CLAUDE.md) — for the canonical phrasing of build/test/branch concepts.
  - [`.claude/docs-plan/PLAN.md`](../docs-plan/PLAN.md) §"Phase 2 — Task 4" — for the term set and length target.
- **Deliberately excluded:** mini-essays. Anything the linked CLAUDE.md / rulebook section explains better. Per-file file lists (those live in the nested CLAUDE.md `Map of file clusters` sections).
- **Date-sensitive items (MUST re-verify at each refresh):**
  - The maintained-branches list and the forward-merge chain — `git branch -r` and the maintenance policy page change as releases EOL / new branches open.
  - The `VERSION` snapshot (`13.0.1 gamma`) — bumped on every release on `main`.
  - The HEAD SHA recorded above.
- **Refresh procedure:**
  - When a new term gets cited in [`.claude/review/`](../review/) or any nested CLAUDE.md, add an entry here (1–4 lines) and link back to the canonical doc.
  - When a release branch is added/EOL'd, update §"Project & process" and the forward-merge chain entry.
  - When the `VERSION` file bumps, update the `main` entry under §"Project & process".
  - Bump `last-verified` and the HEAD SHA above.
