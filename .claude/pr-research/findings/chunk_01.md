## Recurring Patterns

### Commit Hygiene

- **title:** Write the commit summary line in the form `MDEV-NNNNN: <imperative summary>` and keep it short
  - **category:** Commit hygiene
  - **rationale:** Reviewers explicitly rewrite weak commit titles to match the MDEV-prefixed imperative-mood standard before push. The PR title is not the commit title.
  - **examples:**
    - PR4447, spetrunia: "Make the commit title be: `MDEV-38120: Move Json_string and Json_saved_parser_state into sql_json_lib.h`"
    - PR4425, grooverdan: "`MDEV-23893: Reject invalid numerical suffixes` is closer as a function description."
    - PR4430, bnestere (sql/slave.h:43): "In the git commit message, it should mention how old conventions like this are changed in the code."
  - **frequency:** 3-4 instances
  - **severity:** important
  - **applies_to:** all PRs

- **title:** Keep commit message body lines under 72 characters and follow `CODING_STANDARDS.md`
  - **category:** Commit hygiene
  - **rationale:** Direct reference to project standard during review.
  - **examples:**
    - PR4455, svoj: "Please also fix commit message according to https://github.com/MariaDB/server/blob/main/CODING_STANDARDS.md. Specifically lines must be under 72 characters."
  - **frequency:** 1 explicit instance (but referenced as standard)
  - **severity:** important
  - **applies_to:** all PRs

- **title:** Rebase onto the target branch and squash into a single coherent commit; force-push to update the PR
  - **category:** Commit hygiene
  - **rationale:** Maintainers want a clean single-commit-per-MDEV history and explicitly instruct contributors how to do it.
  - **examples:**
    - PR4455, grooverdan: "Rebase all commits onto the 10.11 branch, and squash them, include a commit message saying why these changes occurred. When finished `git push --force` and edit the github PR title to have 10.11 as the target branch."
    - PR4425, grooverdan: "With these done, make this a single corrected commit and `git push --force` tot he same branch will update this PR."
    - PR4447, spetrunia: "Get this pushed, then rebase the #4255 on top of the newer main so that it doesn't include these changes."
  - **frequency:** 3 instances
  - **severity:** important
  - **applies_to:** all PRs

- **title:** Attribute upstream authors with `git commit --amend --author`, not just by mention in body
  - **category:** Commit hygiene
  - **rationale:** Proper Git authorship metadata is required when applying someone else's patch.
  - **examples:**
    - PR4425, grooverdan: "`git commit --amend --author \"Sergei Golubchik <serg@mariadb.org>\"` is a right way to attribute an author. Credit yourself in the body of the message if you want."
  - **frequency:** 1 instance (singleton, but reflects a strict policy)
  - **severity:** important
  - **applies_to:** any contribution applying an upstream patch

- **title:** Target the right branch (oldest still-supported branch where the bug exists), and don't push behaviour cleanups to stable branches
  - **category:** Commit hygiene / Process
  - **rationale:** Stable branches (10.6/10.11) should only get fixes for real bugs; cleanup or imprecision fixes go to `main`/`12.3`.
  - **examples:**
    - PR4441, bnestere: "I think we should put the whole patch into `main` (or `12.3`), it isn't an issue that any users/customers have complained about, and it doesn't have a broader impact. Better not to put those into older/more stable versions."
    - PR4446, dr-m (review_body): "the bug is quite rare and a possible work-around exists … I think that it is OK not to fix this in the oldest maintained branch (10.6)."
    - PR4455, grooverdan: "Rebase all commits onto the 10.11 branch … edit the github PR title to have 10.11 as the target branch."
  - **frequency:** 3 instances
  - **severity:** important
  - **applies_to:** all PRs

### Coding Style

- **title:** Put spaces on both sides of binary operators (`||`, `&&`, `=`, etc.)
  - **category:** Coding style
  - **rationale:** MariaDB coding standard. Reviewers flag missing spacing directly.
  - **examples:**
    - PR4425, grooverdan (mysys/my_getopt.c:1032): "Spaces on either side of `||`."
    - PR4446, dr-m (storage/innobase/trx/trx0undo.cc:1031): "[InnoDB style] there is supposed to be a space before `=`."
  - **frequency:** 2 instances
  - **severity:** nit
  - **applies_to:** any C/C++

- **title:** Match the existing file's indentation/brace style (InnoDB uses TAB indentation and mandatory braces around single-statement blocks)
  - **category:** Coding style
  - **rationale:** Files have legacy styles that must be preserved within them; especially InnoDB.
  - **examples:**
    - PR4446, dr-m (storage/innobase/trx/trx0undo.cc:1031): "This function has been formatted in the original InnoDB style, which uses TAB for indentation. In that style, `{}` braces around single-statement blocks (like the two `if` body above) are mandatory…"
    - PR4412, janlindstrom (sql/sql_show.cc:3262): "Nick-pit: Formatting is incorrect."
    - PR4425, grooverdan (mysys/my_getopt.c:980): "Correct the indentation level of `if` too."
    - PR4430, bnestere (sql/rpl_master_info_file.hh:594): "labels shouldn't be indented"
  - **frequency:** 4+ instances
  - **severity:** important (InnoDB), nit (elsewhere)
  - **applies_to:** storage/innobase/* especially; any C/C++

- **title:** Follow the `Capital_snake_case` naming convention for new types (CODING_STANDARDS.md)
  - **category:** Coding style
  - **rationale:** Stated project guideline; `st_`-prefixed/UPPER_SNAKE for types is discouraged.
  - **examples:**
    - PR4430, bnestere (sql/rpl_info_file.hh:109): "The naming conventions don't follow the replication general pattern of Uppercase_lowercase_underscore_splits. We should try to be consistent." Followed by direct quote of CODING_STANDARDS.md: "New types should be named in Capital_snake_case … Older st_prefixed_snake_case should be never used in the new code."
  - **frequency:** 1 instance (but quotes the standard)
  - **severity:** important
  - **applies_to:** any new C++ class/struct

- **title:** Avoid emotional/subjective language in code comments — state facts only
  - **category:** Coding style / Documentation
  - **rationale:** Code comments must be informational; opinions/jokes do not belong in source.
  - **examples:**
    - PR4441, bnestere (sql/sql_yacc.yy:2291): "I'd suggest avoiding emotion in code comments, and stick to the facts. I.e., instead of 'disappointingly, decimal2double() is implemented…' to something like 'but as of this patch, decimal2double() is implemented…'"
  - **frequency:** 1 instance (singleton — but listed because it's a clear rule)
  - **severity:** nit
  - **applies_to:** any source file

### Correctness

- **title:** Don't rely on order of evaluation of side-effectful subexpressions; use `&&`/`||` for short-circuit when each step can fail
  - **category:** Correctness
  - **rationale:** Bitwise `|` does not sequence its operands; combining error-returning calls with `|` is undefined ordering and skips early-exit.
  - **examples:**
    - PR4441, bnestere (sql/sql_yacc.yy:2289): "I don't think the compiler guarantees the order-of-operations with bitwise OR (i.e., the three functions involved here may run in any order, which is not what you intend, I think). I think this would be better served by `&&`s, also because the `&&`'s short-circuit if there's an error in an earlier…"
    - Author (ParadoxV5) acknowledged this also affects PR#4430.
  - **frequency:** 2 instances (one is a cross-reference)
  - **severity:** blocker
  - **applies_to:** sql/* and parser code

- **title:** Avoid heap allocation under hot/critical locks; precompute and cache values
  - **category:** Performance / Correctness
  - **rationale:** Heap calls under InnoDB's log latch cause regressions when file transitions are frequent.
  - **examples:**
    - PR4405, Thirunarayanan (review_body): "get_archive_path(), get_next_archive_path() are being called(allocates heap memory) under `latch.wr_lock()`. Cache the pre-computed next_archive_path in a member variable, populated after each file transition. With small archive files, file transition could be frequent."
    - PR4405, Thirunarayanan (review_body): "We did change in log_t::append_prepare(). It calls capacity() in archive mode. I hope there is no performance regression because of this change. Archive file creation could slow down page cleaner thread flushing"
  - **frequency:** 2 instances
  - **severity:** blocker
  - **applies_to:** storage/innobase/*

- **title:** Beware of non-atomic reads of multi-word globals on 32-bit platforms
  - **category:** Correctness
  - **rationale:** Reading 64-bit status variables in `get_one_variable()` on IA-32 is non-atomic and tears.
  - **examples:**
    - PR4405, dr-m (storage/innobase/include/log0log.h:289): "It would indeed be a non-atomic read on IA-32: … in get_one_variable (…value_type=SHOW_OPT_GLOBAL, show_type=SHOW_ULONGLONG…)"
  - **frequency:** 1 instance (singleton, but a recurring concern in InnoDB review tradition)
  - **severity:** important
  - **applies_to:** any global counter exposed as status variable

- **title:** Don't silently swallow assignments / preserve `buf_size = capacity()` invariants when refactoring
  - **category:** Correctness (InnoDB)
  - **rationale:** Dropped assignments to `log_sys.buf_size` caused hangs during `SET GLOBAL innodb_log_file_size=…`.
  - **examples:**
    - PR4405, dr-m (storage/innobase/mtr/mtr0mtr.cc:961): "we should have either preserved the assignments to `buf_size` and assertions `buf_size == capacity()`, or replaced the `buf_size` in the `while` expression with `capacity()`. This inconsistency is what caused hangs during `SET GLOBAL innodb_log_file_size`."
  - **frequency:** 1 instance
  - **severity:** blocker
  - **applies_to:** storage/innobase/log/*

### InnoDB-specific (mtr/log/buf invariants)

- **title:** Maintain log-subsystem invariants: `innodb_log_buffer_size <= innodb_log_file_size`; enforce both at SET GLOBAL and during archive attach
  - **category:** InnoDB-specific
  - **rationale:** Archive attach was violating the invariant by attaching a 4 MiB file with a 16 MiB buf; needs explicit enforcement everywhere the size is changed.
  - **examples:**
    - PR4405, dr-m (storage/innobase/log/log0log.cc:1219): "The constraint `log_sys.file_size < log_sys.buf_size` … is supposed to hold. This is being violated when `recv_sys_t::find_checkpoint()` is attaching an archive log file whose size is half the buffer size."
    - PR4405, dr-m (same path:1219): "In `innodb_log_file_size_update()` we enforce the condition: … This will have to be enforc[ed elsewhere]."
  - **frequency:** 3 follow-ups on the same area
  - **severity:** blocker
  - **applies_to:** storage/innobase/log/*

- **title:** Use the correct assertion granularity in InnoDB; relax assertions when the path legitimately exercises a side-codepath instead of weakening logic
  - **category:** InnoDB-specific / Correctness
  - **rationale:** Multiple `ut_ad`/`ut_a` assertions in this PR were either misplaced or too strict and led to bogus crashes; reviewers (dr-m himself) tracked each one and either fixed the assert or the underlying invariant.
  - **examples:**
    - PR4405, dr-m (storage/innobase/log/log0log.cc:1559): "The assertion needs to be as follows, so that we can allow the second `pmem_persist()` to be invoked on 0 bytes: `ut_ad(!archive || end == START_OFFSET);`"
    - PR4405, dr-m (storage/innobase/buf/buf0flu.cc:2341): "This bogus assertion was removed in 54e61c0…"
    - PR4405, dr-m (storage/innobase/mtr/mtr0mtr.cc:519): "The assertion needs to be relaxed in case there was an `log_sys.archive_flush_ahead()` invocation"
  - **frequency:** Many (the PR is dominated by this)
  - **severity:** blocker
  - **applies_to:** storage/innobase/*

- **title:** Document the complete lifecycle of new state machines (when set, when cleared, what's forbidden in each state)
  - **category:** InnoDB-specific / Documentation
  - **rationale:** Reviewer asked for written lifecycle of a new mode-flag.
  - **examples:**
    - PR4405, Thirunarayanan (storage/innobase/buf/buf0flu.cc:2229): "Can you document the complete lifecycle of `recv_sys.rpo`? When is it set, when is it cleared, and what operations are forbidden in this mode?"
    - PR4405, Thirunarayanan (same): "can we check this one at the start of function?" (single-instance precondition check rather than scattered)
  - **frequency:** 2 instances on the same area
  - **severity:** important
  - **applies_to:** storage/innobase/*

### Testing / MTR

- **title:** Use existing high-level include scripts (`include/kill_and_restart_mysqld.inc`, `innodb_max_purge_lag_wait`) instead of hand-rolled equivalents
  - **category:** Testing / MTR
  - **rationale:** Helper scripts exist precisely to reduce flakiness and boilerplate; using them shortens tests and avoids the count_sessions/wait_for_count_sessions dance.
  - **examples:**
    - PR4446, dr-m (max_trx_no_recovery.test:92): "We can simply use the following: `--source include/kill_and_restart_mysqld.inc`. Furthermore … there is no need to use `count_sessions.inc` or `wait_for_count_sessions.inc`."
    - PR4446, dr-m (max_trx_no_recovery.test:21): "This could be replaced simply with the following. `SET GLOBAL innodb_max_purge_lag_wait=0;` The script was originally introduced before that variable existed."
  - **frequency:** 2 instances in one PR
  - **severity:** important
  - **applies_to:** mysql-test/*

- **title:** Use descriptive variable names in MTR tests, not opaque ones
  - **category:** Testing / MTR
  - **rationale:** Maintainability of large test files.
  - **examples:**
    - PR4433, spetrunia (cte_update_delete.test:39): "please use more descriptive names. `$empty_t3`, `$fill_t3`?"
  - **frequency:** 1 instance (nit but representative)
  - **severity:** nit
  - **applies_to:** mysql-test/*

- **title:** Provide test coverage for every documented branch (e.g. RECURSIVE CTE, error path, prepared statement, procedure)
  - **category:** Testing / MTR
  - **rationale:** A feature touching CTEs must test all CTE forms or explicitly emit a clear error.
  - **examples:**
    - PR4433, sanja-byelkin: "There is no any test with RECURSIVE: if it supported it is clear, if it is not supported clear error should be given."
    - PR4433, spetrunia: "Can't believe test coverage for this one is not present … `with T as (select * from t1) delete from T where a<3;` ERROR 1288 …"
    - PR4433, RexJohnston: added "1) recursive cte with update, {explain, plain execution, procedure, prepared statement} 2) recursive cte with delete multi table syntax …"
  - **frequency:** 3 instances (same PR)
  - **severity:** blocker
  - **applies_to:** mysql-test/*

- **title:** Use `--echo` to mark setup/context so .result files read as self-explanatory; end test files with `--echo End of <branch> tests`
  - **category:** Testing / MTR
  - **rationale:** Test results are read directly; explicit echos help merge-conflict resolution and debugging.
  - **examples:**
    - PR4430, bnestere (change_master_default.test:68): "Also these kinds of statements which set up expectations/context for the results should be --echo'd"
    - PR4430, bnestere (change_master_default.test:145): "Also the test needs an `--echo # End of main.change_master_default`"
    - PR4455, grooverdan: "At the end of the tests in `mysql-test/main/mysql_client_test.test`, put a `--echo End of 10.11 tests`. This is a standard practice to make it easier to resolve merge conflicts where multiple branches added tests."
  - **frequency:** 3 instances
  - **severity:** important
  - **applies_to:** mysql-test/*

- **title:** Use `mtr --record` to regenerate `.result` files, don't hand-edit
  - **category:** Testing / MTR
  - **rationale:** Standard mechanism, avoids spurious diffs.
  - **examples:**
    - PR4455, grooverdan: "`mtr --record mysql_client_test` will update the result file in case you haven't discovered this, it doesn't need to be a manual edit (though do verify the contents)."
  - **frequency:** 1 instance
  - **severity:** nit
  - **applies_to:** mysql-test/*

- **title:** Use `--replace_regex` to normalize platform-dependent output so the same `.result` works across OSes (especially Windows)
  - **category:** Testing / MTR
  - **rationale:** Tests must pass on Windows and embedded; `_WIN32`-guarded behavior leaks into output.
  - **examples:**
    - PR4455, grooverdan (mysql_client_test-mysql-source-errors.test:10): "To resolve the difference in output on Windows: `--replace_regex /(ERROR at line 1: Failed to).*/\\1 REPLACED/ --error 1`"
    - PR4455, grooverdan: "move the test to the end of `mysql-test/main/mysql_client_test.test` this will resolve the embedded test failure (there's no client/server in embedded mode)."
    - PR4455, svoj (mysql.cc:4569): "your test won't work on Windows anyway, since the check for file type is under `#ifndef _WIN32`."
  - **frequency:** 3 instances
  - **severity:** important
  - **applies_to:** mysql-test/*, client/*

- **title:** Don't make MTR tests depend on timing or "wait then hope"; use `wait_condition` / proper sync primitives
  - **category:** Testing / MTR
  - **rationale:** Sleep-based "fixes" mask real races and the test fails again later. Reviewers ask for the actual root cause.
  - **examples:**
    - PR4421, vuvova: "what does it fix? [MDEV-10608] says the failure is … but I see it's failing now as `connect con3,localhost,root,, failed with wrong errno`" (i.e. the sync fix doesn't address the real failure)
    - PR4421, svoj: "With this `sleep()` …" (demonstrated test still fails) — followed by patch to `sql_connect.cc`
    - PR4433, grooverdan: "`MEM_UNDEFINED(&lex->parser_state, sizeof(lex->parser_state));` so MSAN builders can catch what's trying to access it rather than Debug having a working build for unknown reasons."
  - **frequency:** 3 instances
  - **severity:** blocker
  - **applies_to:** mysql-test/*

### API / Architecture

- **title:** Don't sprinkle new state into globally shared structs unnecessarily; consider scope (parser-only? per-thd? per-trx?)
  - **category:** API / Architecture
  - **rationale:** Misplaced state in `LEX` is reused unsafely and hides lifetime.
  - **examples:**
    - PR4433, spetrunia: "The patch makes use of LEX::save_list. I was concerned what other users are there. LEX::save_list should get a comment … I'm also wondering if we could move save_list to somewhere where it's clear its lifetime is parser:"
    - PR4430, bnestere (rpl_info_file.h:30): "Is this specific to replication? It seems useful outside of replication, perhaps it should exist in a different header? Or to make a new \"io_cache_utils.h\" or something?"
  - **frequency:** 2 instances
  - **severity:** important
  - **applies_to:** sql/*

- **title:** Prefer MariaDB-internal data structures (HASH, Hash_set, my_decimal, IO_CACHE) over STL equivalents
  - **category:** API / Architecture
  - **rationale:** Maintainer-stated policy: MariaDB's data structures are tuned for the server; STL won't be optimized.
  - **examples:**
    - PR4430, bnestere (rpl_master_info_file.h:640): "we should prefer MariaDB data types (when available) to promote a standard way of doing things. Here, you should be able to just use `HASH` …"
    - PR4430, bnestere (rpl_master_info_file.hh:501) re unordered_map: cited Monty's policy "No work ever planned for allocator implementation. The issue is that for most cases MariaDB string functions are superior to std::"
  - **frequency:** 2 instances same PR
  - **severity:** important
  - **applies_to:** sql/*, any new C++ in core

- **title:** Preserve on-disk / file-format compatibility for downgrade: write fields in the same order as before
  - **category:** API / Architecture / Replication
  - **rationale:** `unordered_map` iteration order would have broken user downgrade.
  - **examples:**
    - PR4430, bnestere (rpl_master_info_file.hh:501): "Why unordered? As the `FIELDS_MAP` is iterated over when saving the KV pairs, wouldn't that make it non-deterministic? The fields should be written in the same order as pre-MDEV-37530 so users can downgrade without breaking anything."
  - **frequency:** 1 instance (rule for serialized formats)
  - **severity:** blocker
  - **applies_to:** sql/*, anything serializing to disk/wire

### Logging / Error handling

- **title:** Improve sloppy error messages: tell the user what actually went wrong; remove duplicates; restrict path-printing length
  - **category:** Logging / Errors
  - **rationale:** Several reviewers actively rewrote error strings during review.
  - **examples:**
    - PR4455, grooverdan (mysql.cc:4565): "Use a modifier on `%s` to restrict the message to the right most portion of the `source_name`. Adjust buffer size accordingly. Message should be '.. it is a directory, block device, or memory allocation failed'. Adjust the other `batch_readline_init` error message to be consist[ent]"
    - PR4455, grooverdan (mysql.cc:4564): "use a `snprintf(sizeof(buff),...`"
    - PR4455, svoj: "Forgot `2>&1`? There's no error in the result file."
    - PR4412, vuvova (mysqld.cc:301): "isn't it supposed to be 'wsrep applier'?" (correcting log/thread name)
  - **frequency:** 4 instances
  - **severity:** important
  - **applies_to:** client/*, sql/*, plugin/*

- **title:** Use `snprintf(buf, sizeof(buf), …)` not unsafe variants; bound user input in messages
  - **category:** Security / Logging
  - **rationale:** Path strings can be arbitrary length; format buffers overflow if not bounded.
  - **examples:**
    - PR4455, grooverdan (mysql.cc:4564): "use a `snprintf(sizeof(buff),...`"
    - PR4455, grooverdan (mysql.cc:4565): "Use a modifier on `%s` to restrict the message to the right most portion of the `source_name`."
  - **frequency:** 2 instances same PR
  - **severity:** important
  - **applies_to:** client/*, sql/*

### Build / CMake / Platform

- **title:** Don't regress portability — code paths must work on Windows, FreeBSD, musl, and across bison versions
  - **category:** Build / CMake / Packaging
  - **rationale:** Reviewers flag `_WIN32`-only paths missing, FreeBSD `EOPNOTSUPP` from `posix_fallocate`, musl libc TZ bug, old bison versions on RHEL/SLES.
  - **examples:**
    - PR4455, svoj (mysql.cc:1254): "It appears that we can't do this check on windows. Let's put it under `#ifndef _WIN32` for now."
    - PR4405, dr-m (storage/innobase/log/log0log.cc:1330): "`posix_fallocate()` would return `EOPNOTSUPP` on FreeBSD."
    - PR4440, grooverdan: "RHEL-8, AlmaLinux 8, OpenSUSE-15 (but not 16), SLES and Windows have a bison version older than 3.6.3(?) when this was introduced."
    - PR4440, gkodinov: "Also, please consider making the cmake addition of this option depend on the bison version."
    - PR4452: entire PR existed because of musl libc bug.
  - **frequency:** 5+ instances
  - **severity:** blocker
  - **applies_to:** Build / portability, client/*, storage/innobase/os/*

- **title:** Don't shrink files via `os_file_set_size()` — POSIX never shrinks; add `os_file_get_size()` assertions
  - **category:** InnoDB-specific / Build / Correctness
  - **rationale:** Real bug, found by adding assertions.
  - **examples:**
    - PR4405, dr-m (include/log0log.h:731): "It turns out that `os_file_set_size()` would never shrink files on POSIX, only enlarge them. I finally caught this by adding some `os_file_get_size()` assertions."
  - **frequency:** 1 (singleton, but valuable warning)
  - **severity:** important
  - **applies_to:** storage/innobase/os/*

### Documentation

- **title:** Don't link to volatile documentation URLs (use canonical or shortlinks); update docs when behaviour changes
  - **category:** Documentation
  - **rationale:** Mariadb.com KB GitBook links break frequently.
  - **examples:**
    - PR4453, ParadoxV5 (s3.cnf:9): "GitBook links tend to be long, so switching to them over 'some sort of' shortlink redirects might not look good."
  - **frequency:** 1 instance (the whole PR4453 is about a stale config link)
  - **severity:** nit
  - **applies_to:** *.cnf, *.cc comments

- **title:** Fix typos and clarify terminology in comments touching transactions/undo/checkpoints
  - **category:** Documentation / Comments
  - **rationale:** Comments in InnoDB must use precise terminology ("committing transactions", not "committing undo logs").
  - **examples:**
    - PR4446, dr-m (storage/innobase/trx/trx0undo.cc:1021): "Typo: 'previously'. I would also slightly clarify the terminology and refer to committing transactions rather than undo logs … I would also note under which circumstances an undo page can contain several transactions: …"
  - **frequency:** 1 instance
  - **severity:** important
  - **applies_to:** storage/innobase/*

### Process / Workflow

- **title:** Senior reviewer will close inactive PRs after ~1 month with no updates
  - **category:** Process
  - **rationale:** Documented behaviour.
  - **examples:**
    - PR4425, gkodinov: "No update for over a month to the PR. I'm closing it. If you feel like resuming the work on it, please re-open."
    - PR4440, gkodinov: "Closing this due to inactivity. Please re-open if you intend to address my comments."
  - **frequency:** 2 instances same author
  - **severity:** important
  - **applies_to:** all PRs

- **title:** Sign the CLA before contributing substantial features
  - **category:** Process
  - **rationale:** Required before merge.
  - **examples:**
    - PR4440, gkodinov: "Please consider signing the CLA to get us started."
  - **frequency:** 1 instance
  - **severity:** blocker
  - **applies_to:** community contributors

- **title:** Coordinate work-in-flight via cross-PR rebasing; merge dependency PRs first
  - **category:** Process
  - **rationale:** Dependent PRs need rebase after their dependency lands.
  - **examples:**
    - PR4447, spetrunia: "Get this pushed, then rebase the #4255 on top of the newer main so that it doesn't include these changes."
    - PR4412, sjaakola: "moved to another PR for 10.11"
  - **frequency:** 2 instances
  - **severity:** important
  - **applies_to:** all PRs

### Memory / Allocation

- **title:** Avoid `goto` chains that leave file descriptors in invalid states (`close(-1)`); structure cleanup with two-label pattern (`err1`/`err`) carefully
  - **category:** Memory / Allocation / Cleanup
  - **rationale:** Reviewer prescribed the exact pattern.
  - **examples:**
    - PR4455, svoj (mysql.cc:1239): "MariaDB common practice would be to use something like this: `... goto err; err1: put_info(buff, INFO_ERROR, 0); err: if (path) my_close(file, MYF(0)); return 0;`"
    - PR4455, svoj (mysql.cc:1223): "I wouldn't `goto err1` from this point, as it will have to issue `close(-1)`. Just do `put_info()` here."
  - **frequency:** 2 instances same PR
  - **severity:** important
  - **applies_to:** client/*, mysys/*

- **title:** Mark file-scope helper functions `static` if not used elsewhere
  - **category:** API / Memory
  - **rationale:** Avoid symbol leakage and accidental external linkage.
  - **examples:**
    - PR4455, svoj (mysql.cc:1210): "It should be `static`."
  - **frequency:** 1 instance
  - **severity:** nit
  - **applies_to:** any C/C++

## Notable Anti-Patterns

- **Bitwise-OR of error-returning calls** to combine error checks (PR4441 sql/sql_yacc.yy:2289). Bug: `|` does not guarantee evaluation order and does not short-circuit. Use `&&` chains.
- **Loop bound that depends on a global flag that can change in the middle**: PR4405 dr-m flagged `while (current_size < size && srv_shutdown_state <= SRV_SHUTDOWN_INITIATED)` in `os_file_set_size()` as "anti-gem" — the shutdown_state check leaks file-write logic out of the call site.
- **`-1` smuggled into an unsigned slot** to mean "unchanged": PR4430 sql/rpl_rli.h:591 "This is unsigned in practice. It was signed *only* because the parser uses `-1` to represent 'unchanged'."
- **`unordered_*` containers for on-disk format** breaks downgrade (PR4430 rpl_master_info_file.hh:501).
- **Function pointer cast through wrong signature** triggers UBSAN function-type-mismatch (PR4449 server_audit.cc:2337). The fix is to not lie about the function pointer type, not to silence UBSAN.
- **Sleep-based "fix" for a connection race** that didn't actually fix the underlying problem (PR4421 — vuvova showed the failure mode still occurs).
- **Allocations under the InnoDB log latch** during a hot codepath (PR4405 — get_archive_path/get_next_archive_path under `latch.wr_lock()`).
- **Bogus assertions** that were too strict and fired in legitimate states (PR4405 — multiple `ut_ad`/`ut_a` in buf0flu.cc and log0log.cc removed or relaxed).
- **Dropping invariant-restoring assignments** during refactor (PR4405 `log_sys.buf_size` assignment dropped → hang in `SET GLOBAL innodb_log_file_size`).
- **Hand-rolled wait-for-session-count and kill-and-restart sequences** when stable helper scripts exist (PR4446).
- **Logger error message tells you a directory failed but doesn't mention "or memory allocation failed" or which file**: PR4455 svoj/grooverdan rewrote both wording and `snprintf` bounds.
- **Code under `#ifdef _WIN32` placed at end of function as dead code** when it belonged inside the `if (MY_S_ISDIR(...))` branch (PR4455 svoj).
- **Returning `1` from `source` failure when caller expects `-1` for `ignore_errors`** (PR4455 svoj mysql.cc:4774).
- **`.hh` vs `.h` invented as a new convention** when MariaDB has single-header libs already using `.h` (PR4430 bnestere). Don't introduce parallel conventions.
- **Naming a constant `MAX_KEY_SIZE` collides with a Windows ARM64 system macro** (PR4430 ParadoxV5, build failure).
- **Relying on `std::from_chars()` for floating-point** before checking Apple Clang/libc++ support (PR4430 ParadoxV5).

## Workflow / Process Signals

- **Branch targeting is enforced at review.** "Edit the github PR title to have 10.11 as the target branch." (PR4455) "Better not to put those into older/more stable versions." (PR4441) "OK not to fix this in the oldest maintained branch (10.6)." (PR4446)
- **Single squashed commit per PR is the norm.** "make this a single corrected commit and `git push --force`" (PR4425). "Rebase all commits onto the 10.11 branch, and squash them" (PR4455).
- **Commit messages use `MDEV-NNNNN: imperative summary`**, lines <= 72 chars, per CODING_STANDARDS.md (PR4455 svoj).
- **Inactive PRs are closed at ~1 month** without updates (PR4425, PR4440).
- **CLA required** before substantial contributions (PR4440 gkodinov).
- **Buildbot CI must run green on the full grid**, not just amd64; reviewer cites the `buildbot/amd64-msan-clang-20` segfault and the full-grid URL (PR4430, PR4440).
- **Cross-PR coordination is explicit**: "rebase #4255 on top of newer main so that it doesn't include these changes" (PR4447). "moved to another PR for 10.11" (PR4412).
- **MEMBER reviewers triage who has area authority**: spetrunia approves optimizer; dr-m owns InnoDB log; bnestere reviews replication; svoj/grooverdan handle client and build; janlindstrom/sjaakola handle Galera/wsrep; vuvova has final say on parser/style.
- **Author can credit upstream via `--author "Name <email>"` rather than co-authored-by trailer** for patch-application style (PR4425 grooverdan).
- **MSAN/UBSAN/ASAN failures from buildbot are treated as blockers**: PR4449 dr-m chasing function-pointer-type-mismatch; PR4430 ParadoxV5 chasing amd64-msan-clang-20 segfaults.
- **Debug builds should wipe memory** so MSAN catches uses, instead of relying on happenstance-zero memory (PR4433 grooverdan: `MEM_UNDEFINED(&lex->parser_state, sizeof(lex->parser_state))`).
- **Reviewers will paste exact `--source` / `--replace_regex` / `--echo` snippets** as code suggestions — the project expects MTR idioms to be re-used rather than rebuilt.
- **`.clang-format` exists but is not enforced** ("I wish everyone could just agree on consistently applying a common .clang-format, but per CODING_STANDARDS.md that…") — match the file's existing style instead (PR4446 dr-m).
- **Status variable design**: numeric status vars all returned as strings is a known wart; new code is reminded of this when adding the new ones (PR4430 sql/mysqld.cc:7391).
- **Replication on-disk format**: writes must remain ordered for downgrade compatibility (PR4430 — explicit blocker for `unordered_map`).
- **Plugin maturity in .cnf samples must match release reality** (PR4453 — `plugin-maturity=alpha` shouldn't be advised for s3).

## Singletons Worth Noting

- **`enum_using_gtid` and friends are duplicated in PerfSchema with off-by-one values** (PR4430 ParadoxV5, table_replication_connection_configuration.cc:224). Worth a future audit.
- **`std::from_chars()` floating-point support** is not portable across Apple Clang (PR4430 ParadoxV5 rpl_master_info_file.hh:425). Use `strtod`-style alternatives for now.
- **`int2my_decimal()` lacks a constructor on `my_decimal`** that takes `longlong` directly (PR4441 sql/sql_yacc.yy:2272 bnestere). Suggested project-wide enhancement.
- **`master_heartbeat_period` was reset by CHANGE MASTER rather than RESET REPLICA** — inconsistency baseline noted (PR4430 ParadoxV5 rpl_mi.cc:189). Likely a future MDEV.
- **`JOIN_TYPE_OUTER` marker is unused in a meaningful way** in the optimizer (PR4408 spetrunia). Suggests a cleanup opportunity but doesn't block PR4408.
- **`save_list` in `LEX` has multiple unrelated users and unclear lifetime** (PR4433 spetrunia). Should be commented and possibly scoped to parser.
- **NATURAL JOIN didn't previously need `JOIN_TYPE_NATURAL`** but now does for SELECT_LEX print correctness (PR4419 DaveGosselin-MariaDB explaining to spetrunia). Documents a subtle requirement.
- **WSREP applier `tx_isolation` change**: open question whether it really changes isolation or just suppresses checks (PR4422 mariadb-TeemuOllakka). Needs more documentation but didn't block merge.
- **`logger_init_mutexes()` function-pointer-type mismatch in plugin/server_audit** — dr-m could not find a clean solution (PR4449). Suggests the service_logger.h API needs redesign.
- **`MAX_KEY_SIZE` is an external Windows ARM64 macro** that breaks compilation if redefined as a server-internal constant (PR4430 ParadoxV5 rpl_master_info_file.h:538).
- **Reproducible-builds proposal needs CMake bison-version detection** before merge (PR4440 gkodinov + grooverdan). Closed for inactivity but the requirement stands for any retry.
