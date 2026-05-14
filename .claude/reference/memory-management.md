---
applies-to: main
last-verified: 2026-05-14
source-of-truth: mysys/my_alloc.c, include/my_sys.h, include/mem_root_array.h, sql/sql_class.{cc,h}
---

# Memory management in MariaDB Server

How allocation works in server code, which arena to pick, and what bug
class you create by mixing them up. Quick rules live in [`sql/CLAUDE.md`](../../sql/CLAUDE.md)
§"MEM_ROOT vs heap"; this is the deep version.

## 1. TL;DR

Three allocation families coexist in the server tree:

| Family | API | Lifetime | Free | Use for |
|---|---|---|---|---|
| **MEM_ROOT arena** | `alloc_root`, `multi_alloc_root`, `strmake_root`, `Sql_alloc::operator new` | The arena's | `free_root()` (bulk) | Almost everything in `sql/`. Parsed tree, optimizer scratch, Items, per-share data. |
| **`my_malloc` / `my_free`** | `my_malloc(key, size, MYF(...))`, `my_realloc`, `my_free` | Whatever the caller chooses | `my_free()` per-pointer | Long-lived non-statement data: globals, plugin state, persistent caches. |
| **Stack-or-heap scratch** | `my_safe_alloca(size)` + `my_safe_afree(ptr, size)` | The current function | `my_safe_afree` | Variable-length scratch in hot paths where the upper bound is small. |

**Mixing them is the most common memory bug** in `sql/`. `free()` on a
MEM_ROOT pointer corrupts the heap; `free_root()` on a `my_malloc`'d pointer
is undefined; pointing a long-lived structure at a `THD`-scoped arena
becomes a use-after-free at disconnect. See §11.

## 2. The MEM_ROOT arena

Implementation: [`mysys/my_alloc.c`](../../mysys/my_alloc.c). API in
[`include/my_sys.h`](../../include/my_sys.h) (~lines 937-967).

A `MEM_ROOT` is a linked list of contiguous blocks plus a preallocated
block. `alloc_root(root, size)` bumps a pointer inside the current block,
or allocates a new block when full. `free_root(root, flags)` walks the
list and releases everything in one shot. **Individual allocations cannot
be returned** — there is no `free_root_one(ptr)`.

| Call | What it does |
|---|---|
| `init_alloc_root(key, root, block_size, prealloc, flags)` | Initialise an arena. `key` is a PSI memory key. |
| `alloc_root(root, size)` | Allocate `size` bytes. Returns `NULL` on OOM. |
| `multi_alloc_root(root, ptr1, size1, ..., NULL)` | One arena allocation, sliced into N return pointers. |
| `strmake_root` / `strdup_root` / `memdup_root` | Copy a string/buffer onto the arena. |
| `free_root(root, MYF(MY_KEEP_PREALLOC))` | Release used blocks; **keep the prealloc block** for the next statement. Per-statement reset path. |
| `free_root(root, MYF(0))` | Release everything including prealloc. |

`Sql_alloc` ([`sql/sql_alloc.h`](../../sql/sql_alloc.h)) overrides
`operator new` to call `alloc_root(thd->mem_root, …)`, so any class
inheriting `Sql_alloc` is automatically arena-allocated when `new`'d
under a `THD` — that's how `Item`, `TABLE_LIST`, `SELECT_LEX`, and most
parse-tree nodes work without explicit `alloc_root` calls.

## 3. Arena lifetimes in `sql/`

| Arena | Defined in | Lifetime | What's allocated here |
|---|---|---|---|
| `thd->mem_root` | [`sql/sql_class.h`](../../sql/sql_class.h) (THD) | One statement | Parsed tree (when not in PREPARE/SP), optimizer scratch, per-statement Items, transformed expressions. Reset between statements by `free_root(thd->mem_root, MYF(MY_KEEP_PREALLOC))`. |
| `thd->stmt_arena->mem_root` | [`sql/sql_class.h`](../../sql/sql_class.h) (Query_arena, line 1265) | Prepared-statement / SP instance | Items from the prep-tree that must survive re-execution. **While in the prep arena, `thd->mem_root` *is* `stmt_arena->mem_root`.** |
| `thd->main_mem_root` | `THD` (line 5841) | Connection lifetime | The underlying root behind `thd->mem_root` outside arena swaps. `thd->mem_root` *usually* points at this. |
| `TABLE_SHARE::mem_root` | [`sql/table.h`](../../sql/table.h) line 745 | Lifetime of the share in the share cache | Column structures, key definitions, parser output for view definitions, virtual-column trees. |
| `sp_head::main_mem_root` | [`sql/sp_head.h`](../../sql/sp_head.h) line 139 | Stored-program cache entry | The compiled SP body — instructions, parsed item trees, sp_pcontext. Accessed via `sp_head::get_main_mem_root()`. |
| `TABLE::expr_arena->mem_root` (and friends) | per `TABLE` | The open TABLE instance | Default-value expressions, virtual-column expressions evaluated against the table. |

`thd->mem_root` is never a *separate* root from `thd->main_mem_root` or
`stmt_arena->mem_root` — it's a pointer that gets swapped. The swap is
the topic of §4.

## 4. `Query_arena` / `Sub_statement_state` — arena swaps

`Query_arena` ([`sql/sql_class.h`](../../sql/sql_class.h) line 1265) bundles
the two pieces of state that must move together when entering a prepared
statement or stored program: the active `MEM_ROOT *` and the `Item *free_list`
(the chain of allocated-but-not-yet-cleaned-up Items).

The swap API on `THD`:

| Method | Effect |
|---|---|
| `set_n_backup_active_arena(set, backup)` | Save current `mem_root` + `free_list` into `backup`; install `set->mem_root` / `set->free_list`. |
| `restore_active_arena(set, backup)` | Inverse: spill current state back into `set`, restore from `backup`. |
| `activate_stmt_arena_if_needed(backup)` | The "if the stmt arena isn't already active, switch to it" helper used in optimizer paths. |
| RAII wrapper `Query_arena_stmt` (line 1621) | Constructor swaps to the stmt arena, destructor restores. The clean way to enter/leave an arena for a scoped region. |

`Sub_statement_state` ([`sql/sql_class.h`](../../sql/sql_class.h) line 2267)
is a *different* save/restore object used when running a trigger or stored
function — it saves connection-wide state (auto-increment intervals,
limits, examined-row counters) that mustn't leak into the parent
statement's accounting. It does **not** swap the MEM_ROOT.

Recipe: `grep -n 'class Query_arena\|set_n_backup_active_arena\|Query_arena_stmt' sql/sql_class.h`.

## 5. The prepared-statement re-execution rule

The most common bug class is allocating on the wrong arena during Item
rewrite. The rule for a rewrite during the first execution of a prepared
statement / stored program:

| Situation | Allocate on | Cleanup |
|---|---|---|
| The rewritten Item must persist across re-executions (e.g. a constant-folded subexpression, an `Item_in_optimizer` wrapper) | `thd->stmt_arena->mem_root` | None — the rewrite *is* the cached plan. |
| The rewrite is per-execution scratch (depends on the current parameter values, runtime statistics, etc.) | `thd->mem_root` | **MUST** be undone in `Item::cleanup()` so the next execution starts clean. |

`PROTECT_STATEMENT_MEMROOT` (only enabled in Debug builds via the CMake
option `WITH_PROTECT_STATEMENT_MEMROOT`, see
[`CMakeLists.txt`](../../CMakeLists.txt) line 206) marks the stmt arena
read-only after prepare and asserts on any write from outside the prepare
phase. That's the canary for the second category leaking into the first.

Deep version with the failure modes:
[`sql/docs/item-system.md`](../../sql/docs/item-system.md) §8
"Prepared-statement re-execution".

## 6. `my_malloc` / `my_free` — long-lived heap

Signature: `void *my_malloc(PSI_memory_key key, size_t size, myf flags)`.
The libc-like family for memory that does **not** belong to a statement.

Flags worth knowing (from [`include/my_sys.h`](../../include/my_sys.h)
lines ~50-100):

| Flag | Meaning |
|---|---|
| `MY_WME` | "Write message on error" — on OOM, log an error. Almost always wanted. |
| `MY_FAE` | "Fatal if any error" — abort the process on OOM. Use sparingly: only when the caller genuinely cannot recover. |
| `MY_ZEROFILL` | `calloc`-style zero-init. |
| `MY_THREAD_SPECIFIC` | Account against the per-thread memory counter. Use for THD-tied allocations. |
| `MY_ALLOW_ZERO_PTR` / `MY_FREE_ON_ERROR` | `my_realloc` semantics. |

Use cases: server-global state, plugin-owned data, persistent caches,
anything that outlives a statement but isn't tied to an existing arena.
Free with `my_free(ptr)` (zero on `NULL` is a no-op — safe).

**Never `free()` on memory from `alloc_root`. Never `free_root()` on
memory from `my_malloc`.** Both will eventually crash. The arena
implementation has its own internal `my_malloc` calls for its blocks,
but that's an implementation detail — callers see arena handouts as
opaque pointers owned by the arena.

## 7. `my_safe_alloca` — stack-or-heap scratch

Macro in [`include/my_sys.h`](../../include/my_sys.h) (lines 220-234).
Allocates on the stack when `size <= MAX_ALLOCA_SZ` (4096 bytes on Linux),
falls back to `my_malloc` otherwise. Paired with `my_safe_afree(ptr, size)`,
which `my_free`s only if the heap branch was taken.

Use for variable-length scratch (a filename buffer, a small expression
list) in hot paths where the upper bound is small but not constant. Don't
use it for buffers larger than ~4 KB on principle — large stack
allocations on deep call paths (parser → optimizer → exec) overflow the
thread stack.

Under Valgrind / ASAN, `my_safe_alloca` always goes through `my_malloc`
so leak checking works.

## 8. `Mem_root_array<T>` — vector on an arena

Header: [`sql/mem_root_array.h`](../../sql/mem_root_array.h). A
`std::vector`-shaped container that allocates its storage on a
`MEM_ROOT *` passed to its constructor. Elements are copied (not
`memcpy`'d) when the array grows; destructors run on element removal
unless `has_trivial_destructor=true` is forced. There is **no** facility
for reusing freed slots on the underlying MEM_ROOT — if you grow-and-shrink
repeatedly, the arena holds onto every intermediate allocation.

Use it instead of `std::vector` for arena-scoped collections of Items,
TABLE_LISTs, expressions, etc. Reviewers reject `std::vector` in new
`sql/*` code precisely because it allocates on the libc heap and creates
the mixing-arena bug class.

## 9. `String` and `LEX_CSTRING` allocation

`String` ([`sql/sql_string.h`](../../sql/sql_string.h)) is a length-prefixed
mutable buffer with two modes: **heap-owned** (`String::alloc(len)`,
`String::copy(s, len, cs)`) where the buffer is `my_malloc`'d and freed
by the destructor; **borrowed** (`String s(buf, len, cs)`,
`String::set(buf, len, cs)`) where the caller owns the buffer and the
`String` must not outlive it.

To put bytes on a MEM_ROOT use `strmake_root` / `strdup_root` /
`safe_lexcstrdup_root` ([`include/my_sys.h`](../../include/my_sys.h)) or
`String::copy(s, len, cs, mem_root)`. Long-lived strings need MEM_ROOT
awareness — pointing a `LEX_CSTRING` at a borrowed buffer that gets
freed is a recurring reviewer-caught bug. See [`sql/docs/charset-and-collation.md`](../../sql/docs/charset-and-collation.md) for the charset-conversion side.

## 10. OOM behavior — no exceptions

MariaDB does **not** use C++ exceptions. The allocators report failure
through return values:

| Call | Behavior on OOM |
|---|---|
| `alloc_root(root, size)` | Returns `NULL`. Calls `root->error_handler` if set. |
| `my_malloc(key, size, MYF(MY_WME))` | Logs `ER_OUTOFMEMORY`, returns `NULL`. |
| `my_malloc(key, size, MYF(MY_FAE))` | Logs the error and **aborts the process**. |
| `my_malloc(key, size, MYF(0))` | Silent. Returns `NULL`. Caller is responsible for any error handling. |

**Callers MUST check the return.** Skipping the NULL-check is a
reviewer-caught defect — see
[`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md)
§"Lifetime / ownership". Forgetting `MY_WME` means the operator sees a
confusing downstream error rather than the actual OOM in the log.

## 11. Pitfalls

- **`free()` (or `my_free`) on a MEM_ROOT pointer.** Heap corruption.
  The arena reuses the memory; libc's `free` thinks it owns it. ASAN
  catches it; production crashes are subtle.
- **Trying to free a single MEM_ROOT allocation.** No API exists —
  handouts are released in bulk at `free_root()`. Such code indicates
  the wrong arena was chosen.
- **Long-lived global on a `THD`-scoped arena.** When the THD
  disconnects, `main_mem_root` is freed; the global dangles. Use
  `my_malloc` (or a TABLE_SHARE / SP arena) for anything outliving the
  connection.
- **`std::vector` (or any libc-heap STL container) in `sql/*`.**
  Reviewers reject. Use `Mem_root_array<T>` for arena-scoped collections
  or in-tree containers (`Dynamic_array`, `List<T>`).
- **Forgetting `MY_WME` on `my_malloc`.** On OOM, the caller gets `NULL`
  but the error log is silent — user sees a misleading downstream
  failure, DBA has no breadcrumb.
- **Large stack buffers without `my_safe_alloca`.** Deep call paths
  (parser → optimizer → exec → handler) accumulate stack; a
  `char buf[1<<16]` mid-path causes stack overflow on deep recursion.
- **Cross-arena pointer aliasing.** An Item on `thd->mem_root` pointing
  to a string on `stmt_arena->mem_root` (or vice versa) survives once,
  then dereferences freed memory on the second execution.
  `PROTECT_STATEMENT_MEMROOT` catches one half; ASAN under `mtr --mem`
  catches the other.
- **Item rewrite without an arena swap.** Rewriting during `optimize`
  while `thd->mem_root` happens to be the per-statement root (not the
  stmt arena) silently corrupts the cached plan. Use `Query_arena_stmt`
  or `activate_stmt_arena_if_needed` — never assume.

## 12. See also

- [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap" — the
  quick-rules version of §§1-3.
- [`sql/docs/item-system.md`](../../sql/docs/item-system.md) §8 — the
  Item-side detail behind §5.
- [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md)
  §"Lifetime / ownership" — reviewer-caught lifetime bugs with cited PRs.
- [`.claude/reference/glossary.md`](glossary.md) — short definitions of
  MEM_ROOT, THD, prepared-statement re-execution.

## How this doc was built

- **Date:** 2026-05-14. **HEAD at write time:** `23097b2d825` (branch `main`).
- **Sources surveyed:**
  - [`mysys/my_alloc.c`](../../mysys/my_alloc.c) — `alloc_root`,
    `free_root`, `init_alloc_root`, `multi_alloc_root` signatures.
  - [`include/my_sys.h`](../../include/my_sys.h) — `my_malloc` / `my_free`
    flags (~lines 50-100, 137-138), `my_safe_alloca` (220-234),
    MEM_ROOT helpers (~937-967).
  - [`sql/mem_root_array.h`](../../sql/mem_root_array.h) — class header
    comment is canonical for "no free-slot reuse".
  - [`sql/sql_class.h`](../../sql/sql_class.h) — `Query_arena` (1265),
    `Query_arena_stmt` (1621), `Sub_statement_state` (2267),
    `THD::main_mem_root` (5841), `set_n_backup_active_arena` decl.
  - [`sql/sql_class.cc`](../../sql/sql_class.cc) — `set_query_arena`
    (4288), `set_n_backup_active_arena` (4475), `restore_active_arena`
    (4495).
  - [`sql/table.h`](../../sql/table.h) line 745 — `TABLE_SHARE::mem_root`.
  - [`sql/sp_head.h`](../../sql/sp_head.h) line 139 — `sp_head::main_mem_root`.
  - [`CMakeLists.txt`](../../CMakeLists.txt) lines 206-215 — the
    `WITH_PROTECT_STATEMENT_MEMROOT` option.
  - [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"MEM_ROOT vs heap" and
    §"Prepared statements & re-execution" — quick-rules to extend, not duplicate.
  - [`sql/docs/item-system.md`](../../sql/docs/item-system.md) §8
    (commit `3d669e661c8`) — the arena/Item interaction. Cross-linked.
- **Deliberately excluded:** InnoDB's `mem_heap_t` / `ut_malloc` family
  (separate subsystem under `storage/innobase/include/mem*.h`); `tpool`
  allocator and `Pool` template (low-level, internal); `wsrep` memory
  accounting (gated on `WITH_WSREP=ON`); exhaustive `my_malloc` flag
  tables (only the flags an `sql/` author commonly chooses are listed).
- **How to refresh:** when `mysys/my_alloc.c` adds a new `*_root` helper
  or changes `free_root` semantics, re-walk §2; when `Query_arena` /
  `Sub_statement_state` signatures change, re-walk §4; when
  `PROTECT_STATEMENT_MEMROOT` semantics change, re-walk §5. Bump
  `last-verified` and the HEAD SHA.
