# vuvova — commits_03.jsonl findings (98 commits, 2025-05-16 → 2026-05-06)

## Commit message conventions

### Subject: `MDEV-NNNNN <terse description>` — no colon between ticket and description
- Confidence: high.
- The bug-ticket prefix has no colon; whatever follows is usually a copy/paraphrase of the Jira summary line (often beginning with an uppercase word from Jira, occasionally lowercase when paraphrased): `MDEV-38209 REFERENCES permission on particular schema is sometimes ignored` (c0acc3cc), `MDEV-36668 main.mysqld--help-aria test failure when no MAC address` (c26d7b9d), `MDEV-37938 very long query cannot be killed quickly` (e5994025), `MDEV-39319 crash with ST_GeomFromGeoJSON(, NULL)` (c454ba88).
- Exception: 1 commit out of ~70 MDEV-prefixed commits uses a colon — `MDEV-39301: fix main.xa - Timeout in wait_until_count_sessions.inc` (e1ce61f0). Default to no colon.

### Subjects routinely exceed 50 chars; the MDEV-prefix exception is used liberally
- Confidence: high. Multiple subjects ≥ 100 chars: 153 chars max (cb31d753 — full Jira title with backticks). He pastes the Jira title verbatim rather than rewriting for brevity.

### Topic-prefixed non-MDEV subjects use lowercase prefix + colon
- Confidence: high. `cleanup: MHNSW_param` (c2bff9ff), `cleanup: remove make_unique_invisible_field_name()` (cfde5bf2), `cleanup: long unique checks` (d8c2362), `cleanup: remove HTON_CAN_READ_CONNECT_STRING_IN_PARTITION` (e35039e7), `cleanup: disconnect before DROP USER` (e3d93697), `MDEV-35897 cleanup: Stats structure` (ca19a251 — pattern combines with MDEV), `bugfix: cannot access shared MEM_ROOT without a lock` (e05e6abf).
- For non-bugfix housekeeping he uses bare imperative subjects with no prefix: `remove unused arguments` (d1fd168d), `remove unused new modes constants` (cd3df714), `remove questionable vector search optimizations` (ee396549), `bump the VERSION` (f984eece), `bump the maturity of caching_sha2_password and parsec plugins` (e1c2bb86), `fix nullptr-with-nonzero-offset UB` (d198be39), `fix a typo in a test` (dfb711e9), `fix sporadic failures on main.user_var --view` (c12e94a3), `fix rand() values in vector tests` (c7795428), `Add test cases for comment handling in audit plugin` (d7573457).

### Empty bodies are common; bodies, when present, are terse imperatives
- Confidence: high. Roughly a third of non-merge commits have an empty body (e.g., c12e94a3, cd3df714, db2f3d23, d1fd168d, dfb711e9, eff01f4f, edda8d54, f984eece, ea8ffad0, cf7a5a16, e02f4d7e). When a body exists, it's 1–4 short lines stating the *cause* and *fix mechanism*, not a story: `correct the length check. remove assertions that a file read from disk contains a specific substring` (db2606d5), `let's make is difficult for wkb and len to desync` (d0501281), `check for thd->killed in the lexer` (e5994025), `set collation for AVG, like it's done for MAX` (d12a5333), `silence non-errors from admin commands, as it's what --silent is documented to do` (d223be11).

### Cross-reference style: bare 12-char SHA, optional MDEV-N
- Confidence: high. `followup for 649216e70d87` (cb0d6dd8), `followup for 0b3abff65874` (ce3b657a), `followup for 11f228cbb2b3` (d08fd634), `followup for 05f901893382` (e28b55bb), `fix as in 2925d0f2ee98` (d1d48c91), `Revert "MDEV-17256 Decimal field multiplication bug." (57898316b6fb)` (da20c175), `Backport from 11.8 aa2ac3078fa99c7cf712c29023c48ffe68677e10` (e1ce61f0). No "see commit", no parentheses around SHA except in Revert.

### Cross-MDEV references are flat lists, not prose
- Confidence: medium. When one fix resolves multiple tickets, he lists them with `also fixes:` (e1f15d50 lists 5 MDEV-IDs in a bullet block).

### Credits authors as one-liners at the bottom of the body
- Confidence: medium. `Discovered by: Aakash Adhikari` (d1d48c91), `Discovered by Riley Scott Jacob` (f81c247f), `Reported by Aisle Research` (f2795510). No `Signed-off-by:` style; no `Co-Authored-By:`.

### Bullet-style bodies use `* ` markers (not `- `)
- Confidence: high. `c27d78be`, `caa04d038`, `e1f15d50`, `ef3c843c`, `e7a55399`. Hyphen bullets are absent.

---

## Code style (as he writes it)

### Hoists short-scope variables into the condition expression
- Confidence: high.
  - `if (int err= node->load(p->graph)) return err;` (c2bff9ff, vector_mhnsw.cc) — replaces a separate declaration.
  - `if (const char *p = strstr(src, "%s"))` (d1d48c91, jdbconn.cpp).
  - `if (auto blob_storage= (String*)alloca(...))` (d8c23629).
- Combined with the "declare at top of scope" coding standard, this is the one place he routinely declares inside an `if`-init.

### `auto` is used selectively — only for spelled-out types he doesn't want to repeat
- Confidence: medium. `auto length= thd->variables.path.text_format_nbytes_needed();` (d1fd168d), `auto blob_storage= (String*)alloca(...)` (d8c23629). Plain types are written out otherwise — no `auto x= 0;`.

### `static_cast` for explicit narrowing; C-style cast for trivially safe pointer/enum casts
- Confidence: medium.
  - `static_cast<const FVectorNode*>(elem)` (c2bff9ff).
  - `static_cast<Item_field *>(arguments[j])->field` (d8c23629 deleted code).
  - `static_cast<ulong>(MAX_FIELD_VARCHARLENGTH / sizeof(float))` (eff01f4f).
  - C-style still used for legacy alloc patterns: `(TABLE_SHARE*)alloc_root(...)` (e05e6abf), `(char*)alloc_root(...)` (e05e6abf), `(Field*) thd->alloc(...)` (cf842c8c).

### Mixes `0`, `NULL`, `nullptr`, `FALSE`, and `TRUE` depending on context
- Confidence: high.
  - Returns `NULL` from existing `String*`-returning functions (c454ba88, f81c247f).
  - Uses `nullptr` in newer string code (ff12ec86 client/mysqldump.c keeps existing convention, but new code in sql/ uses `nullptr`).
  - `DBUG_RETURN(TRUE)` / `DBUG_RETURN(FALSE)` in legacy server code (c27d78be, e054d8b8).
  - `return 0` and `return 1` for `bool`-returning helpers he writes himself: `bool TABLE::check_sequence_privileges(THD *thd) { ... return 0; }` (c27d78be).
- Take-away: he doesn't introduce style migrations; match the surrounding file.

### Uses the project's small-ish typedefs (`uchar`, `uint32`, `uint`) rather than `<cstdint>`
- Confidence: high. New helpers: `uint key_parts= fields_in_hash_keyinfo(keyinfo)` (d8c23629), `static const char *bools=...` (cfe822c6), `const uint max_neighbors=` (c2bff9ff). `int16_t`, `uint8_t` etc. appear only when they're already used by the surrounding code.

### Function ordering: two blank lines between out-of-line definitions
- Confidence: high. Visible in cfde5bf2 (sql_table.cc) where his inserts respect two-blank-line separators, and in d8c23629 where a new `long_unique_fields_differ()` is inserted with two blank lines around it.

### Helpers preceded by a 1–3-line `/* ... */` purpose comment
- Confidence: high.
  - `/* common set of params for many search/select functions */` above `struct MHNSW_param` (c2bff9ff).
  - `/* one visited node during the search. caches the distance to target */` (c2bff9ff).
  - `/* For SPATIAL, FULLTEXT and HASH indexes (anything other than B-tree), ignore the ASC/DESC attribute of columns. */` (e925ddd2).
  - `/* graph related statistical data. stored in MHNSW_Share. copied from ctx to a local structure under a lock. */` (ca19a251).
- He explains *why*, not *what*. Comments above the function are common; inline comments rarer.

### Inline comments tag lossy/lossless or "this is intentional" code paths
- Confidence: medium.
  - `if (b1[frac1] == 0)      /* lossless */ frac1--;` … `else if (frac1 > frac2)    /* lossy, MUST be after lossless */` (f0bcd199, decimal_mul).
  - `set_if_bigger(p->ctx->diameter, max_distance); // not atomic, but it's ok` (c2bff9ff).
  - `/* Don't check privileges, if it's parse_vcol_defs() */` (c27d78be).

### Assertions: `DBUG_ASSERT` everywhere in sql/; documents calling conventions
- Confidence: high.
  - `DBUG_ASSERT(hash_field->invisible == INVISIBLE_FULL);` (cda18262, "add an assert" is the whole fix).
  - `DBUG_ASSERT(off);` (d8c23629).
  - `DBUG_ASSERT(thd->utime_after_query >= thd->utime_after_lock);` plus brace-scope around the call (cb31d753).
  - `DBUG_ASSERT(!mandatory || plugin_maturity_map[plugin->maturity] >= SERVER_MATURITY_LEVEL);` (c604028d) — sole code change in the commit.
  - `DBUG_ASSERT(null_ptr < ptr); DBUG_ASSERT(ptr - null_ptr <= (int)table->s->rec_buff_length);` (fe8047ca) — adds an invariant to guard against future misuse.
- Body of MDEV-18386 (d78cf265) is literally `add an assert to document calling conventions`. He treats asserts as **documentation**.

### He *removes* asserts when they no longer hold for read-from-disk paths
- Confidence: medium.
  - In MDEV-37920 (db2606d5): `remove assertions that a file read from disk contains a specific substring`; deletes `DBUG_ASSERT(share->tabledef_version.length == MICROSECOND_TIMESTAMP_BUFFER_SIZE-1);` and `DBUG_ASSERT(share->tabledef_version.length);`. Rule: never assert on user-supplied / on-disk data.

### Prefers reformulating conditions over adding nesting
- Confidence: medium.
  - Flips inequalities to read positively: `if (len < (size_t)(end-ptr) && ptr[len] != '=')` → `if (len >= (size_t)(end-ptr) || ptr[len] != '=')` (db2606d5).
  - Combines two byte tests: `(*packet == 1 || *packet == 255 || *packet == 254)` → `(*packet < 2 || *packet > 253)` (db2f3d23).
  - Rewrites ternary to incorporate a length-0 guard inline rather than nest: `qb_name.length > 0 || this->get_name().length == 0 ? hint_table_and_qb->qb_name : this->get_name();` (ddd3a612 — fix for nullptr-offset UB).

### Introduces local macros for repeated 2-line idioms, even in C++ code
- Confidence: low (1 commit, but it's notable).
  - `#define advance(wkb,len,N)      do { wkb+=(N); len-=(N); } while(0)` in spatial.cc (d0501281) replaces every `wkb+= X; len-= X;` pair to make pointer/length always advance together — a structural anti-desync technique.

### Casts for safe pointer arithmetic / size args use `(int)` or `(uint)` not constructor-style
- Confidence: medium. `(int) (p - src)` (d1d48c91), `(uint) (wkb - wkb_orig)` (d0501281), `(uint32)strlen(...)` (ff12ec86). Constructor-style casts are absent.

### When introducing struct/class members, initializer in the declaration is the default
- Confidence: medium. `Stats { double ef_power= 0.6; float diameter= 0; size_t graph_size= 0; };` (ca19a251). `struct MHNSW_param { ...; MHNSW_param(MHNSW_Share *ctx, TABLE *graph, int layer) : ctx(ctx), graph(graph), layer(layer) { } };` (c2bff9ff) — uses member-init list, default-init members where possible.

---

## Refactoring / cleanup habits

### "cleanup: <thing>" commits make one focused mechanical change and stop
- Confidence: high.
  - `cleanup: MHNSW_param` (c2bff9ff): pure parameter-bundle introduction; no semantic change. Body: `put common arguments of many functions into one "param" structure, instead of passing them every time independently`.
  - `cleanup: remove HTON_CAN_READ_CONNECT_STRING_IN_PARTITION` (e35039e7): removes a flag set only by Spider but unused; body explicitly says `no behavior changes.`.
  - `cleanup: remove make_unique_invisible_field_name()` (cfde5bf2): removes a function that `duplicates make_internal_field_name() and only used in DBUG_EXECUTE_IF`; wraps the now-DBUG-only caller in `#ifndef DBUG_OFF`.

### Mixes a small bug fix into cleanup only when documented in the body
- Confidence: medium. `cleanup: long unique checks` (d8c2362): body says `consolidate and unify long unique checks. fix a bug where an update of a long unique blob was ignoring the prefix length`. He always **states it** when a cleanup includes a behaviour change.

### `cleanup: disconnect before DROP USER` — sweep style: same micro-change across 40+ test files
- Confidence: high. e3d93697 modifies 50+ test files identically, body explains policy: `MariaDB is traditionally very tolerant to active connections of the dropped user, which isn't the case for most other databases. Let's avoid unintentionally spreading incompatible behavior and disconnect before drop.`. He has no problem with very wide cleanup commits as long as they're mechanical.

### Removes dead/legacy constants when they age out
- Confidence: high. `remove unused new modes constants` (cd3df714) removes 4 `NEW_MODE_*` macros set to `NOW_DEFAULT`. `Un-deprecate keep_files_on_create` (f500849, sys_vars.cc): removes the `DEPRECATED("")` annotation when full removal can't happen — leaves an explanatory body about the dependency on MDEV-38866.

### When a previous optimization stops paying off, he removes it with empirical justification
- Confidence: low. `remove questionable vector search optimizations` (ee396549). Body: `new round of benchmarks didn't reveal any benefits from them, quite the opposite. these were old optimizations added in the early phase of vector search development. apparently later changes made them obsolete.`. The variable rename `alpha` → `leniency` happens in the same commit (semantic clarification rides along).

### Adds engine-side knobs (TOPTION) instead of plumbing through the server
- Confidence: medium. `MDEV-37815 connect_string in partitioning is broken` (e054d8b8): removes server-side `copying of part_elem->connect_string to table->s->connect_string`. Engines that want CONNECTION now declare `TOPTION("CONNECTION")`. Rule: keep storage-engine-specific syntax inside the engine, not at the server boundary.

---

## Bug-fix approach

### Bug fix + targeted regression test, same commit, in the canonical suite
- Confidence: high.
  - MDEV-36852: `long_unique_bugs.result` + the SQL test alongside the table.cc/sql_table.cc fix (cda18262).
  - MDEV-39404: ships a binlog binary fixture `std_data/mdev-39404-binlog.000001` next to the log_event.cc fix (d56b6b6e).
  - MDEV-36870: 100+ lines in `suite/sql_sequence/grant.test` next to the privilege-handling fix (c27d78be).
- Even bodies sometimes literally say `add a test case` (de68699e is a 1-line body).

### "fix the test" / "fix test for --view" / "update test results" pattern for test-only followups
- Confidence: high. He uses these *exact* phrases for followup commits (4 instances in this chunk: ce3b657a, d08fd634, dce20116, e28b55bb). The body is typically `followup for <12-char-sha>` and the diff touches only `.test`/`.result` files. Use this exact wording for test-only stabilization that follows a parent fix.

### Sanitizer-found bugs go in WKB / spatial / strings / parser; one-time precondition checks
- Confidence: high.
  - `MDEV-39279 ASAN error on malformed WKB`: every `num_points`/`num_geometries` now `if (no_data(m_data, 4)) return 1;` before reading 4 bytes (f81c247f).
  - `MDEV-39481 ASAN error on malformed WKB polygon`: replaces every `wkb + N, len - N` argument pair with the `advance(wkb,len,N)` macro to make desync impossible (d0501281). Body: `let's make is difficult for wkb and len to desync`.
  - `MDEV-37920 Out-of-Bounds in File_parser::parse()`: flips the broken length check; doesn't add new bounds infrastructure (db2606d5).
  - `MDEV-37055 UBSAN: 32801 is outside the range of representable values of type 'short'`: 2-line fix in vector code (`std::nextafter`), no broader audit (d0c6889).
  - `fix nullptr-with-nonzero-offset UB` (d198be39, ddd3a612): 1-line conditions added at the callsite — never a wide refactor.
- Pattern: fix the symptom narrowly; only refactor when the bug class repeats (the `advance()` macro is the exception, not the rule).

### "discovered/reported by external security researchers" → tighter checks plus a public test
- Confidence: medium.
  - MDEV-39279 (f81c247f) — "Discovered by Riley Scott Jacob".
  - MDEV-39288 (f2795510) — "Reported by Aisle Research"; the fix is a 1-character change `SHOW_PROC_WITHOUT_DEFINITION_ACLS` → `acl`.
  - MDEV-38892 (d1d48c91) — "Discovered by: Aakash Adhikari"; he ports the same pattern from a sibling fix `2925d0f2ee98`.

### Replication / log-event safety: validate-and-bail style
- Confidence: medium. MDEV-39404 (d56b6b6e): `if (event_len < ... || xid.gtrid_length > MAXGTRIDSIZE || xid.bqual_length > MAXBQUALSIZE) { xid.formatID= -1; seq_no= 0; return; }`. Sets sentinel values rather than throwing, because the constructor signature can't fail.

### "ASAN error", "ASAN errors in X", "UBSAN: <message>" — verbatim sanitizer output is the subject
- Confidence: high. Three of four sanitizer commits paste the literal output: e.g. `ctype-ascii.h:110:27: runtime error: applying non-zero offset 4 to null pointer` (ddd3a612 subject); body: `when this->get_name() is {0,0}`.

### Fix the symptom *upstream* when the call site is "rediscover privileges"
- Confidence: medium.
  - MDEV-38209: instead of patching `check_grant()`, he wraps it with an early `acl_get_all3(...) & need` check at every call site that previously over-trusted SELECT-on-global (c0acc3cc).
  - MDEV-39493: same shape — extract the global `FILE_ACL` check *before* per-table loops (c0fb8448).
- Rule: keep `check_grant` semantics; gate it explicitly at each caller.

### For "X happens in fix_fields()" — move the check to an explicit `check_access()` method
- Confidence: medium. MDEV-36870 (c27d78be): renames `Item_func_nextval::check_access_and_fix_fields()` → `Item_func_nextval::check_access()`, adds `virtual bool check_sequence_privileges(void *arg)` on `Item`, `Virtual_column_info::check_access()`, and `TABLE::check_sequence_privileges()`. Body explicitly says `Don't check NEXTVAL privileges in fix_fields() anymore, it cannot possibly handle all the cases correctly`. He prefers to add a new virtual method and call it explicitly from each operation, rather than overloading `fix_fields`.

### Sometimes the fix is a revert, with the precondition for re-fixing called out
- Confidence: low. MDEV-30255 (da20c175): reverts a months-old MDEV-17256 fix wholesale; body explicitly: `Revert ... It removes zero truncation from decimal_mul() and fixes reported symptoms. But reintroduces multiplication bug.`. Two days later, MDEV-17256 is re-fixed by truncating long factors *before* multiplication (f0bcd199). Reverting upstream and re-doing the fix is acceptable.

### Disables a feature rather than ship a half-fix when corner-case repro blocks a release
- Confidence: low. MDEV-37310 (fb2f324f): replaces a 30-line PK-detection workaround with `disallow UPDATE IGNORE in READ COMMITTED with the table has UNIQUE constraint that is USING HASH or is WITHOUT OVERLAPS`. Body: `This rarely-used combination should not block a release, with be fixed in MDEV-37233`.

---

## Architecture / API choices

### Bundle 3+ co-travelling arguments into a "param" struct passed by pointer
- Confidence: high. The `MHNSW_param` introduction (c2bff9ff) is the prototype: every `select_neighbors(MHNSW_Share*, TABLE*, size_t layer, ...)` becomes `select_neighbors(MHNSW_param*, ...)`. He'll happily change 5–10 call sites in a single cleanup.

### Add a virtual on `Item` only when the new check cuts across the whole tree
- Confidence: medium. `virtual bool check_sequence_privileges(void *arg) { return 0; }` on `Item` (c27d78be) — `void*` for arg because Item processors thread state through a generic void pointer. He overrides it specifically on `Item_func_nextval`, `Item_func_lastval`, `Item_func_setval`. He doesn't add typed signatures to `Item`'s base just for cleanliness.

### Add a `check_*()` method on `TABLE` / `Virtual_column_info` to walk substructures
- Confidence: medium. `TABLE::check_sequence_privileges()` (table.cc, c27d78be) iterates `field[]` and calls `vcol->check_access()`, which walks the item tree. Same shape used for `Sql_path::print()` simplification (d1fd168d) — methods that take no state-dependent arg.

### Adds `~Class() = default;` virtual destructor + new bool return when a base method gains an error path
- Confidence: low. `Grant_table_base::set_table` returns `bool` (e1f15d50) instead of `void`; `virtual ~Grant_table_base() = default;` is added in the same commit because subclasses are now polymorphically destroyable through error paths. He doesn't bother with `override` annotations on the destructors.

### Prefers `std::max` / `std::min` over `MY_MAX` / `MY_MIN` in new code
- Confidence: medium. c2bff9ff, ca19a251, ee396549 all use `std::max`. Doesn't migrate existing `MY_MAX` calls.

### Prefers `set_if_bigger` / `set_if_smaller` (mysys macros) for *atomic-ish* updates with a comment
- Confidence: medium. `set_if_bigger(p->ctx->diameter, max_distance); // not atomic, but it's ok` (c2bff9ff). When concurrency is loose-but-monotone he documents it inline.

### `alloca` is fine for transient buffers in handler hotpaths
- Confidence: medium. `auto blob_storage= (String*)alloca(sizeof(String)*table->s->virtual_not_stored_blob_fields);` (d8c23629). `auto discarded= (Visited**)my_safe_alloca(...)` with matching `my_safe_afree` (c2bff9ff).

### Adds compile-time sentinel/init for a new column at the END of system tables
- Confidence: medium. `add new column mysql.proc.path at the end of the table` (ca78df24). Body: `to simplify downgrades and to avoid breaking applications`. The whole commit moves the new column to the last position in `proc_table_fields` / `MYSQL_PROC_FIELD_*` enum. Rule: don't insert system-table columns in the middle.

### "branch" commits bump VERSION + debian + sysvars_star.result; nothing else
- Confidence: high. `12.2 branch` (e02f4d7e), `13.0 branch` (ea8ffad0), `bump the VERSION` (f984eece) — touch only `VERSION`, `debian/`, `sysvars_star.result`, occasionally `client/mysqlbinlog.cc` for a version-string include. Empty bodies.

### Plugin maturity bumps are one-liners — file each as its own commit
- Confidence: medium. `bump the maturity of caching_sha2_password and parsec plugins` (e1c2bb86) flips `MariaDB_PLUGIN_MATURITY_GAMMA` → `_STABLE` in two plugin declarations. Empty body, no test.

---

## Domain quirks (JSON, parser, ACL, spatial, vector)

### Spatial (`sql/spatial.cc`): every length-bearing arithmetic gets an `advance()` macro / `no_data()` guard
- Confidence: high. d0501281 (MDEV-39481): macro for `wkb`/`len` pairs. f81c247f (MDEV-39279): `if (no_data(m_data, 4)) return 1;` before every `uint4korr(m_data)` access in `num_points` / `num_geometries`. c454ba88 (MDEV-39319): don't pre-check `args[i]->null_value` for geo-from-text/wkb/json before evaluating the arg — `one cannot check item->null_value before evaluating item's value`.

### Vector (`sql/vector_mhnsw.cc`): heavy ongoing refactor; runtime stats live in `MHNSW_Share`, protected by `cache_lock`
- Confidence: high. c2bff9ff (MHNSW_param), ca19a251 (Stats struct), c779542 (rand stabilization in tests), ee396549 (alpha → leniency, removed micro-opts), eff01f4f (max length error), d0c6889 (float-precision overflow), c0acc3c uses `Atomic_relaxed` *before* the lock refactor; new code uses an explicit mutex + read/set/add accessors.

### Parser (`sql_yacc.yy`): non-reserved-keyword groupings are surgical
- Confidence: medium. `reserve PATH_SYM in the same way as NAMES_SYM` (df23b05a): moves `PATH_SYM` out of `ident_cli_func`/`keyword_ident`/`keyword_sysvar_name`/`non_reserved_keyword_udt`/`keyword_sp_decl` and adds it to `keyword_set_special_case`. Don't drop into Bison files without understanding which keyword classes a token has to belong to.

### Lexer kill check
- Confidence: low. `MDEV-37938`: `check for thd->killed in the lexer` (e5994025). Adds `if (thd->killed) { thd->send_kill_message(); return END_OF_INPUT; }` at the top of `lex_one_token`. He'll put a kill check in *very* hot paths when latency matters.

### ACL (`sql_acl.cc`): "rediscover privileges" callers get an explicit pre-check
- Confidence: high. c0acc3cc (MDEV-38209): wraps `check_grant(thd, SELECT_ACL, tables, 0, 1, 1)` with `if (!(acl_get_all3(thd->security_ctx, db_name->str, 0) & need))`. c0fb8448 (MDEV-39493): hoist the global `FILE_ACL` check out of `check_table_access`'s privilege parameter into a pre-check.

### ACL grant-table classes get a `pk_parts` member to validate the loaded `mysql.*` schema
- Confidence: medium. e1f15d50 adds `uint pk_parts;` to `Grant_table_base`, sets it per-class (`User_table_tabular() { ... pk_parts= 2; }`, `Db_table() { ... pk_parts= 3; }`, etc.). `set_table()` returns `bool` and emits `ER_CANNOT_LOAD_FROM_TABLE_V2` if the PK key-part count doesn't match. Defensive parsing pattern — the privilege tables aren't trusted by structure alone.

### CONNECT engine (`storage/connect/`): tightening of `snprintf` and trailing `\n`
- Confidence: medium. e81458b6 (MDEV-38827): removes trailing `\n` from every `snprintf(g->Message, ..., "...\n", ...)` because `my_message_sql` asserts the absence of trailing newline. d1d48c91 (MDEV-38892): replaces `snprintf(sqry, sqry_real_allocated_size, src, "1=1")` with explicit `snprintf(sqry, sqry_size, "%.*s1=1%s", (int)(p - src), src, p + 2)` — kills format-string injection through `src`. Pattern: avoid `printf`-style format-string indirection.

### Server should escape OK-packet bytes too
- Confidence: low. db2f3d23: pluggable auth changes `(*packet == 1 || *packet == 255 || *packet == 254)` to `(*packet < 2 || *packet > 253)` so byte `0` (OK packet) is also escaped. Comments are updated to match.

### Audit plugin (server_audit): `cn->sync_statement` must be initialized in `setup_connection_connect`
- Confidence: low. ef3c843c (MDEV-34680 post-fixes): `cn->sync_statement= 0;`. He'll add a single struct-field initializer when a previous commit forgot one.

### Stored routines / `proc` system table: column order is hardcoded; new columns go last
- Confidence: medium. ca78df24 moves `path` to the *end* of `proc_table_fields`. Don't insert in the middle even if it reads better.

### Boolean engine attributes accept any of `NO|OFF|FALSE|0` / `YES|ON|TRUE|1`
- Confidence: low. cfe822c6: `static const char *bools="NO,OFF,FALSE,0,YES,ON,TRUE,1";` plus a generic auto-alias loop. Add to this list, don't introduce a separate parser.

---

## Maintenance branch handling

### Merge commits have empty bodies; no resolution notes
- Confidence: high. 6 merges in this chunk (c1fcedf4, c21d462e, c4ed889b, d653fcb5, f230c0ff, f6680d65); all `Merge branch '...' into ...` subjects, empty bodies. He resolves conflicts but doesn't narrate them in the commit.

### Forward-merges follow the supported chain `10.6 → 10.11 → 11.4 → 11.8 → 12.x`
- Confidence: high. The 6 merges cover: `10.11 → 11.4` (twice), `11.4 → 11.8`, `bb-11.4-serg → bb-11.8-serg`, `11.8.5 → 11.8`, `11.8 → 12.2`. No "merge main into 10.11", no cross-version cherry-picks.

### "branch" commits mark version bumps at branch creation
- Confidence: medium. `12.2 branch` (e02f4d7e), `13.0 branch` (ea8ffad0). Touch only VERSION + debian + a sysvar result file. Empty body.

### Backport commits state the source SHA explicitly
- Confidence: low. e1ce61f0 (`MDEV-39301: fix main.xa - Timeout in wait_until_count_sessions.inc`): body is `Backport from 11.8 aa2ac3078fa99c7cf712c29023c48ffe68677e10`. Bug-fix backports cite the originating commit, not just the ticket.

---

## Singletons worth noting

- `Update ColumnStore 23.10.5-1` (ca91bf5d): single-line submodule bump.
- `compiler warning: unused variable` (f83d196a): zero-body single-warning fix; no MDEV ID.
- `update engines/funcs.rpl_stm_reset_slave` (dfe4f82e): body explains semantic change `in 12.0 temp table replication was changed, mixed behaves as row in this test, not as statement`. When updating a third-party-style test, document *why* the result changed.
- `mariadb-backup: read --tables-file in the text mode on Windows` (f49a5beb): 1-character fix `"r"` → `"rt"` in `xb_load_list_file`. Empty body; the subject *is* the documentation.
- `mandatory plugins cannot be less mature than the server` (c604028d): the entire commit body is empty and the diff is a single `DBUG_ASSERT`. When the invariant is the documentation, no body is needed.
- `MDEV-37328 Assertion failure ... upon CONVERT PARTITION` (cbcb080a): converts `if (!flag) create_info->null_bits++; data_offset= (create_info->null_bits + 7) / 8;` into a stateless `data_offset= (create_info->null_bits + need_deleted_bit + 7) / 8;`. Style: eliminate per-call state mutation when the same input is processed multiple times.
- `fix sporadic failures on main.user_var --view` (c12e94a3): subject pattern `fix sporadic failures on <suite>.<test> [--<combination>]` is reused across test-stability commits.
- `MDEV-37375 engines/iuds suite fails with ps-protocol` (ed81e5f4): body `and collateral cleanup` is the only mention of test-result line-ending changes spanning thousands of lines. Acceptable to bundle whitespace-cleanup with a real fix if disclosed in the body.
- `MDEV-37938 very long query cannot be killed quickly` (e5994025): puts the kill-check inside the lexer's `lex_one_token`. Hot-path kill checks are legitimate when the lexer itself is the slow path.
- `MDEV-37888 unexpected type changing after changing AVG to MAX` (d12a5333): 1-line fix `collation= DTCollation_numeric();` in `Item_sum_num::fix_fields`. Body: `set collation for AVG, like it's done for MAX`. When a related Item subclass already does the right thing, the fix is to add the same line.
- `Add test cases for comment handling in audit plugin` (d75734570): subject begins with `Add test cases for` (no MDEV) — used when adding regression coverage for an already-merged fix and crediting the prior fix's SHA in the body.
