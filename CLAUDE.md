# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository identity

This is **MariaDB Server** — a fork/drop-in replacement of MySQL maintained by the MariaDB Foundation and MariaDB Corporation. `origin` is `https://github.com/MariaDB/server`. The bug tracker lives at https://jira.mariadb.org and every change is tied to an `MDEV-NNNNN` ticket. License is GPLv2 only (no "any later version"). `VERSION` at the repo root encodes the marketing version (currently `13.0.1`, maturity `gamma`).

Although the parent directory is named `GridGain/`, the working tree is upstream MariaDB — there are no GridGain-specific changes in tree.

## Build

The build system is **CMake** (≥ 3.12). Languages are C99 (since 10.4.25) and C++17 (since 11.8.1). Default build type is `RelWithDebInfo`. The project assumes **out-of-source builds**; once an in-source build has been attempted, you must remove `CMakeCache.txt` to switch.

```sh
# from the repo root
mkdir ../build && cd ../build
cmake ../MariaDB-server          # initial configure (sticky in CMakeCache.txt)
cmake --build . -j$(nproc)       # or: make -j$(nproc)
```

Common configure-time options (`-DOPT=VAL`):

- `CMAKE_BUILD_TYPE=Debug|RelWithDebInfo|Release|MinSizeRel` — `Debug` enables `DBUG_TRACE`, `ENABLED_DEBUG_SYNC`, `SAFE_MUTEX`, `SAFEMALLOC`, `TRASH_FREED_MEMORY`, `_GLIBCXX_DEBUG` (gcc ≥10), and `PROTECT_STATEMENT_MEMROOT`. Non-debug builds get `-DDBUG_OFF`.
- `WITH_ASAN`, `WITH_TSAN`, `WITH_UBSAN`, `WITH_MSAN` — mutually informative; MSAN requires `libc++`. Sanitizer builds force `-Og` if no optimization level was set.
- `MYSQL_MAINTAINER_MODE=AUTO|NO|WARN|ERR` (`AUTO` = `-Werror` only in Debug). Enables `-Wall -Wextra -Wsuggest-override -Wvla -Wframe-larger-than=16384` etc. (see `cmake/maintainer.cmake`).
- `WITH_SSL=bundled|system|yes` — `bundled` uses `extra/wolfssl`; `system` uses OpenSSL. `bundled` lacks AES-GCM.
- `WITH_WSREP=ON|OFF` — Galera cluster replication support (uses `wsrep-lib` submodule).
- `PLUGIN_<NAME>=NO|STATIC|DYNAMIC`, `WITHOUT_<NAME>=1`, `WITH_<NAME>_STORAGE_ENGINE=1` — control individual plugins/engines (`cmake/plugin.cmake`). CI commonly disables `PLUGIN_COLUMNSTORE`, `PLUGIN_ROCKSDB`, `PLUGIN_S3`, `PLUGIN_MROONGA`, `PLUGIN_CONNECT`, `PLUGIN_PERFSCHEMA` for speed.
- `WITHOUT_SERVER=ON` — build only client library + tools.
- `WITH_EMBEDDED_SERVER=ON` — additionally build `libmysqld`.
- `WITH_UNIT_TESTS=ON` (default) — compiles `unittest/` programs and registers them with CTest.
- `SECURITY_HARDENED=ON` (default) — adds `-pie`, `-fstack-protector`, `relro`, `_FORTIFY_SOURCE=2` for non-sanitizer builds.
- `BUILD_CONFIG=<name>` — load `cmake/build_configurations/<name>.cmake` preset.

There are pre-canned compile flag scripts in `BUILD/` (e.g. `BUILD/compile-pentium64-debug-max`, `BUILD/compile-pentium64-asan-max`) — these run `cmake` with a curated flag set.

Useful custom targets:

- `make minbuild` — minimal set of binaries required for `mtr` (mariadbd plus essential client tools).
- `make smoketest` — runs `mariadb-test-run.pl main.1st`. Depends on `minbuild`.
- `make package` — produces a distributable tarball/RPM/DEB based on `CPACK_GENERATOR`.
- `make dist` — source tarball.
- `make test` — runs CTest (`unittest/` TAP programs and ABI checks); does **not** invoke `mtr`.
- `make test-force` — runs `mariadb-test-run.pl` with `--force`.

### Submodules

Six git submodules: `libmariadb` (Connector/C — required), `storage/rocksdb/rocksdb`, `wsrep-lib`, `extra/wolfssl/wolfssl`, `storage/maria/libmarias3`, `storage/columnstore/columnstore`. CMake will run `git submodule update --init --recursive --depth 1` for you unless `cmake.update-submodules` is set to `no` in git config. To opt out of auto-update: `git config cmake.update-submodules no`. To disable a submodule for faster builds (e.g. Windows): `git config submodule.<path>.update none`.

## Testing

There are two distinct test layers:

### 1. MTR — the integration suite (the main one)

The big test framework lives in `mysql-test/` and is driven by `mariadb-test-run.pl` (a.k.a. `mtr`, `mysql-test-run.pl`). It is the canonical way to test the server: each `.test` file is a script of SQL + mysqltest directives, with an expected `.result` file diffed against actual output. It spawns its own `mariadbd` instances in `var/`, so a system server installation is not used and won't conflict.

`make` first, then from the build directory:

```sh
cd mysql-test                            # in your build dir, not source
./mtr                                    # default suites (see @DEFAULT_SUITES in mariadb-test-run.pl)
./mtr alias                              # one test by short name
./mtr main.alias                         # qualified suite.test
./mtr suite/rpl/t/rpl_invoked_features   # by path
./mtr rpl.rpl_invoked_features,mix,innodb # with combination
./mtr --suite=innodb,maria               # run only listed suites
./mtr --record testname                  # (re)generate the .result file
./mtr --big-test                         # include slow tests; twice = only big tests
./mtr --parallel=8                       # parallel workers
./mtr --parallel=auto                    # one per CPU
./mtr --mem                              # vardir on tmpfs (much faster)
./mtr --force                            # don't stop on failure; twice = continue past first failed command
./mtr --extern socket=/tmp/mysql.sock alias  # run against an already-running server
./mtr --manual-gdb testname              # attach gdb interactively
./mtr --valgrind                         # run under valgrind (suppressions in valgrind.supp)
./mtr testname --mariadbd=--loose-foo=bar  # extra server arg for this run
```

Run `./mtr --help` for the (very long) full list.

Test layout:

- `mysql-test/main/` — server-core tests (3000+ tests; the default suite).
- `mysql-test/suite/<name>/` — themed suites (`rpl`, `innodb`, `binlog`, `galera`, `encryption`, `parts`, `sys_vars`, `funcs_1`, `mariabackup`, …). Each suite typically has `t/` for `.test` files and `r/` for `.result` files (the `main/` suite has them side-by-side).
- `mysql-test/std_data/` — shared fixture data.
- `mysql-test/include/` — `.inc` helpers included by `.test` files.
- `mysql-test/collections/` — named lists of tests for CI (`default.daily`, `default.push`, `default.weekly`, `smoke_test`, etc.) and skip lists (`disabled-*.list`, `skip_list_ubsan.txt`).
- Storage engines ship their own MTR suites under e.g. `storage/innobase/mysql-test/`, automatically picked up.
- Test names ending in `-master.opt` carry per-test `mariadbd` arguments; `.combinations` files declare combination matrices; `.rdiff` files describe result-file deltas per combination.

### 2. Unit tests — `unittest/`

C/C++ unit tests written against the in-tree **MyTAP** framework (`unittest/mytap/`). They live in `unittest/{mysys,strings,my_decimal,json_lib,sql,examples,embedded}/` and follow the naming convention `*-t.c[c]`. They are picked up automatically by CTest when `WITH_UNIT_TESTS=ON` (default).

```sh
make test                # via CTest in build dir
ctest -R bitmap          # run by regex
ctest -V                 # verbose output
unittest/mysys/bitmap-t  # run a single TAP binary directly
```

The "examples" tests are intentionally not expected to all pass — they demonstrate failure modes.

There are also longer-running C-only test drivers inside the storage engines (e.g. `storage/maria/ma_test*.c`, `storage/maria/ma_test_all.sh`) which are not part of `make test`.

## Code layout (the parts you'll actually open)

The repo is large (~570 files in `sql/` alone). Key directories:

- `sql/` — the server core. Entry point: `sql/main.cc` → `mysqld_main()` in `sql/mysqld.cc`. Major subsystems:
  - **Parser** — `sql_yacc.yy` (Bison grammar), `sql_lex.{cc,h}`, `gen_lex_hash.cc`, `gen_lex_token.cc`.
  - **Command dispatch** — `sql_parse.cc::mysql_execute_command`, dispatched per `enum_sql_command`.
  - **Optimizer / executor** — `sql_select.{cc,h}`, `opt_*.{cc,h}` (range, subselect, histograms, hints, table_elimination, …), `sql_explain.{cc,h}`.
  - **Items (expressions)** — `item_*.{cc,h}` — every SQL expression / function is an `Item` subclass.
  - **Tables / fields / types** — `table.{cc,h}`, `field.{cc,h}`, `sql_type*.{cc,h}`.
  - **Storage-engine API** — `handler.{cc,h}` defines `class handler` (per-table-instance) and `struct handlerton` (per-engine singleton). Every engine plugs in here.
  - **Replication** — `rpl_*.{cc,h}`, `log.cc`, `log_event*.cc`, `sql_repl.cc`, GTID in `rpl_gtid.{cc,h}`, parallel applier in `rpl_parallel.{cc,h}`. WSREP/Galera in `wsrep_*.{cc,h}` (uses the `wsrep-lib` submodule; `wsrep_dummy.cc` is the stub when `WITH_WSREP=OFF`).
  - **Stored programs** — `sp_*.{cc,h}` (head, instr, pcontext, rcontext, cache, cursor).
  - **ACL / privileges** — `sql_acl.{cc,h}`, `grant.{cc,h}`.
  - **Plugin host** — `sql_plugin.{cc,h}` (loads `MYSQL_ADD_PLUGIN` plugins, manages services).
- `storage/` — storage engines, each its own plugin: `innobase` (InnoDB, the default), `maria` (Aria, default for system tables), `myisam`, `heap` (MEMORY), `archive`, `csv`, `federated`, `federatedx`, `blackhole`, `rocksdb` (submodule), `spider`, `connect`, `mroonga`, `columnstore` (submodule), `sequence`, `perfschema`, `oqgraph`, `sphinx`, `s3`, `videx`, `test_sql_discovery`. Each defines `handler` subclasses and a `handlerton` and is wired up via `MYSQL_ADD_PLUGIN(<name> ... STORAGE_ENGINE ...)`.
- `plugin/` — non-storage plugins: authentication (`auth_pam`, `auth_gssapi`, `auth_ed25519`, …), key-management (`file_key_management`, `aws_key_management`, `hashicorp_key_management`, …), audit (`server_audit`), password validation, compression providers (`provider_lz4` etc.), feedback, locale_info, query_response_time, etc.
- `client/` — command-line clients: `mariadb` (`mysql.cc`), `mariadb-dump` (`mysqldump.cc`), `mariadb-import`, `mariadb-admin`, `mariadb-check`, `mariadb-binlog`, `mariadb-test` (the mysqltest driver), `mariadb-slap`, `mariadb-conv`, `mariadb-upgrade`. Most are aliased to `mysql*` names for compatibility.
- `extra/` — auxiliary binaries: `mariabackup/` (physical backup tool), `mariabackup` (binary), `innochecksum`, `comp_err`, `aws_sdk/`, `my_print_defaults`, `perror`. Also bundled `extra/wolfssl/`.
- `libmariadb/` — Connector/C (submodule). Provides the client library.
- `libmysqld/` — embedded server library (`libmariadbd`), built only with `WITH_EMBEDDED_SERVER=ON`.
- `sql-common/` — code shared between server and clients (`client.c`, `pack.c`, `my_time.c`, error messages).
- `mysys/`, `mysys_ssl/` — portable OS abstraction (file I/O, threading, hash tables, allocators, charset handling helpers). Header API in `include/my_*.h`.
- `strings/` — low-level string and decimal routines; `dbug/` — the DBUG tracing library; `vio/` — virtual I/O (TCP, sockets, named pipes, SSL); `tpool/` — thread pool used by InnoDB and others.
- `include/` — public C/C++ headers consumed across the tree (`my_global.h`, `m_ctype.h`, `m_string.h`, `mysql.h`, etc.). Generated headers (`my_config.h`, `mysql_version.h`, `source_revision.h`) land in `<builddir>/include/`.
- `unittest/` — see above.
- `mysql-test/` — see above.
- `cmake/` — modules included from the top-level `CMakeLists.txt`. Especially important: `plugin.cmake` (the `MYSQL_ADD_PLUGIN` macro), `maintainer.cmake` (warning flags), `os/<platform>.cmake` (platform tweaks), `build_configurations/` (presets).
- `BUILD/` — legacy curated shell wrappers around cmake/configure for specific platform+flag combos.
- `debian/`, `support-files/`, `man/`, `scripts/` — packaging, init scripts, SQL setup scripts (`mariadb_system_tables.sql`, …), man pages.
- `Docs/` — sparse upstream docs; canonical docs are at https://mariadb.com/kb/.
- `randgen/`, `sql-bench/` — separate test/benchmark trees (older, less used).

## Coding style

Authoritative source: `CODING_STANDARDS.md`. Highlights that diverge from common conventions:

- **Allman braces with 2-space indent** (no tabs anywhere). Closing brace on its own line. Single-statement `if`/`while` bodies may omit braces.
- **Line length ≤ 80**. When wrapping, leave operators (`+`, `-`, `&&`, …) at the end of the previous line, not the start of the next.
- **`switch (expr) {`** — opening brace on the same line as `switch` so `case` labels align with `switch`. `case` labels are at the same indent as `switch` (i.e. **not** indented).
- **Preprocessor directives at column 0**, even inside indented code blocks. Comment the original condition on `#else`/`#endif` for long blocks.
- **Assignment style: `a= 1;`** — no space before `=`, single space after. (This makes assignment-site grep accurate: `grep -nE 'foo= ' src/`.) This rule applies to server code; some storage engines (Connect) use the conventional `a = 1`.
- **Pointer placement: `THD *thd`** — `*` binds to the variable name.
- **Identifiers** — `snake_case` for variables/functions; `Snake_Case` (snake_case starting upper) for class names. Avoid single-letter names except short loop counters.
- **Variables declared at the top of their scope.** Helps readers see stack footprint and lets you add early returns/`goto end` without reshuffling.
- **No `long` / `ulong`** in new code — the size differs between Linux and Windows. Use `size_t`, `ptrdiff_t`, `int32_t`, etc.
- **C uses `.c`, C++ uses `.cc`, headers use `.h`**. File names are lower-case with underscores.
- **Functions separated by two blank lines.** No trailing whitespace, no trailing blank lines, `\n` line endings only.
- **Inverse conditions** — write `if (*err == 0)` or `if (!*err)`, not Yoda-style `if (0 == *err)`.

A `.clang-format` file exists at the repo root but its settings (column 80, Cpp11, brace wrapping enabled per category) reflect a *different* style than `CODING_STANDARDS.md` — **do not blindly run `clang-format` over server code**, as it will reformat in ways that conflict with the prose standard. Use it for guidance, not enforcement.

## Working with the tree

- **Commit messages** follow the 50/72 rule. The first line should start with the Jira ticket, e.g. `MDEV-12345 Short description`. The MDEV-prefix exception lets the subject exceed 50 chars if needed. Markdown is permitted in the body (GitHub renders it). Pull requests should be fast-forward — **rebase, don't merge** (`git rebase upstream/<branch>` then `git push --force`).
- **Target branch.** New features → `main` (the GitHub default). Bug fixes → the earliest still-maintained release branch in which the bug reproduces (see https://mariadb.org/about/#maintenance-policy). The release branches are named after marketing versions (`10.11`, `11.4`, `11.8`, `12.0`–`12.3`, …). Don't merge across branches casually — the CI configuration in `.gitlab-ci.yml` is intentionally release-specific.
- **Bugs are tracked in https://jira.mariadb.org** as `MDEV-NNNNN`. PRs and commits reference these.
- **Security issues** must follow https://mariadb.org/about/security-policy/ — do not file them in the public issue tracker.
- **PR auto-labeling.** `.github/workflows/label_recent_prs.yaml` tags PRs as `MariaDB Foundation` / `MariaDB Corporation` / `Codership` / `External Contribution` based on org-team membership of the author.

## CI

There are three CI surfaces, each with a different scope — none of them runs the *full* MTR matrix (which lives in Buildbot, off-repo):

- **GitLab CI** (`.gitlab-ci.yml`) — Fedora (gcc, ninja, clang), CentOS 9, plus an **ASAN** and a **TSAN** build via the `fedora-sanitizer` job. Disables heavy plugins for speed. Runs `make test` (CTest) but not `make test-force`. The file is **intentionally per-branch** — don't merge changes across branches.
- **AppVeyor** (`appveyor.yml`) — Windows / Visual Studio 2022, `MinSizeRel` build with `MYSQL_MAINTAINER_MODE=ERR` and `FAST_BUILD=1`, then `mariadb-test-run.pl --suite=main` with skip list `win/appveyor_skip_tests.txt`. Builds the `minbuild` target only.
- **GitHub Actions** (`.github/workflows/`) — `backup.yml` (nightly repo export to restic/S3), `label_recent_prs.yaml` (PR labeling), `windows-arm64.yml`. No primary build/test pipeline.

## Things to be aware of

- The server binary is now called **`mariadbd`** (legacy alias `mysqld`). Most clients have been renamed `mariadb-*` with `mysql*` symlinks for backward compatibility — both names work and tests use both.
- The `Debug` build defines `ENABLED_DEBUG_SYNC`, which makes `SET DEBUG_SYNC='name SIGNAL go';` and `WAIT_FOR` available — heavily used by MTR tests in race-condition reproductions.
- `DBUG_ENTER("name") / DBUG_RETURN(x) / DBUG_PRINT("key", ("fmt", args))` macros (from `dbug/`) are pervasive in `sql/` for traceable debug output (`mariadbd --debug=...`).
- A surprising amount of the codebase pre-dates the C99/C++17 baseline. Older files may use `my_bool`, `LEX_STRING`, `DYNAMIC_ARRAY`, raw `pthread_mutex_t` instead of modern equivalents; mimic the surrounding style when patching them.
- Generated files (`sql_yacc.cc`, `lex_hash.h`, `lex_token.h`, `errmsg.sys`, `my_config.h`, …) live only in the build directory. Edit `sql_yacc.yy`, `lex.h`, `share/errmsg-utf8.txt`, etc. instead.
- The build trips on stale `CMakeCache.txt` entries when switching from in-source to out-of-source or toggling sanitizers. When odd configure-time checks fail, deleting the build directory is usually faster than debugging.
