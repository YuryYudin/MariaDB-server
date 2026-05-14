---
applies-to: main
last-verified: 2026-05-14
source-of-truth: dbug/, BUILD/, include/my_dbug.h, mysql-test/lib/My/Debugger.pm, mysql-test/CLAUDE.md, .claude/review/correctness-and-security.md, .claude/review/build-and-cmake.md
---

# Reference: debug tooling

Tracing, race-condition repro, sanitizer triage, and live-debugging tools for MariaDB Server. Cross-cuts with [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) (test-side patterns), [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) (review expectations for sanitizer reports), and [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) (sanitizer-build hygiene).

---

## 1. TL;DR

- **DBUG macros** ([`include/my_dbug.h`](../../include/my_dbug.h), library in [`dbug/`](../../dbug/)) — `DBUG_ENTER` / `DBUG_RETURN` / `DBUG_PRINT` / `DBUG_EXECUTE_IF` / `DBUG_ASSERT`. All but `DBUG_ASSERT` compile out in non-Debug builds.
- **DEBUG_SYNC** — cooperative pause/signal between sessions. Debug-only. The canonical way to reproduce a race in an MTR test.
- **[`BUILD/compile-*`](../../BUILD/) scripts** — curated cmake wrappers. Use `compile-pentium64-debug-max`, `compile-pentium64-asan-max`, `compile-pentium64-ubsan`, or `compile-amd64-valgrind-max` instead of hand-rolling `-DWITH_ASAN=ON`.
- **`mtr --gdb` / `--rr` / `--valgrind` / `--strace`** — drop a running server into a debugger / recorder / sanitizer-equivalent from inside an `mtr` invocation. See [`mysql-test/lib/My/Debugger.pm`](../../mysql-test/lib/My/Debugger.pm).
- **Sanitizer triage workflow** — read the failing-thread stack, note allocation/free sites, reproduce with the matching `BUILD/compile-*` script, fix; suppress only as last resort.

---

## 2. DBUG library overview

The in-tree DBUG facility lives in [`dbug/`](../../dbug/) (the runtime — `dbug.c`, `dbug_long.h`, plus example/test programs) with the public API in [`include/my_dbug.h`](../../include/my_dbug.h). It predates the project's adoption of git and is pervasive across `sql/`, `mysys/`, `strings/`, and the storage engines.

| Macro | Purpose | Compiled out in non-Debug? |
|---|---|---|
| `DBUG_ENTER("funcname")` | Mark function entry; pairs with `DBUG_RETURN` / `DBUG_VOID_RETURN`. Produces call-stack tracing under `-#t`. | Yes |
| `DBUG_RETURN(x)` / `DBUG_VOID_RETURN` | Return out of a `DBUG_ENTER`-marked function. Records exit for tracing. | Reduces to plain `return` |
| `DBUG_PRINT("key", ("fmt", args))` | Selective trace line. The first arg is a keyword (filterable from `--debug=d,key1`); the second is a parenthesised `printf`-style tuple. | Yes |
| `DBUG_EXECUTE_IF("name", { … })` | Run a block when the debug condition `name` is set (e.g. `SET debug_dbug='+d,name';`). Used for fault injection. | Yes |
| `DBUG_DUMP("tag", ptr, len)` | Hex-dump a buffer when tracing is on. | Yes |
| `DBUG_ASSERT(cond)` | Assertion. **The only DBUG macro that survives the build only when `DBUG_OFF` is not defined** — by default `DBUG_ASSERT` is a no-op in non-Debug builds, but the `DBUG_ASSERT_AS_PRINTF` variant exists and is occasionally enabled. | Yes (becomes `do {} while(0)`) |
| `DBUG_PUSH("d,key")` / `DBUG_SET("…")` | Programmatic equivalent of `--debug=…`. Rarely used directly in code; called from the parser when you `SET debug='…'`. | Yes |

Two structural rules from the macro definition (see `include/my_dbug.h` lines 81-89):

- A function that calls `DBUG_ENTER` **must** exit through `DBUG_RETURN` / `DBUG_VOID_RETURN`. Plain `return` skips the trace exit point and confuses the stack indicator.
- `DBUG_ENTER` declares a stack frame at the top of the function; place it before any conditional `return`.

The `DBUG_PRINT` keyword convention is loose — `info`, `enter`, `exit`, `error`, plus subsystem-specific keywords (`opt`, `event`, `purge`, …) are common. Filter at runtime, not at compile time.

---

## 3. The `--debug=` flag

Controls what DBUG output appears. Set via the server command line, a `--mariadbd=--debug=…` argument to `mtr`, or per-session via `SET SESSION debug='…';`. The format is documented in full in [`dbug/user.r`](../../dbug/user.r) (the original 1986 nroff manual; still authoritative).

| Form | Effect |
|---|---|
| `--debug=d` | Enable `DBUG_PRINT` output (all keywords). |
| `--debug=t` | Enable function-call tracing (`DBUG_ENTER` / `DBUG_RETURN`). |
| `--debug=d:t` | Both. Colon-separated flags. |
| `--debug=d,key1,key2` | Filter `DBUG_PRINT` to only these keywords. |
| `--debug=d:o,/tmp/trace.log` | Redirect output to a file (default: stderr). |
| `--debug=d:t:i:o,/tmp/trace.log` | Add PID (`i`); useful with parallel forks. |
| `--debug=d:f,foo:F:L` | Trace only function `foo`; print source file (`F`) and line (`L`) prefixes. |
| `--debug=-#d` | Header form `-#` is equivalent to `--debug=`; accepted for back-compat. |
| `SET SESSION debug='+d,foo';` | **Add** to the current set without resetting other flags. The leading `+` matters; without it the value replaces. |
| `SET SESSION debug='-d,foo';` | Remove `foo` from the filter set. |
| `SET SESSION debug='';` | Disable DBUG output for this session. |

The session variable is `debug_dbug` (the legacy `debug` alias points to the same thing). It is itself only writable in Debug builds.

---

## 4. DEBUG_SYNC — race-condition repros

Cooperative pause/signal between sessions. Available only in Debug builds (the CMake build sets `ENABLED_DEBUG_SYNC` when `WITH_DEBUG=ON`).

Server-side, at the point you want a pause:

```c
DEBUG_SYNC(thd, "after_open_table");
```

Test-side, from the MTR `.test` script:

```sql
--connect (con1, ...)
SET DEBUG_SYNC='after_open_table SIGNAL paused WAIT_FOR continue';
send SELECT * FROM t1;

--connection default
SET DEBUG_SYNC='now WAIT_FOR paused';
# … verification queries …
SET DEBUG_SYNC='now SIGNAL continue';

--connection con1
reap;
```

For the full test-driver pattern (mandatory `have_debug.inc` + `have_debug_sync.inc` gating, two-connection idiom, where to find templates), see [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns". Reviewers reject DEBUG_SYNC tests missing the `have_debug_sync.inc` guard (PR4765).

---

## 5. `DBUG_EXECUTE_IF` vs `DEBUG_SYNC`

Different tools for different needs:

| Need | Use | Example |
|---|---|---|
| Run a code block in the test (fault inject, force a branch, simulate slow client) | `DBUG_EXECUTE_IF("name", { ... });` server-side, `SET debug_dbug='+d,name';` test-side | [`sql/sql_parse.cc:2262`](../../sql/sql_parse.cc) `DBUG_EXECUTE_IF("simulate_slow_client_at_shutdown", my_sleep(2000000););` |
| Order events across sessions (session A must pause until session B has done X) | `DEBUG_SYNC(thd, "name");` server-side, `SET DEBUG_SYNC='name SIGNAL …';` test-side | See §4 |

The two compose: a `DBUG_EXECUTE_IF` block can itself call `DEBUG_SYNC` to pause only when fault injection is also enabled.

Real examples to grep for templates: `grep -rn 'DBUG_EXECUTE_IF' sql/` returns ~700 hits; `grep -rn 'DEBUG_SYNC(' sql/` returns ~250.

---

## 6. `BUILD/compile-*` scripts

Curated cmake wrappers under [`BUILD/`](../../BUILD/). Each sources [`BUILD/SETUP.sh`](../../BUILD/SETUP.sh) (shared flag definitions: `debug_cflags`, `valgrind_flags`, `pentium64_cflags`, …) then [`BUILD/FINISH.sh`](../../BUILD/FINISH.sh) (the actual cmake + make invocation). Use them rather than hand-rolling `-DWITH_ASAN=ON` etc. — they capture the platform-specific quirks and the curated plugin disables (e.g. `--without-plugin-rocksdb` for ASan, `--without-spider` for UBSan).

| Script | Builds |
|---|---|
| [`BUILD/compile-pentium64-debug-max`](../../BUILD/compile-pentium64-debug-max) | Full Debug + all major debug flags (`-DSAFE_MUTEX -DSAFEMALLOC -DEXTRA_DEBUG -O0 -g3`). The default "give me a debug build" script. |
| [`BUILD/compile-pentium64-asan-max`](../../BUILD/compile-pentium64-asan-max) | AddressSanitizer + max debug. Use-after-free, heap-overflow, double-free detection. Excludes RocksDB. |
| [`BUILD/compile-pentium64-ubsan`](../../BUILD/compile-pentium64-ubsan) | Undefined-behavior sanitizer. Signed overflow, shift overflow, misaligned access, function-pointer signature mismatch. `MYSQL_MAINTAINER_MODE=NO` to allow the warnings the sanitizer triggers; excludes Spider. |
| [`BUILD/compile-amd64-valgrind-max`](../../BUILD/compile-amd64-valgrind-max), [`BUILD/compile-pentium64-valgrind-max`](../../BUILD/compile-pentium64-valgrind-max) | Valgrind-friendly debug build (`-DHAVE_valgrind -DTRASH_FREE_MEMORY`, `UNINIT_VAR` neutralised). |
| [`BUILD/compile-pentium64-debug-all`](../../BUILD/compile-pentium64-debug-all) | Debug with all engines. |
| [`BUILD/compile-amd64-debug-wsrep`](../../BUILD/compile-amd64-debug-wsrep), [`BUILD/compile-amd64-debug-max`](../../BUILD/compile-amd64-debug-max) | AMD64 variants of the above. |

**Not in tree** (despite occasional references): there is no `compile-pentium64-tsan` or `compile-pentium64-msan` script. ThreadSanitizer and MemorySanitizer builds are produced from CI configuration (`.gitlab-ci.yml`) rather than `BUILD/` presets. To reproduce locally, add `-DWITH_TSAN=ON` or `-DWITH_MSAN=ON` to a normal cmake invocation; MSan additionally requires `libc++` (the system libstdc++ has uninstrumented code that produces false positives).

Each script accepts `--just-print` / `-n` (show the commands without running them), `--just-configure` / `-c` (stop after cmake), `--extra-flags=…`, `--extra-configs=…`, and `--with-debug=full` (no optimisation at all — slower but better stack traces). See [`BUILD/SETUP.sh`](../../BUILD/SETUP.sh) lines 27-48 for the full help.

For sanitizer-build hygiene rules (don't bundle unrelated flag changes, `CMAKE_C_FLAGS_${BUILD_TYPE}` quirks, `--without-plugin-rocksdb` for ASan, MSAN/UBSAN/ASAN need basic optimisation per MDEV-39086), see [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Sanitizer hygiene".

---

## 7. `mtr` debugging flags

The MTR driver wraps each running `mariadbd` with whichever debugger / recorder you ask for. Implementations live in [`mysql-test/lib/My/Debugger.pm`](../../mysql-test/lib/My/Debugger.pm). Combinations are not allowed (e.g. no `--gdb --valgrind`).

| Flag | Effect |
|---|---|
| `--gdb` | Start `mariadbd` under gdb in a new xterm; tests proceed when gdb runs the binary. |
| `--manual-gdb` | Print attach instructions and pause — you attach gdb yourself. Use when no xterm available (CI shell, tmux). |
| `--client-gdb` | Run the **mysqltest** client under gdb (not the server). For debugging test-driver crashes. |
| `--boot-gdb` | Debug the bootstrap-server invocation (`mariadbd --bootstrap`) used to install the system schema. |
| `--ddd` | Like `--gdb` but with the DDD GUI front-end. |
| `--lldb`, `--manual-lldb` | lldb variants — for clang-toolchain hosts. |
| `--rr` | Record under Mozilla `rr` for reverse-debugging. Trace goes to `vardir/log/<type>.rr`. Requires `kernel.perf_event_paranoid <= 1`. |
| `--valgrind` | Run `mariadbd` under `valgrind --tool=memcheck --leak-check=yes`; suppressions in [`mysql-test/valgrind.supp`](../../mysql-test/valgrind.supp). |
| `--valgdb` | Run under both valgrind **and** gdb (gdb attached to valgrind's vgdb stub). Slow but precise. |
| `--strace` | strace `mariadbd`; output to `vardir/log/<type>.strace`. |
| `--debugger=<name>` | Generic dispatcher; `<name>` can be `gdb`, `lldb`, `ddd`, `dbx`, `windbg`, `devenv`, `valgrind`, `strace`, `rr`. Each has `--manual-<name>`, `--client-<name>`, `--boot-<name>` variants. |

Per-debugger args go via `--<name>=<args>` (semicolon-separated; an arg starting with `-` becomes a command-line flag rather than a gdb script directive). Example: `./mtr --gdb='break sql_parse.cc:1234;run' alias`.

For the broader list of `mtr` runtime flags (`--parallel`, `--mem`, `--big-test`, `--record`, `--force`, `--extern`, …) see [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"Common runtime flags".

---

## 8. Sanitizer triage workflow

When CI (or a local sanitizer build) flags a failure:

1. **Read the failing-thread stack.** ASan/UBSan/MSan prepend the failing thread's call stack to the report. The top frame is usually the bug *symptom*, not the cause — but it tells you what subsystem to dig into.
2. **For use-after-free / heap-buffer-overflow, note both the allocation and free stacks.** ASan reports include `allocated by thread T0 here:` and `freed by thread T0 here:` blocks. The free site is frequently the actual bug (premature free or wrong arena); the allocation site tells you what the object was. Misreading the allocation stack as the bug location is the most common triage mistake.
3. **Reproduce locally.** Build with the matching preset:
   ```sh
   cd ../build-asan
   ../MariaDB-server/BUILD/compile-pentium64-asan-max
   cd mysql-test && ./mtr <failing_test>
   ```
4. **Look at what changed.** `git blame` the line at the top of the failing-thread stack against recent commits; cross-reference any open MDEVs.
5. **Suppress only as a last resort.** [`mysql-test/asan.supp`](../../mysql-test/asan.supp), [`mysql-test/lsan.supp`](../../mysql-test/lsan.supp), [`mysql-test/valgrind.supp`](../../mysql-test/valgrind.supp), and [`mysql-test/collections/skip_list_ubsan.txt`](../../mysql-test/collections/skip_list_ubsan.txt) exist but each entry needs an MDEV and is reviewed. Adding to a suppression file without a ticket is a review reject.

For UBSan specifically, common findings are signed-integer overflow (typically `int` arithmetic that should be `unsigned` or wider), shift overflow (`x << 32` on an `int`), and function-pointer signature mismatch (cast-through-wrong-type — PR4449 `server_audit.cc:2337`). For MSan, the typical pattern is an uninitialised output parameter on an error-return path (PR4764). See [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Sanitizer-driven failures (MSAN / UBSAN / ASAN)" for the rules and PR citations.

Recent worked examples:

| MDEV | Sanitizer | Subsystem |
|---|---|---|
| MDEV-39127 | UBSAN | `sql/sql_update.cc::Sql_cmd_update::update_single_table` — invalid downcast |
| MDEV-39098 | UBSAN | Mroonga `groonga/lib/db.c:10882` — insufficient object size |
| MDEV-39109 | MSAN + ASAN | `main.sp-error` stack overflow |
| MDEV-39086 | MSAN/UBSAN/ASAN | MSAN/UBSAN/ASAN builds need basic optimisation to avoid false positives |
| MDEV-38987 | ASAN | View-through-trigger heap-use-after-free (ORACLE mode) |
| MDEV-38474 | ASAN | `st_select_lex_unit::cleanup` heap-use-after-free |
| MDEV-37792 | MSAN | `DELETE` from sequence table |
| MDEV-28619 | UBSAN | `Window_funcs_sort::setup` null-pointer-use |
| MDEV-19194 | ASAN | `fk_prepare_copy_alter_table` use-after-poison |

Run `git log --oneline --grep='UBSAN\|ASAN\|MSAN\|TSAN'` for current examples.

---

## 9. GDB pretty-printers

No official pretty-printers ship in tree. The structures most worth printing — `THD`, `Item *`, `Field *`, `LEX`, `TABLE`, `TABLE_LIST` — are large enough that custom printers help substantially. Community-maintained printers for upstream MySQL can be adapted (the layout overlaps for the older types); a project-specific printer set is an improvement worth considering but not a current blocker.

---

## 10. Useful gdb commands for MariaDB internals

| Command | Use |
|---|---|
| `p *thd` | Inspect the current `THD`. Common follow-ups: `p thd->query()`, `p thd->lex->sql_command`, `p thd->variables.sql_mode`. |
| `p *thd->lex` | The current `LEX` (parser state). `p thd->lex->select_lex` for the top-level select. |
| `bt` | Backtrace of the current thread. |
| `bt full` | Backtrace with local variables. |
| `f 3` | Switch to frame 3 in the current backtrace. |
| `info threads` | List all server threads. |
| `thread apply all bt` | Backtrace **every** thread — essential for diagnosing deadlocks (look for two threads each holding a mutex the other wants). |
| `thread N` | Switch to thread N. |
| `set print pretty on` | Multi-line struct printing — much easier to read. |
| `set print elements 0` | Don't truncate long strings/arrays. |
| `watch *0xADDR` | Hardware watchpoint on a 4-byte word. Use to catch the next write to a memory location. |
| `watch -location var` | Watch the underlying memory rather than the variable's slot. |
| `p current_thd` | The `THD` of whatever thread you're currently in (the macro that resolves via thread-local storage). |
| `call dbug_print_item(item)` | Pretty-print an `Item *` via the in-tree DBUG helper. There are similar `dbug_print_*` helpers for several core types — see [`sql/sql_select.cc`](../../sql/sql_select.cc) for the list. |

When a Debug build asserts, gdb's `bt` lands directly on the `DBUG_ASSERT` site. The expression that failed is in the stack-local `assert_expr` parameter of `my_dbug_assert_failed`.

---

## 11. `mtr --rr` workflow

Mozilla `rr` records the whole program execution deterministically, then lets you replay it in gdb with reverse-step / reverse-continue. Indispensable for intermittent crashes ("it asserts once every fifty test runs").

```sh
# Record once.
./mtr --rr <test>

# Replay (the latest trace ends up in ~/.local/share/rr/<test>-<seq>).
rr replay ~/.local/share/rr/latest-trace
```

Inside rr's gdb session:

| Command | Effect |
|---|---|
| `continue` / `c` | Run forward until breakpoint, crash, or end. |
| `reverse-continue` / `rc` | Run **backwards** until a breakpoint/watchpoint hits. From a crash site, `rc` lands at the previous breakpoint or signal. |
| `reverse-step` / `rs` | Step backwards into the previous source line (descends into callees). |
| `reverse-next` / `rn` | Step backwards over a function call. |
| `reverse-finish` | Run backwards until you exit the current frame. |
| `watch -location *0xADDR` then `rc` | Find the last write to a memory location before a crash — the canonical use-after-free triage move. |

Pre-conditions (enforced by [`mysql-test/lib/My/Debugger.pm`](../../mysql-test/lib/My/Debugger.pm) line 80): `kernel.perf_event_paranoid <= 1`. Set with `sudo sysctl -w kernel.perf_event_paranoid=1`. On hosts that can't lower it, `rr` will refuse to record.

The recording overhead is ~2-5x runtime but is single-threaded (rr serialises threads internally) — don't combine `--rr` with `--parallel=N>1`.

---

## 12. Pitfalls

- **Forgetting `--debug=d`.** Compiling Debug isn't enough; without the `d` flag in the runtime debug string, `DBUG_PRINT` lines never appear. Symmetric mistake: passing `--debug=` to a non-Debug binary (it silently does nothing).
- **`DBUG_PRINT` in a hot path floods the trace** and makes the relevant output un-findable. Filter by keyword (`--debug=d,my_key`) when adding new lines, and prefer one focused trace point to many scattered ones.
- **`DBUG_ASSERT(side_effect)`.** The expression evaluates only in Debug builds. `DBUG_ASSERT(do_thing() == 0);` skips `do_thing()` entirely in production. Pull side effects out: `int rc= do_thing(); DBUG_ASSERT(rc == 0);` (or check the result properly — assertions are not error handling).
- **Running `valgrind` against a non-Debug build** produces false positives from optimised-away locals and shoots noise into the suppression file. Always pair `--valgrind` with a `compile-*-valgrind-max` build.
- **`printf` / `fprintf(stderr, …)` for debug tracing** ships to production. Use `DBUG_PRINT` so non-Debug builds compile it out. Reviewers will flag `printf`-for-debug in PR feedback.
- **Misreading the ASan allocation stack as the bug.** Use-after-free reports show three stacks: the access (top), the free, and the allocation. The free site is where the bug usually is; the allocation is "what got freed too early," not "what's wrong."
- **Shipping a DEBUG_SYNC test without `have_debug_sync.inc`** — passes locally on Debug, fails every non-debug CI build (PR4765). See [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns".
- **Forgetting to disable parallel for `--rr`.** `rr` serialises threads internally; `--parallel=N>1` defeats the determinism that makes recordings replayable.

---

## 13. See also

- Root [`CLAUDE.md`](../../CLAUDE.md) §"Build" — debug / sanitizer build flags; §"Things to be aware of" — DBUG / DEBUG_SYNC summary.
- [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns", §"Common runtime flags" — test-side debug recipes.
- [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Sanitizer-driven failures (MSAN / UBSAN / ASAN)" — review expectations.
- [`.claude/review/build-and-cmake.md`](../review/build-and-cmake.md) §"Sanitizer hygiene" — what reviewers reject in sanitizer-related PRs.
- [`.claude/reference/glossary.md`](glossary.md) §"DBUG / `--debug=…`", §"DEBUG_SYNC", §"`BUILD/compile-*`" — companion definitions.
- [`dbug/user.r`](../../dbug/user.r) — canonical DBUG flag reference (nroff manual, browse in raw form).
- [`mysql-test/lib/My/Debugger.pm`](../../mysql-test/lib/My/Debugger.pm) — every `mtr` debugger flag and its argument template.

---

## 14. How this doc was built

- **Repo state**: branch `main` at `5a224924f49e` (2026-05-14).
- **Files surveyed**:
  - [`include/my_dbug.h`](../../include/my_dbug.h) — DBUG macro definitions (Debug vs `DBUG_OFF` arms).
  - [`dbug/user.r`](../../dbug/user.r) lines 380-580 — `--debug=` control-string syntax.
  - [`BUILD/SETUP.sh`](../../BUILD/SETUP.sh), [`BUILD/compile-pentium64-asan-max`](../../BUILD/compile-pentium64-asan-max), [`BUILD/compile-pentium64-ubsan`](../../BUILD/compile-pentium64-ubsan), [`BUILD/compile-pentium64-debug-max`](../../BUILD/compile-pentium64-debug-max) — preset structure and what each script sets.
  - [`mysql-test/lib/My/Debugger.pm`](../../mysql-test/lib/My/Debugger.pm) lines 1-130 — supported debuggers and their argument templates.
  - [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"DEBUG_SYNC patterns", §"Common runtime flags" — confirmed test-side patterns cross-reference here.
  - [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Sanitizer-driven failures" — confirmed sanitizer rules.
- **Commands run**:
  - `ls BUILD/ | grep -iE 'san|valgrind'` — confirmed `compile-pentium64-{asan-max,ubsan}` and `compile-{amd64,pentium64}-valgrind-max` exist; **no** `tsan` / `msan` script in tree.
  - `git log --oneline --grep='UBSAN\|ASAN\|MSAN\|TSAN' | head -10` — recent sanitizer-driven MDEVs (§8 table).
  - `grep -n 'DBUG_EXECUTE_IF' sql/sql_parse.cc` — confirmed fault-injection examples cited.
- **Deliberately excluded**:
  - The full `dbug/user.r` control-string grammar (rarely needed — common forms covered in §3, full text linked).
  - InnoDB-specific tracing helpers (subsystem-local; lives in `storage/innobase/include/log0log.h` and friends).
  - Performance-Schema instrumentation — different tool, separate doc territory.
- **How to refresh**: re-run the four `ls` / `grep` / `git log` commands; if new sanitizer presets appear in `BUILD/`, update §6; if MDEV citations in §8 go stale, regenerate from `git log --oneline --grep=…`; if `Debugger.pm` adds new entries, update §7.
