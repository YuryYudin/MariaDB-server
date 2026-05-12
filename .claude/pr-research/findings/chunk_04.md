## Recurring Patterns

### Coding Style

- **title**: Add `noexcept` to new C++ functions in InnoDB
  - **category**: Coding style / InnoDB-specific
  - **rationale**: dr-m repeatedly flags new InnoDB functions for missing `noexcept`. The InnoDB codebase has been migrated to mark non-throwing code so the compiler emits no exception cleanup.
  - **examples**:
    - PR4884 `storage/innobase/handler/ha_innodb.cc`: dr-m: "This is missing `noexcept`, and it'd be better to use `size_t` instead of the alias `ulint`."
    - PR4884 `storage/innobase/srv/srv0start.cc`: dr-m: "Missing `noexcept`. A space around the `*` is misplaced."
    - PR4914 `storage/innobase/handler/ha_innodb.cc`: dr-m: "This is missing `noexcept`."
    - PR4914 `storage/innobase/include/dict0mem.h`: dr-m: "This is missing `noexcept`. Shouldn't we first check a more selective condition…"
  - **frequency**: many (4+)
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Prefer `size_t`/explicit C++ types over legacy aliases like `ulint`, `ulong`
  - **category**: Coding style / InnoDB-specific
  - **rationale**: New code should not propagate MDEV-25861 era `_t` and `ulint` typedef aliases.
  - **examples**:
    - PR4884 `ha_innodb.cc`: dr-m: "better to use `size_t` instead of the alias `ulint`."
    - PR4884 `fsp/fsp0fsp.cc`: dr-m: "Let's not make the MDEV-25861 situation worse by adding even more declarations ending in `_t`."
    - PR4913 `row0import.cc`: dr-m: "Would `0UL` work? If not, then maybe `ulong{0}`? I would rather avoid using C-style casts in C++ code."
  - **frequency**: 3+
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Avoid C-style casts in C++ code; use `int(len)` / `static_cast<>` (and `int(len)` is preferred for brevity)
  - **category**: Coding style
  - **rationale**: C-style casts are discouraged; for narrowing-only cases the constructor-style cast `int(x)` is shorter and equivalent.
  - **examples**:
    - PR4884 `srv0start.cc`: dr-m: "`int(len)` is shorter and equivalent to `static_cast<int>(len)`."
    - PR4884 `fsp0fsp.cc`: dr-m: "Please avoid C-style casts. `int(len)` is shorter too."
    - PR4884 `fsp0fsp.cc`: dr-m: "Let's avoid C-style casts. Could we use `st_::span<const char>` as the parameter, to avoid a `reinterpret_cast<const char*>` here?"
  - **frequency**: many
  - **severity**: important
  - **applies_to**: any C++

- **title**: Pointer/reference spacing: unary `*`/`&` attaches to the variable (`TABLE *t`, not `TABLE* t`); no space before assignment operators
  - **category**: Coding style
  - **rationale**: MariaDB house style mandates a consistent pointer/operator-spacing rule that contributors regularly violate.
  - **examples**:
    - PR4884 `srv0start.cc`: dr-m: "A space around the `*` is misplaced."
    - PR4914 `row0mysql.h`: dr-m: "`TABLE* ` should be written as `TABLE *`."
    - PR4914 `trx0purge.cc`: dr-m: "According to our formatting guidelines, there is not supposed to be any space before any assignment operators."
    - PR4914 `row0purge.h`: dr-m: "In the last two lines, there should be a space before and not after the unary `*`."
  - **frequency**: many (4+)
  - **severity**: nit/important
  - **applies_to**: any C/C++

- **title**: Use spaces, not TAB, in new code; mixed indentation is rejected
  - **category**: Coding style
  - **rationale**: Indentation discipline in InnoDB is enforced; mixing TABs and spaces is repeatedly called out.
  - **examples**:
    - PR4905 `fsp/fsp0fsp.cc`: dr-m: "Please do not use TAB in new code."
    - PR4914 `trx0purge.h`: dr-m: "This is mixing TAB and space indentation."
    - PR4914 `trx0purge.cc`: dr-m: "This is mixing TAB and spaces."
    - PR4914 `trx0purge.cc`: dr-m: "This function is supposed to be formatted without any TAB."
  - **frequency**: many
  - **severity**: nit
  - **applies_to**: storage/innobase/*

- **title**: Doxygen: do not use `[in]`/`[out]` markers; use `@retval` not `@return` for specific values; do not mention data-type names in `@param`
  - **category**: Documentation / comments
  - **rationale**: dr-m enforces a specific InnoDB doxygen sub-style.
  - **examples**:
    - PR4884 `srv0start.cc`: dr-m: "Please, no `[in]` in new code. The `@return` comment should not mention individual return values; we have `@retval` for that."
    - PR4914 `row0mysql.h`: dr-m: "`@param mdl_ticket` is missing. `@retval` should be used for documenting literal return values."
    - PR4914 `trx0purge.cc`: dr-m: "`@param` comments usually do not mention data type names."
  - **frequency**: 3+
  - **severity**: important
  - **applies_to**: storage/innobase/*

### Correctness / Memory

- **title**: Functions that allocate must propagate / handle allocation errors (do not return `true` and continue silently)
  - **category**: Correctness
  - **rationale**: Allocation failures in low-level helpers are quietly converted to user-visible errors without context.
  - **examples**:
    - PR4883 `sql/item_strfunc.h`: grooverdan: "This returns true on an allocation error. Can this be handled intelligently?"
    - PR4942 `sql/sql_base.cc`: bnestere on TRUNCATE-of-MEMORY discussion required proper warning logging with GTID context.
  - **frequency**: 1-2 (call out anyway)
  - **severity**: important
  - **applies_to**: sql/* item/* string handling

- **title**: Don't make code copy a pointer and immediately free the source; ensure ownership/lifetime of returned strings
  - **category**: Memory / allocation
  - **rationale**: The PR4883 bug (TRIM uses memory after freed) was caused by `String::set()` sharing a pointer without copying; the fix had to `copy()` the buffer.
  - **examples**:
    - PR4883 commit-msg: spetrunia: "Before the fix, tmp_value would have pointer to the trimmed string, but didn't own it. […] Avoid this by copying the return value into Item_func_trim::tmp_value."
  - **frequency**: 1
  - **severity**: blocker (caught a real bug)
  - **applies_to**: sql/item_*

- **title**: Validate input lengths before using them; tighten bounds checks
  - **category**: Correctness / Security
  - **rationale**: Buffer/length checks are routinely under-strict in patches; reviewers ask for narrower predicates.
  - **examples**:
    - PR4884 `srv0start.cc`: dr-m: "The `if` expression is missing `id_len != 8 ||`."
    - PR4884 `fsp0fsp.cc`: dr-m: "We can enforce a stricter length limit: `if (len == 0 || len > srv_page_size - (rec - btr_pcur_get_page(&pcur))) goto corrupt;`"
    - PR4884 `fsp0fsp.cc`: dr-m: "The output is wrongly assuming a NUL terminated input string. If `DB_TRX_ID` on the record is at least `1<<40`, some trailing garbage could be displayed."
    - PR4966 `sql/udf_example.c`: contributor fix: replaced unbounded `strcpy`+`strlen` with bounded `memcpy` capped at `initid->max_length` with explicit NUL termination.
  - **frequency**: many
  - **severity**: blocker (real OOB / OOM risk)
  - **applies_to**: sql/*, storage/*, udf

- **title**: Use `%.*s` correctly with `int` cast; never assume input is NUL terminated
  - **category**: Correctness
  - **rationale**: Repeated misuse of `printf`-family with un-terminated InnoDB record buffers.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "The output is wrongly assuming a NUL terminated input string."
    - PR4884 `srv0start.cc`: dr-m fixes `static_cast<int>(len)` style to `int(len)` for `sql_print_error("InnoDB: cannot drop %.*s: %s", …)`.
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: storage/innobase/*

### Performance / API design

- **title**: Pass `st_::span<const char>` (or a struct) instead of `(ptr, len)` pairs; avoid re-derivable parameters
  - **category**: API/architecture
  - **rationale**: dr-m repeatedly pushes new APIs to use spans for safer/shorter signatures, and to fit AMD64 6-register parameter limit.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "Could we pass `st_::span<const char> name` instead of passing a name and a length separately?"
    - PR4884 `fsp0fsp.cc`: dr-m: "Let's avoid C-style casts. Could we use `st_::span<const char>` as the parameter, to avoid a `reinterpret_cast<const char*>` here?"
    - PR4887 `btr0cur.cc`: dr-m: "On AMD64, at most 6 scalar parameters can be passed in registers. I would suggest to replace the second parameter with `const dict_index_t&` so that we will not exceed this limit."
  - **frequency**: 3+
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Re-use existing return codes (e.g. `DB_SUCCESS_LOCKED_REC`) instead of adding output-by-reference parameters
  - **category**: API/architecture
  - **rationale**: dr-m prefers encoding additional info in the existing `dberr_t` rather than threading new bool out-params.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "Instead of using an output parameter, can we use the special return value `DB_SUCCESS_LOCKED_REC` to indicate that some unknown tables were dropped?"
    - PR4884 `fsp0fsp.cc`: dr-m: "Instead of assigning an output parameter `drop_unknown`, can we just assign `err= DB_SUCCESS_LOCKED_REC` here, to indicate that something was dropped?"
    - PR4884 `fsp0fsp.cc`: dr-m: "make `scan_system_tablespace_tables()` return the nonzero return value of the callback function. In that way, there is no need to pass `&err` to the lambda function."
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Put new low-level helpers in the correct compilation unit (e.g. `dict/drop.cc` for table-drop helpers)
  - **category**: API/architecture
  - **rationale**: dr-m insists drop-related helpers belong in `dict/drop.cc`, not exported from `fsp0fsp.cc`.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "This function as well as `delete_from_sys_table_entries()` would seem to logically belong to the compilation unit `dict/drop.cc`."
    - PR4884 `fsp0fsp.cc`: dr-m: "Instead of exporting the low-level function `dict_drop_table_metadata()`, I think that it would be more appropriate to define this function and some of its `static` dependencies in `dict/drop.cc`."
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Avoid `std::function` for purely internal callbacks; prefer typed callable concepts/templates
  - **category**: Performance
  - **rationale**: dr-m questioned a `std::function` wrapper that is only used internally with lambdas. Same logic appears around using `std::unordered_map::emplace` instead of `operator[]`+modify.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "What is the comparison good for? When would that condition hold? All callers to this function should be located in the same compilation unit, and all of them are passing an anonymous function object."
    - PR4914 `trx0purge.cc`: dr-m: "The `std::unordered_map::emplace()` should be more efficient than having `operator[]()` default-construct an element that is subsequently edited."
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: storage/innobase/*

- **title**: Avoid hot-path expensive calls; cache once and reuse (`current_thd()`, MDL lookups, etc.)
  - **category**: Performance
  - **rationale**: dr-m flags repeated invocations of `_current_thd()` and `std::unordered_map` lookups in per-record purge code.
  - **examples**:
    - PR4914 `row0purge.cc`: dr-m: "This is repeatedly invoking the expensive function `_current_thd()` in a low-level operation. Do we need it for anything else than silencing a debug assertion?"
    - PR4914 `row0purge.cc`: dr-m: "Do we really need an `std::unordered_map` lookup when processing each record for each virtual index, or could we cache this information in `purge_node_t::maria_table`?"
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: storage/innobase/*

### Testing / MTR

- **title**: Use `--ping` instead of `--sleep` to wait for connection cleanup; sleeps are CI-fragile
  - **category**: Testing / MTR
  - **rationale**: Sleeps cause flaky tests under load; `--ping` round-trips and verifies the server is alive too.
  - **examples**:
    - PR4998 `proxy_protocol_v1_malformed.test`: grooverdan: "sleeps become fragile in CI systems. Use `--ping` to push and receive an OK… As a bonus, this verifies the server is still alive."
    - PR4986: svoj/grooverdan extensive discussion about creating `include/wait_for_query_to_finish.inc` instead of inline `ping`.
    - PR5018 `MDEV-39006.test`: janlindstrom: "Is there any other way to see that page cleaner had a change to run? This introduces a race…"
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: mysql-test/*

- **title**: View-protocol compatibility in MTR: alias `SELECT` columns (`as t`) and use deterministic constants
  - **category**: Testing / MTR
  - **rationale**: Tests run under view/sp/cursor protocols and need column aliases; literal data should be human-recognisable.
  - **examples**:
    - PR4883 `func_str.test`: grooverdan: "use `SELECT LOCATE(....) as t` to be compatible with view protocol"
    - PR4883 `func_str.test`: spetrunia: "The value of constant doesn't matter. Please change `J(W{$vSaYbyeLs)7cRzT1r<e'` to something that makes it apparent, like `data1-data2-data3`."
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: mysql-test/*

- **title**: Test files need MariaDB-conventional header `--echo # MDEV-NNNNN <title>` and `--echo # End of MA.MI tests`
  - **category**: Testing / MTR
  - **rationale**: Headers help merge conflict resolution and grep; the End-of-tests marker is customary at the end of branch-version test sections.
  - **examples**:
    - PR4904 `init_rpl_role_variable_basic.test`: gkodinov: "Please always terminate the last line with a new line. We also customarily add a `--echo # End of MA.MI tests` at the end: helps conflict resolution when merging up and down."
    - PR5011 `create_table_index_flags_invalid.test`: grooverdan: "Following the MariaDB convention can the be an explicit header in this MTR test: `--echo # MDEV-39479 …`"
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: mysql-test/*

- **title**: Place tests in the right suite (e.g. status-var test does not belong in `sys_vars`)
  - **category**: Testing / MTR
  - **rationale**: Suite choice is part of discoverability; reviewers ask for relocation when a variable is reclassified.
  - **examples**:
    - PR4904 `init_rpl_role_variable_basic.test`: gkodinov: "Now that this is a status variable maybe move it out of the sys_vars suite. Maybe in suite/rpl/init_rpl_role.test?"
    - PR4904 `mysqld--help.result`: ParadoxV5: "the expected results of `sys_vars.sysvars_server_notembedded` and `main.mysqld--help` tests need updates to match the new refined description. You can have `path/to/mtr --record …` rewrite the results."
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: mysql-test/*

- **title**: Add `not_embedded.inc` (and similar guards) when the test cannot run in embedded mode
  - **category**: Testing / MTR
  - **rationale**: Many buildbot failures stem from missing `not_embedded.inc` and friends.
  - **examples**:
    - PR4904 `init_rpl_role_variable_basic.test`: gkodinov: "add a not_embedded.inc reference here: this is why the two build bot tests are failing."
    - PR4998 `proxy_protocol_v1_malformed.test`: grooverdan: "why not Windows? Can move `not_embedded.inc` to start of file."
  - **frequency**: 2
  - **severity**: blocker (CI-blocking)
  - **applies_to**: mysql-test/*

- **title**: Tests should verify side-effects exhaustively (search for specific names, query I_S, not just expected status lines)
  - **category**: Testing / MTR
  - **rationale**: A grep that doesn't include the value being tested can pass while leaking garbage.
  - **examples**:
    - PR4884 `sys_truncate_debug.test`: dr-m: "Could we also look for the specific names of the garbage tables here? We could be outputting some garbage, and the test would not catch that. Can we also check the contents of `INFORMATION_SCHEMA.INNODB_SYS_TABLES`…"
    - PR4884 `dict0crea.cc`: dr-m: "Can we replace `CLUST_IND` and `TABLE_ID` with distinctive names so that we can search for them in the test to prove that all data dictionary entries related to this table were deleted?"
    - PR4942 `restart_binlog_warning.test`: bnestere requested coverage of `RESET SLAVE ALL` and named-slave-connection cases.
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: mysql-test/*

- **title**: Always add a regression test, even a minimal one; or explicitly justify why none is possible
  - **category**: Testing / MTR
  - **rationale**: gkodinov repeatedly insists on at least a minimal test in preliminary review.
  - **examples**:
    - PR4889 review: gkodinov: "Would you consider describing the problem and a sequence of actions that lead to it? Preferably there should be a regression test for it."
    - PR4913 review: gkodinov: "Is it possible to do even some minimal testing? E.g. have a cooked .cfg file with a large value and see it rejected?"
    - PR4889 review: vaintroub: "If yes, please add a test case (without client, using just pure socket send). Then you'd need to return with an error…"
    - PR4982 review: gkodinov: "I am wondering: does testing this require a live videx server ? I'm guessing it doesn't. … can you please add a mtr regression test for this?"
  - **frequency**: many (4+)
  - **severity**: blocker (gates preliminary approval)
  - **applies_to**: any change

- **title**: Use `--sorted_result` for queries that lack an ORDER BY when result ordering is not guaranteed
  - **category**: Testing / MTR
  - **rationale**: Parallel/parallel-replica execution can reorder rows, causing flaky tests.
  - **examples**:
    - PR4991 `main.group_by`: copilot review summary describes the fix: "Add `--sorted_result` before the MDEV-6129 regression query…"
  - **frequency**: 1 (referenced as PR-4946 also)
  - **severity**: important
  - **applies_to**: mysql-test/*

### InnoDB-specific

- **title**: Do not invoke low-level `mtr_t::log_file_op()` directly; go through `mtr_t::name_write()` etc.
  - **category**: InnoDB-specific
  - **rationale**: Internal mtr_t logging primitives have invariants only the higher wrappers maintain.
  - **examples**:
    - PR5018 `ha_innodb.cc`: dr-m: "This causes a compilation failure on many debug builders, because the low-level member function `mtr_t::log_file_op()` is not intended to be invoked directly, but only via other functions, such as `mtr_t::name_write()`."
  - **frequency**: 1 (noted)
  - **severity**: blocker (breaks debug builds)
  - **applies_to**: storage/innobase/*

- **title**: Hold `dict_sys` latch only for the SQL parser invocation, not across transaction commit; remember `lock_sys_tables(trx)`
  - **category**: InnoDB-specific
  - **rationale**: Latch lifetime should be minimal; missing `lock_sys_tables` is a recurring bug class.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "I think that we only need to lock `dict_sys` for invoking the SQL parser. There is no need to hold the latch across the transaction commit. What we are really missing here is a call to `lock_sys_tables(trx)` after the creation of the transaction."
    - PR4936 `lock0lock.cc`: dr-m: "It turns out that we will need an additional condition `err <= DB_SUCCESS_LOCKED_REC` here. Otherwise, the `mtr` test in MDEV-39264 would crash a `CMAKE_BUILD_TYPE=RelWithDebInfo` build on shutdown."
  - **frequency**: 2
  - **severity**: blocker
  - **applies_to**: storage/innobase/*

- **title**: Distinguish purge worker vs coordinator threads; cache invalidation for shared dict structures must be scoped
  - **category**: InnoDB-specific
  - **rationale**: PR4914 had many rounds of comments about not invalidating `vc_templ` cache for SQL threads from purge.
  - **examples**:
    - PR4914: dr-m: "We are potentially invalidating the cache for a user of an SQL thread that meanwhile used this `dict_table_t::vc_templ` cache. Do we actually need this cache invalidation?"
    - PR4914 `trx0purge.cc`: dr-m: "Are we missing the following? `ut_ad(thd_get_query_id(thd) == 0);`"
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: storage/innobase/trx, row, handler/

### Commit hygiene

- **title**: Single logical change per commit; squash review-iteration commits before push
  - **category**: Commit hygiene
  - **rationale**: Heavily debated in PR5007 (COMMUNITY_CONTRIBUTIONS.md) and applied across reviews.
  - **examples**:
    - PR5007 `COMMUNITY_CONTRIBUTIONS.md`: vuvova: "one commit = one logical change. […] If a contributor puts unrelated changes in one commit we will ask him to split it."
    - PR4881 (closed): uwezkhan recreated the PR "on top of 10.11 with the commits squashed into a single commit and a MariaDB-compliant commit message."
    - PR4889: vaintroub: "Could you maybe also squash 2 commits into 1."
    - PR4966 review: gkodinov: "Please always keep a single commit in your pull requests and make sure it has a commit message that's compliant with the MariaDB coding standards."
    - PR4982 review: gkodinov: "please squash your 2 commits into a single one: makes it easier for us to merge when ready."
  - **frequency**: many
  - **severity**: blocker (PR will not be merged otherwise)
  - **applies_to**: any change

- **title**: Commit subject is `MDEV-NNNNN <description>` (no colon) and message must be informative
  - **category**: Commit hygiene
  - **rationale**: vuvova prefers no colon (subject length budget); subjects must be informative and not generic.
  - **examples**:
    - PR5007: vuvova: "I personally use `MDEV-12345 ` without a colon. The length of the commit subject is limited, various tools show only a prefix of it…"
    - PR4883 review: spetrunia rewrote the entire commit message: "This uses non-C++ notation and has typos. 'trum'?  Change to something more descriptive…"
    - PR4897 review: spetrunia: "The fix is ok, but the commit comment needs improvement. Please use something like: ```MDEV-39222: After loading saved optimizer context, further queries cause errors…```"
    - PR4933 review: bnestere: "In the commit message where you say 'error on the others' it would be good to extend it with the actual error that is thrown."
  - **frequency**: 4+
  - **severity**: important
  - **applies_to**: any change

- **title**: Don't bundle unrelated changes into a fix PR; split into separate commits/PRs
  - **category**: Commit hygiene
  - **rationale**: Mixing spelling/cleanup with bug fixes complicates review and merge-up.
  - **examples**:
    - PR4998 `tests/mysql_client_test.c`: grooverdan: "obvious bug. But lets put that in a separate commit, maybe even just a separate PR." / "not relevant to the fix of MDEV-39466. Omit and process separately if required." / "separate PR please. Optionally take the spelling fixes there too."
    - PR4933 `rpl_record.cc`: bnestere: "Is this just cleanup? The patch should be null-merged into 11.8, so let's keep it as minimal as possible. Though you can do the cleanup as a separate patch if you'd like."
  - **frequency**: 3
  - **severity**: blocker
  - **applies_to**: any change

- **title**: Target the right branch (lowest affected supported version), not main/development
  - **category**: Commit hygiene / Process
  - **rationale**: Backports drift downstream; targeting main when a fix applies to 10.11 forces rework.
  - **examples**:
    - PR4913 review: dr-m: "I think that should count as a bug fix and target the earliest major version branch where such fixes are accepted. That would be 10.11."
    - PR4913 review: gkodinov: "I side with his request to rebase this to 10.11."
    - PR4998 review: gkodinov: "please target the main branch: targeting development branches is not useful"  (counter-example: dev branch wrong)
    - PR4998 review: grooverdan: "Can you rebase the last commit of yours back to the origin/10.11 branch …"
    - PR5007 `COMMUNITY_CONTRIBUTIONS.md`: vuvova: "the lowest affected but not older than three years…"
  - **frequency**: 4+
  - **severity**: blocker
  - **applies_to**: any change

### Process / Workflow

- **title**: PRs need preliminary review then a final/senior reviewer; two reviewers are expected
  - **category**: Process / Workflow
  - **rationale**: Standard MariaDB review flow; preliminary reviewers (often gkodinov) handle style/test, final reviewers handle subsystem invariants.
  - **examples**:
    - PR4904 review: gkodinov: "LGTM. Please stay tuned for the final review."
    - PR4889 review: gkodinov: "LGTM. Please stand by for the final review."
    - PR4913 review: gkodinov: "please keep working with Marko on the final review."
    - PR5007: vuvova: "you can mention that we try to have two reviewers for every PR"
  - **frequency**: many
  - **severity**: process
  - **applies_to**: any PR

- **title**: Buildbot must be green before merge; tests may take weeks
  - **category**: Process / Workflow
  - **rationale**: Multiple PRs wait on buildbot before merge.
  - **examples**:
    - PR4918: gkodinov: "it needs to pass the buildbot tests first, Otto. In progress."
    - PR4918: ottok: "Is there something you can to do trigger the buildbot tests? They seem to have been pending for 3 weeks?"
    - PR5036: grooverdan posted full CI grid + a single known unrelated msan failure.
  - **frequency**: 2-3
  - **severity**: process
  - **applies_to**: any PR

- **title**: New features need QA sign-off and typically a preview-release cycle before being merged to GA
  - **category**: Process / Workflow
  - **rationale**: New features go through Preview release; bug fixes do not.
  - **examples**:
    - PR4904: ParadoxV5: "Before merging new features, they also need to be approved by QA and typically pre-released in a preview build for at least one release cycle. QA will let us know when this is good to go."
  - **frequency**: 1 (referenced as practice)
  - **severity**: process
  - **applies_to**: feature PRs

- **title**: Inactive PRs may be moved to draft; respond to reviews promptly
  - **category**: Process / Workflow
  - **rationale**: gkodinov enforces responsiveness as a precondition for review continuation.
  - **examples**:
    - PR4881: gkodinov: "There was no reply to my preliminary review from couple of weeks ago. Moving this to 'draft' state. Please move back to 'open' when/if you intend to keep working on it."
  - **frequency**: 1
  - **severity**: process

- **title**: Update PR title/description/Jira to match what is actually changing
  - **category**: Process / Workflow
  - **rationale**: A common closing nit.
  - **examples**:
    - PR4889: gkodinov: "please also update the description of the PR"
    - PR4889: vaintroub: "The only remaining thing is to change the title of the pull request, and the comment."
    - PR4883: grooverdan: "On MDEV Title - valgrind was only used towards the end of the bug and its not important because its a warning. Perhps 'MDEV-32758: TRIM uses memory after freed'"
  - **frequency**: 3
  - **severity**: important

### Logging / Error messages

- **title**: Server-log messages should be user-actionable; use SQL syntax for cross-locale clarity; describe what we are doing, not just observation
  - **category**: Logging / errors
  - **rationale**: dr-m repeatedly rewords InnoDB log messages.
  - **examples**:
    - PR4884 `fsp0fsp.cc`: dr-m: "The message does not say what we are going to do with the table: `sql_print_information(\"InnoDB: DROP TABLE %.*s\", int(len), rec);` I think that using the SQL syntax should make it clear even for DBAs who do not speak English."
    - PR4884 `fsp0fsp.cc`: dr-m: "In my native language, we don't have indefinite and definite articles. … I would suggest 'Found an unknown table'."
    - PR4884 `sys_truncate_debug.test`: dr-m: "Can we please include the name of the table in the search pattern?"
    - PR4884 `fsp0fsp.cc`: dr-m: "Should the message mention `:autoshrink` too, to give the end user a hint what this is about?"
    - PR4942: bnestere refined the binlog warning text: "Server restart truncated MEMORY table %`s.%`s; a TRUNCATE event was written to the binary log at GTID %u-%u-%llu. As this server is a read-only slave, this event may diverge replication…"
  - **frequency**: many (5+)
  - **severity**: important
  - **applies_to**: any server-facing message

### Compatibility / Architecture

- **title**: Do not break compatibility within stable branches; minimal patches in lower branches
  - **category**: Compatibility / deprecation
  - **rationale**: Bug fixes should be minimal in maintenance branches.
  - **examples**:
    - PR4933: bnestere: "Is this just cleanup? The patch should be null-merged into 11.8, so let's keep it as minimal as possible."
    - PR4998: grooverdan: "this is 11.x+ - so lets not change this. Its not relevant to your PR."
  - **frequency**: 2
  - **severity**: blocker
  - **applies_to**: maintenance branches

- **title**: Prefer status variables over read-only system variables
  - **category**: API/architecture
  - **rationale**: Read-only system vars are an "abomination"; status vars are lighter-weight.
  - **examples**:
    - PR4904: gkodinov: "I personally find a non-settable system variable to be an abomination and a gotcha: why would you put something non-settable in a settable bucket…"
    - PR4904: gkodinov: "Status variables are more light-weight than system variables: less locking needed etc."
  - **frequency**: 1 (extensive thread, but single PR)
  - **severity**: important

## Notable Anti-Patterns

- **Sharing pointers into to-be-freed buffers** (PR4883): `String::set(other, offset, length)` shared a buffer that a subsequent TRIM call would invalidate. Correction: `String::copy(ptr+offset, length, charset)` to own the data.
- **Unbounded `strcpy`/`strlen` on UDF inputs** (PR4966 `udf_example.c`): replaced with `memcpy` capped at `initid->max_length` and explicit NUL termination — including raising `max_length` to a sensible bound (`POSIX HOST_NAME_MAX=255` or IPv4 dotted-quad).
- **Validating after dereference / use-before-validate** (PR4889 `sql/sql_acl.cc`): gkodinov flagged "This check, if it needs to be done, needs to be done after assigning passwd." The fix ultimately became a `DBUG_ASSERT` (no real OOB because higher layer NUL-terminates packets).
- **`%.*s` of an InnoDB record without honoring field-end-info** (PR4884): output could contain trailing `DB_TRX_ID` bytes when name is at a record boundary.
- **Missing condition `id_len != 8 ||`** (PR4884 `srv0start.cc`): omitted sanity check on SYS_TABLES.ID field length before `mach_read_from_8`.
- **Re-ordering of SYS_* DELETEs causing FK-like issues** (PR4884): delete from `SYS_FIELDS` before `SYS_INDEXES`; doing it backwards is confusing.
- **Calling `dict_table_close(-1)`** on the sentinel pointer (PR4914): would crash if reached — code path unreachable in regression tests, but unsafe.
- **`xtrabackup` script permissions break Galera SST** (PR4923/PR5015): removing `${WSREP_SCRIPTS}` from `${BIN_SCRIPTS}` strips +x bit and breaks all Galera tests. Fixed in PR5017.
- **Mixing TAB + space in InnoDB** (PR4914, PR4905): repeatedly caught; new InnoDB code must be space-only.
- **Output parameters where a typed return value would do** (PR4884): `bool &drop_unknown` should be encoded in the existing `dberr_t`.
- **Forgetting that `my_time_t` and `UINT_MAX32` were signed before MDEV-32188 (11.5.1)** (PR4933): a subtle Y2038/Y2106 type pitfall in replication; reviewer required validation across primary versions.

## Workflow / Process Signals

- Two-reviewer model: a "preliminary review" (often gkodinov, sometimes grooverdan/spetrunia/bnestere) precedes a "final review" by the subsystem owner (e.g. dr-m for InnoDB, vuvova for server core, abarkov for charset/parser). Don't merge after only one approval.
- Strong preference for **single-commit PRs**, but the rule is actually "one commit per logical change"; multi-commit PRs are acceptable if each commit is self-contained.
- **Squash and rebase** instead of merging the base branch into the PR; force-push the cleaned commit (`git push --force` after amending review comments).
- **Target the lowest still-supported branch** where the bug exists (commonly 10.11, then merge up). 13.0 was being forked from main once preview merges land.
- **Buildbot green is mandatory** before merge — even when 2 approvals are in.
- **New features require QA approval and a Preview-release cycle**; bug fixes do not.
- **Commit messages** matter: write what the bug is, what causes it, and what the fix does — and use C++ syntax (`Class::member()`, not `Class#member()`).
- **Inactive PRs (no contributor reply ~2 weeks)** are moved to draft.
- **CLA / 3-clause BSD license** is a legal requirement; CLA buildbot should be green.
- COMMUNITY_CONTRIBUTIONS.md (PR5007) is being actively defined — capture: PR labels "External contribution" (PR) vs "Contribution" (JIRA) exist; Jira "In progress" assignee = active developer; contributors cannot change Jira assignee.
- **Don't reformat unrelated code in a bug fix**: PR4938: "That code was generated by yourself (as many of the above). You should recheck yourself better in the first place." (midenok was rejecting wholesale Copilot suggestions). Reviewers consistently push back on AI-generated review noise and unrelated formatting changes.
- **AI-bot review noise** (copilot-pull-request-reviewer, gemini-code-assist) is largely ignored or rebutted by senior maintainers; do not block on it.

## Singletons Worth Noting

- PR4887 `btr0cur.cc`: AMD64 SysV ABI 6-register parameter budget should constrain function signatures (dr-m).
- PR4914 `row0purge.h`: When a `union { uintptr_t mariadb_table; metadata; }` encodes a tagged pointer, mask away the tag with `~uintptr_t{1}`, not `~1ULL`, so 32-bit builds still work.
- PR4920 `debian/autobake-deb.sh`: vuvova: detect architecture support by grepping `storage/columnstore/columnstore/debian/control` instead of hardcoded checks — "future proof".
- PR4933 `rpl_record.cc`: Row-based replication is the only path needing Y2106 timestamp clamping changes; statement-based requires a separate mode.
- PR4942: when emitting binlog comments for server-internal events, use a stable prefix ("generated by server …") so users can grep, with details after.
- PR4953: a direct backport PR can be approved by diffing the original PR with `diff -I^@@ -I^index <(git diff ORIG{~2,}) <(git diff BACKPORT{~2,})` — useful technique for verifying backports.
- PR4996 `sql_select.cc`: Suggest deduplicating optimizer-hint print branches via a single helper.
- PR4998 `mysql_client_test.c`: "Ensure your editor doesn't remove this" — guard against editors stripping trailing whitespace on lines that matter.
- PR5018: a page-cleaner background thread (`std::thread` with no THD) cannot host a per-THD `DEBUG_SYNC` action — pick a different waiter, or, better, rely on existing tests that cover the path.
- PR5024 `handler.h`: `handler::scan_time()` should defensively return `0.0` if `stats.block_size == 0` to prevent NaN propagation into cost calculations (Blackhole / 0-block-size engines).
- PR5046 timer disarm: `tpool::timer::disarm()`, not `stop()`, is the API to halt periodic timer firing — and is unnecessary if the periodic callback re-arms itself.
- PR5053 (`SET SESSION AUTHORIZATION`): replacing `find_user_or_anon` with `find_user_exact` is wrong — the function very intentionally uses anon/wildcard matching so the resulting `user()` equals the explicitly named user.
- PR4906: index-name comparison charset — use `my_charset_utf8_bin` (later resolved to a `cmp` instead).
- PR4920 columnstore: place `architecture=$(dpkg-architecture -q DEB_BUILD_ARCH)` *above* the use in `autobake-deb.sh` — order matters.
