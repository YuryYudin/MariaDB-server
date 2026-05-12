# Chunk 00 — Recurring Review Patterns (MariaDB/server PRs, 2025-11-12 → 2026-05-12)

Chunk covers 21 PRs / 468 comments. Heavy load from PR #4405 (innodb_log_archive, 125 comments, mostly dr-m responding to internal QA), PR #4036 (InnoDB FTS parser removal, dr-m vs. Thirunarayanan), PR #4342 (Galera FK warnings, dr-m vs. janlindstrom), PR #4284 (mariadb-dump SHOW SLAVE STATUS, bnestere/vuvova). Strongest signals come from dr-m (InnoDB), gkodinov (preliminary triage), vuvova, Thirunarayanan, grooverdan, svoj, sanja-byelkin, bnestere.

## Recurring Patterns

### Coding Style / C++ Hygiene

- **title**: Follow K&R switch formatting — no line break and no `{}` around `case` bodies unless declaring locals
  - **category**: Coding style
  - **rationale**: dr-m: "According to our formatting rules, we are following the K&R formatting for the `switch` statement body. That is, there must not be a line break here." And: "No variables are being declared within the `switch` statement body. Please discard the superfluous `{` and `}`."
  - **examples**:
    - PR#4036 `storage/innobase/fts/fts0fts.cc:6140` — dr-m
    - PR#4036 `storage/innobase/fts/fts0fts.cc:6152` — dr-m
    - PR#4036 `storage/innobase/fts/fts0opt.cc:644` "The `switch` body is being indented one level (2 spaces) too deep." — dr-m
  - **frequency**: 3+
  - **severity**: important
  - **applies_to**: `storage/innobase/*`, any C/C++

- **title**: Declare variables at first real use (not earlier), and prefer declaring in `while`/`for` expression
  - **category**: Coding style
  - **rationale**: dr-m repeatedly flagged variables declared "unnecessarily early".
  - **examples**:
    - PR#4036 `fts0fts.cc:6186` "`rec` is being declared unnecessarily early. It could be declared in the `while` expression." — dr-m
    - PR#4036 `fts0fts.cc:6194` "`err` is unnecessarily being declared separately from the first actual assignment." — dr-m
    - PR#4342 `row0ins.cc:765` "Why are the declaration and initialization split?" — dr-m
  - **frequency**: 3
  - **severity**: nit/important
  - **applies_to**: `storage/innobase/*`, any C++

- **title**: Indent with the file's existing convention (TAB vs spaces) and don't introduce mixed indent or stray TABs in new code
  - **category**: Coding style
  - **rationale**: dr-m: "The added code needs to be indented with TAB, just like the existing code. … The formatting around `=` is inconsisetnt here. In the old InnoDB formatting style, there would always be a space before…"; "TAB should not be for formatting new functions."
  - **examples**:
    - PR#4036 `fts0opt.cc:1606` — dr-m
    - PR#4342 `row0ins.cc:765` — dr-m
  - **frequency**: 2-3
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: Avoid unrelated formatting changes; touch only what the patch actually modifies
  - **category**: Coding style / commit hygiene
  - **rationale**: dr-m: "I think that we should avoid any changes to formatting unless some code nearby is being changed."
  - **examples**:
    - PR#4342 `row0ins.cc:1253` — dr-m (about an extra blank line before `goto`)
    - PR#3726 `libmariadb`/`wsrep-lib` "please focus on the change at hand!" — gkodinov
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: any

- **title**: Place braces per existing project style
  - **category**: Coding style
  - **rationale**: Multiple comments asking for braces on new line / fixed brace placement.
  - **examples**:
    - PR#4262 `sql/mysqld.cc:5100` "The brace should be on the new line." — FooBarrior, gkodinov fixed it
  - **frequency**: 2
  - **severity**: nit
  - **applies_to**: `sql/*`, client/*

### Correctness / Memory / Lifetimes

- **title**: Avoid `std::string` (and other heap-using STL classes) in InnoDB hot paths — use `my_printf_error`/`%.*s`/in-place buffers
  - **category**: Memory / allocation
  - **rationale**: dr-m: "Please avoid the use of `std::string`. It can lead to significant memory heap fragmentation." Asks to use `my_printf_error` and `dict_table_open_failed()` style.
  - **examples**:
    - PR#4342 `row0ins.cc:1038` — dr-m
    - PR#4342 `row0ins.cc:823` "let's avoid using any `std::string` and use a single `my_printf_error` or similar" — dr-m
    - PR#4342 `row0ins.cc:753` shows the recommended fixed-buffer pattern — dr-m
  - **frequency**: 3+
  - **severity**: blocker (dr-m repeated until fixed)
  - **applies_to**: `storage/innobase/*`

- **title**: Use `sql_print_error`/`sql_print_information` in new code; avoid `ib::logger`/`ib::info`/`puts()` in server code
  - **category**: Logging / errors
  - **rationale**: dr-m: "Can we please avoid `ib::logger` in new code?"; dr-m: "Can we please use `sql_print_error` in new code?". gkodinov rewrote `puts()` to `sql_print_information()` in PR#4262. vuvova: "in the server it should be `sql_print_information()` not `puts()`."
  - **examples**:
    - PR#4036 `fts0fts.cc:2764` — dr-m
    - PR#4036 `fts0opt.cc:1305` — dr-m
    - PR#4262 `client/mysql.cc:1428` "Please use put_info as the rest of them do." — gkodinov
    - PR#4262 vuvova issue comment
  - **frequency**: 4+
  - **severity**: important
  - **applies_to**: `storage/innobase/*`, `sql/*`, `client/*`

- **title**: Guard new InnoDB DDL/state changes with debug assertions documenting invariants (`ut_ad`)
  - **category**: Correctness
  - **rationale**: dr-m: "Please add debug assertions that document some constraints. … It's very hard to review a complex change…". Thirunarayanan: "Add an assert ut_ad(size > 0);"; "Shall we add assert saying `ut_ad(!archive);`". 54 comments in chunk include "assert"/`ut_ad`.
  - **examples**:
    - PR#4036 `fts0fts.cc:6159` "Please add debug assertions that document some constraints. Is `index` expected to be the only index of the table?" — dr-m
    - PR#4036 `fts0fts.cc:6334` "Shouldn't we assert that there only is one index in the table? Otherwise this function would corrupt any secondary indexes." — dr-m
    - PR#4405 `log0log.cc:1176` "Add an assert ut_ad(size > 0);" — Thirunarayanan
    - PR#4405 `log0log.cc:1559` "Shall we add assert saying `ut_ad(!archive);`" — Thirunarayanan
  - **frequency**: many (10+)
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: New buffers/string assembly must not allow buffer overflow; prefer `%.*s` with explicit length
  - **category**: Correctness / security
  - **rationale**: dr-m: "`end` may post one `char` past the end of `db_table`. If that is the case, this assignment would constitute a buffer overflow … In my previous review I suggested the use of `"%.*s"` and specifying the length explicitly."
  - **examples**:
    - PR#4342 `row0ins.cc:768` — dr-m (repeated review)
    - PR#4342 `row0ins.cc:763` 32-column×NAME_LEN math from dr-m
  - **frequency**: 2 (same issue across multiple reviews)
  - **severity**: blocker
  - **applies_to**: `storage/innobase/*`

- **title**: Don't reuse an already-allocated heap pointer (no dangling references); document who owns/frees what
  - **category**: Memory / allocation
  - **rationale**: dr-m: "We seem to be assigning `fetch->heap` to something that is allocated from our local stack. Where do we reset `fetch->heap` before returning from this function? We surely wouldn't want to leave a dangling pointer…"; PR#4047: reviewer points out missing `delete rgi->assembler` on error path.
  - **examples**:
    - PR#4036 `fts0opt.cc:473` — dr-m
    - PR#4036 `fts0priv.h:587` "The destructor would seem to crash when invoking `mem_heap_free(nullptr)` on a default-constructed object." — dr-m
    - PR#4047 `log_event_server.cc:5698` "allocated assembler is not getting deleted" — hemantdangi-gc
    - PR#4332 KhaledR57's MSAN/LSAN leak in `check_unique_keys` — fixed by passing `my_free` to `my_hash_init`
  - **frequency**: 3+
  - **severity**: blocker (real leaks/UAF)
  - **applies_to**: `storage/innobase/*`, `sql/*`

- **title**: Atomic/torn-read risk for SHOW GLOBAL STATUS variables on 32-bit
  - **category**: Correctness (concurrency)
  - **rationale**: Thirunarayanan: "SHOW GLOBAL STATUS access this variable without any mutex. Won't have torn read in case of 32 bit platform?" dr-m agreed and suggested `trx_t::max_inactive_id_atomic` trick.
  - **examples**:
    - PR#4405 `log0log.h:289` — Thirunarayanan, dr-m
  - **frequency**: 1-2 (singleton but flagged by senior maintainer)
  - **severity**: important
  - **applies_to**: any new server-status variable

### InnoDB-specific

- **title**: Don't perform heap allocation per loop iteration in InnoDB — hoist out
  - **category**: Performance
  - **rationale**: dr-m: "This is allocating `offsets` on each loop iteration from `m_heap`, without even trying to reuse previously allocated `offsets`."
  - **examples**:
    - PR#4036 `fts0fts.cc:6215` — dr-m
    - PR#4036 `fts0fts.cc:6187` "Can we allocate this from the stack? … We should know the number of key columns in those tables, right?" — dr-m
  - **frequency**: 2-3
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: Move common code into helper functions; avoid `page_align()`/`page_offsets()` duplication
  - **category**: API/architecture
  - **rationale**: dr-m: "This code is being duplicated in several places. It is not good to invoke `page_align()` several times."; "This is much like `delete_rec()`. Can we use common code for these?"
  - **examples**:
    - PR#4036 `fts0fts.cc:6200`, `:6249`, `:6332` — dr-m
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: For non-hot but error-only Galera/WSREP cold paths, mark with `ATTRIBUTE_COLD ATTRIBUTE_NOINLINE` and pull out of inline code
  - **category**: Performance / API
  - **rationale**: dr-m: "I'd suggest to reduce the amount of inlined code, with something like this: … The `ATTRIBUTE_COLD ATTRIBUTE_NOINLINE` function `wsrep_applier_log_fk()` would contain the rest of the logic. This same pattern occurs in multiple places."; "Did you read the generated code for `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo`? That's the domain where any 'overly compilicated' would make a practical difference."
  - **examples**:
    - PR#4342 `row0ins.cc:835` and `:840` — dr-m
  - **frequency**: 2 (insistent, two review rounds)
  - **severity**: important
  - **applies_to**: `storage/innobase/row/*`, WSREP integration

- **title**: Use C++ functor / lambda objects instead of `void *arg, callback func` C-style callbacks for type safety
  - **category**: API/architecture
  - **rationale**: dr-m: "The C++ way would be to pass a functor object that would also be compatible with a lambda expression."; "Currently we are using a type-unsafe method of passing `void*` to `read_fts_config()`."
  - **examples**:
    - PR#4036 `fts0fts.cc:6390`, `fts0config.cc:63` — dr-m
    - PR#4036 review_body "It would be good to refactor the `fts_sql_callback` interface to use a function object."
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: `storage/innobase/*` (esp. FTS)

- **title**: New non-throwing C++ member functions in InnoDB should be marked `noexcept`
  - **category**: Coding style / performance
  - **rationale**: dr-m: "All member functions are missing `noexcept`."; repeated on multiple new APIs.
  - **examples**:
    - PR#4036 `fts0priv.h:485` — dr-m
    - PR#4036 `fts0opt.cc:436`, `:2001` — dr-m ("Why is there no `noexcept`?")
    - PR#4036 `fts0fts.cc:3727` — dr-m
  - **frequency**: 4
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: Don't define default constructors silently; use `= delete` if not needed
  - **category**: Coding style
  - **rationale**: dr-m: "What do we need a default constructor for? Could we use `= delete;` for that? The destructor would seem to crash when invoking `mem_heap_free(nullptr)` on a default-constructed object."
  - **examples**:
    - PR#4036 `fts0priv.h:587` — dr-m
  - **frequency**: 1 (singleton — but a real latent bug)
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: Use minimum-width bitfields for InnoDB column/field numbers (≤10 bits)
  - **category**: Memory / InnoDB
  - **rationale**: dr-m: "Can we use less space for these? InnoDB column or field numbers should fit in 10 bits."
  - **examples**:
    - PR#4036 `fts0types.h:88` — dr-m
  - **frequency**: 1 (singleton)
  - **severity**: nit
  - **applies_to**: `storage/innobase/*` headers

- **title**: New data members and public types in InnoDB headers need Doxygen comments
  - **category**: Documentation / comments
  - **rationale**: dr-m: "The data members are missing Doxygen comments,"; "Doxygen comments are missing."
  - **examples**:
    - PR#4036 `fts0priv.h:465`, `fts0types.h:74` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/include/*`

- **title**: Prefer std::map / std::vector over hand-rolled InnoDB containers, when not in hot path
  - **category**: API/architecture
  - **rationale**: dr-m: "Can we use `std::map` and `std::vector` instead of the homebrew containers?"
  - **examples**:
    - PR#4036 `fts0types.h:74` — dr-m
  - **frequency**: 1 (but recurring theme: code-modernization in InnoDB)
  - **severity**: nit
  - **applies_to**: `storage/innobase/*`

### Logging / Error Messages

- **title**: Error messages must include identifying info (constraint name, table name) — use existing helpers (`ut_get_name`, `dict_table_open_failed()`)
  - **category**: Logging / errors
  - **rationale**: dr-m: "The message is very confusing, because CHECK TABLE looks like a SQL statement. Why is the name of the failing constraint not being displayed? That together with the referencing table name should be sufficient."; "we are aware of a more efficient way of displaying InnoDB table names. … a conversion from `my_charset_filename` to `system_charset_info` (UTF-8). A test case for this must in..."
  - **examples**:
    - PR#4342 `row0ins.cc:1038` — dr-m
    - PR#4342 `row0ins.cc:823` — dr-m (charset conversion test demand)
    - PR#4342 `row0ins.cc:770` proposes correct `strchr` + `%`s` pattern — dr-m
  - **frequency**: 4
  - **severity**: important
  - **applies_to**: `storage/innobase/*`, any user-visible message

- **title**: Don't produce duplicated tokens like `err: err:` in messages; cover each message in tests
  - **category**: Logging / errors
  - **rationale**: dr-m: "The output would seem to include `err: err:`. Please cover each message in the test cases."; "we have some duplicated `err: err:` strings in the output. This still seems to be the case."
  - **examples**:
    - PR#4342 `row0ins.cc:1789`, `:1788` — dr-m (repeated across reviews)
  - **frequency**: 2 (same issue persisted)
  - **severity**: important
  - **applies_to**: any new user-visible message

- **title**: Don't print absolute paths from the server (they add no value and are non-portable)
  - **category**: Logging / errors
  - **rationale**: dr-m: "Absolute path names do not add any useful information. Some other redundant information had been removed in 88d9348dfc..."
  - **examples**:
    - PR#4342 `galera_FK_duplicate_client_insert,no_warnings.rdiff:2` — dr-m
  - **frequency**: 1
  - **severity**: nit
  - **applies_to**: `mysql-test/*`, server messages

- **title**: Naming consistency between enum/sysvar identifiers and the string literal they emit
  - **category**: API / naming
  - **rationale**: dr-m: "The added symbol `WSREP_MODE_APPLIER_DISABLE_WARNINGS` does not include `FK_` like the added string literal `APPLIER_DISABLE_FK_WARNINGS` does. Is this intentional?"; "The `enum` name says `warning`, but one of the constants includes `ERROR`. … add a comment to each constant…"
  - **examples**:
    - PR#4342 `sql/wsrep_mysqld.h:135`, `:145` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `sql/*`, new system variables / sql_mode flags

### Testing / MTR

- **title**: When testing log messages, use `include/search_pattern_in_file.inc` — don't just rely on suppression
  - **category**: Testing / MTR
  - **rationale**: dr-m: "How can we be sure that the test produces such warnings if we are not checking that the messages are actually being emitted, by using `search_pattern_in_file.inc`?"; "`.*` at the end of the regular expression is redundant".
  - **examples**:
    - PR#4342 `mysql-test/suite/galera/t/galera_fk_selfreferential.test:22` — dr-m
    - PR#4342 `galera/r/MW-369.result:261` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `mysql-test/*`

- **title**: Test must cover the new code paths (constraint names, error strings, all branches), and reuse common `.inc` files
  - **category**: Testing / MTR
  - **rationale**: dr-m: "If the tests are not revised to actually cover the constraint names that the messages are expected to output, then such conflicts will remain undetected."; grooverdan: "Should be possible to add to mysql-test/main/auto_increment_ranges.inc. This is included by … `mysql-test/mt..."
  - **examples**:
    - PR#4342 `row0ins.cc:772` — dr-m
    - PR#3131 grooverdan re: auto_increment_ranges.inc inclusion
    - PR#4332 RuchaDeodhar: "make more simple test cases and add them to the test"
  - **frequency**: many (16+ mentions of "test case" pattern)
  - **severity**: important
  - **applies_to**: `mysql-test/*`

- **title**: Test cases must not contain machine-local paths or developer-only artifacts; use proper test fixtures
  - **category**: Testing / MTR
  - **rationale**: hemantdangi-gc: "change path, this is local to your machine."; spetrunia: "Please move away the example from using mysql.user to using your own table and VIEW. Using a table from mysql.* makes one think that is somehow special."
  - **examples**:
    - PR#4047 `mysql-test/suite/rpl/r/rpl_fragment_row_event.result:48` — hemantdangi-gc
    - PR#4318 spetrunia (use of mysql.user)
  - **frequency**: 2
  - **severity**: blocker
  - **applies_to**: `mysql-test/*`

- **title**: Test cases must be minimal; strip irrelevant details (datatypes, IFNULL, optimizer trace) from repro
  - **category**: Testing / MTR
  - **rationale**: spetrunia: "The testcase and commit comment seem to have a lot of irrelevant details. … Does the bug need longtext? Does it need IFNULL?"; "You enable optimizer trace in t..."
  - **examples**:
    - PR#4318 — spetrunia
  - **frequency**: 1 (singleton, but strong)
  - **severity**: important
  - **applies_to**: `mysql-test/*`

- **title**: Don't change pre-existing `mtr.add_suppression()` to a less specific pattern — keep it narrow
  - **category**: Testing / MTR
  - **rationale**: dr-m: "Why is the `mtr.add_suppression()` less specific? Do we really want to ignore any errors that could be issued for other table or constraint names?"
  - **examples**:
    - PR#4342 `galera/r/MDEV-36923.result:35` — dr-m
  - **frequency**: 1 (but explicit)
  - **severity**: important
  - **applies_to**: `mysql-test/*`

- **title**: Test result and comments must match the SQL terminology and actual table/constraint names used
  - **category**: Testing / MTR
  - **rationale**: dr-m: "There is no table named `cg` or constraint `fk_1` in this test. The error message is misleading or incorrect. Also, the 'child table' appears to be incorrect as well. The SQL terminology would be 'referencing table'…"; "The table name and the constraint name are being omitted here, although a comment right before the statement `INSERT INTO grandchild` claims to know them."
  - **examples**:
    - PR#4342 `MW-369.test:366`, `MDEV-36923.test:54` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `mysql-test/*`

- **title**: `Sys_var_set` tests should verify boundary values that should be rejected
  - **category**: Testing / MTR
  - **rationale**: dr-m: "Is this a tight limit? As far as I understand, the `Sys_var_set Sys_wsrep_mode` was extended with only one member. Hence I'd expect `256` to be a disallowed value."
  - **examples**:
    - PR#4342 `galera/r/galera_var_wsrep_mode.result:24` — dr-m
  - **frequency**: 1
  - **severity**: important
  - **applies_to**: `mysql-test/*` SET-type sysvars

### Build / CMake

- **title**: Prefer `#cmakedefine` (via `config.h.cmake`) over global `add_definitions(-D…)`
  - **category**: Build / CMake
  - **rationale**: gkodinov: "I'd avoid adding a global definition to the command line. I'd add a `#cmakedefine IO_SIZE @IO_SIZE@` to config.h.cmake."; gkodinov: "command line is only that long (on most OSes). So you risk of running out of it." vaintroub agreed.
  - **examples**:
    - PR#3726 `CMakeLists.txt:196` — gkodinov, vaintroub, dr-m all concur
  - **frequency**: 3 (all concurring)
  - **severity**: important
  - **applies_to**: `CMakeLists.txt`, `cmake/*`

- **title**: Put new feature defaults / validation in `configure.cmake`, not in top-level `CMakeLists.txt`
  - **category**: Build / CMake
  - **rationale**: gkodinov: "I'd put the default here and move this to configure.cmake."; "I'd move this check into configure.cmake. Here's it's too late to check and kind of a gotcha."
  - **examples**:
    - PR#3726 `CMakeLists.txt:194`, `include/my_global.h:675` — gkodinov
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: build system

- **title**: Use UPCASE for CMake commands; validate that user-provided numeric vars are actually numeric
  - **category**: Build / CMake
  - **rationale**: gkodinov: "most of the CMake commands in this file are written in UPCASE. Please consider changing math() and message()". vaintroub: "You also might want to add MATCHES `^[0-9]+$`, to ensure it is a number rather than say `512KB`"; "this expression should be called IS_NOT_POWER_OF_TWO. !=0 is TRUE, 0 is FALSE."
  - **examples**:
    - PR#3726 `CMakeLists.txt:199`, `:200` — gkodinov, vaintroub
  - **frequency**: 3
  - **severity**: nit/important
  - **applies_to**: `CMakeLists.txt`

- **title**: Don't modify generated parser files (flex/bison output) directly — tweak the invocation or the input
  - **category**: Build / packaging
  - **rationale**: dr-m: "Instead of modifying the `flex` or `bison` generated files that are included in the source repository (as well as the scripts that could be used for rebuilding them), can we please tweak the Infer invocation so that these files will be excluded from analysis?"
  - **examples**:
    - PR#4293 `fts0blex.cc:4` — dr-m
    - PR#4293 `fts0tlex.cc:1525` "mention in the commit message the Bison version that was used." — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/fts/*lex.cc`, any generated source

- **title**: Don't touch 3rd-party bundled libraries (`extra/readline`, `extra/zlib`) directly — add defines via their local CMakeLists.txt
  - **category**: Build / packaging
  - **rationale**: svoj: "`readline` is a third party library. It would be good to keep it intact and add `-DHAVE_VSNPRINTF` to `extra/readline/CMakeLists.txt` instead. … The very same point applies to `zlib`."
  - **examples**:
    - PR#4017 `extra/readline/display.c:1939` — svoj
  - **frequency**: 1 (but explicit "very same point applies")
  - **severity**: important
  - **applies_to**: `extra/*`

- **title**: When removing `HAVE_*` defines, also clean up `#ifdef HAVE_*` consumers and the cache files
  - **category**: Build / cleanup
  - **rationale**: svoj: "Please cleanup compatibility code as well." "`git grep HAVE_ALLOCA` and `git grep HAVE_MEMCPY` still return quite a few items that should be cleaned up". vuvova: "why would we want garbage like `#ifdef HAVE_PERROR` in the code, when `PERROR` is always defined?". svoj also: removing all occurrences should let you delete the `*Cache.cmake` file entirely.
  - **examples**:
    - PR#4017 — svoj (review_body, line:LinuxCache.cmake:20), vuvova
  - **frequency**: 3
  - **severity**: blocker (review held up until cleanup done)
  - **applies_to**: any feature-detect cleanup

- **title**: Don't bump unrelated submodules (`libmariadb`, `wsrep-lib`) in a feature PR — those need separate PRs
  - **category**: Commit hygiene
  - **rationale**: gkodinov: "do you really need to change these? It looks like there's a conflict on these in buildbot."; vuvova: "`libmariadb` needs a special PR there's no automatic propagation."
  - **examples**:
    - PR#3726 — gkodinov, vuvova
  - **frequency**: 2
  - **severity**: blocker
  - **applies_to**: any PR touching submodules

### Commit Hygiene / Workflow

- **title**: Commit message must be `MDEV-NNNNN <subject>` with descriptive body explaining what and why
  - **category**: Commit hygiene
  - **rationale**: svoj: "Please change commit message so that it conforms to MariaDB guidelines, something like: `MDEV-37630 - logfile cannot output utf8` …" grooverdan: "Commit message is general but implementation is Debian specific." dr-m: "It could be useful to mention in the commit message the Bison version that was used."
  - **examples**:
    - PR#4295 — svoj (review_body)
    - PR#4065 — grooverdan (Debian-specific message)
    - PR#4293 — dr-m (mention bison version)
  - **frequency**: 3
  - **severity**: blocker (review explicitly held)
  - **applies_to**: any commit

- **title**: Rebase regularly; never merge upstream into the PR branch; use bare rebase
  - **category**: Commit hygiene / Workflow
  - **rationale**: PR#4065 author repeatedly: "Rebased on latest 'main' to ensure this PR does not have any extra merge commits." svoj review #3978: "rebase and check bb failures."
  - **examples**:
    - PR#4065 — ottok rebased 8+ times
    - PR#3978 svoj review_body — "rebase and check bb failures."
  - **frequency**: many (28 mentions of "rebase")
  - **severity**: important
  - **applies_to**: any PR

- **title**: Don't bundle unrelated cleanups into one MDEV — split them into separate commits or PRs
  - **category**: Commit hygiene
  - **rationale**: vuvova: "I don't know. I thought you'll remove CHECK and that's it (and also mailx dependency, thanks). But you also used bash arrays, rewrote passwordless root check. Why is all that and why it's in the same MDEV-34902 commit?"
  - **examples**:
    - PR#4390 — vuvova
  - **frequency**: 1 (but explicit)
  - **severity**: important
  - **applies_to**: any PR

- **title**: Foundation/CLA must be signed before review proceeds
  - **category**: Process / workflow
  - **rationale**: gkodinov: "sign the CLA (one of its two versions) so that the CLA bot can check"; "*PLEASE* clear the CLA bot ASAP."
  - **examples**:
    - PR#4243 — gkodinov (review_body)
  - **frequency**: 2 (same PR)
  - **severity**: blocker
  - **applies_to**: any new contributor

- **title**: Target the correct branch: bugfixes go to oldest still-supported branch, features go to `main`
  - **category**: Process / workflow
  - **rationale**: grooverdan: "If you want to take to to 11.8 or 11.4 that's ok by me if those correspond to the Debian 11/12 (?) version that MariaDB has where the merge/move occurred."; sanja-byelkin re #4243: "change it in 10.6 now IMHO too big risk." gkodinov re #4262: "main is good enough."
  - **examples**:
    - PR#4243 — sanja-byelkin
    - PR#4065 — grooverdan
    - PR#4295 — svoj's review implies stable branch behaviour
  - **frequency**: 3
  - **severity**: important
  - **applies_to**: any PR

- **title**: PRs need buildbot CI green; unrelated failures should be filed as separate MDEVs not blockers
  - **category**: Process
  - **rationale**: gkodinov: "please work towards getting buildbot green."; grooverdan: "Lets leave the test failures that are unrelated as JIRA entries…"
  - **examples**:
    - PR#3726 — gkodinov
    - PR#4065 — grooverdan
    - PR#4332 — grooverdan/andrelkin tracked MSAN leaks
  - **frequency**: many
  - **severity**: blocker
  - **applies_to**: any PR

- **title**: No-feedback PRs get converted to draft/closed after 3+ weeks of inactivity
  - **category**: Process
  - **rationale**: gkodinov: "Converting to draft since there's been no reply to the reviews for more than 3 weeks."; "No feedback received on my previous comment. I'll assume the submitter is OK with closing this." svoj: "It'd be better to update this pull request though, rather than creating new one. I will convert this one to draft so that it is off of our radar."
  - **examples**:
    - PR#3131, PR#3978, PR#4017, PR#4243, PR#4295 — gkodinov, svoj
  - **frequency**: 5+
  - **severity**: important
  - **applies_to**: any PR

### Compatibility / API stability

- **title**: Renaming `BASE TABLE` → `SYSTEM TABLE` in `information_schema.TABLES` is too risky without MySQL parity + compatibility flag
  - **category**: Compatibility
  - **rationale**: vaintroub: "How much was that change had been tested with external tools and connectors that rely on I_S.TABLES? It has the potential to break a lot of things"; sanja-byelkin: "I could understand it under compatibility flag (like sql_mode MySQL) but change it in 10.6 now IMHO too big risk."
  - **examples**:
    - PR#4243 — vaintroub, sanja-byelkin
  - **frequency**: 2
  - **severity**: blocker
  - **applies_to**: `sql/sql_show.cc`, `information_schema/*`

- **title**: Mark code/comments TODO when waiting on EOL (e.g. SHOW SLAVE STATUS supported until 11.4 EOL)
  - **category**: Compatibility / docs
  - **rationale**: bnestere: "Please add a code comment w/ a TODO to remove this and associated code once 11.4 goes eol"; "I'd suggest filing a JIRA to remove support for SHOW SLAVE STATUS from mariadb-dump after 11.4 goes EOL."
  - **examples**:
    - PR#4284 `client/mysqldump.cc:181` — bnestere
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `client/*`, replication code

### API design

- **title**: Don't over-engineer — prefer flat, readable code over polymorphism if there's only one or two niche subclasses
  - **category**: API/architecture
  - **rationale**: vuvova: "Really? I understand that you love `std::function` but this is seriously overdoing it." bnestere: "I think the overengineering here hurts readability, and I don't really see the benefit of extensbility, as the use case is very niche."; "Generally I think combining a class which both abstracts how to query something, along with the behavior of using that queried data is too much in the same abstraction." vuvova showed a simple `multi_source ? "SELECT ..." : "SELECT ..."` ternary as the desired refactor.
  - **examples**:
    - PR#4284 `client/mysqldump.cc:178/197/209/6578/7615` — bnestere, vuvova
  - **frequency**: 5+ on same PR
  - **severity**: blocker (drove the redesign)
  - **applies_to**: `client/*`, any new abstraction

- **title**: Return-by-error-code (`dberr_t`) is preferred over out-pointer + bool in InnoDB
  - **category**: API/architecture
  - **rationale**: dr-m: "Could we make the function return an error code? That would allow simpler execution: `if (dberr_t err= sqlRunner.open_table(fts_table, &table)) return err;`"; "Could we make this return `db_err_t` instead of `bool`?"
  - **examples**:
    - PR#4036 `fts0config.cc:45`, `fts0priv.h:491` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/*`

- **title**: Move assertions to the top of the function (precondition-style) rather than after a conditional
  - **category**: Coding style
  - **rationale**: dr-m: "Can the assertion be moved to the start of the function, like they were before this refactoring? Here it is inside a conditional execution path."; "Could this assertion be at the start of this function?"
  - **examples**:
    - PR#4036 `fts0config.cc:57`, `fts0opt.cc:2003` — dr-m
  - **frequency**: 2
  - **severity**: nit
  - **applies_to**: `storage/innobase/*`

- **title**: Make file-local helper functions `static`
  - **category**: Coding style
  - **rationale**: dr-m: "This is missing `static`."
  - **examples**:
    - PR#4342 `row0ins.cc:748` — dr-m
  - **frequency**: 1 (singleton)
  - **severity**: nit
  - **applies_to**: any C/C++

### Galera / WSREP / Replication

- **title**: Don't claim a downgrade path that hasn't been tested — don't add per-character compat checks "just in case"
  - **category**: Compatibility / replication
  - **rationale**: dr-m: "This is not what I requested earlier. We must not create an impression that a downgrade would work if it has not been tested. The check for `'\377'` must not be added."
  - **examples**:
    - PR#4342 `dict0mem.h:1670` — dr-m
  - **frequency**: 1 (but blocker-style insistent)
  - **severity**: blocker
  - **applies_to**: `storage/innobase/include/dict0mem.h`, file formats

- **title**: Cold-path warning logic must consider release-mode behavior (don't flood error log in production)
  - **category**: Logging
  - **rationale**: janlindstrom: "DB_LOCK_WAIT is normal behavior even in applier, it would flood error log if this warning is enabled in release builds."; dr-m: "Why does the logic differ between `CMAKE_BUILD_TYPE=Debug` and `CMAKE_BUILD_TYPE=RelWithDebInfo`?"
  - **examples**:
    - PR#4342 `row0ins.cc:755`, `:1783` — janlindstrom, dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/*` (Galera applier code)

- **title**: On replication PRs, all-error/edge code paths must be testable via `DBUG_EXECUTE_IF` if tests cannot reproduce naturally
  - **category**: Testing / replication
  - **rationale**: dr-m: "Would a Galera specific `DBUG_EXECUTE_IF` in `row_mysql_handle_errors()` serve a similar purpose?"; janlindstrom: "ok I know how to force them using DBUG_EXECUTE_IF."
  - **examples**:
    - PR#4342 `row0ins.cc:755`, `:1789` — dr-m, janlindstrom
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/*`, `sql/log_event*.cc`

### Documentation

- **title**: New non-trivial design intent must be commented (e.g. why `const` + `mutable` asymmetry exists, what `f_len` means)
  - **category**: Documentation
  - **rationale**: Thirunarayanan: "end is const, but access deliberately is non-const. The asymmetry between `const end` and mutable `access` is fine but worth a comment explaining the design intent."; dr-m: "Some comment about `value->f_len` would be useful here."
  - **examples**:
    - PR#4405 `log0recv.h:260` — Thirunarayanan, dr-m
    - PR#4036 `fts0config.cc:57` — dr-m
  - **frequency**: 2
  - **severity**: important
  - **applies_to**: `storage/innobase/*` headers

### Naming

- **title**: Function names should reflect actual semantics; avoid misleading "flush" if no flush always happens
  - **category**: Naming
  - **rationale**: bnestere: "I like the `inline` change, but the change to the function name I'm still not sold on … It isn't guaranteed to flush if the content should all be held in-memory." Resolved to `flush_write_buffer_if_file_backed()` after iteration.
  - **examples**:
    - PR#4373 `sql/log.cc:1984` — bnestere, andrelkin
    - PR#4284 `client/mysqldump.cc:178` "`is` here reads as a verb" — bnestere
  - **frequency**: 2
  - **severity**: nit
  - **applies_to**: any

## Notable Anti-Patterns

- **PR#4036 fts0priv.h:587** — default constructor that leaves heap pointer null, then destructor calls `mem_heap_free(nullptr)` → crash. dr-m: "What do we need a default constructor for? Could we use `= delete;` for that?"
- **PR#4342 row0ins.cc:768** — `char db_table[BUF]; char *end = db_table + N; *end = 0;` buffer overflow flagged across two review rounds; reviewer (dr-m) insisted on `%.*s` length-explicit pattern instead.
- **PR#4342 row0ins.cc:751** — `fk_str.c_str()` then `+ 2` to skip leading `", "` — undocumented magic offset. dr-m proposed introducing `dict_foreign_t::sql_id()` to encapsulate.
- **PR#4036 fts0fts.cc:6215** — repeated `rec_get_offsets()` heap allocation in tight loop. dr-m: hoist or eliminate via existing `3761a7fec8a273...` commit.
- **PR#4036 fts0opt.cc:473** — assigns local-stack pointer to a struct member `fetch->heap` then returns; dangling pointer hazard.
- **PR#4047 log_event_server.cc:5698** — early-return error path leaks `rgi->assembler`. hemantdangi-gc caught it; bnestere noted the destructor cleans up later but agreed to free here too. "We use C++ extensively, but use a lot more `goto end`s than RAII" (ParadoxV5).
- **PR#4332 sql/item_jsonfunc.cc** — `my_hash_init(...)` without passing a `my_free` callback while values were `my_malloc`-allocated → MSAN/LSAN leaks; uncovered on amd64-ubasan-clang-20.
- **PR#4332 sql/item_jsonfunc.cc:6356** — recursive descent without stack-overflow guard. RuchaDeodhar: "Just add a out of stack space check, there are examples in this files."
- **PR#4405 log0log.h:289** — `lsn_archived` is exposed to SHOW GLOBAL STATUS via `&log_sys.archived_lsn` (64-bit ulonglong) without atomic access — torn read on 32-bit. Thirunarayanan asked, dr-m noted simply switching to `Atomic_relaxed<lsn_t>` is not enough because `SHOW_ULONGLONG` reads directly; needs `export_vars` indirection.
- **PR#4405 buf0flu.cc:1819** — assertion `archive ? file_size <= ~0U : ...` was off-by-one; dr-m corrected to `ARCHIVE_FILE_SIZE_MAX`. Pattern: always use the named constant, not `~0U`.
- **PR#4262 client/mysql.cc:1428** — change from `put_info()` to `puts()` broke existing convention; gkodinov: "Please use put_info as the rest of them do."
- **PR#4036 sync.result:85** — silent removal of an `ORDER BY` in an SQL query changed result ordering (caught by Thirunarayanan, dr-m: "Why does the order change here? There is nothing mentioned in the commit message. Some applications might expect a special ordering.")
- **PR#3978** — making `DATE'2001'` (year-only date literal) treated as valid silently breaks documented `'YYYY-MM-DD'` constraint and removes prior conversion warnings on illegal-temporal literals. gkodinov: "I believe we should have had a error here." Multiple .result files showed degraded warning behavior.

## Workflow / Process Signals

- **Preliminary vs final reviewer pattern**: gkodinov repeatedly does "preliminary review" then hands to a senior. ("This is my preliminary review of the change. Once we clear this out I'll solicit a final reviewer.") A final reviewer is assigned by area: dr-m/Thirunarayanan for InnoDB, vuvova/spetrunia for sql/, janlindstrom for Galera, andrelkin/bnestere for binlog/replication, sanja-byelkin for parser/I_S, svoj for build.
- **CLA-bot first**: gkodinov insists CLA is cleared before final review.
- **Submodule PRs are out-of-band**: `libmariadb`, `wsrep-lib`, `mysql-test/std_data` submodule bumps need their own PR ("`libmariadb` needs a special PR there's no automatic propagation" — vuvova).
- **Backport strategy**: introduce in main/dev branch first, backport after 6-9 months without regressions ("I propose we put this in the dev version first, and backport to 11.4+ in 6-9 months if there are no regressions" — ottok PR#4065).
- **Stale PR rule**: ~3 weeks without contributor reply → reviewer converts to draft / closes. Reopening welcomed if work resumes.
- **Unrelated CI failures**: tracked as separate JIRAs (e.g. MDEV-36647), not blockers. grooverdan: "Lets leave the test failures that are unrelated as JIRA entries…" But contributor must enumerate which failures are unrelated.
- **Multi-version review**: vaintroub repeatedly asks whether MySQL has done the same change; PR#4243 closed because no MySQL parity and no compat flag.
- **Reproducing internal QA crashes (mariadb-SaahilAlam)**: PR#4405 shows that internal QA posts every RQG-found assertion failure as line comment; the PR author (dr-m) responds with the commit hash that resolved it. Pattern: assertion failure → commit hash response within days.
- **MDEV-NNNNN cross-referencing**: reviewers frequently file new MDEVs for issues found during review (MDEV-38914, MDEV-38968, MDEV-37789) rather than expand the current PR scope.
- **"This belongs in another PR"** (#4747): dr-m repeatedly rebases pieces to a dependent PR rather than mixing concerns.
- **Bison/flex regen**: must mention the tool version in the commit message (dr-m PR#4293).

## Singletons Worth Noting

- **PR#3726**: `IS_NOT_POWER_OF_TWO` naming convention — when a CMake test variable name implies negation, set it `OR` the negative form, not the positive (vaintroub).
- **PR#4293**: dr-m is fine with modern C++ anonymous unions ("Modern C++ does allow that … recently introduced some of that to `buf_page_t` and `buf_pool_stat_t`") — so "no anonymous union" is *not* a project rule, despite the older policy that motivated PR#4293.
- **PR#4243**: sanja-byelkin: "using strcmp without length comparison first is inefficient" — interesting micro-optimization rule.
- **PR#4373**: andrelkin: introducing a `static` helper for one use is "an overkill" — prefer `inline` body or call-site combinator.
- **PR#4332**: andrelkin highlighted MSAN/LSAN compile-and-run-from-Docker as the recommended way to reproduce sanitizer failures (link to compile-and-using-mariadb-with-sanitizers docs).
- **PR#4036**: dr-m suggests using `pcur.btr_cur.page_cur.block` directly rather than a separate `block` variable — pattern: don't re-read fields already exposed by an iterator.
- **PR#4036**: dr-m: avoid `goto` where a `continue` / `break` would suffice; "The `goto` is redundant."
- **PR#4036**: dr-m suggests "make a lower-level variant of `delete_rec()` operate on a positioned cursor, and make the higher-level variant invoke both `search_tuple()` and the lower-level function" — common refactor he wants for InnoDB row ops.
- **PR#4405**: dr-m on `SET GLOBAL` semantics — there is no way to return a deferred-success status (MDEV-36828 tracks the limitation).
- **PR#4405**: dr-m: when log_archive=ON files exist and `=OFF` is set, old files are not deleted because "we don't necessarily even know their names" — non-obvious lifetime decision worth a comment.
- **PR#4318** (spetrunia): `Item_ref` referring to another `Item_ref` and named via `strdup_root` from the wrong arena is a recurring class of PS/EXECUTE bugs — debug via setup_copy_fields, watch arena ownership in `find_field_in_view()`.
- **PR#4262**: gkodinov rewrote the patch himself and merged via PR — pattern: senior reviewer may take over a stalled PR rather than abandon it.
