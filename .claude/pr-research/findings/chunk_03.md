## Recurring Patterns

### Commit Hygiene & Process

- **title**: Provide a CODING_STANDARDS.md-compliant commit message with MDEV-NNNNN prefix
  - **category**: Commit hygiene
  - **rationale**: Almost every gkodinov "preliminary review" opens by requesting this. PRs are not merged until the message conforms; reviewers refuse to start substantive review otherwise.
  - **examples**:
    - PR4703 gkodinov: "make the commit message compliant with CODING_STANDARDS.md"
    - PR4707 grooverdan: "Recommendation on commit message: MDEV-21543: Speed up VARCHAR pad space handling in multibyte collations (fix)..."
    - PR4713/4714/4731/4737/4743/4793/4810/4811/4830/4869/4881 gkodinov: identical refrain
  - **frequency**: many (11+ direct CODING_STANDARDS mentions, ~29 commit-message comments)
  - **severity**: blocker
  - **applies_to**: every PR

- **title**: Squash multiple commits into a single commit before merge
  - **category**: Commit hygiene
  - **rationale**: Reviewers consistently require one logical change = one commit. Fixup commits during review are fine but must be squashed at the end.
  - **examples**:
    - PR4706 gkodinov: "Please squash the two commits together and look at the vector2 failure in buildbot."
    - PR4737 gkodinov: "Please squash all of your commits into a single one"
    - PR4764 gkodinov: "LGTM after you squash the two commits into a single one."
    - PR4808/4829/4869/4881: same request
  - **frequency**: many (10+)
  - **severity**: blocker

- **title**: Rebase instead of merging the base branch into your PR
  - **category**: Commit hygiene
  - **rationale**: Merge commits clutter history. Project policy is rebase-only.
  - **examples**:
    - PR4703 sanja-byelkin: "Please rebase (we do not need merge dommits) and OK to push"
    - PR4703 sanja-byelkin: "The patch is OK, but please rebase it (we do not need additional merge commits with no sense)"
  - **frequency**: 2-3 instances
  - **severity**: blocker

- **title**: Target the lowest still-supported affected branch (usually 10.11), not main
  - **category**: Process / branch targeting
  - **rationale**: Bug fixes must go into the earliest maintained branch so they propagate up through merges. main/12.x-only PRs that fix older bugs are always sent back.
  - **examples**:
    - PR4706 gkodinov: "This looks like a bug fix... Since vector is introduced in 11.8, can you please rebase on this?"
    - PR4731 gkodinov: "Please rebase to 10.11: this is enhanced test coverage and as such it should go to the earliest maintained version"
    - PR4752/4766/4793/4804/4858/4869/4872/4881 gkodinov: "this is a bug fix. Please rebase to 10.11"
    - PR4789 gkodinov: "If this fails in 10.6 I'd suggest using 10.6 as a base: it is severe enough I believe."
  - **frequency**: many (15+)
  - **severity**: blocker

- **title**: Sign the CLA / make the CLA bot green before merge
  - **category**: Process / workflow
  - **rationale**: Required for legal acceptance of contribution; reviewers may LGTM but cannot merge without it.
  - **examples**:
    - PR4703 gkodinov: "click on the CLA bot button on the PR github page"
    - PR4712 gkodinov: "PLEASE, sort out the CLA bot. It needs to be green for us to accept the contribution."
    - PR4779 gkodinov: "Please sort out the CLA bot : click on the button and choose the right license."
    - PR4881 gkodinov: "sign the CLA please: either pick BSD or MariaCLA."
  - **frequency**: many (~20 mentions)
  - **severity**: blocker

- **title**: Don't include license text or third-party-tooling references in commit messages
  - **category**: Commit hygiene
  - **rationale**: License decisions live in the CLA, not commit messages.
  - **examples**:
    - PR4703 gkodinov: "remove the license reference from the commit message"
    - PR4869 gkodinov: "Thank you for attempting to fix this. Unfortunately, it's not as simple as letting some AI do it."
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Two-stage review: preliminary by gkodinov, then a "final reviewer" for the area
  - **category**: Workflow
  - **rationale**: gkodinov runs an explicit triage pass on virtually every external contributor PR ("This is a preliminary review... please stand by for the final review"). Future contributions should expect this and not push to merge until the area expert (e.g. midenok for ALTER, vuvova for vector/grants, Marko for InnoDB, Sergei P. for optimizer) signs off.
  - **examples**:
    - PR4703/4706/4707/4710/4711/4712/4713/4714/4715/4731/...: identical "This is a preliminary review" boilerplate
    - PR4779 gkodinov: "Please... work with the assigned final reviewer."
    - PR4860 gkodinov: "Please rebase on 10.11 as Daniel requested. Other than that: LGTM. I like the approach."
  - **frequency**: many (~39 mentions)
  - **severity**: important (process expectation)

- **title**: Make buildbot green before requesting re-review
  - **category**: Process / CI
  - **rationale**: Reviewers refuse to merge with red buildbot; PR authors are expected to investigate and fix CI failures themselves, including platform-specific ones.
  - **examples**:
    - PR4706 gkodinov: "this is how your test is failing on the build-bot"
    - PR4712 gkodinov: "There are some test failures after your push: mostly tests that need re-recording it seems. Can you please fix that..."
    - PR4731 grooverdan: "And notably correct the Windows compiling error"
    - PR4779 gkodinov: "There are failing tests after the application of Alexey's diff. Can you please take a look?"
    - PR4811 gkodinov: "Please address the buildbot issues."
    - PR4869 gkodinov: "buildbot compile still failing. Please have a look."
  - **frequency**: many (~24)
  - **severity**: blocker

- **title**: Re-request review in GitHub after pushing fixes
  - **category**: Process / workflow
  - **rationale**: Reviewers won't auto-notice new pushes.
  - **examples**:
    - PR4793 gkodinov: "for future reference, re-request my review in github when you submitted a new changeset. This is what has caused the delay."
  - **frequency**: 1 instance (but stated as a general expectation)
  - **severity**: nit

### Testing / MTR

- **title**: Every bug-fix PR must include an MTR regression test
  - **category**: Testing / MTR
  - **rationale**: "Please add a test" is a standing requirement. The exact case from the JIRA must be reproducible by the test.
  - **examples**:
    - PR4717 dr-m: "There was a nice simple test case posted at the start of MDEV-38928. Please include it in the regression test suite."
    - PR4739 gkodinov: "Please add test cases that cover the two queries that are mentioned in the jira."
    - PR4743 gkodinov: "Would SUPER allow SHOW CREATE SERVER? If it would, please document that into the Jira and the commit message. And also add tests please."
    - PR4752 gkodinov: "this is a bug fix. So please re-base on the first affected version... Secondly: please add a test."
  - **frequency**: many
  - **severity**: blocker

- **title**: End test files with `--echo # End of <branch> tests` (one line, no trailing blank)
  - **category**: Testing / MTR
  - **rationale**: Sentinel makes upward merges trivial. Reviewers reject 3-line decoration blocks.
  - **examples**:
    - PR4710 grooverdan: "now that its rebased - 11.8 the end."
    - PR4711 grooverdan: "The final statement in a test case is ``--echo End of 13.0 tests``. For the purpose of ease of merging..."
    - PR4714 grooverdan: "move this added test to below the `End of 11.7 tests` line, add a `End of 11.8 tests`..."
    - PR4743 vuvova: "one line for the end marker, not three. Just ``--echo # End of 11.8 tests``"
    - PR4810/4811/4829/4874 same
  - **frequency**: many (~18)
  - **severity**: important

- **title**: Always terminate the last line of a test file with a newline
  - **category**: Testing / MTR
  - **rationale**: Git complains, and trailing-newline policy is uniform.
  - **examples**:
    - PR4810 gkodinov: "please always terminate the last time of tests."
    - PR4829 gkodinov: "Please always terminate the last line of a test file."
    - PR4867 sanja-byelkin: "git complains about incorrect test file end"
  - **frequency**: 3+ instances
  - **severity**: important

- **title**: Begin a new test section with an `--echo # MDEV-NNNNN` header (echo, not comment)
  - **category**: Testing / MTR
  - **rationale**: Visible in result file; aids grep and diagnosis.
  - **examples**:
    - PR4711 grooverdan: "The MDEV header below should be echo statements."
    - PR4739 grooverdan: "A test header should be included. ``--echo # --echo # MDEV-35548] UBSAN:...``"
    - PR4789 grooverdan: "I'd move this test to part of mysql-test/main/create.test at end, with a : ``--echo # --echo # MDEV-x....``"
    - PR4804 gkodinov: "we customarily start with a heading stating the MDEV."
    - PR4829 grooverdan: "this would be an `--echo # MDEV....` line. Include a `--echo #` before and after to make this stand out."
  - **frequency**: many
  - **severity**: important

- **title**: Prefer extending existing test files over creating new ones for one-line cases
  - **category**: Testing / MTR
  - **rationale**: Avoids test-suite bloat; many-engine combos already exist (vector.test).
  - **examples**:
    - PR4706 vuvova: "Could you please move the test to vector.test? no need to create a new small test file and a new combination file."
    - PR4711 grooverdan: "This doesn't use or implement any specific innodb features so this can be removed."
    - PR4789 grooverdan: "I'd move this test to part of mysql-test/main/create.test at end"
    - PR4811 grooverdan: "Can the relevant parts of this be moved to ./mysql-test/suite/compat/oracle/t/func_to_date.test towards bottom"
  - **frequency**: 4+ instances
  - **severity**: important

- **title**: Prefix test files with their subsystem (mysql_, binlog_, …) so `--do-test` selectors work
  - **category**: Testing / MTR
  - **rationale**: Allows category-level test running and easier discovery.
  - **examples**:
    - PR4710 gkodinov: "Prefix the file name with the subsystem name please. In this case: mysql_ (we do this so that we can run all relevant tests with --do-test)."
    - PR4766 gkodinov: "All the files in this suite are prefixed with 'binlog_'. ... I'd add a suffix saying what's actually tested."
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Use DEBUG_SYNC, not sleep, for synchronization in tests; guard with have_debug
  - **category**: Testing / MTR
  - **rationale**: Sleeps are flaky on slow CI; sync points are deterministic. Tests must skip cleanly on non-debug builds.
  - **examples**:
    - PR4765 grooverdan: "A sleep statement is ok for validating a test, but as production test it should be a sync point. `DEBUG_SYNC(thd, "select_send_after_sending_eof");`"
    - PR4765 grooverdan: "`--source include/have_debug.inc` needed or `have_debug_sync.inc` if a debug sync implementation is used."
    - PR4765 dr-m: "I'd add both, so that the test will be more efficiently skipped on non-debug builds."
    - PR4804 vaintroub: "I do not see why this sleep is necessary... SELECT SLEEPs in foreground is not very good, adds up to test run, and increased CI times."
  - **frequency**: 4+ instances
  - **severity**: important

- **title**: Re-run `mtr --record` and verify locally before pushing the result file
  - **category**: Testing / MTR
  - **rationale**: Lots of broken result files in submissions. Reviewers refuse to chase recordings.
  - **examples**:
    - PR4706 gkodinov: "Please don't just copy the lines. Please compile and actually run the test before pushing a new version."
    - PR4711 grooverdan: "After adding a test case like this, `mtr --record` and then commit"
    - PR4712 gkodinov: "there's more tests to re-record. Please check the buldbot: it must be clean"
    - PR4829 grooverdan: "Create the `result` file by doing a `mtr --record plugins.feedback_os_release` and then manually validate"
  - **frequency**: many (4+ in this chunk)
  - **severity**: blocker

- **title**: Use generous timeouts (1 min, not seconds) in MTR waits; CI machines are slow
  - **category**: Testing / MTR
  - **rationale**: Short timeouts cause flaky failures on overloaded CI.
  - **examples**:
    - PR4804 vaintroub: "I don't know if timeout 2 is always enough, given overloaded CI machines."
    - PR4874 gkodinov: "what if 120 is not enough? ... yes, that would be better."
    - PR4874 gkodinov: "do 1 min here please. We have some slow test machines ;)"
  - **frequency**: 3+
  - **severity**: important

- **title**: Don't redundantly print warnings the test driver already prints
  - **category**: Testing / MTR
  - **rationale**: Avoid noise.
  - **examples**:
    - PR4769 gkodinov: "it looks like the test driver already prints warnings if any. No need to print these again."
  - **frequency**: 1 instance (but matches general policy)
  - **severity**: nit

- **title**: Drop tables / remove temp files at end of test (clean up after yourself)
  - **category**: Testing / MTR
  - **rationale**: Otherwise tests leak state between runs.
  - **examples**:
    - PR4710 grooverdan: "There should be a `DROP TABLE t` to clean up here."
    - PR4829 gkodinov: "We also clean up after the test. Please add `--remove_file $MYSQLTEST_VARDIR/tmp/skip_test.inc`"
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Use server-side substitutes (com_ping, --ping) instead of brittle sleeps when probing connection state
  - **category**: Testing / MTR
  - **rationale**: Sleeps are nondeterministic; ping is portable.
  - **examples**:
    - PR4765 grooverdan: "can use com_ping... `--ping`"
  - **frequency**: 1 (but reiterated)
  - **severity**: nit

### Coding Style

- **title**: Don't introduce a local boolean when an inline condition reads fine
  - **category**: Coding style (InnoDB)
  - **rationale**: dr-m repeatedly prunes intermediate booleans.
  - **examples**:
    - PR4717 dr-m: "As far as I understand, there is no need to introduce the local variable `is_temp`. We can simply check that condition first..."
    - PR4717 dr-m: "We don't seem to need this brace, because no local variables are being introduced."
  - **frequency**: 2 instances
  - **severity**: nit

- **title**: Use the constructor-style cast `unsigned(x)` / `uint16(x)` rather than `static_cast<unsigned>(x)` or C-style casts in C++ code
  - **category**: Coding style (InnoDB / C++)
  - **rationale**: Shorter, idiomatic for InnoDB; avoid C-style casts in C++.
  - **examples**:
    - PR4717 dr-m: "`unsigned(` would be shorter than `static_cast<unsigned>(`."
    - PR4797 dr-m: "`uint32_t(n)` is equivalent and nicer to read."
    - PR4783 dr-m: "I would suggest to avoid C-style casts in C++ code. A constructor-style cast would be shorter too: `uint16(val * prec_fact...)`"
  - **frequency**: 3 instances
  - **severity**: nit

- **title**: Drop redundant `inline` keyword when function is defined in header at declaration
  - **category**: Coding style (C++)
  - **rationale**: "The `inline` keyword is only necessary when there is a declaration of something that will be defined separately with `inline` linkage."
  - **examples**:
    - PR4717 dr-m: "The function is being defined `inline` elsewhere, but this declaration is missing an `inline` keyword."
    - PR4717 dr-m: "If there is a combined declaration and definition... we usually omit the `inline` keyword because it is redundant."
  - **frequency**: 2 instances
  - **severity**: nit

- **title**: Reorder branches so the rare path is the body, the common path is the fall-through
  - **category**: Coding style / performance
  - **rationale**: Better branch prediction; locality of common code; dr-m suggests "check the less likely condition first".
  - **examples**:
    - PR4717 dr-m: "Generally, I think that it would be better to check the less likely condition first. ALTER IGNORE TABLE should be less likely to be invoked than any operation on temporary tables."
    - PR4858 dr-m: "Can we make a separate loop for the rare online DDL case?... Only the likely case would be handled inline here"
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Prefer bitwise `|` / `&` instead of `||` / `&&` to avoid conditional branches in hot paths
  - **category**: Performance / coding style (InnoDB)
  - **rationale**: Compiler emits a branch for short-circuit; bitwise stays in registers.
  - **examples**:
    - PR4707: PR title itself: "use bitwise `&` to fix build error on amd64-msan-clang-20-debug"
    - PR4717 dr-m: "Instead of using short-circuit evaluation, we could use bitwise arithmetics and therefore avoid introducing a conditional jump."
    - PR4858 dr-m: "if (v_cols[num_v].m_col.ord_part | old_v_cols[num_v].m_col.ord_part) // bitwise | to avoid conditional branch"
  - **frequency**: 3 instances
  - **severity**: important (InnoDB hot paths)

- **title**: Cache repeatedly-read bit-field values in a local
  - **category**: Performance / coding style (InnoDB)
  - **rationale**: Bit-field reads are not trivial; reading multiple times bloats codegen.
  - **examples**:
    - PR4717 dr-m: "`m_prebuilt->table->skip_alter_undo` is a bit-field. Because we are reading it multiple times in this code path, it would make sense to assign the value to a local variable during the first access."
  - **frequency**: 1 instance
  - **severity**: nit (but principled)

- **title**: Don't quote MDEV-NNNNN with backticks in code comments
  - **category**: Coding style
  - **rationale**: Plain text is sufficient.
  - **examples**:
    - PR4711 gkodinov: "you can skip quoting the mdev number here." (×3 on same PR)
  - **frequency**: 3 instances in PR4711
  - **severity**: nit

- **title**: Don't repeat MDEV title in code comments; trust git blame
  - **category**: Coding style
  - **rationale**: Source comments should focus on the why; bug-id is recoverable from git.
  - **examples**:
    - PR4811 grooverdan: "Listing MDEV and title in code comment not desirable. Focus on the message. There's git blame if people want to look it up."
  - **frequency**: 1 instance
  - **severity**: nit

- **title**: Use `ELSEIF`, not `ENDIF()` + new `IF()`, in CMake
  - **category**: Coding style (CMake)
  - **rationale**: Cleaner, fewer scopes.
  - **examples**:
    - PR4872 vaintroub: "ELSEIF() please, instead of ENDIF() and new IF(). And, please can use longer strings."
  - **frequency**: 1 instance
  - **severity**: nit

- **title**: Drop redundant parentheses (e.g. around shift in `a | (b << c)`, around `sizeof` of expression)
  - **category**: Coding style
  - **rationale**: Standard precedence is unambiguous; consistent with surrounding code.
  - **examples**:
    - PR4783 dr-m: "There is no need to add parentheses around the shift: `a | b << c` is the same as `a | (b << c)`."
    - PR4824 dr-m: "The parentheses after `sizeof` are only needed when the argument is a name of a type."
  - **frequency**: 2 instances
  - **severity**: nit (vaintroub pushed back on the shift one)

### Correctness / Memory / Buffer-handling

- **title**: When replacing sprintf with snprintf, pass the *actual* buffer size as a parameter; don't guess
  - **category**: Correctness (buffer overflows)
  - **rationale**: MDEV-39173 was driven by AI-generated patches that hard-coded buffer sizes. gkodinov's repeated review note: hardcoded constants are wrong; the size belongs as a function parameter.
  - **examples**:
    - PR4869 gkodinov: "That's not how you do this! It's about the size of the receiving buffer."
    - PR4869 gkodinov: "I'd take the size as a parameter to MYSQL[_BIN]_LOG::generate_new_name."
    - PR4869 gkodinov: "I'd add it as a parameter instead. Right not it's not preventing anything and if I pass a smaller buffer I'd just get a crash"
    - PR4869 gkodinov: "Please add a parameter and use it: there's just 3 calls to this. And 2 of these 3 calls are off by one :)"
    - PR4869 gkodinov: "Unfortunately, it's not as simple as letting some AI do it. You will need to find the actual size of the buffer and then set that as a limit."
    - PR4824 dr-m: "What happens if more than `BINLOG_NAME_MAX_LEN` characters of input is available? Would the `filename` be terminated by `\0`, or could the subsequent `sql_print_information()` call exceed the bounds..."
  - **frequency**: many (15+ in PR4869 alone)
  - **severity**: blocker

- **title**: Replace magic-number lengths with named constants/defines (e.g. for MD5 buffers)
  - **category**: Correctness / coding style
  - **rationale**: Multiple instances of "5"/"32"/"33" buffer constants got flagged. A single named constant prevents drift.
  - **examples**:
    - PR4869 sanja-byelkin: "I see that VIEW_MD5_LEN is 32 and MD5_BUFF_LENGTH is 33 'I'd define the last as (VIEW_MD5_LEN + 1) and wrote that calc_md5 always require the buffer of 33 byte"
    - PR4869 gkodinov: "Optional: it's painful to watch this 255 constant. I'd add a define in mysql_com.h"
    - PR4869 gkodinov: "where does 60 come from?"
    - PR4869 gkodinov: "please use a named const"
  - **frequency**: many (5+ in PR4869)
  - **severity**: important

- **title**: Use `%llu` / `%lld` printf format and remove casts when the type is already `unsigned long long`
  - **category**: Correctness (format specifiers)
  - **rationale**: Avoids redundant casts and platform-mismatched printf args.
  - **examples**:
    - PR4869 gkodinov: "since you are touching on this line, please use %llu and remove the casts."
    - PR4869 gkodinov: "ditto: %llu and cast removal"
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Use mysys wrappers (my_strtol, my_strtod, my_stat, mysql_socket_*) instead of raw libc
  - **category**: API / portability
  - **rationale**: Provides PSI instrumentation, Windows handling, consistent error reporting.
  - **examples**:
    - PR4764 gkodinov: "please use my_strtol."
    - PR4764 gkodinov: "please use my_strtod()"
    - PR4764 gkodinov: "Please fix the msan failure. And also use the mysys functions please."
    - PR4874 gkodinov: "please use the mysys functions. my_stat in this case."
    - PR4874 gkodinov: "Please use mysql_socket_socket. ... please use mysql_socket_connect."
  - **frequency**: many (5+)
  - **severity**: important (but vuvova in PR4874 pushed back on overuse of mysql_ wrappers in mysqld init paths)

- **title**: Initialize output variable to avoid MSAN uninitialized-value diagnostics
  - **category**: Correctness (MSAN)
  - **rationale**: MSAN is part of CI; uninit reads on error paths blow up.
  - **examples**:
    - PR4764 gkodinov: "I believe you need to assign something to *var here. Otherwise msan complains."
  - **frequency**: 1+ (referenced repeatedly throughout PR4764)
  - **severity**: blocker

- **title**: When parsing trailing garbage, accept whitespace and control characters (isspace, iscntrl)
  - **category**: Correctness / compatibility (file parsing)
  - **rationale**: master.info / relay-log.info contain various trailing whitespace; strict parsing causes regressions.
  - **examples**:
    - PR4764 gkodinov: "I'd also allow space and control symbols. basically isspace and iscntrl"
    - PR4764 gkodinov: "ditto here. ... and here. Maybe have a helper function instead of copying the code?"
  - **frequency**: 3 instances in PR4764
  - **severity**: important

- **title**: `recv()==0` means peer closed the socket; do not retry — but it's not always an error in PROXY-protocol parsing
  - **category**: Correctness (networking)
  - **rationale**: vaintroub corrected gkodinov: 0 from recv on a non-zero-byte request is FIN/SHUT_WR, retrying is wrong. Conversely, the original code did treat 0 as an error condition; gkodinov initially thought it should retry. The lesson is to know that 0 = peer-closed for blocking reads.
  - **examples**:
    - PR4881 gkodinov: "this is wrong: you can get a 0 if there's no bytes to read when you call recv(). But there may be more bytes to read later. It needs to keep trying."
    - PR4881 vaintroub: "I think it was correct @gkodinov . 0 is returned from recv if and only if peer closes socket normally (FIN, not RESET)"
    - PR4881 vaintroub: "Nope, this is wrong. 0 is an error condition."
  - **frequency**: 1 thread, many comments
  - **severity**: important (correctness debate, but vaintroub's view prevailed)

- **title**: Use `static_assert` to document numeric magic and catch silent renumbering
  - **category**: Correctness / defensive coding (InnoDB)
  - **rationale**: dr-m repeatedly suggests static_asserts to lock invariants tied to enum values used in bit math.
  - **examples**:
    - PR4717 dr-m: "Add `static_assert` to document what the `2` is about."
    - PR4717 dr-m: "`static_assert(TRX_DML_BULK == 3, ""); static_assert(TRX_DDL_BULK == 2, ""); static_assert(TRX_NO_BULK == 0, ""); static_assert((TRX_DDL_BULK & 1) == 0, "");`"
    - PR4824 dr-m: "we could use the unary form of `static_assert` and reduce the source code line count by 1."
  - **frequency**: 3 instances
  - **severity**: important

- **title**: Use `memcpy()`-based load/store for unaligned access, rely on compiler to fold
  - **category**: Correctness (UBSAN unaligned access) / performance
  - **rationale**: Long debate in PR4783 — dr-m advocated memcpy idiom; vaintroub showed Godbolt evidence that for odd-byte widths the generated code is identical or worse, so memcpy is not blanket-better.
  - **examples**:
    - PR4783 dr-m: "I think that this had better be based on `memcpy()`, along these lines... `memcpy(&ret, p, 5);`"
    - PR4783 vaintroub: "Nope, memcpy with odd length is not better at all... here is the proof https://godbolt.org/z/77T7rE1zM (you could have checked too, before suggesting?)"
  - **frequency**: 4+ instances (one PR, many comments)
  - **severity**: important (and: review suggestions need Godbolt evidence on micro-optimizations)

- **title**: Don't change byte-order semantics under the cover of an unrelated patch; LE swap on a LE path is a bug
  - **category**: Correctness (endianness)
  - **rationale**: dr-m noted a stray MY_BSWAP32 on the LE branch that didn't exist before.
  - **examples**:
    - PR4783 dr-m: "I believe that the line `lo= MY_BSWAP32(lo);` needs to be removed from this little-endian code path, because in `include/byte_order_generic_x86_64.h` there was no equivalent..."
    - PR4783 dr-m: "There is a semantic mistake in all these functions. We are converting from little endian to host byte order, not vice versa. Hence, the invocation should be `return my_letoh16(ret)`"
  - **frequency**: 2 instances
  - **severity**: blocker

### InnoDB-Specific

- **title**: Place hot-path InnoDB functions to minimize register shuffling in AMD64 ABI
  - **category**: InnoDB / performance
  - **rationale**: Functions with 7+ params blow past the 6-register AMD64 calling convention.
  - **examples**:
    - PR4746 dr-m: "The parameters will not fit in the 6 registers that are available in the commonly used AMD64 calling conventions... I would make `mtr, undo_block` the first parameters so that no registers have to be shuffled"
    - PR4746 dr-m: "Please check the generated AMD64 code for `CMAKE_BUILD_TYPE=RelWithDebInfo`."
  - **frequency**: 2 instances
  - **severity**: important (InnoDB hot path)

- **title**: log_checkpoint / FILE_CHECKPOINT discipline: only the buf_flush_page_cleaner thread runs checkpoints; ensure shutdown writes exactly one trailing FILE_CHECKPOINT
  - **category**: InnoDB (redo log)
  - **rationale**: Long discussion in PR4747 about why two threads can't race on a checkpoint slot, and why a final FILE_CHECKPOINT during shutdown is invariant. Future InnoDB redo PRs must respect this invariant.
  - **examples**:
    - PR4747 dr-m: "only the `buf_flush_page_cleaner()` thread can invoke `log_checkpoint()` or `log_checkpoint_low()`."
    - PR4747 dr-m: "This assertion is part of the shutdown. It tries to ensure that the checkpoint runs to completion, that is, recovery will parse nothing more than a single `FILE_CHECKPOINT` record."
  - **frequency**: many (in PR4747)
  - **severity**: blocker

- **title**: InnoDB internal naming convention: `mi_uintNkorr` is big-endian (MyISAM); `uintNkorr` is little-endian; don't mix
  - **category**: InnoDB / MyISAM conventions
  - **rationale**: Naming descends from "korrekt" (innodb sense = big-endian, ulint). Cross-replacing breaks .MYD compatibility.
  - **examples**:
    - PR4783 vaintroub: "mi_uint5korr is not a corresponding function for uint5korr. *mi_* is big endian"
    - PR4797 vaintroub: "uint2korr has an unfortunate naming only descriptive to its creator... 'korrekt' in Innodb sense is big endian, also accepting/returning ulints"
  - **frequency**: 2+ instances
  - **severity**: blocker (subtle wire-format)

- **title**: Avoid invoking non-inline functions inside a hot loop; move the loop into the compilation unit that owns the type
  - **category**: InnoDB / performance
  - **rationale**: Reduce per-iteration cost; keep cross-TU coupling local.
  - **examples**:
    - PR4858 dr-m: "This is invoking a non-inline function in a loop while failing to pass the first parameter as `clust_index`. Can we declare this function inside `row0log.cc` so that the function call inside the loop can be removed?"
    - PR4858 dr-m: "the function `row_log_col_is_indexed()` is only being called here, and the definition is not inline. I think that we should move that entire loop to `row0log.cc`"
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Remove InnoDB "uglification" (.inl files) and prefer C++ inline functions in headers
  - **category**: InnoDB / code modernization
  - **rationale**: dr-m's standing cleanup push: write code directly in headers as inline functions.
  - **examples**:
    - PR4797 dr-m: "While doing this, can we remove all the InnoDB uglification and write the code directly in `mach0data.h` as follows, for all these functions"
    - PR4797 dr-m: "This function is duplicating `uint2korr()`. Can we remove it and replace the calls with calls to `uint2korr()`?"
  - **frequency**: 2 instances
  - **severity**: nit/important (dr-m's modernization direction; vaintroub partially declined)

- **title**: When buffer-pool memory is reserved with `PROT_NONE` + virtual_mem_commit, follow up on the symmetric "extend" path
  - **category**: InnoDB / memory mgmt
  - **rationale**: missing pair-call to my_virtual_mem_commit on extend.
  - **examples**:
    - PR4740 dr-m: "The logical place for this call would be right after the call of `my_virtual_mem_commit()`. I think that we need a similar call when extending the buffer pool."
    - PR4852 dr-m: "This needs to be `std::max` instead of `std::min`. Furthermore, the following error message will have to be suppressed for the failing initial attempt to reserve 8 TiB with `PROT_NONE`"
  - **frequency**: 2 instances
  - **severity**: blocker

### Logging / Errors

- **title**: Use `%iE` (or `%M` on older branches) for printing errno; don't enumerate errno cases by hand
  - **category**: Logging / errors
  - **rationale**: My-error infrastructure already formats; long EACCES/EMFILE switches are noise.
  - **examples**:
    - PR4874 vuvova: "From all possible errors here, as far as I can see, we can only ever get EMFILE, ENFILE, ENOMEM. Either way, mariadbd should abort... So I'd use just `sql_print_error("Cannot create a socket: %iE. Aborting", errno);` note it's `%iE` in 13.0 but `%M` in 10.11"
    - PR4874 vuvova: "Remove the `EACESS` if(), and in the second use `%iE` (or `%M`)"
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Error messages should describe what happened, not blame the wrong thing
  - **category**: Logging / UX
  - **rationale**: Error wording reflects on whole release; vuvova explicitly rewrites them.
  - **examples**:
    - PR4874 vuvova: "This isn't a very helpful error message. From all possible errors here... mariadbd should abort and not because the socket file exists."
    - PR4789 grooverdan: "On commit message, its more than just preventing an assertion, its about giving a error message to the user."
  - **frequency**: 2 instances
  - **severity**: important

- **title**: Function names must describe behavior, not be vague verbs
  - **category**: Naming
  - **rationale**: "handle_x" / generic verbs forbidden in favor of descriptive names.
  - **examples**:
    - PR4874 vuvova: "may be, just a suggestion, `unlink_socket_if_unused()` ? 'handle' doesn't really explain anything. or `unlink_socket_or_abort()`"
    - PR4824 vaintroub: "sizeof_name_buf, really? maybe there is something more natural, and short, 'buf_size'?"
  - **frequency**: 2 instances
  - **severity**: nit

### Build / CMake / Sanitizers

- **title**: `CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}` requires uppercased build type and shouldn't be applied to MSVC
  - **category**: Build / CMake
  - **rationale**: Common CMake pitfall; MSVC accepts different flag syntax.
  - **examples**:
    - PR4816 vaintroub: "CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE} does not work unless you uppercase the build type. You do not want that to run for MSVC, because options check is brittle, assume GCCisms"
    - PR4816 vaintroub: "Actually, it is also an option because of both cl and clang-cl (which accepts MSVC command line). Thus please add AND NOT MSVC to the check"
  - **frequency**: multiple comments in PR4816
  - **severity**: important

- **title**: CMakeLists.txt should not silently change flags beyond what was asked for (no sneaking `-Og` into `WITH_ASAN`)
  - **category**: Build / CMake
  - **rationale**: vaintroub's strong opinion: build flags belong in CMAKE_BUILD_TYPE, not bundled with sanitizer toggles. CI-only flags belong in CI env.
  - **examples**:
    - PR4816 vaintroub: "If I want ASAN it is just ASAN, and not 'ASAN and lets make your debugging a little bit more complicated'. ... I think -Og should be something set in the CI, rather than in CMakeLists.txt"
  - **frequency**: multi-comment thread
  - **severity**: important

- **title**: ENABLE_DEBUG_SYNC etc. variables must be respected; tests must skip on non-debug builds
  - **category**: Testing / Build
  - **rationale**: have_debug.inc / have_debug_sync.inc inclusion is mandatory for any DBUG_EXECUTE_IF or DEBUG_SYNC test.
  - **examples**:
    - PR4765 grooverdan: "`--source include/have_debug.inc` needed or `have_debug_sync.inc` if a debug sync implementation is used."
  - **frequency**: 1+ explicit
  - **severity**: important

- **title**: Don't ship code that breaks `WITH_INNODB_EXTRA_DEBUG=ON` combinations
  - **category**: Build
  - **rationale**: Internal testing combos depend on `PLUGIN_PERFSCHEMA=NO` plus extra-debug; breakage caught by Marko.
  - **examples**:
    - PR4784 dr-m: "This change is fixing the following combination: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_INNODB_EXTRA_DEBUG=ON`... In our internal testing, we use the `rr record` friendly option `PLUGIN_PERFSCHEMA=NO`."
  - **frequency**: 1 instance
  - **severity**: blocker (Marko fixed it himself)

### Replication / Binlog / Galera

- **title**: Use `include/reset_master.inc` instead of inline `RESET MASTER`
  - **category**: Replication tests
  - **rationale**: Wraps proper sync; portable across master/slave versions.
  - **examples**:
    - PR4771 knielsen: "It's better to do this: `--source include/reset_master.inc`"
  - **frequency**: 1 instance
  - **severity**: important (Galera-area maintainer correction)

- **title**: When reusing privileges (FEDERATED ADMIN, SUPER, etc.) document semantics in JIRA and commit message
  - **category**: ACL / replication
  - **rationale**: Privilege drift turns privileges into roles. Reviewers prefer dedicated privileges.
  - **examples**:
    - PR4743 gkodinov: "It usually is not a good idea to reuse privileges. This turns them into roles... I'd advocate to adding a different privilege"
    - PR4743 gkodinov: "Why are you revoking SUPER as well? Would SUPER allow SHOW CREATE SERVER? If it would, please document that into the Jira and the commit message."
  - **frequency**: 2 instances same PR
  - **severity**: important

### API / Architecture

- **title**: Features that span multiple engines belong above the engine layer, not in one engine
  - **category**: API / architecture
  - **rationale**: "High-level indexes" (vector hlindex) are by design implemented above the engine; checks must too.
  - **examples**:
    - PR4706 vuvova: "No, this is completely wrong. This doesn't fix MyISAM or Aria. 'hlindexes' are called **High-Level** Indexes because they are implemented on a higher level, not in the engine, but above it. Size check must also be done not in the engine, but above it."
  - **frequency**: 1 (but architectural, big)
  - **severity**: blocker

- **title**: Don't bloat THD by removing virtual functions in MDL_context_owner unless you measurably gain
  - **category**: API / architecture
  - **rationale**: De-THD direction; MDL_context_owner exists for unit-test isolation; flatten only with care.
  - **examples**:
    - PR4808 svoj: "You claim that you de-virtualized `MDL_context_owner` methods, but you didn't. You have to remove inheritance from `MDL_context_owner` and remove `override` keyword from all relevant methods."
    - PR4808 svoj: "No, these methods don't relate to MDL. They rather form some sort of session state interface, not MDL. Please remove this line, it is misleading."
    - PR4808 vaintroub: "For the unmeasurable performance benefit of removing virtual function we'll plant this THD dependency everywhere. We should actually de-THD as much as we can."
  - **frequency**: many in PR4808
  - **severity**: blocker (PR ultimately rejected on architecture grounds)

- **title**: Don't reference "MySQL" in comments inside MariaDB source
  - **category**: Documentation / branding
  - **rationale**: MariaDB is its own product; legacy MySQL comments should be revised.
  - **examples**:
    - PR4858 dr-m: "What is MySQL? We're MariaDB."
  - **frequency**: 1 instance
  - **severity**: nit

- **title**: Add Doxygen `@param` documentation when a new parameter is added
  - **category**: Documentation
  - **rationale**: Especially for booleans whose meaning isn't obvious at call sites.
  - **examples**:
    - PR4858 dr-m: "This comment does not really explain the purpose of the parameter. Corresponding comments are missing from the overridden functions in some derived classes. Would `bool will_update_row` be a more descriptive name?"
    - PR4858 dr-m: "A comment `@param will_update_row` should have been added with an explanation. Currently it's hidden in `sql/handler.cc`, where the parameter being called `mark_for_update`. Either this comment needs to be a copy of that one, or that comment needs to be moved here."
  - **frequency**: 2 instances same PR
  - **severity**: important

- **title**: Don't add default values for boolean parameters that change behavior across all derived classes
  - **category**: API / safety
  - **rationale**: Default = forgotten override = silent bug.
  - **examples**:
    - PR4858 dr-m: "By far the most callers would seem to pass this flag as `false`. Hence the default parameter kind of makes sense. However, it would be safer not to define a default value and require each caller to specify this parameter."
  - **frequency**: 1 instance
  - **severity**: important

- **title**: Don't accept empty strings into `my_realpath` to "fix" callers; fix the caller not to pass empty strings
  - **category**: API design
  - **rationale**: Empty path is invalid; pushing the workaround into utility functions hides the real bug.
  - **examples**:
    - PR4865 vuvova: "I don't understand the logic here. `error_if_data_home_dir()` can strip the file name... and that's why the latter must accept empty strings? It doesn't make any sense."
  - **frequency**: 1 instance
  - **severity**: blocker

### Error Codes & Messages

- **title**: Add new error codes to errmsg-utf8.txt to allow translation, instead of reusing existing ones with new strings
  - **category**: Errors / i18n
  - **rationale**: Translators rely on stable code/string pairing.
  - **examples**:
    - PR4712 grooverdan: "Just a thought, should we add `ER_CANT_ALTER_TABLE HY000` in sql/share/errmsg-utf8.txt with the same error number HY000 as ER_CANT_CREATE_TABLE so translations can be added?"
  - **frequency**: 1 instance (but suggested as standing practice)
  - **severity**: important

## Notable Anti-Patterns

- **AI-generated buffer-size guesses**: PR4869 (MDEV-39173) used Claude-style automation to replace `sprintf` with `snprintf`. Reviewer gkodinov repeatedly called out hard-coded length constants that didn't match the actual receiving buffer. Fix: thread the actual size as a function parameter. Quote: "it's not as simple as letting some AI do it. You will need to find the actual size of the buffer and then set that as a limit."
- **Engine-local fix for a cross-engine feature**: PR4706 placed the vector-index size check in InnoDB; HL-indexes are above-engine, so MyISAM/Aria still broken. vuvova: "No, this is completely wrong."
- **Leaving stripped-Boost as residual change**: PR4768 — Boost was already not in the package. Author found it via packaging audit; reviewers noted it could just be deleted.
- **Submodule/.gitattribute drift in unrelated PR**: PR4829 — feedback plugin PR included submodule updates from columnstore. grooverdan: "Remove submodule updates and .gitattribute additions from this commit"
- **`recv() == 0` retry loop**: PR4881 initially proposed retrying on `recv()==0`; vaintroub corrected: 0 means peer closed.
- **Hardcoded sleep timeouts**: PR4804 / PR4874 — 2-second timeouts cause flakes on overloaded CI. Increase to 1 min.
- **Reverting a patch by re-declaring a different type**: PR4783 — reverter attempted to also change `my_wc_t` to `uint16`. dr-m: "I thought that you were against the use of the `long` data type, which `my_wc_t` is an alias of?" Author reverted that part.
- **Empty-string path passed to my_realpath**: PR4865 — fix the caller, don't widen the API.
- **Reading bit-field repeatedly in hot path**: PR4717 — cache in local.
- **Submitting PR against unrelated MDEV**: PR4762 gkodinov: "Please never submit a pull request against an MDEV if you do not intend to solve the mdev."
- **Empty unit-test data ("\xc3" as 'ASCII')**: PR4731 — test claimed to test charsets but only fed ASCII bytes; reviewer requested proper Item_string with windows-1251.
- **Sprintf %s with terminator overrun**: PR4869 — buffer sized for constant chars but excluding the runtime-injected component; sanja-byelkin: "Is it pass windows and 32bits with no problem?"
- **Test that masks the very data being verified**: PR4829 — masking `/etc/os-release` content before comparing made the test useless ("The data you need to test gets masked out. So it could be empty or wrong and no one will notice.")

## Workflow / Process Signals

- **Two-stage review** is universal: gkodinov triages every new external PR ("preliminary review") and assigns a senior "final reviewer" per area: midenok (DDL/partitions), vuvova (vector, ACL, server), dr-m + Thirunarayanan (InnoDB), spetrunia/RexJohnston (optimizer), svoj (MDL), janlindstrom (Galera), vaintroub (threadpool, byte order, Windows, build).
- **Branch targeting** is policy-driven, not preference: bug fixes go to lowest still-maintained branch (often 10.11, sometimes 10.6); new features to current dev (12.3/main); test enhancements may go to whichever branch first had the feature.
- **CLA-bot must be green** as a hard precondition; gkodinov asks for it on virtually every CONTRIBUTOR PR.
- **One commit, MDEV-prefixed message, CODING_STANDARDS.md compliant** is the merge precondition.
- **Buildbot must be clean**: re-recording .result files, fixing MSAN/ASAN/UBSAN failures, fixing Windows path-length issues. Authors are expected to investigate platform-specific failures themselves.
- **Zulip channel** (mariadb.zulipchat.com) is referenced as the place to escalate or get guidance ("Please reach out on Zulip if you need guidance on adding the test." — PR4829 gkodinov).
- **GSoC PRs** are explicitly distinct workflow ("It was intended to be, but it's pretty much done, so there's no point starting on it now." — PR4711).
- **Closing a PR in favor of another**: standard practice when target branch needs to change and rebase-in-PR isn't feasible. Examples: PR4752 → PR4764, PR4727 → PR4755.
- **Re-request review** explicitly after pushing changes; reviewers don't watch passively.
- **Marking PRs as draft vs open**: PR4830 — "should this PR be 'open' or in 'draft' state?" Draft for in-progress, open for ready-for-review.
- **Performance claims require benchmarks** (oltp_point_select cached is the canonical micro-benchmark for measuring sql-layer overhead) — vaintroub on PR4808.

## Singletons Worth Noting

- **CONFIG_ARM64_VA_BITS_36/39** kernel-config quirk (PR4852): `std::min` vs `std::max` for buffer-pool size on 36-bit VA. May matter if MariaDB is ever ported to small-VA embedded ARM.
- **mi_uintNkorr vs uintNkorr** semantic split (PR4783, PR4797): `mi_*` = big-endian (MyISAM disk format), plain = little-endian (memory). Don't cross.
- **vector.test as a many-engines combo test** (PR4706): reuse rather than creating new combination files.
- **--view-protocol disable for opt_context_store_sys_vars** (PR4851): MDEV titles must distinguish "test file" from "test suite" precisely — spetrunia: "The term 'test-suite' is used for different thing."
- **GCC C90 mixed-decl warning in mysql_client_test.c** (PR4881): "ISO C90 forbids mixed declarations and code" still fires even with C99 — declare prefix before code.
- **HUGE_VAL is NOT infinity** (PR4731): "HUGE_VAL is an overflow indicator." Use proper +Inf/-Inf via `std::numeric_limits<double>::infinity()` etc.
- **NAN printing in JSON is specified** (PR4731): "JSON has a specific definition of what NAN should print." (NaN is not a valid JSON number; the writer should reject or emit a sentinel.)
- **`feedback` plugin not compiled on buildbot** (PR4829): tests requiring feedback need explicit `--source include/have_partition.inc`-style skip checks for `information_schema.plugins`.
- **Windows path-length test fragility** (PR4855): tests with long path names must move to `_not_windows.test`.
- **InnoDB shutdown invariant**: exactly one trailing `FILE_CHECKPOINT` written; recovery parses only that. Multiple PR4747 dr-m comments encode this invariant.
- **`uintNkorr/intNstore` macros must avoid unaligned access** is itself a recurring MDEV-37788 theme — see PR4783, PR4797, and references to PR4742.
- **PROXY-protocol v1 buffer size = 107 bytes max** is a spec constant (PR4881). Header parser must size for full header + NUL terminator.
- **`ENABLE_DEBUG_SYNC` not enabled in non-debug builds** is what triggers the have_debug skip requirement (PR4765).
- **VIEW_MD5_LEN / MD5_BUFF_LENGTH = VIEW_MD5_LEN + 1** convention (PR4869): MD5 hex string is 32 chars plus NUL = 33 bytes.
- **sanja-byelkin pattern for debug functions**: same return type / interface (`const char*`, "<NULL>" for null, "" for missing) across `dbug_print_*` functions (PR4703).
