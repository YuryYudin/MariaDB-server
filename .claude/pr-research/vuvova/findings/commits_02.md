# vuvova / Sergei Golubchik — commit-style findings (commits_02.jsonl)

Sample: 99 commits between 2025-05-04 and 2026-05-04. 53 start with `MDEV-`, 10 are explicit `cleanup`, 7 are merges (`Merge branch 'X' into 'Y'`), the remaining 29 are short un-prefixed descriptions of small fixes/follow-ups.

---

## Commit message conventions

### Subject format: `MDEV-NNNNN <Sentence summary>` — no colon, no prefix verb

The Jira ticket is the prefix; what follows is a copy/paraphrase of the bug title, capitalised as a sentence — not a Conventional-Commits style verb. He does not write `MDEV-NNN: fix X`, only `MDEV-NNN X`.

- `7e14749d968e` — `MDEV-37341 Assertion failures \`null_ptr < ptr' and \`ptr - null_ptr <= ...' with BEFORE trigger and UPDATE`
- `9703c90712f3` — `MDEV-37199 UNIQUE KEY USING HASH accepting duplicate records`
- `964937de3463` — `MDEV-39112 The query returns incorrect results when using LPAD`
- `b6d0e23d76fe` — `MDEV-38365 SHA2 auth plugin crash on large packets`

Confidence: high (all 53 MDEV subjects in this chunk). Applies to: all bug-fix commits.

### Long-subject exception: he routinely overruns 72/80 chars to keep the JIRA title verbatim

22/99 subjects exceed 72 chars, 11 exceed 80; the longest is 132 chars. This matches the CODING_STANDARDS exception for MDEV-prefixed subjects, but he uses it *liberally* — he doesn't paraphrase to fit.

- `7e14749d968e` (132 chars) keeps the full assertion text.
- `b930eef31787` `MDEV-37326 Assertion failure upon update on versioned partitioned table with long unique under READ ...`
- `9b393c7f198d` `MDEV-38057 main.func_json test fails in sandbox interface with lo device only`

Confidence: high. Applies to: MDEV-prefixed subjects only.

### Subject convention for non-MDEV commits: lowercase imperative, often a sentence fragment

When no MDEV ticket: subject is lowercase, often begins with `fix`, `don't`, `cleanup:`, or a noun phrase. No initial capital and no period.

- `832743f8f7c4` — `fix a memory leak in sysvars`
- `8260be640869` — `don't backtick-quote CURRENT_SCHEMA`
- `8229217206ff` — `don't create build files like mysqlserver-$<CONFIG>.mri.tpl`
- `9fbd5ce3c5df` — `improve test readability`
- `9d ce783911a9` — `fix spider/bugfix.mdev_22979 test`
- `b96b5a6ccf6a` — `cleanup: ha_partition::m_rec0`
- `a18f8d38563b` — `MDEV-37784 fix the warning`  (note: even with MDEV, "fix the warning" is lowercase fragment)

Confidence: high. Applies to: refactoring, build, test-only commits.

### `cleanup:` is the canonical prefix for pure cleanups

He uses `cleanup:` (lowercase, colon, space) when the commit does not change observable behaviour. The subject after the colon is a noun phrase (the thing being cleaned), not an imperative.

- `b96b5a6ccf6a` — `cleanup: ha_partition::m_rec0`
- `89c933d61c8d` — `cleanup: remove explicit rounding before decimal2longlong`
- `bcb77590f0f6` — `cleanup: CREATE_TYPELIB_FOR() helper`
- `9134fea5d674` — `cleanup: move constraint tests from check.test to check_constraint.test`
- `aef0468c1846` — `cleanup: \`select ... into\` tests`
- `9412821dbd47` — `cleanup: generocity->leniency`
- `a4f17dc64f29` — `cleanup: mhnsw - always scale>0`
- `b88576ea1956` — `cleanup: sphinx tests`
- `84987d1471b9` — bare `cleanup` (no colon, no description) — happens, but rare.

Confidence: high. Applies to: refactors, renames, dead-code removal, test reorganisation.

### Bodies: very terse, often absent

30/99 commits (≈30%) have empty bodies — including merges, version bumps, small parser fixes, and many cleanups. Median body length is 123 chars. Long bodies appear only when the *why* is non-obvious or when summarising multiple changes.

- Empty: `93ef1236002f` (JSON crash fix, 1-line diff), `8d6699db90da` (UBSAN shift fix, 1-line diff), `9253d6dad562`, `82c0008e327d`, `afc8a33496b0`.
- One-liners: `addb01fb60d4` body is just `LOCATE is documented to return NULL if any of its arguments is NULL`.
- Multi-paragraph reserved for genuinely complex fixes: `9703c90712f3` (READ COMMITTED gap-lock explanation), `c06a25e49570` (subdist autodetection rationale), `bead24b7f3df` (race-condition explanation).

Confidence: high. Applies to: all commits.

### Bullet-point bodies for multi-aspect commits

When a single commit touches several distinct things, the body is a bulleted list starting with `*` (asterisk + space), each bullet a sentence fragment in imperative voice or a noun phrase.

- `92641e4aa867` —
  ```
  * remove redundant checks for `len` in `get_param_length()`
  * validate return value `length` in `get_param_length()`
  * fix all `Item_param::set_param_XXX()` methods to never read past `len`
  ```
- `84eec86b3778` — `* put autocommit/commit outside of LOCK/UNLOCK. * use uppercase ... * restore the old value of autocommit`
- `b998e3a7b950` — `* let use_cache_on_timeout apply to other errors / * enable use_cache_on_timeout by default and deprecate it / ...`
- `ac493871999e` — `* fail acl_load() if it was killed, ... * only increment grant_version if privileges were, in fact, updated`
- `9dce783911a9` — `* remove the file to be --repeat friendly / * specify the correct defaults-group-suffix...`

Confidence: high. Applies to: commits with 2+ logical changes.

### Cross-references use 7-12 char SHA prefixes plus a noun (often "followup for")

He routinely names the commit being fixed/followed-up by short SHA. Variants seen: `followup for <sha>`, `Followup for <sha>`, `Revert the fix for MDEV-... (<sha>).`, `fixes innodb_fts.fulltext_misc failures after MDEV-37653`.

- `832743f8f7c4` — `followup for f33367f2ab19`
- `9749d71f9527` — `Followup for 4f9a13e9ecf2`
- `a74edc42d080` — `followup for 8001679af648`
- `b01a279f0425` — `followup for 1eff7ddd810a`
- `b6445714cabf` — `followup for c3578720e6b5`
- `7e49bffa29b4` — `Revert the fix for MDEV-35622 (957ec8bba6c).`
- `87fdb5ac62db` — `restore ... that was disabled in b62101f84be4`

Confidence: high. Applies to: any commit that fixes/reverts/cherry-picks earlier work.

### Cherry-picks are tagged either inline or as a trailer

Two equivalent forms in this sample. He uses both.

- `bcb77590f0f6` body: `(cherry picked from commit d046aca0c76da36c8ba14359034a716af667aa51)` (standard git trailer)
- `a18f8d38563b` body ends with the same `(cherry picked from commit ...)` form, after main rationale.
- `aef0468c1846` uses the informal `Cherry-pick from 11.8` instead of the standard line.

Confidence: medium. Applies to: cherry-picks across release branches.

### Reporter credit goes at the end of the body, no special trailer

For externally-reported security/audit bugs he appends a brief `Reported by …` line at the end. No `Reported-by:` trailer syntax.

- `aca6743d5345` — `Reported by Aisle Research`
- `b6d0e23d76fe` — `Reported by Pavel Kohout, Aisle Research, www.aisle.com`

Confidence: medium (2 examples; pattern is consistent). Applies to: security-disclosed bugs.

---

## Code style (as he writes it)

### `nullptr` not `NULL` in new C++ code, but he is comfortable touching either

In code he writes from scratch he uses `nullptr`; in older surrounding code he leaves `NULL` (or `0`) alone when not changing those lines.

- `8b1ccf6e8213` introduces `const Sp_handler *pkg_routine_hndlr= nullptr;` in `sql/sql_path.cc`.
- `9ef20acfbe26` — `return do_savepoint_rollback(thd, nullptr);` in new C++ code.
- Older edits keep `NULL`/`0` style: `9134fea5d674`, `b1daecfc4514`.

Confidence: medium. Applies to: new code in `sql/` and `plugin/`.

### `auto` for ad-hoc local typedefs; `static_cast` for downcasts

He uses `auto` where the type is verbose, and `static_cast<T*>` over C-style casts for non-trivial pointer conversions, while still using C-style casts for simple integer/`my_ptrdiff_t` arithmetic.

- `9ef20acfbe26` — `for (auto trx= static_cast<MHNSW_Trx*>(thd_get_ha_data(thd, &tp)); ...)`
- `89c933d61c8d` — `auto product= my_decimal();`
- C-style numeric casts: `8d6699db90da` keeps `(key_part_map)1 << parts`; `7e14749d968e` keeps `(my_ptrdiff_t)`.

Confidence: high. Applies to: new C++ code.

### `if (T *p = expr)` pattern preferred over separate decl + check

When he writes new code for null-checked dereferences, he collapses declaration + test into one line, and is willing to nest two of them.

- `a3d1b8264bc3` — replaces:
  ```
  Vio *vio= thd->net.vio;
  SSL *ssl= (SSL *) vio->ssl_arg;
  if (ssl) { ... }
  ```
  with
  ```
  if (Vio *vio= thd->net.vio)
    if (SSL *ssl= (SSL *) vio->ssl_arg)
    { ... }
  ```

Confidence: medium (single but archetypal). Applies to: defensive null checks for pointers from external state.

### One-letter local boolean named after the role; defensive flags named explicitly

He gives short pithy names to local control booleans, even one letter when the scope is tiny.

- `9703c90712f3`:
  ```
  bool lax= (ha_table_flags() & HA_CHECK_UNIQUE_AFTER_WRITE) > 0;
  ...
  const bool after_write= ha_table_flags() & HA_CHECK_UNIQUE_AFTER_WRITE;
  ```
- `c06a25e49570` — `bool d= M1B-M1` style abbreviations in stats math (M1, M2, dn, t1).

Confidence: medium.

### Comments in code are sparse, sometimes one-word, and stay on the same line

When he writes comments inline he favours `//` end-of-line comments (in C++) with a single concise phrase. Block comments are reserved for non-obvious algorithms.

- `7d08434f674a` — `static long cache_timeout;              // for KEY_MAP key_info_cache`
- `8b1ccf6e8213` — `if (caller) // first, search in the current package` ; `else // name1.name2()` ; `if (!name->m_explicit_name) // name()`
- `9ef20acfbe26` — `// release shared ctx`, `// replace it with trx`, `// free shared ctx in this scope, keep trx`
- `c06a25e49570` — block comment introducing `stats_collector` describing what it can collect and when, plus `// parallel Welford's online algorithm`.

Confidence: high. Applies to: SQL layer C++ code.

### He removes dead helpers rather than leaving them for "completeness"

When a function becomes obsolete or duplicates existing functionality he deletes it the same commit.

- `8857312503aa` deletes `add_engine_part_options()` and calls `append_create_options()` instead.
- `b96b5a6ccf6a` removes `m_rec0` field and all assignments to it; switches callers to `table->record[0]`.
- `9fc124f8f92c` removes the entire `found_unknown_values == NULL` branch documentation from `Predicant_to_list_comparator::cmp`.
- `8b1ccf6e8213` removes early-return `if (!is_cur_schema(i)) return m_schemas[i];` (collapsing the function).

Confidence: high. Applies to: cleanups and surrounding bug fixes.

### Function exports happen by removing `static` and adding a header declaration

When a private helper becomes useful elsewhere, he turns it `extern` in place — never copies the body.

- `8857312503aa` — `sql/sql_show.cc` `static void append_create_options(...)` becomes `void append_create_options(...)` and gains a declaration in `sql/sql_show.h`.

Confidence: low (1 example, but recurrent pattern from other chunks).

### He prefers `std::` math/algorithms but not containers; rolls his own data structures

He freely uses `std::max`, `std::abs`, `std::round`, `std::nextafter`, `std::sqrt`, `std::isfinite` in vector code, but data structures stay in-house (`Queue`, `MHNSW_Trx`, MariaDB strings).

- `a4f17dc64f29` — replaces `if (std::abs(scale) < std::abs(get_float(v + i))) scale= get_float(v + i);` with `scale= std::max(scale, std::abs(get_float(v + i)));`
- `c06a25e49570` — `std::isfinite`, `std::sqrt`.

Confidence: medium. Applies to: vector/numeric code.

### Style is tolerant of `goto end;` / `goto err;` for cleanup paths in C

He writes new C code that exits via `goto end;` with a single cleanup block, rather than RAII or duplicated cleanup.

- `a2b62fe57257` rewrites `ma_backup.c::aria_read_index` to use a single `void *alloca_ptr= 0;` and `goto end;` exits, replacing inline `DBUG_RETURN(...)` returns scattered through the function.

Confidence: medium. Applies to: C code in `storage/`, `mysys/`.

### Constants/Defaults written as multiplication for readability

He spells out timeouts/sizes as multiplications instead of pre-computed numbers.

- `7d08434f674a` — `24*60*60*1000` and `60*1000`.
- `c06a25e49570` — `subdist_stddev_valid= 10000;` with comment.

Confidence: medium.

### `unlikely(...)` is used for error paths he is adding

When wrapping new error checks he routinely uses the existing `unlikely()` macro.

- `b96b5a6ccf6a` — `if (unlikely((error= get_part_for_buf(...))))`
- `b6fd9f1e77d9` — adds `num_fields() < min_columns` into existing `if`.

Confidence: medium.

---

## Refactoring / cleanup habits

### "cleanup:" commits are narrow and pre-condition the next fix

A `cleanup:` commit typically lands immediately before a related functional change, removing redundancy so the real fix is small.

- `a4f17dc64f29` `cleanup: mhnsw - always scale>0` precedes `c06a25e49570` MDEV-36205 (autodetection) — both touch the same `FVector::create` area; the cleanup removes the negative-scale branch.
- `bcb77590f0f6` `cleanup: CREATE_TYPELIB_FOR() helper` introduces a macro then uses it everywhere in a single sweep across `client/*.{c,cc}` and `sql/*.cc`.

Confidence: medium. Applies to: vector code and any place he plans multiple touches.

### Renames are commits of their own with one-word bodies

When changing terminology he ships the rename as a standalone commit with the rationale stated in one sentence.

- `9412821dbd47` `cleanup: generocity->leniency` body: `as a more fitting English word here`. Diff renames `generous_furthest` -> `lenient_furthest`, `generosity` -> `leniency`.

Confidence: low (1 ex). Applies to: terminology fixes.

### He retroactively comments code he just understood

When a fix requires reasoning through a confusing structure, he leaves an explanatory comment.

- `8b1ccf6e8213` — adds `// first, search in the current package`, `// name()`, `// name1.name2()` inside `Sql_path::resolve` while restructuring the same code.
- `c06a25e49570` — adds `// or any other sigmoid` and `// parallel Welford's online algorithm`.

Confidence: medium.

### Move test data out of "wrong" test files into right ones

He maintains test-suite hygiene by relocating tests when their topical home is clearer.

- `9134fea5d674` `cleanup: move constraint tests from check.test to check_constraint.test`.
- `b88576ea1956` `cleanup: sphinx tests` — moves per-test sphinx requirement out of suite-level requirement.

Confidence: medium.

### Cleanup of test-protocol gating belongs in the harness, not in tests

When many tests carry the same workaround (e.g. `disable_ps2_protocol`/`disable_cursor_protocol` around `SELECT INTO`) he fixes it in `client/mysqltest.cc` so the workaround disappears from all tests at once.

- `aef0468c1846` `cleanup: \`select ... into\` tests` — body: `* automatically disable ps2 and cursor protocol when the select statement returns no result set / * remove manual {disable|enable}_{ps2|cursor}_protocol from around \`select ... into\` in tests`. Touches `client/mysqltest.cc` *and* dozens of `.test` files.

Confidence: medium.

---

## Bug-fix approach

### Fix at the cause, not at the symptom; explain what was wrong, not what you changed

Bodies of MDEV fixes typically diagnose the original code's wrong assumption, then state the corrective principle. He rarely lists files changed.

- `9d3af2c8e31a` MDEV-37063 — `Search_context is supposed to increase the refcnt ... It was doing so for MHNSW_Share, but not for MHNSW_Trx that was created inside mhnsw_read_next().`
- `bea8c6a30454` MDEV-37198 — `mysql_update() aborts if SQL_SELECT::check_quick() fails. SQL_SELECT::check_quick() fails when thd->killed is set. Thus, mysql_update() must also test thd->killed ...`
- `7e14749d968e` MDEV-37341 — `in SIMULTANEOUS_ASSIGNMENT there is no need to switch value items to new nullable copies of table Field's - they must refer to old values in the row, which can never be null anyway.`
- `964937de3463` MDEV-39112 — `LPAD was modifying its first argument, even if it was a const string`

Confidence: high. Applies to: all non-trivial fixes.

### Quote the rule violated by the bug, especially for SQL-standard / docs issues

When a bug is "we deviate from spec/docs", the body cites the rule, not the code.

- `9fc124f8f92c` MDEV-25415 — quotes SQL Standard `<simple case>` rule directly.
- `addb01fb60d4` MDEV-37740 — `LOCATE is documented to return NULL if any of its arguments is NULL`.

Confidence: high.

### Tests go in the same commit as the fix, in the obvious suite

Most MDEV fixes touch both source and `mysql-test/...result`/`.test` in one commit, and the test is added in the suite already covering the area.

- `7e14749d968e` adds rows to `mysql-test/main/simultaneous_assignment.{result,test}`.
- `addb01fb60d4` adds to `main/func_str.test` (the existing LOCATE coverage).
- `9845026051dd` adds to `main/innodb_group.{result,test}`.
- `9ef20acfbe26` adds to `main/vector_innodb.{result,test}`.
- `9703c90712f3` adds two whole new test files (`main/long_unique_innodb_debug.{test,result}`, `suite/period/innodb_debug.{test,result}`) because the bug needs new fixtures.

Confidence: high.

### Test-only commits exist as their own commits when fix is elsewhere

When the *fix* lives elsewhere (different MDEV, cherry-pick, or upstream), he ships the test as its own commit.

- `823a3a258f03` `MDEV-36205 coverage test` (empty body)
- `8df3524cf38e` `MDEV-37345 temporary table, ALTER, recreate sequence` body: `Test case only. The bug is fixed by cherry-pick of 2d5db535847 ...`
- `886a51d95667` `MDEV-35875 Misleading error message for non-existing ENCRYPTION_KEY_ID` body: `update the test case`.

Confidence: medium.

### Crashes from user-controlled input get `my_safe_alloca` + cap

When a length comes from the client wire format, he caps the on-stack allocation and falls back to `malloc`.

- `b6d0e23d76fe` MDEV-38365 — adds local `MAX_ALLOCA_SZ 4096` plus a `my_safe_alloca`/`my_safe_afree` macro pair to `plugin/auth_mysql_sha2/sha256crypt.c`:
  ```
  #define my_safe_alloca(size) (((size) > MAX_ALLOCA_SZ) ? malloc(size) : alloca(size))
  ```
- `92641e4aa867` MDEV-39478 — similar concern (validates lengths from `COM_STMT_EXECUTE`).

Confidence: medium. Applies to: protocol handlers, plugins receiving raw client bytes.

### Sanitizer fixes are tiny, surgical, and the subject names the sanitizer error

UBSAN/ASAN findings get the sanitizer's raw text as the subject (no MDEV needed).

- `8d6699db90da` — `runtime error: shift exponent 32 is too large for 32-bit type 'int'`; one-line fix: `(key_part_map) (1 << parts)` -> `(key_part_map)1 << parts` (cast precedence to widen first).
- `982535b11f3b` — `overflow/inf in vec_distance_euclidean`; one-line: `float dist` -> `double dist`.

Confidence: medium. Applies to: sanitizer-detected numeric bugs.

### "fix the warning" — change the implementation to suit the policy rather than carry exceptions

When a warning can't be silenced cleanly, he changes the implementation.

- `a18f8d38563b` body: `cannot add new warnings in 11.8 anymore: * remove ER_WARN_DEFAULT_SYNTAX * use ER_VARIABLE_IGNORED instead * change the wording in it to be more generic`. Fixes the policy mismatch by reusing an existing error code rather than adding a new one.

Confidence: low (1 ex). Applies to: stable-branch fixes where API/error additions are forbidden.

### "relax assert" is preferred wording when the assertion was wrong, not the code

When the bug is that an assertion is too tight, he says so explicitly.

- `96b8f636a9c4` `relax assert to account for recursive RETURNS TEXT functions`.
- `b930eef31787` MDEV-37326 body: `... the assert is over-zealous. but in the future it might be actually closed.` — still keeps a fallback path.

Confidence: medium.

### Minimal patches preferred; he won't refactor surroundings to fit a fix

Most MDEV fixes are 1-10 line code changes plus tests. He resists incidental cleanups inside fix commits — those go in separate `cleanup:` commits.

- `addb01fb60d4` — 3-line `item_func.cc` change.
- `82c0008e327d` — empty body, 1-line: change `null-rejecting` property of `Item_func_quote`.
- `b6fd9f1e77d9` — 2-line: `also check number of columns`.
- `b1daecfc4514` — 1-line yacc deletion.
- `87fdb5ac62db` — 1-line restore in `sql_admin.cc`.

Larger restructures are flagged either with `cleanup:` or with explicit multi-bullet bodies (e.g. `92641e4aa867`, `a2b62fe57257`).

Confidence: high.

---

## Architecture / API choices

### Compatibility is named and preserved explicitly in bodies

When changing default behaviour he calls out the backward-compatibility decision in plain prose.

- `7d08434f674a` — `we don't want to remove a variable for compatibility reasons`.
- `b998e3a7b950` — `* enable use_cache_on_timeout by default and deprecate it / * increase cache_timeout to max and deprecate it / ... * delete both in 13.3`.
- `b9ae75d661ca` MDEV-37998 — `For backward compatibility, though, let's keep copying constant default values and the "compressed" attribute.`

Confidence: high. Applies to: anything visible to users / DBAs.

### Plugin API additions get a version bump and a `*.pp` pin

He bumps `MYSQL_AUTHENTICATION_INTERFACE_VERSION` and updates the `*.h.pp` snapshot in the same commit when a struct gains a field.

- `c0233a09eeec` MDEV-37600 — `#define MYSQL_AUTHENTICATION_INTERFACE_VERSION 0x0202` -> `0x0203`, also updates `plugin_auth_common.h` adding `int tls;` and refreshes `*.h.pp`.

Confidence: medium (1 ex but archetypal). Applies to: plugin headers in `include/mysql/`.

### Helpers are introduced as small inline methods on the relevant class

When he needs a predicate used in 2-3 places, he adds it as a method on the existing class — not as a free function.

- `823e62523348` adds `bool LEX::is_in_sf_or_trg()` (5-line impl in `sql_lex.cc`, decl in `sql_lex.h`) rather than open-coding the three sp_handler comparisons in `sql_yacc.yy`.

Confidence: medium.

### Destructors over manual cleanup-call sites

When the same cleanup is forgotten in N call sites, the response is to put it in the destructor and remove the calls.

- `85b713b2a3af` `free Sql_path in the destructor, perform cleanup in cleanup()` — deletes `path.free()` calls from `sys_var_end`, `THD::~THD`, `plugin_thdvar_cleanup`, `Sp_handler::db_find_routine`, `sp_head::~sp_head` and adds `~Sql_path() { free(); }`.

Confidence: medium.

### New storage-engine flags rather than special cases in the server

Where the fix needs the engine to opt in/out of behaviour, he adds a `HA_*` flag and threads it through.

- `9703c90712f3` adds `HA_CHECK_UNIQUE_AFTER_WRITE` to `handler.h`, then branches on `ha_table_flags()` in `handler::check_duplicate_long_entry_key` and `handler::ha_check_overlaps`.

Confidence: medium. Applies to: handler API extensions.

### `Stat` accumulators get parallel-mergeable definitions and a research escape hatch

When adding statistics, he writes them so they can be combined out of order, and gates extended-research stats behind a compile-time switch.

- `c06a25e49570` — `stats_collector` with parallel Welford's online algorithm, plus `#define STATS_NON_GAUSSIAN 0 /* 0 for no, 3 for yes */` to enable M3/M4 without forking the code.

Confidence: low (1 ex). Applies to: vector/optimizer instrumentation.

---

## Domain quirks (JSON, parser, ACL, vector, etc.)

### Parser changes are paired between `sql_yacc.yy` and a method on `LEX`/`Lex`

He keeps grammar actions short and pushes logic into named methods on `LEX`. The yacc edit calls the method and emits `my_error` + `MYSQL_YYABORT`.

- `823e62523348` — yacc calls `Lex->is_in_sf_or_trg()` and aborts; method body lives in `sql_lex.cc`.
- `bd0dc4006e8a` — simplifies an `opt_where_clause` action by removing a redundant null check (`if ($3)` — can never be NULL).
- `b1daecfc4514` — single-line yacc deletion to drop unwanted initialisation of `$$->auth`.

Confidence: high (consistent with the rest of his parser work). Applies to: `sql/sql_yacc.yy`.

### CURRENT_SCHEMA / PATH is a recent focus; assume new logic is incomplete and pin tests

This sample contains seven commits around `Sql_path` / `CURRENT_SCHEMA` / `SET PATH`:
- `8b1ccf6e8213`, `823e62523348`, `8260be640869` (`don't backtick-quote CURRENT_SCHEMA`), `875c128751cb` (`more tests for duplicate values in path`), `85b713b2a3af`, `a1c1dba49850`, `afc8a33496b0`, `be67aff19b43` (`Don't implicitly search in CURRENT_SCHEMA`).

Several bodies admit incomplete prior work — `be67aff19b43` body: `the intention was not to, but some code paths weren't fixed yet`. Pattern: he ships multiple narrow follow-ups rather than one big patch.

Confidence: high (within this chunk). Applies to: `sql/sql_path.{cc,h}`, related yacc rules.

### JSON-engine fixes prefer reusing existing `dynstr_*` helpers over hand-rolled buffers

- `93ef1236002f` MDEV-38356 — replaces `strncpy((char*)a_res.str, val.ptr(), je->value_len);` with `dynstr_set(&a_res, val.c_ptr());`. The hand-rolled copy was racy w.r.t. the dynstr's allocated capacity.

Confidence: low. Applies to: `sql/json_*.cc`.

### Vector code (mhnsw) is *his* — lots of micro-tweaks, deep math comments, terse subjects

Vector/MHNSW commits in this chunk are concentrated and stylistically distinctive: bodies often empty, code dense with std-math, comments brief.

- `a4f17dc64f29`, `982535b11f3b` (empty bodies, one-liners).
- `c06a25e49570` shows the contrast: long body when the algorithm change is non-obvious.
- `9d3af2c8e31a`, `9ef20acfbe26`, `9412821dbd47`, `a158bbb1a2b0`, `84987d1471b9`, `98f1623af871`.

Confidence: high (chunk-internal). Applies to: `sql/vector_*.{cc,h}`.

### ACL fixes: minimal, targeted, body explains the wrong assumption

ACL commits in this chunk are small and the bodies focus on the wrong piece of state.

- `b163b8f1c560` MDEV-28773 — `as elsewhere, it a priv table doesn't exist - skip it / only update in-memory structures`.
- `ac493871999e` MDEV-37506 — bulleted body explaining failure path and version increment.
- `b6fd9f1e77d9` MDEV-28482 — body just says `also check number of columns`.
- `bc977fb0084c` MDEV-37971 — body explains existing inconsistency before stating the change.
- `957ec8bba6ca` -> `7e49bffa29b4` is a self-revert when validation was too strict for cross-version upgrades.

Confidence: high. Applies to: `sql/sql_acl.cc`, `sql/sql_servers.cc`.

### Error-message hygiene: no trailing newlines, no empty messages

Two complementary fixes:
- `9306353d2d04` MDEV-36753 — `remove '\n' from error log messages`.
- `a9fdd946f64c` MDEV-38868 — `avoid empty error messages in failed CONNECT assisted discovery`; falls back to `my_error(ER_GET_ERRNO, ...)` if `g->Message[0]` is empty.

Confidence: medium. Applies to: any `my_printf_error`/`my_error` call site.

### CMake/build fixes get one-line bodies that name the rule violated

- `8229217206ff` body: `cmake generator expressions are expanded *during the build step*. If the file is created *during the configuration step* its name cannot use generator expressions.`
- `929bb98595ab` body: `include headers needed to build plugins, same as in RPMs`.

Confidence: medium. Applies to: `cmake/`, `debian/`.

---

## Maintenance branch handling

### Merge subjects are exactly `Merge branch 'X.Y' into Z.W`, body empty unless rebase touched logic

In this sample: `9161270a116d`, `9bfea48ce121`, `a6f55550082b`, `aab83aecdca1`, `b15d1adf85c5`, `b29d3779e42f`, `b565b3e7e041` — six of seven have empty bodies. The exception (`aab83aecdca1`) explains a row-ordering test fixup needed during the merge:

> `main/statistics_json.result is updated for f8ba5ced551 (MDEV-36099) ... before f8ba5ced551 delete was deleting rows one by one ... MDEV-36099 fixes this bug ...`

So: merge body is empty by default; only present when he had to *resolve* a conflict via judgement, not just textual merge.

Confidence: high.

### Same MDEV gets a different commit per branch with `(N.M version)` in the subject

When a fix needs distinct code per release branch he tags the variant in parens.

- `aa6a2e6bf05d` — `MDEV-37345 sequences and prelocking (11.4 version)`.

Confidence: low (1 ex but distinctive).

### Stable branches refuse new error codes; reuse existing ones

For 11.8-targeted fixes he calls out the policy explicitly.

- `a18f8d38563b` body: `cannot add new warnings in 11.8 anymore: * remove ER_WARN_DEFAULT_SYNTAX * use ER_VARIABLE_IGNORED instead`.

Confidence: low. Applies to: stable / maintenance-branch commits.

### Version-bump commits are minimal and have empty bodies

Bumping a submodule or a marketing version: just the bump, no body.

- `809e6f4195da` — `12.3 branch` (VERSION, debian/changelog, sysvars_star.result).
- `a0759bf017df` — `Connector/C 3.3.17`.
- `a3c3db769307` — `update WolfSSL to 5.8.0-stable`.
- `a99dfa26d394` — `HeidiSQL 12.11`.
- `b0a2b921cc7a` — `ColumnStore 6.4.11-1`.

Confidence: high.

---

## Singletons worth noting

- `9703c90712f3` (MDEV-37199, UNIQUE w/ READ COMMITTED) is the only commit in this chunk where he ships two brand-new `.test`/`.result` file pairs in one go (the rest extend existing ones). Justified by needing new fixtures.
- `b6d0e23d76fe` defines `MAX_ALLOCA_SZ`/`my_safe_alloca`/`my_safe_afree` macros locally in a `.c` file rather than promoting them to `my_alloca.h`. Future repeats may move them out.
- `c06a25e49570` ships a research artefact (`STATS_NON_GAUSSIAN` toggle, M3/M4 collection) in production code — preserved behind a `0` flag with comment `0 for no, 3 for yes`.
- `b88576ea1956` switches sphinx tests from suite-level `--require-sphinx` gating to per-test gating, with the subject as `cleanup: sphinx tests` and body explaining the policy: run them even without sphinx, skip individually.
- `90f5e0995638` `fix tests for --view` — explicit acknowledgement that an earlier commit (`bead24b7f3df`) unintentionally widened test coverage, and treats the broadened coverage as a *bug* to be cleaned up by fixing tests rather than reverting the change.
- `7e49bffa29b4` is a *self-revert* of his own earlier fix `957ec8bba6c` (MDEV-35622) — body just says `Revert the fix for MDEV-35622 (957ec8bba6c).` plus one explanatory paragraph. He's comfortable reverting himself.
- `bfcd2674a3b2` — re-disables `--view-protocol` for tests with `body: creating and dropping views doesn't work very well with transactions`. He fixes the test infrastructure not the protocol.
- `aca6743d5345` MDEV-39289 fixes a Windows-specific command-injection by switching from `system()`-style to `_spawnlp` (no escaping needed) — solution by API choice rather than escaping logic.
