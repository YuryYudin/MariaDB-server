---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/sql_acl.{cc,h}, sql/grant.{cc,h}, sql/privilege.h, sql/sql_priv.h
---

# Reference: ACL & privileges

The MariaDB authorisation system: the `mysql.*` grant tables, the in-memory caches that mirror them, the privilege bitmask in [`privilege.h`](../privilege.h), the per-statement check funnel, `GRANT` / `REVOKE` execution, and the role graph. Loaded on demand from [`sql/CLAUDE.md`](../CLAUDE.md) §"ACL & privileges" — that file lists the cluster; this file goes deep.

> **Authentication** (how a user proves who they are — `password.c`, auth plugins) is touched only briefly here. This doc is about **authorisation**: given a known user, what may they do.

## TL;DR

- **On-disk state** is six (sometimes seven) tables in the `mysql` schema: `mysql.global_priv` (canonical user/global table, formerly `mysql.user`), `mysql.db`, `mysql.tables_priv`, `mysql.columns_priv`, `mysql.procs_priv`, `mysql.proxies_priv`, `mysql.roles_mapping`. The legacy `mysql.host` table is read if present.
- **In-memory caches** mirror those tables: `acl_users`, `acl_dbs`, `acl_proxy_users`, `acl_hosts`, `acl_roles`, `acl_roles_mappings`, `column_priv_hash`, `proc_priv_hash`, `func_priv_hash`, `package_spec_priv_hash`, `package_body_priv_hash`. All live in [`sql_acl.cc`](../sql_acl.cc) as file-scope statics.
- **Roles are first-class principals** since 10.0.5: `ACL_ROLE` extends `ACL_USER_BASE`. The role graph is stored in `mysql.roles_mapping`; activated roles are unioned into `THD::security_ctx->master_access`.
- **A privilege check is `sctx->master_access & WANT_ACL`.** Bits are typed `privilege_t` (a strict enum) in [`privilege.h`](../privilege.h).
- **ACL is incrementally maintained.** `GRANT` / `REVOKE` mutates a single hash entry or `Dynamic_array` slot. A **full** rebuild from tables only happens at startup ([`acl_init`](../sql_acl.cc)), on `FLUSH PRIVILEGES` ([`acl_reload`](../sql_acl.cc) + [`grant_reload`](../sql_acl.cc)), and after `mariadb-upgrade` runs schema fixes.
- **Don't gate new functionality on `SUPER`.** Mint a new `*_ADMIN` bit in [`privilege.h`](../privilege.h) instead — see [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"ACL / privileges" and PR4743.

---

## 1. Storage layer — the grant tables

All grant tables live in the `mysql` schema. Their canonical names and the file-scope names that wrap them are in `MYSQL_TABLE_NAME[]` ([`sql_acl.cc`](../sql_acl.cc) near the `enum_acl_tables` definition — `grep -n 'enum_acl_tables\|MYSQL_TABLE_NAME' sql/sql_acl.cc`).

| Table | Purpose |
|---|---|
| `mysql.global_priv` | User accounts + global (instance-wide) privileges + auth plugin / password / SSL / resource limits / account-options JSON. Replaces the pre-10.4 `mysql.user`. There is **still** a `mysql.user` *view* over `global_priv` for backwards-compatible SQL. |
| `mysql.db` | Schema-level grants. Wildcards in `Db` allowed (`%`, `_`). Per-user × per-db row. |
| `mysql.tables_priv` | Table-level grants and column-level grant *parents*. |
| `mysql.columns_priv` | Column-level grants — one row per (user, db, table, column). |
| `mysql.procs_priv` | Routine-level grants: stored functions, procedures, packages (spec + body separately). The `Routine_type` column distinguishes them. |
| `mysql.proxies_priv` | `GRANT PROXY` mappings (`user@host` may impersonate `other@host`). |
| `mysql.roles_mapping` | Edges of the role graph: `Role` is granted to `User@Host` (where the grantee may itself be a role). |
| `mysql.host` *(legacy)* | Per-host overrides. Loaded if present; not created by modern installations. |

**The canonical loader** is [`acl_load(THD *, const Grant_tables&)`](../sql_acl.cc) (file-scope, ~line 2680). It is called from [`acl_init`](../sql_acl.cc) at server start and from [`acl_reload`](../sql_acl.cc) for `FLUSH PRIVILEGES`. The companion [`grant_load`](../sql_acl.cc) (~line 8228) populates the table / column / routine hashes, called from [`grant_init`](../sql_acl.cc) and [`grant_reload`](../sql_acl.cc).

> `grep -n 'acl_load\|acl_init\|acl_reload\|grant_init\|grant_load\|grant_reload' sql/sql_acl.cc`

Schema is created and migrated by [`scripts/mariadb_system_tables.sql`](../../scripts/mariadb_system_tables.sql) and [`scripts/mariadb_system_tables_fix.sql`](../../scripts/mariadb_system_tables_fix.sql) (executed by `mariadb-upgrade`). When you add a new privilege bit you **must** widen the relevant `SET(...)` column there — see [`privilege.h`](../privilege.h) header comment "when adding new privilege bits".

## 2. In-memory caches

All declared as file-scope statics at the top of [`sql_acl.cc`](../sql_acl.cc) (`grep -n 'static DYNAMIC_ARRAY acl_\|static HASH acl_\|static Dynamic_array<ACL_DB>' sql/sql_acl.cc`):

| Cache | Type | Mirrors | Notes |
|---|---|---|---|
| `acl_users` | `DYNAMIC_ARRAY` of `ACL_USER` | `mysql.global_priv` | Sorted; binary-searched by `(user, host)` after `rebuild_acl_users()`. |
| `acl_dbs` | `Dynamic_array<ACL_DB>` | `mysql.db` | Sorted by (host, db, user). |
| `acl_proxy_users` | `DYNAMIC_ARRAY` of `ACL_PROXY_USER` | `mysql.proxies_priv` | |
| `acl_hosts` | `DYNAMIC_ARRAY` of `ACL_HOST` | `mysql.host` | Legacy. |
| `acl_roles` | `HASH` of `ACL_ROLE` | role rows in `mysql.global_priv` (those with `is_role=Y`) | Key: rolename, utf8mb3_bin. |
| `acl_roles_mappings` | `HASH` of `ROLE_GRANT_PAIR` | `mysql.roles_mapping` | The edges of the role DAG. |
| `acl_check_hosts` | `HASH` | derived from `acl_users` / `acl_dbs` | Fast wildcard-free host lookup. |
| `acl_wild_hosts` | `DYNAMIC_ARRAY` | derived | Wildcard hosts that need pattern matching. |
| `column_priv_hash` | `HASH` of `GRANT_TABLE` | `mysql.tables_priv` + `mysql.columns_priv` | One entry per (user, host, db, table); the table grant lives on the entry, column grants in a child `HASH` named `hash_columns`. |
| `proc_priv_hash` | `HASH` of `GRANT_NAME` | `mysql.procs_priv` *(Routine_type=PROCEDURE)* | |
| `func_priv_hash` | `HASH` of `GRANT_NAME` | `mysql.procs_priv` *(FUNCTION)* | |
| `package_spec_priv_hash`, `package_body_priv_hash` | `HASH` of `GRANT_NAME` | `mysql.procs_priv` *(PACKAGE / PACKAGE BODY)* | The four "routine-like" hashes are selected per `Sp_handler` subclass — `grep -n 'get_priv_hash' sql/sql_acl.cc`. |
| `acl_cache` | `Hash_filo<acl_entry>` | derived | Per-`(thd_user, host, db)` resolved-`db_access` cache; invalidated by `grant_version`. |

**Locking.** Two locks cover everything:

- **`acl_cache->lock`** (`mysql_mutex_t`, owned by the `Hash_filo` instance) — guards the `acl_*` arrays/hashes and `acl_roles*`. Held briefly during reads and for all mutations. `grep -n 'mysql_mutex_lock(&acl_cache->lock)' sql/sql_acl.cc`.
- **`LOCK_grant`** ([`mysqld.cc`](../mysqld.cc) — `mysql_rwlock_t LOCK_grant`) — guards `column_priv_hash`, `proc_priv_hash`, `func_priv_hash`, `package_*_priv_hash`, and `grant_version`. **Read** lock during `check_grant*`, **write** lock during `mysql_table_grant` / `mysql_routine_grant` / `grant_reload`.

Order: acquire **`LOCK_grant` before `acl_cache->lock`**. Reload acquires both (and the underlying table locks before either). When you add a new operation that mutates ACL state, mirror an existing `GRANT` path — never invent a new locking order.

The `Hash_filo<acl_entry> *acl_cache` is a small per-connection-decision cache. It is keyed on `(user, host, db)` and stores the resolved `db_access` so that repeated statements in the same database avoid the full db-grant walk. It is invalidated by bumping `static uint grant_version` whenever the underlying state changes.

## 3. The privilege-bit enum

[`sql/privilege.h`](../privilege.h) defines `enum privilege_t : unsigned long long`. Each bit is a power of two; the enum is strict (overloaded operators in the same file forbid implicit `int` conversion — `if (priv != NO_ACL)` is the idiomatic test, **not** `if (priv)`).

A representative slice (full list at the top of `privilege.h`):

```cpp
enum privilege_t: unsigned long long {
  NO_ACL                = 0,
  SELECT_ACL            = 1UL << 0,
  INSERT_ACL            = 1UL << 1,
  UPDATE_ACL            = 1UL << 2,
  DELETE_ACL            = 1UL << 3,
  CREATE_ACL            = 1UL << 4,
  DROP_ACL              = 1UL << 5,
  RELOAD_ACL            = 1UL << 6,
  GRANT_ACL             = 1UL << 10,
  INDEX_ACL             = 1UL << 12,
  ALTER_ACL             = 1UL << 13,
  SUPER_ACL             = 1UL << 15,
  EXECUTE_ACL           = 1UL << 18,
  TRIGGER_ACL           = 1UL << 27,
  // Dynamic / fine-grained "split-from-SUPER" bits (10.5.2+):
  SET_USER_ACL          = 1UL << 30,
  FEDERATED_ADMIN_ACL   = 1UL << 31,
  CONNECTION_ADMIN_ACL  = 1ULL << 32,
  READ_ONLY_ADMIN_ACL   = 1ULL << 33,
  REPL_SLAVE_ADMIN_ACL  = 1ULL << 34,
  REPL_MASTER_ADMIN_ACL = 1ULL << 35,
  BINLOG_ADMIN_ACL      = 1ULL << 36,
  BINLOG_REPLAY_ACL     = 1ULL << 37,
  SLAVE_MONITOR_ACL     = 1ULL << 38,
  SHOW_CREATE_ROUTINE_ACL = 1ULL << 39,
};
```

Useful aggregates (in the same header) — combine bits at compile time:

- `COL_DML_ACLS` = `SELECT | INSERT | UPDATE | DELETE`.
- `STD_TABLE_DDL_ACLS` = `CREATE | DROP | ALTER`; `ALL_TABLE_DDL_ACLS` adds `INDEX`.
- `VIEW_ACLS` = `CREATE_VIEW | SHOW_VIEW`.
- `TABLE_ACLS` = `COL_DML_ACLS | ALL_TABLE_DDL_ACLS | VIEW_ACLS | GRANT_ACL | REFERENCES_ACL | TRIGGER_ACL | DELETE_HISTORY_ACL`.
- `DB_ACLS` = `TABLE_ACLS | PROC_DDL_ACLS | EXECUTE_ACL | CREATE_TMP_ACL | LOCK_TABLES_ACL | EVENT_ACL | SHOW_CREATE_ROUTINE_ACL`.
- `PROC_ACLS` = `ALTER_PROC_ACL | EXECUTE_ACL | GRANT_ACL | SHOW_CREATE_ROUTINE_ACL`.
- `GLOBAL_ACLS` = `DB_ACLS | SHOW_DB_ACL | CREATE_USER_ACL | CREATE_TABLESPACE_ACL | SUPER_ACL | RELOAD_ACL | SHUTDOWN_ACL | PROCESS_ACL | FILE_ACL | REPL_SLAVE_ACL | ALLOWED_BY_SUPER_BEFORE_*`.

The `ALLOWED_BY_SUPER_BEFORE_110000` aggregate is the set of bits that used to require `SUPER` and were split out as named bits — agents adding similar splits should follow that pattern.

**Idiomatic check shape:**

```cpp
if (!(thd->security_ctx->master_access & SOMETHING_ACL))
{
  my_error(ER_SPECIFIC_ACCESS_DENIED_ERROR, MYF(0), "SOMETHING");
  return TRUE;
}
```

For object-level access, use the helpers in §4 — **don't** test `master_access` directly for tables/columns/routines, because that misses db/table/column grants and role propagation.

## 4. The check flow

A statement arrives at [`dispatch_command`](../sql_parse.cc) → [`mysql_execute_command`](../sql_parse.cc) (the big `switch (lex->sql_command)`). Most `case SQLCOM_*` arms call **one or more** of these check helpers before doing work. All are declared in [`sql_acl.h`](../sql_acl.h).

| Helper | Granularity | Reads | Sets / Errors |
|---|---|---|---|
| [`Security_context::check_access(want, match_any)`](../sql_class.h) | Global only | `sctx->master_access` | Returns bool; **does not** emit `my_error`. |
| [`check_global_access(thd, want, no_errors)`](../sql_acl.cc) | Global only | `sctx->master_access` | Emits `ER_SPECIFIC_ACCESS_DENIED_ERROR` unless `no_errors`. |
| [`check_access(thd, want, db, save_priv, gii, dont_check_global, no_errors)`](../sql_acl.cc) | Global + db | `master_access`, `acl_dbs` (via `acl_get`) | Writes resolved set into `*save_priv`; `gii` is the internal-table fast path. |
| [`check_table_access(thd, want, tables, …)`](../sql_parse.cc) | Table list | walks `TABLE_LIST::grant`, calls `check_grant` | One emission per table on failure. |
| [`check_grant(thd, want, tables, any_combination_will_do, n, no_errors)`](../sql_acl.cc) | Table + columns (delayed) | `column_priv_hash` under `LOCK_grant` rd | Sets `grant->privilege` on each `TABLE_LIST`. |
| [`check_grant_column(thd, grant, db, table, column, sctx)`](../sql_acl.cc) | Single column | `column_priv_hash` | Per-column lookup; called from `Item_field::fix_fields`. |
| [`check_grant_all_columns(thd, want, fields_iter)`](../sql_acl.cc) | All columns of a TABLE_LIST | `column_priv_hash` | Used for `SELECT *` rewrites. |
| [`check_grant_routine(thd, want, procs, sph, no_error)`](../sql_acl.cc) | Stored routine | per-`Sp_handler` priv hash (`proc_priv_hash` / `func_priv_hash` / `package_*_priv_hash`) | Used during routine resolution + execution. |
| [`check_grant_db(thd, db)`](../sql_acl.cc) | Db-or-anything-in-it | `acl_dbs` + `column_priv_hash` + routine hashes | Used by `SHOW DATABASES` filtering. |

**The walk for a typical `SELECT a, b FROM t` is:**

1. `mysql_execute_command` arm for `SQLCOM_SELECT` calls `check_table_access(thd, SELECT_ACL, all_tables, …)`.
2. `check_table_access` iterates `TABLE_LIST *`; for each, it short-circuits if `master_access & want == want` (global covers everything), then if `db_access & want == want` (db grant covers it), and only then falls through to `check_grant`.
3. `check_grant` takes `LOCK_grant` read, looks up `column_priv_hash[(user,host,db,table)]`, ORs in any table-level bits, and stores the resolved set on `TABLE_LIST::grant`.
4. During `Item_field::fix_fields`, [`check_column_grant_in_table_ref`](../sql_acl.cc) consults `TABLE_LIST::grant` and, if column-level checking is required (any column-level grant exists for this user+table), calls `check_grant_column` per referenced column.
5. If a role is active (`sctx->priv_role` set), step 1's `master_access` already includes the role's union — the role merging happened at `SET ROLE` time, not now.

> **The check funnel is "widest first."** Global covers db covers table covers column. Each step short-circuits if the broader grant already suffices. The column-level path is only **reached** if `column_priv_hash` has an entry for this (user, host, db, table) — see the pitfall in §8.

**Internal-schema fast path.** Tables under reserved schemas (`information_schema`, `performance_schema`) get an `ACL_internal_schema_access` / `ACL_internal_table_access` decision *before* the grant tables (`grep -n 'ACL_INTERNAL_ACCESS_' sql/sql_acl.h`). The three results are `GRANTED`, `DENIED`, `CHECK_GRANT`.

## 5. Roles

Roles are stored as rows in `mysql.global_priv` with `is_role='Y'` (an account-options JSON flag) plus edges in `mysql.roles_mapping`. The in-memory model is:

- `ACL_USER_BASE` is the common base. It owns a `Dynamic_array<ACL_ROLE *> role_grants` — the roles directly granted to this principal.
- `ACL_USER` (a real account) inherits from `ACL_USER_BASE`. Holds password / auth-plugin / resource-limit state.
- `ACL_ROLE` also inherits from `ACL_USER_BASE`. Holds its **own** `access` (privileges granted directly to the role) **and** a `counter` used by the role traversal (`grep -n 'class ACL_ROLE' sql/sql_acl.cc`).
- The special role **`PUBLIC`** is implicit; `static ACL_ROLE *acl_public` is the cached pointer. Everyone is a member.

**The role graph.** `acl_roles_mappings` is a `HASH` whose entries are `ROLE_GRANT_PAIR` rows; `acl_roles` is the `HASH` of roles keyed by name. Traversal helpers:

- `traverse_role_graph_up(role, …)` — walk from a role upward to all principals who can use it.
- `traverse_role_graph_down(principal, …)` — walk from a principal downward through the roles they can activate (used to compute effective privileges).

When a connection issues `SET ROLE r`, [`acl_setrole`](../sql_acl.cc) sets `sctx->priv_role`, then walks the role graph down from `r` and `OR`s every reachable `ACL_ROLE::access` into `sctx->master_access`. From that point on, ordinary `master_access & FOO_ACL` checks see the activated role's privileges. **Without** an active role, the role-derived bits are absent.

**Default role.** Each `ACL_USER` may carry a default role (stored as an account-option in `mysql.global_priv`). It is auto-applied at connect time via [`acl_authenticate`](../sql_acl.cc) → setrole equivalent (`grep -n 'default_rolename\|default_role' sql/sql_acl.cc`).

**Cycle detection.** `add_role_user_mapping` and the graph walk use the `ROLE_CYCLE_FOUND` sentinel. Cycles in `mysql.roles_mapping` are detected on load and on `GRANT`.

## 6. `GRANT` / `REVOKE` execution

[`sql/grant.cc`](../grant.cc) is small (~100 lines) — it forwards to handlers in [`sql_acl.cc`](../sql_acl.cc). The real work lives in:

| Statement | Entry point | What it mutates |
|---|---|---|
| `GRANT … ON *.*` / `GRANT … ON db.*` | [`mysql_grant`](../sql_acl.cc) | `mysql.global_priv` and/or `mysql.db`; `acl_users` / `acl_dbs`. |
| `GRANT … ON db.tbl` (table or column) | [`mysql_table_grant`](../sql_acl.cc) | `mysql.tables_priv`, `mysql.columns_priv`; `column_priv_hash`. |
| `GRANT EXECUTE ON [PROCEDURE\|FUNCTION\|PACKAGE\|PACKAGE BODY] …` | [`mysql_routine_grant`](../sql_acl.cc) | `mysql.procs_priv`; the matching routine hash via `Sp_handler::get_priv_hash()`. |
| `GRANT … TO role` / `GRANT role TO grantee` | [`mysql_grant_role`](../sql_acl.cc) | `mysql.roles_mapping`; `acl_roles_mappings`; cycle check. |
| `GRANT PROXY ON …` | path inside `mysql_grant` via the proxy-priv branch | `mysql.proxies_priv`; `acl_proxy_users`. |
| `REVOKE …` | same entry points with a `revoke` flag | mirror of the GRANT path; final empty-state rows are deleted from the table and the cache slot. |
| `REVOKE ALL PRIVILEGES, GRANT OPTION FROM u` | [`mysql_revoke_all`](../sql_acl.cc) | clears every table; iterates all in-memory hashes. |
| `CREATE / DROP / RENAME / ALTER USER`, `CREATE ROLE`, `SET DEFAULT ROLE` | [`mysql_create_user`](../sql_acl.cc), `mysql_drop_user`, `mysql_rename_user`, `mysql_alter_user`, etc. | `mysql.global_priv`; `acl_users` / `acl_roles`; cascading row removal from db/tables/columns/procs/proxies/roles_mapping for `DROP USER`. |

Each handler:

1. Takes `LOCK_grant` write (for table/column/routine paths) and/or `acl_cache->lock`.
2. Opens the relevant grant tables via `Grant_tables::open_and_lock`.
3. Mutates the table rows.
4. Mutates the corresponding in-memory cache (single insert/update/delete — **not** a full rebuild).
5. Bumps `grant_version` (which invalidates `acl_cache` cache entries).
6. Writes the binlog event for replication.
7. Releases locks.

The incremental approach is why GRANT is cheap; full reload is only `FLUSH PRIVILEGES`.

## 7. Don't reuse existing privileges for new functionality

If you are adding a new server-side feature gated on permission (a new admin statement, a new sysvar, a new operation on system tables), **mint a new privilege bit**. Do not reuse `SUPER_ACL` or an existing `*_ADMIN_ACL` "because it's close enough."

> "It usually is not a good idea to reuse privileges. This turns them into roles. … I'd advocate adding a different privilege." — PR4743 (gkodinov), captured in [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"ACL / privileges".

The exception that proves the rule: the **`ALLOWED_BY_SUPER_BEFORE_*` aggregates** in [`privilege.h`](../privilege.h) — those exist because historic features *had* been collapsed onto `SUPER`, and the project has been carving them back out (`SET_USER_ACL` 10.5.2, `FEDERATED_ADMIN_ACL` 10.5.2, `CONNECTION_ADMIN_ACL` 10.5.2, `READ_ONLY_ADMIN_ACL` 10.5.2, `BINLOG_ADMIN_ACL`, `BINLOG_REPLAY_ACL`, `SLAVE_MONITOR_ACL` 10.5.8, `SHOW_CREATE_ROUTINE_ACL` 11.3.0). Adding to that pile is the right move; adding a *new* `SUPER`-gated feature is not.

**Checklist for a new privilege bit** (from the comment block at the top of [`privilege.h`](../privilege.h) lines 73–87 — `grep -n 'When adding new privilege bits' sql/privilege.h`):

1. Add the bit definition in `enum privilege_t` (next free shift).
2. Add a new `LAST_<version>_ACL` and `ALL_KNOWN_ACL_<version>` constant; change `ALL_KNOWN_ACL` to point at the new version.
3. Update `GLOBAL_ACLS`, `DB_ACLS`, `TABLE_ACLS`, `PROC_ACLS` if the bit applies at those levels.
4. Update `SUPER_ADDED_SINCE_USER_TABLE_ACL` if you intend `SUPER` to still imply it for upgrade compat.
5. Add the user-visible name to `static struct show_privileges_st sys_privileges[]` and `static const char *command_array[]` / `command_lengths[]` in [`sql_acl.cc`](../sql_acl.cc) (`grep -n 'show_privileges_st\|command_array\[\]' sql/sql_acl.cc`).
6. Widen the relevant `SET(…)` column in [`scripts/mariadb_system_tables.sql`](../../scripts/mariadb_system_tables.sql) and [`scripts/mariadb_system_tables_fix.sql`](../../scripts/mariadb_system_tables_fix.sql).
7. Teach `User_table_json::get_access()` to read the new bit.
8. Extend `sql_yacc.yy` so `GRANT new_priv ON …` parses (`grep -n 'CONNECTION_ADMIN\|FEDERATED_ADMIN' sql/sql_yacc.yy`).
9. Add MTR coverage under `mysql-test/suite/funcs_1/` and/or `mysql-test/main/grant*.test`; include a `mariadb-upgrade` round-trip if the schema changed.

## 8. Pitfalls

- **Gating a new feature on `SUPER`.** Don't. Mint a new `*_ADMIN_ACL` bit. PR4743; §7 above.
- **Forgetting to invalidate the cache after a DDL that touches a grant table.** Any path that writes `mysql.global_priv` / `mysql.db` / `mysql.tables_priv` / `mysql.columns_priv` / `mysql.procs_priv` / `mysql.roles_mapping` outside the canonical `mysql_*_grant` entry points must take `LOCK_grant` + `acl_cache->lock`, update the in-memory cache, and bump `grant_version`. Stale caches show up as "GRANT worked but next statement still says access denied" — and pass tests that re-`FLUSH PRIVILEGES` between steps.
- **Column-level overrides table-level when any column grant exists.** `check_grant` records the table-level `privilege` on `TABLE_LIST::grant`; if the user has *any* column grant on that table, `check_column_grant_in_table_ref` falls through to per-column checks for **every** referenced column, even those covered by a broader table grant. A test that only references columns the user has column-level grants for can hide a column you forgot to grant on.
- **`FLUSH PRIVILEGES` is rebuild-from-tables, not just clear-and-reload.** `acl_reload` re-opens the seven grant tables under `TL_READ`, allocates a fresh `acl_memroot`, parses every row into `ACL_USER` / `ACL_DB` / `ACL_ROLE` again, re-sorts the arrays, and re-walks the role graph. It is **O(rows)** in every grant table, holds `acl_cache->lock` write the whole time, and serialises against all authentication and all privilege checks. Cheap on a fresh install; expensive on a multi-tenant box with 10⁵ users.
- **Privilege checked at parse vs execute.** A check evaluated only in `mysql_execute_command`'s `SQLCOM_*` arm is **not** re-evaluated when the same prepared statement is re-executed (`mysql_stmt_execute_common`) and the user has lost the privilege in the meantime, **unless** the check helper is called from `Prepared_statement::execute` too. Worse: stored-program bodies are checked at definition time (and against the **definer's** rights for `SQL SECURITY DEFINER`). Tests must cover prepared-statement (`PREPARE … EXECUTE …`) and stored-procedure variants for **every** new privilege check — see [`.claude/review/testing.md`](../../.claude/review/testing.md).
- **Role privileges are a snapshot at `SET ROLE` time.** `SET ROLE r` walks the graph and ORs role bits into `sctx->master_access`. A subsequent `GRANT new_priv TO r` does not update existing sessions until they re-issue `SET ROLE`. Test for this if your feature requires "rolling" grants.
- **`SQL SECURITY DEFINER` routines run with the *definer's* `master_access`, not the invoker's.** [`sp_change_security_context`](../sp_head.cc) swaps `THD::security_ctx`. A new privilege your routine relies on must be granted to the *definer*, not to the caller; CI tests that grant only the caller silently pass under `SQL SECURITY INVOKER` and fail in real deployments.
- **`mysql.user` vs `mysql.global_priv`.** Since 10.4, `mysql.user` is a view over `mysql.global_priv`. New SQL must read/write `mysql.global_priv` (or the canonical [`Grant_tables`](../sql_acl.cc) wrapper). Tests that hand-craft `INSERT INTO mysql.user` to set up state are likely wrong on 10.4+.
- **`acl_cache` (the `Hash_filo`) is not the same as the in-memory caches.** It is a small per-decision cache keyed on `(user, host, db)` holding the resolved `db_access`. Invalidated by bumping `grant_version`. Mutations to `acl_users` / `acl_dbs` / `column_priv_hash` must bump `grant_version` or stale entries leak.
- **The legacy `mysql.host` table is still read** if present. Custom installs / upgrades may still have it; don't assume only the modern five tables. `grep -n 'Table_host\|HOST_TABLE\b' sql/sql_acl.cc`.
- **Internal-schema access is decided before the grant tables.** A new privilege you add cannot grant access to `performance_schema.*` or `information_schema.*` rows unless you also extend the matching `ACL_internal_schema_access` subclass.

## 9. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) §"ACL & privileges" — the parent map; do not paraphrase.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Auth / ACL" — review rules with PR citations.
- [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"ACL / privileges" — the don't-reuse-`SUPER` rule (PR4743).
- [`.claude/review/testing.md`](../../.claude/review/testing.md) — prepared-statement and stored-procedure variant requirement.
- [`sql/privilege.h`](../privilege.h) — the privilege bit registry. The "when adding new privilege bits" comment block is the canonical checklist; §7 above is a paraphrase.
- [`sql/sql_acl.h`](../sql_acl.h) — public API: `check_access`, `check_grant`, `check_table_access`, `check_grant_routine`, `mysql_grant`, `mysql_table_grant`, `mysql_routine_grant`, `mysql_grant_role`.
- Forward references:
  - `sql/docs/stored-programs.md` (Phase 5) — `Sp_handler::get_priv_hash`, the four routine hashes, `SQL SECURITY DEFINER` semantics.

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `23097b2d8258de2a99b8ec1088be01a59174c01e` (branch `main`).
- **Files surveyed:**
  - [`sql/sql_acl.cc`](../sql_acl.cc) — 15663 lines. Spot-read the file-scope statics cluster (~700–760), `enum_acl_tables` and `MYSQL_TABLE_NAME[]` (~784–820), `acl_load` / `acl_init` / `acl_reload` (~2566–3110), `acl_setrole` and role traversal (`grep -n 'traverse_role_graph_\|acl_setrole' sql/sql_acl.cc`), `check_grant` family (~8506–9100), `mysql_table_grant` / `mysql_routine_grant` / `mysql_grant_role` (~7430–8460, ~8095–8165, ~7800–7900), `grant_load` / `grant_reload` (~8195–8460), `sp_grant_privileges` / `sp_revoke_privileges` (~12090–12200), `fill_effective_table_privileges` (~13449). Recipe: `grep -n 'acl_load\|acl_init\|acl_reload\|grant_init\|grant_load\|grant_reload' sql/sql_acl.cc`.
  - [`sql/sql_acl.h`](../sql_acl.h) — 388 lines, full read; confirmed the public-API surface and `ACL_internal_*` enums.
  - [`sql/grant.cc`](../grant.cc), [`sql/grant.h`](../grant.h) — 108 + 99 lines, full read; confirmed these are thin shims into `sql_acl.cc`.
  - [`sql/privilege.h`](../privilege.h) — full read of the `enum privilege_t`, the aggregate constexprs (`COL_DML_ACLS`, `TABLE_ACLS`, `DB_ACLS`, `PROC_ACLS`, `GLOBAL_ACLS`, `ALLOWED_BY_SUPER_BEFORE_*`), and the "when adding new privilege bits" header comment.
  - [`sql/sql_priv.h`](../sql_priv.h) — 390 lines; confirmed it no longer holds the privilege bits (those moved to `privilege.h`) and now mostly holds `OPTION_*` thread/option flags. The task brief named `sql_priv.h`; the canonical home is `privilege.h`.
  - [`sql/sql_class.h`](../sql_class.h) — `Security_context` definition (~1907–1975) for `master_access` / `db_access` / `priv_user` / `priv_host` / `priv_role` and `check_access`.
  - [`sql/sql_parse.cc`](../sql_parse.cc) — `mysql_execute_command` (~3491) and a sampling of `check_access` / `check_table_access` call sites to confirm the funnel.
  - [`sql/mysqld.cc`](../mysqld.cc) — `mysql_rwlock_t LOCK_grant` definition (~781).
  - [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Auth / ACL"; [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) §"ACL / privileges" (PR4743).
- **Deliberately excluded:**
  - Authentication plugin protocol details (`auth_pam`, `auth_gssapi`, `auth_ed25519`, native scramble) — covered by plugin docs and the auth-plugin API; this doc is about authorisation.
  - Password hashing internals from [`password.c`](../password.c) — covered by the plugin API.
  - The full row layout of every grant table — read [`scripts/mariadb_system_tables.sql`](../../scripts/mariadb_system_tables.sql) for that.
  - Wire-protocol-level access-denied error formatting — handled by `ER_ACCESS_DENIED_ERROR` and friends in `share/errmsg-utf8.txt`.
  - SSL / X.509 requirements (`REQUIRE SUBJECT / ISSUER / CIPHER`) — stored in `mysql.global_priv` account-options JSON; not on this doc's critical path.
  - Resource limits (`MAX_QUERIES_PER_HOUR` etc.) — stored beside privileges but enforced in `sql_connect.cc`, not in the check funnel.
- **Refresh procedure:**
  - Re-run `wc -l sql/sql_acl.cc sql/sql_acl.h sql/grant.cc sql/grant.h sql/privilege.h` and bump line-count anchors if they have drifted.
  - Re-walk the `grep -n 'acl_load\|acl_init\|acl_reload\|grant_init\|grant_load\|grant_reload' sql/sql_acl.cc` set; the symbols themselves are stable.
  - If a new `*_ADMIN_ACL` bit lands, add it to the §3 representative-slice listing and the §7 checklist example.
  - If the role graph traversal API changes (new `traverse_role_graph_*` variants), update §5.
  - Bump `last-verified`.
