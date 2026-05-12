# Build / CMake / Portability

CMake style, sanitizer hygiene, and portability constraints.

## CMake style

- **UPCASE CMake commands.** Match the rest of the file (`SET`, `IF`, `MATH`, not `set`, `if`, `math`).
  - PR3726 gkodinov: "most of the CMake commands in this file are written in UPCASE. Please consider changing `math()` and `message()`."
- **Use `ELSEIF()`** rather than `ENDIF() ... IF()`. Fewer scopes.
  - PR4872 vaintroub: "ELSEIF() please, instead of ENDIF() and new IF()."
- **Use `#cmakedefine` via `config.h.cmake`** for new compile-time defines, not `ADD_DEFINITIONS(-DFOO=...)` at the top-level.
  - PR3726 gkodinov: "I'd avoid adding a global definition to the command line. I'd add a `#cmakedefine IO_SIZE @IO_SIZE@` to config.h.cmake. It's already included by my_global.h."
  - PR3726 gkodinov: "command line is only that long (on most OSes). So you risk of running out of it."
- **Put feature defaults and validation in `configure.cmake`**, not the top-level `CMakeLists.txt`.
  - PR3726 gkodinov: "I'd put the default here and move this to configure.cmake."
  - PR3726 gkodinov: "I'd move this check into configure.cmake. Here's it's too late to check and kind of a gotcha."
- **Validate numeric user-input variables** with `MATCHES "^[0-9]+$"`. Don't silently accept `"512KB"`.
  - PR3726 vaintroub: "You also might want to add MATCHES `^[0-9]+$`, to ensure it is a number rather than say `512KB`."
- **Name negation-conditions in the negative.** `IS_NOT_POWER_OF_TWO` reads correctly when the test is "`!=0` is TRUE".
  - PR3726 vaintroub: "this expression should be called IS_NOT_POWER_OF_TWO. !=0 is TRUE, 0 is FALSE."

## Sanitizer hygiene

- **Don't bundle unrelated flag changes** with sanitizer toggles. CI-only flags belong in CI env, not `CMakeLists.txt`.
  - PR4816 vaintroub: "If I want ASAN it is just ASAN, and not 'ASAN and lets make your debugging a little bit more complicated'... I think `-Og` should be something set in the CI, rather than in CMakeLists.txt."
- **`CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}` requires UPPERCASE build type**, and the substitution doesn't work for MSVC.
  - PR4816 vaintroub: "`CMAKE_C_FLAGS_${CMAKE_BUILD_TYPE}` does not work unless you uppercase the build type. You do not want that to run for MSVC, because options check is brittle, assume GCCisms."
  - PR4816 vaintroub: "Actually, it is also an option because of both cl and clang-cl (which accepts MSVC command line). Thus please add AND NOT MSVC to the check."
- **Guard new linker flags with `check_linker_flag`.** And know that `CHECK_LINKER_FLAG` needs CMake ≥ 3.18.
  - PR4522 vaintroub on `cmake/mysql_add_executable.cmake:36`: "use add_link_options... Check that this linker option is valid"
  - PR4522 vaintroub on `mysys/CMakeLists.txt:199`: "CHECK_LNKER_FLAG needs CMake 3.18, thus CMAKE version check needs to be VERSION_GREATER_EQUAL '3.18'."
- **MSVC vs gcc-isms.** Compiler-flag checks brittle on MSVC; `clang-cl` accepts MSVC command-line syntax.
- **Bison version detection.** New parser features (`%define api.token.raw`, …) require ≥ 3.6.3, which RHEL-8 / AlmaLinux 8 / OpenSUSE 15 / SLES / Windows lack.
  - PR4440 grooverdan: "RHEL-8, AlmaLinux 8, OpenSUSE-15 (but not 16), SLES and Windows have a bison version older than 3.6.3(?) when this was introduced."
  - PR4440 gkodinov: "Also, please consider making the cmake addition of this option depend on the bison version."

## Portability

The buildbot grid includes Windows, FreeBSD-like behaviour, musl libc, ARM64, ppc64le, s390x. Reviewers will flag platform-specific assumptions.

- **`#ifndef _WIN32` for POSIX-only code paths.** Windows has different file-type / signal / fork semantics.
  - PR4455 svoj on `mysql.cc:1254`: "It appears that we can't do this check on windows. Let's put it under `#ifndef _WIN32` for now."
  - PR4455 svoj on `mysql.cc:4569`: "your test won't work on Windows anyway, since the check for file type is under `#ifndef _WIN32`."
- **Code under `#ifdef _WIN32` belongs *inside* the relevant branch**, not appended at the end of a function as dead code.
  - PR4455 svoj.
- **FreeBSD `posix_fallocate()` returns `EOPNOTSUPP`.** Handle it.
  - PR4405 dr-m on `storage/innobase/log/log0log.cc:1330`: "`posix_fallocate()` would return `EOPNOTSUPP` on FreeBSD."
- **`os_file_set_size()` never shrinks on POSIX.** Only enlarges. (See [`correctness-and-security.md`](correctness-and-security.md).)
- **musl libc TZ bug.** PR4452 exists because of one.
- **ARM64 specifics**: `MAX_KEY_SIZE` collides with a system macro on Windows ARM64; CONFIG_ARM64_VA_BITS_36/39 changes `std::min`/`std::max` choices for buffer-pool reservation.
- **`MAP_POPULATE` hides errors** — use `madvise(MADV_POPULATE_*)`.

## Submodules

Six submodules: `libmariadb`, `wsrep-lib`, `extra/wolfssl/wolfssl`, `storage/maria/libmarias3`, `storage/columnstore/columnstore`, `storage/rocksdb/rocksdb`.

- **Don't bundle submodule bumps in unrelated PRs.** Always a separate PR.
  - PR3726, PR4557, PR4829.
- **CMake will auto-update submodules** unless you set `git config cmake.update-submodules no`. Reviewers will catch unintended bumps.

## Third-party libraries — don't patch in-tree

- **Don't modify `extra/readline`, `extra/zlib`, `extra/wolfssl` directly.** Add defines via their local `CMakeLists.txt`.
  - PR4017 svoj: "`readline` is a third party library. It would be good to keep it intact and add `-DHAVE_VSNPRINTF` to `extra/readline/CMakeLists.txt` instead. The very same point applies to `zlib`."
- **Don't touch Bison/Flex-generated files** (`*lex.cc`, `sql_yacc.cc`). Edit the `.l` / `.yy` source and rerun; mention the Bison version in the commit message.
  - PR4293 dr-m.

## Packaging

- **Debian packaging changes go in `debian/`.** Triggers (not configure) for cross-package state reactions.
  - PR4644 vuvova / grooverdan — long discussion about `triggers` vs `configure`.
- **`Replaces:` in `debian/control`** preserves clean upgrade paths when moving files between packages.
- **`CPACK_COMPONENTS_ALL` membership** controls automatic `.cnf` generation for plugin packages.
- **Plugin maturity in `.cnf` samples** must match release reality.
  - PR4453 — `plugin-maturity=alpha` shouldn't be suggested for s3.
- **Don't keep stripped-Boost references** when Boost is already removed from the package.
  - PR4768.

## `WITH_*` flags and feature combinations

- **`WITH_INNODB_EXTRA_DEBUG=ON`** is part of the internal test matrix; don't break it.
  - PR4784 dr-m: "This change is fixing the following combination: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_INNODB_EXTRA_DEBUG=ON`... In our internal testing, we use the `rr record` friendly option `PLUGIN_PERFSCHEMA=NO`."
- **`PLUGIN_PERFSCHEMA=NO`** — also `rr record` friendly. dr-m uses this combo.
- **Sanitizer builds** force `-Og` if no optimization level was set.
- **Galera disabled** in GitLab CI by default for speed; tests that need Galera must run on appropriate buildbot slaves.

## Build types

| Build type | Definitions |
|---|---|
| **`Debug`** | `DBUG_TRACE`, `ENABLED_DEBUG_SYNC`, `SAFE_MUTEX`, `SAFEMALLOC`, `TRASH_FREED_MEMORY`, `_GLIBCXX_DEBUG` (gcc≥10), `PROTECT_STATEMENT_MEMROOT`. |
| **`RelWithDebInfo`** | Default. `DBUG_OFF`, but symbols + frame pointer kept. |
| **`Release`** | `DBUG_OFF`, no debug info. |
| **`MinSizeRel`** | What Windows AppVeyor builds. |
| **`+WITH_ASAN`** / **`+WITH_TSAN`** / **`+WITH_UBSAN`** / **`+WITH_MSAN`** | Stack overlay onto any build type. MSAN requires libc++. |

Sanitizer + `-O0` is rejected — sanitizer builds use `-Og` if no level was set.

## CI surfaces

- **GitLab CI**: Fedora + CentOS + ASAN/TSAN. Disables heavy plugins for speed (`PLUGIN_COLUMNSTORE`, `PLUGIN_ROCKSDB`, `PLUGIN_S3`, `PLUGIN_MROONGA`, `PLUGIN_CONNECT`, `PLUGIN_PERFSCHEMA`, `WITH_WSREP=OFF`). Runs `make test` (CTest) but not the full MTR. Per-branch tailored — *do not* merge CI changes across branches.
- **AppVeyor**: Windows VS 2022, `MinSizeRel` build, `mariadb-test-run.pl --suite=main`. Skip list in `win/appveyor_skip_tests.txt`.
- **GitHub Actions**: `backup.yml` (nightly), `label_recent_prs.yaml`, `windows-arm64.yml`. Not the primary build/test.
- **Buildbot** (`buildbot.mariadb.org`): the main multi-platform grid. Mandatory green before merge.

## Security hardening flags

`SECURITY_HARDENED=ON` (default) — adds `-pie`, `-fstack-protector`, `-Wl,-z,relro,-z,now`, `_FORTIFY_SOURCE=2`. Disabled when any sanitizer is on.

## When in doubt

- **vaintroub owns Windows / build / byte-order / threadpool.** Cite Godbolt for micro-optimizations.
- **svoj owns build / packaging / MDL.** Watch for "third-party library" pushback.
- **grooverdan owns Debian packaging / CI orchestration / test helpers.** Watch for "Windows path issue".
