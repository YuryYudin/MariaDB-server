---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/sys_vars.cc, sql/sys_vars.inl, sql/set_var.{cc,h}, storage/innobase/handler/ha_innodb.cc
---

# Playbook: Add a new system variable

**Use when:** you need to expose new tunable configuration to the user via `SET`, `SHOW VARIABLES`, `mariadbd --opt`, or `my.cnf`.
**Skip if:** (a) the flag is session-only and visible only to internal code — add a member to `THD` or `LEX` instead; (b) it's a build-time toggle — add a CMake option under [`cmake/`](../../cmake/) and a `#define`, not a sysvar; (c) the addition is a runtime *status* counter — that lives in `SHOW STATUS` / `s_status_vars[]`, not `sys_vars.cc` (replication status vars go under [`mysql-test/suite/rpl/`](../../mysql-test/suite/rpl/), **not** `sys_vars` — PR4904).
**Typical effort:** 1-2 hours including the two tests (visibility/range + functional).

## Overview

A sysvar is one of two distinct constructs depending on where it lives:

- **Server-core sysvar** (the common case): `static Sys_var_<type> Sys_<name>(...)` in [`sql/sys_vars.cc`](../../sql/sys_vars.cc). The class constructor registers it into `sys_var_hash` at startup; no extra wiring needed.
- **Plugin / storage-engine sysvar**: `static MYSQL_SYSVAR_<TYPE>(name, var, flags, ...)` in the plugin's own `.cc`, **appended to the plugin's `<plugin>_system_variables[]` array**. Comes and goes with `INSTALL PLUGIN` / `UNINSTALL PLUGIN`. InnoDB's flavour is at [`storage/innobase/handler/ha_innodb.cc`](../../storage/innobase/handler/ha_innodb.cc).

The two paths are **not interchangeable** — pick the one that matches where your code lives.

Cross-loads: [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"System variables" + §"Where to start"; [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Where to start" + §"Pitfalls" (the "three places must agree" wiring rule); [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Plugin / sysvar API" and [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Plugins and sysvars" — every `check`-vs-`update` rule below is cited from there.

## Files you'll touch — server-core flavour

| File | Role |
|---|---|
| [`sql/sys_vars.cc`](../../sql/sys_vars.cc) | The `Sys_var_<type>` definition. Find a similar existing variable and copy its shape. |
| [`sql/sql_class.h`](../../sql/sql_class.h) (if `SESSION_VAR`) | New field in `struct system_variables` (line ~737). For `GLOBAL_VAR`, a free global goes wherever the related globals live. |
| `sql/<feature>.cc` | The read sites: `thd->variables.<name>` (session) or the bare global (global). Add the variable to actually have an effect. |
| `mysql-test/suite/sys_vars/t/<name>_basic.test` + `.result` | Visibility + range + scope test. |
| `mysql-test/<suite>/t/<test>.test` + `.result` | Functional test exercising the gated behaviour. See [`add-mtr-test.md`](add-mtr-test.md). |

## Files you'll touch — plugin / InnoDB flavour

| File | Role |
|---|---|
| `<plugin>/<file>.cc` (e.g. [`storage/innobase/handler/ha_innodb.cc`](../../storage/innobase/handler/ha_innodb.cc)) | `MYSQL_SYSVAR_*` macro **and** append to `<plugin>_system_variables[]` in the same file. |
| Plugin's backing storage (e.g. [`storage/innobase/srv/srv0srv.cc`](../../storage/innobase/srv/srv0srv.cc) + [`include/srv0srv.h`](../../storage/innobase/include/srv0srv.h)) | The actual variable the macro points at. |
| `mysql-test/suite/sys_vars/t/<plugin>_<name>_basic.test` + `.result` | Visibility test (e.g. `innodb_<name>_basic.test` — 90+ templates already in tree). |
| Functional test under the plugin's bundled suite | E.g. `storage/innobase/mysql-test/innodb/<name>.test`. |

The "three places must agree" rule for plugin sysvars: the `MYSQL_SYSVAR_*` macro, the append to `<plugin>_system_variables[]`, and the backing variable declaration. Missing any one means the variable is either invisible, unsettable, or settable but inert. [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Pitfalls".

## Steps — server-core flavour

1. **Confirm the variable is needed.** Reviewers reject "a knob for the sake of a knob". Cite a real user need (a Jira issue, a configuration scenario, a measured workload). [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Plugin / sysvar API".

2. **Pick the right `Sys_var_*` type.** Decision table — open [`sql/sys_vars.inl`](../../sql/sys_vars.inl) to confirm:

   | Sys_var class | Use for |
   |---|---|
   | `Sys_var_mybool` | On/off bool. |
   | `Sys_var_uint` / `Sys_var_int` / `Sys_var_ulong` / `Sys_var_long` / `Sys_var_ulonglong` | Numeric thresholds, sizes, counters. Prefer the smallest type that fits. New code: `uint`/`int`/`ulonglong` (root [`CLAUDE.md`](../../CLAUDE.md) §"Coding style" — `long`/`ulong` differ Linux vs Windows). |
   | `Sys_var_double` | Float thresholds. Rare. |
   | `Sys_var_enum` | Small fixed-set string options; backed by `TYPELIB`. |
   | `Sys_var_set` | Bit-set of multiple flags; backed by `TYPELIB`. |
   | `Sys_var_charptr` / `Sys_var_charptr_fscs` / `Sys_var_lexstring` | Free-form string (paths, lists). Locking discipline applies — see below. |
   | `Sys_var_session_special` | Session-only with custom storage (e.g. `last_insert_id`). |
   | `Sys_var_plugin` / `Sys_var_pluginlist` | Names of installed plugins. |

   **Don't add new `Sys_var_*` classes** — [`sql/sys_vars.cc:26`](../../sql/sys_vars.cc) header: *"Don't add new Sys_var classes or uncle Occam will come with his razor."*

3. **Pick the scope.** Use one of:

   - `SESSION_VAR(name)` — per-connection. Different connections see different values. The backing variable is a field in `struct system_variables` at [`sql/sql_class.h:737`](../../sql/sql_class.h).
   - `GLOBAL_VAR(name)` — server-wide. The backing variable is a free global.
   - `SESSION_VAR(name)` combined with `IN_BINLOG` if the session value must replicate to slaves (e.g. `auto_increment_increment`).
   - `READONLY` — settable only at startup (`--opt=value` or `my.cnf`). Combine with `GLOBAL_VAR` or `SESSION_VAR` as needed.

4. **Declare the backing variable.** For `SESSION_VAR` → add a field to `struct system_variables` in [`sql/sql_class.h`](../../sql/sql_class.h) (line ~737, alphabetical within its type cluster). For `GLOBAL_VAR` → a free global next to the existing similar globals.

5. **Define the sysvar in [`sql/sys_vars.cc`](../../sql/sys_vars.cc).** Find a similar existing variable and copy its shape. Three templates verified at HEAD:

   ```cpp
   // Bool, global (sys_vars.cc:521):
   static Sys_var_mybool Sys_automatic_sp_privileges(
          "automatic_sp_privileges",
          "Creating and dropping stored procedures alters ACLs",
          GLOBAL_VAR(sp_automatic_privileges),
          CMD_LINE(OPT_ARG), DEFAULT(TRUE));

   // Unsigned int, session, range + block + default (sys_vars.cc:467):
   static Sys_var_uint Sys_analyze_max_length(
          "analyze_max_length", "...",
          SESSION_VAR(analyze_max_length),
          CMD_LINE(REQUIRED_ARG), VALID_RANGE(32, UINT_MAX32),
          DEFAULT(UINT_MAX32), BLOCK_SIZE(1));

   // Enum, session, check + update callbacks (sys_vars.cc:708):
   static Sys_var_enum Sys_binlog_format(
          "binlog_format", "...",
          SESSION_VAR(binlog_format), CMD_LINE(REQUIRED_ARG, OPT_BINLOG_FORMAT),
          binlog_format_names, DEFAULT(BINLOG_FORMAT_MIXED),
          NO_MUTEX_GUARD, NOT_IN_BINLOG,
          ON_CHECK(binlog_format_check),
          ON_UPDATE(fix_binlog_format_after_update));
   ```

   The user-visible name is lower-`snake_case`. The description appears in `SHOW VARIABLES` and `mariadbd --help --verbose`.

6. **Validation: `check` callback.** If the new value must satisfy constraints **beyond** type bounds (e.g. must be a power of two, must be a subset of another sysvar, must not be set inside a transaction), pass `ON_CHECK(check_fn)`. The check fires **before** the new value is stored.

   **Validity checks belong in `check`, never in `update`** — PR4633 (vuvova): *"validity checks must be done in the `check` callback, not in the `update` callback"*. [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Plugins and sysvars".

   Signature: `static bool check_fn(sys_var *self, THD *thd, set_var *var)` — return `true` to reject the assignment (the prospective value is in `var->save_result`).

7. **Side effects: `update` callback.** If changing the value requires action (flush a cache, restart a worker, reconfigure I/O), pass `ON_UPDATE(update_fn)`. The server has **already written the new value into its backing storage** by the time `update` runs — **do not re-validate or re-write the sysvar's own storage in `update`** (PR4633 — vuvova on `server_audit.cc:2372`). [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Plugin / sysvar API".

   Signature: `static bool update_fn(sys_var *self, THD *thd, enum_var_type type)`. Return `false` on success.

8. **Wire the variable into the code that uses it.** Read it via:

   - **Session sysvar:** `thd->variables.<name>` — no lock required (only the owning `THD` reads its own session variables).
   - **Global sysvar:** the bare global. **For pointer-to-string sysvars (`Sys_var_charptr`), hold the relevant lock when dereferencing** — the pointer can be swapped from under you between read and dereference. [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency" (PR — "Don't read a pointer-to-string sysvar without a lock").

9. **Add the visibility / range test.** Path: `mysql-test/suite/sys_vars/t/<name>_basic.test` + `<name>_basic.result`. Templates: [`init_rpl_role_variable_basic.test`](../../mysql-test/suite/sys_vars/t/init_rpl_role_variable_basic.test), [`innodb_buffer_pool_in_core_dump_basic.test`](../../mysql-test/suite/sys_vars/t/innodb_buffer_pool_in_core_dump_basic.test). The standard shape: save old value → `SELECT @@GLOBAL/@@SESSION` to confirm scope → `SHOW VARIABLES LIKE` to confirm visibility → query `INFORMATION_SCHEMA.{GLOBAL,SESSION}_VARIABLES` → `SET` each valid value (and `--error ER_*` each invalid) → restore. Use `--source include/not_embedded.inc` when separate connections are needed (PR4904). Footer `--echo # End of 13.0 tests` (matches [`VERSION`](../../VERSION) — see [`add-mtr-test.md`](add-mtr-test.md)).

10. **Add the functional test.** Wherever the gated behaviour fits. Usually `mysql-test/main/<feature>.test` (extend an existing file — PR4706, PR4789) or the relevant suite. The functional test exercises the actual behavior the sysvar gates, not the `SET`/`SHOW` machinery. See [`add-mtr-test.md`](add-mtr-test.md) for the full test-writing playbook.

11. **Commit.** The sysvar definition, the backing variable, all call sites, the visibility test, and the functional test go in **one commit** — `git bisect` correctness ([`add-mtr-test.md`](add-mtr-test.md) §"Steps" step 10). Subject: `MDEV-NNNNN <short description>`.

## Steps — plugin / InnoDB flavour

Cross-load [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Where to start" — it has the canonical "three places must agree" walk-through.

1. **Define the macro** (real template from [`ha_innodb.cc:19234`](../../storage/innobase/handler/ha_innodb.cc)):

   ```cpp
   static MYSQL_SYSVAR_BOOL(stats_include_delete_marked,
     srv_stats_include_delete_marked,
     PLUGIN_VAR_OPCMDARG,
     "Include delete marked records when calculating persistent statistics",
     NULL, NULL, FALSE);
   ```

   Backing variable (`srv_stats_include_delete_marked`) is declared in [`srv/srv0srv.cc`](../../storage/innobase/srv/srv0srv.cc) + [`include/srv0srv.h`](../../storage/innobase/include/srv0srv.h).

2. **Append to `<plugin>_system_variables[]`** in the same `.cc` (InnoDB's array starts at [`ha_innodb.cc:20165`](../../storage/innobase/handler/ha_innodb.cc), terminator `NULL`). Forgetting this is the #1 silent failure — the variable is simply invisible.

3. **Pick the right `PLUGIN_VAR_*` flag:**

   | Flag | Meaning |
   |---|---|
   | `PLUGIN_VAR_READONLY` | Settable only at startup (`--opt=value` / `my.cnf`). |
   | `PLUGIN_VAR_OPCMDARG` | Argument **optional** (typical bool — `--opt` toggles, `--opt=1` sets). |
   | `PLUGIN_VAR_RQCMDARG` | Argument **required** (numbers, strings, enums). |
   | `PLUGIN_VAR_NOCMDARG` | No command-line argument at all (rare). |
   | `PLUGIN_VAR_NOSYSVAR` | Command-line only, hidden from `SHOW VARIABLES`. |
   | `PLUGIN_VAR_NOCMDOPT` | `SHOW`-only, no command-line form. |
   | `PLUGIN_VAR_MEMALLOC` | For dynamically-allocated string values (plugin frees the previous value on update). |

   Combine with `|` — e.g. `PLUGIN_VAR_NOCMDARG | PLUGIN_VAR_READONLY` ([`ha_innodb.cc:19228`](../../storage/innobase/handler/ha_innodb.cc)).

4. **Tests:** visibility test at `mysql-test/suite/sys_vars/t/innodb_<name>_basic.test` (90+ templates exist); functional test under `storage/innobase/mysql-test/innodb/<name>.test` (auto-discovered).

## Examples from past PRs

| MDEV | Variable | Flavour | Notable |
|---|---|---|---|
| MDEV-38202 (`1ca0cfacf5a`) | `init_rpl_role` | Server-core enum, `GLOBAL_VAR` + `READONLY` | Test: [`init_rpl_role_variable_basic.test`](../../mysql-test/suite/sys_vars/t/init_rpl_role_variable_basic.test) — canonical minimal visibility-test shape. |
| MDEV-9247 (`bdbd63eeb85`) | `default_master_connection` | Server-core string, `SESSION_GLOBAL_VAR` | Promoted a previously session-only sysvar to globally settable. |
| MDEV-22186 (`b4bc43e5c19`) | `innodb_buffer_pool_in_core_dump` | InnoDB `MYSQL_SYSVAR_BOOL` + `update` callback | Canonical InnoDB sysvar with side-effect update; test pair under `sys_vars/` + `storage/innobase/mysql-test/innodb/`. |
| MDEV-37949 (`3394a9d1148`) | `innodb_log_archive` cluster | Multiple InnoDB sysvars + on-disk format change | Multi-sysvar feature with cross-validation in `check` callbacks. |
| MDEV-36290 (`6ef289416e2`) | `binlog_row_event_fragment_threshold` | Server-core `Sys_var_uint` retyped from `ulong` | Type-narrowing migration — why picking the smallest fitting type matters. |
| MDEV-38787 (`f87f803df11`) | `wsrep_slave_fk_checks` | Marked **DEPRECATED** | Uses the `DEPRECATED(<version>, "")` macro at [`sys_vars.cc:75`](../../sql/sys_vars.cc). |

Browse more: `git log --oneline -- sql/sys_vars.cc | head -30` (server-core); `git log --oneline -- storage/innobase/handler/ha_innodb.cc | head -30` (InnoDB).

## Pitfalls and rejection patterns

- **Validity check in `update` instead of `check`.** PR4633 (vuvova): *"validity checks must be done in the `check` callback, not in the `update` callback"*. By the time `update` fires, the server has already stored the value. [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Plugins and sysvars".
- **`update` re-writes the sysvar's own storage.** PR4633 (vuvova on `server_audit.cc:2372`): the server has already assigned the new value before calling `update`. Use `update` for side effects only.
- **Missing visibility test in `sys_vars/`.** PR4711 — every sysvar gets a `<name>_basic.test`; without it `SHOW VARIABLES` behaviour can regress silently.
- **Wrong scope.** `SESSION_VAR` for what should be server-wide (or vice versa) is an ABI-ish mistake — hard to fix once shipped.
- **Plugin sysvar missing the append to `<plugin>_system_variables[]`.** The `MYSQL_SYSVAR_*` macro alone does **nothing**. The variable must be in the registration array. Silent failure: `SHOW VARIABLES` doesn't show it; the plugin reads the C++ default forever.
- **Wrong `PLUGIN_VAR_*` flag.** `PLUGIN_VAR_READONLY` on a variable the user expects to `SET` at runtime is a UX bug; `PLUGIN_VAR_RQCMDARG` on a bool means `--opt` (without `=1`) is a parse error.
- **Pointer-to-string sysvar dereferenced without locking.** [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency": the pointer can be swapped between read and dereference.
- **Deprecated sysvar not marked `DEPRECATED`.** Use the `DEPRECATED(<version-int>, "<replacement-or-empty>")` macro at [`sys_vars.cc:75`](../../sql/sys_vars.cc). Real example: MDEV-38787 (`f87f803df11`).
- **Hyper-specific knob with no real user.** Every sysvar is forever in the ABI; cite a real Jira/workload need. [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Plugin / sysvar API".
- **Sysvar declared but never read.** `grep -r '<name>\b' sql/ storage/ plugin/` — orphan = dead code.
- **Name not lower `snake_case`.** Underscores, not hyphens; no CamelCase. The display name and CLI form must match.
- **Hard-coding the value in tests instead of save-and-restore.** Causes side-effects between tests; pattern: `SET @old_<name> = @@<name>;` at the top, restore at the bottom (see [`innodb_buffer_pool_in_core_dump_basic.test`](../../mysql-test/suite/sys_vars/t/innodb_buffer_pool_in_core_dump_basic.test) lines 11/31).

## Validation

Same shape as [`add-mtr-test.md`](add-mtr-test.md) §"Validation":

```sh
cd <build>
cmake --build . -j$(nproc)            # sys_vars.cc compiles, plugin compiles
cd mysql-test
./mtr sys_vars.<name>_basic            # visibility/range — must pass
./mtr <suite>.<functional-test>        # functional behaviour — must pass
./mtr --suite=sys_vars                 # surrounding suite — catches collisions
```

Sanity-check on the running server: `SHOW [GLOBAL|SESSION] VARIABLES LIKE '<name>'` lists it; `SELECT @@GLOBAL.<name>` returns the default; `SET GLOBAL <name> = <value>` succeeds (or fails predictably). Before submitting, **buildbot must be clean** across all platforms (PR4811, PR4869, PR4918).

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `f03e562b97c` (branch `main`).
- **Files surveyed:**
  - [`sql/sys_vars.cc`](../../sql/sys_vars.cc) — header comment (line 24-31, "use ON_CHECK/ON_UPDATE; don't add new Sys_var classes"); `DEPRECATED` macro at line 75; sampled real entries `Sys_automatic_sp_privileges` (521), `Sys_analyze_max_length` (467), `Sys_binlog_format` (708) with its check/update pair.
  - [`sql/sys_vars.inl`](../../sql/sys_vars.inl) — class template inventory (`Sys_var_integer` (175), `Sys_var_mybool` (452), `Sys_var_enum` (381), `Sys_var_set` (1515), `Sys_var_charptr` (512), `Sys_var_session_special` (2046), `Sys_var_plugin` (1648), etc.).
  - [`sql/set_var.{cc,h}`](../../sql/set_var.cc), [`sql/sql_class.h`](../../sql/sql_class.h) (`struct system_variables` at line 737).
  - [`storage/innobase/handler/ha_innodb.cc`](../../storage/innobase/handler/ha_innodb.cc) — `MYSQL_SYSVAR_*` examples (lines 19199-19256, 19514-19518); `innobase_system_variables[]` at line 20165; `innodb_buffer_pool_in_core_dump` update callback.
  - [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"Plugin / sysvar API"; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Plugins and sysvars" — every `check`/`update` citation.
  - [`sql/CLAUDE.md`](../../sql/CLAUDE.md), [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md), [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md), [`.claude/playbooks/add-mtr-test.md`](add-mtr-test.md) — cross-link targets, not duplicated.
  - [`init_rpl_role_variable_basic.test`](../../mysql-test/suite/sys_vars/t/init_rpl_role_variable_basic.test) (19 lines) and [`innodb_buffer_pool_in_core_dump_basic.test`](../../mysql-test/suite/sys_vars/t/innodb_buffer_pool_in_core_dump_basic.test) (32 lines) — `<name>_basic.test` templates.
  - Real commits: `1ca0cfacf5a` (MDEV-38202), `bdbd63eeb85` (MDEV-9247), `b4bc43e5c19` (MDEV-22186), `3394a9d1148` (MDEV-37949), `6ef289416e2` (MDEV-36290), `f87f803df11` (MDEV-38787 deprecation).
  - [`.claude/docs-plan/PLAN.md`](../docs-plan/PLAN.md) §"Phase 3 — Task 6 / Task 9" — the brief.
- **Deliberately excluded:** the full `Sys_var_*` constructor argument reference (read [`sql/sys_vars.inl`](../../sql/sys_vars.inl) directly for the exact signature); per-plugin sysvar idioms beyond InnoDB (Phase 7, plugin-specific CLAUDE.md); the deeper `set_var.cc` `SET` execution path; status-variable mechanics (different system — `mysqld.cc::s_status_vars[]`).
- **Refresh procedure:** when a new `Sys_var_*` class is added to [`sql/sys_vars.inl`](../../sql/sys_vars.inl) add a row to §"Steps" step 2; when a new `PLUGIN_VAR_*` flag is added add a row to §"Steps — plugin"; when the review rulebooks gain a sysvar rule fold into §"Pitfalls"; bump `last-verified`.
