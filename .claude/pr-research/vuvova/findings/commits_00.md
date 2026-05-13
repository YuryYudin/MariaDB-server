## Commit message conventions

### Subject form: `MDEV-N <terse-description>` — no colon, no prefix word, sentence-case
The Jira ticket is space-separated from a normal-cased natural-language summary. He never uses `MDEV-N: ...` (colon) or `MDEV-N fix: ...` (prefix). The summary is often a copy-paste of the bug headline, including punctuation and bracketed assertion text — long subjects are accepted.

- `03dd699ffefc MDEV-37315 Assertion `!xid_state.xid_cache_element' failed in trans_xa_rollback`
- `1bdaabc0c682 MDEV-35622 SEGV, ASAN use-after-poison when reading system table with less than expected number of columns`
- `2bbfcb187602 MDEV-39408 mbstream insufficient path validation`
- `387fe5ecc3a6 MDEV-36787 Error 153: No savepoint with that name upon ROLLBACK TO SAVEPOINT, assertion failure`

Confidence: high. Applies to: every MDEV commit (~60 of 97).

### Non-MDEV subjects use lowercase prefix-word followed by topic
He uses a small fixed set of leading prefix-words for non-bug-tracker work, all lowercase, separated by colon or by a verb. Verbs prefer imperative-but-lowercase (`bump`, `fix`, `update`, `make`, `find`).

- `cleanup: <topic>` — code/build/test cleanup with no behavior change: `04ad6c707062 cleanup: make_dist.cmake.in`; `050f683c7da3 cleanup: whitespace`; `1668695b55ac cleanup: use CREATE_TYPELIB_FOR`; `292bab3565fb cleanup: Sp_caches::sp_caches_swap()`; `35f65007b749 cleanup: change sql_command_flags from uint to cf_flags_t`; `387de3d5b83d cleanup: remove unused argument`.
- `bump the VERSION` / `bump the maturity` / `bump inet4 maturity to stable` — version bumps.
- `mtr: <topic>` — mysql-test infrastructure: `26c8bc935728 mtr: make wait_for_line_count_in_file.inc leave traces in the log`; `317f099ca561 mtr: override local gnutls config`.
- `CONNECT: <topic>` — storage-engine-specific cleanup: `2abbea88fb06 CONNECT: suppress \n at the end of the error message`.
- `(clang20) error: ...` — parenthetical compiler tag: `144dead8826f (clang20) error: moving a temporary object prevents copy elision`.
- bare imperative for one-shots: `0c94001a32da fix merge test to restore the environment`; `1bb660008f1a fix the test to not leave $datadir/test/imp_t1.ibd around`; `22591551fb7f fix --path to work`; `39f490821609 update ColumnStore`; `3730b92be0d2 zlib 1.3.2`.

Confidence: high.

### Body uses terse imperatives, often bullet lists; no markdown headings; references prior SHAs as 12-char hex
Bodies are short — typically one or two lines explaining *why*, not *what*. Bullets use `*` (asterisk), never `-`. When referencing predecessors he writes "followup for <12-char-sha>" or "followup for <sha> (MDEV-N description)".

- `04e09010773c MDEV-32745 followup for 7828fb475b0` — body uses a `*`-bulleted list of sub-changes.
- `1668695b55ac cleanup: use CREATE_TYPELIB_FOR` body: `followup for f7387cb13d0`.
- `1563988ae61e` body: `followup for ef3c843c172 and 7251cbca518`.
- `2b11a0e9918a` body: `followup for 9703c90712f3 (MDEV-37199 UNIQUE KEY USING HASH accepting duplicate records)`.
- `3a2e1f87a1fa` body: `followup for 9703c90712f3 (MDEV-37199 ...)` — same hash referenced repeatedly when there are multiple followups.

Confidence: high.

### Lowercase pronoun-style bug commentary in bodies
He frequently opens the body with a lowercased clause that continues the subject grammatically — no capital letter, no formality. Sometimes drops articles. Reads like a code comment.

- `04122ed770b5 MDEV-36815 ...` body: `rewrite the check to use mysql.global_priv (finally!)`
- `04e993f0bff9 MDEV-39281 ...` body: `copy the coresponding check from OEMColumns()\n\nReported by Aisle Research` (typo "coresponding" left in)
- `0fc66b6ff0d4 MDEV-35541 UBSAN: runtime error: ...` body is the raw sanitizer trace
- `1c7685f5fc56 bugfix: nextval() in default, and UPDATE SET x=DEFAULT` body: `set thd->lex->default_used accordingly`
- `2a31a0f893d8 ...` body: `it's not an error, as the server continues anyway`

Confidence: high.

### Bug bodies often state the rationale as a numbered fact list
Where there are multiple causes/fixes, he uses `1.`, `2.` enumeration in the body.

- `387fe5ecc3a6 MDEV-36787 ...`: `1. InnoDB should return HA_ERR_ROLLBACK if it aborts a transaction internally\n2. the server should recognize it and perform an automatic rollback`
- `3e9710597578 13.0 deprecations`: structured into `removed:`, `extended under old-mode:`, `un-deprecated:` sections, each with `*`-bullets.

Confidence: medium.

### Many MDEV commits have empty bodies
For straightforward bug fixes whose subject already conveys the change, he writes no body at all. Examples: `05f36e67d373 MDEV-39266 Stack Overflow via alloca() in Privilege Table JSON Parser` (test-only adjustment); `07331813d8d6 MDEV-27277 update test results`; `1ae06b9e2ed3 MDEV-37947 Item_func_hex doesn't check for max_allowed_packet`; `21303c6bfe87 MDEV-38777 ...`; `2746c19a9cc1 MDEV-37203 UBSAN: ...`; `3b140fed0d70 bump the VERSION`. Routine merge commits also have empty bodies.

Confidence: high.

## Code style (as he writes it)

### Indentation/alignment follows server style strictly; he also retroactively un-tabs lines he touches
When editing an old file mixed with tabs, he re-indents the surrounding block to spaces. See `0dcec66416b3 MDEV-38233` (Item_func_make_set::val_str) where the entire function body is reformatted from tab-indent to space-indent in one go — purely incidental to the bug fix.

Confidence: medium.

### `nullptr` is acceptable in C++ code; `NULL`/`0` still used in older paths
He uses `nullptr` in newer code (`2c983b5ebb3a` — `Temporal::Warn_push warn(get_thd(), table ? table->s->db.str : nullptr, ...)`), but stays with `NULL`/`0` when patching old files (`1839cc67a746` — `if (null_value) return 0;` in `item_jsonfunc.h`). No campaign to convert.

Confidence: medium.

### Casts: prefers C-style; uses `static_cast<T&&>(x)` only where required by language rules
Plain C-style casts dominate (`(size_t) info->table->s->reclength` → `table->s->reclength` becomes `memcpy(... , table->s->reclength)`; `(ha_rows) ((double) ...)`; `(uint)(line-start)`). The only `static_cast` he introduced was forced by C++ syntax in a move-elision fix: `144dead8826f` uses `static_cast<Zeros&&>(rhs)` because that's the rvalue-cast idiom required for the upstream class.

Confidence: high. Applies to: server/storage/mysys.

### Variable hoisting: introduces a local at the top of a block when it removes a chain of `info->table->...`
He repeatedly refactors `info->table->file->...` into `TABLE *table= info->table; ... table->file->...`. Same change applied to multiple member references in the same block.

- `28b09e353734 MDEV-34984 rr_from_cache ...`: added `TABLE *table= info->table;` at top of function, then `table->file->print_error`, `memcpy(info->record(), info->cache_pos, table->s->reclength);`, `table->file->ha_rnd_pos(...)`.

Confidence: medium (this pattern appears multiple times across his work).

### `unlikely(...)` is removed when the surrounding code doesn't really need it
He pruned `unlikely((error= ...))` to plain `(error= ...)` in `28b09e353734`. He uses `unlikely` himself sparingly.

Confidence: low (single example, but consistent with general lean-toward-simpler style).

### `bzero` and other mysys / non-libc idioms preferred
`07a14b717048` writes `if (g->Message[0])` — character test rather than `strlen`. `26606cefdc1f` uses `bzero((void*)&old_path, sizeof(Sql_path));`. `11210a2c0528` uses `memcpy((void*)&old_path, ..., sizeof(Sql_path));` over assignment. Standard library is avoided for these primitives.

Confidence: medium.

### Stack-allocated strings via `StringBuffer<N>` rather than `String`
- `11210a2c0528 PATH is ...` introduces `StringBuffer<MAX_FIELD_WIDTH> sql_path_str;` in `Sp_handler::db_find_routine`.
- `2c983b5ebb3a MDEV-38006 ...` keeps `StringBuffer<40> tmp;` pattern (existing); his only change is to add table/field-name parameters to `Temporal::Warn_push`.

Confidence: medium.

### Casts to fix sanitizers: change the *type*, not the operation
For UBSAN narrowing-cast / signedness diagnostics, his fix is usually to widen the local variable's type rather than insert casts.
- `0bfe10e2b797 MDEV-38087 ...`: `uint count;` → `int count;` plus replacing `!count || count > fields.elements` with `count <= 0 || count > (int)fields.elements`. Same commit replaces `'???'` placeholder error with `llstr(count, buf)` so the user sees the actual offending value.
- `32327e572bbd MDEV-39540 ...`: `uint sz;` → `size_t sz;`.
- `04e09010773c` followup: changed loop condition to `(uint)(line-start) >= width`.

Confidence: high.

### `MY_FILEPOS_ERROR` / `MY_FILE_ERROR` over hand-coded `~(my_off_t) 0`
`0fc66b6ff0d4 MDEV-35541` replaces `info->end_of_file = ~(my_off_t) 0;` (3 occurrences) with `MY_FILEPOS_ERROR` / `MY_FILE_ERROR`, then guards the arithmetic `if (eof != MY_FILE_ERROR) eof+= ...`. He prefers named sentinels.

Confidence: medium.

### `my_safe_alloca`/`my_safe_afree` to replace bare `alloca`
- `05f36e67d373 MDEV-39266 Stack Overflow via alloca() in Privilege Table JSON Parser`: drop-in replace `alloca(value_len)` with `my_safe_alloca(value_len)`, add matching `my_safe_afree(ptr, value_len)`, restructure to single-exit so the free executes.

Confidence: high (it's an in-tree idiom he applies the same way every time).

## Refactoring / cleanup habits

### Cleanup commits do exactly one thing
Each `cleanup:` commit is single-purpose. No drive-by edits. The diff stays small and reviewable.

- `1668695b55ac cleanup: use CREATE_TYPELIB_FOR` — only converts `TYPELIB x = { array_elements(a)-1, "", a, NULL, NULL };` to the macro form, nothing else.
- `292bab3565fb cleanup: Sp_caches::sp_caches_swap()` — deletes the method *and* its single caller block in `get_all_tables`, plus the surrounding explanatory comment, because the underlying race "is no longer needed" (commit body explains why).
- `387de3d5b83d cleanup: remove unused argument` — drops `THD *thd` from `Field::make_empty_rec_reset(THD*)` and all overrides.
- `35f65007b749 cleanup: change sql_command_flags from uint to cf_flags_t` — converts a `#define`-based bitmask to a strongly typed `enum cf_flags_t : uint { ... }`, deleting all the macros and the `extern uint sql_command_flags[]` declaration in one commit. Adds `operator|`/`operator|=` overloads inline.

Confidence: high.

### Cleanup bodies explicitly justify the change for debuggability or for an invariant
- `35f65007b749` body: `introduce a dedicated enum type for sql_command_flags / to simplify debugging:` (followed by a sample `(gdb) p sql_command_flags[SQLCOM_SELECT]` showing the bitfield decoded by name).
- `292bab3565fb` body: `remove the fix for MDEV-25243. It's no longer needed, because / a routine can no longer be re-parsed in the middle of a statement.`

Confidence: high.

### Delete dead code aggressively when its precondition is gone
- `1fa182723d77 do NOT prefer itself in seemingly recursive calls, follow the path` — deletes `Sql_path::resolve_recursive_routine()` entirely (header + impl + call site) because PATH should be authoritative.
- `0cac216e4f36 merge ErrConvMDQName into ErrConvDQName` — collapses a derived class into its base when the special case is buggy. Body: "and remove incorrect thd->db behavior".
- `3e9710597578 13.0 deprecations` removes whole files (`sql/des_key_file.cc`, `sql/des_key_file.h`) and all related `Create_func_des_*` classes, marks the bit in `mysql_com.h` as `/* unused (1ULL << 18) */`.

Confidence: high.

### Tighten signatures from `LEX_CSTRING` to `String *` / `system_variables &`
When the surrounding context lets him pass richer data, he changes the signature once and removes downstream re-parsing.
- `13c5cab5cf30 change Sql_path::from_text() to take a String, not LEX_CSTRING` body: `* use str->c_ptr() for the error message / * pass correct charset / * remove redundant parsing Table_triggers_list::check_n_load`.
- `22591551fb7f fix --path to work` first migrated `from_text(THD*, ...)` to `from_text(system_variables &, ...)` because plugin-style sysvars don't have a `THD`.

Confidence: medium.

### Comment changes lag the code: he deletes the obsolete comment in the same commit
`152ed78d4917 MDEV-37345` deletes a 6-line comment about merge children alongside the algorithm change that made it moot.

Confidence: medium.

## Bug-fix approach

### Fix at the assertion-site or the data-flow source, not at the symptom
For a missing flag or invalid state, he fixes the place that *fails to set* the flag, not the place that fails to handle the absence.
- `089caf901f91 MDEV-34817 perfschema.lowercase_fs_off ...`: `initialize counters when constructing a new PFS_program object` — added `pfs->m_stmt_stat.reset(); pfs->m_sp_stat.reset();` in `find_or_create_program`.
- `1c7685f5fc56 bugfix: nextval() in default, ...`: spread `Lex->default_used= TRUE;` across `sql_yacc.yy` (`DEFAULT` token rule and `update_elem` rule) and `Item_param::set_default`. Fix is at every grammar entry point.
- `1563988ae61e MDEV-37160 ...`: `initialize cn->sync_statement everywhere where cn->thread_id is`.

Confidence: high.

### Treat the bug like a recipe: list each contributing location and patch them all in one commit
When several files conspire to produce a bug, the diff hits every site. He does not split.
- `0d20ed9eae8b MDEV-35580` adds `#undef SSL_get_cipher` + `#define SSL_get_cipher(ssl) ...` in `include/ssl_compat.h` — single change at the macro layer, covers all callers.
- `1ac4aeb5d8d9 MDEV-35581` — same idiom for `SSL_get_cipher_list`.

Confidence: high.

### Bug-fixes include MTR tests in the same commit; tests live in the existing nearest-topic file
Tests are appended to an existing `.test`/`.result` file rather than a new file named after the MDEV.
- `MDEV-37315` → `mysql-test/main/xa.test` / `xa.result`.
- `MDEV-39281` → `storage/connect/mysql-test/connect/t/oem.test`.
- `MDEV-38087` → `mysql-test/main/order_by.test`.
- `MDEV-38233` → `mysql-test/main/func_set.test` (existing).
- `MDEV-38242` → tests added to `tests/mysql_client_test.c` as a new function `test_mdev_38242` registered in the `my_tests[]` array.

New `.test` files are rare and only for entirely new feature areas.

Confidence: high.

### C-tests use the `test_mdev_NNNNN` naming convention
For `tests/mysql_client_test.c`, the function name encodes the ticket: `test_mdev_38242`, `test_mdev_20516`, `test_mdev_24411`, `test_mdev_34718_bu` — body of function repeats `myheader("test_mdev_38242");`. He registers it in the `my_tests[]` array at the bottom in the same commit.

Confidence: high.

### Sanitizer-found bugs: change types/condition wording, not insert casts
- `0af24548e5e3 runtime error: inf is outside the range ...` — rewrites a division so the divisor is captured in a local of `double` type *and* the zero-check uses the same value:
  ```c
  if (double arpk= keyinfo->actual_rec_per_key(j))
    ha_rows records= (ha_rows) ((double) show_table->stat_records() / arpk);
  ```
  No `static_cast`, no suppression — the algebra changes so the UB cannot happen.
- `2746c19a9cc1 MDEV-37203 UBSAN: applying zero offset to null pointer ...` — `if (field->is_null() != field->is_null(off))` → `if (field->is_null() || field->is_null(off))`. The "differ" semantic is wrong anyway; "either is NULL" is the real predicate.
- `0fc66b6ff0d4 MDEV-35541` — see MY_FILE_ERROR note above.

Confidence: high.

### `--skip-grant-tables` paths get explicit `if (!initialized) return DB_ACLS;`
`202411326306 MDEV-38811 crash in information_schema.table_constraints when --skip-grant-tables`: just two lines at the top of `acl_get_all3`: `if (!initialized) return DB_ACLS;`. The body says: "acl_get_all3() wasn't expecting --skip-grant-tables". Pattern: small early-return.

Confidence: medium.

### Robustness preferred over upgrade-breaking validation
For corrupt or incomplete system tables, his fix relaxes the check rather than rejecting:
- `1bdaabc0c682 MDEV-35622` body: `Relaxed check, only number of columns and the PK. / Enough to avoid crashes, but doesn't break upgrades and migration from MySQL as in MDEV-37777.` Introduces a small `plugin_table_is_valid(TABLE *)` helper and calls it from every entry into the plugin table.

Confidence: medium.

### Helper extraction for "validate this thing"
When the same validation needs to happen at 2–3 entry points he extracts a one-line helper. Pattern: `static bool <topic>_is_valid(<type> *)`. See `plugin_table_is_valid` in `1bdaabc0c682`. It also raises the error inside the helper rather than at the caller.

Confidence: medium.

### Error-message correctness: include the offending value, not `???`
`0bfe10e2b797` replaces `my_error(ER_BAD_FIELD_ERROR, MYF(0), order_item->full_name(), thd_where(thd));` with `char buf[64]; my_error(..., llstr(count, buf), ...);` — the bogus index becomes part of the error string.

Confidence: medium.

### `my_message(ER_UNKNOWN_ERROR, ...)` must be guarded for empty content
`07a14b717048 MDEV-38868`: he wraps the message call with `if (g->Message[0])` and falls back to `my_error(ER_GET_ERRNO, MYF(0), rc, "CONNECT");`. Empty error strings hit a `DBUG_ASSERT(*str != '\0')` in `my_message_sql` — he fixes the asserting site, not the assert.

Confidence: medium.

### Severity reductions when the server "continues anyway"
- `2a31a0f893d8 MDEV-38802`: `sql_print_error("Can't open and lock privilege tables: %s", ...)` → `sql_print_warning(...)`. Body: "it's not an error, as the server continues anyway".
- `0db178da5ede MDEV-38124 event scheduler spams the error log`: wraps `sql_print_information(...)` calls with `if (global_system_variables.log_warnings > 2)`. Body explicitly states the new convention: startup/shutdown at `>0`, runtime notes at `>2`, abnormal one becomes `[Error]`.

Confidence: high.

## Architecture / API choices

### New helpers prefer `static` file-local, narrow signature, error-raising-inside
`1bdaabc0c682` adds `static bool plugin_table_is_valid(TABLE *table)` in `sql/sql_plugin.cc` that itself calls `my_error(ER_CANNOT_LOAD_FROM_TABLE_V2, ...)` before returning false. Callers do `if (!plugin_table_is_valid(table)) goto end2;` — no error-message duplication.

Confidence: medium.

### RAII guards for thread-local context
`11210a2c0528 PATH ...` introduces `class Sql_path_instant_set` whose ctor saves and overwrites `thd->variables.path` and dtor restores it (and zeroes the saved copy). He explicitly leaves a `TODO XXX fix Sql_path class to avoid hacks below` comment near the `memcpy`-based swap. Pattern: scope-tied save/restore via small classes whose members are private THD*+state.

Confidence: medium.

### Strongly-typed enums in place of `#define` bitfields, with overloaded operators
`35f65007b749` introduces `enum cf_flags_t : uint { CF_X = 1U << 0, ... };` plus `static inline constexpr cf_flags_t operator|(cf_flags_t a, cf_flags_t b)` and `operator|=`. Storage stays `cf_flags_t` (no implicit decay to int).

Confidence: high (singleton commit but representative of his preferred replacement pattern for legacy `#define` flag groups).

### Macros remain the right answer for cross-platform compat / vendor abstraction
He adds `#undef X` followed by `#define X(...) ...` in `include/ssl_compat.h` to translate WolfSSL APIs to look like OpenSSL — twice, in adjacent commits (`0d20ed9eae8b`, `1ac4aeb5d8d9`). He doesn't introduce a C++ wrapper.

Confidence: medium.

### Compile-time alignment: change a `#define` to a `MY_ALIGN()` expression
`26606cefdc1f MDEV-39141`: `#define HEADER_SIZE 24` → `#define HEADER_SIZE MY_ALIGN(sizeof(my_memory_header), 16)`, plus `#undef ALIGN_SIZE / #define ALIGN_SIZE(X) MY_ALIGN(X, 16)`. Adjusts a single `mtr` baseline (`type_assoc_array.sp-assoc-array-64bit prints changes in memory_used, and my_malloc() uses more memory now`) — he proactively notes the test-result delta in the commit body.

Confidence: medium.

### Adds operator overloads on values, not type-traits
Where he needs `cf_flags_t a | b` and `a |= b`, he writes free `inline constexpr` operators side by side. No `std::underlying_type_t` or constexpr metaprogramming.

Confidence: low (one example).

### `std::*` is used minimally
`std::swap(table->record[0], table->record[1]);` in `2b11a0e9918a` and `std::move(static_cast<X&&>(rhs))` in the clang20 fix are the only `std::` references in this commit set. He uses MariaDB-internal `swap_variables(T, a, b)` macro elsewhere (visible in deleted `Sp_caches::sp_caches_swap`).

Confidence: medium.

### Place fixes in the layer that "owns" the invariant, not at the caller
`288db5fa5f73 MDEV-24981 LOAD INDEX ...`: rather than special-case LOAD INDEX in InnoDB, he calls `thd->transaction->xid_state.check_has_uncommitted_xa()` at the top of `mysql_admin_table`, and *removes* `thd->transaction->xid_state.er_xaer_rmfail()` from `open_tables` (because `check_has_uncommitted_xa` itself raises the error). Body explicitly says: "Also, remove duplicate XAER_RMFAIL in open_tables(), check_has_uncommitted_xa() already issues it."

Confidence: high. Lesson: when fixing, audit *who* raises the error and keep only one site.

## Domain quirks

### ACL / privilege paths: `mysql.global_priv` is the source of truth
`04122ed770b5 MDEV-36815`: body: `rewrite the check to use mysql.global_priv (finally!)`. He resists `mysql.user`-based checks.

Confidence: low (single example, but the parenthetical "finally!" signals long-standing direction).

### SSL / WolfSSL compatibility: emulate OpenSSL via macros in `include/ssl_compat.h`
Pattern repeated across `MDEV-35580` and `MDEV-35581`. Bodies use the same form:
```
emulate OpenSSL behavior in WolfSSL:
* use IANA cipher names (TLS_ prefix, underscore) for TLSv1.3
  e.g. TLS_AES_256_GCM_SHA384
* use OpenSSL names (no previx, dash) otherwise
```

Confidence: high (for SSL work, this header is the locus).

### Stored procedure / PATH: `Sql_path` work
PATH is a focus area (multiple commits): `11210a2c0528`, `13c5cab5cf30`, `1fa182723d77`, `22591551fb7f`, `3b14490e5842`. He prefers:
- Storing identifiers unquoted (empty `Lex_ident_db{nullptr-but-length-0}` means "CURRENT_SCHEMA").
- `is_cur_schema(size_t i)` checks `!m_schemas[i].length` rather than comparing strings.
- `from_text(const system_variables &sv, String *str)` — pass sysvar context as a struct ref, accept richer string types so the function can do the charset/case-folding itself.
- Error reporting uses `str->c_ptr()` (NULL-terminated), see `13c5cab5cf30` body.

Confidence: high (for the PATH subsystem).

### XA / xid_cache_element: when in doubt, check for an active element, not just the mode
`03dd699ffefc MDEV-37315`: bug was that `if (thd->in_multi_stmt_transaction_mode())` missed the rollback-only state. Fix: `if (thd->in_multi_stmt_transaction_mode() || xid_state.xid_cache_element)`. Pattern: state-flag-OR-presence-of-cached-object.

Confidence: low (one example).

### JSON paths: `null_value` must be honored in every `val_*` override
`1839cc67a746 MDEV-39135 JSON_OBJECTAGG(NULL) in decimal context`: 2-line fix in `Item_func_json_objectagg::val_decimal` — `if (null_value) return 0;` at the top. Body: `json_objectagg didn't return NULL if null_value==true`. Same pattern likely applies to all aggregate functions overriding only `val_decimal`/`val_real` without checking `null_value`.

Confidence: low (one example).

### `mysql_audit_general` and slow-log placement: keep in `Prepared_statement::execute()`, suppress double-logging via flag
`317fb109153b MDEV-38375` body: `just like slow logging, MYSQL_AUDIT_GENERAL_STATUS / should be done inside Prepared_statement::execute()`. He adds `bool log_slow_done= false;` at top of `dispatch_command`, sets it in the `COM_STMT_EXECUTE` branches, and uses it to gate both audit and slow-log emission at the bottom. The dispatch path always has a single boolean tracking "was this already logged".

Confidence: medium.

### CONNECT (storage engine) bugs are fixed in-engine without touching server core
`04e993f0bff9`, `07a14b717048`, `2abbea88fb06` — all stay inside `storage/connect/`. He doesn't push CONNECT-specific quirks into the server core.

Confidence: medium.

### `--skip-grant-tables` / `!initialized` guards are early-return
See `202411326306 MDEV-38811`. Pattern: top-of-function `if (!initialized) return <permissive-default>;`.

Confidence: low.

### Sequence / NEXTVAL ownership lives on `TABLE::internal_tables`
- `152ed78d4917 MDEV-37345` re-routes the prelocking distance check through `table->internal_tables`.
- `2bf1d089cf8e MDEV-37906`: `if (table->triggers || table->check_constraints || table->internal_tables)` — adds sequences to the list of features that disable DELAYED.
- `18f85c8c681d MDEV-37302`: trigger prelocking only when `lock_type >= TL_FIRST_WRITE`.

Pattern: piggy-back sequence behavior on the existing "table has side effects" predicates rather than introducing a new flag.

Confidence: medium.

### Server-audit plugin: `cn->sync_statement` initialized everywhere `cn->thread_id` is
`1563988ae61e MDEV-37160`: the fix is purely "add one line in three setup functions". When a struct member must always be zeroed alongside another, he edits all sibling init sites in one commit. Body explicitly states the invariant.

Confidence: medium.

### `record[0]` vs `record[1]` swap invariant
`2b11a0e9918a MDEV-37268`: he documents (in the body) "maintain the invariant, that handler::ha_update_row() is always invoked as handler::ha_update_row(record[0], record[1])". Fix wraps the update with `table->move_fields(...); std::swap(record[0], record[1]); ... move back; swap back`. The pattern: preserve invariant via paired before/after operations rather than per-call adjustments.

Confidence: medium.

### `rnd_init()` / `rnd_end()` must pair around `rnd_pos()`
`3a2e1f87a1fa MDEV-37268`: body: `don't forget to rnd_init()/rnd_end() around rnd_pos()`. Restructured `if/else` blocks so `rnd_end()` is always called even on error.

Confidence: low.

## Maintenance branch handling

### Forward-merge cadence
All 7 merges in this window are forward-merges along the release chain, with empty bodies (or near-empty — `zlib 1.3.2` is the exception, repackaged as a merge subject).
- `Merge branch '10.6' into 10.11` (`053f9bcb5b14`)
- `Merge branch '10.11' into 11.4` × 3 (`054a893f1645`, `1093a2f3b8a4`, `40f708466147`)
- `Merge branch '11.8' into 12.2` (`27c98794bbf5`)
- `Merge branch '12.2' into 12.3` (`366de0ae3bb5`)
- `3730b92be0d2 zlib 1.3.2` — used as a merge commit subject, body is just `zlib 1.3.2`.

Confidence: high.

### Bug fixes target the oldest still-maintained branch where the bug exists, then merge up
Visible from the file paths he edits in MDEV commits vs which branches the surrounding merges traverse. Several "MDEV-N (X.Y version)" subjects appear explicitly: `152ed78d4917 MDEV-37345 sequences and prelocking (11.4 version)` — the parenthetical signals "this is the per-branch backport".

Confidence: medium.

### Followup commits land on the branch where the predecessor went, addressed by 12-char SHA
- `12578d8a69c9 MDEV-38604 fix SP execution too` (empty body) — fixes the same area as a prior commit on the same branch.
- `1563988ae61e MDEV-37160 ... followup for ef3c843c172 and 7251cbca518` — references its predecessors by sha.
- `2b11a0e9918a` and `3a2e1f87a1fa` are both followups for `9703c90712f3 (MDEV-37199 UNIQUE KEY USING HASH ...)`.

Confidence: high.

### Warning vocabulary is branch-aware: cannot add new warnings in maintenance releases
`399edc7c6205 MDEV-37784 fix the warning` body: `cannot add new warnings in 11.8 anymore: / * remove ER_WARN_DEFAULT_SYNTAX / * use ER_VARIABLE_IGNORED instead / * change the wording in it to be more generic`. Operational rule: in released branches he prefers re-purposing an existing error code over adding a new one.

Confidence: high.

### Test-result baselines updated as their own commit
`07331813d8d6 MDEV-27277 update test results` and `33f436b689a0 MDEV-15327 fix test results` are dedicated commits whose only job is to refresh `.result` files after a behavior or wording change landed earlier.

Confidence: medium.

## Singletons worth noting

- `2c983b5ebb3a MDEV-38006 Inconsistent behaviors when casting into time` rewrites `number_to_time_only` to validate-then-cap rather than cap-then-validate. The body articulates the conceptual fix in prose: `number-to-time conversion was too eagerly capping the value. / A string "9000090" was invalid time, because of 90 seconds. / But number-to-time was capping first, validating later`. Pattern: prefer validate-first when fixing similar "lenient parser" bugs.

- `2dcd3cefe1f5 MDEV-38374 nonsense code in wsrep_store_key_val_for_row()` is a classic "the memcpy is in the wrong scope" copy-paste fix; body: `fix copy-paste error. See the code for MYSQL_TYPE_VARCHAR`. He's terse and points at the working analogous block rather than re-explaining.

- `3b7e35a3fab0 MDEV-38283 Incorrect results for NULLIF function` narrows a long-standing optimizer hack. Body: `narrow a historical hack in convert_const_compared_to_int_field() to apply only to bigint-vs-string comparison as it was supposed to`. He restricts the predicate (`args[!field]->cmp_type() == STRING_RESULT &&`) rather than removing the hack — minimal patch.

- `3dc0cef21887 MDEV-35184 Federated + vector key`: in `handler::create`, raises `ER_ILLEGAL_HA_CREATE_OPTION` with the engine and option names as separate `%s` arguments — `my_error(ER_ILLEGAL_HA_CREATE_OPTION, MYF(0), "FEDERATEDX", "VECTOR")`. Idiomatic message format for "engine X does not support feature Y".

- `2bbfcb187602 MDEV-39408 mbstream insufficient path validation`: the path check is a flat `if (*path == '.' || *path == '/' || strstr(path, "/../"))` — terse, no abstraction. Note he places the check at the very top of `file_entry_new` before any allocation.

- `06bf8304f08f Revert "check_digest() tests"` body: `This reverts commit 485773adce55ed3dcae3d20028a218f2f694775d. / We need at least one test that actually shows P_S digests`. Pattern: when reverting, restate the reason in one sentence after the boilerplate.

- `2a722fcfc941 MDEV-37554 MariaDB auth protocol differs from MySQL`: deletes a 13-line "we cannot allow plugin data packet to start from 0, 255 or 254 ..." comment-and-special-case block, replacing it with a single `net_write_command(... 1, ...)` call commented `/* plugin data, prefixed with 1 */`. Bias: a single-byte prefix beats a runtime-escape special-case.

- `26c8bc935728 mtr: make wait_for_line_count_in_file.inc leave traces in the log` — when an `.inc` file's behavior changes, he updates only that file (not the suites that consume it). Single-purpose mtr cleanup.

- `144dead8826f (clang20) error: moving a temporary object prevents copy elision` — fix is to *drop* `std::move()` around a temporary because the temporary was already an rvalue. Mental model: in modern C++, fewer moves is better; trust copy/move elision.
