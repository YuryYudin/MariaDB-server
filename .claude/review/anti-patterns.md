# Anti-Patterns Catalogue

Concrete bad patterns caught by reviewers in the 6-month window, with PR references and the fix that was demanded. Useful for self-screening before pushing.

Grouped by category; each entry: **what was wrong → what the reviewer wanted**.

## Buffer / format-string bugs (real OOB / crash risks)

### `sprintf` migration with hard-coded buffer sizes
- **PR4869 (`MDEV-39173 Replace sprintf with snprintf`)** — AI-generated patch hard-coded `snprintf(buf, 64, ...)` etc. without verifying the actual destination buffer size. Multiple call sites had buffers smaller than the asserted limit.
- **Fix wanted**: thread the actual buffer size as a function parameter, not a literal at the call site.
  - gkodinov: "I'd take the size as a parameter to `MYSQL[_BIN]_LOG::generate_new_name`."
  - gkodinov: "Please add a parameter and use it: there's just 3 calls to this. And 2 of these 3 calls are off by one :)"

### `String::set(other, offset, len)` shares the buffer
- **PR4883 (`MDEV-32758: TRIM uses memory after freed`)** — `Item_func_trim::tmp_value` got a pointer into a buffer that subsequent calls invalidated.
- **Fix wanted**: `String::copy(ptr+offset, length, charset)` to own the data.

### Unbounded `strcpy`/`strlen` on UDF inputs
- **PR4966 (`udf_example.c`)** — replaced with `memcpy` capped at `initid->max_length` and explicit NUL termination. Also raised `max_length` to `HOST_NAME_MAX=255` or IPv4 dotted-quad as appropriate.

### `%.*s` of InnoDB record without honouring field-end-info
- **PR4884 (`fsp0fsp.cc`)** — output included trailing `DB_TRX_ID` bytes when name was at a record boundary because `len` wasn't capped.

### Old-protocol auth off-by-one
- **PR4509 (`sql/sql_acl.cc:13866`)** — `+1` was correct for clients lacking `CLIENT_SECURE_CONNECTION` but got trimmed by the fix.

### `db_table[BUF]` then `*end = 0` overflow
- **PR4342 (`row0ins.cc:768`)** — `end` could be one past the buffer. dr-m insisted on `%.*s` length-explicit pattern instead.

### Default constructor + destructor `mem_heap_free(nullptr)` crash
- **PR4036 (`fts0priv.h:587`)** — `= delete;` the default ctor instead.

### Recursive descent without stack-overflow guard
- **PR4332 (`sql/item_jsonfunc.cc:6356`)** — RuchaDeodhar: "Just add a out of stack space check, there are examples in this files."

### `my_hash_init()` without `my_free` callback
- **PR4332 (`sql/item_jsonfunc.cc`)** — MSAN/LSAN leaks; caught on `amd64-ubsan-clang-20`. Fix: pass `my_free` as the free callback.

### One-byte OOB in PROXY-protocol v1 parser
- **PR4881 (`MDEV-39564`)** — header parser missed CR/LF edge cases; v2 also leaked uninitialized memory (MDEV-39576).

### Negative-zero leaking through optimizer grouping
- **PR4632 (`MDEV-38670 Unary minus on empty string returns -0`)** — fixing the printer alone is insufficient; the optimiser groups -0 and +0 differently.

### Buffer too large on the stack inside a lock
- **PR4633 (`server_audit.cc:1116`)** — 256-byte stack buffer in a contended path; pull out / allocate outside the lock.

## Sequencing / control flow

### Bitwise-OR of error-returning calls
- **PR4441 (`sql/sql_yacc.yy:2289`)** — `f1() | f2() | f3()` doesn't sequence operations and doesn't short-circuit. Use `&&` (or `||`) chains.

### `recv() == 0` retry loop
- **PR4881** — gkodinov initially suggested retrying on `recv()==0`; vaintroub corrected: 0 = peer closed (FIN), do not retry. Don't trust the first review without thinking.

### Function pointer cast through wrong signature
- **PR4449 (`server_audit.cc:2337`)** — silences UBSAN function-type-mismatch but leaves the real bug. Fix the signature.

### `fprintf("%s", str)` instead of `fwrite`
- **PR4605 (`backup_copy.cc:1940`)** — gkodinov: "NEVER use that."

### Sleep-based "fix" for a connection race
- **PR4421** — vuvova: "what does it fix? [MDEV-10608] says the failure is … but I see it's failing now as `connect con3,localhost,root,, failed with wrong errno`." Don't sleep, find the real race.

### Loop bound depends on a global flag mutating mid-loop
- **PR4405 (`os_file_set_size()`)** — `while (current_size < size && srv_shutdown_state <= SRV_SHUTDOWN_INITIATED)`: the shutdown_state check leaks file-write logic out of the call site.

### Validating after dereference
- **PR4889 (`sql/sql_acl.cc`)** — `assert/check` after the value was already used; reviewer demanded the check before the assignment.

## Lifetime / leaks

### Early-return error path leaks `rgi->assembler`
- **PR4047 (`log_event_server.cc:5698`)** — hemantdangi-gc caught it; bnestere noted destructor cleans up later but agreed to free here too.

### Dangling heap pointer via local stack assignment
- **PR4036 (`fts0opt.cc:473`)** — `fetch->heap = local`. Returns leave a dangling pointer.

### Submodule PRs bundled with feature PRs
- **PR3726, PR4557, PR4829** — submodule bumps belong in their own PRs.

### Default boolean parameter on a behavior-changing function
- **PR4858** — dr-m: defaults = forgotten overrides = silent bugs.

## Test-quality bugs

### Test that doesn't exercise the bug being fixed
- **PR4549 (`mysqldump-system-collation.test:38`)** — gkodinov: "your test is about re-defining the mysql.users view... do you think this re-creates the problem at all?"

### Sleep-based test sync
- **PR4421**, **PR4697 (`xa.test:82`)**, **PR4669** — Use `DEBUG_SYNC` / `--ping` / `wait_condition`.

### Hand-rolled wait-for-session-count + kill-and-restart
- **PR4446** — use `include/kill_and_restart_mysqld.inc`.

### `mtr.add_suppression()` broadened to match anything
- **PR4342 (`MDEV-36923.result:35`)** — keep the regex tight to the specific error you're suppressing.

### Test using `mysql.user` as fixture data
- **PR4318** — spetrunia: "Using a table from mysql.* makes one think that is somehow special."

### Test that masks the data being verified
- **PR4829** — feedback plugin test masked `/etc/os-release` content before comparing, defeating the assertion.

### `.test` file with `_WIN32`-guarded behavior leaking into output
- **PR4455 (`mysql.cc:1254`)** — needs `--replace_regex` to normalise Windows-specific output.

### Test missing `not_embedded.inc` / `--loose-` for embedded-mode runs
- **PR4606, PR4641, PR4697, PR4904, PR4998** — Standard cause of CI failures.

### Test result with developer-local paths
- **PR4047 (`rpl/r/rpl_fragment_row_event.result:48`)** — local-machine paths leaked into `.result`.

### Random test data ("J(W{$vSaYbyeLs)…")
- **PR4883** — spetrunia: use `data1-data2-data3` so failures are diagnosable.

### Missing `--echo End of <branch> tests`
- **PR4455, PR4710, PR4711, PR4743, PR4810, PR4811, PR4829, PR4874, PR4904** — many PRs. One line, not three.

### Modifying generated parser files
- **PR4293 (`fts0blex.cc:4`)** — edit the source `.l`/`.yy`, mention Bison version in commit.

### Editor corrupting UTF-8 in `.result` files
- **PR4581** — spetrunia: "Does your editor still damage the characters it cannot recognize?"

### `if/else` ladder where the rare path is the body
- **PR4717, PR4858** — reorder so the common case falls through.

## API misuse

### `std::function` for purely internal callback
- **PR4884 (`fsp0fsp.cc`)** — dr-m: "What is the comparison good for? When would that condition hold? All callers... are passing an anonymous function object."

### `std::unordered_map::operator[]` to default-construct then edit
- **PR4914 (`trx0purge.cc`)** — use `emplace()` instead.

### `unordered_map` for on-disk format
- **PR4430 (`rpl_master_info_file.hh:501`)** — iteration order is non-deterministic. Breaks downgrade. Use `HASH`.

### Validity check in `update` callback
- **PR4633 (`server_audit.cc:2361`)** — belongs in `check`.

### `update` callback re-writing the sysvar's own storage
- **PR4633 (`server_audit.cc:2372`)** — server does it for you.

### `strftime` in a plugin instead of server service
- **PR4633** — vuvova: "Big issue: don't use strftime. The server already has date-to-string formatting functions."

### `MAP_POPULATE` to pre-fault
- **PR4674** — hides errors. Use `madvise(MADV_POPULATE_*)`.

### `strnlen` on packet data
- **PR4534 (`sql_acl.cc:13817`)** — vuvova: server already zero-terminates packets; don't introduce platform-dependent libc deps.

### `mysql_*` socket wrappers in mysqld init paths
- **PR4874** — vuvova pushed back on overuse during bootstrap; use judgment.

### Bumping read-only sysvar widths
- **PR4243** (`information_schema.TABLES`'s `TABLE_TYPE`) — closed without merge because tools depend on the current column shape.

### Reusing existing privileges (FEDERATED ADMIN, SUPER) for new ops
- **PR4743** — mint a new privilege.

### Cross-engine feature implemented inside one engine
- **PR4706 (vector index size check in InnoDB)** — vuvova: "No, this is completely wrong... 'hlindexes' are called High-Level Indexes because they are implemented on a higher level, not in the engine, but above it."

### `mtr_t::log_file_op()` called directly
- **PR5018** — breaks debug builders. Use `mtr_t::name_write()` or similar wrapper.

### Allocations under InnoDB log latch
- **PR4405 (`get_archive_path()`)** — Thirunarayanan: "Cache the pre-computed next_archive_path in a member variable, populated after each file transition. With small archive files, file transition could be frequent."

### Bogus `ut_ad`/`ut_a` assertions
- **PR4405** — multiple over-strict assertions in `buf0flu.cc` and `log0log.cc` that fired in legitimate states. Relax the predicate, not the logic.

### Dropped invariant-restoring assignments during refactor
- **PR4405** — `log_sys.buf_size` assignment dropped → hang in `SET GLOBAL innodb_log_file_size`.

### Per-iteration heap allocation in tight loop
- **PR4036 (`fts0fts.cc:6215`)** — hoist out or stack-allocate.

### Bit-field re-read on every loop iteration
- **PR4717 (`skip_alter_undo`)** — cache in a local.

### `std::function` everywhere
- **PR4284 (`mysqldump.cc`)** — vuvova: "Really? I understand that you love `std::function` but this is seriously overdoing it." Five comments on the same PR drove a redesign.

### Removing virtual functions on `MDL_context_owner` claimed as "perf win"
- **PR4808** — rejected; "For the unmeasurable performance benefit of removing virtual function we'll plant this THD dependency everywhere."

### Widening `my_realpath` to accept empty strings
- **PR4865** — vuvova: "It doesn't make any sense." Fix the caller.

## Style / formatting

### Whitespace-only changes
- **PR4508, PR4581, PR4633, PR4342** — recurring. Editor reformats are caught.

### Mixing TAB and space in InnoDB
- **PR4905, PR4914** — new code = spaces only.

### C-style cast in C++ code
- **PR4717, PR4783, PR4884, PR4913** — use `int(x)` or `static_cast<>()`.

### `long` / `ulong` in new code
- **PR4522, PR4884** — use `size_t`, `uint64_t`, etc.

### Yoda conditions / pre-decrement habits
- `CODING_STANDARDS.md` — caught when seen.

### `*` attached to type, not variable
- **PR4914** — `TABLE *t`, not `TABLE* t`.

### Brace style mismatch with surrounding file
- **PR4036, PR4446** — read the file, don't guess.

## Commit / process

### Multiple commits in a PR
- Recurring across **10+ PRs**. Squash.

### Merge commits in a PR
- **PR4703, PR4508** — rebase, don't merge.

### Commit message starting with anything other than MDEV-NNNNN
- **PR4425, PR4447, PR4549, PR4569, PR4625, PR4649, PR4658, PR4664, PR4697, PR4703, PR4707, PR4869** — many.

### License text in commit message
- **PR4703** — gkodinov: "remove the license reference from the commit message."

### Submitting third-party patch without attribution
- **PR4688** — grooverdan: "you appear to have taken @BjarneDMat's patches from JIRA and submitted them as your own."

### Submitting a PR against an unrelated MDEV
- **PR4762** — gkodinov: "Please never submit a pull request against an MDEV if you do not intend to solve the mdev."

### Bumping unrelated submodules in a PR
- **PR3726, PR4557, PR4829** — separate PR, always.

### PR body / title not matching what changed
- **PR4889, PR4883** — update both before requesting final review.

### LLM-generated arguments in review discussions
- **PR4589** — vuvova: "I can ask an LLM myself, no need to do it for me."

### AI-assisted patches without verification
- **PR4869** — gkodinov: "Unfortunately, it's not as simple as letting some AI do it."
- **PR4938** — midenok rejected wholesale Copilot suggestions.

### Targeting `main` for a bug fix
- **PR4534, PR4569, PR4602, PR4606, PR4680, PR4688, PR4706, PR4731, PR4752, PR4766, PR4789, PR4793, PR4804, PR4858, PR4869, PR4872, PR4881, PR4913, PR4998** — rebase to 10.11 (or 10.6 for critical).

## Specific subtle bugs worth remembering

- **`-1` smuggled into unsigned slot** to mean "unchanged" (PR4430 `sql/rpl_rli.h:591`).
- **`enum_using_gtid` duplicated in PerfSchema with off-by-one values** (PR4430).
- **`std::from_chars()` for floating-point** not portable on Apple Clang (PR4430).
- **`master_heartbeat_period` reset on CHANGE MASTER** (PR4430) — a documented inconsistency that future PRs should not entrench.
- **`MAX_KEY_SIZE` collides with Windows ARM64 system macro** (PR4430).
- **`HUGE_VAL` is not infinity** (PR4731).
- **`NAN` is not a valid JSON number** (PR4731).
- **`my_time_t` was signed before MDEV-32188 (11.5.1)** — Y2038/Y2106 timestamp clamping in replication needs to handle both (PR4933).
- **`mi_uintNkorr` is big-endian; `uintNkorr` is little-endian.** Don't cross. (PR4783, PR4797.)
- **`xtrabackup` script permissions break Galera SST** if `${WSREP_SCRIPTS}` is removed from `${BIN_SCRIPTS}` (PR4923/PR5015).
- **`dict_table_close(-1)` on the sentinel pointer** would crash if reached (PR4914) — unreachable in regression tests, but unsafe.
- **Read-only transactions entering group-commit logic** — add `ut_ad` (PR4591).
- **`SHOW GLOBAL STATUS` `ulonglong` torn read on 32-bit** — route through `export_vars` (PR4405).
- **`os_file_set_size()` never shrinks on POSIX** — only enlarges (PR4405).
- **`posix_fallocate()` returns `EOPNOTSUPP` on FreeBSD** — handle it (PR4405).
- **Function-pointer signature mismatch** triggers UBSAN — fix the signature, don't cast (PR4449).
- **PROXY-protocol v1 max header = 107 bytes** — size for full header + NUL (PR4881).
- **`ENABLE_DEBUG_SYNC` not on in non-debug builds** — `have_debug.inc` skip required (PR4765).
- **`MAX_KEY_SIZE`** macro collision on Windows ARM64 (PR4430).
- **`feedback` plugin not compiled on buildbot** — tests requiring it need `information_schema.plugins` checks (PR4829).
- **Index-name comparison charset** — use `my_charset_utf8_bin` or a `cmp` helper (PR4906).
- **`handler::scan_time()` returning NaN** with `stats.block_size == 0` (PR5024 — Blackhole / 0-block-size engines).
- **`tpool::timer::disarm()`** is the API to halt periodic firing — not `stop()` (PR5046).
- **`find_user_or_anon` vs `find_user_exact`** — anon/wildcard matching is intentional (PR5053).

## High-frequency "blocker" tally (window-wide)

Approximate counts of how often each blocker showed up across the 319 substantive PRs:

| Pattern | ~Count |
|---|---|
| Commit message format (MDEV-NNNNN / CODING_STANDARDS.md) | 30+ |
| Squash into one commit | 20+ |
| Branch targeting (rebase to 10.11/10.6) | 20+ |
| CLA bot green | 15+ |
| Buildbot must be green | 15+ |
| Add a test / minimal test | 15+ |
| `.test` file header/footer + newline | 15+ |
| Re-record `.result` files after change | 10+ |
| InnoDB style (`noexcept`, no TAB in new code, K&R switch, etc.) | 15+ |
| Don't bundle unrelated changes | 8+ |
| Don't break wire/on-disk format | 5+ |
| Whitespace-only changes | 5+ |
| AI-generated noise / hard-coded buffer sizes | 5+ |
| Sleep in tests | 5+ |
| Missing `not_embedded.inc` | 4+ |
| Validity check in `update` not `check` | 2+ |
| `posix_fallocate`/`MAP_POPULATE` / OS-specific | 4+ |

If you self-screen against this list, you'll pre-empt the vast majority of preliminary-review comments.
