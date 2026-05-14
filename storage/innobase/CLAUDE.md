---
applies-to: main
last-verified: 2026-05-14
source-of-truth: storage/innobase/
---

# `storage/innobase/` — Claude agent overview

InnoDB is MariaDB's **default storage engine**: a row-store with B+tree indexes, MVCC, full ACID semantics, crash recovery via a physical-mini-transaction redo log, and pluggable encryption / page-compression / spatial-index / fulltext support. It is built as a single CMake plugin (`MYSQL_ADD_PLUGIN(innobase ... STORAGE_ENGINE)` in [`CMakeLists.txt`](CMakeLists.txt) line 434) and plugs into the server through a `handlerton` plus a `handler` subclass at [`handler/ha_innodb.cc`](handler/ha_innodb.cc) — the same boundary every storage engine implements (see [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Storage-engine API"). InnoDB owns its own buffer pool, on-disk tablespace format, redo log, undo log, lock manager, change buffer, fulltext indexes, and spatial (R-tree) indexes.

MariaDB's InnoDB has **diverged significantly** from MySQL's: the latch implementation (`srw_lock`, `ssux_lock`, `sux_lock` — see [`include/sux_lock.h`](include/sux_lock.h)), the redo log format and recovery path, the page checksum implementation, log archiving (MDEV-37949, landed on `main`), the buffer-pool reservation strategy (MDEV-22186, MDEV-39139), and the dictionary cache discipline all differ. **Don't assume MySQL InnoDB documentation applies** — read MariaDB source first, MariaDB JIRA second, MySQL docs only as a tertiary cross-check.

> **Project-wide style and review rules:** [`.claude/review/README.md`](../../.claude/review/README.md)
> **InnoDB-specific review wisdom (canonical):** [`.claude/review/innodb.md`](../../.claude/review/innodb.md) — read before any non-trivial InnoDB PR.
> **Code-review entry point:** [`.claude/skills/mreview/SKILL.md`](../../.claude/skills/mreview/SKILL.md)
> **MDEV bug-fix entry point:** [`.claude/skills/mfix/SKILL.md`](../../.claude/skills/mfix/SKILL.md)

---

## Subdirectory map

The InnoDB tree (`ls storage/innobase/`) is organised by subsystem. Each row below is one real subdirectory with one representative file — read the file, don't read a paraphrase.

| Subdir | Purpose | Representative file |
|---|---|---|
| [`buf/`](buf/) | Buffer pool: page cache, LRU, flushing, doublewrite, linear/random read-ahead (in [`buf0rea.cc`](buf/buf0rea.cc)). | [`buf/buf0buf.cc`](buf/buf0buf.cc) (29 commits / 12 months) |
| [`fil/`](fil/) | Tablespace file management; `fil_space_t`, `fil_node_t`, AIO orchestration, encryption, page compression. | [`fil/fil0fil.cc`](fil/fil0fil.cc) (37 commits / 12 months) |
| [`log/`](log/) | Redo log writer, recovery, log encryption, log archive (MDEV-37949). | [`log/log0recv.cc`](log/log0recv.cc) — recovery |
| [`trx/`](trx/) | Transactions, MVCC, undo segments, purge, rollback, `INFORMATION_SCHEMA.INNODB_TRX`. | [`trx/trx0trx.cc`](trx/trx0trx.cc) |
| [`dict/`](dict/) | Data dictionary: `SYS_TABLES`, `SYS_INDEXES`, in-memory `dict_table_t` / `dict_index_t`, persistent statistics, table drop. | [`dict/dict0dict.cc`](dict/dict0dict.cc), [`dict/drop.cc`](dict/drop.cc) |
| [`page/`](page/) | Page operations: cursor, slot directory, COMPRESSED page format. | [`page/page0page.cc`](page/page0page.cc) |
| [`btr/`](btr/) | B+tree: insert, search, split/merge, bulk load, adaptive hash, persistent cursor. | [`btr/btr0btr.cc`](btr/btr0btr.cc), [`btr/btr0cur.cc`](btr/btr0cur.cc) |
| [`row/`](row/) | Row operations: insert, update, select, online ALTER, import, FTS sort, undo apply. The SQL-to-InnoDB row-level glue lives here. | [`row/row0mysql.cc`](row/row0mysql.cc), [`row/row0sel.cc`](row/row0sel.cc) |
| [`srv/`](srv/) | Server lifecycle: startup, shutdown, monitor thread, master thread, sysvars. | [`srv/srv0start.cc`](srv/srv0start.cc), [`srv/srv0srv.cc`](srv/srv0srv.cc) |
| [`ibuf/`](ibuf/) | Change buffer (formerly insert buffer). | [`ibuf/ibuf0ibuf.cc`](ibuf/ibuf0ibuf.cc) |
| [`lock/`](lock/) | Row and table locks; deadlock detection; predicate locks for GIS. | [`lock/lock0lock.cc`](lock/lock0lock.cc) |
| [`mtr/`](mtr/) | Mini-transactions — the atomic unit of page modification + redo. | [`mtr/mtr0mtr.cc`](mtr/mtr0mtr.cc) |
| [`mem/`](mem/) | InnoDB's per-heap memory allocator (`mem_heap_t`). Not the buffer pool. | [`mem/mem0mem.cc`](mem/mem0mem.cc) |
| [`os/`](os/) | OS abstraction: file I/O (`os_aio`, pread/pwrite), threading, time. | [`os/os0file.cc`](os/os0file.cc) |
| [`pars/`](pars/) | The internal InnoDB SQL parser used for dictionary bootstrap and FTS. Bison/Flex generated. | [`pars/pars0pars.cc`](pars/pars0pars.cc), [`pars/pars0grm.y`](pars/pars0grm.y) |
| [`handler/`](handler/) | The bridge to the SQL server: `handlerton`, `ha_innobase`, online ALTER, `INFORMATION_SCHEMA` tables. | [`handler/ha_innodb.cc`](handler/ha_innodb.cc) (61 commits / 12 months — #1 hot file), [`handler/handler0alter.cc`](handler/handler0alter.cc), [`handler/i_s.cc`](handler/i_s.cc) |
| [`ha/`](ha/) | The InnoDB-internal hash-table-based `ha_storage` (deduped string store). Don't confuse with `handler/`. | [`ha/ha0storage.cc`](ha/ha0storage.cc) |
| [`fsp/`](fsp/) | Free-space management: extent allocator, system tablespace bootstrap, encryption-keyring file format. | [`fsp/fsp0fsp.cc`](fsp/fsp0fsp.cc), [`fsp/fsp0sysspace.cc`](fsp/fsp0sysspace.cc) |
| [`fts/`](fts/) | Fulltext indexes. Has its own Bison/Flex generated lexer (`fts0blex.l`, `fts0pars.y`). | [`fts/fts0fts.cc`](fts/fts0fts.cc) |
| [`gis/`](gis/) | R-tree spatial indexes; predicate locks. | [`gis/gis0rtree.cc`](gis/gis0rtree.cc) |
| [`data/`](data/) | `dfield_t` / `dtype_t` — InnoDB's typed-value abstraction (the row representation in memory before serialisation). | [`data/data0data.cc`](data/data0data.cc), [`data/data0type.cc`](data/data0type.cc) |
| [`eval/`](eval/) | Expression evaluator for the internal SQL parser (used by `pars/`, FTS). | [`eval/eval0eval.cc`](eval/eval0eval.cc) |
| [`rem/`](rem/) | Record manager: serialised record format on a page, comparison helpers. | [`rem/rem0rec.cc`](rem/rem0rec.cc), [`rem/rem0cmp.cc`](rem/rem0cmp.cc) |
| [`read/`](read/) | MVCC read views (`ReadView`). | [`read/read0read.cc`](read/read0read.cc) |
| [`que/`](que/) | Query graph for the internal SQL parser. | [`que/que0que.cc`](que/que0que.cc) |
| [`fut/`](fut/) | Tiny file-linked-list helpers used by `fsp/`. | [`fut/fut0lst.cc`](fut/fut0lst.cc) |
| [`sync/`](sync/) | Latch primitives (`srw_lock`, the `cache.cc` CPU-side-channel mitigation). | [`sync/srw_lock.cc`](sync/srw_lock.cc) |
| [`ut/`](ut/) | Utilities: debug assertion machinery, RB-tree, vector, random, time. | [`ut/ut0dbg.cc`](ut/ut0dbg.cc), [`ut/ut0rbt.cc`](ut/ut0rbt.cc) |
| [`include/`](include/) | **All public-within-InnoDB headers**, by subsystem prefix (`buf0*`, `fil0*`, `log0*`, `trx0*`, `dict0*`, `page0*`, `btr0*`, `row0*`, `srv0*`, `ibuf0*`, `lock0*`, `mtr0*`, `mem0*`, `mach0*`, `os0*`, `pars0*`, `data0*`, `eval0*`, `rem0*`, `read0*`, `fsp0*`, `fts0*`, `gis0*`, `dyn0*`, `db0err.h`, `sux_lock.h`, `srw_lock.h`, …). Legacy `.inl` files are being removed in favour of inline definitions in the headers; see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Removing `.inl` files". |
| [`mysql-test/`](mysql-test/) | MTR suites that ship with InnoDB: `innodb`, `innodb_zip`, `innodb_gis`, `innodb_fts`, `innodb_undo`. Picked up automatically by `mtr`. |
| [`unittest/`](unittest/) | A handful of C++ unit tests. |

Note: there are no `mach/` or `unzip/` source subdirectories — `mach0data.h` (low-level integer packing/unpacking for the on-disk format) lives in [`include/`](include/) as inline-only, and compressed-page logic is split between [`page/page0zip.cc`](page/page0zip.cc) and [`buf/buf0buddy.cc`](buf/buf0buddy.cc).

---

## The SQL ↔ InnoDB bridge

The server calls InnoDB through two abstractions defined in `sql/`:

- **`handlerton`** — per-engine singleton (capabilities, factory functions, commit/recover/savepoint callbacks).
- **`handler`** — per-table-instance API (open, close, rnd_init/next, index_read/next, write_row, update_row, delete_row, …).

InnoDB implements both in [`handler/ha_innodb.cc`](handler/ha_innodb.cc) (the #1 most-modified InnoDB file: 61 commits in the last 12 months). Key wiring:

| Concept | InnoDB-side | Where set up |
|---|---|---|
| The handlerton | `innobase_hton` (a `handlerton *`) | [`handler/ha_innodb.cc:4109`](handler/ha_innodb.cc) `innobase_init()` (the plugin init function). Hooks: `prepare = innobase_xa_prepare`, `recover = innobase_xa_recover`, `commit = innobase_commit`, `rollback = innobase_rollback`, etc. |
| The handler subclass | `class ha_innobase : public handler` | [`handler/ha_innodb.h`](handler/ha_innodb.h) |
| Per-handler-instance scratch state | `row_prebuilt_t *m_prebuilt` | [`include/row0mysql.h:462`](include/row0mysql.h) |
| The InnoDB transaction | `trx_t` (NOT `innobase_trx_t` — that name is obsolete) | [`include/trx0trx.h`](include/trx0trx.h); each server-side `THD` lazily acquires one via `trx_create()` and stashes it on `THD::ha_data[hton->slot].ha_ptr`. |
| Value conversion: MariaDB `Field` ↔ InnoDB `dfield_t`/`dtype_t` | `row_mysql_store_col_in_innobase_format()` etc. | [`row/row0mysql.cc`](row/row0mysql.cc), [`data/data0data.cc`](data/data0data.cc), [`data/data0type.cc`](data/data0type.cc) |
| The error round-trip | `dberr_t` → MySQL error code | `convert_error_code_to_mysql()` at [`handler/ha_innodb.cc:2043`](handler/ha_innodb.cc) — called ~24 times throughout the file (every `ha_innobase::*` method that catches a `dberr_t` from a lower layer routes through it). |

Two naming conventions to keep straight:

- **`innobase_*` free functions** in `ha_innodb.cc` (e.g. `innobase_init`, `innobase_commit`, `innobase_xa_prepare`, `innobase_kill_query`) are the *server-facing* handlerton callbacks — pointer values stored on `innobase_hton`.
- **`ha_innobase::*` methods** are the per-handler-instance virtual overrides the server calls via the `handler*` pointer.

When adding a new server-callable hook, add the free function *and* wire it into `innobase_hton` in `innobase_init`.

---

## Latch hierarchy & locking discipline

InnoDB has **two distinct concurrency-control layers**. Don't conflate them.

### Layer 1 — In-memory **latches** (short-held, ordered)

Latches protect in-memory structures. Held briefly; ordered to avoid deadlock.

| Primitive | Where | Used for |
|---|---|---|
| `mysql_mutex_t` | server-wide, [`include/my_pthread.h`](../../include/my_pthread.h) | Global mutexes (e.g. `log_sys.mutex` callers, table-cache). |
| `srw_lock` | [`include/srw_lock.h`](include/srw_lock.h), [`sync/srw_lock.cc`](sync/srw_lock.cc) | Shared/exclusive rw-latch. |
| `ssux_lock` (Shared / "Strong-shared" or update / eXclusive) | [`include/srw_lock.h`](include/srw_lock.h) | Three-mode latch: S, U (= shared-exclusive / update), X. |
| `sux_lock<ssux>` | [`include/sux_lock.h`](include/sux_lock.h) | Fat rw-latch built on `ssux_lock` adding **recursive U / X** acquisition and debug-build owner tracking. `block_lock` (page latch) and `index_lock` are typedefs of this. |
| `mtr_t` mini-transaction | [`mtr/mtr0mtr.cc`](mtr/mtr0mtr.cc), [`include/mtr0mtr.h`](include/mtr0mtr.h) | Holds the page latches taken during one logical operation and releases them at `mtr.commit()`. See next section. |

**Latch order rule.** Latches must be acquired in a fixed order. There is **no single doc that enumerates the full graph**; the order is encoded in source comments at the point of each acquisition (search for "latching order" or "latch order"), e.g. [`include/row0row.h:352`](include/row0row.h) for index-record order, [`btr/btr0cur.cc:960`](btr/btr0cur.cc) for page-to-previous-page order, [`include/buf0buf.h:1312`](include/buf0buf.h) for buffer-pool/page interaction, and many `ut_ad()` assertions throughout. **Do not invent or paraphrase a "canonical order" — read the surrounding `ut_ad`s and comments at every site you touch.** Debug builds with `UNIV_DEBUG` (set by `CMAKE_BUILD_TYPE=Debug` or `-DWITH_INNODB_EXTRA_DEBUG=ON`) catch many ordering errors via the `readers` / `writer` bookkeeping in `sux_lock` ([`include/sux_lock.h`](include/sux_lock.h)).

For PR-review expectations on latching, see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Redo log discipline" and §"Performance discipline" — and reviewers will flag heap allocation under `log_sys.latch.wr_lock()` (PR4405), `current_thd()` calls under hot latches (PR4914), and so on.

### Layer 2 — Row / table **locks** (long-held, transaction-scoped)

These are SQL-visible locks: row locks, gap locks, table locks, predicate locks (GIS).

- Type: `lock_t` in [`include/lock0types.h`](include/lock0types.h).
- Manager: [`lock/lock0lock.cc`](lock/lock0lock.cc) (`lock_sys`).
- Deadlock detection: in the same file (`lock_wait`).
- Predicate locks for spatial indexes: [`lock/lock0prdt.cc`](lock/lock0prdt.cc).

Reviewers expect: `lock_sys` is **unlocked** when acquiring a page latch (see the comment at [`lock/lock0lock.cc:1274`](lock/lock0lock.cc) — "lock_sys must be unlocked to preserve latching order"). Violations are deadlock-bugs.

---

## `mtr_t` — mini-transactions

A mini-transaction is the **atomic unit of page modification**. Every page write goes through one. It (a) accumulates page latches taken on the way down the tree, (b) buffers redo-log records describing each physical modification, and (c) on `commit()` appends the buffered records to the global log buffer and releases the latches.

Key file: [`mtr/mtr0mtr.cc`](mtr/mtr0mtr.cc). Public API: [`include/mtr0mtr.h`](include/mtr0mtr.h).

- **Always paired.** `mtr_t mtr; mtr.start(); ...; mtr.commit();`. Never bare-acquire and bare-release page latches.
- **Take page latches via `mtr.s_lock` / `mtr.x_lock` / `mtr.u_lock`** (or the `mtr_x_lock_index` etc. macros at [`include/mtr0mtr.h:38-54`](include/mtr0mtr.h)). The mtr remembers what was acquired and releases at `commit()`.
- **Log mode** via `mtr.set_log_mode(MTR_LOG_NO_REDO)` for non-redo-logged operations (temporary tables, recovery, some bulk-load paths). The default `MTR_LOG_ALL` writes redo. `MTR_LOG_SUB` and `MTR_LOG_NONE` are also defined — read the enum in [`include/mtr0mtr.h:171`](include/mtr0mtr.h) before picking one.
- **Don't call `mtr_t::log_file_op()` directly.** Use higher-level wrappers like `mtr_t::name_write()`. Calling the low-level function directly is a debug-build compile-error trap that has hit real PRs — see PR5018, cited in [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Redo log discipline".
- **`mtr.commit()` is the LSN-publishing point.** Recovery replays one mtr atomically. A half-written mtr in the log = a recovery bug.

---

## `dberr_t` propagation

InnoDB's internal error type is `enum dberr_t`, defined at [`include/db0err.h:32`](include/db0err.h). Almost every InnoDB function that can fail returns one of:

| Code | Meaning |
|---|---|
| `DB_SUCCESS` | OK. |
| `DB_SUCCESS_LOCKED_REC` | OK and we now hold a record lock. (Special "richer success" — note that the convention is to encode such states in `dberr_t` rather than via out-parameters; see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Headers / API design".) |
| `DB_LOCK_WAIT` / `DB_LOCK_WAIT_TIMEOUT` / `DB_DEADLOCK` | Lock-wait outcomes; the caller must release latches and either re-try or abort. |
| `DB_DUPLICATE_KEY` | Unique-violation; caller may convert to a SQL error. |
| `DB_INTERRUPTED` | The THD was killed; bail out. |
| Anything else | An error — propagate up. |

Rules:

- **Wrap on the way in, unwrap on the way out.** Server entry points call into InnoDB, get a `dberr_t`, and run it through `convert_error_code_to_mysql()` ([`handler/ha_innodb.cc:2043`](handler/ha_innodb.cc)) to get a server-side `HA_ERR_*` / `HA_ERR_INTERNAL_ERROR` / `HA_ERR_OUT_OF_MEM` etc.
- **Don't swallow a non-`DB_SUCCESS` return.** Every internal function that can fail propagates by default. If you ignore the return value, justify it.
- **Don't pass `dberr_t` through `bool` + out-pointer.** Reviewers reject this — see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Headers / API design" (PR4036, PR4884).
- **For user-visible diagnostics, use `sql_print_error()` / `sql_print_warning()` / `sql_print_information()`** in new code — *not* `ib::error()` / `ib::warn()` / `ib::info()` / `puts()` / `fprintf(stderr, …)`. See [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Logging discipline" (PR4036 ×2). The legacy `ib::*` calls are still pervasive in old code; mimic the surrounding file when patching, but for *new* code prefer `sql_print_*`.

---

## On-disk page format & version compatibility

InnoDB pages have a versioned on-disk layout. Page type and version live in the page header; the system tablespace and per-table tablespace headers carry global format markers (`FIL_HEADER_SRV_VERSION` and friends in [`include/fsp0types.h`](include/fsp0types.h) / [`include/page0types.h`](include/page0types.h)).

**Rule:** **don't change the page format without a planned upgrade story.** Reviewers will block any change that:

- Adds, removes, or reorders bytes in a page header without a reserved-bit allocation and a version bump.
- Changes a checksum algorithm without keeping the old one decodable for older data files.
- Repurposes a previously-reserved field.
- Claims a downgrade path that hasn't been *tested*. **Don't add "in case of old format" compat checks speculatively** — see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"On-disk / page format" (PR4342: "we must not create an impression that a downgrade would work if it has not been tested").
- Writes a `std::unordered_map`-ordered structure to disk. Use deterministic ordering; reviewers will flag (PR4430).

Key files:

| File | Owns |
|---|---|
| [`include/page0types.h`](include/page0types.h) | Page-type constants, page-header offsets. |
| [`page/page0page.cc`](page/page0page.cc), [`page/page0cur.cc`](page/page0cur.cc) | Page operations and slot directory. |
| [`page/page0zip.cc`](page/page0zip.cc) | Compressed-page format. |
| [`fsp/fsp0fsp.cc`](fsp/fsp0fsp.cc) | Free-space header, extent descriptors. |
| [`include/fsp0types.h`](include/fsp0types.h) | Tablespace flags, version constants. |
| [`mach0data.h`](include/mach0data.h) | Big-endian integer packing — **never cross-reference with `uintNkorr` (little-endian, MyISAM)**. See [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"On-disk / page format" (PR4783, PR4797). |

Concrete recent format-affecting change: **MDEV-37949** (`innodb_log_archive`) extended the redo log on-disk format; see [`log/log0log.cc`](log/log0log.cc) `log_t::set_archive()`. Don't conflate the archived-log format with the live log format.

---

## Redo log (`log0*`) — gotchas

The redo log is a circular append-only log of physical-mini-transaction records, written by `mtr_t::commit()` and read by recovery at startup. Hot recovery file: [`log/log0recv.cc`](log/log0recv.cc) (`recv_sys`). Format and write path: [`log/log0log.cc`](log/log0log.cc), [`log/log0crypt.cc`](log/log0crypt.cc), [`log/log0sync.cc`](log/log0sync.cc).

- **The format changed recently.** MDEV-14425 (single redo file, no rotation) was followed by **MDEV-37949** (log archiving) on `main`; the file headers and record encoding are not identical to MySQL InnoDB.
- **Adding a new redo record type = a new format version.** Recovery in `log0recv.cc` must learn to parse it. Old log files written without the new type must still replay. A backward-incompatible record type bumps the file header version and requires `mariadb-upgrade` / a clean shutdown of the previous version.
- **Don't generate redo for non-redo-logged operations.** Use `mtr.set_log_mode(MTR_LOG_NO_REDO)` for temp-table modifications, recovery itself, and certain bulk-load paths.
- **Only `buf_flush_page_cleaner()` calls `log_checkpoint()` / `log_checkpoint_low()`.** Other threads must not. See [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Redo log discipline" (PR4747).
- **Exactly one `FILE_CHECKPOINT` record on shutdown.** Recovery parses no more than that. Same section, same source.
- **Maintain `innodb_log_buffer_size <= innodb_log_file_size`** at every transition — this is enforced on sysvar update *and* on archive attach. Violations caused real hangs (PR4405, MDEV-39104).
- **Log archiving is now in tree** (`storage/innobase/log/log0log.cc` `set_archive()`, MDEV-37949). When a feature reads/writes redo, account for the archive mode and the two file headers it produces.

---

## Buffer pool & I/O subsystem

The buffer pool is InnoDB's page cache. It is a single contiguous chunk reserved with `PROT_NONE` at startup and committed lazily ([`buf/buf0buf.cc`](buf/buf0buf.cc), 29 commits / 12 months; see MDEV-22186, MDEV-39139, MDEV-39142 for recent address-space and resize work).

- **Page lookup:** `buf_page_get_gen()` ([`include/buf0buf.h:200`](include/buf0buf.h)). Returns a `buf_block_t *` with the page latched (`RW_S_LATCH` / `RW_X_LATCH` / `RW_NO_LATCH`) and *fixed* — the page can't be evicted until you release.
- **Page identity:** `(space_id, page_no)`. `space_id` is the tablespace id (system = 0, undo tablespaces = 1..N, per-table = ≥ `SRV_SPACE_ID_UPPER_BOUND/2`). `page_no` is the in-file 16 KiB (or compressed-size) page index.
- **Dirty / LRU lists:** managed in [`buf/buf0flu.cc`](buf/buf0flu.cc) (flushing) and [`buf/buf0lru.cc`](buf/buf0lru.cc) (eviction). Neighbour flushing reduces seek cost on rotational media; `innodb_flush_neighbors` controls.
- **Doublewrite buffer:** [`buf/buf0dblwr.cc`](buf/buf0dblwr.cc). Protects against torn pages on crash.
- **Asynchronous I/O:** [`os/os0file.cc`](os/os0file.cc) (`os_aio`). Linux uses `io_uring` or `libaio` depending on the kernel and build flags; the thread-pool-backed fallback uses `tpool/` from the server.
- **Resize:** `innodb_buffer_pool_size` is asynchronous — the resize work is driven from `buf0buf.cc` and may take a long time. Don't block on it from a server-thread context.

---

## Where to start, by task type

| Task | First read | Then | Reference |
|---|---|---|---|
| Add an InnoDB system variable | [`handler/ha_innodb.cc`](handler/ha_innodb.cc) — clone a `static MYSQL_SYSVAR_*` (e.g. `MYSQL_SYSVAR_BOOL(stats_on_metadata, …)`) and **append it to `innobase_system_variables[]`** in the same file. Pick `PLUGIN_VAR_OPCMDARG` for a settable bool, `PLUGIN_VAR_RQCMDARG` for one requiring a value, `PLUGIN_VAR_READONLY` for `--option`-only. | Declare the backing variable in [`srv/srv0srv.cc`](srv/srv0srv.cc) + [`include/srv0srv.h`](include/srv0srv.h). Add a sysvar test as `mysql-test/suite/sys_vars/t/innodb_<name>_basic.test` (+ `.result`); the existing 90+ `innodb_*_basic.test` files are the copy template. Add a functional test under `storage/innobase/mysql-test/innodb/` exercising the new behaviour. | `.claude/playbooks/add-system-variable.md` (Phase 3) |
| Fix a buffer-pool / I/O bug | [`buf/buf0buf.cc`](buf/buf0buf.cc), [`fil/fil0fil.cc`](fil/fil0fil.cc) | [`buf/buf0flu.cc`](buf/buf0flu.cc), [`buf/buf0lru.cc`](buf/buf0lru.cc), [`os/os0file.cc`](os/os0file.cc) | — |
| Fix a transaction / locking bug | [`trx/trx0trx.cc`](trx/trx0trx.cc), [`lock/lock0lock.cc`](lock/lock0lock.cc) | [`read/read0read.cc`](read/read0read.cc) for the MVCC view; [`trx/trx0purge.cc`](trx/trx0purge.cc) for purge | — |
| Change page format | [`page/page0page.cc`](page/page0page.cc), [`fsp/fsp0fsp.cc`](fsp/fsp0fsp.cc), [`include/page0types.h`](include/page0types.h), [`include/fsp0types.h`](include/fsp0types.h) | Recovery path in [`log/log0recv.cc`](log/log0recv.cc); upgrade in `mariadb-upgrade` | [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"On-disk / page format" |
| Index-related bug | [`btr/btr0btr.cc`](btr/btr0btr.cc), [`btr/btr0cur.cc`](btr/btr0cur.cc), [`row/row0sel.cc`](row/row0sel.cc) | [`dict/dict0dict.cc`](dict/dict0dict.cc) for index metadata; [`btr/btr0sea.cc`](btr/btr0sea.cc) for adaptive hash | — |
| Add a new SHOW or INFORMATION_SCHEMA table | [`handler/i_s.cc`](handler/i_s.cc) — every `INNODB_*` IS table is here | The handlerton hookup in [`handler/ha_innodb.cc`](handler/ha_innodb.cc) `innobase_init` | — |
| Crash recovery change | [`log/log0recv.cc`](log/log0recv.cc) | [`srv/srv0start.cc`](srv/srv0start.cc) for startup wiring | [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Redo log discipline" |
| Replication / binlog interaction (group commit) | [`handler/ha_innodb.cc`](handler/ha_innodb.cc) `innobase_xa_prepare` / `innobase_commit_ordered` / `innobase_commit` | [`sql/log.cc`](../../sql/log.cc) | [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Replication" |
| Fulltext bug | [`fts/fts0fts.cc`](fts/fts0fts.cc), [`fts/fts0opt.cc`](fts/fts0opt.cc) | [`row/row0ftsort.cc`](row/row0ftsort.cc) for sort/build | — |
| Spatial / R-tree bug | [`gis/gis0rtree.cc`](gis/gis0rtree.cc), [`gis/gis0sea.cc`](gis/gis0sea.cc) | [`lock/lock0prdt.cc`](lock/lock0prdt.cc) for predicate locks | — |
| Online ALTER bug | [`handler/handler0alter.cc`](handler/handler0alter.cc) | [`row/row0log.cc`](row/row0log.cc) for the row-log; [`row/row0merge.cc`](row/row0merge.cc) for the build | — |

---

## Pitfalls (with real MDEVs / PRs)

Most of these are single bullets from the InnoDB rulebook; load the linked file for full context.

- **Don't print `LEX_CSTRING::str` directly through `%s` / `printf` for identifiers.** InnoDB raw `my_charset_filename` bytes are not UTF-8; convert via `ut_get_name()` / `dict_table_open_failed()` before user-visible output. PR4342; [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Logging discipline".
- **Don't acquire latches out of order.** There is no global enumeration of the order — read the `ut_ad`s and "latching order" comments at every site you touch. Violations are typically caught by `UNIV_DEBUG` builds (`sux_lock`'s `readers`/`writer` tracking).
- **Don't allocate heap memory under `log_sys.latch.wr_lock()` or other hot latches.** Cache pre-computed values in member variables. PR4405; [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"Performance discipline".
- **Don't bypass `mtr_t` for page modifications.** Every persistent page write must be in a started, log-mode-correct mini-transaction. Half-mtrs corrupt recovery.
- **Don't call `mtr_t::log_file_op()` directly** — use `mtr_t::name_write()` or another high-level wrapper. Debug builds fail to compile otherwise. PR5018.
- **Don't break the `(space_id, page_no)` invariant.** A `buf_page_t` from one space must not be reinterpreted as belonging to another; cross-space references are bugs.
- **Don't use `printf` / `fprintf` / `puts` / `ib::logger` / `ib::info` in new code.** Use `sql_print_error` / `sql_print_warning` / `sql_print_information`. Legacy code mixes them; mimic the file, but write new code in the new style. PR4036 ×2.
- **Don't introduce `std::string` in InnoDB.** Heap-fragmentation cost. Use `my_printf_error` / `%.*s` / fixed buffers / `st_::span<const char>`. PR4342 ×3.
- **Don't add `_t` / `ulint`-style aliases to new code** — that reverses the MDEV-25861 cleanup. Use `size_t`, `uint32_t`, etc. PR4884, PR4913.
- **Don't pass 7+ scalar parameters to a function on a hot path.** AMD64 SysV ABI = 6 register-passed scalars; the 7th spills. PR4746, PR4887.
- **Don't claim an untested downgrade path.** No speculative `'\377'` checks or "in case of old format" branches. PR4342.
- **Don't write `std::unordered_map`-ordered data to disk or the wire.** Serialised ordering must be deterministic. PR4430.
- **Don't reuse legacy MyISAM `mi_uintNkorr` (big-endian) in InnoDB code.** InnoDB uses `mach_read_from_*` / `mach_write_to_*` from [`include/mach0data.h`](include/mach0data.h). PR4783, PR4797.
- **Don't add a `dict_sys` latch around the whole transaction commit.** Latch `dict_sys` only for the SQL parser invocation; use `lock_sys_tables(trx)` for the commit. PR4884.
- **Sysvar wiring is easy to half-do.** Three places must agree: the `MYSQL_SYSVAR_*` macro in [`ha_innodb.cc`](handler/ha_innodb.cc), the append to `innobase_system_variables[]` (right below), and the backing variable in `srv0srv.cc` + `srv0srv.h`. Missing any of the three means the variable either isn't visible, isn't settable, or doesn't actually affect anything. Pick the right `PLUGIN_VAR_*` flag (`READONLY` for `--option-only`, `OPCMDARG` for runtime-settable bool, `RQCMDARG` when a value is required). A missing `update` callback is the usual reason `SET GLOBAL` "succeeds" but does nothing.

---

## See also

- Root [`CLAUDE.md`](../../CLAUDE.md) — project overview, build, branch policy.
- [`sql/CLAUDE.md`](../../sql/CLAUDE.md) — the SQL side of the bridge (handler / handlerton API, THD, error machinery).
- [`.claude/review/innodb.md`](../../.claude/review/innodb.md) — **canonical InnoDB review wisdom**. Read before any non-trivial InnoDB PR.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) — general correctness; lifetime/ownership and integer-overflow rules apply to InnoDB too.
- [`.claude/review/coding-style.md`](../../.claude/review/coding-style.md) — server-wide style. InnoDB has its own sub-dialect on top of this; see [`.claude/review/innodb.md`](../../.claude/review/innodb.md) §"The InnoDB style sub-dialect".
- [`.claude/review/testing.md`](../../.claude/review/testing.md) — MTR test expectations.
- [`.claude/review/logging-and-errors.md`](../../.claude/review/logging-and-errors.md) — `sql_print_*` vs `my_error` vs `ib::*`.
- [`.claude/skills/mfix/SKILL.md`](../../.claude/skills/mfix/SKILL.md) — MDEV bug-fix end-to-end workflow.
- [`.claude/skills/mreview/SKILL.md`](../../.claude/skills/mreview/SKILL.md) — code-review orchestration.
- Forward references (not yet written):
  - `.claude/reference/glossary.md` (Phase 2) — definitions for `dberr_t`, `mtr_t`, `dfield_t`, `trx_t`, "page", "extent", "tablespace", etc.
  - `.claude/playbooks/add-system-variable.md` (Phase 3) — concrete InnoDB sysvar example.
  - `.claude/playbooks/forward-merge.md` (Phase 3) — InnoDB changes often span release branches.
  - `.claude/reference/threading-and-locks.md` (Phase 5) — server-wide context for `sux_lock` and friends.
  - `.claude/reference/debug-tooling.md` (Phase 5) — `UNIV_DEBUG`, `WITH_INNODB_EXTRA_DEBUG`, DBUG, rr-record.

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `b4e390790d1` (branch `main`).
- **Files surveyed:**
  - Full `ls storage/innobase/` listing (31 subdirs + `CMakeLists.txt` + COPYING files; no checked-in `README*` / `*.md`).
  - Each subdir spot-listed to confirm representative files and to sanity-check the task's expected list — confirmed: `btr buf data dict eval fil fsp fts fut gis ha handler ibuf include lock log mem mtr mysql-test os page pars que read rem row srv sync trx unittest ut`. **Not present** (task list named them): `mach/` (the `mach0data.h` header lives in `include/`), `unzip/` (compressed-page code is in `page/page0zip.cc` + `buf/buf0buddy.cc`).
  - Spot-read [`storage/innobase/CMakeLists.txt`](CMakeLists.txt) line 434 for the `MYSQL_ADD_PLUGIN` invocation.
  - [`handler/ha_innodb.cc`](handler/ha_innodb.cc) for the handlerton wiring (line 4109, 4127, 4128), `convert_error_code_to_mysql` (line 2043), and the `innobase_xa_*` callbacks (line 1181, 1194).
  - [`include/db0err.h`](include/db0err.h) for `dberr_t`.
  - [`include/mtr0mtr.h`](include/mtr0mtr.h) for the mtr API and `MTR_LOG_NO_REDO`.
  - [`include/sux_lock.h`](include/sux_lock.h), [`include/srw_lock.h`](include/srw_lock.h), [`sync/srw_lock.cc`](sync/srw_lock.cc) for the latch primitives.
  - [`include/buf0buf.h`](include/buf0buf.h) for `buf_page_get_gen`.
  - [`include/row0mysql.h`](include/row0mysql.h) for `row_prebuilt_t`.
  - [`include/trx0trx.h`](include/trx0trx.h) for `trx_t`.
  - [`include/row0row.h:352`](include/row0row.h) and many `ut_ad` sites for latch-order comments; confirmed there is **no central enumeration** file.
  - [`.claude/review/innodb.md`](../../.claude/review/innodb.md) — for citation targets (PR4036, PR4342, PR4405, PR4430, PR4446, PR4717, PR4746, PR4747, PR4783, PR4797, PR4824, PR4858, PR4884, PR4887, PR4914, PR4913, PR4905, PR5018).
  - `git log --since "12 months ago" --oneline -- storage/innobase/<file>` for each hot-file count cited (ha_innodb.cc = 61, buf0buf.cc = 29, fil0fil.cc = 37). Total InnoDB commits in window: 259.
- **Deliberately excluded:**
  - File-by-file paraphrase. Read the file, not a summary.
  - The full latch-order graph. There is no central source of truth and a partial paraphrase would be worse than none — readers are directed to the in-source `ut_ad`s and "latching order" comments.
  - Per-record-format / per-page-format byte layouts. Those live in the headers; a deep reference (`storage/innobase/docs/page-format.md`) is appropriate later if needed.
  - MySQL InnoDB cross-references. Documented at the top: don't assume MySQL docs apply.
  - The Connector-C-style "what is a B+tree" tutorial. Out of scope.
- **Refresh procedure:**
  - When a subdirectory is added/renamed under `storage/innobase/`, update the subdir map.
  - When a new hot file (≥ 20 commits / 12 months) emerges, update the §"Subdirectory map" annotation and the §"Where to start" table.
  - When [`.claude/review/innodb.md`](../../.claude/review/innodb.md) gains a section, cross-link it.
  - When a redo-log format version or page-format change lands, update §"On-disk page format" and §"Redo log".
  - Bump `last-verified` to the new walk-through date.
