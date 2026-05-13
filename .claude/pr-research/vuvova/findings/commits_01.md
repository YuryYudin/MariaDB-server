# Sergei Golubchik (vuvova) — patterns from commits_01.jsonl

81 commits, 2025-04-27 to 2026-05-04. 7 are merges (12.0->12.1, 10.6, 10.11, 11.4->11.8, 11.8->12.1, 12.2->12.3, 12.3->13.0); the rest are authored work spanning sql/, mysys/, storage/{spider,rocksdb,sphinx,connect}, extra/mariabackup, plugin/, client/, parser, build.

## Commit message conventions

### No colon after MDEV-NNNNN, no separator word
- Subject form is `MDEV-NNNNN <description copied from Jira>`. There is **no colon, no dash, no "fix:" tag** between the ticket and the description.
- Evidence (high, ~44 commits):
  - `46135c625bcd` "MDEV-36979 Same alias name with different case on same table is not working in functions"
  - `6f671c5174bb` "MDEV-39111 The query returns an incorrect value when using LPAD and REPLACE"
  - `71d4cae8668d` "MDEV-37503 UBSAN: downcast Item_func_plus to Item_field invalid in sql_prepare.cc:1516"
  - `7b9d3a4df6c9` "MDEV-38654 Assertion `str[strlen(str)-1] != '\n'' failed upon federated discovery error"
- The 50-char limit is ignored when copying the Jira summary; backticks and assertion text are kept verbatim.

### Non-MDEV subjects use one of a small set of lowercase prefix verbs
- `cleanup:` — pure-refactor commit (`4602761a9db0`, `473a6cea79de`, `4f9a13e9ecf2`, `5b0818ee637c` ("cleanup" alone is also used), `74baec1b8a92`, `75b000372b6d`, `75b2aadb9e92`, `78e474b1a720`).
- `fix ` — test or minor follow-up (`44c2dffe25ec` "fix parts.key_compare_result_on_equal --cursor", `5008e33eace8` "fix sporadic failures of rpl.rpl_drop_temp test", `5e7c391dcbfd`, `6c835b163415`, `53504fa4bf39`).
- `remove ` — deletion of an identifier (`6e086ce2a3a8` "remove Sql_path_stack and Sql_path_push", `7772bf07d8c8` "remove LEX::make_sp_name_sql_path()").
- `bump ` — version/maturity (`524399f8289d` "bump the VERSION", `54ad2216578b` "bump uuid_v4 and uuid_v7 plugin maturity to stable", `6bc959432cea`).
- `make ` — test reliability tweak (`564d9e0d6ed6` "make the test clearer", `7888b6c0d55d` "make max_session_mem_used tests more reliable").
- `correct ` — semantic correction not tied to a ticket (`4d0395a6ffe0` "correct sql_command_flags: add CF_CHANGES_DATA as needed").
- `allocate ` / `suppress ` / `clarify ` — verbs used directly when they describe the action.
- Confidence: high.

### `followup for <sha12>` references
- When a commit fixes something a previous commit broke, the body contains the literal phrase `followup for <12-hex>` on its own line. The SHA is 12 chars, no link.
- Evidence (medium):
  - `4a5b8133449d` body: `cannot return ok earlier if the transaction is bf-aborted\n\nfollowup for 0513a4a974db`
  - `53504fa4bf39` body ends `followup for f33367f2ab19`.
  - `5622f3f5e8ce` body: `followup for 9703c90712f3 (MDEV-37199 UNIQUE KEY USING HASH ...)`.
  - `6c835b163415` body: `followup for 649216e70d87`.
- The parenthetical `(MDEV-NNNNN summary)` after the SHA is added when the prior commit was the original feature work.

### Body is terse, imperative, and explains the cause not the fix
- ~22 short bodies, ~29 medium bodies, ~5 long; 18 commits have no body at all (one-liners like `44c2dffe25ec`, `bump the VERSION`, `clarify the test...`).
- When there is a body, the first sentence explains the underlying cause:
  - `46135c625bcd`: `table keys {db,table,alias} must be compared with table_alias_charset` (one line).
  - `6f671c5174bb`: explains `REPLACE() tries to modify its first argument in-place...` before the patch is described.
  - `4ca9fca4f6ce` body uses an asterisk-bullet list with code-diff snippets in the prose — rare but he does it.
- He often uses lower-case sentences without final periods and references identifiers in backticks only when copy-pasting from an assertion or error.

### Short hint-style first lines for test/build-only changes
- `bump the VERSION`, `12.1 branch`, `make the test clearer`, `suppress 'InnoDB: native AIO failed' under rr`, `clarify the test for triggers with different paths`, `fix rpm upgrade tests after MDEV-37726` — these intentionally have no MDEV ticket and read like notes-to-self.

## Code style (as he writes it)

The standard MariaDB style from CODING_STANDARDS.md applies. Beyond that:

### `if (unlikely(...))` is dropped from new code, even on the error path
- He frequently removes `unlikely` wrappers when restructuring an `if` chain because they obscure the diff.
- Evidence (medium):
  - `7772bf07d8c8` rewrites `if (unlikely(check_name_with_error(...)) || unlikely(!(db= ...).str) || unlikely(!(res= new ...)))` into a 3-statement form **without** `unlikely`.
  - `5b0818ee637c` removes several `unlikely(...)`-wrapped guards from `Sp_handler::db_load_routine` (`if (!my_hash_search...)` rewrite).
  - `65bdb573e6b6` parser fix uses `if (Lex->current_select->table_list.elements > MAX_TABLES)` — no `unlikely`.
- He keeps `unlikely` only when the original code had it AND the line is otherwise unchanged.

### Move-construct / `std::move`, never copy big structs
- Evidence (medium):
  - `6e086ce2a3a8`: `m_path(std::move(thd->variables.path))`, `thd->variables.path.set(std::move(m_path))`.
  - `69f401bdb63e` makes `Sql_path` move-aware; copy-assign delegates to `set(rhs)`.

### Single-statement bodies on the same/next line, no braces, no `unlikely`
- Tightens the original style further. Multi-condition `if` runs uncluttered:
  - `633417308f16`: `DBUG_ASSERT(buf == table->record[0] || buf == table->record[1]);` collapses a two-line assert into one.
  - `74baec1b8a92`: replaces a 30-line nested loop with one `while ((part_elem= part_it++)) { ... }` and no extra braces.

### Constructor-style and `reinterpret_cast` over C-style downcasts; bare C-style for one-word changes
- Evidence:
  - `71d4cae8668d` deliberately changes `static_cast<Item_field*>(f)` to `reinterpret_cast<Item_field*>(f)` to silence UBSAN, and adds a debug-only `(Item_field*)0x01` guard.
  - `4602761a9db0` keeps a single `(uchar *)table->field[SERVER_NAME_FIELD]->ptr` (C-style) in a partially-rewritten `ha_index_read_idx_map` call — he doesn't introduce `static_cast` casually.
  - `65bdb573e6b6` uses `static_cast<int>(MAX_TABLES)` for a single argument that needs widening.
- Pattern: `reinterpret_cast` for "the compiler must shut up about UB I have proven cannot fire"; constructor-style only when the cast is to a struct literal (e.g. `Lex_ident_db_normalized(...)` — see `69f401bdb63e`). Plain `(uchar*)` and `(char*)` remain in code he hasn't rewritten.

### Use `nullptr` sparingly; mostly stays with `NULL` / `0` / `NullS` in C-style code
- Evidence:
  - `74baec1b8a92` writes `return NULL;` in a new method (`partition_element_iterator`).
  - `6060eec5967d` (mariabackup): `mariabackup_args.push_back(nullptr);` — uses `nullptr` in a clearly C++ context.
- He matches the file: C/.c stays `NULL`, .cc with templates can be `nullptr`; he doesn't convert the file wholesale.

### Variable declarations at the top of a scope; introduce throw-away locals only when they shorten code
- Evidence:
  - `46135c625bcd` `5f262639fe96` `5b0818ee637c`: keeps declarations at function top.
  - `7325f948e8b0`: declares `LEX_CSTRING view_sql_path=...` at the start of the new scope block where it is needed (still top-of-block).

### `enum` blocks for symbolic field indexes
- He introduces tagged enums when seeing magic-numbered `table->field[N]`.
- Evidence (medium, dedicated commit):
  - `4602761a9db0` introduces
    ```
    enum mysql_plugin_fields { PLUGIN_NAME, PLUGIN_SONAME, PLUGIN_FIELDS_COUNT };
    enum servers_fields { SERVER_NAME_FIELD, HOST_FIELD, DB_FIELD, ... SERVERS_FIELDS_COUNT };
    ```
    and replaces every `table->field[0..8]` accordingly. Note the trailing `..._COUNT` member used in `table->s->fields < SERVERS_FIELDS_COUNT` checks.
- Apply this idiom when touching ACL/system-table code that indexes `table->field[N]` numerically.

### `DBUG_ENTER`/`DBUG_RETURN`/`DBUG_PRINT` only inherited, almost never added
- He removes `unlikely` and refactors signatures but does not sprinkle new `DBUG_ENTER` calls in code he writes. He does fix existing ones: `5b0818ee637c` corrects `DBUG_ENTER("sp_link_routine")` to `DBUG_ENTER("sp_clone_and_link_routine")` to match the function name.

### Asserts: relax rather than tighten when the assertion proves false on legitimate input
- Evidence (medium):
  - `6e1880beca38`: parser assert `(yyvsp[-3].simple_string) < (yyvsp[-1].simple_string)` — fix is to **relax** the assert to account for query-killed-in-parser.
  - `7b9d3a4df6c9`: `DBUG_ASSERT(str[strlen(str)-1] != '\n')` relaxed to `... != '\n' || strlen(str) == MYSQL_ERRMSG_SIZE-1` to allow truncated-at-newline.
- He pairs the relaxation with a body that names the legitimate exception and (when possible) fixes the source too (`7be481670e8c` removes trailing `'\n'` from CONNECT messages in a separate commit).

## Refactoring / cleanup habits

### Pure-cleanup commits go in their own commit, with `cleanup:` prefix or bare `cleanup` subject
- Confidence: high. Cleanups are never folded into a MDEV fix.
- Evidence: `4602761a9db0`, `473a6cea79de`, `4f9a13e9ecf2`, `5b0818ee637c` (subject is just "cleanup"; body is a bulleted list of independent micro-changes), `74baec1b8a92`, `75b000372b6d`, `75b2aadb9e92`, `78e474b1a720`.
- The bare-`cleanup` body lists each change as a bullet:
  ```
  * rename to follow the standard vprintf name convention
  * remove `(LEX_CSTRING*) &lex_string` casts
  * LEX_CSTRING -> Lex_ident_db in path
  * Hash_set<Sroutine_hash_entry>
  * move assert out of the loop
  * some comments and whitespace changes
  ```

### Patterns he eliminates
- **Magic field indexes** → enum + named constants (`4602761a9db0`).
- **`HASH*` raw API** → typed `Hash_set<T>` template (`5b0818ee637c`: `bool sp_update_sp_used_routines(HASH *dst, HASH *src)` → `bool sp_update_sp_used_routines(Sroutine_hash *dst, HASH *src)`, replacing manual `my_hash_search`/`my_hash_insert` with `dst->find()/insert()` and switching the loop to range-for `for (Sroutine_hash_entry &rt: *src)`).
- **`my_alloca` for variable-length buffers** → `my_safe_alloca`/`my_safe_afree` when size can exceed a threshold (`64c9efbfa574` — fixes a Spider crash by switching all four allocation sites).
- **Casts of `LEX_STRING`/`LEX_CSTRING` to-self** — `(LEX_CSTRING*) &lex_string` and `(const char*) name->str` are stripped (`5b0818ee637c`, `7b276c0282a9`).
- **Outdated `MYSQL_VERSION_ID` ifdefs** — `75b2aadb9e92` removes everything from `MYSQL_VERSION_ID > 32300` to `>= 50515` in client, plugins (handler_socket, oqgraph, sphinx) and extra/mariabackup. Explicitly skips externally-hosted engines: connect, mroonga, columnstore.
- **Permanent state machinery for a transient need** — `6e086ce2a3a8` deletes `Sql_path_stack` and `Sql_path_push` (a heap-backed list in THD) in favor of a stack-local `Sql_path_instant_set`. Body: "Do it on the stack like for sql_mode, sctx, abort_on_warning, and other THD properties that often need to be changed temporarily." This is his recurring view: **transient overrides belong on the C++ stack, not in THD**.
- **`unlikely(...)` decoration** — see code-style section.

### Renaming as clarification
- When a name is misleading he renames first, fixes later.
- Evidence:
  - `7772bf07d8c8` removes `LEX::make_sp_name_sql_path()` because "it confusingly didn't have anything to do with sql path"; merged into `LEX::make_sp_name()` with a `bool with_db` flag.
  - `79ad188d46d3` renames `option_struct` on `partition_element` to `option_struct_part` and on `TABLE_SHARE` to `option_struct_table` to "emphasize its semantics and prevent incorrect usage".
  - `78e474b1a720` renames `sp_cache_flush_obsolete()` to `sp_cache_remove()` because most callers don't actually need the version-compare; the version compare moves to the one caller that needs it.

### Extract helpers only when the same multi-line dance repeats verbatim
- `75b000372b6d`: introduces `build_path_for_table(char *to, const char *dir, const char *table, const char *ext)` after seeing the same `convert_dirname`+`my_load_path`+`fn_format` sequence twice.
- `74baec1b8a92`: introduces `partition_element_iterator` because the `if (m_is_sub_partitioned) { nested-iterator } else { flat-iterator }` pattern appeared in 3 places.
- He doesn't extract helpers for a single user.

### When deleting code, also delete the comment that explained it
- `59d679a3832c`: removes `Binary_string::chop()` plus its 20-line "PMG 2004.11.12 ..." comment block. The note explaining why `String::chop` is now charset-aware lives in the commit message, not in the code.

## Bug-fix approach

### Fix at the cause, not at the assert site; pair with a relaxed assert when the assert is unsound
- Evidence (high):
  - `7be481670e8c` (CONNECT engine): removes `\n` from error messages at every `snprintf(g->Message, ...)` site rather than relaxing the assert further.
  - `7b9d3a4df6c9` does both: relaxes assert in `my_message_sql` AND unifies `ERRMSGSIZE` with `MYSQL_ERRMSG_SIZE` so the next caller doesn't drift.
  - `4802bfe4f907`: assert was tripping because partition auto-create chose a value at `TIMESTAMP_MAX_VALUE`; the fix is a 1-line check in `partition_info::vers_set_hist_part`, not an assertion change.

### Tests live with the fix; placed under the smallest existing suite
- Evidence (high — almost every MDEV commit includes a test):
  - `5738edf406b1`: adds 13 lines to `mysql-test/main/join_outer.test`.
  - `6f671c5174bb`: adds 11 lines to `mysql-test/main/func_str.test`.
  - `633417308f16`: adds 21 lines to `mysql-test/suite/period/t/long_unique.test`.
  - `64c9efbfa574`: creates a dedicated `storage/spider/mysql-test/spider/t/loop_check_long_var.test` because the bug is engine-specific.
  - `7984408bbdf0`: 5 lines added to `mysql-test/main/gis.test`.
- He prefers to extend an existing `.test` file (matches the area) over creating a new one. New files only appear when the area is new (Spider loop-check) or the test is meaningfully separate (`mysql-test/main/sp-bugs2.test` in `46135c625bcd`).

### Minimal patches dominate
- 1-3 line code changes are the norm:
  - `46135c625bcd`: 1 line (`system_charset_info` → `table_alias_charset` in `my_hash_init`).
  - `6f671c5174bb`: 1 line (`value_buff.mark_as_const();`).
  - `7984408bbdf0`: 1 line (`len-= ls_len;`).
  - `74b2da777eff`: 1 line (`create_info->option_struct= share->option_struct_table;`).
  - `4802bfe4f907`: 1 line (`&& vers_info->hist_part->range_value < TIMESTAMP_MAX_VALUE`).
- Larger patches show up when the cleanup is intentional (`79ad188d46d3` reworks `option_struct` end-to-end).

### Sanitizer fixes are usually 1-line workarounds + comment block
- Evidence (medium):
  - `4bfbdbc68236` "ubsan error, memcpy(dst, NULL, 0)": adds `|| !name->m_db.str` to a guard.
  - `71d4cae8668d` UBSAN: switches `static_cast` to `reinterpret_cast`, adds an `#ifndef DBUG_OFF` debug check, and a 4-line `/* note that ... */` comment explaining why the bad pointer is never dereferenced.
  - `4c04c656e647` MSAN compiler bug: a 4-line `IF (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER "20.0") ... SET(CMAKE_CXX_FLAGS_RELWITHDEBINFO ... -O1) ENDIF()` in `CMakeLists.txt`, with the LLVM issue number in the body.

### Crash-on-NULL-data fixes via `safe_str(...)`
- Evidence (low-medium):
  - `7b276c0282a9` adds an overload `safe_str(const LEX_CSTRING*)` to `include/m_string.h`, then changes every `client_cs_name->str` in `Trigger_creation_ctx::create` to `safe_str(client_cs_name)`. Body: "don't trust the content of a file read from disk". Pattern: when a struct from disk may have a NULL `.str`, the fix is to centralize NULL-tolerance in `safe_str()` rather than per-call null checks.

### When a follow-up has its own MDEV, fix the symptom in a one-line patch
- `4e240192647b` "MDEV-39112 fix RPAD too" (empty body) is paired with the prior LPAD fix in `6f671c5174bb`.
- `557bd9ef90f0` "MDEV-39498 more fixes" with body: `* use max_length=640\n* also fix mroonga_highlight_html, mroonga_normalize, mroonga_snippet_html\n* remove disable_cursor_protocol from all mroonga tests`.

## Architecture / API choices

### Add a parameter to an existing method rather than spawning a near-duplicate
- `7772bf07d8c8` turns two functions (`make_sp_name` / `make_sp_name_sql_path`) into one with a `bool with_db`.

### Move long-lived per-statement state to the C++ stack
- See cleanup section `6e086ce2a3a8`. Body explicitly cites `sql_mode`, `sctx`, `abort_on_warning` as the model. New abstractions follow the `XYZ_instant_set` naming.

### Prefer in-tree typed containers (`Hash_set<T>`, `List<T>`, `List_iterator_fast`) over raw `HASH`
- `5b0818ee637c` migrates `sp_update_sp_used_routines`/`sp_update_stmt_used_routines` to `Sroutine_hash` typedef + range-for.
- He **does not** introduce `std::unordered_map` / `std::vector` even where they'd fit. The new iterator in `74baec1b8a92` (`partition_element_iterator`) is hand-rolled with `List_iterator_fast` rather than wrapping STL.

### Single allocation in one block, not per-element
- `69f401bdb63e` body: "allocate Sql_path in one memory chunk, not one per schema ... because it's always allocated and freed as a whole". Parser is reworked so it produces a complete name-list, then one `my_malloc` covers the whole thing.

### Cross-plugin API additions: bump the interface version, add the field
- `63583b08246b` (caching_sha2_password): bumps `MYSQL_AUTHENTICATION_INTERFACE_VERSION` from `0x0202` to `0x0203` and adds `int tls;` to `MYSQL_PLUGIN_VIO_INFO`. The version bump and the struct change are in the same commit.

### Approximate-then-refine optimisation pattern (in vector/JSON code)
- `4ca9fca4f6ce` introduces `distance_greater_than(Y, Z)`. Pattern: instead of always-exact computation, compute a partial estimate (192 first dims), multiply by a safety margin (1.05f), and only fall back when needed. Constants land as file-scope `static constexpr` (`subdist_part`, `subdist_margin`) so they're tunable without rebuilds-of-everything.

### `CF_*` flags pattern: declare all relevant flags up-front, fix-up at top-level
- `4d0395a6ffe0` shows the canonical layout for `sql_command_flags[]`: each `SQLCOM_*` is assigned `CF_CHANGES_DATA` (etc.) in one block, then `|= CF_AUTO_COMMIT_TRANS` is applied later. He converts a few stray `=` into `|=` when the second assignment was meant to compose.

## Domain quirks

### JSON / strings
- Charset-correctness is checked at every `String::append/chop` call. `59d679a3832c` rewrites `String::chop()` to track `well_formed_length()` after decrement, and replaces a `for (...) chop()` loop in `json_nice()` with `nice_js->length(nice_js->length() - value_len)` (still keeping the second loop because it counts characters, not bytes).
- `Item_func_json_extract::val_bool()` (`67068c8f9050`) — adds a new virtual override for an existing Item rather than special-casing the caller (`Item_func_truth`).
- `58318518d25f` (`Item_string::type_handler()`): single-line change replacing `&type_handler_varchar` with `Type_handler::string_type_handler(max_length)` — pick the right type-handler factory rather than hard-coding.

### Parser (sql_yacc.yy)
- Add cheap pre-checks rather than letting the parser build a deep AST that will be rejected later: `65bdb573e6b6` enforces `MAX_TABLES` in the `table_ref -> join_table` rule.
- Use `MYSQL_YYABORT;` after `my_error(...)`. Don't call `thd->parse_error()` when you've already produced a typed error.

### ACL / system tables
- New `enum mysql_*_fields { ..., _FIELDS_COUNT }` per system table (see `4602761a9db0`).
- Compare `table->s->fields < <ENUM>_FIELDS_COUNT` instead of magic ints.

### Vector / mhnsw
- File-scope `static constexpr` for tunables, comments explaining "X and Y are best by test", and a body that lists alternatives tested and which datasets break (e.g. "destroys recall for original (non-randomized) gist and *mnist") — see `4ca9fca4f6ce`. Apply this discipline when proposing any vector-index tuning.

### Internal utilities preferred over libc/STL
- `safe_str` (`7b276c0282a9`) for NULL strings.
- `my_safe_alloca` (`64c9efbfa574`) when a buffer may be large.
- `MYSQL_ERRMSG_SIZE` (`7b9d3a4df6c9`) instead of a per-file `#define ERRMSGSIZE 512`.
- `Lex_ident_db_normalized`, `Lex_cstring_strlen` for typed identifier wrapping (visible in many cleanup commits).

### Test reliability practice
- `7888b6c0d55d`: when tests are inherently fragile (memory accounting), **consolidate them into one file** with `--skip-msan`, `--skip-embedded`, `--skip-ps-protocol`, `--skip-32bit` all set; remove those restrictions from other files. Body: "they're very fragile by nature, but let's at least move them into one file ... to have the memory usage more predictable".
- `764b893cb7f7`: when a known message clutters logs under `rr`, **add a suppression**, not a code change.
- `5e7c391dcbfd`: a long body explaining "the test that didn't work for years" — multiple independent fixes enumerated 1) ... 4).

### `change_db` and similar global-state set-ups
- `78ed44beb3ce` body: "Events should use proper `mysql_change_db()` to configure the current database correctly, in particular to set the db_charset." The fix replaces a partial `thd->set_db(&dbname)` with a real `mysql_change_db()` call and removes a 15-line comment that justified the wrong shortcut.

### `prepare_for_insert(1)` lifecycle
- `57434359540c` body explains the ordering: lookup-handler preparation must precede `prune_partitions()` because `prune_partitions` expects all partitions in the read-set. Same idiom shows up in `6521b4112bb6` — moving `prepare_for_insert(1)` to `initialize_tables` from `prepare()` because `multi_update::prepare` runs before `lock_tables()`.

## Maintenance branch handling

### Merge commit subjects are exactly `Merge branch 'X.Y' into Z.A`
- Bodies are empty most of the time. They contain notes only when the merge required manual conflict resolution:
  - `6e8dbb969334` (12.0 -> 12.1) body: `wsrep.wsrep_off: update the result file after c4cad8d50c2`.
  - `6660d0bdd7c8` (12.3 -> 13.0) body: `changed deprecation version for wsrep_slave_FK_checks, because it was just deprecated this month`.

### Forward-merge cadence and direction
- He merges in the canonical chain (10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → 13.0). Multiple merges in this chunk for the same chain land same-day or close (e.g. 2025-08-03 brings `55a39f13e408`, `59f9ef24ea58`, `6e8dbb969334`).
- He authors targeted commits on `10.6`/`10.11` only for very specific bugfixes; in this chunk most authored work targets the latest dev branches.

### "12.1 branch" placeholder commit
- `72b666b837eb` "12.1 branch" — used to mark the branch fork point. Single empty-bodied commit.

## Singletons worth noting

- **`523504fa4bf39` set_malloc_size_cb pattern**: when a callback can be NULL, store a `dummy` no-op instead of NULL-checking on every call. `update_malloc_size= func ? func : dummy;` removes three `if (update_malloc_size != dummy)` checks. Same principle should be applied to other "may be unset" callbacks.
- **`6060eec5967d` mariabackup early-options**: replaces a hand-rolled `strncmp(argv[i], "--foo", optend - argv[i])` block with two passes of `handle_options(..., xb_early_options)` using a `my_bool xb_early_options(opt, arg, ctx) { return 0; }` no-op handler. He prefers reusing `my_getopt` even for partial-parsing scenarios.
- **`516f68af9e5d` prelocking distance**: when ranking candidates by a distance metric, multiply by 2 and bit-OR a tiebreaker into the low bit (`distance|= 1`). Avoid adding floats or fields.
- **`5f262639fe96` field-store conventions**: returning non-zero from `Field::store(double)` when `nr != val` (rounded vs. original) is now the contract for "fractional truncation"; warnings via `set_warning(ER_WARN_DATA_OUT_OF_RANGE, 1)`. Don't introduce a new warning level (`E_DEC_TRUNCATED`/`set_note(WARN_DATA_TRUNCATED, 1)` was removed precisely to make this binary).
- **`57629c25816d`**: Debian client-plugin loading bug fixed by **symlinking** during install, not by changing the search path in code. Body: `symlink client pligins into INSTALL_PLUGINDIR on Debian`.
- **`635559a2ad68` audit-plugin parser removal**: a 400-line hand-rolled keyword-scanner deleted in favour of a single `thd_sql_command(thd)` call plus a new `sql_command.h` header that splits `enum_sql_command` out of `sql_cmd.h`. Pattern: don't reimplement what the server already exposes.
- **`5fa5ee3edb21` "Bug#37117875 test case"**: he occasionally lands a test for an upstream MySQL bug number when MariaDB's behaviour diverges or was already fixed; body is empty, subject names the upstream bug ID.
- **`5349220b2e82`**: SQL-script fix in `scripts/sys_schema/procedures/ps_setup_save.sql` — he edits the `sys_schema` SQL directly and adds a regression test under `mysql-test/suite/sysschema`. No `.cc` involved.
