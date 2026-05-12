# Correctness & Security

Patterns that catch real bugs. Sanitizers (ASAN/UBSAN/MSAN) run in CI and reviewers expect you to chase down every failure they produce.

## Buffer / length validation

This is the single most common bug class flagged in the window.

- **Validate input lengths against the actual remaining buffer**, not against magic constants.
  - PR4884 dr-m on `srv0start.cc`: "The `if` expression is missing `id_len != 8 ||`." (the patch read 8 bytes from a field that wasn't necessarily 8 bytes long).
  - PR4884 dr-m on `fsp0fsp.cc`: "We can enforce a stricter length limit: `if (len == 0 || len > srv_page_size - (rec - btr_pcur_get_page(&pcur))) goto corrupt;`."
  - PR4534 vuvova on `sql_acl.cc:13631`: "may be `if (len > end - passwd)` ?"
- **Never assume input is NUL-terminated**, especially InnoDB record bytes and wire packets.
  - PR4884 dr-m: "The output is wrongly assuming a NUL terminated input string. If `DB_TRX_ID` on the record is at least `1<<40`, some trailing garbage could be displayed." → use `%.*s` with `int(len)`.
  - PR4342 dr-m: "`end` may post one `char` past the end of `db_table`. If that is the case, this assignment would constitute a buffer overflow." Pattern: prefer `%.*s` with explicit length over building a NUL-terminated copy.
- **Pass the actual buffer size as a parameter** when migrating `sprintf`→`snprintf`. Hard-coding the constant at the call site is the AI/automation anti-pattern that PR4869 exists to undo.
  - PR4869 gkodinov: "That's not how you do this! It's about the size of the receiving buffer."
  - PR4869 gkodinov: "I'd take the size as a parameter to `MYSQL[_BIN]_LOG::generate_new_name`."
  - PR4869 gkodinov: "I'd add it as a parameter instead. Right now it's not preventing anything and if I pass a smaller buffer I'd just get a crash."
  - PR4869 gkodinov: "Please add a parameter and use it: there's just 3 calls to this. And 2 of these 3 calls are off by one :)"
  - PR4869 gkodinov: "Unfortunately, it's not as simple as letting some AI do it. You will need to find the actual size of the buffer and then set that as a limit."
  - PR4824 dr-m: "What happens if more than `BINLOG_NAME_MAX_LEN` characters of input is available? Would the `filename` be terminated by `\0`?"
- **Use `snprintf(buf, sizeof(buf), ...)` not `snprintf(buf, MAGIC, ...)`** when the buffer is local.
  - PR4455 grooverdan on `mysql.cc:4564`: "use a `snprintf(sizeof(buff),...`."
  - PR4455 grooverdan on `mysql.cc:4565`: "Use a modifier on `%s` to restrict the message to the right most portion of the `source_name`. Adjust buffer size accordingly."
- **UDF input is untrusted.**
  - PR4966 `udf_example.c`: replaced unbounded `strcpy`+`strlen` with bounded `memcpy` capped at `initid->max_length` and explicit NUL termination. Also raised `max_length` to `HOST_NAME_MAX=255` (POSIX) or IPv4-dotted-quad.
- **PROXY-protocol v1 header parsing**: max header length is 107 bytes; size for full header + NUL.
  - PR4881 — fixes for off-by-one and CR/LF handling in the v1 parser. PR4889 — line-length DBUG_ASSERT vs returning an error.

## Format specifiers

- **Match the type:** `%llu` / `%lld` for `unsigned long long` / `long long`, `%zu` for `size_t`, `%.*s` (with `int(len)`) for explicit-length strings. Drop redundant casts when migrating.
  - PR4869 gkodinov: "since you are touching on this line, please use %llu and remove the casts." (twice).
- **`%iE` (13.0+) or `%M` (10.11)** for `errno` — don't hand-enumerate `EACCES`/`EMFILE`/`ENOMEM`.
  - PR4874 vuvova: "Remove the `EACESS` if(), and in the second use `%iE` (or `%M`)."
  - PR4874 vuvova: "I'd use just `sql_print_error(\"Cannot create a socket: %iE. Aborting\", errno);` note it's `%iE` in 13.0 but `%M` in 10.11."
- **`fprintf(\"%s\", str)` is forbidden — use `fwrite`** or the project's IO abstraction.
  - PR4605 gkodinov on `backup_copy.cc:1940`: "fprintf(\"%s\", ...) is a less performant equivalent to fwrite(). NEVER use that."

## Sequencing / short-circuit

- **Don't use `|` or `&` to chain error-returning function calls.** They don't short-circuit and have unspecified evaluation order.
  - PR4441 bnestere on `sql/sql_yacc.yy:2289`: "I don't think the compiler guarantees the order-of-operations with bitwise OR (i.e., the three functions involved here may run in any order, which is not what you intend, I think). I think this would be better served by `&&`s, also because the `&&`'s short-circuit if there's an error in an earlier."
- *Exception in InnoDB hot paths*: `|` over `||` is sometimes preferred to avoid a conditional branch — but only for pure bit-tests on flags, never for calls that may fail.
  - PR4717 dr-m: "Instead of using short-circuit evaluation, we could use bitwise arithmetics and therefore avoid introducing a conditional jump."
  - PR4858 dr-m: "`if (v_cols[num_v].m_col.ord_part | old_v_cols[num_v].m_col.ord_part) // bitwise | to avoid conditional branch`."

## NULL handling

- **Distinguish "no value" from "empty value"**. Returning NULL when the answer is "empty list" is wrong; return empty string.
  - PR4618 vuvova on `sql_show.cc:6663`: "NULL generally means that there can be no create options... the list is simply empty, I'd expect an empty string here, not NULL."
- **Don't silently substitute NULL with a default**; reject it.
  - PR4606 gkodinov on `ha_mroonga.cpp:941`: "I do not quite like the silent substitution of NULL with 'off'. IMHO, if you don't want NULLs as arguments, then reject these."
- **Don't `set_notnull()` on a column whose schema already disallows NULL** — redundant noise.
  - PR4618 vuvova: "It seems you forgot to remove `table->field[17]->set_notnull();` ... if it's not [nullable], you don't need to set it to not null, it's already and always not null."

## Lifetime / ownership

- **Don't share a pointer into a buffer that may be freed** — copy the data into your own storage.
  - PR4883 `Item_func_trim`: `String::set()` shared a buffer that subsequent TRIM calls invalidated. Fix: `String::copy(ptr+offset, length, charset)`. The PR title became "MDEV-32758: TRIM uses memory after freed."
- **Don't reuse an already-allocated heap pointer** for a new allocation — document who owns what and when it's freed.
  - PR4036 dr-m on `fts0opt.cc:473`: "We seem to be assigning `fetch->heap` to something that is allocated from our local stack. Where do we reset `fetch->heap` before returning from this function? We surely wouldn't want to leave a dangling pointer."
- **Don't define a default constructor silently.** Use `= delete` if not needed — otherwise the destructor may run on uninitialised state.
  - PR4036 dr-m on `fts0priv.h:587`: "What do we need a default constructor for? Could we use `= delete;` for that? The destructor would seem to crash when invoking `mem_heap_free(nullptr)` on a default-constructed object."
- **Clean up on every error path.** `goto end` style is acceptable; but every `goto` must walk through every `delete`/`free`.
  - PR4047 hemantdangi-gc on `log_event_server.cc:5698`: "allocated assembler is not getting deleted." ParadoxV5: "We use C++ extensively, but use a lot more `goto end`s than RAII."
- **`my_hash_init()` needs a `my_free` callback** if you `my_malloc` into the hash.
  - PR4332: `sql/item_jsonfunc.cc` MSAN/LSAN leak from missing `my_free` in `my_hash_init`. Reproducer ran via `amd64-ubsan-clang-20`.
- **`-1` smuggled into an unsigned slot** to mean "unchanged" is fragile. Declare the field signed if the sentinel must exist; otherwise carry the sentinel in a separate bool.
  - PR4430 ParadoxV5: "This is unsigned in practice. It was signed *only* because the parser uses `-1` to represent 'unchanged'."

## Sanitizer-driven failures (MSAN / UBSAN / ASAN)

- **MSAN: uninitialised reads.** Initialise output parameters before every `return` in the error paths.
  - PR4764 gkodinov: "I believe you need to assign something to *var here. Otherwise msan complains."
- **MSAN: `MEM_UNDEFINED(...)`** on stack-allocated structs lets MSAN catch use-before-init in *debug* builds. Use it in MTR setup paths.
  - PR4433 grooverdan: "`MEM_UNDEFINED(&lex->parser_state, sizeof(lex->parser_state));` so MSAN builders can catch what's trying to access it rather than Debug having a working build for unknown reasons."
- **UBSAN: function-pointer signature mismatch.** Don't cast a function pointer through the wrong signature to silence a compiler — fix the actual signature.
  - PR4449 dr-m on `server_audit.cc:2337`: the cast triggered `function-type-mismatch` UBSAN. The fix is the underlying API.
- **UBSAN: unaligned access.** Use a `memcpy()`-based load/store for arbitrary-width fields; the compiler will fold to a single load on aligned platforms. But measure on Godbolt before claiming generality — PR4783 had a long dr-m / vaintroub debate where `memcpy` of odd lengths sometimes generated worse code than the explicit byte-by-byte version. **Micro-optimisation suggestions require Godbolt evidence.**
  - PR4783 dr-m: "I think that this had better be based on `memcpy()`, along these lines... `memcpy(&ret, p, 5);`."
  - PR4783 vaintroub: "Nope, memcpy with odd length is not better at all... here is the proof https://godbolt.org/z/77T7rE1zM."
- **ASAN: stack-overflow guards** for recursive descent.
  - PR4332 RuchaDeodhar on `sql/item_jsonfunc.cc:6356`: "Just add a out of stack space check, there are examples in this files."

## Concurrency

- **Don't read a pointer-to-string sysvar without a lock.** The pointer can be swapped between read and dereference.
  - PR4633 gkodinov on `server_audit.cc:273`: "This is not a thread safe access to a global variable of type string pointer and the data it points to! While doing it this way is fine for simple types (up to a native CPU word aligned: 2 or 4 usually). It's definitely not ok to do unsynchronized reads on..." Pattern: take rw-lock, copy into thread-local buffer, release.
- **32-bit torn reads on `ulonglong` `SHOW STATUS` variables.** `get_one_variable()` reads memory directly; `Atomic_relaxed<>` isn't sufficient because `SHOW_ULONGLONG` doesn't go through the atomic load. Use `export_vars` indirection.
  - PR4405 Thirunarayanan on `log0log.h:289`: "SHOW GLOBAL STATUS access this variable without any mutex. Won't have torn read in case of 32 bit platform?"
  - PR4405 dr-m: agreed; suggested `trx_t::max_inactive_id_atomic` trick.
- **Heap allocation under hot locks** is a perf bug.
  - PR4405 Thirunarayanan: "`get_archive_path()`, `get_next_archive_path()` are being called (allocates heap memory) under `latch.wr_lock()`. Cache the pre-computed next_archive_path in a member variable, populated after each file transition."
- **`recv() == 0` means peer closed the socket** — it is **not** a retry condition.
  - PR4881 vaintroub correcting gkodinov: "0 is returned from recv if and only if peer closes socket normally (FIN, not RESET)... this is wrong. 0 is an error condition."
- **Read-only transactions must not enter group-commit logic.**
  - PR4591 vaintroub requested an `ut_ad` assertion in `trx_flush_log_if_needed()` for this invariant.

## Charset / collation

- **InnoDB identifier display needs charset conversion.** Raw `my_charset_filename` bytes are not UTF-8; convert to `system_charset_info` before printing.
  - PR4342 dr-m: "we are aware of a more efficient way of displaying InnoDB table names... a conversion from `my_charset_filename` to `system_charset_info` (UTF-8). A test case for this must in..."
- **Charset-aware comparisons for index names**, not `strcmp` (or use a `cmp` helper).
  - PR4906: discussion about comparing using `my_charset_utf8_bin` vs a `cmp` helper.

## Numerical pitfalls

- **Canonicalise negative zero on float output paths** and comment that you're doing it.
  - PR4632 vuvova: "may be with a comment? Like `if (nr == 0.0) nr= 0.0; // correct negative zero` otherwise looks very confusing."
- **`HUGE_VAL` is not infinity** — it's an overflow indicator. Use `std::numeric_limits<double>::infinity()`.
  - PR4731 — explicit reviewer note.
- **NaN is not a valid JSON number** — the writer should reject or emit a sentinel, not produce `NaN`.
  - PR4731 — explicit reviewer note.
- **`my_time_t` was signed before MDEV-32188 (11.5.1)** — Y2038/Y2106 timestamp clamping in replication must validate across primary versions.
  - PR4933 bnestere.

## Endianness

- **Wire-format reads must use little-endian helpers** (`my_letoh16`, `uintNkorr`); don't sprinkle `MY_BSWAP32` on a LE branch.
  - PR4783 dr-m: "I believe that the line `lo= MY_BSWAP32(lo);` needs to be removed from this little-endian code path, because in `include/byte_order_generic_x86_64.h` there was no equivalent."
  - PR4783 dr-m: "There is a semantic mistake in all these functions. We are converting from little endian to host byte order, not vice versa. Hence, the invocation should be `return my_letoh16(ret)`."
- **`mi_uintNkorr` is big-endian, `uintNkorr` is little-endian.** Don't substitute — `.MYD` files depend on it.
  - PR4783 vaintroub: "`mi_uint5korr` is not a corresponding function for `uint5korr`. `mi_*` is big endian."
  - PR4797 vaintroub: "`uint2korr` has an unfortunate naming only descriptive to its creator... 'korrekt' in Innodb sense is big endian, also accepting/returning ulints."

## Plugins and sysvars

- **Validity checks belong in the `check` sysvar callback**, never `update`.
  - PR4633 vuvova on `server_audit.cc:2361`: "validity checks must be done in the `check` callback, not in the `update` callback."
- **Don't have the `update` callback re-write the sysvar's own storage** — the server already assigns it for you.
  - PR4633 vuvova on `server_audit.cc:2372`.
- **Plugins must use server services**, not libc directly. Time formatting via `thd_gmt_sec_to_TIME` / `thd_TIME_to_str` so the time-zone semantics match.
  - PR4633 vuvova: "Big issue: don't use strftime. The server already has date-to-string formatting functions."

## Input parsing — file formats

- **Accept whitespace and control characters when reading legacy on-disk files** (`master.info`, `relay-log.info`); strict parsing causes regressions.
  - PR4764 gkodinov: "I'd also allow space and control symbols. basically isspace and iscntrl."
- **Don't break wire format / on-disk ordering for downgrade compatibility.**
  - PR4430 bnestere on `rpl_master_info_file.hh:501`: "Why unordered? As the `FIELDS_MAP` is iterated over when saving the KV pairs, wouldn't that make it non-deterministic? The fields should be written in the same order as pre-MDEV-37530 so users can downgrade without breaking anything."

## Operational safety

- **`MAP_POPULATE` hides errors** — use `madvise(MADV_POPULATE_{READ,WRITE})` if you need pre-faulting.
  - PR4674 vaintroub: "MAP_POPULATE hides errors, it is the best effort. Either use appropriate madvise(MADV_POPULATE_{READ|WRITE})... Else, we can live without special option for Linux."
- **`os_file_set_size()` never shrinks on POSIX** — only enlarges. Add assertions if you assumed otherwise.
  - PR4405 dr-m on `include/log0log.h:731`: "It turns out that `os_file_set_size()` would never shrink files on POSIX, only enlarge them. I finally caught this by adding some `os_file_get_size()` assertions."

## Auth / ACL

- **Old-protocol auth path off-by-one**: the `+1` was correct for clients lacking `CLIENT_SECURE_CONNECTION`.
  - PR4509 gkodinov on `sql_acl.cc:13866`: "This will only work for clients that send in CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA set."
- **`strnlen` is not portable** — `_POSIX_C_SOURCE >= 200809L` or `_GNU_SOURCE`. MariaDB's read functions already zero-terminate packets; don't rely on `strnlen`.
  - PR4534 vuvova: "I'd keep using `strlen` here. `strnlen` is `_POSIX_C_SOURCE >= 200809L` or `_GNU_SOURCE`... we don't rely on strnlen elsewhere."
- **Don't widen utility functions** to accept invalid inputs (e.g. empty paths in `my_realpath`) — fix the caller.
  - PR4865 vuvova: "I don't understand the logic here. `error_if_data_home_dir()` can strip the file name... and that's why the latter must accept empty strings? It doesn't make any sense."

## Replication / binlog

- **Row-based vs statement-based replication paths diverge** for time-clamping etc.
  - PR4933 bnestere.
- **`include/reset_master.inc` over inline `RESET MASTER`** in MTR tests (more portable across versions and adds the right sync).
  - PR4771 knielsen.
- **Binlog-event size lookup**: don't change the user-visible default without thinking about replay.
  - PR4697 — `binlog_row_event_max_size` to 64k.
