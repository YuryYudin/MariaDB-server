---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/sp_*.{cc,h}
---

# Reference: stored programs

Deep dive on stored programs — procedures, functions, triggers, events, and Oracle-compat packages. This is the *concepts* doc; the high-level map of `sp_*.{cc,h}` files lives in [`sql/CLAUDE.md`](../CLAUDE.md) §"Stored programs" — read that first; this doc goes inside.

Adjacent docs: stored-program parsing (the "second parser pass") is in [`sql/docs/parser.md`](parser.md). `Item` semantics — including `Item_splocal` (SP locals as items) and `Item_trigger_field` (NEW/OLD as items) — are in [`sql/docs/item-system.md`](item-system.md).

---

## 1. TL;DR

- **`sp_head`** is the *compiled program*: a long-lived object holding the instruction array, parameter and local declarations, condition handlers, security context, charset and DEFINER. One per cached routine. Declared via `grep -nE '^class sp_head' sql/sp_head.h`.
- **`sp_instr_*`** are the *opcodes*. The interpreter walks `sp_head::m_instr` (a `DYNAMIC_ARRAY`) and dispatches `execute()` per element. The opcode family is enumerated by `grep -nE '^class sp_instr_' sql/sp_instr.h`.
- **`sp_pcontext`** is the *parse-time* scope: a tree mirroring lexical `BEGIN…END` blocks, holding variable / cursor / handler / sub-block declarations. Built by the parser as it descends; never touched at run time.
- **`sp_rcontext`** is the *run-time* stack: per-execution variable slots, cursor instances, and the handler-state stack. Created fresh by `sp_head::rcontext_create` each invocation.
- **Compile once, execute many.** `sp_head` is built on first call and cached in `sp_cache` (LRU, per-THD); DDL on the routine increments a global `Cversion` that invalidates entries on next lookup.

---

## 2. What "stored programs" covers

All four user-facing kinds share the `sp_*` machinery:

| Kind | Created by | Body parsed into | Invoked by |
|---|---|---|---|
| Procedure | `CREATE PROCEDURE` | `sp_head` (`Sp_handler` = `sp_handler_procedure`) | `CALL p()` (`SQLCOM_CALL`) → `sp_head::execute_procedure` |
| Function | `CREATE FUNCTION` | `sp_head` (function `Sp_handler`) | Expression evaluation; `Item_func_sp::execute` → `sp_head::execute_function` |
| Trigger | `CREATE TRIGGER` | `sp_head` (`Sp_handler` = `sp_handler_trigger`) | Storage-engine row events; `Table_triggers_list::process_triggers` → `sp_head::execute_trigger` |
| Event | `CREATE EVENT` | `sp_head` for the body | The event scheduler thread → `sp_head::execute_procedure` |
| Package (Oracle mode) | `CREATE PACKAGE` / `CREATE PACKAGE BODY` | A pair of `sp_head`s (`sp_handler_package_spec`, `sp_handler_package_body`); each routine inside is its own `sp_head` with `m_parent` set | Per-routine call as above |

Concretely: triggers and events do *not* have their own bytecode. The body is a SQL block parsed into the same `sp_instr_*` opcode list as a procedure body. What differs is the **invocation harness** (no SQL `CALL`, no `Item_func_sp` — see §9).

The metadata storage tables are `mysql.proc` (procedures, functions, packages), `mysql.event` (events), and `mysql.triggers` together with the per-table `.TRG` files (triggers live partly on disk next to the table whose rows they fire on).

---

## 3. Lifecycle

```
DDL (CREATE)           First reference        Subsequent references
─────────────          ──────────────         ─────────────────────
 sp_create_routine()      sp_cache_routine()      sp_cache_lookup() → hit
 writes mysql.proc        reads mysql.proc                ↓
        ↓                        ↓                  execute_procedure /
   nothing in cache         re-parse body           execute_function /
                            ↓                       execute_trigger
                          build sp_head
                            ↓
                          sp_cache_insert()
                            ↓
                          execute…
```

### 3.1 Create

`Sp_handler::sp_create_routine` (`grep -nE 'sp_create_routine' sql/sp.cc`) writes a row to `mysql.proc` (or `mysql.event`) containing the body text, characteristic flags, DEFINER, security mode, charset and `sql_mode`, parameter list, returns clause. The routine body is *stored as text*, not as bytecode — every load re-parses.

### 3.2 Load

On first call from a connection, `dispatch_command` / the optimizer / a trigger event walks through `Sp_handler::sp_cache_routine` (`grep -nE 'Sp_handler::sp_cache_routine' sql/sp.cc`). On a miss it:

1. Reads the row from `mysql.proc` (or the `.TRG` file for triggers).
2. Runs the parser on the body text in **stored-program parse mode**: `THD::lex->sphead` is set to a fresh `sp_head`, and the bison grammar calls `sp_head::add_instr` for each statement / control construct it reduces (see [`sql/docs/parser.md`](parser.md) §"Stored-program parsing", and `grep -nE 'LEX::sphead' sql/sql_lex.h`).
3. Inserts the result into the cache via `sp_cache_insert` (see `grep -nE 'sp_cache_insert' sql/sp_cache.h`).

### 3.3 Compile

Each parsed statement / control construct in the body becomes one or more `sp_instr_*` appended to the instruction array `sp_head::m_instr` (`grep -nE 'DYNAMIC_ARRAY m_instr' sql/sp_head.h`). Control flow constructs (`IF`, `WHILE`, `LOOP`, `CASE`, `REPEAT`) are lowered by the parser into combinations of `sp_instr_jump` / `sp_instr_jump_if_not` and labels. Local variable assignments become `sp_instr_set`. Cursors expand to a multi-instruction declare/open/fetch/close sequence.

All `Item *` subtrees inside instructions are allocated on the **sp_head's own `MEM_ROOT`** (`sp_head::main_mem_root`), so they survive across executions.

### 3.4 Execute

Three entry points on `sp_head`:

| Function | Caller | Returns to |
|---|---|---|
| `sp_head::execute_procedure(THD*, List<Item>* args)` | `mysql_execute_command(SQLCOM_CALL)` | `CALL` statement caller |
| `sp_head::execute_function(THD*, Item** args, …)` | `Item_func_sp::execute` (expression context) | The `Field*` `return_fld` passed in |
| `sp_head::execute_trigger(THD*, …)` | `Table_triggers_list::process_triggers` | Bool success/fail; no SQL result |

Each entry point: creates an `sp_rcontext`, sets it on the THD, then enters the interpreter loop — fetch instruction at `ip`, call its virtual `execute(thd, &next_ip)`, advance `ip` to `next_ip`. Exits when `next_ip` falls off the end, when an unhandled error fires, or when an explicit `RETURN` / `LEAVE` jump goes past the entry's range.

Find them with `grep -nE 'sp_head::execute_(procedure|function|trigger)' sql/sp_head.cc`.

### 3.5 Cache and invalidation

`sp_cache` is a per-THD object pointed to from `thd->sp_proc_cache` / `thd->sp_func_cache` / `thd->sp_package_spec_cache` / `thd->sp_package_body_cache`. Internally an LRU-bounded hash keyed by qualified name; see `grep -nE 'class sp_cache' sql/sp_cache.cc`.

Invalidation is **version-stamp based**, not direct purge:

- The global `Cversion` counter is bumped by `sp_cache_invalidate()` on any DDL that could affect routines (`CREATE`/`DROP`/`ALTER PROCEDURE`, `FLUSH ROUTINES`, etc.).
- Each cached `sp_head` remembers `m_sp_cache_version` at insertion.
- `sp_cache_lookup` compares the two on every hit and treats stale entries as misses; `sp_cache_flush_obsolete` actually frees them. See `grep -nE 'sp_cache_flush_obsolete|sp_cache_version' sql/sp_cache.cc sql/sp_head.h`.

A running execution holds a reference (`sp_head::m_flags |= IS_INVOKED`); flush won't free a sp_head that's currently on a call stack.

---

## 4. `sp_head` — the compiled program

What's inside, by group (member names below — `grep -nE 'class sp_head' sql/sp_head.h` for the declaration):

**Identity / metadata.** `m_handler` (the `Sp_handler` — procedure / function / trigger / event / package), `m_qname` (`db.name`), `m_params` and `m_body` (the original source text — needed for `SHOW CREATE`), `m_defstr` (the reconstructed `CREATE` text), `m_definer`, `m_sql_mode`, `m_creation_ctx` (per-DDL charset triple: client / connection / results — applied on every execution so the body parses the same way regardless of caller `sql_mode`).

**Compiled body.** `m_instr` — the `DYNAMIC_ARRAY` of `sp_instr*` pointers. `m_pcont` — the root `sp_pcontext` retained for introspection / `SHOW CREATE` text reconstruction (the *runtime* doesn't need the pcontext, but tools and re-resolution do).

**Function-specific.** `m_return_field_def` (`Spvar_definition` of the RETURNS clause).

**Flags.** `m_flags` bitset: `HAS_RETURN`, `MULTI_RESULTS`, `CONTAINS_DYNAMIC_SQL`, `IS_INVOKED`, `HAS_SET_AUTOCOMMIT_STMT`, `HAS_COMMIT_OR_ROLLBACK`, `MODIFIES_DATA`, `HAS_COLUMN_TYPE_REFS`, `HAS_AGGREGATE_INSTR`. Used by the optimizer (e.g. detection of binlog-unsafe routines) and by the trigger / function call site (e.g. forbidding `MULTI_RESULTS` in trigger bodies).

**Security and recursion.** `m_security_ctx` (DEFINER's context for SUID routines). `m_recursion_level`, `m_next_cached_sp`, `m_first_instance`, `m_first_free_instance` — linked list of clones at different recursion depths; one `sp_head` per depth so concurrent recursion has separate `sp_rcontext` storage.

**Memory.** `sp_head` privately inherits from `Query_arena`. `main_mem_root` owns the entire compiled tree: every `Item`, every `sp_instr_*`, every `sp_pcontext` node. Freed in bulk by `sp_head::destroy`.

**Cache versioning.** `m_sp_cache_version` (see §3.5).

---

## 5. The `sp_instr_*` opcodes

The instruction set is small (~25 opcodes) and visible at one grep: `grep -nE '^class sp_instr_' sql/sp_instr.h`.

| Opcode | One-line purpose |
|---|---|
| `sp_instr_stmt` | Execute an embedded SQL statement (the most common opcode; wraps a parsed `LEX` plus its mini-arena). |
| `sp_instr_set` | Assign a value to a local variable (`v := expr`, `SET v = expr`). Subclasses cover row-field assignment (`r.col := …`), associative-array element assignment (`m('k') := …`), trigger-field assignment (`NEW.col := …`). |
| `sp_instr_set_default_param` | Materialise a default for a parameter that wasn't passed. |
| `sp_instr_set_case_expr` | Evaluate the `CASE expr` operand once into a hidden slot for subsequent `WHEN` comparisons. |
| `sp_instr_jump` | Unconditional jump (target instruction index). |
| `sp_instr_jump_if_not` | Conditional jump: evaluate a `bool` expression, jump if false. The building block of `IF` / `WHILE` / `UNTIL`. |
| `sp_instr_preturn` | Procedure return (`RETURN` without a value in a procedure context, or fall-through past END). |
| `sp_instr_freturn` | Function return — evaluate the return expression, write to the caller-supplied `Field`, then exit. |
| `sp_instr_hpush_jump` | Push a condition handler (`DECLARE … HANDLER FOR …`) on the rcontext handler stack; the "jump" goes past the handler body so the handler isn't entered inline. |
| `sp_instr_hpop` | Pop *N* handlers off the stack on block exit. |
| `sp_instr_hreturn` | Return from a `CONTINUE` / `EXIT` handler body to the appropriate resumption point. |
| `sp_instr_cpush` | Push a cursor declaration onto the rcontext cursor stack (`DECLARE c CURSOR FOR …`). The cursor's query LEX is owned by this instruction. |
| `sp_instr_cpop` | Pop *N* cursors off the stack on block exit. |
| `sp_instr_copen` | `OPEN c` — run the cursor's SELECT, open the result-set state. |
| `sp_instr_cclose` | `CLOSE c`. |
| `sp_instr_cfetch` | `FETCH c INTO v1, v2, …` — pull one row, assign columns to local variables. |
| `sp_instr_agg_cfetch` | The aggregate-function variant: `FETCH GROUP NEXT ROW` inside an `AGGREGATE FUNCTION` body. |
| `sp_instr_cursor_copy_struct` | When declaring a record `r %ROWTYPE` of a cursor, copy the cursor's column types into the record's `Row_definition_list` so its sp_variable slot has the right shape. |
| `sp_instr_copen_by_ref` / `sp_instr_cclose_by_ref` / `sp_instr_cfetch_by_ref` | REF CURSOR variants (MDEV-10152) — operate on a cursor passed by reference rather than declared locally. |
| `sp_instr_error` | Explicit `SIGNAL` — raise a SQL condition with a given SQLSTATE / number / message. |
| `sp_instr_destruct_variable` | Run the destructor for a composite variable going out of scope (associative arrays, records). |
| `sp_instr_set_trigger_field` | The `NEW.col := …` assignment inside a `BEFORE` trigger body. |
| `sp_instr_set_ps_placeholder` | Bind a prepared-statement parameter at execute time (used inside packages built around `DBMS_SQL`). |

Most non-trivial opcodes inherit from `sp_lex_instr`, which carries a private `LEX` and `Query_arena` so each statement parses independently and is re-prepared per invocation as needed.

---

## 6. `sp_pcontext` vs `sp_rcontext`

The single most important distinction in this subsystem. They look superficially similar but live in different worlds.

### `sp_pcontext` — parse-time context

A tree of `sp_pcontext` nodes mirroring lexical block structure. Each node holds:

- Local variable declarations (`sp_variable` — name, type, mode IN/OUT/INOUT, default, offset-in-frame). `grep -nE 'class sp_variable' sql/sp_pcontext.h`.
- Cursor declarations (`sp_pcursor`).
- Condition handler declarations (`sp_handler`, with the conditions they catch).
- Labels (`sp_label`) for `LEAVE` / `ITERATE` / `GOTO` targets.
- A parent pointer and a child list — `BEGIN … END` blocks push a child; `END` pops.

The parser builds this as it descends; the root pcontext is `sp_head::m_pcont`. After parsing it's effectively read-only — its job is to be the symbol table for name resolution during the *parse* (e.g. when the parser sees `v + 1`, it walks the active pcontext chain to find `v` and emits an `Item_splocal` carrying its frame offset).

### `sp_rcontext` — run-time context

A flat per-execution structure (`grep -nE '^class sp_rcontext' sql/sp_rcontext.h`). Created by `sp_head::rcontext_create` at the start of every call. Holds:

- A **frame** of variable storage — one slot per `sp_variable`. Implemented as a `Virtual_tmp_table` so each slot is a real `Field` and the type-handler machinery works uniformly (assignments go through `Field::store`; reads through `Field::val_*`).
- A stack of open `sp_cursor` instances.
- A stack of **active condition handlers**, with per-handler activation state (a handler "fires" when a matching condition is raised; the runtime jumps to its handler body, runs it, then `sp_instr_hreturn` resumes).
- A pointer to the caller's `sp_rcontext` (for chained DEFINER calls).
- Recursion-frame bookkeeping.

The instruction-vs-context split is the same idea as a bytecode VM: instructions are static and shared across invocations; the rcontext is the per-invocation stack.

---

## 7. Parameter passing — IN / OUT / INOUT

`sp_variable::mode` is `MODE_IN` / `MODE_OUT` / `MODE_INOUT` (`grep -nE 'enum_mode' sql/sp_pcontext.h`).

- **IN** — caller's `Item *` is evaluated once at call entry; the result is stored into the rcontext frame slot. Mutations to the local don't leak back.
- **OUT** — frame slot is initialised to NULL at call entry; caller's `Item *` must be assignable (an `Item_field` of a writable column, a user variable, an SP local). On return, the slot value is written back via the caller's item.
- **INOUT** — caller's value flows in at entry, the slot's value flows out at return.

The write-back happens in `sp_head::execute_procedure` after the interpreter loop returns; the caller's argument list (`List<Item> *args`) is walked, and for each OUT/INOUT parameter the frame slot is `set_value`'d through the original `Item *`. For an `Item_field`, that updates the underlying column; for `Item_user_var_as_out_param`, it updates the user variable.

Function return values (`RETURN expr`) go through `sp_instr_freturn`, which evaluates `expr` and stores the result into the caller-supplied `return_fld` parameter of `execute_function`. There's no "OUT param" for the return; the function's return value rides on `Item_func_sp` exactly the way a built-in's return rides on its `val_*`.

Recent work: **MDEV-38768** (RECORD in routine parameters and function RETURN) extended OUT/INOUT to composite row types. **MDEV-10152** (REF CURSOR) added cursor-by-reference parameters — see the `sp_instr_*_by_ref` opcode family in §5.

---

## 8. Cursors

`sp_cursor` (`grep -nE '^class sp_cursor' sql/sp_cursor.h`) wraps a query string plus enough state to fetch rows one at a time:

- The compiled `LEX` for the cursor's SELECT (lives on `sp_instr_cpush`'s arena).
- The current `select_result` sink (rebound to fetch into the FETCH target list).
- A `sp_cursor_statistics` base for `%FOUND` / `%NOTFOUND` / `%ROWCOUNT` introspection.
- A re-open count and an "is open" flag.

Lifecycle: `sp_instr_cpush` registers the cursor in the rcontext (parse-time-known offset); `sp_instr_copen` parses (if needed) and executes the SELECT, holding the result-set state; `sp_instr_cfetch` advances and stores columns into target locals; `sp_instr_cclose` releases the result.

**Strong (strict) cursors.** `OPEN strict_cursor FOR <stmt>` requires the runtime statement's column count/types to match the cursor's declared shape; mismatches raise a clear error rather than silently truncating or rebinding. The error wording was fixed recently — see **MDEV-39546** (commit `96b3dd0c344`).

**Prepared-statement cursors.** **MDEV-33830** added support for cursors on prepared statements — opening a cursor for a `?`-parameterised SQL text via `DBMS_SQL`-style packages.

---

## 9. Triggers

Triggers reuse the procedure machinery with three differences:

1. **Where the body lives.** The trigger body text is stored in a `.TRG` file next to the table (one `.TRG` per table, listing all its triggers), not in `mysql.proc`. The `mysql.triggers` table was added later (MDEV-25292) as the atomic-DDL replacement. Loaded by `Table_triggers_list::create_lists_needed_for_files` and friends; see `grep -nE 'Trigger_creation_ctx::create' sql/sql_trigger.cc`.
2. **How the body is parsed.** Same parser, same `sp_instr_*` opcodes, but the surrounding `LEX::sql_command` is `MYSQL_TRIGGER_SQLCOM` rather than `SQLCOM_CALL` / `SQLCOM_CREATE_FUNCTION`. The trigger handler `Sp_handler::sp_handler_trigger` plugs in trigger-specific limits (no `MULTI_RESULTS`, no schema-modifying DDL, no autonomous transaction control).
3. **How NEW and OLD work.** Inside a trigger body, `NEW.col` and `OLD.col` are not real columns — they're `Item_trigger_field` instances (`grep -nE 'class Item_trigger_field' sql/item.h`) that resolve at fix-fields time to a `Field*` aliasing `table->record[0]` (NEW) or `table->record[1]` (OLD). Assignment (`NEW.col := …` in a BEFORE trigger) goes through `sp_instr_set_trigger_field`, which calls `Field::store` directly on the active row buffer. Read [`sql/CLAUDE.md`](../CLAUDE.md) §"TABLE record buffers & paired `Field` pointers" — the same `record[0]` / `record[1]` story underpins trigger semantics.

Invocation: storage engines call `Table_triggers_list::process_triggers` from `handler::ha_write_row` / `ha_update_row` / `ha_delete_row`. BEFORE triggers run with the row buffer still mutable (so `NEW.col := …` is meaningful); AFTER triggers run post-engine-write, so assigning to `NEW.col` no longer changes what was written.

Recent additions: **MDEV-30645** (`CREATE TRIGGER FOR STARTUP | SHUTDOWN`) added server-lifetime triggers; **MDEV-34723** (NEW and OLD in a trigger as row variables) lets `NEW` / `OLD` be passed whole as `%ROWTYPE` values.

---

## 10. Pitfalls

Cite-and-link list. Most of these are restatements of single bullets from the `.claude/review/` rulebook or recent MDEVs.

- **Don't mutate `sp_head` from `cleanup()`.** `sp_head` outlives the statement that called it: it's cached across executions and shared by concurrent connections that share the cache. `cleanup()` runs per execution and must touch only the **rcontext** and per-execution scratch. Treat the sp_head as read-only after compile.
- **Don't allocate execution-scratch on the sp_head's MEM_ROOT.** Anything per-execution belongs on `thd->mem_root` or `thd->stmt_arena->mem_root`. Allocations on `sp_head::main_mem_root` survive forever and accumulate. See `PROTECT_STATEMENT_MEMROOT` (Debug builds) and [`sql/CLAUDE.md`](../CLAUDE.md) §"Prepared statements & re-execution".
- **Don't re-bind parsed `Item *` references across re-execution.** The compiled tree under the sp_head is long-lived; per-execution rewrites that change `Item *` slots must either (a) write to per-execution scratch or (b) restore the original in `Item::cleanup`. The `Item_func_trim` family (MDEV-32758) was an analogous bug in non-SP code.
- **`mysql.proc` schema changes need an upgrade path.** Adding a column means bumping `mysql.proc`'s definition in `scripts/mysql_system_tables*.sql`, teaching `mysql-upgrade` how to add the column on an old install, *and* handling the "column missing" case at read time during the upgrade window. The same applies to `mysql.event` and `mysql.triggers`.
- **BEFORE vs AFTER trigger row-buffer state differs.** A test that exercises a BEFORE trigger and an AFTER trigger with the same body will see different `record[0]` / `record[1]` contents — BEFORE sees pre-engine state, AFTER sees post-engine state. Bugs in the trigger body that depend on row-buffer aliasing (e.g. `NEW.col := OLD.col` semantics) won't be caught by testing only one. See [`sql/CLAUDE.md`](../CLAUDE.md) §"TABLE record buffers".
- **Cursors can leak when an exception unwinds without explicit CLOSE.** The handler-stack unwind in `sp_instr_hpush_jump` / `sp_instr_hreturn` does not automatically close open cursors declared in the same block; the parser inserts an `sp_instr_cpop` on block exit, which does. Hand-rolled control flow (`GOTO` past block end, `LEAVE` in unusual nesting) can bypass that. Test with a handler that catches an error after `OPEN`.
- **Recursive routines need separate `sp_rcontext` per depth.** That's why `sp_head` keeps an instance list (`m_next_cached_sp`, `m_first_free_instance`). If you add per-execution state to `sp_head` (don't — but if you must), make sure each `sp_head` clone in the chain has its own copy, not a shared one. **MDEV-37710** (ASAN errors in `find_type2`) was in this area.
- **`SIGNAL` SQLSTATE classes affect handler matching.** SQLSTATE class `'01'` is WARNING (continues), `'02'` is NOT FOUND, all others are EXCEPTION. A handler for `SQLEXCEPTION` doesn't catch a `'01'` warning. Tests must exercise the full matrix.
- **Cached sp_head invalidation is version-stamp, not eager.** A `DROP PROCEDURE` followed by `CALL` from a *different* connection that still has the old version in its private cache will re-look-up and find a NULL row — `Sp_handler::sp_cache_routine` returns SP_NOT_FOUND on the next access. But the in-cache stale `sp_head` is only freed when the version comparison fires. Don't write tests that assume eager free.
- **Trigger creation context lives separately from the trigger body.** `Trigger_creation_ctx` carries the charset / `sql_mode` / DB name at `CREATE TRIGGER` time and is re-applied on every fire. Bugs there silently corrupt identifier resolution: **MDEV-37378** (SIGSEGV on CREATE TRIGGER), **MDEV-38001** (NULL deref in `Trigger_creation_ctx::create`).

---

## 11. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) — the file-cluster map; this doc lives downstream of §"Stored programs".
- [`sql/docs/parser.md`](parser.md) — how the stored-program second parser pass works (the `LEX::sphead` invariant, statement-by-statement parsing into `sp_instr_*`).
- [`sql/docs/item-system.md`](item-system.md) — `Item_splocal`, `Item_sp_variable`, `Item_trigger_field`, how SP-local references plug into expression evaluation.
- [`.claude/reference/error-handling.md`](../../.claude/reference/error-handling.md) — `Sql_condition`, `Diagnostics_area`, SQLSTATE classification; the same machinery that SP handlers ride on.
- [`.claude/playbooks/add-mtr-test.md`](../../.claude/playbooks/add-mtr-test.md) — recording results, prepared-statement / stored-procedure variant skeletons (the SP variant is mandatory for any new SQL feature).
- [`.claude/review/testing.md`](../../.claude/review/testing.md) — "Cover every documented branch": SP/PS variant coverage is not optional.

---

## 12. How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `23097b2d825` (branch `main`).
- **Files surveyed (with the grep recipes used):**
  - `sql/sp_head.h` — class layout: `grep -nE 'class sp_head|m_instr|m_flags|m_pcont|m_sp_cache_version' sql/sp_head.h`.
  - `sql/sp_head.cc` — entry points: `grep -nE 'sp_head::execute_(procedure|function|trigger)' sql/sp_head.cc`.
  - `sql/sp_instr.h` — opcode inventory: `grep -nE '^class sp_instr_' sql/sp_instr.h`.
  - `sql/sp_pcontext.h` — parse-time classes: `grep -nE '^class' sql/sp_pcontext.h` (sp_variable, sp_label, sp_condition, sp_pcursor, sp_handler, sp_pcontext).
  - `sql/sp_rcontext.h` — `grep -nE '^class sp_rcontext' sql/sp_rcontext.h`.
  - `sql/sp_cache.{h,cc}` — public API: `grep -nE 'sp_cache_(insert|lookup|invalidate|flush_obsolete)' sql/sp_cache.h sql/sp_cache.cc`.
  - `sql/sp_cursor.h` — cursor classes: `grep -nE '^class sp_cursor' sql/sp_cursor.h`.
  - `sql/sp.cc` — DDL + load path: `grep -nE 'Sp_handler::sp_(create_routine|cache_routine)' sql/sp.cc`.
  - `sql/item.h` — `Item_trigger_field`: `grep -nE 'class Item_trigger_field' sql/item.h`.
  - Recent SP commit log: `git log --oneline -- sql/sp_*.cc | head -30` — surfaced MDEV-10152, MDEV-33830, MDEV-38109, MDEV-38768, MDEV-38933, MDEV-39546, MDEV-37710, MDEV-37378, MDEV-38001, MDEV-30645, MDEV-34723.
- **Deliberately excluded:**
  - File-by-file paraphrase of `sp_*.h` — the grep recipes above point you at the source.
  - DBMS_SQL / SYS package internals (MDEV-19635, MDEV-38933) — Oracle-compat surface area, separate doc territory.
  - Event scheduler internals (`event_scheduler.cc`, `event_queue.cc`) — they invoke `sp_head::execute_procedure`, so for SP semantics this doc covers it; the scheduler itself is its own subsystem.
  - WSREP interactions with stored programs — covered in [`sql/docs/replication.md`](replication.md).
- **Refresh procedure:**
  - When a new `sp_instr_*` lands, add a row to the opcode table in §5.
  - When the storage location for routine metadata changes (e.g. the `mysql.triggers` rollout, MDEV-25292), update §2 and §9.
  - When `sp_head` flags or members change, refresh §4. Re-run `grep -nE 'class sp_head' sql/sp_head.h` to confirm.
  - Bump `last-verified` to the new walk-through date.
  - If a rulebook section moves or a new MDEV pitfall lands, update §10.
