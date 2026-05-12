# MariaDB PR Review Patterns — Chunk 02

Analysis of 1038 review comments across 95 PRs (closed/merged 2025-11-12 to 2026-05-12). Strongest reviewers represented: gkodinov (228 comments), dr-m (117), vuvova (96), grooverdan (56), spetrunia (45), vaintroub (19), Thirunarayanan (14).

## Recurring Patterns

### Commit Hygiene

#### Squash all commits into a single commit before merge
- **category**: Commit hygiene
- **rationale**: Reviewers consistently require contributors to collapse iteration commits into one logical commit before approval — "after you push PRs won't matter anymore, the history only contains commits, not PRs."
- **examples**:
  - PR4509 (vuvova, APPROVED): "looks good, thanks. Would you mind squashing all commits into one? Then I'll merge it."
  - PR4569 (vuvova, APPROVED): "Looks good, please squash into one commit."
  - PR4602 (gkodinov): "I'd squash the two commits in one."
  - PR4625 (gkodinov, CHANGES_REQUESTED): "can you please squash all of your commits into a single one and put up a commit message that conforms to CODING_STANDARDS.md ?"
  - PR4678 (gkodinov): "Please don't have multiple commits. Always squash your commits to a single one and update the commit message in the process."
- **frequency**: 10+ instances
- **severity**: blocker (gates merge)
- **applies_to**: every PR

#### Commit message must follow CODING_STANDARDS.md / CONTRIBUTING.md
- **category**: Commit hygiene
- **rationale**: A blocking checklist item on nearly every external-contributor PR. The message must explain "what the issue is, how it was fixed and how it was tested."
- **examples**:
  - PR4549 (gkodinov): "please follow the https://github.com/MariaDB/server/blob/main/CODING_STANDARDS.md#git-commit-messages for the format of the commit message."
  - PR4569 (gkodinov): "Please observe https://mariadb.org/.../make-sure-your-commit-messages-and-content-follow-the-following-guidelines when compiling the commit message text."
  - PR4649 (gkodinov): "Please add a better commit message that according to the coding standard: describes what the issue is, how it was fixed and how it was tested."
  - PR4658 (gkodinov): "Great that you managed to do a single commit. Please now add a commit message compliant to CODING_STANDARDS.md."
  - PR4668, PR4664, PR4653, PR4697, PR4630 — same admonition
- **frequency**: ~12 instances
- **severity**: blocker
- **applies_to**: every PR

#### Bug fixes target the lowest still-maintained branch that reproduces (typically 10.11, sometimes 10.6)
- **category**: Process / branch targeting
- **rationale**: gkodinov repeatedly notes the policy: "Bug fixes should be based against the earliest maintained branch in which the bug can be reproduced." 10.6 is currently restricted to "critical" bugs; 10.11 is the default safe target for non-critical bug fixes.
- **examples**:
  - PR4569 (gkodinov): "please re-base on 10.11. I am still (relatively) new here and it was pointed out to me that only 'critical' bugs currently go to 10.6."
  - PR4534 (gkodinov): "I'd also rebase on 10.11 at this point. I do not think it's that critical for 10.6."
  - PR4549 (gkodinov): "please re-base to 10.11: this is a bug and it needs to be fixed in all affected versions."
  - PR4680 (gkodinov): "10.11 is the correct target at this point. Please rebase to that."
  - PR4606 (gkodinov): "Can you re-base to 10.6 please? This is a crashing bug and the jira says it applies to 10.6 onwards."
- **frequency**: 10+ instances
- **severity**: blocker
- **applies_to**: all bug-fix PRs

#### Rebase, do not merge; force-push to the same branch
- **category**: Commit hygiene
- **rationale**: Merge commits in PRs are not accepted; the project workflow rebases atop the target branch.
- **examples**:
  - PR4508 (grooverdan): "Can you rebase without a merge commit onto the 10.11 branch, squash commits together and force push to the same github branch."
  - PR4658 (gkodinov): "The preferred way to update the base branch around here is with rebase. ... This guarantees that only your changes will [appear]."
- **frequency**: 3-4 explicit
- **severity**: important
- **applies_to**: any PR with merge commits

#### CLA must be signed (and CLA bot must report green) before final review
- **category**: Process / workflow
- **rationale**: gkodinov routinely blocks final review until the CLA bot reports signed.
- **examples**:
  - PR4493 (gkodinov, DISMISSED): "can you please clear up the license agreement asap?"
  - PR4601 (gkodinov): "PLEASE sign the CLA. Click on the button saying 'CLA not signed yet' and make sure it is signed."
  - PR4605 (gkodinov): "Please also sort out the CLA bot! It must say 'CLA signed'."
  - PR4618 (gkodinov): "it looks like the CLA bot didn't record its checking. Please click on the CLA bot..."
- **frequency**: 6+ instances
- **severity**: blocker
- **applies_to**: external contributor PRs

#### Attribute the original author when re-submitting someone else's patch
- **category**: Commit hygiene / ethics
- **rationale**: grooverdan flagged a contributor for posting another author's JIRA patch without credit.
- **examples**:
  - PR4688 (grooverdan): "you appear to have taken @BjarneDMat's patches from JIRA and submitted them as your own without even an attribution to the author. Can you please credit the author `git commit --author '...' --amend`..."
- **frequency**: 1 strong instance (still worth a rule)
- **severity**: blocker
- **applies_to**: any PR claiming third-party work

### Testing / MTR

#### Every contribution must add a test; ensure it fails before the fix and passes after
- **category**: Testing
- **rationale**: Standard requirement, restated as a checklist item by gkodinov.
- **examples**:
  - PR4549 (gkodinov): "Please also verify that the test fails without your fix and passes with it."
  - PR4678 (gkodinov): "Please add tests to cover the change. You seem to have a pretty clear path to reproduce. Just add that into a .test file."
  - PR4691 (gkodinov): "LGTM. Can we please try to add a test as discussed?"
- **frequency**: 4+ instances
- **severity**: blocker
- **applies_to**: every bug-fix / feature PR

#### Reduce the test case to the minimum reproducer
- **category**: Testing
- **rationale**: spetrunia insists tests strip irrelevant clauses; "I don't believe this is the minimal testcase. Please try to reduce it as much as possible."
- **examples**:
  - PR4505 (spetrunia, sql/main/range_notembedded.test): "I don't believe this is the minimal testcase. Please try to reduce it as much as possible. Tables need to have two records to avoid the '1-row table is const table' code path."
  - PR4505 (spetrunia): "So I just took the above query and removed things that were irrelevant. Please verify that the below still crashes..."
  - PR4687 (spetrunia, having.test:1087): "Grouping operation is not necessary here at all. This will already show the problem..."
- **frequency**: 3-4 instances
- **severity**: important
- **applies_to**: `mysql-test/*`

#### Make tests self-contained — do not piggy-back on neighbouring regression tests
- **category**: Testing
- **rationale**: gkodinov: "Ideally a bug regression test should be self-contained: it should assume nothing that it needs exists and it should leave nothing behind when done."
- **examples**:
  - PR4601 (gkodinov, partition_grant.test:84): "Please do not 'reuse' part of existing bug regression tests. Ideally a bug regression test should be self-contained..."
  - PR4617 (gkodinov): tests must be added covering hex num, float, etc.
  - PR4569 (gkodinov, func_math_div_zero.result): "Please add coverage for all of the functions you're affecting"
- **frequency**: 3 instances
- **severity**: important
- **applies_to**: `mysql-test/*`

#### No `sleep` in tests — they are non-deterministic
- **category**: Testing
- **rationale**: gkodinov: "Most of the times sleep is nondeterministic and just obfuscating the real issue."
- **examples**:
  - PR4697 (gkodinov, xa.test:82): "Why? Most of the times sleep is nondeterministic and just obfuscating the real issue. Note that there are unstable tests that can fail even without your change. I'd refrain from trying to 'fix' these with sleeps."
  - PR4669 (gkodinov, alter_copy_stats.result): suggests `debug_sync` / DBUG library instead of timing-dependent triggers
- **frequency**: 2 strong instances
- **severity**: important
- **applies_to**: `mysql-test/*`

#### Re-record `.result` files when behaviour changes; do not leave failing tests in buildbot
- **category**: Testing / Build
- **rationale**: Multiple reviewers tell contributors to `--record` affected tests and unblock buildbot before requesting another review.
- **examples**:
  - PR4569 (gkodinov): "please make sure you re-record the rest of the failing test cases too."
  - PR4678 (gkodinov): "Please re-record rpl.rpl_from_mysql80: it's failing because of your changes."
  - PR4632 (gkodinov, func_math.result): "func_math is failing on most of the build-bot platforms. Please fix this."
  - PR4549 (gkodinov): "Please also look at the main.mysqldump-system-collation failure."
- **frequency**: 5+ instances
- **severity**: blocker
- **applies_to**: any PR touching SQL surface

#### Skip embedded mode or `--loose-`prefix variables that don't exist there
- **category**: Testing / build
- **rationale**: Tests that need a server feature missing from embedded must either source `not_embedded.inc` or use `--loose-` so the option is silently ignored.
- **examples**:
  - PR4606 (gkodinov): "Most of the engine's tests do not run in embedded mode. Are you sure you haven't missed adding `--source include/not_embedded.inc`"
  - PR4697 (gkodinov, vector.opt): "prefix with --loose here because it's run in embedded mode."
  - PR4641 (gkodinov, reset_slave_all_leaks_master_info.test): "either exclude embedded or fix the failures in this test when run with embedded. See buildbot."
- **frequency**: 3 instances
- **severity**: important
- **applies_to**: `mysql-test/*`

#### Test result files: don't print expressions, print results; use SQL upcase / identifier lowercase
- **category**: Testing style
- **rationale**: gkodinov pushes a consistent style for `.test` files.
- **examples**:
  - PR4601 (gkodinov, partition_grant.test): "I'd typically do SQL command parts in upcase and the identifiers in lowercase"
  - PR4603 (gkodinov): "please don't add random AS clauses to existing tests."
  - PR4603 (gkodinov, innodb_ctype_ldml.test:347): "no need for that. It's easier to read when the expression is printed in the result file."
  - PR4517 (spetrunia, derived_view.result:4500): unnecessary touching of `@save_optimizer_switch` — already restored 1K lines above
- **frequency**: 3 instances
- **severity**: nit
- **applies_to**: `mysql-test/*`

#### End each test file with version marker `# End of X.Y tests`
- **category**: Testing style
- **rationale**: Standard convention.
- **examples**:
  - PR4632 (gkodinov, func_math.test:1949): "It is customary to end a test file with a version test end echo command. Please add one for the target version: 13 in your case I believe"
  - PR4651 (grooverdan, trim_core_dump.test:76): "`--echo # End of 10.11 tests` maker"
- **frequency**: 2 instances
- **severity**: nit
- **applies_to**: `mysql-test/*`

### Coding Style

#### No whitespace-only changes
- **category**: Coding style
- **rationale**: Whitespace-only edits pollute diffs and complicate `git blame`.
- **examples**:
  - PR4508 (gkodinov, extra/perror.c:355): "please don't do white-space only changes"
  - PR4633 (gkodinov, server_audit.cc:1153 and :1179): "don't do white-space only changes please!"
  - PR4581 (spetrunia, show_explain.result:1342): "What's this change? Does your editor still damage the characters it cannot recognize? ... Please remove changes like this."
  - PR4522 (vaintroub, srv0start.cc): unrelated indentation churn was flagged
- **frequency**: 5+ instances
- **severity**: important
- **applies_to**: any C/C++/SQL/test file

#### Use named constants instead of magic numbers
- **category**: Coding style
- **rationale**: gkodinov repeatedly nags about literal sizes.
- **examples**:
  - PR4633 (gkodinov, server_audit.cc:1234): "I'd use some named const size_t for the 1k constant"
  - PR4633 (gkodinov, :1288): "same here: use a named constant for 1k"
- **frequency**: 2 instances
- **severity**: nit
- **applies_to**: any C/C++

#### Prefer `static const` over `#define` for typed constants
- **category**: Coding style
- **rationale**: grooverdan recommends modern typed constants.
- **examples**:
  - PR4651 (grooverdan, ha_innodb.cc:19305): "`static const` instead of define."
- **frequency**: 1 strong instance (consistent with general C++ guidance)
- **severity**: nit
- **applies_to**: `sql/*`, `storage/innobase/*`

#### Avoid `long`/`ulong` for typed objects — they are not portable
- **category**: Coding style / correctness
- **rationale**: vaintroub: ulong size is platform-dependent; what matters is the actual width.
- **examples**:
  - PR4522 (vaintroub, sql/password.c:127): "That they are ulong, is non-essential (and also unnecessary, better if they used a more portable type) But that they are 8 byte long, is essential."
  - PR4569 (gkodinov, item_func.h:254): "make this a static func please. No need for it to be an instance method."
  - PR4503 (vuvova, rpl_info_file.h:77): proposes a portable C++ template instead of raw ulong parsing
- **frequency**: 2-3 instances
- **severity**: important
- **applies_to**: any C/C++

#### Capitalised, descriptive macro names; consistent with project conventions
- **category**: Coding style
- **rationale**: Macros must be upper-case; meaningful.
- **examples**:
  - PR4522 (vaintroub, sql_parse.h:204): "Suggest a more meaningful name, also e.g MY_CHARSET_UTF8MB4_BIN (also capitalized, this is the usual convention for macros)"
- **frequency**: 1 instance
- **severity**: nit
- **applies_to**: any C/C++ header

#### Migrate `sprintf` to `snprintf` (iteratively, per area)
- **category**: Coding style / security
- **rationale**: An ongoing project-wide effort; gkodinov runs the migration to eliminate compiler warnings.
- **examples**:
  - PR4522 (gkodinov, mysqladmin.cc:687): "My goal is simple: get a warning-free compile."
  - PR4522 (vaintroub, srv0start.cc:1383): suggests collapsing the snprintf onto one line when migrating
- **frequency**: 2 instances (whole PR is the theme)
- **severity**: important
- **applies_to**: `client/*`, `storage/*`, anywhere `sprintf`

#### Prefer flat early-return error handling over nested `if/else`
- **category**: Coding style
- **rationale**: Project convention: "we typically do not do nested if() else ... for errors."
- **examples**:
  - PR4605 (gkodinov, backup_copy.cc:1950): "we typically do not do nested if() else ... for errors. We'd typically do something like: if (call_function() == error) { do something with error; return if needed; // or goto handle_error; }"
  - PR4633 (gkodinov, :1123): "just do 'else' here. Easier to read."
  - PR4615 (DaveGosselin-MariaDB, sql_test.cc): "No else after return"
- **frequency**: 3 instances
- **severity**: nit
- **applies_to**: any C/C++

#### Use `StringBuffer<>` over raw allocate-and-concatenate
- **category**: Coding style / memory
- **rationale**: vuvova flags hand-rolled buffer math in server code.
- **examples**:
  - PR4618 (vuvova, sql_show.cc:6655): "use `StringBuffer<>` instead"
  - PR4618 (vuvova, :6654): "add a comment, why `+ 1`"
- **frequency**: 1 PR but echoed multiple lines
- **severity**: important
- **applies_to**: `sql/*`

### Correctness

#### Validity checks belong in the `check` sysvar callback, not the `update` callback
- **category**: Correctness / plugin API
- **rationale**: vuvova: validating in `update` is the wrong layer.
- **examples**:
  - PR4633 (vuvova, server_audit.cc:2361): "validity checks must be done in the `check` callback, not in the `update` callback"
- **frequency**: 1 strong instance, broadly applicable
- **severity**: important
- **applies_to**: plugins exposing sysvars

#### Unsynchronised reads of pointer-to-string sysvars are unsafe
- **category**: Correctness / threading
- **rationale**: gkodinov flags that complex sysvars (string pointers) need RW locking before/after dereference.
- **examples**:
  - PR4633 (gkodinov, server_audit.cc:273): "This is not a thread safe access to a global variable of type string pointer and the data it points to! While doing it this way is fine for simple types (up to a native CPU word aligned: 2 or 4 usually). It's definitely not ok to do unsynchronized reads on..."
  - PR4633 (gkodinov, :1198): walks through the correct lock-sequence pattern
- **frequency**: 2 instances on same PR
- **severity**: blocker
- **applies_to**: `plugin/*`, any sysvar-backed buffer

#### Don't trust input lengths — validate against the packet remainder
- **category**: Correctness / security
- **rationale**: A class of CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA / auth bugs led to repeated guidance on bounds checking.
- **examples**:
  - PR4534 (vuvova, sql_acl.cc:13631): "may be `if (len > end - passwd)` ?"
  - PR4534 (vuvova): suggests combining `CLIENT_SECURE_CONNECTION` branches to make the bounds logic single-source
  - PR4509 (gkodinov, sql_acl.cc:13866): "This will only work for clients that send in CLIENT_PLUGIN_AUTH_LENENC_CLIENT_DATA set..."
  - PR4534 (vuvova, sql_acl.cc:13817): "I'd keep using `strlen` here. `strnlen` is `_POSIX_C_SOURCE >= 200809L` or `_GNU_SOURCE` ... we don't rely on strnlen elsewhere."
- **frequency**: 4 instances across 2 PRs
- **severity**: blocker
- **applies_to**: `sql/sql_acl.cc`, packet parsing

#### NULL vs empty-string semantics: distinguish "no value" from "value is empty list"
- **category**: Correctness / SQL semantics
- **rationale**: vuvova: returning NULL when the concept is applicable but the list is empty is wrong; return empty string.
- **examples**:
  - PR4618 (vuvova, sql_show.cc:6663): "NULL generally means that there can be no create options ... the list is simply empty, I'd expect an empty string here, not NULL"
  - PR4606 (gkodinov, ha_mroonga.cpp:941): "I do not quite like the silent substitution of NULL with 'off'. IMHO, if you don't want NULLs as arguments, then reject these."
- **frequency**: 2 instances
- **severity**: important
- **applies_to**: `sql/*`, plugin sysvars

#### Don't set a column to not-null when its definition already disallows NULL
- **category**: Correctness
- **rationale**: vuvova: `set_notnull()` is redundant for non-nullable columns.
- **examples**:
  - PR4618 (vuvova, sql_show.cc:7507): "It seems you forgot to remove `table->field[17]->set_notnull();` ... if it's not [nullable], you don't need to set it to not null, it's already and always not null."
  - PR4618 (vuvova, :10129): "not nullable (same below)"
- **frequency**: 2 instances on same PR
- **severity**: nit
- **applies_to**: `sql/sql_show.cc`

### API / Architecture

#### Use existing service APIs rather than `strftime` and other libc paths
- **category**: API / architecture
- **rationale**: Plugins must use server-provided services (e.g. `thd_gmt_sec_to_TIME`, `thd_TIME_to_str`) so they share the server's time-zone semantics.
- **examples**:
  - PR4633 (vuvova, server_audit.cc:291): "Big issue: don't use strftime. The server already has date-to-string formatting functions..."
  - PR4633 (vuvova, item_timefunc.cc:1372): "The service is good. How you use it is good. It is very correct to pass NULL as the thd here..."
- **frequency**: 2 instances on same PR
- **severity**: blocker
- **applies_to**: `plugin/*`

#### Use the project's IO abstraction (`ds_open`, `ds_write`, `dst_close`) in mariabackup, not raw `fopen`/`fprintf`
- **category**: API / architecture
- **rationale**: gkodinov pointed out `fprintf("%s",...)` is "a less performant equivalent to fwrite(). NEVER use that."
- **examples**:
  - PR4605 (gkodinov, backup_copy.cc:1935-1947): "I'd use ds_open() instead and not the C LIB FILE functions." / "I'd use ds_write() here" / "I'd use dst_close() here" / "close does flush. No need to do it separately." / "fprintf("%s", ...) is a less performant equivalent to fwrite(). NEVER use that."
- **frequency**: 5 line comments on one PR
- **severity**: blocker
- **applies_to**: `extra/mariabackup/*`

#### Reuse existing error codes, especially the generic `ER_STD_INVALID_ARGUMENT`, rather than minting hyper-specific ones
- **category**: API / architecture / errors
- **rationale**: vuvova: avoid creating "patently stupid" error messages copied from MySQL; prefer the generic standard-error code.
- **examples**:
  - PR4569 (vuvova, item_func.cc:2033): "This patently stupid error message came from MySQL where it should've never been added in the first place. We shouldn't use it ... Please use `ER_STD_INVALID_ARGUMENT` which we consistently use for cases like this."
  - PR4569 (vuvova, func_math.result:50): "Let's not create too many very specific errors."
- **frequency**: 2 instances on same PR
- **severity**: important
- **applies_to**: `sql/share/errmsg-utf8.txt`, `sql/item_*.cc`

#### Don't change the user-visible width of a digest column without thinking about backward compat
- **category**: API / compatibility
- **rationale**: vuvova on the MD5 -> XXH3 swap: "keep it at 32 here. It'd be good to know that existing applications (that query and, perhaps, temporarily store these digests) will continue to work."
- **examples**:
  - PR4573 (vuvova, check_digest.inc:6): "let's keep it at 32 here ... existing applications ... will continue to work"
  - PR4573 (vuvova, sql_digest.cc:162): suggests `XXH3_128bits` because "it has the same width as md5, so less changes and ... same chance of collisions as before."
- **frequency**: 2 instances on one PR
- **severity**: important
- **applies_to**: anything user-visible (P_S, INFORMATION_SCHEMA)

### Build / CMake

#### Guard new linker flags with `check_linker_flag` and the right CMake minimum-version check
- **category**: Build / CMake
- **rationale**: vaintroub: "Check that this linker option is valid, before using it (e.g with check_linker_flag), I believe it might be missing in older Xcode."
- **examples**:
  - PR4522 (vaintroub, cmake/mysql_add_executable.cmake:36): "use add_link_options ... Check that this linker option is valid"
  - PR4522 (vaintroub, mysys/CMakeLists.txt:199): "CHECK_LNKER_FLAG needs CMake 3.18, thus CMAKE version check needs to be VERSION_GREATER_EQUAL '3.18'"
- **frequency**: 3 instances on same PR
- **severity**: important
- **applies_to**: `CMakeLists.txt`, `cmake/*`

#### Don't depend on platform-specific kernel features without runtime/madvise checks
- **category**: Build / OS portability
- **rationale**: vaintroub: `MAP_POPULATE` "hides errors, it is the best effort. Either use appropriate madvise(MADV_POPULATE_{READ|WRITE}) ... Else, we can live without special option for Linux..."
- **examples**:
  - PR4674 (vaintroub, ha_innodb.cc:3810): "Either you need to test whether grow and shrink work with large pages, or leave appropriate comment that you could not test"
  - PR4674 (vaintroub): MAP_POPULATE rejection
  - PR4674 (vaintroub): notes 32-bit constraints on ASLR/virtual address space
- **frequency**: 3 instances on same PR
- **severity**: important
- **applies_to**: `storage/innobase/*`

### Documentation / Comments

#### Add a comment when code reads as a clever no-op (e.g. `nr = 0.0` to canonicalise -0)
- **category**: Documentation / comments
- **rationale**: vuvova: surprising-but-correct code needs a one-liner explaining why.
- **examples**:
  - PR4632 (vuvova, sql/field.cc:4709): "may be with a comment? Like `if (nr == 0.0) nr= 0.0; // correct negative zero` otherwise looks very confusing"
  - PR4517 (spetrunia, sql_select.cc:22717): "Please add a comment like 'We can end up with a zero-length index for (SELECT '' as col FROM t1) as DT. Such indexes are not allowed for regular tables ...'"
  - PR4618 (vuvova, sql_show.cc:6654): "add a comment, why `+ 1`"
- **frequency**: 3 instances
- **severity**: nit
- **applies_to**: any C/C++

#### Don't strip code comments because their dependent prose elsewhere
- **category**: Documentation / comments
- **rationale**: vuvova fixed wording on the audit plugin docstring for the sysvar.
- **examples**:
  - PR4633 (gkodinov, server_audit.cc:283): provides exact wording: "a format string used to print the timestamp into the audit log messages..."
  - PR4633 (vuvova, server_audit_timestamp.test:23): "you can now remove references to the 'system strftime' from comments"
- **frequency**: 2 instances on same PR
- **severity**: nit
- **applies_to**: `plugin/*`

### Process / Workflow

#### "Preliminary" review vs "final" review is a two-stage protocol
- **category**: Process / workflow
- **rationale**: gkodinov runs all contributor PRs through a preliminary review pass, then defers to a domain expert ("final reviewer"). This is the dominant review structure for external PRs.
- **examples**:
  - PR4569, PR4549, PR4601, PR4605, PR4632, PR4633, PR4641, PR4658, PR4669, PR4678, PR4680, PR4684, PR4686, PR4688, PR4691, PR4697 — all show "This is a preliminary review" / "Please stand by for the final review" pattern (36 explicit mentions of "preliminary review" by MEMBER reviewers).
- **frequency**: 36+ instances
- **severity**: important (informational)
- **applies_to**: any external contributor PR

#### Stale-PR closure after ~3 weeks of no contributor response
- **category**: Process / workflow
- **rationale**: gkodinov closes inactive PRs.
- **examples**:
  - PR4497 (gkodinov): "No reply to my review for more than 3 weeks. Closing the PR. Please re-open and address my review comments if you intend to resume working on this"
- **frequency**: 1 explicit instance, but a clear policy signal
- **severity**: important
- **applies_to**: every PR

#### Open / link a JIRA ticket; PR title must start with MDEV-NNNNN
- **category**: Process / workflow
- **rationale**: gkodinov: "processing on our end would be faster if there was a jira filed and mentioned in the topic."
- **examples**:
  - PR4691 (gkodinov): "processing on our end would be faster if there was a jira filed and mentioned in the topic. I did that for you now. But it takes some time for me."
  - PR4534 (gkodinov): "Please use https://jira.mariadb.org/browse/MDEV-38550 instead of the original one."
  - PR4590 (gkodinov): "it also feels like we need a new MDEV for this. Can you please open one with a good description?"
  - PR4508 (grooverdan): "Commit message title should be: MDEV-37908: Replace KB links with MariaDB Documentation links"
- **frequency**: 4 instances
- **severity**: blocker
- **applies_to**: every PR

#### Don't bundle unrelated changes — split into separate commits / PRs
- **category**: Commit hygiene / process
- **rationale**: vuvova: "It's mainly important to have COM_CHANGE_USER changes in a separate commit ... after you push PRs won't matter anymore, the history only contains commits, not PRs."
- **examples**:
  - PR4509 (vuvova): "It's mainly important to have COM_CHANGE_USER changes in a separate commit (and they were)"
  - PR4522 (gkodinov): split unrelated linker / bison / sprintf migrations into separate PRs
  - PR4557 (spetrunia): "What's the above? why in this patch?" / "It's moved from .cc file. But why?"
  - PR4573 (vuvova, perfschema/pfs_column_types.h:64): "not really related to the MD5->XXH3_128bit change, but ok, whatever"
  - PR4697 (gkodinov): "Just please remove or explain seemingly unrelated changes."
- **frequency**: 5 instances
- **severity**: important
- **applies_to**: any PR

#### Don't restart the server multiple times in a test — combine option setups
- **category**: Testing / performance
- **rationale**: vuvova: "restarting the server takes time, better to keep the number of restarts to the minimum"
- **examples**:
  - PR4633 (vuvova, server_audit_timestamp.opt:4): "adding `--server-audit-timestamp-format=CMD-LINE-%Y-%m-%d` here in the .opt file. ... restarting the server takes time, better to keep the number of restarts to the minimum"
- **frequency**: 1 strong instance
- **severity**: nit
- **applies_to**: `mysql-test/*`

## Notable Anti-Patterns

- **Unsynchronised global string-pointer read** (PR4633, plugin/server_audit/server_audit.cc:273) — reading both the pointer and pointee without a lock. Correction: take the rw_lock around the value, copy into a thread-local buffer, release lock before doing anything else. (gkodinov)
- **Validity check in `update` sysvar callback** (PR4633, server_audit.cc:2361) — must be in `check`. (vuvova)
- **Reusing `update` callback to mutate the sysvar's own storage** (PR4633, :2372) — the server already does this assignment; the plugin shouldn't.
- **Off-by-one in old-protocol auth path** (PR4509, sql/sql_acl.cc:13866) — `+1` was correct for clients lacking `CLIENT_SECURE_CONNECTION`. The fix accidentally trimmed it.
- **Using `strnlen` where the buffer is already NUL-terminated by the read function** (PR4534, sql_acl.cc:13817) — vuvova: "In MariaDB the read function zero-terminates the packet, we don't rely on strnlen elsewhere... better to avoid the question altogether."
- **`fprintf("%s", str)` instead of `fwrite`** (PR4605, backup_copy.cc:1940) — "NEVER use that."
- **`MAP_POPULATE` for "make this resident"** (PR4674) — hides errors; use `madvise(MADV_POPULATE_*)`.
- **Negative-zero leaking through arithmetic** (PR4632) — fixing the printer (dtoa) alone is insufficient; the optimiser groups -0 and +0 differently.
- **Whitespace-only edits in unrelated lines** (PR4581, PR4508, PR4633) — these signal an editor that re-saved the file with different settings.
- **Patently-stupid error string copied from MySQL** (PR4569) — vuvova insists on `ER_STD_INVALID_ARGUMENT` instead of mint-new specific codes.
- **Test that exercises a different code path from the bug being fixed** (PR4549, mysqldump-system-collation.test:38) — "your test is about re-defining the mysql.users view ... do you think this re-creates the problem at all?"
- **Editor that "damages characters it cannot recognize"** in result files (PR4581, show_explain.result:1342) — characters in tests must be UTF-8 clean.
- **`my_strdup` of a value that's still owned by another path** (PR4606, ha_mroonga.cpp:943) — would leak / double-free under `PLUGIN_VAR_MEMALLOC`.
- **Two-records-needed to avoid "1-row table is const table" path** in optimizer tests (PR4505) — `spetrunia`'s reminder.
- **Stack buffer too large in a contended path** (PR4633, :1116) — 256 bytes on stack inside a lock; pull it out, allocate outside the lock.
- **Asymmetric printing in JSON tracer** (PR4505, opt_range.cc) — must print both `key1_*` and `key2_*` fields the same way.
- **Submitting a patch authored by someone else without credit** (PR4688) — confirmed by grooverdan as a hard policy violation.

## Workflow / Process Signals

- **Two-stage review**: gkodinov / grooverdan often act as preliminary reviewers and explicitly hand off to a "final reviewer" (Sergei Golubchik / area expert). Expect a "preliminary review" header on the first MEMBER review of an external PR.
- **CLA bot must report signed** before approval (PR4493, PR4601, PR4605, PR4618). Without the bot's confirmation, even an approving review will be paused.
- **MDEV-NNNNN in PR title and commit message** is mandatory; reviewers will open a JIRA ticket on behalf of the contributor if missing (PR4691).
- **Target branch**: bug fixes go to "the earliest maintained branch in which the bug can be reproduced." Currently: 10.6 only for critical bugs; 10.11 default for non-critical bugs; main for features only. The branch is decided early and pushed back to the contributor (PR4534, PR4569, PR4602, PR4606, PR4680, PR4688).
- **Single squashed commit** is a precondition for merge (PR4509, PR4569, PR4602, PR4625, PR4630, PR4633, PR4653, PR4658, PR4664, PR4669, PR4678, PR4697).
- **Force-push the squashed/rebased version to the same branch** (PR4508, PR4658) — do not open a new PR for the same change.
- **Buildbot must be green** on all platforms before final approval (PR4534, PR4549, PR4569, PR4590, PR4632, PR4641, PR4658, PR4697). Specifically watch Windows builds (PR4509, PR4641).
- **Don't auto-bump submodules** in an unrelated PR (PR4557, extra/wolfssl) — spetrunia flagged a wolfssl bump that was unrelated to the patch.
- **Inactive PRs are closed after ~3 weeks** (PR4497).
- **Codership/Galera is now a MariaDB property** but development happens externally (PR4536, PR4689) — be cautious adding labels referring to deprecated org names.
- **AI / LLM disclosure** indirectly raised (PR4589): "I can ask an LLM myself, no need to do it for me." Reviewers expect contributors to substantiate suggestions with benchmarks/justification rather than LLM-generated arguments.
- **MEMBER-level merge etiquette**: when a domain expert and a preliminary reviewer disagree, the final reviewer (Sergei) decides (PR4619, PR4601, PR4632).
- **"Bug-test first, fix second" workflow** is emerging — DaveGosselin-MariaDB cites a "Recommended MariaDB Git workflow 2026" document: one commit adds the failing test; the next commit fixes it and updates the result.
- **Don't make decisions about cross-cutting refactors (e.g. sprintf→snprintf) in one big-bang PR** — iterate per area (PR4522). When a reviewer asks "is there anything wrong with the changes proposed?", a back-and-forth on scope is expected.

## Singletons Worth Noting

- **`if (0) { ... }` trick** to wrap a disabled test block creating a smaller diff (PR4519, vuvova).
- **Use `RENAME TABLE` to swap-in/swap-out a custom-collation `mysql.role_edges` table** instead of DROP+RECREATE in a test (PR4549, grooverdan).
- **`condition_pushdown_from_having` is not the same as the issue** — be precise about which optimiser switch your reproducer touches (PR4687, spetrunia).
- **Reduce nested template-style copy methods** — `clone_item` → `clone_constant` rename was required to make the semantics explicit (PR4557, spetrunia).
- **`%TZH` / `%TZM` for timezone hours/minutes** is the Oracle / Postgres convention; MariaDB should align (PR4619, gkodinov / vuvova).
- **`include/my_dbug.h already defines DBUG_ASSERT as a no-op`** — don't add redundant guards (PR4688, grooverdan).
- **Triggers vs configure in Debian postinst** — for galera package, use `triggers` to react to mariadb-server state changes (PR4644, vuvova/grooverdan, after extensive discussion).
- **`Replaces:` in debian/control** preserves a clean upgrade path when moving files between packages (PR4644).
- **InnoDB free-page logic depends on `freed_ranges`** — don't change the logic for the empty case without justification (PR4495, Thirunarayanan).
- **Lambda for a single-shot loop tail** — spetrunia suggested replacing a lambda with `for (;; last_range= nullptr, file->set_end_range(nullptr))` (PR4687).
- **Read-only transactions must not enter group-commit logic** — vaintroub requested an `ut_ad` assertion in `trx_flush_log_if_needed()` (PR4591).
- **`unreferenced label`** in `strings/ctype.c` when `SIZE_OF_SIZE_T > 8` — guard or remove (PR4570, vaintroub).
- **Mariabackup must not regenerate `mariadb_upgrade_info`** on `--copy-back`; the file must be the one captured at backup time (PR4605, vaintroub).
- **`CPACK_COMPONENTS_ALL` membership controls auto-cnf generation** for plugin packages (PR4644).
- **`StringBuffer<>` for SHOW output** instead of dynamic dynamic-allocation (PR4618).
- **DBUG-library / debug_sync over hand-tuned sleeps and triggers** (PR4669) — but the contributor pushed back on complexity, so it's still a recommendation rather than a rule.
- **"Don't tie `core_file` to a new feature"** — grooverdan wants the legacy `core_file` deprecated; do not entrench it (PR4651).
- **InnoDB asserts about locks across mod_tables are difficult** — partition tables and IS-locks on source make blanket assertions unsafe (PR4636, Thirunarayanan).
