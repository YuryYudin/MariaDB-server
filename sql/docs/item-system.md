---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/item.{cc,h}, sql/item_func.{cc,h}, sql/sql_type.cc
---

# Reference: the `Item` expression-tree system

Deep dive on the `Item` class family — how SQL expressions are represented, resolved, transformed, evaluated, and torn down. This is the *concepts* doc; the *procedure* for adding a new SQL function is in [`add-sql-function.md`](../../.claude/playbooks/add-sql-function.md). The high-level map of `item_*.cc` files and the base-class picker live in [`sql/CLAUDE.md`](../CLAUDE.md) §"Items (expressions)" — read that first; this doc goes inside.

---

## 1. TL;DR

- **Every SQL expression is an `Item` subtree.** Columns, literals, arithmetic, function calls, subqueries, row constructors — all `Item` subclasses. Found in `sql/item*.{cc,h}` (cluster table in [`sql/CLAUDE.md`](../CLAUDE.md) §"Items (expressions)").
- **Items have a lifecycle:** parse → `fix_fields` → optimize/`transform` → `val_*` (executed) → `cleanup`. **Respect each phase** — the most common bug class in `sql/` is per-execution mutation that survives into the next execution of a prepared statement.
- **Values are read via `val_int()` / `val_real()` / `val_str()` / `val_decimal()` / `get_date()` / `val_native()`.** Callers must read `item->null_value` AFTER the call to see whether the result was SQL-NULL.
- **`Type_handler` is the type-dispatch table.** Items delegate type-specific decisions (`Field` creation, conversion, comparison, `MIN`/`MAX` semantics, binlog encoding) to `Type_handler` virtuals — see [`sql/sql_type.h`](../sql_type.h).
- **`shallow_copy()` and `cleanup()` are the easy-to-forget hooks.** Missing the first → crashes when the optimizer clones an item during transformation. Missing the second → stale state on the second execution of a prepared statement (the `Item_func_trim`-family of bugs).

---

## 2. The class hierarchy

The base lives in [`sql/item.h`](../item.h). Use the grep recipes below — line numbers drift, but `class Item_*` declarations don't:

```sh
grep -n '^class Item' sql/item.h        # base + ident + cache + ref + copy
grep -n '^class Item' sql/item_func.h   # numeric/typecast/arithmetic
grep -n '^class Item' sql/item_strfunc.h
grep -n '^class Item' sql/item_sum.h
grep -n '^class Item' sql/item_cmpfunc.h
grep -n '^class Item' sql/item_subselect.h
```

Top-level shape (collapsed — each leaf has many subclasses):

```
Item                                  (abstract base, sql/item.h)
├── Item_basic_value
│   └── Item_basic_constant
│       ├── Item_literal             → Item_num → Item_int / Item_decimal / Item_float
│       │                            → Item_string (and family)
│       └── Item_null
├── Item_fixed_hybrid                  (base for "already-fixed" items)
│   ├── Item_sp_variable              → Item_splocal* (SP locals)
│   ├── Item_name_const               (NAME_CONST(...))
│   └── Item_result_field             (items that own a Field*)
│       ├── Item_ident
│       │   ├── Item_field            → Item_old_field (RETURNING OLD_VALUE)
│       │   │                         → Item_field_row (row column)
│       │   └── Item_ref              → Item_direct_ref
│       │                             → Item_direct_view_ref
│       │                             → Item_outer_ref (correlated subquery)
│       │                             → Item_ref_null_helper
│       └── (via Item_func_or_sum:)
│           ├── Item_func             → numeric / string / temporal / json /
│           │                           xml / window / vector / geo / cmp / ...
│           └── Item_sum              → SUM / AVG / COUNT / GROUP_CONCAT / MIN / MAX / ...
├── Item_subselect                    → Item_singlerow_subselect / Item_in_subselect /
│                                       Item_exists_subselect / Item_allany_subselect
├── Item_row                          (row constructor, sql/item_row.h)
├── Item_cache                        (materialized value)
│   └── Item_cache_int / _real / _str / _decimal / _datetime / _row / ...
├── Item_copy                         (preserved value for GROUP BY / window funcs)
│   └── Item_copy_string / Item_copy_timestamp
└── Item_param                        (?-placeholder)
```

Don't paraphrase the whole tree — when in doubt, `grep '^class Item_<thing>' sql/item*.h` to land on the right declaration.

---

## 3. The `Item` lifecycle

| Phase | When | Method(s) | What happens |
|---|---|---|---|
| **Parse** | grammar match | constructor | The item is allocated (on `thd->mem_root` or, inside `PREPARE`/SP, on `thd->stmt_arena->mem_root`). Identifier resolution has *not* happened yet. |
| **Fix-fields** | first execute | `fix_fields(THD*, Item**)` | Resolves identifiers (`Item_field` finds its `Field*`), propagates types/precision/charset/null-ability up from children, marks the item `fixed()`. Idempotent via `fix_fields_if_needed()`. |
| **Optimize** | `JOIN::optimize` | `transform()`, `compile()`, `walk()` | The optimizer rewrites the tree: constant folding, predicate pushdown, subquery flattening, AND/OR chain flattening, `Item_cache` insertion. |
| **Execute** | per `val_*` call | `val_int()` / `val_real()` / `val_str(String*)` / `val_decimal(my_decimal*)` / `get_date(THD*, MYSQL_TIME*, Date_mode_t)` / `val_native(THD*, Native*)` | The caller pulls the typed value; `item->null_value` is set by the call. |
| **Cleanup** | statement end | `cleanup()` (virtual, [`sql/item.h`](../item.h)) | Resets per-execution state so the next execution starts clean. **Critical for prepared statements / SPs.** |

**`fix_fields()`** (find via `grep -n 'virtual bool fix_fields' sql/item.h`) is the type-propagation pass. Override when subclassing `Item_func` only if your function needs identifier-resolution behaviour different from `Item_func::fix_fields`; for the common case, let the base class call your `fix_length_and_dec()` instead.

**`fix_length_and_dec()`** is where you set `max_length`, `decimals`, `collation`, and `maybe_null` for your subclass — called by `Item_func::fix_fields`. This is also where you call `agg_arg_charsets_*()` for string-returning functions (see §9).

**`cleanup()`** is the most common forgotten hook. Always call `Parent::cleanup()` from an override (the [`sql/CLAUDE.md`](../CLAUDE.md) §"Prepared statements & re-execution" calls this out explicitly).

---

## 4. The value-reading API

The "executor pulls" model. Find prototypes in [`sql/item.h`](../item.h) around line 1440-1700 (grep `'virtual longlong val_int'` etc.):

| Method | Returns | How to check NULL |
|---|---|---|
| `val_int()` | `longlong` | `item->null_value` set on the call |
| `val_real()` | `double` | `item->null_value` |
| `val_str(String *str)` | `String*` (NULL pointer if SQL-NULL) | also `item->null_value` |
| `val_decimal(my_decimal *dec)` | `my_decimal*` (NULL pointer if SQL-NULL) | also `item->null_value` |
| `get_date(THD*, MYSQL_TIME*, Date_mode_t)` | `bool` (TRUE on NULL or error) | also `item->null_value` |
| `val_native(THD*, Native *to)` | `bool` (TRUE on NULL or error) | also `item->null_value` |
| `val_str_ascii(String*)` | `String*` | also `item->null_value` |

Caller pattern (the *only* correct shape):

```cpp
longlong v= item->val_int();
if (item->null_value)
{
  // result was SQL-NULL
}
else
{
  // use v
}
```

**Don't read `null_value` before `val_*`.** Its value is undefined until the read happens. Don't cache a value across `val_*` calls either — items may be evaluated for many rows and `null_value` flips per row.

Each method has a "natural" variant per `Type_handler` (e.g. `Item_int::val_int` is natural; `Item_int::val_str` formats the integer). Callers usually go through whichever `val_*` matches the consumer's needs and the `Type_handler` takes care of conversion.

A `val_*_result()` variant (`val_int_result`, `val_str_result`, …) reads from the temporary-table image (`result_field`) when the item has one, rather than re-evaluating. Aggregate items use this when they've been spilled to a tmp table.

---

## 5. `Type_handler` — the type dispatch table

`Type_handler` ([`sql/sql_type.h`](../sql_type.h) line ~3917 — `grep -n 'class Type_handler\b' sql/sql_type.h`) is the single-dispatch virtual table for SQL types. One instance per (logical-type, charset-family) — see the singletons in [`sql/sql_type.cc`](../sql_type.cc) (`type_handler_slonglong`, `type_handler_double`, `type_handler_newdecimal`, `type_handler_long_blob`, `type_handler_datetime2`, `type_handler_json_longtext`, etc.).

A `Type_handler` knows:

- **In-memory representation** — which `Field` subclass to instantiate, via `make_table_field()`/`make_conversion_table_field()` (used by tmp-table creation, RBR conversion).
- **Wire / binlog encoding** — `field_type()` returns the on-wire `enum_field_types` (`MYSQL_TYPE_LONGLONG`, `MYSQL_TYPE_NEWDECIMAL`, etc.); binlog packing goes through `Type_handler::Column_definition_*` helpers.
- **Which `val_*` is "natural"** — `Item_save_in_field` (search `Type_handler::Item_save_in_field` in [`sql/sql_type.h`](../sql_type.h)) decides whether to go through `val_int`, `val_real`, `val_str`, etc., for `Item *` → `Field *` writes.
- **Comparison and aggregation rules** — `Item_eq_value`, `Item_func_min_max_get_date`, `cmp_native`, `Item_const_eq` for `=`/`MIN`/`MAX` semantics across the type.
- **String formatting / parsing** — `Column_definition_*`, `Item_print`.

Find the full surface area: `grep -n 'Type_handler::Item_' sql/sql_type.h | head -40` — the `Item_*` prefix marks "called from an `Item` virtual that delegates to me".

Per-type files plug specific behaviour in:

- [`sql/sql_type_json.cc`](../sql_type_json.cc) / [`.h`](../sql_type_json.h) — JSON.
- [`sql/sql_type_geom.cc`](../sql_type_geom.cc) / [`.h`](../sql_type_geom.h) — geometry/spatial.
- [`sql/sql_type_row.cc`](../sql_type_row.cc) / [`.h`](../sql_type_row.h) — row (`Item_row` backing handler).
- [`sql/sql_type_string.cc`](../sql_type_string.cc) / [`.h`](../sql_type_string.h) — CHAR / VARCHAR / TEXT.
- [`sql/sql_type_vector.cc`](../sql_type_vector.cc) / [`.h`](../sql_type_vector.h) — vector (11.8+).
- [`sql/sql_type_composite.cc`](../sql_type_composite.cc) / [`.h`](../sql_type_composite.h) — composite (SP record/row).
- [`sql/sql_type_fixedbin.h`](../sql_type_fixedbin.h), [`sql/sql_type_int.h`](../sql_type_int.h), [`sql/sql_type_real.h`](../sql_type_real.h), [`sql/sql_type_ref.h`](../sql_type_ref.h), [`sql/sql_type_timeofday.h`](../sql_type_timeofday.h) — header-only specialisations.

Every `Item` has `virtual const Type_handler *type_handler() const;`. When subclassing an `Item_func`, you usually inherit a default — `Item_int_func::type_handler()` returns `type_handler_slonglong`, `Item_real_func::type_handler()` returns `type_handler_double`, etc. Override only if your function returns a non-default type (e.g. a `BIGINT UNSIGNED` instead of signed `BIGINT`). The `add-sql-function.md` playbook walks through this — cross-link [`add-sql-function.md`](../../.claude/playbooks/add-sql-function.md) §"Pick the return-type family".

---

## 6. The indirect items: `Item_field`, `Item_ref`, `Item_cache`

These are the subclasses where "what the item evaluates to" lives somewhere else — a column, another item, a cache. They have outsized contribution to bugs because the indirection is easy to forget.

### `Item_field` — a column reference

[`sql/item.h`](../item.h) line ~3782 (`grep -n 'class Item_field :' sql/item.h`). Holds a `Field *field` pointer plus the table reference (`Item_ident::cached_table`). All `val_*` calls go through `field->val_*()`.

The dual-buffer model (`record[0]` / `record[1]` and the paired `Field` pointers `ptr` / `ptr_old`, `null_ptr` / `null_ptr_old`) is owned by the [`sql/CLAUDE.md`](../CLAUDE.md) §"TABLE record buffers & paired `Field` pointers" section. **Read that section before touching `Item_field`-adjacent code.** The MDEV-39179 family of bugs (UPDATE ... RETURNING OLD_VALUE — swap only one half of the pair, wrong NULL semantics) lives entirely in this interaction.

`Item_old_field` (line ~4077) is the subclass that *temporarily redirects* a `Field` to read from `record[1]`. Its `fix_fields` does the pointer swap.

### `Item_ref` — indirection by `Item **ref`

[`sql/item.h`](../item.h) line ~6183. The classic indirection: an `Item_ref` holds an `Item **ref` and delegates everything (`val_int`, `val_str`, type, fix_fields) to `*ref`. Several variants with different semantics:

| Subclass | Purpose | Key file:line |
|---|---|---|
| `Item_direct_ref` | Plain "treat me as the target" indirection. | sql/item.h ~6448 |
| `Item_direct_ref_to_ident` | Indirection that re-exposes itself as the original identifier (for `EXPLAIN`, error messages). | sql/item.h ~6504 |
| `Item_direct_view_ref` | View column. Distinct from the underlying table column for privilege checks. | sql/item.h ~6673 |
| `Item_outer_ref` | Correlated outer reference. The optimizer may decorrelate. | sql/item.h ~6916 |
| `Item_ref_null_helper` | Carries a NULL bit out of a subquery. | sql/item.h ~6981 |
| `Item_direct_ref_to_item` | Wraps any `Item *` (no `Item **`-indirection through a slot); used by window-function reordering. | sql/item.h ~8697 |

When the optimizer's `Item::transform` walks the tree, the "real" expression hides behind the ref. `Item::real_item()` ([`sql/item.h`](../item.h) ~2206; `Item_ref` overrides at ~6309) is the helper that peels the indirection. **If your transform/walk callback compares item types or rewrites by class, call `real_item()` first** — otherwise you'll silently ignore everything behind a ref.

### `Item_cache` — materialized value

[`sql/item.h`](../item.h) line ~7827 (and family at ~8017-8420). When the optimizer needs to evaluate a subtree once and reuse the result (subquery materialization, `Item_singlerow_subselect`'s cached scalar, `CASE`/`COALESCE` short-circuiting), it wraps the source in an `Item_cache`. The cache stores by underlying type:

```
Item_cache             (base)
├── Item_cache_int     → Item_cache_bool, Item_cache_year, Item_cache_temporal
│                        (and Item_cache_time / _datetime / _date subclasses)
├── Item_cache_timestamp
├── Item_cache_real    → Item_cache_double / Item_cache_float
├── Item_cache_decimal
├── Item_cache_str     → Item_cache_str_for_nullif
└── Item_cache_row
```

`Item_cache_wrapper` ([`sql/item.h`](../item.h) ~6538) is a different beast — it's used to plug a cache *into* the tree as a transparent passthrough during expression-cache rewrites.

The thing to remember: an `Item_cache` is **stale** until `cache_value()` runs. Calling `val_int` before populating returns garbage / the previous row's value. The optimizer wires up the population step via `Item_subselect::init_expr_cache_tracker` and friends.

---

## 7. `Item::transform`, `walk`, `compile` — the visitor pattern

Three flavours of tree walk live in [`sql/item.h`](../item.h) around lines 2221-2257:

| Method | Purpose | Callback signature |
|---|---|---|
| `walk(Item_processor, walk_subquery, arg)` | Read-only visit. Returns `bool` from each callback; short-circuits on first `true`. Used by analysis passes (does-this-subtree-reference-X, count-aggregates, etc.). | `bool (*Item_processor)(Item *, void *)` |
| `transform(THD*, Item_transformer, uchar *arg)` | Walk-then-rewrite. The callback returns a (possibly new) `Item*` to substitute. | `Item* (*Item_transformer)(THD*, Item*, uchar*)` |
| `compile(THD*, Item_analyzer, uchar **arg_p, Item_transformer, uchar *arg_t)` | Two-phase: analyse first (decides whether to descend); transform on the way up. The standard combinator when the rewrite is context-sensitive. | analyzer `bool*`, transformer `Item*` |

The optimizer uses these for:

- **Constant folding** — `Item_func` with all-constant args is replaced by an `Item_int` / `Item_string` / etc. via `transform`.
- **Predicate pushdown into derived tables** — see `Item::derived_field_transformer_for_where` / `_for_having` (the `*_transformer` virtuals are catalogued by `grep -n 'virtual Item \*.*transformer' sql/item.h`).
- **IN-to-EXISTS / semi-join unification** — `Item_in_subselect::transform`.
- **AND/OR flattening** — `Item_cond` collapses chains.
- **Removal of `WHERE TRUE` / `WHERE FALSE`** — `JOIN::optimize` short-circuits.

**Anti-pattern: free the old item from inside the callback.** Items are owned by their `MEM_ROOT`; freeing manually leaves dangling pointers in the parent's `args[]`. Let the MEM_ROOT reclaim them. If the rewrite must persist across re-execution, allocate the replacement on `thd->stmt_arena->mem_root`, not `thd->mem_root` (see §8).

**Anti-pattern: ignore `Item_ref` in the visitor.** Call `real_item()` before pattern-matching, or override the relevant virtual on `Item_ref` so the walk descends through.

---

## 8. Prepared-statement re-execution

The single most error-prone area when working on Items. The rules (allocate on the right arena, never leave dangling pointers, preserve the original tree, cover with PS/SP test variants) are in [`sql/CLAUDE.md`](../CLAUDE.md) §"Prepared statements & re-execution" — read that for the do/don't list.

Here, the **mechanism**:

1. **Prepare** parses the statement and runs `fix_fields()` on its item tree. Items are allocated on `thd->stmt_arena->mem_root` so they survive between executions. Entry point: `mysql_stmt_prepare` / `Prepared_statement::prepare` in [`sql/sql_prepare.cc`](../sql_prepare.cc).
2. **Execute (first time)** may rewrite the tree as part of `JOIN::optimize` — constant folding, predicate pushdown, semi-join conversion. Each rewrite goes through `Item::transform`. *Where* the replacement gets allocated determines whether it survives:
   - On `thd->stmt_arena->mem_root` (when `thd->mem_root == thd->stmt_arena->mem_root`, which is true during prepare and via `Query_arena_stmt`) → survives, becomes part of the cached plan.
   - On a plain `thd->mem_root` → freed at statement end, must be reset by `cleanup()`.
3. **`cleanup()`** runs at statement end. Per-execution scratch state (cached `null_value`, expanded references, decorrelation-time substitutions that depend on dynamic parameters) must be reset here. Failure to do so → second execution reads stale state.
4. **`PROTECT_STATEMENT_MEMROOT`** (`CMAKE_BUILD_TYPE=Debug` only — references in [`sql/sp_head.cc`](../sp_head.cc), [`sql/sp_instr.cc`](../sp_instr.cc)) asserts on writes to the statement arena from outside the prepare phase. That's the canary debug builds use to catch a forgotten arena switch.

**`shallow_copy()`** ([`sql/item.h`](../item.h) ~2859, the pure virtual; ~1919 for the `shallow_copy_with_checks` wrapper) is the optimizer's clone hook. When the optimizer needs to duplicate a subtree (for example, when distributing a predicate across an `OR`-chain or splitting a derived table), it calls `shallow_copy_with_checks(thd)`. **Missing `shallow_copy()` on a new `Item_func` subclass → crash on re-execution after the optimizer transforms the tree.** Copy-paste from a sibling subclass; the standard shape is

```cpp
Item *shallow_copy(THD *thd) const override
{ return get_item_copy<Item_func_yours>(thd, this); }
```

(see [`sql/item.h`](../item.h) at the `get_item_copy` helper). See [`sql/CLAUDE.md`](../CLAUDE.md) §"Prepared statements & re-execution" for the wider rule set.

**Bug families to recognise:**

- "Forgot `shallow_copy()` → crash on re-execution after the optimizer cloned the item." Symptom: passes once, crashes on the second `EXECUTE` of the same `PREPARE`.
- "Forgot to reset cached `null_value` / accumulated state in `cleanup()` → stale NULL bit or wrong result on second execution." Item_func_trim (MDEV-32758 / PR4883, cited in [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Lifetime / ownership") was a buffer-aliasing variant of this family.
- "Allocated a transformation result on `thd->mem_root` instead of `thd->stmt_arena->mem_root` → second execution finds freed memory." `PROTECT_STATEMENT_MEMROOT` catches the inverse (writes from outside prepare); the freed-memory case usually shows up as ASAN use-after-free under MTR's `--mem` runs.

---

## 9. Charset / collation propagation through Items

A common review-rejection source. Items that return strings carry a `DTCollation collation` member ([`sql/sql_type.h`](../sql_type.h) ~3163). The result collation is *not* implicitly inherited from a single argument — it must be **aggregated** across all string-returning children, with coercibility rules deciding when a coercion is forced.

Helper functions on `Item_func` (via `Item_args`):

| Helper | Use for |
|---|---|
| `agg_arg_charsets_for_string_result(collation, items, n)` | String-returning function whose result charset is derived from its string args. (`CONCAT`, `LOWER`, …) |
| `agg_arg_charsets_for_comparison(collation, items, n)` | Comparison whose operands must share a comparison charset. (`=`, `<`, `LIKE` collation derivation.) |
| `agg_arg_charsets_for_string_result_with_comparison(collation, items, n)` | String-returning with embedded comparison. (`REPLACE`, `IF` on strings, `INSERT` (the function), `CASE`-on-strings.) |
| `agg_arg_charsets(collation, items, n, flags, item_sep)` | The generic primitive. |

Find usage examples: `grep -n 'agg_arg_charsets_for_string_result' sql/item_strfunc.cc` — every string-result `fix_length_and_dec()` calls one of these and returns `true` on failure (which is the "incompatible collations" error path).

**Forgetting this call in a string-returning function is a standard rejection.** The reviewer rule (cite [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Charset / collation"): InnoDB raw `my_charset_filename` bytes are not UTF-8 — convert to `system_charset_info` before printing identifier-bearing messages, and test with non-ASCII. PR4342.

Index/identifier name comparisons must be charset-aware (PR4906): use `my_charset_utf8_bin` cmp or the in-tree `cmp` helper, not raw `strcmp`.

---

## 10. NULL handling: `null_value` vs `maybe_null`

Two distinct concepts, both on every `Item`:

| | `maybe_null` | `null_value` |
|---|---|---|
| Set by | `fix_length_and_dec()` (or `set_maybe_null()` — see [`sql/item.h`](../item.h) ~1331) | `val_int()` / `val_real()` / `val_str()` / `val_decimal()` / `get_date()` / `val_native()` |
| Read by | The optimizer (to elide null-checks, derive output column nullability, `IS [NOT] NULL` rewrite) | The caller, immediately after each `val_*` |
| Semantics | **Static.** "Can this item ever return NULL given its current arg shape?" | **Dynamic.** "Did this particular evaluation return NULL?" |
| Test it via | `item->maybe_null()` ([`sql/item.h`](../item.h) ~1062) | `item->null_value` ([`sql/item.h`](../item.h) ~1047, a public `bool`) |

**Rules:**

- Set `maybe_null` **conservatively** — if any argument can be NULL and the function is "NULL-propagating" (`NULL → NULL`), the result `maybe_null` is true. `Item_args::is_any_arg_maybe_null()` ([`sql/item.h`](../item.h) ~2929) is the helper.
- Propagate `null_value` **from every argument that can be NULL.** Pattern in a `val_*` implementation:

  ```cpp
  longlong x= args[0]->val_int();
  if ((null_value= args[0]->null_value))
    return 0;
  longlong y= args[1]->val_int();
  if ((null_value= args[1]->null_value))
    return 0;
  return x + y;
  ```

  The `null_value=` assignment-in-condition idiom is canonical — server style permits it (see [`.claude/review/coding-style.md`](../../.claude/review/coding-style.md)).
- Never leave `null_value` set from a previous call when returning a non-NULL result; clear it.

The MDEV-39179 bug family is a NULL-handling family disguised as a `Field`-pointer swap: half-swap (`ptr` but not `null_ptr`) reads the OLD row's bytes through the NEW row's null bit. See [`sql/CLAUDE.md`](../CLAUDE.md) §"TABLE record buffers" for the full story and the corrective test pattern (nullable column, both transition directions, prepared-statement variant).

---

## 11. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) — parent map, cluster table, base-class picker, the PS re-execution rules, TABLE record buffers (the `Item_field` interaction).
- [`.claude/playbooks/add-sql-function.md`](../../.claude/playbooks/add-sql-function.md) — procedural side: file-by-file walkthrough for adding a new `Item_func_*`.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) — §"NULL handling", §"Charset / collation", §"Lifetime / ownership".
- [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) — §"Where features live", §"API design discipline".
- [`.claude/review/coding-style.md`](../../.claude/review/coding-style.md) — assignment-in-condition idiom, pointer-asterisk placement, naming.
- Related references:
  - [`sql/docs/optimizer.md`](optimizer.md) — `JOIN::optimize`'s use of `Item::transform`, where each rewrite phase lives, materialization strategy.
  - [`sql/docs/parser.md`](parser.md) — where Items are *constructed* in `sql_yacc.yy` and via the `item_create.cc` factory.
- Related references:
  - [`sql/docs/charset-and-collation.md`](charset-and-collation.md) — `CHARSET_INFO`, the `String` class, collation derivation in depth.
  - [`.claude/reference/memory-management.md`](../../.claude/reference/memory-management.md) — MEM_ROOT arenas, `alloc_root`, the stmt-arena lifetime in detail.

---

## 12. How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `5b6d020d1fe` (branch `main`).
- **Files surveyed:**
  - [`sql/item.h`](../item.h) (~9000 lines) — base class, `Item_ident`, `Item_field`, `Item_ref` family, `Item_cache` family, `Item_copy`, `Item_param`, value-method prototypes, visitor methods, `shallow_copy`.
  - [`sql/item_func.h`](../item_func.h) — `Item_func`, `Item_int_func`, `Item_real_func`, `Item_func_hybrid_field_type`, `Item_func_numhybrid`, the arithmetic/typecast tree.
  - [`sql/item_strfunc.h`](../item_strfunc.h) — `Item_str_func`, `Item_str_ascii_func`, `Item_str_ascii_checksum_func` (the base classes referenced from the cluster table).
  - [`sql/item_sum.h`](../item_sum.h), [`sql/item_cmpfunc.h`](../item_cmpfunc.h), [`sql/item_subselect.h`](../item_subselect.h), [`sql/item_row.h`](../item_row.h) — for the cross-family hierarchy table.
  - [`sql/sql_type.h`](../sql_type.h) — `Type_handler` base class, `DTCollation`, `Type_handler_*` family, the `Item_*` virtual surface.
  - [`sql/item_strfunc.cc`](../item_strfunc.cc) — for real call-sites of `agg_arg_charsets_for_string_result*`.
  - [`sql/CLAUDE.md`](../CLAUDE.md) — for the cluster table and base-class picker that this doc deliberately does *not* duplicate.
  - [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md), [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) — for citation-worthy review rules touching Items.
- **Commands used to confirm structure:**
  - `grep -n '^class Item' sql/item.h sql/item_func.h sql/item_strfunc.h sql/item_sum.h sql/item_cmpfunc.h sql/item_subselect.h sql/item_row.h`
  - `grep -n '^class Type_handler' sql/sql_type.h`
  - `grep -n 'Type_handler::Item_' sql/sql_type.h`
  - `grep -n 'shallow_copy\|get_copy' sql/item.h`
  - `grep -n 'agg_arg_charsets' sql/item.h sql/item_func.h sql/item_strfunc.cc`
  - `grep -n 'PROTECT_STATEMENT_MEMROOT' sql/*.cc`
- **Deliberately excluded:**
  - Line numbers as primary references — they drift. Cited file-and-feature (with grep recipe) instead.
  - File-by-file paraphrase of every `Item_func_*` subclass — that's [`sql/CLAUDE.md`](../CLAUDE.md)'s cluster table.
  - "How to add a new SQL function" — that's [`add-sql-function.md`](../../.claude/playbooks/add-sql-function.md).
  - Optimizer-phase ordering (where `transform` is called *from*) — covered in [`sql/docs/optimizer.md`](optimizer.md).
  - Parser construction of items (where `new (thd->mem_root) Item_func_*` happens) — covered in [`sql/docs/parser.md`](parser.md).
  - `String`/`CHARSET_INFO`/`my_charset_*` deep dive — covered in [`sql/docs/charset-and-collation.md`](charset-and-collation.md).
- **Refresh procedure:**
  - When a new `Item_*` family lands (new `sql/item_*.h`, new `Item_cache_*`, new `Type_handler_*`), update the §2 grep recipes and the §6 sub-section if the new family is "indirect".
  - When a review-rulebook section moves or a new MDEV pitfall lands touching Items, update the §9/§10 citations.
  - Re-walk the §3 lifecycle table against any new `fix_fields_if_needed_for_*` variants that show up in [`sql/item.h`](../item.h) ~1148-1168.
  - Bump `last-verified` to the walk-through date.
