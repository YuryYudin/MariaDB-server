---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/item_create.cc, sql/item_func.{cc,h}, sql/CLAUDE.md
---

# Playbook: Add a new built-in SQL function

**Use when:** you're adding a new built-in scalar function callable from SQL — `BAR(x)`, `JSON_FOO(j, p)`, `ST_NEW(g1, g2)`, `MONTHS_BETWEEN(d1, d2)`, etc.
**Skip if:** (a) it's a **stored** function (`CREATE FUNCTION`, pure SQL — no C++); (b) it's a **UDF** (loadable, per-engine — use [`plugin/udf_examples/`](../../plugin/udf_examples/) as the template); (c) it's a **window-function aggregate** (different machinery — see [`sql/item_windowfunc.{cc,h}`](../../sql/item_windowfunc.cc) and [`Item_sum`](../../sql/item_sum.h)); (d) it's a **regular aggregate** (`SUM`-shape — subclass `Item_sum_*` in [`sql/item_sum.cc`](../../sql/item_sum.cc)).
**Typical effort:** 2-4 hours for a simple scalar function; longer for variadic, JSON-shape return, or hybrid-type returns.

## Overview

A built-in SQL function in MariaDB is a C++ class that subclasses some `Item_*` base in [`sql/item_*.{cc,h}`](../../sql/). The parser routes the SQL identifier (`BAR`, `JSON_FOO`) to the constructor through a factory in [`sql/item_create.cc`](../../sql/item_create.cc). [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" has the cluster-file map (string → `item_strfunc.cc`, time → `item_timefunc.cc`, JSON → `item_jsonfunc.cc`, vector → `item_vectorfunc.cc`, GIS → `item_geofunc.cc`, …) — don't restate it; read.

The factory determines argument arity **at parse time** (using `Create_func_arg0` / `Create_func_arg1` / `Create_func_arg2` / `Create_func_arg3` / `Create_native_func` for variadic). The class methods (`val_*`, `fix_length_and_dec`, `func_name_cstring`, `shallow_copy`) determine behaviour **at execute time**.

## Files you'll touch

| File | Role |
|---|---|
| [`sql/<cluster>.h`](../../sql/) | Declare the new `Item_func_<name>` class — header lives next to the existing family. |
| [`sql/<cluster>.cc`](../../sql/) | Implement `val_*()` and `fix_length_and_dec()`. |
| [`sql/item_create.cc`](../../sql/item_create.cc) | New `Create_func_<name>` factory subclass + entry in the `Native_func_registry func_array[]` array (or one of the per-mode/per-feature registry arrays). |
| `mysql-test/main/<suitable>.test` + `.result` | The MTR test — PS + SP variants mandatory. See [`add-mtr-test.md`](add-mtr-test.md). |
| [`sql/sql_yacc.yy`](../../sql/sql_yacc.yy) | **Only** if the name has to be a SQL keyword (e.g. `EXTRACT(... FROM ...)`, `CAST(... AS ...)`, `POSITION(... IN ...)` — special syntax, not just a function call). Almost always avoidable — the factory is the right home. |

## Steps

1. **Confirm the function name isn't taken and isn't a keyword.**

   ```sh
   grep -i '"BAR"' sql/item_create.cc sql/sql_yacc.yy sql/lex.h | head
   grep -inE 'STRING_WITH_LEN\("BAR"\)' sql/item_create.cc
   ```

   The `Native_func_registry` arrays in [`sql/item_create.cc`](../../sql/item_create.cc) (search `static.*Native_func_registry`) are the source of truth for factory-registered names. [`sql/lex.h`](../../sql/lex.h) lists keywords that go through the grammar instead. If your candidate name clashes, pick a different one (or namespace it as `MY_BAR` / `JSON_BAR`).

2. **Pick the right return-type base class.** Choose by **return type, not argument type** — a function taking an `INT` and returning a `VARCHAR` is `Item_str_func`. The table is canonical in [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" — read it there; the short form:

   | Returns | Base |
   |---|---|
   | Integer | `Item_int_func` (`Item_longlong_func` for fixed `BIGINT`) |
   | Double | `Item_real_func` |
   | DECIMAL | `Item_decimal_func` |
   | String (with charset) | `Item_str_func` (or `Item_str_ascii_func` / `Item_str_ascii_checksum_func` for ASCII-only) |
   | DATE / TIME / DATETIME | `Item_datefunc` / `Item_timefunc` / `Item_datetimefunc` |
   | Boolean / predicate | `Item_bool_func` |
   | Return depends on args | `Item_func_hybrid_field_type` / `Item_func_numhybrid` |

3. **Pick the cluster file** (decide `<cluster>` for the next two steps). Use [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" — the table maps domain → cluster file. **Create a new `item_*.{cc,h}` file only for a wholly-new function family** (e.g. `item_vectorfunc.cc` was new in 11.8 for the vector family). Don't fragment for a single function — pitfall, see below.

4. **Declare the class in `<cluster>.h`.** Pattern (modelled on `Item_func_uuid_short` and `Item_func_abs` in [`sql/item_func.h`](../../sql/item_func.h) — `grep -n 'class Item_func_uuid_short\|class Item_func_abs' sql/item_func.h`):

   ```cpp
   class Item_func_bar : public Item_int_func
   {
   public:
     Item_func_bar(THD *thd, Item *a) : Item_int_func(thd, a) {}
     longlong val_int() override;
     bool fix_length_and_dec(THD *thd) override;
     LEX_CSTRING func_name_cstring() const override
     {
       static LEX_CSTRING name= {STRING_WITH_LEN("bar") };
       return name;
     }
   protected:
     Item *shallow_copy(THD *thd) const override
     { return get_item_copy<Item_func_bar>(thd, this); }
   };
   ```

   Notes:
   - **`func_name_cstring()`** — return a `LEX_CSTRING` with the SQL identifier; used by `EXPLAIN`, error messages, `JSON_OBJECTAGG`-style introspection. Missing → empty function name in output.
   - **`shallow_copy()`** is the current API on `main`, `10.6`, `10.11`, `11.4`, `11.8`, `12.2`, `12.3` — the optimizer's clone hook during transformation. Missing → crashes on re-execution after optimizer rewrites. See [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution". **Backports note:** on `12.0` and `12.1` only, the method is named `do_get_copy(THD*) const` — same signature, same purpose, different name. Confirm by `git show <branch>:sql/item.h | grep -E 'shallow_copy|do_get_copy'` before patching a back-port.
   - The `get_item_copy<T>` helper is defined in [`sql/item.h`](../../sql/item.h) — `grep -n 'get_item_copy' sql/item.h`.

5. **Implement the methods in `<cluster>.cc`.** Pattern (the null-propagation idiom is from `Item_func_crc32::val_int` in [`sql/item_strfunc.cc`](../../sql/item_strfunc.cc) — `grep -n 'Item_func_crc32::val_int' sql/item_strfunc.cc`):

   ```cpp
   longlong Item_func_bar::val_int()
   {
     DBUG_ASSERT(fixed());
     longlong v= args[0]->val_int();
     if ((null_value= args[0]->null_value))
       return 0;
     return v * 2;
   }

   bool Item_func_bar::fix_length_and_dec(THD *thd)
   {
     max_length= MY_INT64_NUM_DECIMAL_DIGITS;
     set_maybe_null();          // because args[0] may be NULL
     return false;
   }
   ```

   - Propagate `null_value` from **every** argument that can be NULL (see Pitfalls — same family as MDEV-39179). For temporal-input functions that call `get_date()` for each arg, the idiom is `if ((null_value= args[0]->get_date(thd, &t0, mode) || args[1]->get_date(thd, &t1, mode))) return 0;` — OR the booleans into a single `null_value` assignment.
   - For `Item_str_func`: also call `agg_arg_charsets_for_string_result(collation, args, arg_count)` in `fix_length_and_dec()` to derive the result collation from the inputs (skipping this is a common review-rejection — see Pitfalls).
   - Set `set_maybe_null()` (replaces the older `maybe_null= true`) only if a NULL **can** appear in the result; an always-non-NULL function should leave it unset so the optimizer can elide null-checks.
   - **`Item_real_func` and `Item_int_func` have sensible default `fix_length_and_dec()`** implementations (`Item_real_func` sets `decimals= NOT_FIXED_DEC; max_length= float_length(decimals)`). You only need to override if you want to tighten precision, set `set_maybe_null()` conditionally, or aggregate charset/collation from string-typed children.
   - For functions interacting with `record[1]` / `Field::ptr_old` — extremely rare for new code — read [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"TABLE record buffers" first. MDEV-39179 was a swap-only-half-the-pointers bug.

6. **Register in the factory in [`sql/item_create.cc`](../../sql/item_create.cc).** Two parts.

   **(a) The `Create_func_<name>` subclass.** Pattern (modelled on `Create_func_abs` — `grep -n 'class Create_func_abs\|Create_func_abs::create_1_arg' sql/item_create.cc`):

   ```cpp
   class Create_func_bar : public Create_func_arg1
   {
   public:
     Item *create_1_arg(THD *thd, Item *arg1) override;
     static Create_func_bar s_singleton;
   protected:
     Create_func_bar() = default;
     ~Create_func_bar() override = default;
   };
   ```

   ```cpp
   Create_func_bar Create_func_bar::s_singleton;

   Item*
   Create_func_bar::create_1_arg(THD *thd, Item *arg1)
   {
     return new (thd->mem_root) Item_func_bar(thd, arg1);
   }
   ```

   Variants by arity: `Create_func_arg0` / `Create_func_arg1` / `Create_func_arg2` / `Create_func_arg3` (each enforces arity at parse time and emits `ER_WRONG_PARAMCOUNT_TO_NATIVE_FCT`). Use `Create_native_func` when the argument count is **variable** — override `create_native()` and do your own arg-count check. Real variadic example: `Create_func_aes_encrypt` (find it via `grep -n 'class Create_func_aes_encrypt' sql/item_create.cc`).

   **(b) The `Native_func_registry` entry.** Append to the appropriate array — locate them with `grep -nE 'static.*Native_func_registry' sql/item_create.cc`. Two main destinations:

   - **`func_array[]`** — the *unconditional* registry; the function is callable in any `sql_mode`. Use this if the function exists in default (non-Oracle) mode, even if you also enable it in Oracle mode.
   - **`func_array_oracle_overrides[]`** — registered **only** when `sql_mode='ORACLE'`. Use this when the function is exclusively an Oracle compatibility function (the canonical example is `MONTHS_BETWEEN`, MDEV-37319).

   Decision rule: *"Is this function available in default mode?"* — yes → `func_array[]`; no → `func_array_oracle_overrides[]`. Don't confuse "Oracle-themed" (e.g. `ADD_MONTHS`, available everywhere) with "Oracle-only" (e.g. `MONTHS_BETWEEN`, mode-gated).

   Entries are **alphabetically sorted, one line per entry** — the in-file comment says *"keep 1 line per entry, it makes grep | sort easier"*:

   ```cpp
   { { STRING_WITH_LEN("BAR") }, BUILDER(Create_func_bar)},
   ```

7. **Add the MTR test.** Cross-link to [`add-mtr-test.md`](add-mtr-test.md) for naming, location, and recording. **Mandatory coverage** for a new function:
   - **Happy path** with multiple input types (int, decimal, negative, large) as relevant to your function.
   - **NULL handling** — `SELECT BAR(NULL);` and a row-set with NULL inputs (use a **two-row** table so the const-table short-circuit doesn't mask bugs — see [`add-mtr-test.md`](add-mtr-test.md) §"Two rows minimum").
   - **Error / out-of-range** if applicable (use `--error ER_*`, never numeric codes).
   - **Prepared-statement variant** — `PREPARE s FROM 'SELECT BAR(?)'; EXECUTE s USING …;`. Mandatory per PR4433. Copy the skeleton from [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton".
   - **Stored-procedure variant** — same skeleton.
   - **Non-default `sql_mode`** if the function's behaviour is mode-sensitive (e.g. Oracle-compat, `PIPES_AS_CONCAT`, `PAD_CHAR_TO_FULL_LENGTH`).

   File-naming: `mysql-test/main/func_<group>.test` is the convention for a new function family ([`add-mtr-test.md`](add-mtr-test.md) §"Naming"). Default to **extending** an existing `func_*.test` if one fits the domain (see MDEV-31736 below).

   For an **Oracle-mode-only** function (registered in `func_array_oracle_overrides[]`), the test goes under [`mysql-test/suite/compat/oracle/t/<name>.test`](../../mysql-test/suite/compat/oracle/t/) instead — the suite's startup includes already set `sql_mode=ORACLE`, so don't repeat that at file scope. Use a sibling test (e.g. `func_add_months.test`) as the shape template. Add a negative case at the end that flips `sql_mode=DEFAULT` and expects `ER_SP_DOES_NOT_EXIST` to prove the gating works.

8. **Record and run.** From the build directory:

   ```sh
   cd <build>/mysql-test
   ./mtr --record main.func_<name>
   git diff -- mysql-test/main/func_<name>.result   # eyeball every line
   ./mtr main.func_<name>                            # confirm it now passes
   ```

   Verify the test **fails without your fix** by reverting the call site and re-running ([`add-mtr-test.md`](add-mtr-test.md) step 8).

9. **Commit.** Header + impl + factory entry + test in **one commit**. Subject: `MDEV-NNNNN <one-line description>`. Cross-link: [`add-mtr-test.md`](add-mtr-test.md) §"Commit".

## Examples from past PRs

| MDEV | Function | Base class | Cluster | Notes |
|---|---|---|---|---|
| MDEV-37319 (`cd483cfe082`) | `MONTHS_BETWEEN(d1, d2)` | `Item_real_func` | [`sql/item_timefunc.{cc,h}`](../../sql/item_timefunc.cc) | Canonical example — 22 lines in `item_create.cc`, 119 in `item_timefunc.cc`, 18 in `.h`, plus 47/79 lines of test under `mysql-test/suite/compat/oracle/`. Two-arg, Oracle-namespaced (separate registry array). |
| MDEV-20023 (`2fcc2b4f516`) | `TRUNC(date [, format])` | temporal | [`sql/item_timefunc.{cc,h}`](../../sql/item_timefunc.cc) | Variadic — uses `Create_native_func` because arg count is 1 or 2. Oracle-compat surface. |
| MDEV-20022 (`b10e209d169`) | `TO_NUMBER(num_or_str [, fmt])` | `Item_real_func` | New file [`sql/item_numconvfunc.cc`](../../sql/item_numconvfunc.cc) | One of the rare "new cluster file" cases — Oracle compat, a numeric-formatting family with no good existing home. |
| MDEV-31736 (`a35f744d787`) | `FORMAT_BYTES(n)` | `Item_str_func` | [`sql/item_strfunc.{cc,h}`](../../sql/item_strfunc.cc) | Extended existing `mysql-test/main/func_format.{test,result}` rather than creating a new test file (+137/+221 lines). Multiple `sys_schema` `.result` files updated to use the new function. |
| MDEV-32885 (`9ccf02a9a76`) | `VEC_DISTANCE(v1, v2)` | `Item_real_func` | New file [`sql/item_vectorfunc.{cc,h}`](../../sql/item_vectorfunc.cc) | New cluster file justified by a wholly-new function family (vector). Two `CMakeLists.txt` edits to register the new source. |
| MDEV-38967 (`a3c2a17d364`) | `STR_TO_DATE` index support fix | existing | [`sql/item_timefunc.cc`](../../sql/item_timefunc.cc) | Not a new function but a useful read for how an existing one is wired (`Create_func` entry, `fix_length_and_dec` interaction with optimizer). |

## Pitfalls and rejection patterns

- **Missing `func_name_cstring()`.** Empty function name in `EXPLAIN` and error messages. [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Prepared statements & re-execution" (paragraph "`get_copy()` and `func_name()` are easy to forget").
- **Missing `shallow_copy()` (formerly `get_copy()`).** The optimizer's `Item::transform` will alias the original's children — crashes on re-execution after optimizer rewrites. Same `sql/CLAUDE.md` paragraph.
- **`null_value` not propagated from every nullable argument.** Wrong NULL semantics — the same shape of bug as MDEV-39179 (which was about `record[1]` pointers, but the family is the same: incomplete propagation of "this input was NULL"). Test with `SELECT BAR(NULL)` **and** a multi-row table containing a NULL in the argument column.
- **Wrong base class.** `Item_real_func` for a function that always returns `INT` loses precision and forces unnecessary float arithmetic; `Item_int_func` for a function that can return `> 2^63` silently overflows. Pick by return type, **always**.
- **`Item_str_func` subclass without setting collation in `fix_length_and_dec`.** Result has unspecified collation — review-rejection. Call `agg_arg_charsets_for_string_result(collation, args, arg_count)` (or `agg_arg_charsets_for_comparison` if comparing); set `max_length` to the max character count × `collation.collation->mbmaxlen` for variable-byte charsets.
- **Arity-check in `val_int` / `val_str` rather than the factory.** `Create_func_arg<N>` rejects wrong arity at parse time — fast user feedback, no execution context to worry about. Putting `if (arg_count != 1) my_error(...);` in `val_int` wastes their time and reviewer's.
- **Forgetting `PREPARE … EXECUTE` and stored-procedure tests.** PR4433 family — every new SQL feature needs both variants. Use the skeleton in [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton". A function that works in immediate execution can still crash on the second execute of a prepared statement (missing `shallow_copy()`).
- **One-row test table.** The 1-row-is-const-table optimizer short-circuit silently makes broken functions pass — [`add-mtr-test.md`](add-mtr-test.md) §"Two rows minimum" (PR4505). Use **two rows minimum**, NULL in the relevant column.
- **Touching `sql_yacc.yy` when the factory suffices.** Adding a name to the grammar bloats the parser, can cause shift/reduce conflicts, and is almost never needed — only do it if the syntax differs from `IDENT(args)` (e.g. `EXTRACT(... FROM ...)`).
- **Creating a new `item_*.cc` file when an existing cluster fits.** Fragmentation. The 11.8 vector family and the Oracle `TO_NUMBER` family are the only recent justifiable new-cluster cases (cited above). Default to extending the existing cluster.
- **Numeric error codes in tests.** `--error 1234` → use `--error ER_FOO_BAR`. Names are stable; numbers change perception. [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"mysqltest directive cheat-sheet".
- **New `ER_*` error code added in the middle of `errmsg-utf8.txt`.** It's an ABI — codes go at the end. If your function needs a new error message, follow [`add-error-message.md`](add-error-message.md).
- **Out-of-alphabetical-order insertion into `func_array[]`.** Reviewers grep|sort the registry — keep the alpha order. Comment at line 6320-6324 of `item_create.cc`.
- **Forgetting Oracle-mode shape.** If the function is `sql_mode='oracle'` only, register it in `func_array_oracle_overrides[]` — not the global `func_array[]`. The rule: *"Is this function available in default mode?"* — yes → `func_array[]` (even if Oracle-themed, e.g. `ADD_MONTHS`); no → `func_array_oracle_overrides[]` (e.g. MDEV-37319 `MONTHS_BETWEEN`). See step 6 above for the full decision.

## Validation

The deliverable check:

```sh
cd <build>
cmake --build . -j$(nproc)            # the new symbol compiles, factory registers
cd mysql-test
./mtr main.func_<name>                 # the new test passes
./mtr --suite=main                     # no collateral .result-file collisions
```

Confirm:
- `EXPLAIN SELECT BAR(x) FROM t1` shows `bar` in the Item tree — verifies `func_name_cstring()`.
- `PREPARE s FROM 'SELECT BAR(?)'; EXECUTE s USING 7; EXECUTE s USING NULL;` — verifies `shallow_copy()` survives re-execution.
- `SELECT BAR(NULL)` returns `NULL`, not `0` or an arbitrary number — verifies `null_value` propagation.
- Buildbot clean across all sanitizer configs — UBSan in particular catches `null_value`-after-error mistakes and format-string mismatches.

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `f03e562b97c` (branch `main`).
- **Files surveyed:**
  - [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"Items (expressions)" (cluster table, base-class chooser table), §"Prepared statements & re-execution" (`shallow_copy`/`func_name_cstring` consequences), §"TABLE record buffers" (for the rare-but-cited record-buffer case), §"Where to start" (entry pointer to this playbook). Cited heavily; not duplicated.
  - [`sql/item_create.cc`](../../sql/item_create.cc) — `Create_func_abs` declaration + impl, `func_array[]` shape, `Create_func_aes_encrypt` (variadic example), `func_array_oracle_overrides[]`. Find each via `grep -n` since exact line numbers drift across releases.
  - [`sql/item_func.h`](../../sql/item_func.h) — `Item_func_abs`, `Item_func_uuid_short` (minimal class templates); `shallow_copy()` pattern via `get_item_copy<T>`.
  - [`sql/item.h`](../../sql/item.h) — `shallow_copy()` virtual and `get_item_copy<T>` template.
  - [`sql/item_strfunc.cc`](../../sql/item_strfunc.cc) — `Item_func_crc32::val_int` for the `null_value` propagation idiom.
  - [`sql/item_timefunc.h`](../../sql/item_timefunc.h) / [`item_timefunc.cc`](../../sql/item_timefunc.cc) — for the temporal-input null-propagation pattern.
  - [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) §"PS/SP variant skeleton", §"Where new tests go" — cited; test machinery lives there.
  - [`.claude/playbooks/add-mtr-test.md`](add-mtr-test.md) — the test workflow; delegated, not duplicated.
  - [`.claude/playbooks/add-error-message.md`](add-error-message.md) — referenced for the `ER_*` case.
  - [`.claude/docs-plan/PLAN.md`](../docs-plan/PLAN.md) §"Phase 3 — Task 7" — brief for this playbook.
  - Real commits: `cd483cfe082` (MDEV-37319 MONTHS_BETWEEN), `2fcc2b4f516` (MDEV-20023 TRUNC), `b10e209d169` (MDEV-20022 TO_NUMBER), `a35f744d787` (MDEV-31736 FORMAT_BYTES), `9ccf02a9a76` (MDEV-32885 VEC_DISTANCE), `a3c2a17d364` (MDEV-38967 STR_TO_DATE).
- **Deliberately excluded:** the full `Item` class hierarchy and `fix_fields` plumbing (deferred to `sql/docs/item-system.md`, Phase 4); aggregate-function machinery (`Item_sum`, different shape — would need its own playbook); window-function aggregates (different machinery); UDF authoring (separate template under [`plugin/udf_examples/`](../../plugin/udf_examples/)); the per-language-mode registry surface (Oracle, hint, geom — search `Native_func_registry` in `item_create.cc` for the full list).
- **Refresh procedure:** when a new cluster file is added (last was `item_numconvfunc.cc` for MDEV-20022) or the `Item` API renames a hook (history: `get_copy` → `do_get_copy` → `shallow_copy`; `12.0` and `12.1` still ship `do_get_copy`), update the class skeleton in step 4 and the backport footnote; bump `last-verified`.

## Validation history

- **2026-05-14 end-to-end test** (MDEV-37319, MONTHS_BETWEEN, dispatched as a no-context fresh subagent against pre-fix commit `2fcc2b4f516`):
  - The agent's plan matched the landed fix file-for-file (5 files, same base class, same factory pattern, same test location).
  - Surfaced and fixed in this playbook: (a) backport-branch API rename note for `do_get_copy`; (b) replaced stale line numbers with `grep` recipes; (c) clarified the `func_array[]` vs `func_array_oracle_overrides[]` decision rule with the *"available in default mode?"* test; (d) added the `Item_real_func` / `Item_int_func` default-`fix_length_and_dec` note; (e) added the temporal-input null-propagation idiom; (f) added the Oracle-mode-only test-suite cross-reference.
  - Total time the agent estimated for an end-to-end MDEV-37319 implementation, including the playbook-driven steps: ~3 hours (within the playbook's stated 2-4 hour range).
