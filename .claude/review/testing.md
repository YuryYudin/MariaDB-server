# Testing — MTR conventions

MariaDB's regression test framework (`mariadb-test-run.pl`, a.k.a. `mtr`) has a lot of conventions that don't appear in any one document. This file collects what reviewers consistently demand.

## A test is required

Every bug-fix PR needs an MTR regression test that fails without the fix and passes with it. If a test is genuinely impossible, explain why on the PR and in the commit message — reviewers will sometimes accept this for environment-only fixes but they will *always* ask first.

- PR4549 gkodinov: "Please also verify that the test fails without your fix and passes with it."
- PR4691 gkodinov: "LGTM. Can we please try to add a test as discussed?"
- PR4717 dr-m: "There was a nice simple test case posted at the start of MDEV-38928. Please include it in the regression test suite."
- PR4739 gkodinov: "Please add test cases that cover the two queries that are mentioned in the jira."
- PR4913 gkodinov: "Is it possible to do even some minimal testing? E.g. have a cooked .cfg file with a large value and see it rejected?"
- PR4982 gkodinov: "I am wondering: does testing this require a live videx server? I'm guessing it doesn't... can you please add a mtr regression test for this?"

## Minimal repro, deterministic data

- **Strip irrelevant detail from the repro.** Drop unused columns, joins, `IFNULL`, optimizer-trace, sysvar twiddling. spetrunia is the most insistent:
  - PR4505 spetrunia: "I don't believe this is the minimal testcase. Please try to reduce it as much as possible. Tables need to have two records to avoid the '1-row table is const table' code path."
  - PR4505 spetrunia: "So I just took the above query and removed things that were irrelevant. Please verify that the below still crashes..."
  - PR4687 spetrunia on `having.test:1087`: "Grouping operation is not necessary here at all. This will already show the problem..."
- **Two rows per table** to avoid the `const-table` optimization short-circuit. (PR4505.)
- **Recognisable test data.** Don't paste pseudo-random gibberish; pick `data1-data2-data3` so failures are diagnosable.
  - PR4883 spetrunia: "The value of constant doesn't matter. Please change `J(W{$vSaYbyeLs)7cRzT1r<e'` to something that makes it apparent, like `data1-data2-data3`."

## Self-contained — don't piggy-back

- PR4601 gkodinov on `partition_grant.test:84`: "Please do not 'reuse' part of existing bug regression tests. Ideally a bug regression test should be self-contained: it should assume nothing that it needs exists and it should leave nothing behind when done."
- Clean up after yourself: `DROP TABLE`, `--remove_file`, `RESET *` as appropriate.
  - PR4710 grooverdan: "There should be a `DROP TABLE t` to clean up here."
  - PR4829 gkodinov: "We also clean up after the test. Please add `--remove_file $MYSQLTEST_VARDIR/tmp/skip_test.inc`."

## Headers and footers

Every test gets a `--echo` MDEV header and an end-of-version marker. They make merge-conflict resolution between branches trivial.

- **Header**: `--echo # MDEV-NNNNN <short description>` (use `--echo`, not a `#` source comment — the echo lands in the `.result` file).
  - PR4711 grooverdan: "The MDEV header below should be echo statements."
  - PR4739 grooverdan: "A test header should be included. `--echo # --echo # MDEV-35548] UBSAN:...`"
  - PR4789 grooverdan: "I'd move this test to part of mysql-test/main/create.test at end, with a: `--echo # --echo # MDEV-x....`"
  - PR4804 gkodinov: "we customarily start with a heading stating the MDEV."
  - PR4829 grooverdan: "this would be an `--echo # MDEV....` line. Include a `--echo #` before and after to make this stand out."
- **Footer**: `--echo # End of <maj.min> tests`. The *marker line itself* is one line — don't surround it with decorative `--echo ===` bars or repeated marker lines. The bare `--echo #` blank-comment frame around it (`--echo #` / `--echo # End of M.m tests` / `--echo #`) is project-normal in many existing files. **Match the file's existing footer style** — mixing within a single file is worse than picking either. If the file is new or has only single-line markers, use the single-line style.
  - PR4711 grooverdan: "The final statement in a test case is `--echo End of 13.0 tests`. For the purpose of ease of merging..."
  - PR4743 vuvova: "one line for the end marker, not three. Just `--echo # End of 11.8 tests`."
  - PR4710 grooverdan: "now that its rebased - 11.8 the end."
  - PR4714 grooverdan: "move this added test to below the `End of 11.7 tests` line, add a `End of 11.8 tests`."
  - PR4904 gkodinov: "We also customarily add a `--echo # End of MA.MI tests` at the end: helps conflict resolution when merging up and down."
  - **Context**: MDEV-29924's accepted fix (commit `1a3859fff09`, by vuvova) added a 3-line frame in `mysql-test/main/type_time_hires.test`. The "one line" preference is contextual.
- **Terminate the last line with a newline.** Git complains otherwise.
  - PR4810 gkodinov: "please always terminate the last time of tests."
  - PR4829 gkodinov: "Please always terminate the last line of a test file."
  - PR4867 sanja-byelkin: "git complains about incorrect test file end."

## Naming and placement

- **Prefix new test files with the subsystem name.** Lets `--do-test` selectors work, and aids discovery.
  - PR4710 gkodinov: "Prefix the file name with the subsystem name please. In this case: mysql_ (we do this so that we can run all relevant tests with --do-test)."
  - PR4766 gkodinov: "All the files in this suite are prefixed with 'binlog_'. ... I'd add a suffix saying what's actually tested."
- **Place the test in the right suite.** Status-var tests don't belong in `sys_vars`; they belong in `suite/rpl/` or the most natural subsystem.
  - PR4904 gkodinov: "Now that this is a status variable maybe move it out of the sys_vars suite. Maybe in suite/rpl/init_rpl_role.test?"
- **Prefer extending an existing file** for a single-case test rather than creating a new combination file.
  - PR4706 vuvova: "Could you please move the test to vector.test? no need to create a new small test file and a new combination file."
  - PR4711 grooverdan: "This doesn't use or implement any specific innodb features so this can be removed."
  - PR4789 grooverdan: "I'd move this test to part of mysql-test/main/create.test at end."
  - PR4811 grooverdan: "Can the relevant parts of this be moved to `./mysql-test/suite/compat/oracle/t/func_to_date.test` towards bottom."

## Synchronisation: never `sleep`

- **Use `DEBUG_SYNC` + `--source include/have_debug.inc`** (or `have_debug_sync.inc`) for sync points. Tests must skip cleanly on non-debug builds.
  - PR4765 grooverdan: "A sleep statement is ok for validating a test, but as production test it should be a sync point. `DEBUG_SYNC(thd, \"select_send_after_sending_eof\");`."
  - PR4765 grooverdan: "`--source include/have_debug.inc` needed or `have_debug_sync.inc` if a debug sync implementation is used."
  - PR4765 dr-m: "I'd add both, so that the test will be more efficiently skipped on non-debug builds."
- **Use `wait_condition`** for state-change probes that don't have a sync point.
  - PR4421 — sleep "fixes" that didn't address the real failure mode.
- **Use `--ping` (com_ping) over short sleeps for connection-state probes.** Faster, deterministic, and verifies the server is alive.
  - PR4765 grooverdan: "can use com_ping... `--ping`."
  - PR4998 grooverdan: "sleeps become fragile in CI systems. Use `--ping` to push and receive an OK… As a bonus, this verifies the server is still alive."
- **Avoid `SELECT SLEEP()` in tests** — adds to CI time.
  - PR4804 vaintroub: "I do not see why this sleep is necessary... SELECT SLEEPs in foreground is not very good, adds up to test run, and increased CI times."
- **Generous timeouts on `wait_condition`** — 60s, not 2s. CI machines are slow.
  - PR4874 gkodinov: "what if 120 is not enough? ... yes, that would be better."
  - PR4874 gkodinov: "do 1 min here please. We have some slow test machines ;)"

## Embedded mode

- **Source `include/not_embedded.inc`** when the test needs features the embedded library lacks (client-server interaction, separate user accounts, etc.).
  - PR4606 gkodinov: "Most of the engine's tests do not run in embedded mode. Are you sure you haven't missed adding `--source include/not_embedded.inc`?"
  - PR4904 gkodinov on `init_rpl_role_variable_basic.test`: "add a not_embedded.inc reference here: this is why the two build bot tests are failing."
  - PR4998 grooverdan: "why not Windows? Can move `not_embedded.inc` to start of file."
- **`--loose-` prefix on `.opt` files** when the option may not exist in embedded mode.
  - PR4697 gkodinov: "prefix with --loose here because it's run in embedded mode."

## Windows / OS-specific normalisation

- **`--replace_regex`** for output that differs between platforms.
  - PR4455 grooverdan on `mysql_client_test-mysql-source-errors.test:10`: "To resolve the difference in output on Windows: `--replace_regex /(ERROR at line 1: Failed to).*/\\1 REPLACED/ --error 1`."
- **Move tests to `_not_windows.test`** if they require POSIX behavior (long path names, signals, fork).
  - PR4855 — path-length tests.
- **Windows paths in `.result` files** must be matched with regex.

## Helper scripts

Many sequences have existing helpers — use them instead of hand-rolling.

- `include/kill_and_restart_mysqld.inc` — restart sequence.
- `innodb_max_purge_lag_wait` (system variable) — purge sync (replaces the older `wait_for_purge.inc`).
- `include/search_pattern_in_file.inc` — verifying log messages.
- `include/reset_master.inc` — preferred over inline `RESET MASTER`.
- `include/count_sessions.inc` / `wait_for_count_sessions.inc` — session counting (but rarely needed if you use `kill_and_restart_mysqld.inc`).
- `include/have_debug.inc`, `have_debug_sync.inc`, `not_embedded.inc`, `have_partition.inc`, `not_windows.inc`, `have_innodb.inc` — skip guards.
- For Galera tests: `--source include/have_wsrep.inc` and friends.

Reviewers will paste the exact helper invocation as a code suggestion — use it.

- PR4446 dr-m: "We can simply use the following: `--source include/kill_and_restart_mysqld.inc`. Furthermore... there is no need to use `count_sessions.inc` or `wait_for_count_sessions.inc`."
- PR4446 dr-m: "This could be replaced simply with the following. `SET GLOBAL innodb_max_purge_lag_wait=0;`. The script was originally introduced before that variable existed."
- PR4771 knielsen: "It's better to do this: `--source include/reset_master.inc`."

## `mtr --record` — never hand-edit `.result`

- PR4711 grooverdan: "After adding a test case like this, `mtr --record` and then commit."
- PR4455 grooverdan: "`mtr --record mysql_client_test` will update the result file in case you haven't discovered this, it doesn't need to be a manual edit (though do verify the contents)."
- PR4706 gkodinov: "Please don't just copy the lines. Please compile and actually run the test before pushing a new version."
- PR4712 gkodinov: "there's more tests to re-record. Please check the buldbot: it must be clean."
- PR4829 grooverdan: "Create the `result` file by doing a `mtr --record plugins.feedback_os_release` and then manually validate."

When behavior changes on a SQL surface, every affected `.result` file across all suites must be re-recorded; reviewers will not chase down which ones.

- PR4569 gkodinov: "please make sure you re-record the rest of the failing test cases too."
- PR4678 gkodinov: "Please re-record rpl.rpl_from_mysql80: it's failing because of your changes."
- PR4632 gkodinov on `func_math.result`: "func_math is failing on most of the build-bot platforms. Please fix this."
- PR4549 gkodinov: "Please also look at the main.mysqldump-system-collation failure."

## Test-coverage expectations

- **Cover every documented branch.** RECURSIVE CTEs need their own tests. Error paths need their own tests. Procedure and prepared-statement variations get covered too.
  - PR4433 sanja-byelkin: "There is no any test with RECURSIVE: if it supported it is clear, if it is not supported clear error should be given."
  - PR4433 RexJohnston added "1) recursive cte with update, {explain, plain execution, procedure, prepared statement} 2) recursive cte with delete multi table syntax."
- **Cover every error message you add.** The test must include the exact identifier (table/constraint/column name) so the formatting is verified.
  - PR4342 dr-m (×4 on `MW-369.test`, `MDEV-36923.test`).
  - PR4884 dr-m: "Could we also look for the specific names of the garbage tables here? We could be outputting some garbage, and the test would not catch that."
- **Verify side-effects exhaustively.** Query `INFORMATION_SCHEMA` for follow-up state.
  - PR4884 dr-m: "Can we replace `CLUST_IND` and `TABLE_ID` with distinctive names so that we can search for them in the test to prove that all data dictionary entries related to this table were deleted?"
- **Don't mask the data being tested.** A regex replace that strips the value defeats the assertion.
  - PR4829 (PR closed because) "The data you need to test gets masked out. So it could be empty or wrong and no one will notice."

## Test style

- **SQL command parts UPCASE, identifiers lowercase**, in `.test` files.
  - PR4601 gkodinov: "I'd typically do SQL command parts in upcase and the identifiers in lowercase."
- **Don't add unnecessary `AS` clauses to existing tests.** But *do* alias `SELECT` columns when you're under `--view-protocol`:
  - PR4603 gkodinov: "please don't add random AS clauses to existing tests."
  - PR4883 grooverdan: "use `SELECT LOCATE(....) as t` to be compatible with view protocol."
- **Print results, not just status.** Don't print expressions when the result already echoes.
  - PR4603 gkodinov: "no need for that. It's easier to read when the expression is printed in the result file."
- **`--echo`-mark setup/context** so `.result` files read as self-explanatory.
  - PR4430 bnestere on `change_master_default.test:68`: "Also these kinds of statements which set up expectations/context for the results should be --echo'd."
- **`--sorted_result`** for queries without an explicit `ORDER BY` when ordering isn't guaranteed (parallel replicas etc.).
  - PR4991 — explicit fix to `main.group_by` adding `--sorted_result` before the MDEV-6129 regression query.
- **Don't reuse `mysql.*` system tables** as the test fixture — create your own.
  - PR4318 spetrunia: "Please move away the example from using mysql.user to using your own table and VIEW. Using a table from mysql.* makes one think that is somehow special."
- **No paths from the developer's machine** in `.result` files.
  - PR4047 hemantdangi-gc on `rpl_fragment_row_event.result:48`: "change path, this is local to your machine."
- **No `mtr.add_suppression()` broadening.** Keep the regex narrow to the specific error you're suppressing.
  - PR4342 dr-m: "Why is the `mtr.add_suppression()` less specific? Do we really want to ignore any errors that could be issued for other table or constraint names?"
- **`Sys_var_set` tests must verify boundary values are rejected** (e.g. `value=256` if there are only 8 bits' worth of flags).
  - PR4342 dr-m.
- **Descriptive test variable names.** `$empty_t3` / `$fill_t3` over `$x`/`$y`.
  - PR4433 spetrunia.
- **No redundant warning printing** if `mtr` already prints them.
  - PR4769 gkodinov: "it looks like the test driver already prints warnings if any. No need to print these again."

## Combinations

- **Combinations files** declare matrix runs; `.rdiff` files describe per-combination result deltas.
- **Existing combination test files (e.g. `vector.test`)** should be extended rather than duplicated.

## Result files

- **Don't edit `.result` to make broken tests pass.** Reviewers spot this.
- **No invisible characters** — confirm the file is clean UTF-8 / ASCII.
  - PR4581 spetrunia: "Does your editor still damage the characters it cannot recognize?"

## Don't restart unnecessarily

- **Combine option setup** to minimise server restarts in a test.
  - PR4633 vuvova: "adding `--server-audit-timestamp-format=CMD-LINE-%Y-%m-%d` here in the .opt file... restarting the server takes time, better to keep the number of restarts to the minimum."

## `MEM_UNDEFINED` for MSAN tests

- **Wipe stack-allocated structs in debug builds** so MSAN catches use-before-init.
  - PR4433 grooverdan: "`MEM_UNDEFINED(&lex->parser_state, sizeof(lex->parser_state));` so MSAN builders can catch what's trying to access it rather than Debug having a working build for unknown reasons."

## Unit tests (`unittest/`)

Separate framework. CTest-driven MyTAP programs. Naming `*-t.c[c]`. See `unittest/README.txt`. Less reviewer churn than MTR — most volume is in MTR.

## Buildbot is mandatory

Buildbot is *not* GitHub Actions or AppVeyor. It's the project's own multi-platform CI grid:

- amd64-gcc / amd64-clang / amd64-msan-clang-20 / amd64-tsan / amd64-ubsan / amd64-asan
- aarch64, ppc64le, s390x
- Windows
- macOS

All jobs must be green before merge. Authors are responsible for chasing platform-specific failures — Windows path issues, MSAN uninit reads, etc.

- PR4811 gkodinov: "Please address the buildbot issues."
- PR4869 gkodinov: "buildbot compile still failing. Please have a look."
- PR4918 ottok: "Is there something you can to do trigger the buildbot tests? They seem to have been pending for 3 weeks?"

If a buildbot failure is genuinely unrelated, file it as a separate MDEV and link it in the PR — but enumerate the failures you're claiming to be unrelated.

- grooverdan: "Lets leave the test failures that are unrelated as JIRA entries…"
