---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/log.cc, sql/log_event.{cc,h}, sql/log_event_server.cc, sql/rpl_mi.cc, sql/rpl_rli.cc, sql/rpl_parallel.cc, sql/rpl_gtid.cc, sql/rpl_record.cc, sql/slave.cc, sql/sql_repl.cc, sql/semisync_master.cc, sql/semisync_slave.cc, sql/wsrep_*.cc, sql/wsrep_dummy.cc
---

# Reference: replication

Deep dive on MariaDB's replication subsystem — binlog format, log-event types, the master-side write path, the slave thread model, parallel applier, GTID, semi-sync, WSREP/Galera integration, and RBR/SBR/MIXED format selection. The **map** of files in `sql/` lives in [`sql/CLAUDE.md`](../CLAUDE.md) §"Replication" — read that first. This doc goes *inside*.

Term definitions (binlog, GTID, RBR/SBR/MIXED, relay log, semisync, WSREP, `wsrep_dummy.cc`) are in [`.claude/reference/glossary.md`](../../.claude/reference/glossary.md) §"Replication & WSREP".

---

## 1. TL;DR

- **MariaDB replication is asynchronous by default**, **semi-synchronous** with the in-tree plugin ([`sql/semisync_master.cc`](../semisync_master.cc) / [`semisync_slave.cc`](../semisync_slave.cc)), **synchronous** with **WSREP/Galera** ([`sql/wsrep_*.cc`](../wsrep_mysqld.cc) plus the `wsrep-lib` submodule). Plus a binlog-only "archival" mode where no slave is attached.
- **Master writes events to the binary log** ([`sql/log.cc`](../log.cc) → `MYSQL_BIN_LOG`); the slave's I/O thread pulls them, writes them to its local **relay log**; the SQL thread (or a pool of parallel workers) applies them. Two thread roles per replication channel.
- **Row-based (RBR)**, **statement-based (SBR)**, and **mixed (MIXED)** binlog formats coexist. Choice is per-statement, governed by `binlog_format` and the statement's unsafe-classification (`enum_binlog_stmt_unsafe` in [`sql/sql_lex.h`](../sql_lex.h)).
- **GTID** is MariaDB's transaction identifier — `<domain>-<server_id>-<seq>`. Distinct from MySQL's `uuid:N` format; heterogeneous replication needs conversion.
- **WSREP/Galera** lives in `sql/wsrep_*.cc` + the `wsrep-lib` submodule. [`sql/wsrep_dummy.cc`](../wsrep_dummy.cc) provides empty stubs so the server compiles with `WITH_WSREP=OFF`; any new wsrep-only code must compile against the stub or stay behind `#ifdef WITH_WSREP`. See [`sql/CLAUDE.md`](../CLAUDE.md) §"Replication".

---

## 2. The big picture

```
   Client                        Master                              Slave
   ──────                        ──────                              ─────
                                ┌──────────┐                       ┌──────────┐
   COMMIT  ───────────────>     │ engines  │   binlog              │ slave IO │ <-- pulls events
                                │ (InnoDB) │  ──────>              │  thread  │ --> relay log
                                ├──────────┤  (COM_BINLOG_DUMP)    └──────────┘         │
                                │   log.cc │                             ^              v
                                │MYSQL_BIN_│                             |        ┌──────────┐
                                │   LOG    │                             |        │ slave SQL │
                                └──────────┘                             |        │ thread or │
                                      │                                  |        │ rpl_parallel│
                                      v                                  |        │  workers  │
                                ┌──────────┐                       ┌──────────┐  └─────┬─────┘
                                │ binlog   │ <- mariadb-binlog     │ Master_  │        v
                                │ files    │    SHOW BINLOG EVENTS │  info    │   ┌──────────┐
                                └──────────┘                       │ Relay_   │   │ engines  │
                                                                   │ log_info │   │ on slave │
                                                                   └──────────┘   └──────────┘
```

`Master_info` ([`sql/rpl_mi.cc`](../rpl_mi.cc)) tracks per-master state (host, port, position, credentials). `Relay_log_info` ([`sql/rpl_rli.cc`](../rpl_rli.cc)) tracks per-channel apply state (last applied position, error state, parallel-worker bookkeeping).

---

## 3. Binlog format and event types

A binlog file is a sequence of **log events**. Every event starts with a common header (timestamp, event type, server_id, event length, end-position) and a type-specific body. The on-disk layout is **version-stable**: the first event in every binlog file is a `FORMAT_DESCRIPTION_EVENT` declaring the writer's binlog version and per-event-type body lengths, so an older slave can read a newer master's binlog within ABI limits.

Major event types — definitions in [`sql/log_event.h`](../log_event.h) `enum Log_event_type`:

| Event | When written | Notes |
|---|---|---|
| `FORMAT_DESCRIPTION_EVENT` | First event in every file | Binlog version + per-event-type body lengths. |
| `GTID_EVENT` | Start of every transaction | MariaDB GTID; distinct from MySQL's `GTID_LOG_EVENT` (33) — MariaDB uses 162. |
| `QUERY_EVENT` | SBR statement | Raw SQL text + session state. `is_part_of_group()` check in [`log_event.h`](../log_event.h). |
| `INTVAR_EVENT`, `RAND_EVENT`, `USER_VAR_EVENT` | Before SBR statement | Session state replay (`LAST_INSERT_ID`, `RAND()` seed, user vars). |
| `TABLE_MAP_EVENT` | Before every row-event batch | Table metadata (id, name, column defs). |
| `WRITE_ROWS_EVENT_V1` / `_EVENT` (`= 23` / `= 30`) | RBR INSERT | V1 is the MariaDB-and-MySQL-5.1+ format; the unsuffixed (V2) variant is MySQL-5.6+. |
| `UPDATE_ROWS_EVENT_V1` / `_EVENT` (`= 24` / `= 31`) | RBR UPDATE | Both before- and after-images. |
| `DELETE_ROWS_EVENT_V1` / `_EVENT` (`= 25` / `= 32`) | RBR DELETE | Before-image only. |
| `XID_EVENT` | Transactional commit | Engine XID; signals end of a transaction. |
| `ROTATE_EVENT` | File rotation | Names the next binlog file. |
| `STOP_EVENT`, `INCIDENT_EVENT` | Housekeeping / replication-gap notices | |
| `ANNOTATE_ROWS_EVENT` (`= 160`) | RBR statement annotation | MariaDB-only; carries the originating SQL text for human-readable `mariadb-binlog` output. |
| `BINLOG_CHECKPOINT_EVENT` (`= 161`) | XA crash-recovery marker | Master-side only. |
| `GTID_LIST_EVENT` (`= 163`) | Start of every binlog file | Snapshot of `gtid_binlog_pos` for fast seek. |
| `START_ENCRYPTION_EVENT` (`= 164`) | After FDE if binlog encryption is on | |
| `QUERY_COMPRESSED_EVENT`, `*_COMPRESSED_*` (`= 165`–`171`) | When `log_bin_compress=ON` | Compressed body. Event number layout is **load-bearing**: type conversion is `(t − WRITE_ROWS_COMPRESSED_EVENT + WRITE_ROWS_EVENT)`. |
| `PARTIAL_ROW_DATA_EVENT` (`= 172`) | When row exceeds `slave_max_allowed_packet` | MDEV-32570 (server-side `1eff7ddd810`, client-side `5fda8988a6c`) — splits a single oversize row event into pieces. |

`MARIA_EVENTS_BEGIN= 160` is the boundary above which all event numbers are MariaDB-only. The comment at line 708 in `log_event.h` is load-bearing: **"Existing events (except `ENUM_END_EVENT`) should never change their numbers."** Bumping `ENUM_END_EVENT` is the only safe extension.

Each type is a class in [`sql/log_event.h`](../log_event.h) deriving from `Log_event` (line 1270): `Query_log_event`, `Format_description_log_event`, `Xid_log_event`, `Gtid_log_event`, `Rows_log_event` (with the V1/V2 + compressed subclasses), `Rows_log_event_fragmenter` (the splitter for `PARTIAL_ROW_DATA_EVENT`). Read 2–3 of these for shape; don't try to memorise the lot. The implementations are split:

- [`log_event.cc`](../log_event.cc) — common reader/writer (~4 250 lines).
- [`log_event_server.cc`](../log_event_server.cc) — server-side write + apply paths (~8 930 lines).
- [`log_event_client.cc`](../log_event_client.cc) — `mariadb-binlog` decoder paths.

**Changing the format is heavily reviewed.** See [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"Replication / binlog wire format": new event numbers go at the end, existing numbers never change, GTID format invariants are not negotiable, and `bnestere`/`andrelkin` are the reviewers for any binlog-format change. PR4697 (`binlog_row_event_max_size` default) was explicitly version-gated.

---

## 4. The master-side write path

Canonical file: [`sql/log.cc`](../log.cc) (~15 350 lines). The class is `MYSQL_BIN_LOG` ([`log.h:628`](../log.h)) which extends `TC_LOG` (transaction-coordinator log) and `Event_log`. Key entry points:

| Function | What it does |
|---|---|
| `MYSQL_BIN_LOG::write(Log_event*)` ([`log.cc:8667`](../log.cc)) | Write one event (called by ad-hoc loggers — e.g. `Incident_log_event`). |
| `MYSQL_BIN_LOG::write_event(Log_event*)` ([`log.cc:7046`](../log.cc)) | Low-level: serialise event to the active `IO_CACHE`. |
| `MYSQL_BIN_LOG::write_table_map(THD*, TABLE*)` ([`log.cc:7962`](../log.cc)) | Emit `TABLE_MAP_EVENT` before a row-event batch. |
| `MYSQL_BIN_LOG::write_transaction_or_stmt` ([`log.cc:11169`](../log.cc)) | Per-transaction commit body. |
| `MYSQL_BIN_LOG::trx_group_commit_leader` ([`log.h:809`](../log.h)) | **Group commit** — multiple transactions share a single `fsync`. |
| `ha_commit_trans(THD*, bool)` ([`sql/handler.cc:1757`](../handler.cc)) | Cross-engine commit coordinator. Calls into `MYSQL_BIN_LOG` to flush the binlog **before** each engine commits, so binlog and engine state stay consistent across crash. |

**Binlog rotation** happens at `max_binlog_size`, on `FLUSH LOGS`, or on `FLUSH BINARY LOGS`. Each new file gets a fresh `FORMAT_DESCRIPTION_EVENT` followed by a `GTID_LIST_EVENT` snapshot.

**Group commit.** Concurrent committing sessions queue on `MYSQL_BIN_LOG::group_commit_queue`; one elected leader writes the binlog for the whole batch and triggers engine commits in order. Crucial for throughput on rotational disks. The mechanism is woven through `trx_group_commit_leader`, `trx_group_commit_with_engines`, and the per-entry `group_commit_entry` struct ([`log.h:654`](../log.h)).

**Row packing for RBR.** Done in [`sql/rpl_record.cc`](../rpl_record.cc): `pack_row()` ([`rpl_record.cc:74`](../rpl_record.cc)) and `unpack_row()` (line 319). Format is per-`Field` engine packing (same as on-disk), preceded by a NULL-bit vector. **Changing the pack format breaks the wire** — see review-rule citation in §3.

**Newer "binlog-in-engine".** A recent option (`--binlog-storage-engine=innodb`, commit `7081f2a58ec`) integrates the binlog into InnoDB's WAL; see [`Docs/replication/binlog.md`](../../Docs/replication/binlog.md) for the on-disk layout (16 KiB pages, CRC32 trailer, chunked records, compressed-integer encoding). This is **not** the default; the classical binlog code path remains the primary surface.

---

## 5. The slave-side read path

Two threads per replication channel — both spawned from [`sql/slave.cc`](../slave.cc), driven by a `Master_info` ([`rpl_mi.cc`](../rpl_mi.cc)) and a `Relay_log_info` ([`rpl_rli.cc`](../rpl_rli.cc)):

### 5.1 I/O thread

Entry point: `handle_slave_io()` ([`slave.cc:4490`](../slave.cc)). Spawned via `start_slave_thread(..., handle_slave_io, ...)` ([`slave.cc:1372`](../slave.cc)).

The I/O thread connects to the master, sends `COM_BINLOG_DUMP` / `COM_BINLOG_DUMP_GTID` ([`sql/sql_repl.cc`](../sql_repl.cc) handles the master side), and reads events into the local **relay log**. `Master_info` records the current master log file + position; `Relay_log_info::relay_log` records where they landed locally.

### 5.2 SQL thread

Entry point: `handle_slave_sql()` ([`slave.cc:5154`](../slave.cc)). Reads from the relay log and applies events to the local server.

`Relay_log_info` ([`rpl_rli.h:63`](../rpl_rli.h)) tracks:

- Current relay-log file + position (`group_relay_log_name`, `group_relay_log_pos`).
- Last committed master position (`group_master_log_name`, `group_master_log_pos`).
- Slave error state (via the `Slave_reporting_capability` base).
- Per-channel filters (`Rpl_filter`) and parallel-worker pool pointer.

`Master_info` (`rpl_mi.h:152`, extends `Master_info_file` + `Slave_reporting_capability`) is the per-master singleton: connection params, parallel-mode setting, GTID position, heartbeat config. The on-disk format of `master.info` and `relay-log.info` was refactored in **MDEV-37530** (commit `89bd6b00335`) to iterable tuples — touching that format requires the same care as binlog wire format.

### 5.3 Relevant recent bugs

`git log --oneline -- sql/slave.cc | head` — pick a few for context:

- **MDEV-38497** (`43de3460bae`) — `RESET SLAVE ALL` was leaving residual config.
- **MDEV-15327** (`d755574c47f`) — `Master_Server_Id` not reset on `CHANGE MASTER` / `RESET SLAVE`.
- **MDEV-29466** (`bd06d0de6c4`) — renamed `description_event_for_exec` → `description_event_for_sql_thread` to disambiguate from the I/O thread's FDE.
- **MDEV-38731** (`ba305095ffe`) — wrong index usage in RBR when no PK.
- **MDEV-38117** (`de15b1160d8`) — replication stops on multi-master with no PK.

---

## 6. Parallel applier

[`sql/rpl_parallel.cc`](../rpl_parallel.cc) (~3 650 lines). The SQL thread can dispatch event groups to a pool of worker threads (`rpl_parallel_thread`), each running `handle_rpl_parallel_thread()` ([`rpl_parallel.cc:1233`](../rpl_parallel.cc)).

### 6.1 The four modes

From [`sql/mysqld.h:69`](../mysqld.h) (must match `slave_parallel_mode_typelib` in [`sys_vars.cc`](../sys_vars.cc), see comment in the header):

```cpp
enum enum_slave_parallel_mode {
  SLAVE_PARALLEL_NONE,           // sequential apply
  SLAVE_PARALLEL_MINIMAL,        // only DDL of independent domains
  SLAVE_PARALLEL_CONSERVATIVE,   // only transactions the master pre-marked as parallel-safe (commit_id)
  SLAVE_PARALLEL_OPTIMISTIC,     // assume independence, detect conflicts, retry on conflict
  SLAVE_PARALLEL_AGGRESSIVE      // even more eager parallelisation
};
```

Default: `SLAVE_PARALLEL_OPTIMISTIC` (`Rpl_filter::parallel_mode` ctor in [`rpl_filter.cc:28`](../rpl_filter.cc)).

The dispatch decision lives around [`rpl_parallel.cc:3389`](../rpl_parallel.cc) — when a `GTID_EVENT` arrives, the worker pool is chosen by comparing `mi->parallel_mode` against the event's commit-id / group ordering. Conservative mode trusts the master's `cid` (commit-id) field in `Gtid_log_event` to declare parallel-safety; optimistic mode ignores it and lets the workers race + retry.

### 6.2 Common bug surface

Parallel-applier bugs are a recurring source of MDEVs because the scheduler interacts with engine-internal locking, GTID domain semantics, and prepared-statement memory. `git log --oneline -- sql/rpl_parallel.cc | head` (selected):

- **MDEV-38776** (`8fe41532c16`) — worker thread retried a transaction 10 times in vain, giving up.
- **MDEV-38212 / MDEV-37686** (`7f3145e068b`) — breaks in parallel replication.
- **MDEV-36840** (`f7ba16980da`) — `Seconds_Behind_Master` spike at log rotation on parallel replica.
- **MDEV-35570** (`8c817e2d8ad`) — parallel slave `ALTER SEQUENCE` attempted to binlog out-of-order.
- **MDEV-35465** (`a2575a07034`) — async replication stops working on Galera async-replica node when parallel replication is enabled.
- **MDEV-34049** (`d959acbbf84`) — parallel access to temp table across different `domain_id`.
- **MDEV-20065** (`07d71fdcf8a`) — parallel replication for Galera slave.

When fixing parallel-applier code, always run the `rpl` MTR suite under several `slave_parallel_mode` combinations (`conservative`, `optimistic`, `aggressive`) — most regressions surface only in one mode.

---

## 7. GTID — global transaction ID

MariaDB GTID format: **`<domain>-<server_id>-<seq>`**.

| Component | Meaning |
|---|---|
| `domain` (uint32) | An independent transaction stream. Different domains can be applied in parallel **without** coordination — the master is responsible for setting domain on `BEGIN`. Default is 0. |
| `server_id` (uint32) | The originator. Lets a slave know which transactions to skip on re-replication. |
| `seq` (uint64) | Monotonically increasing per-domain sequence number. |

Defined in [`sql/rpl_gtid.h`](../rpl_gtid.h) — key structures:

- `rpl_gtid` — a single triple.
- `rpl_slave_state` ([`rpl_gtid.h:126`](../rpl_gtid.h)) — per-domain "what has this slave applied". Maintained in-memory **and** persisted to the `mysql.gtid_slave_pos` table (per-engine variant table via `gtid_pos_table`).
- `slave_connection_state` — the position a slave sends to the master on `COM_BINLOG_DUMP_GTID`.

Server variables exposed: `gtid_binlog_pos`, `gtid_current_pos`, `gtid_slave_pos`, `gtid_domain_id`, `gtid_seq_no`. The `mysql.gtid_slave_pos*` system tables (one per chosen storage engine) hold the persistent slave position; updates to them are part of the slave's apply transaction so position + data move together atomically.

**Distinct from MySQL.** MySQL's GTID is `uuid:N` (server UUID, transaction number) and uses event types 33–35 (`GTID_LOG_EVENT`, `ANONYMOUS_GTID_LOG_EVENT`, `PREVIOUS_GTIDS_LOG_EVENT`) — MariaDB explicitly ignores those (see [`log_event.h:688`](../log_event.h) "MySQL 5.6 GTID events, ignored by MariaDB") and uses event type 162 (`GTID_EVENT`) plus 163 (`GTID_LIST_EVENT`). **Heterogeneous MariaDB↔MySQL replication requires conversion**; changing GTID semantics breaks it.

Bugs recently:

- **MDEV-38641** (`cbbb3e51d29`) — replication of system-versioning tables.
- **MDEV-20586** (`13aad4ed2b1`) — incorrect commit of transaction in GTID table processing.

---

## 8. Semi-sync

In-tree plugins ([`sql/semisync_master.cc`](../semisync_master.cc), [`semisync_slave.cc`](../semisync_slave.cc)). The class is `Repl_semi_sync_master` ([`semisync_master.h:413`](../semisync_master.h)). Activated by `rpl_semi_sync_master_enabled` + the slave-side counterpart `rpl_semi_sync_slave_enabled`.

**Behaviour.** When enabled, the master commits the transaction in storage engines, then waits — up to `rpl_semi_sync_master_timeout` (ms) — for at least one slave to ACK that it has written the binlog event to **its** relay log. The client is unblocked only after that ACK (the `AFTER_COMMIT` mode) or after the binlog flush but before the engine commit (`AFTER_SYNC` mode).

**Fault model: best-effort, not synchronous commit.** If no slave ACKs within the timeout, the master logs a warning and **falls back to asynchronous replication** (`rpl_semi_sync_master_status` flips off). Subsequent transactions don't wait. When a slave reconnects, semi-sync may re-engage. **Do not conflate semi-sync with WSREP's synchronous commit** — semi-sync gives a durability hint, not a cluster-consistency guarantee.

Recent fixes:

- **MDEV-37120** (`002330e542c`) — timeout log-message clarity.
- **MDEV-36934** (`4c8af2007d4`) — master became unresponsive when a replica stopped (a known fault-tolerance gap).
- **MDEV-36663** (`1d5557d9c0b`) — replica can't kill dump thread when using SSL.

---

## 9. WSREP / Galera

`sql/wsrep_*.cc` is the integration layer; the `wsrep-lib` git submodule provides the certification-based total-order replication protocol; the `galera-4` library (built separately) is the wire protocol. Galera **replaces** the binlog with a write-set replicated at COMMIT time — the transaction can't commit until **all** cluster nodes have certified it. This is what makes Galera "synchronous".

Key concepts (definitions in [`.claude/reference/glossary.md`](../../.claude/reference/glossary.md) §"Replication & WSREP"):

- **Write-set** — the set of rows touched by a transaction plus its key fingerprints, packaged for total-order delivery.
- **Certification** — every node receives the write-set in the same order; each independently decides commit-or-abort based on conflicts with locally-running transactions.
- **TOI** (Total Order Isolation) — DDL is serialised cluster-wide: every node executes it at the same point in the total order. Default for most DDL.
- **RSU** (Rolling Schema Upgrade) — DDL applied node-by-node, opt-in via `wsrep_OSU_method=RSU`. Lets a schema upgrade proceed without blocking the cluster, at the cost of split-brain risk during the rolling window.
- **SST** / **IST** — state-snapshot transfer / incremental state transfer. How a joining node catches up.

### 9.1 The `wsrep_dummy.cc` story

When the build is configured `WITH_WSREP=OFF`, [`sql/wsrep_dummy.cc`](../wsrep_dummy.cc) (~174 lines) provides empty stubs for every `wsrep_*` function the server expects to be able to call unconditionally. Examples (line 23 onward): `wsrep_is_wsrep_xid`, `wsrep_prepare_key_for_innodb`, `wsrep_consistency_check`, `wsrep_lock_rollback`, `wsrep_thd_LOCK`, `wsrep_thd_kill_LOCK`, `wsrep_thd_self_abort`, `wsrep_set_data_home_dir`, etc.

**The invariant for new code:** any reference to a wsrep-only function from outside `sql/wsrep_*.cc` must either:

1. Exist in `wsrep_dummy.cc` as a stub, **or**
2. Stay behind `#ifdef WITH_WSREP`.

This is restated in [`sql/CLAUDE.md`](../CLAUDE.md) §"Replication". Build breakage with `WITH_WSREP=OFF` is the canonical CI signal that this rule was violated.

### 9.2 Recent bugs

- **MDEV-39011** (`9f8f6d24dbf`) — THD leak in async slave error path with `wsrep_restart_slave`.
- **MDEV-30612** (`1e3b820f2cd`) — usage of `lex->definer` in `wsrep_create_trigger_query`.
- **MDEV-28750** (`1f34996880f`) — `multi_update::send_eof()` assertion.
- **MDEV-35969** (`a0b69304e50` / `e06f5b2579b`) — service-manager status detail.

Galera development happens externally in `codership/` repos — cross-repo coordination is required for protocol-level changes ([`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"Codership / Galera").

---

## 10. RBR / SBR / MIXED — format choice

`binlog_format` = `STATEMENT` / `ROW` / `MIXED`. The choice is per-statement, made by the server based on the statement's classification:

- **`STATEMENT` (SBR).** Emit `QUERY_EVENT` with the original SQL. Cheap, replays exactly. Fails for non-deterministic statements (`NOW()`, `UUID()`, `RAND()` — handled via auxiliary `INTVAR_EVENT` / `RAND_EVENT` / `USER_VAR_EVENT` to ship session state). Fails entirely for statements whose effect depends on data the slave doesn't see (e.g. `UPDATE … LIMIT N` without `ORDER BY`).
- **`ROW` (RBR).** Emit `TABLE_MAP_EVENT` + `WRITE_ROWS_EVENT_V1` / `UPDATE_ROWS_EVENT_V1` / `DELETE_ROWS_EVENT_V1` carrying packed row images (before, after, or both — packed by `pack_row()` in [`rpl_record.cc:74`](../rpl_record.cc)). More precise; bigger; required for non-deterministic effects. RBR + no PK has performance and correctness traps — see MDEV-38731 / MDEV-38117 above.
- **`MIXED`.** Per-statement: SBR by default; RBR for "unsafe" statements. The classification list is `enum_binlog_stmt_unsafe` in [`sql/sql_lex.h:1840`](../sql_lex.h) — values include:

  | Constant | Trigger |
  |---|---|
  | `BINLOG_STMT_UNSAFE_LIMIT` | `LIMIT` without ORDER BY |
  | `BINLOG_STMT_UNSAFE_INSERT_DELAYED` | `INSERT DELAYED` |
  | `BINLOG_STMT_UNSAFE_SYSTEM_TABLE` | Direct DML on a `mysql.*` table |
  | `BINLOG_STMT_UNSAFE_AUTOINC_COLUMNS` | Statement that reads an auto-increment column it doesn't own |
  | `BINLOG_STMT_UNSAFE_UDF` | UDF (possibly non-deterministic) |
  | `BINLOG_STMT_UNSAFE_SYSTEM_VARIABLE` | Read of a session-state variable |
  | `BINLOG_STMT_UNSAFE_SYSTEM_FUNCTION` | Call to a non-deterministic built-in |
  | `BINLOG_STMT_UNSAFE_NONTRANS_AFTER_TRANS` | Mixed transactional + non-transactional writes |
  | `BINLOG_STMT_UNSAFE_MIXED_STATEMENT` | Mixed within one statement |
  | `BINLOG_STMT_UNSAFE_INSERT_IGNORE_SELECT`, `_INSERT_SELECT_UPDATE`, `_WRITE_AUTOINC_SELECT`, `_REPLACE_SELECT` | Specific INSERT/REPLACE … SELECT patterns |

`Query_log_event::is_unsafe()` and `LEX::set_stmt_unsafe()` are the runtime check / classification points. **Adding a new Item or a new built-in function?** Decide which flags apply (does it read session state? is it non-deterministic? does it depend on schema not present on the slave?) and mark it via `set_stmt_unsafe(BINLOG_STMT_UNSAFE_*)`. Missing or inconsistent marking is a recurring review-flag — see [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) and [`sql/docs/item-system.md`](item-system.md) (the `IS_UNSAFE` mention).

**RBR vs SBR diverge on time semantics**: PR4933 (bnestere) — time-clamping path was different between RBR and SBR. Always test both paths.

---

## 11. Pitfalls and review patterns

- **Adding a new `Log_event_type` value or changing an existing one breaks the wire.** New numbers go at the end; existing ones never change (load-bearing comment at [`log_event.h:708`](../log_event.h)). Bump `ENUM_END_EVENT` only. Update `Format_description_log_event::Format_description_log_event()` per-type body lengths.
- **Changing `pack_row()` / `unpack_row()` format** — [`rpl_record.cc:74`](../rpl_record.cc) — breaks replication wire format **between versions**. Heavily reviewed; needs version-negotiation story.
- **Changing GTID `<domain>-<server_id>-<seq>` semantics** — heterogeneous MariaDB↔MySQL and forward-compatibility break. The format is contractual.
- **Adding a wsrep call without `WITH_WSREP=OFF` build coverage.** Either add to [`wsrep_dummy.cc`](../wsrep_dummy.cc) or wrap in `#ifdef WITH_WSREP`. The build is the canary.
- **`IS_UNSAFE` markings inconsistent between SBR and MIXED.** Adding an Item that reads session state without `BINLOG_STMT_UNSAFE_SYSTEM_VARIABLE` corrupts SBR replicas silently.
- **Parallel-applier ordering assumptions vs engine locking.** Conservative trusts `commit_id`; optimistic detects conflicts and retries. If your fix touches lock-order, run all three modes (MDEV-35570, MDEV-38776).
- **Semi-sync ≠ synchronous commit.** It is best-effort, fall-back-to-async on timeout. Don't document it as a durability guarantee. (MDEV-36934 was exactly the "what happens when the only ACK-er stops" case.)
- **`include/reset_master.inc` over inline `RESET MASTER`** in MTR tests — more portable, includes the right sync barrier (PR4771 knielsen, [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Replication / binlog").
- **`binlog_row_event_max_size` default changes are version-gated.** PR4697; don't change without a story for older slaves.
- **Submodule bumps (`wsrep-lib`, `libmariadb`) are out-of-band PRs.** Don't fold a `.gitmodules` SHA bump into a replication feature/bug-fix ([`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"Submodules", PR3726/PR4557/PR4829).
- **`Master_info` / `Relay_log_info` file-format changes** (the on-disk `master.info`, `relay-log.info`) — heavily reviewed (MDEV-37530 refactored them to iterable tuples).
- **Test prepared-statement and stored-program variants** for any new replication feature ([`.claude/review/testing.md`](../../.claude/review/testing.md), PR4433).

---

## 12. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) §"Replication" — file map.
- [`.claude/reference/glossary.md`](../../.claude/reference/glossary.md) §"Replication & WSREP" — term definitions.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Replication / binlog".
- [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"Replication / binlog wire format", §"Codership / Galera", §"Submodules".
- [`sql/docs/item-system.md`](item-system.md) — for `IS_UNSAFE` marking of new `Item` subclasses.
- [`Docs/replication/binlog.md`](../../Docs/replication/binlog.md) — the new binlog-in-engine on-disk format spec.
- Forward refs:
  - [`sql/docs/optimizer.md`](optimizer.md) (Phase 4) — for the RBR row-event emission path during executor stage.
  - `.claude/reference/debug-tooling.md` (Phase 5) — for slave-side debug recipes, `DEBUG_SYNC` patterns common to `rpl_*` tests.

---

## 13. How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `1205ba92f5a` (branch `main`).
- **Files surveyed:**
  - [`sql/log.cc`](../log.cc) (15 354 lines), [`sql/log.h`](../log.h) — `MYSQL_BIN_LOG` class, group-commit machinery.
  - [`sql/log_event.h`](../log_event.h) — `enum Log_event_type` (lines 617–765) and class declarations (`Log_event`, `Query_log_event`, `Format_description_log_event`, `Xid_log_event`, `Gtid_log_event`, `Rows_log_event`).
  - [`sql/log_event.cc`](../log_event.cc) / [`log_event_server.cc`](../log_event_server.cc) / [`log_event_client.cc`](../log_event_client.cc) — entry points only.
  - [`sql/rpl_mi.h`](../rpl_mi.h) / [`rpl_rli.h`](../rpl_rli.h) — `Master_info`, `Relay_log_info` class signatures.
  - [`sql/rpl_parallel.cc`](../rpl_parallel.cc) — `handle_rpl_parallel_thread`, dispatch around line 3389.
  - [`sql/rpl_gtid.h`](../rpl_gtid.h) — `rpl_slave_state`, `gtid_pos_table`.
  - [`sql/rpl_record.cc`](../rpl_record.cc) — `pack_row` (line 74), `unpack_row` (line 319).
  - [`sql/slave.cc`](../slave.cc) — `handle_slave_io` (line 4490), `handle_slave_sql` (line 5154), spawn at line 1372/1382.
  - [`sql/mysqld.h`](../mysqld.h) — `enum_slave_parallel_mode` (line 69).
  - [`sql/sql_lex.h`](../sql_lex.h) — `enum_binlog_stmt_unsafe` (line 1840).
  - [`sql/semisync_master.h`](../semisync_master.h) / [`semisync_master.cc`](../semisync_master.cc) — `Repl_semi_sync_master`, timeout vars.
  - [`sql/wsrep_dummy.cc`](../wsrep_dummy.cc) — stub list (174 lines).
  - [`Docs/replication/binlog.md`](../../Docs/replication/binlog.md) — the new binlog-in-engine spec.
  - `.claude/review/api-and-architecture.md` §"Replication / binlog wire format" / §"Codership / Galera" / §"Submodules".
  - `.claude/review/correctness-and-security.md` §"Replication / binlog".
  - `.claude/reference/glossary.md` §"Replication & WSREP".
  - `git log --oneline -- sql/rpl_*.cc sql/log.cc sql/log_event*.cc sql/slave.cc sql/rpl_parallel.cc sql/wsrep_*.cc sql/semisync_*.cc` — for MDEV citations.
- **Deliberately excluded:**
  - Line-by-line paraphrase of `MYSQL_BIN_LOG`, `Log_event`, or any of the >1 000-line classes — read the file.
  - Full XA / 2PC walkthrough — beyond scope; pointers only.
  - Galera protocol internals (certification queue, EVS, gcomm) — those live in `wsrep-lib` / `galera-4`, not in `sql/`.
  - The Connector/C side of `COM_BINLOG_DUMP*` — that's [`libmariadb/`](../../libmariadb/).
  - `mariadb-binlog` CLI flags — `client/mysqlbinlog.cc`, not server-side.
- **Refresh procedure:**
  - If `enum Log_event_type` ([`log_event.h:617`](../log_event.h)) gains a new entry, update §3.
  - If `enum_slave_parallel_mode` ([`mysqld.h:69`](../mysqld.h)) changes, update §6.1.
  - If `enum_binlog_stmt_unsafe` ([`sql_lex.h:1840`](../sql_lex.h)) gets new values, update §10.
  - If [`wsrep_dummy.cc`](../wsrep_dummy.cc) grows or shrinks, re-skim §9.1.
  - If a major replication-format MDEV lands, add to §5.3 / §6.2 / §7 / §8 / §9.2 as appropriate.
  - Re-run `git log --oneline -10 -- sql/rpl_parallel.cc` quarterly; replace stale MDEV citations.
  - Bump `last-verified` after walking through the code.
