---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/sql_select.cc, sql/opt_*.cc, sql/sql_explain.cc
---

# Reference: the query optimizer

Deep dive on the optimizer and executor: how a parsed `SELECT_LEX` becomes a sequence of `JOIN_TAB`s with chosen access methods, where each transformation lives, and what file to open first for each bug shape. The high-level map of `opt_*.cc` files lives in [`sql/CLAUDE.md`](../CLAUDE.md) §"Optimizer & executor" — read that first; this doc goes inside.

For the expression-tree machinery the optimizer manipulates (`Item::transform`, `walk`, `compile`, the visitor pattern), see [`sql/docs/item-system.md`](item-system.md). For what produces the `LEX`/`SELECT_LEX` the optimizer consumes, see [`sql/docs/parser.md`](parser.md).

---

## 1. TL;DR

- **Entry is `JOIN::prepare` → `JOIN::optimize` → `JOIN::exec`** in [`sql/sql_select.cc`](../sql_select.cc). That file is ~35 000 lines; phase boundaries are clear if you know where to grep (`grep -nE '^(int|bool|void) JOIN::' sql/sql_select.cc`).
- **Distinct optimizations live in their own `opt_*.cc` files** — range ([`opt_range.cc`](../opt_range.cc)), subquery flattening ([`opt_subselect.cc`](../opt_subselect.cc)), table elimination ([`opt_table_elimination.cc`](../opt_table_elimination.cc)), histograms ([`opt_histogram_json.cc`](../opt_histogram_json.cc)), hints ([`opt_hints.cc`](../opt_hints.cc)), split materialization ([`opt_split.cc`](../opt_split.cc)), GROUP BY cardinality ([`opt_group_by_cardinality.cc`](../opt_group_by_cardinality.cc)).
- **The executor shape is a `JOIN_TAB` chain** — one per table in the chosen join order. The optimizer's job is to choose (a) the order, (b) the per-table access method, (c) the materialization strategy for any subqueries.
- **`EXPLAIN` / `EXPLAIN FORMAT=JSON` / `ANALYZE` output** is produced in [`sql/sql_explain.cc`](../sql_explain.cc) from `Explain_*` data structures the optimizer populates as it makes decisions.
- **Most optimizer bugs are Item-rewrite bugs** — constant folding that breaks prepared-statement re-execution, predicate pushdown that loses NULL-extended row semantics, semi-join transforms that drop a needed filter. The rest are cost-estimation bugs. See §10 for entry points per bug shape.

---

## 2. Phase ordering — from parse to result

Sequential trace, with grep-recipes instead of line numbers (line numbers drift; method names don't).

### 2.1 Parse

The grammar in [`sql_yacc.yy`](../sql_yacc.yy) builds a `LEX` containing one or more `SELECT_LEX` blocks. At this point `Item`s are unresolved — identifiers haven't been bound to `Field*`, types haven't been propagated. See [`sql/docs/parser.md`](parser.md).

### 2.2 Dispatch

[`sql/sql_parse.cc`](../sql_parse.cc)::`mysql_execute_command` dispatches on `LEX::sql_command`. For `SQLCOM_SELECT`, control reaches `mysql_select()` (a thin wrapper) which calls into `JOIN::prepare` and then `JOIN::optimize`/`JOIN::exec`.

### 2.3 `JOIN::prepare`

```sh
grep -n '^JOIN::prepare\b\|^JOIN::prepare(' sql/sql_select.cc
```

Calls `setup_fields` for the select list / WHERE / ORDER BY / GROUP BY, which in turn calls `Item::fix_fields` on every `Item` in the tree. After `prepare` returns: every `Item` is `fixed()`, type / charset / nullability are propagated, identifiers are bound. See [`sql/docs/item-system.md`](item-system.md) §"The `Item` lifecycle".

For prepared statements and stored programs, `JOIN::prepare` runs **once** and is followed by `JOIN::optimize` on every execution — see §11.

### 2.4 `JOIN::optimize` → `JOIN::optimize_inner`

```sh
grep -n '^int JOIN::optimize\b\|^JOIN::optimize_inner\|^int JOIN::optimize_stage2' sql/sql_select.cc
```

The big switchboard. `JOIN::optimize()` is a thin shell around `optimize_inner()`, which calls `optimize_stage2()` after the bulk of work is done. Substeps, in roughly the order they fire (find them with `grep -n 'JOIN::optimize_\|JOIN::optimize\b' sql/sql_select.cc` plus the per-area files):

| Substep | Where | What |
|---|---|---|
| Constant-table detection | `optimize_inner` | Tables joined on PK = const get pulled out of the join. |
| WHERE normalization | `optimize_inner` (`Item_cond` flattening) | AND/OR chains flatten; tautologies/contradictions removed. |
| Equality propagation | `substitute_for_best_equal_field` | `t1.a = t2.b AND t1.a = 5 ⇒ t2.b = 5`. |
| Subquery flattening | [`opt_subselect.cc`](../opt_subselect.cc)::`convert_join_subqueries_to_semijoins` | `IN (SELECT…)`/`EXISTS (SELECT…)` → semi-join or materialization. See §5. |
| Derived-table merging | [`sql/sql_derived.cc`](../sql_derived.cc)::`mysql_handle_derived` | `FROM (SELECT…)` inlined when possible. See §6. |
| Table elimination | [`opt_table_elimination.cc`](../opt_table_elimination.cc) | Drop LEFT-JOINed tables no column of which is referenced. |
| Join-order selection | `best_extension_by_limited_search` (in `sql_select.cc`) | Cost-driven greedy / exhaustive plan search. |
| Access-method choice | [`opt_range.cc`](../opt_range.cc)::`SQL_SELECT::test_quick_select` | Per-table: ref, range, index-merge, ROR intersect, loose scan. See §4. |
| Statistics-driven costing | [`opt_histogram_json.cc`](../opt_histogram_json.cc) + engine `scan_time`/`keyread_time` | Histograms refine selectivity. See §8. |
| Hint application | [`opt_hints.cc`](../opt_hints.cc) | `/*+ … */` directives override cost-based picks. See §7. |
| GROUP BY / ORDER BY cardinality | [`opt_group_by_cardinality.cc`](../opt_group_by_cardinality.cc), `JOIN::optimize_distinct` | Decide loose index scan / tmp table / filesort. |
| Split materialization | [`opt_split.cc`](../opt_split.cc) | Push outer values into derived materialization. |

Don't paraphrase 7 000 lines — point at the file:method and read the source.

### 2.5 `JOIN::exec`

```sh
grep -n '^int JOIN::exec\b\|^int JOIN::exec_inner' sql/sql_select.cc
```

Walks the `JOIN_TAB` chain. Per row from the leftmost table: try every subsequent `JOIN_TAB` (`sub_select` / `evaluate_join_record`), apply `select_cond` (pushed-down WHERE), evaluate `HAVING`, emit rows. Aggregation / DISTINCT / ORDER BY are layered on top via post-join tabs (`JOIN::make_aggr_tables_info`, `Filesort` from [`filesort.cc`](../filesort.cc), dedupe from [`uniques.cc`](../uniques.cc)).

For `EXPLAIN`/`ANALYZE`, `JOIN::save_explain_data` runs instead of (or alongside) `exec` — see §9.

---

## 3. The `JOIN` / `JOIN_TAB` / `SELECT_LEX` triangle

The three core data structures and how they relate:

| Type | What it represents | Key fields |
|---|---|---|
| `SELECT_LEX` (in [`sql/sql_lex.h`](../sql_lex.h)) | One SELECT block in the parse tree | `item_list`, `where`, `group_list`, `order_list`, child blocks (`first_inner_unit`), `join` (back-pointer to its JOIN). |
| `JOIN` (in [`sql/sql_select.h`](../sql_select.h)) | The optimization + execution plan for ONE `SELECT_LEX` | `join_tab` array, `table_count`, `tables_list`, `conds` (WHERE), `having`, `best_positions`, `select_lex` (back-pointer). |
| `JOIN_TAB` (`struct st_join_table` in [`sql/sql_select.h`](../sql_select.h)) | One position in the join sequence — one table + how to access it | `table`, `ref` (eq-ref / ref access method), `select_cond` (pushed-down WHERE), `select` / `quick` (range plan), `first_inner`/`last_inner` (LEFT JOIN nesting), `next_select` (executor callback). |

A query with N base tables produces a `JOIN` with an array of N `JOIN_TAB`s in chosen join order. A query with subqueries / unions produces nested `SELECT_LEX`s, each owning its own `JOIN`.

`POSITION` (also in `sql_select.h`) is the *candidate* form of a `JOIN_TAB` used during plan search — `best_positions[i]` is the chosen entry for slot `i`, copied into `join_tab[i]` once the plan is committed.

---

## 4. Range optimizer ([`opt_range.cc`](../opt_range.cc), [`opt_range.h`](../opt_range.h))

The brains of "should we use an index range scan, and which?". Inputs: WHERE clause + per-table indexes. Output: a `QUICK_SELECT_I` (or NULL = full scan) describing the chosen plan.

Key entry: `SQL_SELECT::test_quick_select`. Read it once end-to-end to internalise the structure — it constructs a `SEL_TREE` from the WHERE, then asks each candidate strategy to estimate its cost.

### Intermediate AST in index-key space

- **`SEL_ARG`** — one node in a per-index range tree. Represents a range over one key part, with `left`/`right`/`next_key_part` links forming a 4-D tree (one dimension per key part).
- **`SEL_TREE`** — per-table set of `SEL_ARG`s, one per candidate index, plus index-merge alternatives.

WHERE rewrite ⇒ `SEL_TREE` ⇒ `QUICK_*` is the data-flow.

### `QUICK_*` variants

| Class | Strategy |
|---|---|
| `QUICK_RANGE_SELECT` | Single index range scan. |
| `QUICK_INDEX_MERGE_SELECT` | Sort-union of multiple per-index ranges (rowid-sort, then dedupe). |
| `QUICK_INDEX_INTERSECT_SELECT` | Sort-intersect of multiple per-index ranges. |
| `QUICK_ROR_INTERSECT_SELECT` | Rowid-ordered intersect (rows come out already sorted by rowid — no temp file). Requires clustered PK or compatible engine ordering. |
| `QUICK_ROR_UNION_SELECT` | Rowid-ordered union. |
| `QUICK_GROUP_MIN_MAX_SELECT` | Loose index scan for `GROUP BY` + MIN/MAX. |
| `QUICK_SELECT_DESC` | Reverse-direction range scan (for `ORDER BY … DESC`). |

Recent MDEVs that exercised this corner: MDEV-38649 / MDEV-38921 / MDEV-38934 (range w/o min/max endpoint + reverse scan / ICP) — find via `git log --oneline -- sql/opt_range.cc | head -10`. They're the canonical "wrong result from a range scan" shape.

---

## 5. Subquery flattening ([`opt_subselect.cc`](../opt_subselect.cc))

`IN (SELECT …)` and `EXISTS (SELECT …)` get rewritten into **semi-joins** when possible (the inner side becomes additional tables in the outer JOIN). When not possible, **materialization** is the fallback (the inner side runs once, results land in a temp table, the outer predicate becomes a lookup).

Main entries (`grep -n '^bool \|^int ' sql/opt_subselect.cc | head -30`):

- `check_and_do_in_subquery_rewrites` — initial decision in `JOIN::prepare`/early `optimize`.
- `convert_join_subqueries_to_semijoins` — the actual semi-join conversion pass during `JOIN::optimize`.
- `setup_jtbm_semi_joins` — wires up the converted predicate into the join.

### Semi-join execution strategies

Picked per-subquery by the planner via the `Semi_join_strategy_picker` family in [`sql/sql_select.h`](../sql_select.h):

| Strategy | Picker class | When it wins |
|---|---|---|
| **DuplicateWeedout** | `Duplicate_weedout_picker` | Run as a normal join; rowid-dedupe outer rows at the end. Most general, often the fallback. |
| **FirstMatch** | `Firstmatch_picker` | Stop scanning the inner side at the first match per outer row. Wins when the inner side has many matches but only existence matters. |
| **LooseScan** | `LooseScan_picker` | Exploit an indexed inner side: scan the index once, skipping duplicates. |
| **Materialization** | `Sj_materialization_picker` | Build a uniqued temp table from the inner side; turn the outer predicate into a hash lookup. |

Bugs in this area typically have one of three shapes:
- **NULL semantics lost** across the transform — `IN (NULL)` should be NULL, not FALSE; semi-join doesn't preserve that for free.
- **Empty inner side** — the rewritten predicate must still evaluate correctly when the inner SELECT produces zero rows.
- **Hint targeting lost** — `IGNORE INDEX` / `USE INDEX` / `/*+ NO_RANGE_OPTIMIZATION(...) */` on the inner side must survive the rewrite.

See `git log --oneline -- sql/opt_subselect.cc` for the recent commit cadence and example MDEVs.

---

## 6. Derived-table merging ([`sql/sql_derived.cc`](../sql_derived.cc))

When a `FROM (SELECT …) AS d` can be inlined into the outer query, the optimizer avoids the materialization round-trip. `mysql_handle_derived` is the entry point; it runs in phases (`DT_*` flags) interleaved with `JOIN::optimize`.

Mergeability rules (negative list — any one fails ⇒ materialize):
- No aggregates / `DISTINCT` / `GROUP BY` / `HAVING`.
- No `LIMIT` / `OFFSET`.
- No `UNION` (use `derived-with-keys` for some UNION shapes).
- No subqueries in the select list.
- Inner SELECT must not be a recursive CTE seed.

Non-mergeable derived tables get materialized via `select_unit::create_result_table` and are surfaced to the outer JOIN as a temp `TABLE` with auto-generated keys (`drop_unused_derived_keys` later prunes unused ones).

Common bug surfaces (cite `git log --oneline -- sql/sql_derived.cc sql/sql_cte.cc | head -15`):
- Identifier resolution leaking the merged view's scope (e.g. MDEV-38272 family).
- Security-context propagation from the view's definer to the merged predicate.
- Unused-derived-key pruning over-eager (filesort regressions, e.g. MDEV-38877).

---

## 7. Hints ([`opt_hints.{cc,h}`](../opt_hints.cc), [`opt_hints_parser.cc`](../opt_hints_parser.cc))

`/*+ HINT_NAME(args) */` comments parsed by [`opt_hints_parser.cc`](../opt_hints_parser.cc) — a separate recursive-descent parser, **not** part of the bison grammar (see [`sql/docs/parser.md`](parser.md) §"Optimizer hints"). The result is an `Opt_hints` tree (`Opt_hints_global` → `Opt_hints_qb` (per query block) → `Opt_hints_table` → `Opt_hints_key`).

Hints are applied during `JOIN::optimize` at the points where a hint can override a default (join order, access method choice, semi-join strategy, merge/no-merge of a derived table, etc.). Each `Opt_hints` object carries a "specified" mask and a "switched on" mask.

Recent example: MDEV-38045 added implicit query-block names and the `QB_NAME(@qb_name)` path syntax. MDEV-39304 fixed `QB_NAME` being silently ignored inside view definitions. Find via:

```sh
git log --oneline -- sql/opt_hints*.cc | head -10
```

When adding a new hint:
1. Add a parser rule in `opt_hints_parser.cc`.
2. Add an enum value + storage slot in `Opt_hints_map` / the relevant `Opt_hints_*` subclass.
3. Add the apply-site in the optimizer phase the hint targets.
4. Cover both "hint accepted, has effect" and "hint accepted, no-op because impossible" paths in MTR tests.

---

## 8. Cost and statistics

Two flavours of stats feed the cost model:

- **In-memory** estimates from `TABLE::file->stats` (cardinality, index distribution, average row size). Engines fill these on table-open and refresh on `ANALYZE TABLE`.
- **Persistent** stats — `mysql.innodb_table_stats` / `mysql.innodb_index_stats` for InnoDB; analogous mechanisms for other engines via the `engine-independent statistics` framework (`mysql.column_stats` / `mysql.index_stats` / `mysql.table_stats`).

**Histograms** in [`opt_histogram_json.cc`](../opt_histogram_json.cc) supplement uniform-distribution assumptions with column-level distribution data. Loaded from `mysql.column_stats` when `use_stat_tables=PREFERABLY` and a histogram is present.

The cost model layers:
- Engine-supplied per-row / per-block costs via `handler::scan_time()`, `handler::keyread_time()`, `handler::key_scan_time()` virtuals in [`sql/handler.h`](../handler.h) (`grep -n 'scan_time\|keyread_time' sql/handler.h`).
- SQL-layer constants in [`sql/sql_const.h`](../sql_const.h) and the `optimizer_*` system variables (`optimizer_disk_read_cost`, `optimizer_key_compare_cost`, etc.) for fine-grained tuning.
- Per-plan accumulators in `POSITION::cost` / `JOIN::best_read`.

When debugging "wrong join order chosen", enable the optimizer trace (`SET optimizer_trace='enabled=on'`; results in `INFORMATION_SCHEMA.OPTIMIZER_TRACE`) and inspect the cost numbers per `best_extension_by_limited_search` step. The trace is built in [`opt_trace.cc`](../opt_trace.cc).

---

## 9. `EXPLAIN` and `ANALYZE` ([`sql/sql_explain.{cc,h}`](../sql_explain.cc))

`EXPLAIN` does not rerun the optimizer — it runs the optimizer once and prints the resulting plan. `JOIN::save_explain_data` populates `Explain_*` objects from the chosen plan; the printer methods produce the user-visible output.

The `Explain_*` class hierarchy (`grep -n '^class Explain_' sql/sql_explain.h`):

- `Explain_node` (base) — one row / one sub-plan.
- `Explain_select`, `Explain_union` — query-block-level.
- `Explain_basic_join` — a join (one per SELECT_LEX).
- `Explain_table_access` — per-`JOIN_TAB` access info (index, rows, filtered, extra).
- `Explain_quick_select`, `Explain_index_use`, `Explain_rowid_filter`, `Explain_range_checked_fer` — range / index details.
- `Explain_aggr_filesort`, `Explain_aggr_tmp_table`, `Explain_aggr_remove_dups`, `Explain_aggr_window_funcs` — post-join steps.
- `Explain_subq_materialization` — materialized subquery detail.
- `Explain_update`, `Explain_delete`, `Explain_insert` — DML variants.

Formats:
- **Default `EXPLAIN`** — tabular text output (the classic 12-column shape).
- **`EXPLAIN FORMAT=JSON`** — same data, JSON tree (printed via `Json_writer`).
- **`ANALYZE`** — runs the query AND prints, with real `r_rows` / `r_filtered` / `r_total_time_ms` measured during execution (kept in `Filesort_tracker` / `Exec_time_tracker`-style structs on each plan node).

When adding a new EXPLAIN field: edit the relevant `Explain_*` class in `sql_explain.h` (storage), populate it in `JOIN::save_explain_data_intern` (in `sql_select.cc`) or per-engine pushdown helpers, and update **all** print methods in `sql_explain.cc` (tabular printer + JSON writer + ANALYZE printer). A field added to JSON-only but not tabular is a common review reject.

---

## 10. Where common bug categories land

For an agent dropping into optimizer code with a bug report — "what file owns this concern?":

| Bug shape | First file:method to open |
|---|---|
| Query returns wrong row count | `sql_select.cc::JOIN::optimize_inner` — was a predicate pushed down past a LEFT JOIN? If a subquery was flattened, also `opt_subselect.cc::convert_join_subqueries_to_semijoins`. |
| Wrong join order chosen | `sql_select.cc::best_extension_by_limited_search`. Compare costs in `EXPLAIN FORMAT=JSON` / optimizer trace. |
| Range scan chose wrong index | `opt_range.cc::SQL_SELECT::test_quick_select`. Print the `SEL_TREE` (`DBUG_EXECUTE("range_alloc", print_sel_tree(...))`) and look at which `QUICK_*` won. |
| Subquery materialization regression | `opt_subselect.cc` — check which `Semi_join_strategy_picker` was selected. |
| EXPLAIN missing a row / format key | `sql_explain.cc` printers — tabular vs JSON vs ANALYZE must stay in sync. |
| Hint accepted but ignored | `opt_hints.cc::Opt_hints::resolve` and the apply-site for the specific hint family. |
| `ORDER BY ... LIMIT` ignored / extra filesort | `filesort.cc`, `sql_select.cc::JOIN::optimize_distinct`, `test_if_skip_sort_order`. |
| Derived table not merged | `sql_derived.cc::mysql_handle_derived`. Check the mergeability negative list (§6). |
| Wrong result with ICP / reverse scan | `opt_range.cc` (recent MDEV-38649/38921/38934 family); index-condition-pushdown in `opt_index_cond_pushdown.cc`. |
| MIN/MAX returns wrong value | `opt_sum.cc` (constant-MIN/MAX optimization) and the loose-index-scan path. |
| Histogram-related selectivity off | `opt_histogram_json.cc`, recent MDEV-38273 family. |

---

## 11. Pitfalls and review patterns

The recurring failure modes when changing optimizer code. Cite real PRs / MDEVs.

- **Predicate pushdown over LEFT JOIN that loses NULL-extended semantics.** A WHERE that filters the right side of a LEFT JOIN can be safely pushed into the right table only if it rejects NULL — otherwise the LEFT JOIN becomes an effective INNER JOIN. See [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"NULL handling".
- **Const-folding that confuses prepared-statement re-execution.** The folded constant must allocate on `thd->stmt_arena->mem_root` (not `thd->mem_root`); otherwise on the second execution the prior arena has been freed and the substituted `Item_int` points at garbage. See [`sql/docs/item-system.md`](item-system.md) §"Prepared-statement re-execution".
- **`Item::transform` that mutates instead of copying.** `transform()` returns a (possibly new) `Item*` — the caller must replace the slot in the parent. In-place mutation of a shared subtree corrupts every other reference to it. See [`sql/docs/item-system.md`](item-system.md) §"`Item::transform`, `walk`, `compile` — the visitor pattern".
- **New EXPLAIN field landed in JSON only.** Tabular `EXPLAIN`, `EXPLAIN FORMAT=JSON`, and `ANALYZE` all share `Explain_*` storage but have separate printers — keep them in sync. See §9.
- **Optimizer crashes on empty subquery.** Usually a missing NULL check on the rewritten predicate when the inner SELECT produces zero rows (the `Item_singlerow_subselect` value stays unset; `null_value` must be checked).
- **Subquery transform drops `IGNORE INDEX` / hint targeting.** Hints on the inner side of an `IN` subquery must be preserved across semi-join conversion — check `Opt_hints_qb` linkage after the rewrite.
- **Range scan with no min or max endpoint plus reverse direction.** Repeatedly fragile in `QUICK_SELECT_DESC` + ICP combinations — see MDEV-38649 / MDEV-38921 / MDEV-38934. Any change to `opt_range.cc` reverse-scan code needs reverse-direction + ICP + range-without-endpoint coverage.
- **Cost model edits that don't account for engine-supplied costs.** `handler::scan_time()` / `keyread_time()` are virtual and return engine-specific numbers — comparing them across engines without normalising is a classic regression source.
- **Plan-search heuristic changes without `--big-test` coverage.** `best_extension_by_limited_search` is exponential in the worst case; pruning changes need workloads with 10+ table joins, which only `--big-test` MTR cases exercise.

---

## 12. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) §"Optimizer & executor" — the canonical file-cluster table.
- [`sql/docs/item-system.md`](item-system.md) — `Item::transform`, `walk`, `compile`, and the visitor pattern used by every optimizer rewrite pass; prepared-statement re-execution rules.
- [`sql/docs/parser.md`](parser.md) — what produces the `LEX` / `SELECT_LEX` the optimizer consumes; the separate `opt_hints_parser.cc` for hints.
- [`.claude/playbooks/add-sql-function.md`](../../.claude/playbooks/add-sql-function.md) — most new SQL function work interacts with the optimizer indirectly via `Item::transform` and `Item::const_item()`.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) — NULL handling, lifetime / ownership.
- [`.claude/review/testing.md`](../../.claude/review/testing.md) — PS/SP variant requirement; `--big-test` join-search coverage.
- Forward references (not yet written):
  - `sql/docs/replication.md` (Phase 4) — binlog row-image format and how it interacts with optimized DML.
  - `.claude/reference/debug-tooling.md` (Phase 5) — `--debug=d,info` / optimizer trace / DBUG keywords for tracing optimizer decisions.

---

## 13. How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `a662a237b48` (branch `main`).
- **Files surveyed:**
  - [`sql/sql_select.cc`](../sql_select.cc) (~35 080 lines) — method index via `grep -nE '^(int|bool|void) JOIN::' sql/sql_select.cc`; phase boundaries (`prepare`, `optimize`, `optimize_inner`, `optimize_stage2`, `exec`, `exec_inner`).
  - [`sql/sql_select.h`](../sql_select.h) — `JOIN_TAB` (`typedef struct st_join_table`), `JOIN`, `POSITION`, `Semi_join_strategy_picker` + four picker subclasses.
  - [`sql/opt_range.{cc,h}`](../opt_range.cc) — `SEL_ARG`, `SEL_TREE`, `QUICK_*` family, `SQL_SELECT::test_quick_select`.
  - [`sql/opt_subselect.cc`](../opt_subselect.cc) — `convert_join_subqueries_to_semijoins`, `check_and_do_in_subquery_rewrites`, `setup_jtbm_semi_joins`.
  - [`sql/opt_hints.h`](../opt_hints.h), [`sql/opt_hints_parser.cc`](../opt_hints_parser.cc) — `Opt_hints` tree shape.
  - [`sql/opt_histogram_json.cc`](../opt_histogram_json.cc), [`sql/opt_table_elimination.cc`](../opt_table_elimination.cc), [`sql/opt_split.cc`](../opt_split.cc), [`sql/opt_group_by_cardinality.cc`](../opt_group_by_cardinality.cc), [`sql/opt_index_cond_pushdown.cc`](../opt_index_cond_pushdown.cc), [`sql/opt_sum.cc`](../opt_sum.cc), [`sql/opt_trace.cc`](../opt_trace.cc) — file roles only.
  - [`sql/sql_explain.h`](../sql_explain.h) — `Explain_*` class list via `grep -n '^class Explain_' sql/sql_explain.h`.
  - [`sql/sql_derived.cc`](../sql_derived.cc) — `mysql_handle_derived` entry.
  - [`sql/handler.h`](../handler.h) — cost virtuals (`scan_time`, `keyread_time`, `key_scan_time`).
  - Recent commits via `git log --oneline -- sql/opt_*.cc sql/sql_select.cc sql/sql_explain.cc | head -30` for MDEV citations (MDEV-38045/38934/38921/38649/38273/38877/39304 etc.).
- **Deliberately excluded:**
  - File-by-file paraphrase of `sql_select.cc` — the file is 35 k lines; the doc cites file:method.
  - Cost-model arithmetic — too detail-bound; doc points at `optimizer_*` sysvars and trace as the entry.
  - Per-strategy implementation walk-through of each `QUICK_*` — those are documented in `opt_range.h` headers; the doc cites the class name and lets readers open it.
  - WSREP / Galera-specific optimizer paths (cluster certification) — not optimizer-core.
  - Partition pruning (`sql_partition.cc`) — mentioned only obliquely; full coverage is a separate doc.
- **Refresh procedure:**
  - When a new `opt_*.cc` file appears or an existing one is renamed, update §2.4 and the `sql/CLAUDE.md` table together.
  - When a new `Semi_join_strategy_picker` subclass lands, update §5.
  - When a new `Explain_*` class lands, update §9.
  - Re-grep `git log --oneline -- sql/opt_*.cc sql/sql_select.cc | head -30` for fresh MDEV citations every quarter; replace old ones if they're no longer the canonical examples.
  - Bump `last-verified` to the new walk-through date.
