# InnoDB-Specific Rules

InnoDB (`storage/innobase/*`) has its own coding subculture, enforced primarily by **Marko Mäkelä (`dr-m`)** and **Thirunarayanan**. Their reviews account for over 700 comments in the window — the highest of any maintainers. If you're touching InnoDB, read this whole file.

## The InnoDB style sub-dialect

InnoDB diverges from server-wide style in a few ways that get caught on every PR:

| Rule | What/why | Evidence |
|---|---|---|
| **TAB inside legacy files; spaces in new files.** | Legacy InnoDB sources use TAB indentation with mandatory braces. New files use spaces. **Never mix in the same hunk.** | PR4036, PR4446, PR4905, PR4914 — dr-m: "Please do not use TAB in new code", "This is mixing TAB and space indentation", "This function is supposed to be formatted without any TAB." |
| **K&R `switch`**: opening brace on same line as `switch (...)`, `case` aligned with `switch`, no extra braces inside case bodies *unless* declaring locals. | InnoDB convention. | PR4036 dr-m: "no line break here", "No variables are being declared within the `switch` statement body. Please discard the superfluous `{` and `}`." |
| **Mandatory braces around single-statement `if/else`** *in legacy files*. | InnoDB style. | PR4446 dr-m on `trx0undo.cc:1031`. |
| **Space before `=`** in legacy InnoDB; **no space before `=`** in new code (server-wide style). | Read what the file already does. | PR4446 dr-m: "[InnoDB style] there is supposed to be a space before `=`." Contrast PR4914: "no space before any assignment operators." |
| **Pointer style is `TYPE *var`**, asterisk binds to variable. | Server-wide; called out in InnoDB too. | PR4914 dr-m on `row0mysql.h`: "`TABLE*` should be written as `TABLE *`." |
| **`noexcept` on every new non-throwing C++ member function.** | Lets the compiler skip exception cleanup. | PR4036 dr-m (×4), PR4884 dr-m (×2), PR4914 dr-m (×2). |
| **No `std::string` in InnoDB.** | Heap fragmentation cost. Use `my_printf_error` / `%.*s` / fixed-size buffers / `st_::span<const char>`. | PR4342 dr-m (×3+). |
| **No `_t` / `ulint`-style aliases in new code.** | Reverses the MDEV-25861 cleanup direction. | PR4884 dr-m: "Let's not make the MDEV-25861 situation worse by adding even more declarations ending in `_t`." |
| **`size_t` / `uint32_t` / `size_t` over `ulint`/`ulong`.** | Portability + clarity. | PR4884, PR4913. |
| **`int(len)` / `unsigned(x)` over `static_cast<int>(len)` and C-style casts.** | Shorter, idiomatic. | PR4717, PR4783, PR4884, PR4913. |
| **Doxygen sub-style.** No `[in]`/`[out]` markers. Use `@retval` for literal returns. Don't repeat data-type names in `@param`. | dr-m's enforced convention. | PR4884, PR4914. |
| **Drop redundant `inline`.** | The keyword is only needed when separating declaration and definition. | PR4717 (×2). |
| **Make file-local helpers `static`.** | Avoid symbol leakage. | PR4342, PR4455. |
| **`static_assert` to document magic numbers** that participate in bit math. | Catches silent renumbering. | PR4717 (×2), PR4824. |
| **Doxygen comments on new data members and public types.** | Maintenance + auto-doc. | PR4036 dr-m: "The data members are missing Doxygen comments." |
| **Minimum-width bitfields for column/field numbers** (≤10 bits). | Memory pressure. | PR4036 dr-m: "InnoDB column or field numbers should fit in 10 bits." |
| **Use existing helpers** rather than duplicating `page_align()` / `page_offsets()` calls. | DRY; reduces per-call overhead. | PR4036 dr-m (×3). |

## Performance discipline

InnoDB hot paths get cycle-level scrutiny. The recurring themes:

- **No heap allocation under hot latches.** `log_sys.latch.wr_lock()` in particular.
  - PR4405 Thirunarayanan: "`get_archive_path()`, `get_next_archive_path()` are being called(allocates heap memory) under `latch.wr_lock()`. Cache the pre-computed next_archive_path in a member variable, populated after each file transition. With small archive files, file transition could be frequent."
- **AMD64 SysV ABI: at most 6 scalar parameters in registers.** Signatures of 7+ scalars cause register shuffling. Pass references / spans / structs to compress the parameter count.
  - PR4746 dr-m: "The parameters will not fit in the 6 registers that are available in the commonly used AMD64 calling conventions... I would make `mtr, undo_block` the first parameters so that no registers have to be shuffled."
  - PR4746 dr-m: "Please check the generated AMD64 code for `CMAKE_BUILD_TYPE=RelWithDebInfo`."
  - PR4887 dr-m: "On AMD64, at most 6 scalar parameters can be passed in registers. I would suggest to replace the second parameter with `const dict_index_t&` so that we will not exceed this limit."
- **Hoist heap allocations out of loops.**
  - PR4036 dr-m on `fts0fts.cc:6215`: "This is allocating `offsets` on each loop iteration from `m_heap`, without even trying to reuse previously allocated `offsets`."
  - PR4036 dr-m on `fts0fts.cc:6187`: "Can we allocate this from the stack? We should know the number of key columns in those tables, right?"
- **Cache repeatedly-read bit-fields in a local.**
  - PR4717 dr-m: "`m_prebuilt->table->skip_alter_undo` is a bit-field. Because we are reading it multiple times in this code path, it would make sense to assign the value to a local variable during the first access."
- **Bitwise `|`/`&` over `||`/`&&`** for pure bit tests in hot paths to avoid conditional branches.
  - PR4717 dr-m: "Instead of using short-circuit evaluation, we could use bitwise arithmetics and therefore avoid introducing a conditional jump."
  - PR4858 dr-m: "`if (v_cols[num_v].m_col.ord_part | old_v_cols[num_v].m_col.ord_part)` // bitwise | to avoid conditional branch."
- **Cold paths get `ATTRIBUTE_COLD ATTRIBUTE_NOINLINE`** and are split out of the hot inline body.
  - PR4342 dr-m: "I'd suggest to reduce the amount of inlined code, with something like this... The `ATTRIBUTE_COLD ATTRIBUTE_NOINLINE` function `wsrep_applier_log_fk()` would contain the rest of the logic."
- **Avoid expensive helpers in per-record paths** — `_current_thd()`, `std::unordered_map::find` etc. Cache once.
  - PR4914 dr-m: "This is repeatedly invoking the expensive function `_current_thd()` in a low-level operation. Do we need it for anything else than silencing a debug assertion?"
  - PR4914 dr-m: "Do we really need an `std::unordered_map` lookup when processing each record for each virtual index, or could we cache this information in `purge_node_t::maria_table`?"
- **`std::unordered_map::emplace()` over `operator[]` + assign** when inserting new keys.
  - PR4914 dr-m: "The `std::unordered_map::emplace()` should be more efficient than having `operator[]()` default-construct an element that is subsequently edited."
- **Don't use `std::function` for purely internal callbacks.** Prefer typed callable templates or lambdas inlined at the call site.
  - PR4884 dr-m: "What is the comparison good for? When would that condition hold? All callers to this function should be located in the same compilation unit, and all of them are passing an anonymous function object."

## Asserts

- **Use `ut_ad()` to document invariants** the code depends on, even when they currently hold.
  - PR4036 dr-m: "Please add debug assertions that document some constraints. Is `index` expected to be the only index of the table?"
  - PR4036 dr-m: "Shouldn't we assert that there only is one index in the table? Otherwise this function would corrupt any secondary indexes."
  - PR4405 Thirunarayanan: "Add an assert `ut_ad(size > 0);`."
- **Move assertions to function entry.** Don't bury them inside conditional paths.
  - PR4036 dr-m on `fts0config.cc:57`: "Can the assertion be moved to the start of the function, like they were before this refactoring? Here it is inside a conditional execution path."
- **Don't over-assert.** Multiple PR4405 reviews showed `ut_ad`/`ut_a` that were too strict and fired on legitimate states. The fix is usually to relax the predicate (e.g. `!archive || end == START_OFFSET`).

## Redo log discipline (mtr_t / log_t / log_sys)

This is the highest-stakes area in InnoDB. PR4405 (`innodb_log_archive`) had ~125 comments, almost entirely about subtle invariants.

- **Only `buf_flush_page_cleaner()` invokes `log_checkpoint()` / `log_checkpoint_low()`.**
  - PR4747 dr-m.
- **Exactly one trailing `FILE_CHECKPOINT` is written on shutdown.** Recovery parses no more than that.
  - PR4747 dr-m: "This assertion is part of the shutdown. It tries to ensure that the checkpoint runs to completion, that is, recovery will parse nothing more than a single `FILE_CHECKPOINT` record."
- **Maintain `innodb_log_buffer_size <= innodb_log_file_size`** at all transition points.
  - PR4405 dr-m: "The constraint `log_sys.file_size < log_sys.buf_size` is supposed to hold. This is being violated when `recv_sys_t::find_checkpoint()` is attaching an archive log file whose size is half the buffer size." Pattern: enforce in `innodb_log_file_size_update()` *and* in archive attach.
- **Don't drop assignments to `log_sys.buf_size` during refactor.** Preserve invariants like `buf_size == capacity()` or rewrite the loop to call `capacity()`.
  - PR4405 dr-m: "we should have either preserved the assignments to `buf_size` and assertions `buf_size == capacity()`, or replaced the `buf_size` in the `while` expression with `capacity()`. This inconsistency is what caused hangs during `SET GLOBAL innodb_log_file_size`."
- **`mtr_t::log_file_op()` is *not* directly callable** — go through `mtr_t::name_write()` or one of the other high-level wrappers. Breaks debug builds otherwise.
  - PR5018 dr-m: "This causes a compilation failure on many debug builders, because the low-level member function `mtr_t::log_file_op()` is not intended to be invoked directly, but only via other functions, such as `mtr_t::name_write()`."

## Dict / metadata

- **`dict_sys` latch only for the SQL parser invocation**, not across the entire transaction commit.
  - PR4884 dr-m: "I think that we only need to lock `dict_sys` for invoking the SQL parser. There is no need to hold the latch across the transaction commit. What we are really missing here is a call to `lock_sys_tables(trx)` after the creation of the transaction."
- **Drop helpers belong in `dict/drop.cc`**, not exported from `fsp0fsp.cc`.
  - PR4884 dr-m: "This function as well as `delete_from_sys_table_entries()` would seem to logically belong to the compilation unit `dict/drop.cc`."
- **Distinguish purge worker vs SQL threads when invalidating shared dict caches** (`dict_table_t::vc_templ`).
  - PR4914 dr-m: "We are potentially invalidating the cache for a user of an SQL thread that meanwhile used this `dict_table_t::vc_templ` cache. Do we actually need this cache invalidation?"
  - PR4914 dr-m: "Are we missing the following? `ut_ad(thd_get_query_id(thd) == 0);`."
- **Order of `DELETE` from system tables matters.** Delete from `SYS_FIELDS` before `SYS_INDEXES`, etc.
  - PR4884.
- **Don't call `dict_table_close(-1)`** — unreachable in tests, but unsafe.
  - PR4914.

## On-disk / page format

- **Don't claim a downgrade path that hasn't been tested.** Don't add ad-hoc compat checks "just in case".
  - PR4342 dr-m: "This is not what I requested earlier. We must not create an impression that a downgrade would work if it has not been tested. The check for `'\377'` must not be added."
- **Preserve serialised field ordering.** `std::unordered_map` is wrong for anything written to disk or the wire.
  - PR4430 — applies project-wide, not just InnoDB.
- **`mi_uintNkorr` (big-endian, MyISAM) vs `uintNkorr` (little-endian).** Don't cross-reference.
  - PR4783, PR4797.
- **Bison/Flex generated files** in `storage/innobase/fts/*lex.cc` — edit the source `.l`/`.y` and rerun, mention the Bison version in the commit message.
  - PR4293 dr-m.

## Headers / API design in InnoDB

- **Prefer `st_::span<const char>`** to `(ptr, len)` pairs for new APIs — single parameter, type-safe.
  - PR4884 dr-m (×2).
- **Encode richer return values in `dberr_t`** (e.g. `DB_SUCCESS_LOCKED_REC`) rather than threading out-parameters.
  - PR4884 dr-m (×3).
- **Make functions return error codes** instead of `bool + out-pointer`.
  - PR4036 dr-m: "Could we make the function return an error code? That would allow simpler execution: `if (dberr_t err= sqlRunner.open_table(fts_table, &table)) return err;`."
- **Use C++ functor objects / lambdas** instead of `void *arg + callback ptr` C-style callbacks. Type safety.
  - PR4036 dr-m: "The C++ way would be to pass a functor object that would also be compatible with a lambda expression."
- **Modernise InnoDB containers cautiously.** `std::map` / `std::vector` are acceptable outside hot paths; `std::function` / `std::unordered_map` need justification.
  - PR4036 dr-m: "Can we use `std::map` and `std::vector` instead of the homebrew containers?"

## Logging discipline

- **`sql_print_error` / `sql_print_information` in new code.** Avoid `ib::logger` / `ib::info` / `puts()`.
  - PR4036 dr-m (×2).
- **Include the identifier in every user-visible message** (table name, constraint name) — via `ut_get_name()` or `dict_table_open_failed()` for charset conversion.
  - PR4342 dr-m (×3+).
- **No absolute paths in messages.** Non-portable and informationally noisy.
  - PR4342 dr-m.
- **No `err: err:` duplication** — cover each message in a test.
  - PR4342 dr-m (×2).
- **SQL syntax in messages** for clarity across locales:
  - PR4884 dr-m: "`sql_print_information(\"InnoDB: DROP TABLE %.*s\", int(len), rec);` I think that using the SQL syntax should make it clear even for DBAs who do not speak English."

## Cold-path / warning logic

- **Don't flood the error log in production builds.** `DB_LOCK_WAIT` is normal in the applier — warn only in debug.
  - PR4342 janlindstrom: "`DB_LOCK_WAIT` is normal behavior even in applier, it would flood error log if this warning is enabled in release builds."
  - PR4342 dr-m: "Why does the logic differ between `CMAKE_BUILD_TYPE=Debug` and `CMAKE_BUILD_TYPE=RelWithDebInfo`?"

## Galera / WSREP

- **`DBUG_EXECUTE_IF` to test error/edge paths** when natural reproduction is impossible.
  - PR4342 dr-m: "Would a Galera specific `DBUG_EXECUTE_IF` in `row_mysql_handle_errors()` serve a similar purpose?"

## 32-bit pitfalls

- **`SHOW GLOBAL STATUS` ulonglong on IA-32 = torn read** unless routed via `export_vars`.
  - PR4405 Thirunarayanan / dr-m.
- **Tagged-pointer masks**: use `~uintptr_t{1}`, not `~1ULL`, so 32-bit builds work.
  - PR4914 `row0purge.h`.

## Memory management for the buffer pool

- **`PROT_NONE` reserve + commit pair** — pair every reserve with the symmetric commit on the extend path.
  - PR4740 dr-m: "The logical place for this call would be right after the call of `my_virtual_mem_commit()`. I think that we need a similar call when extending the buffer pool."
- **`std::max` vs `std::min` on 8 TiB reservation attempts**: get this right and suppress the failure-noise on the initial `PROT_NONE` attempt.
  - PR4852 dr-m.

## Read-only / shutdown discipline

- **Read-only transactions must not enter group-commit.**
  - PR4591 vaintroub.
- **Internal QA RQG-driven assertion failures** are posted as line comments on PR4405; the response pattern is `commit-hash that resolved it` within days. Expect this on any InnoDB change of substance.

## Removing `*.inl` files

- **dr-m's modernization push**: write the inline functions directly in headers, eliminate `.inl` files.
  - PR4797 dr-m: "While doing this, can we remove all the InnoDB uglification and write the code directly in `mach0data.h` as follows, for all these functions."
  - dr-m has been pushing this for years; opinions on micro-optimisation differ between dr-m and vaintroub. **Bring Godbolt evidence to micro-optimisation suggestions.**

## InnoDB testing conventions

- **`include/search_pattern_in_file.inc` for log-message tests.** Suppression alone is not coverage.
  - PR4342 dr-m: "How can we be sure that the test produces such warnings if we are not checking that the messages are actually being emitted, by using `search_pattern_in_file.inc`?"
- **`include/kill_and_restart_mysqld.inc`, `innodb_max_purge_lag_wait`** — use these helpers instead of hand-rolled session-counting + restart sequences.
  - PR4446 dr-m.
- **`mtr.add_suppression()` patterns must remain specific**, not broadened to "any error".
  - PR4342 dr-m: "Why is the `mtr.add_suppression()` less specific? Do we really want to ignore any errors that could be issued for other table or constraint names?"
- **Test must exercise the new error messages** with the specific table/constraint names, not just check status lines.
  - PR4884 dr-m: "Could we also look for the specific names of the garbage tables here? We could be outputting some garbage, and the test would not catch that. Can we also check the contents of `INFORMATION_SCHEMA.INNODB_SYS_TABLES`?"
- **`WITH_INNODB_EXTRA_DEBUG=ON`** is one of the internal combos that must keep building. dr-m's own combo: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_INNODB_EXTRA_DEBUG=ON -DPLUGIN_PERFSCHEMA=NO` is `rr record`-friendly.

## When in doubt

dr-m's reviews are very specific about *what* is wrong but also about *how to verify*. When you receive a comment about generated code or a hot path, his standing expectation is:

1. Look at the generated assembly under `RelWithDebInfo` (or post a Godbolt link).
2. If the change is to a calling convention or wire format, run the existing replication / Galera test suites against your branch.
3. Cite specific MDEV numbers when claiming a constraint is "already" handled — he will check.
