---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/
---

# `sql/` — Claude agent overview

The MariaDB server core: parser, optimizer, executor, items (expressions), types and fields, the handler API that every storage engine plugs into, replication (binlog/relay log/parallel applier/WSREP), stored programs, ACL, plugin host, and the wire protocol. Statements enter via `dispatch_command()` → `mysql_execute_command()` in [`sql_parse.cc`](sql_parse.cc) and leave through the `handler` / `handlerton` interface in [`handler.cc`](handler.cc) / [`handler.h`](handler.h) to a storage engine under `storage/`.

The directory is large (~550 files: 249 `.cc`, 296 `.h`, plus one `.yy`, one `.c`, generated artefacts and CMake glue). This file is the **map**: it points you at the cluster you need, names the canonical files in it, and forwards to deeper docs (some still to be written — flagged with `(Phase N)`).

> **Code-review entry point:** [`.claude/skills/mreview/SKILL.md`](../.claude/skills/mreview/SKILL.md)
> **MDEV bug-fix entry point:** [`.claude/skills/mfix/SKILL.md`](../.claude/skills/mfix/SKILL.md)
> **Project-wide style and review rules:** [`.claude/review/README.md`](../.claude/review/README.md)

---

## Map of file clusters

Canonical files only — read the file, don't read a paraphrase of it.

### Parser & lexer

| File | Purpose |
|---|---|
| [`sql_yacc.yy`](sql_yacc.yy) | Bison grammar (the only `.yy` file). `gen_yy_files.cmake` splits it via `%ifdef MARIADB / %ifdef ORACLE` into `yy_mariadb.yy` and `yy_oracle.yy` at build time — there is no separate `sql_yacc_ora.yy` checked in. |
| [`lex.h`](lex.h) | Keyword tables consumed by `gen_lex_hash.cc` / `gen_lex_token.cc` to build the perfect hash and token id table. |
| [`sql_lex.{cc,h}`](sql_lex.cc) | The `LEX` struct: per-statement parser state, query block lists, parsed object refs. |
| [`gen_lex_hash.cc`](gen_lex_hash.cc) | Build-time generator: emits `lex_hash.h`. |
| [`gen_lex_token.cc`](gen_lex_token.cc) | Build-time generator: emits `lex_token.h`. |
| [`lex_ident.h`](lex_ident.h), [`lex_ident_sys.h`](lex_ident_sys.h), [`lex_ident_cli.h`](lex_ident_cli.h), [`lex_string.h`](lex_string.h) | Identifier / `LEX_CSTRING` wrappers and charset-aware comparators. |
| [`opt_hints_parser.{cc,h}`](opt_hints_parser.cc) | Sub-parser for optimizer hints (e.g. `/*+ NO_RANGE_OPTIMIZATION(...) */`). |

### Command dispatch & THD

| File | Purpose |
|---|---|
| [`sql_parse.cc`](sql_parse.cc) | `dispatch_command()` (per-packet dispatch from `do_command`), `mysql_execute_command()` (big switch over `enum_sql_command`). The funnel every statement passes through. |
| [`sql_class.{cc,h}`](sql_class.cc) | `THD` (the per-connection thread state), `Statement`, `Query_arena`, `Sub_statement_state`. Read [`sql_class.h`](sql_class.h) before touching anything connection-scoped. |
| [`sql_priv.h`](sql_priv.h) | `ACL_*` privilege bitmasks. |
| [`sql_const.h`](sql_const.h) | Tunables and architectural limits (`MAX_FIELDS`, `MAX_KEY`, …). |
| [`sql_command.h`](sql_command.h) | The `enum_sql_command` enum that drives the dispatch switch. |
| [`mysqld.{cc,h}`](mysqld.cc) | `mysqld_main()`, startup/shutdown, signal handling, `sql_print_*` log functions. |

### Optimizer & executor

| File | Purpose |
|---|---|
| [`sql_select.{cc,h}`](sql_select.cc) | The main optimizer/executor: `JOIN::prepare`, `JOIN::optimize`, `JOIN::exec`, `mysql_select`. |
| [`opt_range.{cc,h}`](opt_range.cc) | Range / index-merge optimizer (`SEL_TREE`, `QUICK_*`). |
| [`opt_subselect.{cc,h}`](opt_subselect.cc) | Subquery flattening: semi-join, materialization, IN-to-EXISTS. |
| [`opt_table_elimination.cc`](opt_table_elimination.cc) | Drop outer-joined tables not referenced by the query. |
| [`opt_histogram_json.{cc,h}`](opt_histogram_json.cc) | JSON-format histogram statistics. |
| [`opt_hints.{cc,h}`](opt_hints.cc) | Statement-level optimizer hint application (parsed by `opt_hints_parser.cc`). |
| [`opt_split.cc`](opt_split.cc) | Split materialization (semi-join unique). |
| [`opt_group_by_cardinality.{cc,h}`](opt_group_by_cardinality.cc) | GROUP BY cost / cardinality estimation. |
| [`sql_explain.{cc,h}`](sql_explain.cc) | `EXPLAIN` / `EXPLAIN FORMAT=JSON` / `ANALYZE` output. |
| [`filesort.cc`](filesort.cc), [`uniques.cc`](uniques.cc) | Sort and dedupe implementation. |

### Items (expressions)

Every SQL expression is an `Item` subtree.

| File | Purpose |
|---|---|
| [`item.{cc,h}`](item.cc) | `Item` base class, `Item_field`, `Item_ref`, `Item_cache`, `fix_fields` plumbing, value coercion. |
| [`item_func.{cc,h}`](item_func.cc) | `Item_func` and arithmetic/numeric scalar functions. |
| [`item_strfunc.{cc,h}`](item_strfunc.cc) | String functions (`CONCAT`, `SUBSTRING`, `TRIM`, …). |
| [`item_sum.{cc,h}`](item_sum.cc) | Aggregates (`SUM`, `AVG`, `GROUP_CONCAT`, …). |
| [`item_cmpfunc.{cc,h}`](item_cmpfunc.cc) | Comparison / boolean (`=`, `<`, `IN`, `BETWEEN`, `AND`/`OR`). |
| [`item_subselect.{cc,h}`](item_subselect.cc) | Subquery items: `IN`, `EXISTS`, scalar / row subqueries. |
| [`item_timefunc.{cc,h}`](item_timefunc.cc) | Temporal functions. |
| [`item_jsonfunc.{cc,h}`](item_jsonfunc.cc) | JSON_*. |
| [`item_xmlfunc.{cc,h}`](item_xmlfunc.cc) | XML / EXTRACTVALUE / UPDATEXML. |
| [`item_windowfunc.{cc,h}`](item_windowfunc.cc) | Window functions. |
| [`item_geofunc.{cc,h}`](item_geofunc.cc) | GIS functions. |
| [`item_vectorfunc.{cc,h}`](item_vectorfunc.cc) | Vector / similarity functions (MariaDB 11.8+). |
| [`item_create.{cc,h}`](item_create.cc) | **Factory.** Maps SQL identifier → `Item_func_*` constructor. Where a new function name gets registered. Subclass `Create_func` (or its arity helpers `Create_func_arg0` / `Create_func_arg1` / `Create_func_arg2` / `Create_func_arg3` / `Create_native_func`); the arity check lives in the factory, not in `fix_fields`. The registry is `native_functions_hash` populated by `item_create_init()`; existing entries — search for `static Native_func_registry` arrays in `item_create.cc` — are the copy-paste template. |

**Choosing an `Item_func` base class**: pick by *return type*, not by *argument type*.

| Base | When |
|---|---|
| `Item_int_func` | Returns an integer. |
| `Item_real_func` | Returns a `double`. Most numeric functions whose precision exceeds `DECIMAL` use this. |
| `Item_decimal_func` | Returns a `DECIMAL`. |
| `Item_str_func` | Returns a string (you'll typically derive from `Item_str_ascii_func` or `Item_str_ascii_checksum_func` for fixed-charset results). |
| `Item_datefunc` / `Item_timefunc` / `Item_datetimefunc` / `Item_temporal_func` | Returns the named temporal type. |
| `Item_func_hybrid_field_type` / `Item_func_numhybrid` | Return type depends on argument types (e.g. `GREATEST`, `IF`). Override `fix_length_and_dec_*()` per type family. |
| `Item_bool_func` | Boolean/predicate (`IS NULL`, `<`, `BETWEEN`). |

Then override (at minimum): one `val_*()` method matching your return type (`val_int`, `val_real`, `val_str`, `val_decimal`, `get_date`); `fix_length_and_dec()` to set precision/length/charset/null-ability; `func_name()` returning a `LEX_CSTRING` with the SQL identifier; and `get_copy()` so the optimizer can clone your item during transformation (use the `COPY_OR_SAME` / `get_item_copy` helpers — copy-paste from a sibling).

### Tables, fields, types

| File | Purpose |
|---|---|
| [`table.{cc,h}`](table.cc) | `TABLE` (per-open) and `TABLE_SHARE` (per-share, cached). The in-memory table representation. |
| [`field.{cc,h}`](field.cc) | `Field` hierarchy: per-column storage / conversion / packing. |
| [`sql_type.{cc,h}`](sql_type.cc) | `Type_handler` — the single dispatch point for "how does this data type behave". |
| `sql_type_*.{cc,h}` | Per-type plug-ins (`sql_type_json.cc`, `sql_type_geom.cc`, `sql_type_row.cc`, `sql_type_string.cc`, `sql_type_vector.cc`, `sql_type_composite.cc`). |
| [`unireg.{cc,h}`](unireg.cc) | `.frm`-file writers; legacy table-definition format glue. |
| [`create_options.{cc,h}`](create_options.cc) | Engine-specific `CREATE TABLE ... <opt>=<val>` parsing. |

### Storage-engine API

| File | Purpose |
|---|---|
| [`handler.{cc,h}`](handler.cc) | `class handler` (per-table-instance API the optimizer/executor calls) and `struct handlerton` (per-engine singleton: capabilities, factory functions). The integration boundary every engine implements. |
| [`ha_partition.{cc,h}`](ha_partition.cc) | The partitioning meta-engine (delegates to child handlers). |
| [`ha_sequence.{cc,h}`](ha_sequence.cc) | The `SEQUENCE` engine glue. |
| [`derived_handler.{cc,h}`](derived_handler.cc), [`select_handler.{cc,h}`](select_handler.cc), [`group_by_handler.{cc,h}`](group_by_handler.cc) | "Pushdown" handler hooks an engine can implement to take over derived-table / select / GROUP BY execution. |
| [`multi_range_read.{cc,h}`](multi_range_read.cc) | MRR (multi-range read) interface helpers. |

### Replication

| File | Purpose |
|---|---|
| [`log.cc`](log.cc) | The binlog (`MYSQL_BIN_LOG`) and engine-tx coordination at commit. |
| [`log_event.{cc,h}`](log_event.cc), [`log_event_server.cc`](log_event_server.cc), [`log_event_client.cc`](log_event_client.cc) | Binlog event types: `Query_log_event`, `Rows_log_event`, `Gtid_log_event`, `Format_description_log_event`, … |
| [`sql_repl.cc`](sql_repl.cc) | `COM_BINLOG_DUMP*` server side, `SHOW BINLOG EVENTS`. |
| [`rpl_mi.{cc,h}`](rpl_mi.cc), [`rpl_rli.{cc,h}`](rpl_rli.cc) | `Master_info` (per-master state) and `Relay_log_info` (per-replication channel state). |
| [`rpl_parallel.{cc,h}`](rpl_parallel.cc) | Parallel SQL applier (optimistic / conservative / aggressive). |
| [`rpl_gtid.{cc,h}`](rpl_gtid.cc) | GTID type, `gtid_set`, `gtid_state`, `slave_pos`. |
| [`rpl_record.{cc,h}`](rpl_record.cc) | Row-based replication record packing. |
| [`slave.{cc,h}`](slave.cc) | IO + SQL slave threads. |
| [`semisync*.{cc,h}`](semisync.cc) | Semi-sync master/slave plugins (in-tree). |
| [`wsrep_*.{cc,h}`](wsrep_mysqld.cc) | Galera integration; uses the `wsrep-lib` submodule. |
| [`wsrep_dummy.cc`](wsrep_dummy.cc) | The stub built when `WITH_WSREP=OFF` — references here must compile without the submodule. |

### Stored programs

| File | Purpose |
|---|---|
| [`sp.{cc,h}`](sp.cc) | mysql.proc / mysql.func table I/O, stored-routine cache lookup. |
| [`sp_head.{cc,h}`](sp_head.cc) | `sp_head` — the compiled program (instruction list, locals, handlers). |
| [`sp_instr.{cc,h}`](sp_instr.cc) | The `sp_instr_*` opcodes (set/jump/stmt/cursor/return/error). |
| [`sp_pcontext.{cc,h}`](sp_pcontext.cc) | **Parse**-time context: lexical scope, variable/cursor declarations, condition handlers. |
| [`sp_rcontext.{cc,h}`](sp_rcontext.cc) | **Run**-time context: variable storage, cursor instances, handler stack. |
| [`sp_cache.{cc,h}`](sp_cache.cc) | LRU cache of `sp_head`s per THD. |
| [`sp_cursor.{cc,h}`](sp_cursor.cc) | Cursor execution. |

### ACL & privileges

| File | Purpose |
|---|---|
| [`sql_acl.{cc,h}`](sql_acl.cc) | In-memory ACL caches (`acl_users`, `acl_dbs`, `acl_roles`, `column_priv_hash`), `mysql.user` etc. readers, role propagation. |
| [`grant.{cc,h}`](grant.cc) | `GRANT` / `REVOKE` statement execution. |
| [`password.c`](password.c) | Native auth password hashing. |

### Plugin host

| File | Purpose |
|---|---|
| [`sql_plugin.{cc,h}`](sql_plugin.cc) | Plugin loader, `INSTALL PLUGIN` / `UNINSTALL`, service-registration glue. New plugin services land here. |
| [`sql_plugin_compat.h`](sql_plugin_compat.h) | Forward-compat ABI shims for older plugin versions. |
| [`sql_plugin_services.inl`](sql_plugin_services.inl) | The registry of services exposed to plugins (audit, encryption, locale, json, etc.). |

### System variables

| File | Purpose |
|---|---|
| [`sys_vars.cc`](sys_vars.cc) | All built-in `Sys_var_*` definitions. New sysvar → here. |
| [`sys_vars.inl`](sys_vars.inl) | The `Sys_var_*` class templates. |
| [`set_var.{cc,h}`](set_var.cc) | `SET` statement execution, `Sys_var` base class. |

### Errors & messages

| File | Purpose |
|---|---|
| [`share/errmsg-utf8.txt`](share/errmsg-utf8.txt) | **Canonical** source of every `ER_*` code, in every translation. Edited by hand; `comp_err` builds `errmsg.sys` and the C header. |
| [`sql_error.{cc,h}`](sql_error.cc) | `Sql_condition`, `Diagnostics_area`, `Warning_info` — the SQL-layer error/warning machinery. |
| [`derror.{cc,h}`](derror.cc) | Loads compiled translations into the server. |
| [`sql_signal.cc`](sql_signal.cc) | `SIGNAL` / `RESIGNAL`. |
| [`mysqld.cc::sql_print_*`](mysqld.cc) | Error-log writers (`sql_print_error`, `sql_print_warning`, `sql_print_information`). |

---

## THD lifecycle & the `current_thd` rule

- **One `THD` per connection thread.** The server creates it in `handle_one_connection` and destroys it on disconnect.
- **`THD::store_globals()`** plugs the THD into `pthread_setspecific(THR_THD, this)` so that `current_thd` (and `_db_push_()`-style DBUG calls) return it. Until this is called, **`current_thd` returns NULL**.
- **Background threads construct their own THD** — event scheduler, purge, parallel-applier workers, slave IO/SQL threads, page cleaner. They're not connections, but they use the same `THD::store_globals()` plumbing. Search for `new THD(next_thread_id())` to find them.
- **Don't call `current_thd` from contexts where no THD is set**: global initializers, signal handlers, asynchronous I/O completion callbacks, OS-thread entry points before `store_globals()`. Pass `thd` explicitly down the call chain instead.
- **`THD::mem_root` is per-statement.** It is reset between statements (`free_root(thd->mem_root, MYF(MY_KEEP_PREALLOC))`).
- **`THD::stmt_arena->mem_root` is per-prepared-statement / per-stored-program.** Allocations there survive re-execution. Items mutated during `fix_fields` / `optimize` must be careful which arena they were allocated from — see below.

See [`.claude/review/api-and-architecture.md`](../.claude/review/api-and-architecture.md) ("De-THD direction") for the policy on adding new fields to THD: **don't**, unless you have a measured reason.

---

## Prepared statements & re-execution

The single most error-prone area of `sql/`. A prepared statement (`PREPARE … FROM`, the binary protocol, or implicit prep via stored programs) is parsed and `fix_fields`'d **once**, then executed many times. Item rewrites that happen during the first execution (`Item::transform`, optimizer substitutions, constant folding) must:

- **Allocate on the right arena.** Rewrites that need to persist across re-execution go on `thd->stmt_arena->mem_root`. Rewrites that are per-execution scratch go on `thd->mem_root` and must be undone in `Item::cleanup` so the next execution starts clean.
- **Never leave dangling pointers.** If the rewrite changed an `Item *` somewhere, `Item::cleanup` must reset it. The debug-build assertion `PROTECT_STATEMENT_MEMROOT` (enabled in `CMAKE_BUILD_TYPE=Debug`, see [`.claude/review/build-and-cmake.md`](../.claude/review/build-and-cmake.md)) trips on writes to the statement arena from a non-prepare context — that's the canary.
- **Preserve the original tree under `THD::stmt_arena`.** [`sql_prepare.cc`](sql_prepare.cc) is the entry point: `mysql_stmt_prepare`, `Prepared_statement::execute`, `mysql_stmt_execute_common`.
- **Cover prepared and procedural execution in tests.** Reviewers flag any new SQL feature whose MTR test doesn't include `prepare … execute …` and stored-procedure variations — see [`.claude/review/testing.md`](../.claude/review/testing.md).
- **`get_copy()` and `func_name()` are easy to forget** when subclassing `Item_func`. `get_copy()` lets the optimizer clone your item during transformation (without it, a transformed copy will alias the original's children and you'll get crashes on re-execution). `func_name()` is used for `EXPLAIN`, error messages, and `JSON_OBJECTAGG`-style introspection — missing it shows up as an empty function name in user output. Copy both from a sibling subclass.

Deep dive — covered in [`sql/docs/item-system.md`](docs/item-system.md).

---

## TABLE record buffers & paired `Field` pointers

Every open `TABLE` has at least two row buffers: `table->record[0]` ("the current row") and `table->record[1]` ("the previous row"). Their use depends on the operation:

- **`UPDATE`** — `record[0]` holds the new row being constructed; `record[1]` holds the original row. Storage engines compare them, BEFORE/AFTER UPDATE triggers see both, RBR emits both images in the binlog, and `UPDATE ... RETURNING OLD_VALUE(col)` reads from `record[1]`.
- **`DELETE`** — `record[0]` holds the row being deleted.
- **`INSERT`** — only `record[0]` is meaningful.

`Field` carries **paired pointers** mirroring this dual-buffer layout:

| Pointer | Points into | Read by |
|---|---|---|
| `Field::ptr` | `record[0]` | `val_int` / `val_str` / `val_decimal` / `get_date` — the active row's data. |
| `Field::ptr_old` | `record[1]` (when set) | Code that wants the previous row's data; set by `Item_old_field::fix_fields` and similar. |
| `Field::null_ptr` | `record[0]`'s null bitmap | `Field::is_null()`. Points *outside* `record[0]` for `NOT NULL` columns — use `maybe_null()` to test. |
| `Field::null_ptr_old` | `record[1]`'s null bitmap | The previous-row counterpart of `null_ptr`. |

**Invariant: swap pairs, not halves.** Code that temporarily redirects a `Field` to read from `record[1]` (e.g. [`Item_old_field::send`](item.cc) for `RETURNING OLD_VALUE(col)`) must swap **both** `ptr ↔ ptr_old` *and* `null_ptr ↔ null_ptr_old`. Swapping only `ptr` reads the OLD row's data but checks the NEW row's null bit — wrong NULL semantics on nullable columns. **MDEV-39179 was exactly this bug.**

When initialising `ptr_old` / `null_ptr_old`:

```cpp
field->ptr_old = field->table->record[1] +
                 field->offset(field->table->record[0]);
if (field->null_ptr)
  field->null_ptr_old = field->table->record[1] +
                        (field->null_ptr - field->table->record[0]);
```

Test coverage: any regression test for an UPDATE-time bug should use a **nullable** column, cover **both directions** (`old=NULL → new=non-NULL` AND `old=non-NULL → new=NULL`), and include a prepared-statement variant — see [`mysql-test/CLAUDE.md`](../mysql-test/CLAUDE.md) §"PS/SP variant skeleton". A single-direction test passes accidentally if you swap only one half of the pair.

---

## MEM_ROOT vs heap

Quick rules (full details in [`.claude/reference/memory-management.md`](../.claude/reference/memory-management.md)):

- **`thd->mem_root`** — per-statement. Use for anything that lives only this statement (parsed tree nodes, optimizer scratch).
- **`thd->stmt_arena->mem_root`** — per-prepared-statement / per-stored-routine instance. Use for items / structures created during the first execution that must survive re-execution. While in the prep arena, `thd->mem_root` *is* `stmt_arena->mem_root`; outside, it isn't.
- **`thd->main_mem_root`** — the underlying root behind `thd->mem_root` when no nested arena is in effect.
- **`my_malloc` / `my_free`** — long-lived non-statement allocations (server-global state, plugin-owned data). Free what you malloc.
- **Never call `free()` on memory handed out by `alloc_root` / `MEM_ROOT`.** MEM_ROOTs are bulk-free only (`free_root`). Lifetime is the root's lifetime.
- **`my_safe_alloca`** — stack if small, heap if not. Use for variable-length scratch in hot paths.
- **`mem_root_array<T>`** — `std::vector`-shaped container that allocates on a `MEM_ROOT`. Preferred over `std::vector` for arena-scoped collections.

---

## `my_error()` vs `push_warning_printf()` vs `sql_print_error()`

The decision rule:

| If the message is… | Use | Visible to |
|---|---|---|
| An **error** that aborts the current statement | `my_error(ER_*, MYF(0), …)` | The SQL client (in `SHOW WARNINGS` and as the statement error). |
| A **warning** the client should see but the statement continues | `push_warning_printf(thd, Sql_condition::WARN_LEVEL_WARN, ER_*, …)` | The SQL client (in `SHOW WARNINGS`). |
| Server-side state, diagnostic, or startup-time info | `sql_print_error()` / `sql_print_warning()` / `sql_print_information()` | The error log only (the DBA, not the client). |
| Translatable, new wording | A new `ER_*` entry at the **end** of [`share/errmsg-utf8.txt`](share/errmsg-utf8.txt) | Same as the corresponding error/warning category. |

Authoritative rules — wording, format-specifier (`%iE` vs `%M`), identifier quoting, `errno` formatting, what to test — are in [`.claude/review/logging-and-errors.md`](../.claude/review/logging-and-errors.md). Don't restate; read.

Forbidden in server code: `printf`, `fprintf(stderr, …)`, `puts`, `ib::logger` (in *new* InnoDB code), `fprintf("%s", …)`.

---

## Where to start, by task type

| Task | First read | Then | Workflow skill / playbook |
|---|---|---|---|
| Add a SQL function (e.g. `BAR(x)`) | [`item.h`](item.h), [`item_create.cc`](item_create.cc), an existing `item_*func.cc` for shape | [`sql_yacc.yy`](sql_yacc.yy) only if a new keyword | `.claude/playbooks/add-sql-function.md` (Phase 3) |
| Add a system variable | [`sys_vars.cc`](sys_vars.cc) — find a similar variable and copy its shape | The using `.cc` file; a sysvar test under `mysql-test/suite/sys_vars/` | `.claude/playbooks/add-system-variable.md` (Phase 3) |
| Add a new error message | [`share/errmsg-utf8.txt`](share/errmsg-utf8.txt) — new code at the *end* | The `my_error()` / `push_warning_printf()` call site, and the `.result` diff | `.claude/playbooks/add-error-message.md` (Phase 3) |
| Fix an optimizer bug | [`sql_select.cc`](sql_select.cc) `JOIN::optimize`, `JOIN::exec` | The relevant `opt_*.cc` | [`sql/docs/optimizer.md`](docs/optimizer.md) |
| Item / expression bug | [`item.cc`](item.cc) `Item::fix_fields`, the specific `item_*.cc` | `Item::cleanup` / `Item::transform` | [`sql/docs/item-system.md`](docs/item-system.md) |
| Replication change | `rpl_*.{cc,h}` and `log_event*.cc` | [`log.cc`](log.cc) commit path; binlog event format | [`sql/docs/replication.md`](docs/replication.md) |
| Parser change | [`sql_yacc.yy`](sql_yacc.yy) (covers MariaDB *and* Oracle modes via `%ifdef`) | [`lex.h`](lex.h); regenerate via the build (`gen_lex_hash.cc` / `gen_lex_token.cc` build-time only) | [`sql/docs/parser.md`](docs/parser.md) |
| Stored-program change | [`sp_head.cc`](sp_head.cc), [`sp_instr.cc`](sp_instr.cc), [`sp_pcontext.cc`](sp_pcontext.cc) | `sp_rcontext.cc` for runtime | [`sql/docs/stored-programs.md`](docs/stored-programs.md) |
| Charset / collation issue | [`sql_string.cc`](sql_string.cc), `lex_charset.cc`, [`item_strfunc.cc`](item_strfunc.cc) | `m_ctype.h` API | [`sql/docs/charset-and-collation.md`](docs/charset-and-collation.md) |
| ACL change | [`sql_acl.cc`](sql_acl.cc), [`grant.cc`](grant.cc) | `sql_priv.h` / `privilege.h` privilege bits | [`sql/docs/acl-and-privileges.md`](docs/acl-and-privileges.md) |
| Add an MTR test | `mysql-test/CLAUDE.md` (Phase 1) | The suite under `mysql-test/suite/<name>/` or `mysql-test/main/` | `.claude/playbooks/add-mtr-test.md` (Phase 3) |
| Fix an MDEV bug | — | — | [`.claude/skills/mfix/SKILL.md`](../.claude/skills/mfix/SKILL.md) |
| Code-review a change | — | — | [`.claude/skills/mreview/SKILL.md`](../.claude/skills/mreview/SKILL.md) |
| Forward-merge to a newer branch | — | — | `.claude/playbooks/forward-merge.md` (Phase 3) |

---

## Pitfalls (with real MDEVs / PRs)

Most of these are restatements of single bullets from the `.claude/review/` rulebook; load the linked file for the full discussion.

- **Don't share a pointer into a buffer that may be freed.** `Item_func_trim`'s `String::set()` aliased a buffer that subsequent calls invalidated — fix was `String::copy(...)`. MDEV-32758 / PR4883; see [`.claude/review/correctness-and-security.md`](../.claude/review/correctness-and-security.md) §"Lifetime / ownership".
- **Charset propagation through Item rewrites is manual.** InnoDB raw `my_charset_filename` bytes are not UTF-8 — convert to `system_charset_info` before printing identifier-bearing messages, and test with non-ASCII. PR4342; [`.claude/review/logging-and-errors.md`](../.claude/review/logging-and-errors.md) §"InnoDB identifier display".
- **`HA_*` flags need wiring in every per-engine handler.** Cross-engine features belong above the engine layer — don't bury the check inside one engine. PR4706: "High-Level Indexes are implemented … above the engine, not in it." See [`.claude/review/api-and-architecture.md`](../.claude/review/api-and-architecture.md) §"Where features live".
- **New `ER_*` codes go at the END of [`share/errmsg-utf8.txt`](share/errmsg-utf8.txt)** to keep the numeric ABI stable. Don't reorder, don't insert in the middle. Translatable per-language strings are required. PR4712.
- **No Yoda conditions** (`if (0 == err)`). Write `if (!err)`. CODING_STANDARDS.md; [`.claude/review/coding-style.md`](../.claude/review/coding-style.md).
- **`TABLE *t`, not `TABLE* t`** — pointer asterisk binds to the variable. PR4914.
- **No `long` / `ulong` in new code** — width differs Linux vs Windows. Use `size_t`, `int64_t`, `uint32_t`. PR4522.
- **No C-style casts in C++ code.** Use constructor-style: `int(len)`, `uint16_t(n)`. PR4717, PR4783, PR4884.
- **Validity checks live in the sysvar `check` callback, not `update`.** The server already writes the sysvar's own storage; don't re-do it in `update`. PR4633.
- **Don't reuse existing privileges (`SUPER`, `FEDERATED ADMIN`) for new functionality** — mint a new privilege. PR4743.
- **Internal containers, not STL** in `sql/*`: `HASH`, `String`, `StringBuffer<>`, `Hash_set`, `IO_CACHE`. `std::unordered_map` / `std::function` get rejected in hot paths. PR4430, PR4618, PR4808.
- **Don't change on-disk / wire format without a downgrade story.** Information-schema column widths, binlog event order, master-info field order — all stable. PR4243, PR4430, PR4573 (MD5 → XXH3 width thread).
- **Submodule bumps are out-of-band PRs.** Don't fold a `libmariadb` / `wsrep-lib` / `wolfssl` SHA bump into a feature/bug-fix PR. PR3726, PR4557, PR4829.
- **Prepared-statement and stored-procedure test variants are not optional** for any new SQL feature. See PR4433 and [`.claude/review/testing.md`](../.claude/review/testing.md) §"Cover every documented branch".

---

## See also

- Root [`CLAUDE.md`](../CLAUDE.md) — project-wide overview, build, branch policy.
- [`CODING_STANDARDS.md`](../CODING_STANDARDS.md) — the authoritative human-targeted style guide.
- [`.claude/review/README.md`](../.claude/review/README.md) — the distilled rulebook index.
  - [`.claude/review/checklist.md`](../.claude/review/checklist.md) — pre-PR / pre-merge checklist.
  - [`.claude/review/coding-style.md`](../.claude/review/coding-style.md)
  - [`.claude/review/api-and-architecture.md`](../.claude/review/api-and-architecture.md)
  - [`.claude/review/correctness-and-security.md`](../.claude/review/correctness-and-security.md)
  - [`.claude/review/logging-and-errors.md`](../.claude/review/logging-and-errors.md)
  - [`.claude/review/testing.md`](../.claude/review/testing.md)
  - [`.claude/review/commit-and-process.md`](../.claude/review/commit-and-process.md)
  - [`.claude/review/innodb.md`](../.claude/review/innodb.md)
  - [`.claude/review/build-and-cmake.md`](../.claude/review/build-and-cmake.md)
  - [`.claude/review/anti-patterns.md`](../.claude/review/anti-patterns.md)
- [`.claude/skills/mfix/SKILL.md`](../.claude/skills/mfix/SKILL.md) — MDEV bug-fix end-to-end workflow.
- [`.claude/skills/mreview/SKILL.md`](../.claude/skills/mreview/SKILL.md) — code-review orchestration.
- Forward references (not yet written):
  - `mysql-test/CLAUDE.md` (Phase 1)
  - `storage/innobase/CLAUDE.md` (Phase 1)
  - `.claude/reference/glossary.md` (Phase 2)
  - `.claude/reference/branches-and-forward-merges.md` (Phase 2)
  - `.claude/playbooks/add-sql-function.md`, `add-system-variable.md`, `add-error-message.md`, `add-mtr-test.md`, `forward-merge.md` (Phase 3)
  - [`sql/docs/item-system.md`](docs/item-system.md), [`optimizer.md`](docs/optimizer.md), [`replication.md`](docs/replication.md), [`parser.md`](docs/parser.md)
  - [`sql/docs/stored-programs.md`](docs/stored-programs.md), [`acl-and-privileges.md`](docs/acl-and-privileges.md), [`charset-and-collation.md`](docs/charset-and-collation.md)
  - [`.claude/reference/memory-management.md`](../.claude/reference/memory-management.md), [`error-handling.md`](../.claude/reference/error-handling.md), [`threading-and-locks.md`](../.claude/reference/threading-and-locks.md), [`debug-tooling.md`](../.claude/reference/debug-tooling.md)

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `fe7bc8c92f8` (branch `main`).
- **Files surveyed:**
  - Full `ls sql/` listing (~565 entries; 249 `.cc`, 296 `.h`, plus generators, `sql_yacc.yy`, `share/`, `wsrep_*` family, etc.).
  - Spot-read [`sql/CMakeLists.txt`](CMakeLists.txt) to confirm the parser pipeline (`sql_yacc.yy` → `yy_mariadb.yy` + `yy_oracle.yy` via [`gen_yy_files.cmake`](gen_yy_files.cmake) — there is no checked-in `sql_yacc_ora.yy`).
  - [`.claude/review/*.md`](../.claude/review/) — for citation targets.
  - [`.claude/docs-plan/PLAN.md`](../.claude/docs-plan/PLAN.md) — for outline and forward-reference paths.
  - Recent `sql/` commit log (`git log --oneline -20 -- sql/`) for currency.
- **Deliberately excluded:**
  - File-by-file paraphrase (read the file, not a paraphrase).
  - Detailed item / optimizer / replication semantics — those are Phase-4 deep references.
  - Build / sanitizer / branch-policy details — root `CLAUDE.md` and the rulebook own those.
  - Submodule descriptions — root `CLAUDE.md` lists them.
  - Windows-specific files (`handle_connections_win.*`, `threadpool_win.*`, `mysql_upgrade_service.cc`, `winservice.*`, `winmain.cc`, `message.mc`) — mentioned only when relevant.
- **Refresh procedure:**
  - When a file cluster grows or shifts (new `opt_*.cc`, new `wsrep_*`, new `sql_type_*.cc`, etc.), update the relevant table.
  - Bump `last-verified` to the new walk-through date.
  - If a rulebook section moves or a new MDEV pitfall lands, update the citations.
  - Re-run the Phase-1 validation prompt ("add a new SQL function `BAR(x)` …") against a fresh subagent and fold any miss back into this file.
