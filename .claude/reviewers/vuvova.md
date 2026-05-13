# Sergei Golubchik (`vuvova`) — reviewer profile

**Role**: lead maintainer of MariaDB Server, owner of the parser / ACL / vector / connector / packaging / charset / replication / server-core areas; default "final reviewer" for non-InnoDB work; he is also the person who ultimately merges most PRs.

**Window analysed**: 2025-05-13 → 2026-05-13 (12 months).
**Corpus**: 375 unique commits authored across all maintained branches + 346 of his comments (266 line, 48 review-body, 32 issue) on 71 PRs.

**Use this doc to**:
1. write code and commits that pass his review on the first iteration, and
2. interpret his comments (catchphrases, severity, what he *means* by short questions).

The profile is reviewer-personal; it does **not** replace `.claude/review/*.md`, `CODING_STANDARDS.md`, or the `mfix` skill — it complements them with what he specifically does differently or insists on.

---

## TL;DR — the highest-signal rules

These are the patterns that fire on **>5 commits or >3 reviews** and where deviation almost always draws a comment.

1. **Commit subject is `MDEV-NNNNN <description>` — no colon.** 205/206 of his MDEV commits use this form. He paraphrases the JIRA title verbatim, accepting subjects up to 130+ chars when needed.
2. **Non-MDEV commits use a lowercase prefix-word**: `cleanup:`, `fix `, `remove `, `bump `, `make `, `correct `, `mtr:`, `CONNECT:`. No initial capital. No trailing period.
3. **`cleanup:` commits are strictly single-purpose** and almost always land *before* the related MDEV fix.
4. **One logical change per commit, but not "exactly one commit"** — he accepts multi-commit PRs when each commit is a distinct logical change. The squash-on-merge step is also acceptable to him: "Looks good, please squash into one commit, then I'll merge."
5. **Cross-references use bare 12-char SHA**: `followup for 649216e70d87`, `(cherry picked from commit <40-hex>)`. No "see commit", no parentheses around the SHA except when reverting.
6. **Body explains the *cause*, not "what I changed"**. ~30 % of his commits have an empty body — he treats the subject + diff as self-documenting for trivial fixes.
7. **Tests live in the same commit as the fix**, in the smallest *existing* `.test` file that already covers the area. New `.test` files are rare and reserved for genuinely new fixtures.
8. **Test-only commits exist**, named with the verbatim phrase **"fix the test"**, **"update test results"**, **"fix sporadic failures on …"**, **"add test cases for …"**.
9. **Match the file's existing style** — he uses `nullptr`/`NULL`/`0`, `static_cast`/C-style cast, `TRUE`/`FALSE`/`true`/`false`, all depending on the surrounding file. He does not run style migrations on code he merely edits.
10. **Push fixes into the layer that *owns* the invariant.** When in doubt, fix the *caller* rather than widen a utility. Don't fix many places when one upstream fix would do.
11. **Don't widen APIs to accept invalid input.** Reject empty strings, NULL, etc. at the caller; don't add tolerance to the utility.
12. **Engine-specific behaviour goes in the engine.** Check `table_flags()`, add a `HA_*` flag, or override an engine method. Don't `if (engine_name == "InnoDB")` in the server.
13. **Validity checks live in the right callback**: in `check` (not `update`) for sysvars; in the parser (yacc) for type validity; in `fix_fields()` only when the check can be done there exhaustively, otherwise add an explicit `check_*()` method.
14. **`%iE` (13.0+) or `%M` (10.11) for errno** in `sql_print_*`. Never hand-enumerate `EACCES`/`EMFILE`/etc.
15. **Reuse existing error codes** — especially `ER_STD_INVALID_ARGUMENT` and `ER_INVALID_ARGUMENT_FOR_LOGARITHM`. In stable branches he refuses to add new warnings at all.
16. **User-facing errors do not go to the error log.** Either drop `ME_ERROR_LOG`, or use `sql_print_error` (deliberately) but not both.
17. **Bug fixes on the lowest still-maintained branch where the bug exists**; features on `main`. The phrase is "the lowest affected but not older than three years GA branch for bugs, main for features and refactorings."
18. **Forward-merges follow the chain** `10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → main`. Merge subjects are exactly `Merge branch 'X.Y' into Z.A`; bodies are empty unless he resolved a non-trivial conflict.
19. **For sanitizer-found bugs the commit subject is the raw sanitizer output** (no MDEV needed if there isn't one). The fix changes the *type* or *algebra*, not "insert a cast to silence the warning."
20. **"why?"** as a one-word review comment is his most common interaction shape — it means "justify this or remove it." Three escalations: `why?`, `why??`, `why???`.

---

## How he writes commit messages

### Subject

- **`MDEV-NNNNN <Jira title verbatim>` — no colon, no separator word.**
  - 205/206 of his MDEV commits in the window are no-colon. The single colon outlier is `e1ce61f0` `MDEV-39301: fix main.xa - Timeout in wait_until_count_sessions.inc` — a backport.
  - Subject length is limited only by the JIRA title; he routinely exceeds 50/72/80 chars. The longest in the window is 153 chars (`cb31d753`). He never abbreviates the JIRA title to fit.
- **Non-MDEV subjects** are lowercase, no initial capital, no period. The accepted prefix-words and their canonical use:
  - `cleanup:` — pure refactor, no behaviour change. Optionally combined with MDEV: `MDEV-35897 cleanup: Stats structure`. Examples: `cleanup: ha_partition::m_rec0`, `cleanup: generocity->leniency`, `cleanup: long unique checks`, `cleanup: move constraint tests from check.test to check_constraint.test`.
  - `fix ` — small test/build fix or follow-up. `fix a memory leak in sysvars`, `fix sporadic failures of rpl.rpl_drop_temp test`, `fix the test to not leave $datadir/test/imp_t1.ibd around`.
  - `remove ` — deletion. `remove LEX::make_sp_name_sql_path()`, `remove unused new modes constants`, `remove questionable vector search optimizations`.
  - `bump ` — version/maturity. `bump the VERSION`, `bump uuid_v4 and uuid_v7 plugin maturity to stable`.
  - `make ` — test reliability. `make the test clearer`, `make max_session_mem_used tests more reliable`.
  - `correct ` — semantic correction without a ticket. `correct sql_command_flags: add CF_CHANGES_DATA as needed`.
  - `mtr:` — `mariadb-test-run` infrastructure: `mtr: make wait_for_line_count_in_file.inc leave traces in the log`.
  - `CONNECT:` / `InnoDB:` — engine-specific work that doesn't have an MDEV: `CONNECT: suppress \n at the end of the error message`.
  - `(clang20) ` / `(11.4 version)` — parenthetical compiler/branch tag.
  - bare imperative `don't ...` / `update ColumnStore` / `zlib 1.3.2` are also accepted.
- **Stable-branch backport** subject often carries the variant in parens: `MDEV-37345 sequences and prelocking (11.4 version)`.
- **Reverts**: `Revert "MDEV-17256 Decimal field multiplication bug." (57898316b6fb).` — full SHA in parens.

### Body

- **Body is terse, imperative, often empty.** ~30 % of non-merge commits have no body. When present, the median is ~120 chars. He uses no markdown headings, no `Co-Authored-By:` trailers, no `Signed-off-by:` trailers.
- **First line of body is lowercased and continues the subject grammatically**, often without a final period. Reads like an inline code comment. Examples: "rewrite the check to use mysql.global_priv (finally!)", "it's not an error, as the server continues anyway", "set thd->lex->default_used accordingly".
- **Bullet bodies use `*` (asterisk + space), never `-`**:
  ```
  * remove redundant checks for `len` in `get_param_length()`
  * validate return value `length` in `get_param_length()`
  * fix all `Item_param::set_param_XXX()` methods to never read past `len`
  ```
- **Multi-cause / multi-fix fixes use numbered enumeration** (`1.`, `2.`) when prose would obscure them.
- **`followup for <12-char-sha>` is a literal phrase** on its own line, optionally followed by `(MDEV-N description)`:
  ```
  followup for 9703c90712f3 (MDEV-37199 UNIQUE KEY USING HASH ...)
  ```
- **Cherry-picks** use the standard `(cherry picked from commit <40-hex>)` trailer, *or* the informal `Cherry-pick from 11.8`. Both are seen.
- **Reporter credit** goes at the very end of the body: `Reported by Aisle Research`, `Discovered by: Aakash Adhikari`, `Reported by Pavel Kohout, Aisle Research, www.aisle.com`. No `Reported-by:` syntax.
- **Cross-MDEV references** in bodies are flat lists with `also fixes: MDEV-X, MDEV-Y, MDEV-Z`.
- **For warnings/errors that cannot be changed in a stable branch**, the body explicitly cites the policy: `cannot add new warnings in 11.8 anymore: * remove ER_WARN_DEFAULT_SYNTAX * use ER_VARIABLE_IGNORED instead`.

---

## How he writes code

### Style baseline

He follows `CODING_STANDARDS.md` strictly, plus the following observed habits:

- **Match the file's existing style.** This is the strongest pattern. In `.c` files: `NULL`, `TRUE`/`FALSE`, C-style casts. In new `.cc` he writes: `nullptr`, C-style for trivially-safe casts, `static_cast` for downcasts/narrowing. He does *not* migrate styles in files he merely edits.
- **`auto` for verbose types only.** `auto trx= static_cast<MHNSW_Trx*>(thd_get_ha_data(thd, &tp))`, `auto length= thd->variables.path.text_format_nbytes_needed()`. Never `auto x= 0;`.
- **Internal typedefs** (`uchar`, `uint`, `uint32`) preferred over `<cstdint>` types — he only writes `int16_t`/`size_t`/`uint64_t` when the surrounding code uses them.
- **Two blank lines between out-of-line function definitions.** He preserves this even when inserting a new helper next to existing ones.

### Variable & control-flow patterns he *uses*

- **`if (T *p = expr)` collapsed declaration + check.** This is the *one place* he routinely declares inside an `if`. He'll nest two of them:
  ```cpp
  if (Vio *vio= thd->net.vio)
    if (SSL *ssl= (SSL *) vio->ssl_arg)
    { ... }
  ```
- **Variable hoisting**: replaces a chain of `info->table->...` with `TABLE *table= info->table; ...` at the top of the block when it removes 3+ member chains.
- **Drops `unlikely(...)` wrappers when restructuring an `if` chain** because they obscure the diff. He keeps `unlikely` only when the surrounding code already had it AND the line is otherwise unchanged.
- **Uses `goto end;` / `goto err;`** for cleanup paths in C code — single cleanup block, not RAII or duplicated cleanup.
- **Spelled-out timeouts/sizes**: `24*60*60*1000`, `60*1000`, `MY_ALIGN(sizeof(my_memory_header), 16)`. Multiplications stay legible.

### Casts

- **C-style casts for trivially-safe numeric / pointer-to-char**: `(uchar*) ptr`, `(int) (p - src)`, `(size_t) reclength`. He doesn't introduce `static_cast` casually.
- **`static_cast<T*>(...)` for non-trivial pointer downcasts**: `static_cast<const FVectorNode*>(elem)`, `static_cast<MHNSW_Trx*>(thd_get_ha_data(thd, &tp))`.
- **`reinterpret_cast<T*>(...)` when he wants to silence UBSAN** for a downcast he's proven safe, with a debug-only guard (`71d4cae8668d`).
- **Constructor-style cast** (`int(x)`, `uint16(x)`) is rare in his code — *but* the InnoDB dialect uses it, so he accepts/encourages it in InnoDB review.

### Comments

- **Comments are sparse and short.** Inline `//` C++ comments are one-line fragments; he reserves multi-line block comments for non-obvious algorithms.
- **Comments explain *why*, not *what*.** The function name + signature is supposed to explain *what*.
- **Inline comments tag intent**: `set_if_bigger(p->ctx->diameter, max_distance); // not atomic, but it's ok`, `if (b1[frac1] == 0) /* lossless */ frac1--;`.
- **No MDEV titles in code comments.** *"Also, don't mention MDEV in the comment."* (PR #4682). The MDEV reference goes in the commit message, not in the source.
- **Helpers get a 1–3-line `/* ... */` purpose comment** when their name doesn't fully describe them: `/* common set of params for many search/select functions */ struct MHNSW_param { ... };`.
- **Retroactive comments**: when fixing a confusing structure he often leaves an explanatory comment alongside the fix.
- **Delete obsolete comments alongside the code they described** — same commit.

### Assertions — used as documentation

He treats `DBUG_ASSERT` as a free way to *document calling conventions* and invariants:

- *"add an assert to document calling conventions"* is literally the entire body of `d78cf265`.
- He **adds** asserts when an invariant is non-obvious: `DBUG_ASSERT(buf == table->record[0] || buf == table->record[1])`, `DBUG_ASSERT(null_ptr < ptr); DBUG_ASSERT(ptr - null_ptr <= (int)table->s->rec_buff_length);`.
- He **relaxes** asserts when they prove false on legitimate input — pairs the relaxation with a body that names the legitimate exception. Example: `DBUG_ASSERT(str[strlen(str)-1] != '\n')` → `... != '\n' || strlen(str) == MYSQL_ERRMSG_SIZE-1` for truncated-at-newline messages.
- He **removes** asserts that check user-supplied / on-disk data: *"remove assertions that a file read from disk contains a specific substring."*
- When a fix is purely "add an invariant assert", that's the whole commit. No tests, no other changes.

### Buffers, strings, allocation

- **`my_safe_alloca` / `my_safe_afree` over bare `alloca`** when the buffer size may exceed a small constant. Sometimes he defines the macro locally: `#define my_safe_alloca(size) (((size) > MAX_ALLOCA_SZ) ? malloc(size) : alloca(size))`.
- **`StringBuffer<N>` over `String` for stack-allocated short buffers.**
- **`bzero((void*)&x, sizeof x)`, `memcpy((void*)&dst, &src, sizeof src)`** for struct overwrites — avoids implicit copy-assign issues.
- **`safe_str(...)`** when reading possibly-NULL `LEX_CSTRING.str` from disk: *"don't trust the content of a file read from disk."*
- **Named sentinels over hand-coded ones**: `MY_FILEPOS_ERROR` / `MY_FILE_ERROR` replace `~(my_off_t) 0`.

### Containers / algorithms

- **In-tree typed containers preferred over STL**: `Hash_set<T>`, `List<T>`, `List_iterator_fast`. He migrates raw `HASH` to `Hash_set<T>` in cleanups.
- **`std::max`, `std::min`, `std::abs`, `std::round`, `std::sqrt`, `std::isfinite`, `std::nextafter`** in new vector/numeric code, but `MY_MAX`/`MY_MIN` is left alone in existing code.
- **`std::move` for big-struct moves.** He'll add `m_path(std::move(thd->variables.path))` etc.
- **`std::function` / `std::unordered_map` are essentially absent from his code.** He won't accept them in reviews either.
- **Single allocation in one chunk**, not one allocation per element. *"allocate Sql_path in one memory chunk, not one per schema."*

### Enums, flags, macros

- **Strongly-typed `enum X : uint { ... }` over `#define`-based bitfields**, with file-local overloaded `operator|` / `operator|=` defined inline alongside the enum.
- **`enum <topic>_fields { ..., <TOPIC>_FIELDS_COUNT }` for system-table column indexes**, with trailing `_COUNT` member used in `table->s->fields < <TOPIC>_FIELDS_COUNT` validity checks.
- **`CREATE_TYPELIB_FOR(arr)` macro** for new `TYPELIB` initializers (instead of `TYPELIB x= { array_elements(a)-1, "", a, NULL, NULL };`).
- **Macros remain the right answer for cross-platform / vendor abstraction.** He adds `#undef X` + `#define X(...)` in `include/ssl_compat.h` to emulate OpenSSL on WolfSSL, not a C++ wrapper.

---

## Refactoring habits

### One logical change per commit

- *"No, absolutely not. It often can (and should) do with a single commit. But it's not an absolute rule, it depends on the case. If a contributor puts unrelated changes in one commit we will ask him to split it. Say, one commit = one logical change."* (PR #5007)
- He routinely lands a `cleanup:` commit *immediately before* the related fix commit. The cleanup removes redundancy so the real fix is small.

### `cleanup:` commits

- Single-purpose. The subject describes the *thing* being cleaned (noun phrase), not the action.
- The body is empty when the diff speaks for itself, otherwise one paragraph stating that *no behaviour changes* (when accurate).
- Can be very wide if mechanical and uniform — `cleanup: disconnect before DROP USER` touches 40+ test files identically; the body explains the project policy reason.

### Renames

- Rename first, fix later — separate commits.
- Rename commit subject: `cleanup: <old>-><new>` or `MDEV-N <new>-or-context`.
- Always restate the rationale in one sentence in the body: *"as a more fitting English word here"*.

### Dead code removal

- Delete dead helpers immediately when their precondition is gone — don't leave for "completeness". Examples: `Sql_path::resolve_recursive_routine`, the entire `des_key_file.{cc,h}` family.
- Delete the comments that explained the deleted code in the same commit.
- Remove `MYSQL_VERSION_ID > NNNN` ifdefs that have aged out, but **skip externally-hosted engines** (connect, mroonga, columnstore).
- When `#define HAVE_FOO` is always defined, remove it everywhere.

### Helper extraction

- Extract helpers only when the same multi-line dance repeats verbatim 2+ times.
- Helpers go as **methods on the relevant class**, not free functions. `LEX::is_in_sf_or_trg()`, `TABLE::check_sequence_privileges()`. The yacc edit calls the method and emits `my_error` + `MYSQL_YYABORT`.
- File-local helpers are `static` in the `.c`/`.cc`, raising errors themselves rather than at the caller. Callers do `if (!plugin_table_is_valid(table)) goto end;`.

### Bundling arguments

- Bundle 3+ co-traveling arguments into a `struct <topic>_param`. *"put common arguments of many functions into one "param" structure, instead of passing them every time independently."* Example: `MHNSW_param`.
- Pass the bundle by pointer; happy to change 5–10 call sites at once.

### Add a parameter instead of duplicating

- Add a `bool with_db` (or similar) to an existing method instead of spawning a near-duplicate.
- Example: he turned `make_sp_name()` + `make_sp_name_sql_path()` into one method with a `bool with_db` flag.

### Move transient state from THD to the C++ stack

> *"Do it on the stack like for sql_mode, sctx, abort_on_warning, and other THD properties that often need to be changed temporarily."*

- Pattern: introduce an `XYZ_instant_set` class whose ctor saves+overwrites a THD field and dtor restores it.

### Plugin-API additions

- New struct member → bump `MYSQL_<NAME>_INTERFACE_VERSION` from `0xMMmm` to `0xMM(mm+1)` and update the `*.h.pp` snapshot **in the same commit**.

---

## Bug-fix approach

### The shape of a typical fix

- **Test + fix in the same commit.** Test goes in the smallest *existing* `.test` file that already covers the area. He resists creating new `.test` files; exceptions are large new feature areas or bugs needing new fixtures.
- **Body diagnoses the wrong assumption** in the original code, then states the corrective principle. He rarely lists files changed.
- **Test-only commits exist** when the fix lives elsewhere (different MDEV, cherry-pick, upstream). Subject form: `MDEV-N <topic> coverage test` or `MDEV-N <topic>` with body `Test case only. The bug is fixed by cherry-pick of <sha>`.
- **Test-only follow-ups** for `.test` / `.result` files use exact phrases: `fix the test`, `update test results`, `fix sporadic failures on <suite>.<test>` (sometimes with a `--combination` suffix), `fix sporadic failures on main.user_var --view`.

### What the fix touches

- **Minimal patches dominate** — 1–10 lines of code + a test. Larger restructures are flagged either as separate `cleanup:` commits or via explicit multi-bullet bodies.
- **For sanitizer-found bugs** he changes the *type* or *algebra*, not the operation:
  - UBSAN narrowing: `uint count;` → `int count;` and rewrite the comparison.
  - UBSAN shift: `(key_part_map)(1 << parts)` → `(key_part_map)1 << parts` (precedence fix to widen first).
  - UBSAN inf: rewrite division to capture divisor in a local of `double` type so the zero-check uses the same value.
  - UBSAN nonzero-offset-from-null: change `(!=)` to `(||)` semantics when the predicate was wrong anyway.
- **For NULL/empty-string crashes** (read-from-disk data): introduce `safe_str(...)` over each `.str` access, not per-call null checks.
- **For user-controlled lengths** (wire-format / plugin auth): `my_safe_alloca` with explicit `MAX_ALLOCA_SZ` cap.
- **For "fix the test"** that doesn't expose a real bug: he edits the test harness (`client/mysqltest.cc`), not the test (one place vs. dozens of `.test` files).

### Severity reductions

- Demote `sql_print_error` → `sql_print_warning` when the server "continues anyway." Body: *"it's not an error, as the server continues anyway."*
- Gate noisy `sql_print_information` with `if (global_system_variables.log_warnings > 2)`. Convention he stated: startup/shutdown at `>0`, runtime notes at `>2`, abnormal becomes `[Error]`.

### "Reported by …"

- Crediting external researchers: append `Reported by <Person/Org>` (or `Discovered by …`) at the end of the body. No special trailer.

---

## What he asks of others (review preferences)

These are patterns he repeatedly asks for in PRs he reviews — the most-frequent "fix this before I'll approve" requests.

### Architecture

- **Push the special case into the engine that has it.** Don't introduce server-side branches by engine name. *"If we get another such storage engine, we can adjust this logic. But for now, all these special cases will be spread everywhere through the code. … So my preference would be not to introduce them in the first place."* (PR #4050)
- **Engine capability via `table_flags()`, not bespoke checks.** *"It must be either table_flags() check or something that doesn't need any capability checks at all."* (PR #4627)
- **High-Level indexes (HNSW) live above the engine layer**, not in it. Size checks, validity checks, etc. go in the server, not in InnoDB/Aria. *"this is completely wrong. … 'hlindexes' are called High-Level Indexes because they are implemented on a higher level, not in the engine, but above it."* (PR #4706)
- **Don't widen utility APIs to accept invalid input.** *"Empty string is an invalid path, just don't pass it to my_realpath() in the first place."* (PR #4865)
- **Fix the root cause once, not normalize in every call site.** *"Fixing all val_real() everywhere is error prone (easy to miss something), not future proof. … The problem is not that a zero value can be negative. … This is easy to fix in dtoa.c. … fix hp_rec_hashnr(). … do not fix every place where floating point calculations can happen."* (PR #4632)
- **Validity checks live in the `check` callback, not `update`.** (sysvars)
- **Validity checks live in the parser when they're type-syntax checks.** *"why do you need a new allowed() method when you can put the check into Column_definition_set_attributes()? … Perhaps you can move the check into the parser?"* (PR #4287)
- **Don't relax an assertion to allow a buggy behaviour. Better keep the assert and fix the bug.** (PR #4161)
- **Don't leave artifacts on failure.** A function that creates X must clean up X on failure before returning. (PR #4659, modelled on `ha_partition::create()`)
- **Don't introduce parallel utilities** when one exists. *"don't use make_unique_invisible_field_name(). It does pretty much the same as make_internal_field_name() … except that make_internal_field_name() is actually used."* (PR #4718)
- **2PC discipline**: any transaction that writes to binlog must go through `tc->prepare()` — commit *or* rollback. (PR #4301)

### Style

- **Comments must add information.** Drop opinions, mood, and MDEV titles. *"drop these comments, they aren't helpful in the long run. The function name is good and clearly explains what it does."* (PR #4254). *"Also, don't mention MDEV in the comment."* (PR #4682). *"dunno, looks hackish."* (PR #4633 — pushing back on a self-deprecating code comment).
- **Match the file's existing comment style** — *"use the same comment style as elsewhere in this file."*
- **Don't comment-out code, just remove it.**
- **`current_thd` is the spelled name** (it's a macro for `_current_thd()`).
- **Use named parameters in public header declarations.** *"it's impossible to understand what the function is doing otherwise."*
- **Many helpers should be `static` inside their `.c`** rather than exposed in a header. *"judging from how many files you had to change, many of these functions can be static in my_compress.c."*
- **Don't pass `void*` when you mean `Compress_buffer*`.**
- **Defensive checks: prove every clause is reachable, otherwise drop.** He enumerates each `!` clause of a long predicate and asks "is it even possible here?" *"I understand defensive programming, but I think it's way too much defensive."* (PR #4718)

### Memory / allocation

- **`alloca` is unacceptable for unbounded input.** Use `my_safe_alloca`, `malloc/free`, or a class-member `String` buffer that persists across calls. (PR #4096)
- **Don't allocate from `thd->mem_root` per-row.** `mem_root` is freed as a whole. Allocate once per statement at most.
- **Use the *execution* arena, not the *statement* arena, for things that should live across executions of the same statement.** Difference matters for prepared statements: execution arena is freed after every execute; statement arena has the lifetime of the prepared statement.
- **Don't copy a `CHARSET_INFO`** — take the address: `CHARSET_INFO *cs= &my_charset_utf8mb4_general_ci;`.

### Containers / libraries

- **`StringBuffer<>` over manual concat / allocation.** (PR #4618)
- **`strxnmov` / `my_snprintf` over `std::string` concatenation.** *"why do you create a static std::string, if all you ever need is char*?"* (PR #4096)
- **Keep small headers dependency-free.** *"my_bit.h, again, is a small clean header-only library with no dependencies. don't contaminate with my_global.h or mysys or anything."* (PR #4504)
- **`my_global.h` is not for plugins.** Plugins should use `libservices/` services.
- **Server services from plugins, not reimplementation.** *"don't use strftime. The server already has date-to-string formatting functions DATE_FORMAT()."* If the service is missing, add a method to an existing service before creating a new one.
- **`mysql_*` instrumented wrappers only where Performance Schema cares.** Plain `socket()`, `connect()` etc. elsewhere.
- **`CREATE_TYPELIB_FOR()` macro** for new `TYPELIB` initializers.

### Error / message wording

- **`%iE` (13.0+) or `%M` (10.11) for `errno`.** *"I'd use just `sql_print_error("Cannot create a socket: %iE. Aborting", errno);` note it's %iE in 13.0 but %M in 10.11."* (PR #4874)
- **Reuse existing error codes.** Specifically `ER_STD_INVALID_ARGUMENT`, `ER_INVALID_ARGUMENT_FOR_LOGARITHM`. *"This patently stupid error message came from MySQL where it should've never been added in the first place. We shouldn't use it … Let's not create too many very specific errors."* (PR #4569)
- **User-facing errors don't go to the error log.** Drop `ME_ERROR_LOG`. *"yes, the user won't read the error packet … If you want the error in the error log, use MYF(ERROR_LOG) or sql_print_error."* (PR #4281)
- **NULL ≠ empty list.** When a concept is applicable but the list is empty, return empty string, not NULL. (PR #4618)
- **Don't `set_notnull()` on a column declared NOT NULL** — it's redundant.
- **Server should use `sql_print_information()`, not `puts()`.** *"in the server it should be sql_print_information() not puts(). Or nothing at all, client is sufficient, I think."*
- **Drop redundant prefixes in error text.** *"remove 'parsec:' prefix, it's redundant. And may be ' (next supported value)' too, because the variable help text should say that, not a warning message after the fact."*
- **Abort on truly fatal.** If the failure mode is `EMFILE`/`ENFILE`/`ENOMEM`, abort the server. Don't fall through with a misleading recovery.

### Test conventions

- **EXPLAIN of query X must use literally the same SQL as the executed query X.** *"you must have the same query in EXPLAIN and here, otherwise EXPLAIN makes no sense."* (PR #4627)
- **Tests must demonstrate the claimed property.** For vector indexes, use data points where L1 and L2 distance give *different* orderings; for HNSW, build the index with the same metric you're testing. (PR #4654)
- **Add to an existing many-engine test** (e.g. `vector.test`) over creating a new test file. (PR #4706)
- **Boundary cases**: for every new restriction, test `CHANGE COLUMN`, `MODIFY COLUMN`, `DROP COLUMN`, `RENAME COLUMN`, `RENAME INDEX`. (PR #4718)
- **`--echo` end-of-section marker is one line** (`--echo # End of 11.8 tests`).
- **`--echo` MDEV section *opener* is three lines** (frame + `--echo # MDEV-N <title>` + frame).
- **Set the `.opt` file when testing a command-line flag** — don't `--restart` inside the test. Restarts are slow.
- **`--connect con1` already opens the connection.** Don't follow with `--connection con1`.
- **Don't re-invent disconnect-wait** — cherry-pick or use `wait_until_count_sessions.inc`.
- **Print stored bytes to verify**, don't trust the SQL surface. *"print the password here, that is, select left(json_value(...)) from mysql.global.priv where user='t_iter' to verify that the password indeed has a correct iteration character."* (PR #4504)
- **`--replace_result` with specific tokens, not user-controlled values.** Don't match on `$USER` etc.
- **Avoid `max_session_mem_used` and similar fragile triggers.** Prefer creating an obstacle file: *"create a file from mysqltest with the name of the future .idb file, then file creation will fail."*
- **Don't use `DBUG_EXECUTE_IF` if `DEBUG_SYNC` will do.** *"those DBUG_EXECUTE_IF don't improve readability, they're a necessary evil, but still evil."*
- **Use Perl modules in MTR Perl blocks** instead of layering shell trickery: `IO::Socket::UNIX` etc.
- **Wait on log strings, not hard-coded sleeps**, in Perl helpers.

### Commit hygiene asks

- **"Squash to one commit, then I'll merge."** This is the canonical close.
  - Variant: *"And squash commits into two. One with purely style changes and one with functional feature. Thanks."* (PR #4356)
- **One logical change per commit, but not "exactly one commit"** — see TL;DR.
- **Target the lowest still-maintained branch where the bug reproduces.** Features → `main`. Stable branches refuse new error codes.
- **Subject: `MDEV-12345 ` (space, no colon), MDEV at the front.** *"any characters that don't carry information effectively reduce the length of the prefix."*
- **Rebase, don't merge.**

---

## Maintenance branches

- **Forward-merge chain**: `10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → main`. No "merge main into 10.11", no cross-version cherry-picks.
- **Merge subject**: `Merge branch 'X.Y' into Z.A`. Body is **empty** unless he resolved a non-trivial conflict; then a one-line note such as *"main/statistics_json.result is updated for f8ba5ced551 (MDEV-36099) … before f8ba5ced551 delete was deleting rows one by one … MDEV-36099 fixes this bug."*
- **Per-branch variants**: subject tag `(11.4 version)`, `(10.6 version)`. Used when the per-branch patch differs structurally from the same fix on `main`.
- **Backports** state the source SHA in the body: `Backport from 11.8 aa2ac3078fa99c7cf712c29023c48ffe68677e10`.
- **Branch-cut commits**: `12.2 branch`, `13.0 branch`. Empty body. Touch only `VERSION`, `debian/`, `sysvars_star.result`, sometimes `client/mysqlbinlog.cc`.
- **Submodule / vendor bumps**: `update WolfSSL to 5.8.0-stable`, `Connector/C 3.3.17`, `zlib 1.3.2`, `HeidiSQL 12.11`, `ColumnStore 6.4.11-1`, `Update ColumnStore 23.10.5-1`. Empty body.
- **Plugin maturity bumps**: their own commit, one-line, no test. *"bump uuid_v4 and uuid_v7 plugin maturity to stable."*
- **Stable-branch policy** is named explicitly in the commit body when it constrains the fix. *"cannot add new warnings in 11.8 anymore."*
- **Test-result baseline updates** are their own commits: `MDEV-27277 update test results`, `MDEV-15327 fix test results`. Body empty.

---

## Process / interaction patterns

### Approval styles

- **"Looks good, please squash, then I'll merge"** — standard close. He distinguishes the approval from the actual merge; he merges *after* the squash.
- **"Approved either way, but … (suggestion)"** — approval with non-blocking suggestion.
- **"basically ok to push, I'm approving the PR, but please check the following: …"** — approval-with-loose-ends.
- **"I don't insist, but …"** — a suggestion he expects you to consider, won't block on.

### Second reviewer

- He **explicitly hands off to a domain owner** when he's not the right expert: *"looks ok to me, but I still think @spetrunia should see it too."* *"And let Brandon review the std::initializer_list changes."*
- He'll **ask the original author of a plugin** to review when the fix touches their territory: *"I've asked the original developer of the audit plugin to take a look, in case he'd have a cleaner idea."*

### "In-Testing" handoff

He has a reusable boilerplate for community PRs that get approved:

> *"This is what happens now: MDEV-XXX is moved to the 'In-Testing' status, if everything is fine, a tester will approve it and it'll be pushed into main in time for the X.Y.Z release which is planned for the beginning of <month>. There is nothing you need to do anymore, unless testing finds bugs."*

### Disagreement / takeovers

- **Pushes back on LLM-generated arguments** explicitly. *"I can ask an LLM myself, no need to do it for me, though."* (PR #4589)
- **Re-bases the PR himself** when he wants to unblock it: *"I've rebased on the latest 10.11, performance schema and feedback plugin are now fixed, please remove all related workarounds from your PR."*
- **Offers to take over** when a contributor stalls near a release deadline, polite framing: *"This issue is marked in MDEV-38550 as a Blocker. … we won't be able to wait for you forever, when a deadline comes we'll have to take over."*
- **Self-reverts** are normal. *"Revert the fix for MDEV-35622 (957ec8bba6c)."* He's comfortable acknowledging his own incomplete prior work.

### "why?" — the signature comment

He frequently writes a single **"why?"** as a line comment. It means: *"I see no apparent justification — explain or remove."* Three escalations:

- **"why?"** — first ask.
- **"why??"** — repeated unjustified test/code change.
- **"why???"** — same again, more emphatic.

Single-word "why?" on a test line is one of the most common shapes in his review corpus.

### Other terse interrogatives

- **"Don't mention MDEV in the comment."**
- **"so, here it's an empty db, and below it's any_db. Shouldn't there be a consistent way to distinguish …"** — pushing for a single representation rather than two equivalent encodings.
- **"is it even possible here?"** — defensive-programming pushback, per `!`-clause.

---

## Domain-specific opinions

### Vector / HNSW (his code)

- **HL-indexes are server-level, not engine-level.** Size checks, validity, etc. above the engine layer.
- **Dot product is not a distance** without benchmarks on real data. *Ann-benchmarks-style* insert-speed-vs-recall 2D chart is the bar.
- **New distance functions** must come with an index test using vectors where the new distance gives a *different ordering* than existing distances.
- **Vector code lives in `sql/vector_mhnsw.cc`**, runtime stats in `MHNSW_Share` protected by `cache_lock`.
- **File-scope `static constexpr`** for tunables, e.g. `subdist_part`, `subdist_margin`. Comments explain "X and Y are best by test" and which datasets break alternatives.
- **Approximate-then-refine optimisations**: `distance_greater_than(Y, Z)` that estimates with the first ~192 dims times a margin (1.05f), falling back when needed.
- **`MHNSW_param` struct** for the common-args bundle.

### Replication / XA / 2PC

- **Any binlog write goes through `tc->prepare()`** — commit or rollback.
- **Don't relax XA asserts** to allow unilateral rollback. Use `xid_state.set_rollback_only()` instead.
- **A "rollback" with a non-transactional engine** is committed in that engine; binlog still needs to commit it.

### ACL / privileges / packet parsing

- **`mysql.global_priv` is the source of truth.** Avoid `mysql.user`-based checks.
- **MariaDB's read function zero-terminates the packet** — `strlen` is safe; don't add `strnlen`.
- **Combine `CLIENT_SECURE_CONNECTION` branches** with a single `ER_UNKNOWN_COM_ERROR` covering both.
- **"Rediscover privileges" call sites** get an explicit pre-check (`acl_get_all3(...) & need`) rather than patching `check_grant()`.
- **`BACKUP SERVER`** requires global `SELECT_ACL`.
- **Add `pk_parts` to `Grant_table_base` subclasses** — privilege tables are validated by PK key-part count, not by structure alone.

### Parser / Item

- **Cheap pre-checks at parser level** rather than letting the parser build a deep AST that will be rejected.
- **Pluggable-type checks belong in the parser rule** (`field_type_all_with_typedefs`).
- **`MYSQL_YYABORT;`** after `my_error(...)` in yacc; not `thd->parse_error()`.
- **Move privilege checks out of `fix_fields()`** into `check_sequence_privileges()` / `check_access()` when `fix_fields` can't handle all contexts.
- **`ErrConvDouble`** for double values in error messages.
- **Walk-the-tree visitors are expensive** — try `fix_fields` time first.
- **Lexer kill check** in `lex_one_token` for very long queries (`if (thd->killed) { ... return END_OF_INPUT; }`).

### InnoDB

- **`ha_innobase::external_lock()` is where engine-specific isolation work belongs.**
- **Multi-update / multi-delete**: read-only tables in the join don't need S-locks.

### Charset

- **JSON-escape can take any charset** — it does the conversion internally.
- **Vector-parsing output is `my_charset_bin`**, not the source JSON's charset.
- **Don't transcode** to utf8mb4 just to pass to a function that handles any charset.

### CONNECT engine

- **Bugs are fixed in-engine** without touching server core.
- **No trailing `\n`** in `snprintf(g->Message, ...)` — `my_message_sql` asserts that.
- **`my_message(ER_UNKNOWN_ERROR, g->Message)`** must guard for empty content — fall back to `my_error(ER_GET_ERRNO, ...)`.
- **No `printf`-style format-string indirection** through user-supplied data.

### Plugin / service architecture

- **Plugins consume server primitives via `libservices/` services.**
- **For audit/log code, pass `NULL` as `thd`** to thd-services so global time-zone / locale apply (session settings should not affect the global audit log).
- **`my_global.h` is not for plugins.**

### Packaging / systemd

- **Keep the socket in `RUNDATADIR`** (the original intention) but make `RUNDATADIR=/run/mysql`.
- **For DEB version migrations**: look at historical commits doing `conflicts/replaces` correctly — copy them.
- **`systemctl` reads** `lib/systemd/system/<service>.service.d/*.conf`.
- **Plugin packaged separately** wants a `.cnf` for autoload; **plugin shipped inside the server package** does NOT.
- **`plugin.cmake`'s `CONFIG` keyword** was originally a tokudb special case — used cautiously.

### CMake

- **`MATCHES` is regex.** Use it for OS lists: `MATCHES "fedora|rhel$|centos"`.
- **`INSTALL_RUNDATADIR` is always set** — no need to check.
- **CMake generator expressions** are expanded at *build* step. If a file is created at *configure* step, its name can't use generator expressions.
- **`check_linker_flag` needs CMake ≥ 3.18.**
- **Don't `set_package_properties(... REQUIRED ...)`** when the dep is genuinely optional.

### Other

- **`xxhash.h` has 128-bit hash.** Same width as MD5, same collision risk — preferred over `XXH3_64` when replacing MD5.
- **`__has_feature` belongs in `my_global.h`** (his own observation he hasn't moved on yet).
- **Galera applier string spelling**: `"wsrep applier"`.
- **Don't put a per-file COPYING** in a directory that only contains a `CMakeLists.txt` — the project license covers it.

---

## Catchphrases / verbatim turns of phrase

The most quotable / most-recognisable bits of his review prose. Recognising them helps interpret severity.

- **"why?"** / **"why??"** / **"why???"** — see Process section.
- **"Looks good, please squash, then I'll merge"** — close.
- **"basically ok to push, I'm approving the PR, but please check the following: …"** — approval-with-loose-ends.
- **"Approved either way, but …"** — non-blocking suggestion.
- **"I don't insist, but …"** — soft preference.
- **"please rebase on top of the main branch"** — usually after approval; merging-friendly close.
- **"This is what happens now: MDEV-XXX is moved to the 'In-Testing' status …"** — community-handoff boilerplate.
- **"Don't mention MDEV in the comment."** — code comments document intent, not history.
- **"so, here it's an empty db, and below it's any_db. Shouldn't there be a consistent way to distinguish …"** — pushing for one representation.
- **"it's not an error, as the server continues anyway"** — body line for `error→warning` demotions.
- **"cannot add new warnings in 11.8 anymore"** — stable-branch policy citation.
- **"followup for <12-char-sha>"** — body cross-reference.
- **"first reviewer / second reviewer"** (NOT "preliminary / final") — PR #5007: *"we try to have two reviewers for every PR, for years."*

---

## Singletons worth remembering

PR-specific gems that may apply when the right area comes up.

- **`SET GLOBAL var=default`** in MTR is preferred over `--restart` to reset a sysvar. (PR #4633)
- **`SHOW CREATE SERVER`** privilege requires `FEDERATED ADMIN`. (PR #4743 context)
- **Backward-compatible defaults over "empty = special-case-hardcoded"**: *"don't make it 'empty = hard-coded', it's not very intuitive, simply set the default value of timestamp_format to the correct (backward compatible) value."* (PR #4633)
- **For tests needing a present file** (forcing a downstream failure): create the file from `mysqltest`, not via `max_session_mem_used`. (PR #4659)
- **For per-clause defensive-programming reviews** see PR #4254 as the model — enumerate each `!` clause.
- **For Manhattan/Euclidean parity tests** ensure the vectors place the expected target at *different ranks* under each distance. (PR #4654)
- **`Compress_buffer compress_buf= {buf, buf_end, buf};`** — single-line C99 aggregate init style. (PR #4356)
- **Old-protocol auth** has a `+1` that's real when `CLIENT_SECURE_CONNECTION` isn't set. Verify against `sql_acl.cc:13866` comment. (PR #4509)
- **`set_if_bigger` / `set_if_smaller`** are the in-tree atomic-ish max/min macros. Use them with a `// not atomic, but it's ok` inline comment for loose-but-monotone counters.
- **Hot-path kill check** in `lex_one_token` is legitimate when the lexer is the slow path.
- **System-table columns**: when adding a column, **place it at the end**. *"to simplify downgrades and to avoid breaking applications."* (commit `ca78df24` on `mysql.proc`)
- **Boolean engine attributes** accept `NO|OFF|FALSE|0|YES|ON|TRUE|1`. Use the canonical list, don't write a parser.
- **For Windows command injection**: switch from `system()`-style to `_spawnlp` — solution by API choice rather than escaping logic.
- **For the wsrep test result**: `wsrep applier` is the spelling.

---

## Quick reference: shapes he uses for common situations

| Situation | His shape |
|---|---|
| MDEV bug fix | `MDEV-NNNNN <Jira title verbatim>` — no colon |
| Non-MDEV fix | `cleanup:` / `fix ` / `remove ` / `bump ` / `make ` / `correct ` |
| Test-only follow-up | `fix the test` / `update test results` / `fix sporadic failures on <suite>.<test>` |
| Sanitizer fix subject | the raw sanitizer message |
| Per-branch backport | `MDEV-NNNNN <topic> (10.11 version)` |
| Cherry-pick | `(cherry picked from commit <40-hex>)` trailer |
| Reverted commit | `Revert "<original subject>." (<12-hex>).` |
| Reference to prior commit | `followup for <12-hex>` |
| Multi-MDEV close | `also fixes: MDEV-X, MDEV-Y` |
| External-reporter credit | `Reported by <Person/Org>` / `Discovered by <Person>` (end of body) |
| Branch-cut commit | `12.2 branch` |
| Submodule / vendor bump | `update WolfSSL to 5.8.0-stable` |
| Merge commit | `Merge branch 'X.Y' into Z.A` — empty body |
| Approve-with-squash | "Looks good, please squash into one commit. Then I'll merge it." |
| Approve-with-followup | "basically ok to push, I'm approving the PR, but please check the following: …" |
| Approve-with-second-reviewer | "looks ok to me, but I still think @<name> should see it too" |
| Community handoff | "This is what happens now: MDEV-XXX is moved to the 'In-Testing' status …" |
| Justification-request | "why?" / "why??" / "why???" |

---

## What to use this for, what NOT to use it for

**Use**:
- Drafting a commit message before opening a PR in an area he reviews.
- Naming a `.test` file / placing a regression test where he won't move it.
- Picking an error code when adding a `my_error(...)` call.
- Deciding whether to introduce a helper, a class method, or a parameter.
- Interpreting a `why?` comment without escalating it into a 3-round debate.
- Pre-empting "fix the root cause / don't widen the API / don't introduce engine-specific server branches" feedback.

**Do not use** this as:
- A reason to ignore `.claude/review/*.md` or `CODING_STANDARDS.md` — he expects those followed first.
- A licence to argue from "vuvova would have done X" without evidence. He pushes back on LLM-generated authority claims.
- A specification for `mfix` or any other skill — this is observed-behaviour reference, not a normative rule book.
