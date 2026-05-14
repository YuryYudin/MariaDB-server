---
applies-to: main
last-verified: 2026-05-14
source-of-truth: include/mysql/psi/mysql_thread.h, mysys/thr_mutex.c, sql/sql_class.{cc,h}
---

# Reference: threading & lock primitives

## TL;DR

- **One `THD` per thread** — connection threads have one, and so do every background thread that runs SQL-ish work (slave IO/SQL, parallel applier workers, event scheduler, InnoDB purge / page-cleaner, …). [`current_thd`](../../sql/mysqld.cc) is per-thread storage (a `thread_local THD *THR_THD` in [`sql/mysqld.cc:733`](../../sql/mysqld.cc); plugged in by [`THD::store_globals()`](../../sql/sql_class.cc) at line 2421).
- **Use `mysql_mutex_t`, not raw `pthread_mutex_t`.** The PSI wrappers in [`include/mysql/psi/mysql_thread.h`](../../include/mysql/psi/mysql_thread.h) add Performance Schema visibility (`SHOW ENGINE PERFORMANCE_SCHEMA STATUS`, `information_schema.metadata_lock_info`, `events_waits_*`) and the `SAFE_MUTEX` lock-order tracker.
- **`SAFE_MUTEX` (Debug builds only)** catches lock-order inversions at runtime. Enabled automatically by `CMAKE_BUILD_TYPE=Debug` (see `-DSAFE_MUTEX` in [`CMakeLists.txt:362`](../../CMakeLists.txt)).
- **Atomics: prefer `std::atomic<T>` or the in-tree `Atomic_counter<T>` / `Atomic_relaxed<T>` wrappers** in new C++ code; the older C [`my_atomic_*`](../../include/my_atomic.h) API is for C-only files. Atomics are for single-word counters/flags, **not** for multi-field invariants.
- **InnoDB has its own latch + row-lock hierarchy.** Don't paraphrase it here — see [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy & locking discipline".

---

## Thread types in MariaDB

Every thread in `mariadbd` is one of these. The "Has THD?" column matters: if the thread doesn't have a THD plugged in via `store_globals()`, calling `current_thd` returns `NULL` (or worse — see Pitfalls).

| Thread | Owner / where created | Has THD? | Notes |
|---|---|---|---|
| Connection thread | `handle_one_connection` / thread pool | yes | One per active client; lifetime = connection. `thd->thread_id` is the visible session id. |
| Slave IO thread | `handle_slave_io` in [`sql/slave.cc`](../../sql/slave.cc) | yes | Per replication channel; constructs its own THD via `new THD(next_thread_id())`. |
| Slave SQL thread | `handle_slave_sql` in [`sql/slave.cc`](../../sql/slave.cc) | yes | Per replication channel; applies events. |
| Parallel-applier worker | [`sql/rpl_parallel.cc`](../../sql/rpl_parallel.cc) (`rpl_parallel_thread`) | yes | Per worker slot; pooled. Modes: `optimistic` / `conservative` / `aggressive`. |
| Event scheduler | [`sql/event_scheduler.cc`](../../sql/event_scheduler.cc) | yes | One main scheduler thread + per-event worker threads. |
| Purge thread (InnoDB) | InnoDB `srv0srv.cc` / `trx0purge.cc` | yes | For undo cleanup. Constructs an `innobase_create_background_thd()` THD. |
| Background page cleaner (InnoDB) | InnoDB `buf0flu.cc` | yes | For dirty-page flush. |
| Group-commit / binlog flusher | [`sql/log.cc`](../../sql/log.cc) | yes | Coordinator thread for binlog-engine group commit. |
| Thread-pool dispatcher | [`sql/threadpool_*.cc`](../../sql/) | sometimes | Per worker; the worker plugs/unplugs the request's THD on each task. |
| Signal handler | OS signal delivery | **NO** | Must not call `current_thd`. Use only async-signal-safe APIs; defer real work to a normal thread. |

Search recipe — find where a background thread gets its THD:

```sh
git grep -nE 'new THD\(' sql/ storage/        # candidate background-thread constructors
git grep -n 'store_globals' sql/              # the per-thread "plug it in" call
```

---

## THD per-thread invariant — the `current_thd` rule

The mechanism is short:

```cpp
// sql/mysqld.cc:733
static thread_local THD *THR_THD;

MYSQL_THD _current_thd() { return THR_THD; }
void set_current_thd(THD *thd) { THR_THD= thd; }
```

`THD::store_globals()` ([`sql/sql_class.cc:2421`](../../sql/sql_class.cc)) is the one place that plugs a THD into the running thread:

```cpp
void THD::store_globals()
{
  set_current_thd(this);
  mysys_var= my_thread_var;
  mysys_var->id= thread_id;
  // ... stack bounds, real_id (pthread_self), thr_lock_info_init, etc.
}
```

`THD::reset_globals()` (line 2477) is the counterpart for the thread-pool case: the THD is detached, `set_current_thd(0)` clears the per-thread slot.

**The rule.** A thread that wants `current_thd` to work for it **must** call `THD::store_globals()` first. Connection threads do this once. Background threads do it once after they construct their THD. Code paths invoked from contexts that haven't done either (signal handlers, very early init, plugin background workers that forgot to call `store_globals`) **cannot** use `current_thd` — they must take the THD as a parameter.

Citation:

```sh
grep -n 'store_globals\|set_current_thd' sql/sql_class.cc | head
```

For policy on adding new fields to THD (don't, unless measured), see [`.claude/review/api-and-architecture.md`](../review/api-and-architecture.md) §"De-THD direction".

---

## `mysql_mutex_t` and the PSI wrappers

The project's mutex/rwlock/cond types live in [`include/mysql/psi/mysql_thread.h`](../../include/mysql/psi/mysql_thread.h). Each wraps the corresponding pthread primitive plus a Performance Schema instrumentation hook:

```cpp
// include/mysql/psi/mysql_thread.h:133
struct st_mysql_mutex
{
#ifdef SAFE_MUTEX
  safe_mutex_t m_mutex;
#else
  pthread_mutex_t m_mutex;
#endif
  struct PSI_mutex *m_psi;
};
typedef struct st_mysql_mutex mysql_mutex_t;
```

The four types and their API shapes (all defined in `mysql_thread.h`):

| Type | API | Notes |
|---|---|---|
| `mysql_mutex_t` | `mysql_mutex_init(key, &m, attr)`, `mysql_mutex_lock(&m)`, `mysql_mutex_trylock(&m)`, `mysql_mutex_unlock(&m)`, `mysql_mutex_destroy(&m)` | Drop-in for `pthread_mutex_t`. |
| `mysql_rwlock_t` | `mysql_rwlock_{init,rdlock,wrlock,tryrdlock,trywrlock,unlock,destroy}` | Drop-in for `pthread_rwlock_t`. Writer-preferring. |
| `mysql_prlock_t` | `mysql_prlock_{init,rdlock,wrlock,unlock,destroy}` | "**P**refers **R**eaders" rwlock built on `rw_pr_lock_t`. Use only when readers must not starve. |
| `mysql_cond_t` | `mysql_cond_{init,wait,timedwait,signal,broadcast,destroy}` | Drop-in for `pthread_cond_t`. |

**New code must use the `mysql_*` wrappers** — declaring a raw `pthread_mutex_t` (or `std::mutex`) skips PSI instrumentation, so the lock is invisible in `INFORMATION_SCHEMA` / PFS tables and can't be reasoned about with the standard tooling. See [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency".

InnoDB uses its own latch types (`srw_lock`, `ssux_lock`, `sux_lock`, `block_lock`, `index_lock`) on top of futexes — see [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy & locking discipline".

---

## `SAFE_MUTEX` (Debug-only lock-order tracking)

When `CMAKE_BUILD_TYPE=Debug`, the build adds `-DSAFE_MUTEX` (see [`CMakeLists.txt:362`](../../CMakeLists.txt)) and `mysql_mutex_t`'s storage switches to `safe_mutex_t` ([`mysys/thr_mutex.c`](../../mysys/thr_mutex.c), declared in [`include/my_pthread.h`](../../include/my_pthread.h)). Every lock and unlock is then recorded in a thread-local stack; if a thread acquires mutex `B` while holding `A`, the pair `A→B` is registered. A subsequent acquisition of `A` while holding `B` (the inverse) trips an assertion.

To **declare** a known-good ordering up front — useful at server startup before either path has run — call:

```cpp
mysql_mutex_record_order(&A, &B);   // declares A < B
```

This expands to `lock(A); lock(B); unlock(B); unlock(A);` under `SAFE_MUTEX` (it's a no-op in non-debug builds — see [`include/my_pthread.h:788-796`](../../include/my_pthread.h)). The locks are momentarily held in the desired order so the tracker learns it.

Real call sites (the project's "lock-order graph", such as it is, is encoded by these — there is **no single document** that lists them):

```sh
$ grep -rn 'mysql_mutex_record_order' sql/
sql/mysqld.cc:4538:   mysql_mutex_record_order(&LOCK_active_mi, &LOCK_global_system_variables);
sql/log.cc:4489:      mysql_mutex_record_order(&LOCK_log, &LOCK_global_system_variables);
sql/event_scheduler.cc:359: mysql_mutex_record_order(&LOCK_scheduler_state, &LOCK_global_system_variables);
sql/sql_class.cc:929: mysql_mutex_record_order(&LOCK_thd_kill, &LOCK_thd_data);
sql/sql_acl.cc:3059:  mysql_mutex_record_order(&acl_cache->lock, &LOCK_status);
```

**The rule.** If you've locked `A` and want to lock `B`, either an `A→B` order must already exist in the call graph (declared via `mysql_mutex_record_order` *or* established by an existing acquisition path), or you must reorder — release `A`, acquire `B` first, then re-acquire `A`. Don't paper over `SAFE_MUTEX` asserts; they're real lock-order bugs (e.g. MDEV-29930 "Lock order inversion in ibuf_remove_free_page()", commit `a2ee2c7ea10`).

InnoDB has its own ordering discipline encoded in `ut_ad()` assertions and source comments — see [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy & locking discipline".

---

## Reader-writer locks

- **`mysql_rwlock_t`** — writer-preferring. Reasonable default for read-mostly state where occasional writers must not starve. Under high *write* contention readers may pile up.
- **`mysql_prlock_t`** — reader-preferring (built on `rw_pr_lock_t`). Use sparingly: chosen when readers are hot-path and writers are rare enough that reader starvation is the bigger concern. Writers can be starved indefinitely under continuous read load.
- **Don't read pointer-to-string sysvars without holding the rwlock long enough to **copy** the value** — the pointer can be swapped between read and dereference. PR4633; [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency".

Recent contention bugs to be aware of (illustrative of why long-held rwlocks are a perf problem, not just a correctness one): MDEV-39040 "log_sys.latch performance lost to PERFORMANCE_SCHEMA", MDEV-37482 "Contention on btr_sea::partition::latch", MDEV-19749 "MDL scalability regression after backup locks".

---

## Atomics

Three flavours in tree, in roughly preferred order:

| Choice | Header | When |
|---|---|---|
| **`std::atomic<T>`** | `<atomic>` | Default for new C++ code. Standard memory-order vocabulary. |
| **`Atomic_counter<T>`** | [`include/my_counter.h`](../../include/my_counter.h) | Convenience wrapper for monotonic counters (`++` / `--` / `+=`). Used pervasively in `sql/sql_class.h` etc. |
| **`Atomic_relaxed<T>`** | [`include/my_atomic_wrapper.h`](../../include/my_atomic_wrapper.h) | Relaxed-only loads/stores (no fences). Use when you've thought about ordering and decided you don't need it. |
| **`my_atomic_add#` / `my_atomic_load#` / `my_atomic_cas#` / `my_atomic_fas#`** | [`include/my_atomic.h`](../../include/my_atomic.h) | C-only files; mostly legacy. Mirrors `<stdatomic.h>` shape. |

**The rule.** Atomics are for **single-word** state that one thread reads while another writes (counters, flags, sequence numbers). They are **not** a substitute for a mutex when you have an invariant that spans multiple fields — re-reading an atomic across two lines does not guarantee the value didn't change in between, so any decision that depends on two related reads needs a mutex.

A specific 32-bit pitfall: `SHOW STATUS` reads `ulonglong` counters directly via `get_one_variable()`, which doesn't go through the atomic load path — so `Atomic_relaxed<ulonglong>` on a 32-bit platform is **still subject to torn reads**. The fix is to indirect through `export_vars`. See PR4405 in [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency".

---

## Condition variables

The standard protocol — `mysql_cond_t` is a drop-in for `pthread_cond_t`:

```cpp
mysql_mutex_lock(&m);
while (!predicate())
  mysql_cond_wait(&cv, &m);          // releases m while waiting; re-acquires on wakeup
// ... act on the predicate ...
mysql_mutex_unlock(&m);
```

```cpp
mysql_mutex_lock(&m);
set_state_that_makes_predicate_true();
mysql_cond_signal(&cv);              // or mysql_cond_broadcast for all waiters
mysql_mutex_unlock(&m);
```

**Always re-check the predicate in a loop.** Spurious wakeups, lost-signal/broadcast races between waiters, and shutdown paths that broadcast unconditionally all violate the "one signal == one ready waiter" intuition.

For MTR tests waiting on server state, **don't** use `SELECT SLEEP(N)` or `--sleep` — use [`include/wait_condition.inc`](../../mysql-test/include/wait_condition.inc) (with a generous timeout, e.g. 60s). See [`.claude/review/testing.md`](../review/testing.md) §"Synchronisation: never `sleep`" (PR4421, PR4765, PR4998, PR4804).

---

## THD-scoped state vs global state

Use the lifetime of the data to pick the home:

| Data lifetime | Where it lives | Locking |
|---|---|---|
| Per-statement scratch | `thd->mem_root` allocations, `THD` member fields used in `dispatch_command` | None — only the owning thread reads it. |
| Per-connection state | `THD` member field | None for the owning thread; **cross-thread reads (e.g. KILL, SHOW PROCESSLIST) must take `LOCK_thd_data` or `LOCK_thd_kill`** (see [`sql/sql_class.h:1710-1718`](../../sql/sql_class.h) and `mysql_mutex_record_order(&LOCK_thd_kill, &LOCK_thd_data)` in `sql_class.cc:929`). |
| Server-wide config / stats | File-scope static in [`sql/mysqld.cc`](../../sql/mysqld.cc), `MYSQL_BIN_LOG` singleton, ACL caches | `mysql_mutex_t` / `mysql_rwlock_t` named `LOCK_*` (e.g. `LOCK_global_system_variables`, `LOCK_active_mi`, `LOCK_status`). |
| Engine-shared state | The engine's singleton (`lock_sys`, `buf_pool`, `fil_system`, `log_sys`) | The engine's own latch types (InnoDB: `srw_lock` / `ssux_lock` / `sux_lock`). |

Cross-thread access pattern for THD data:

```cpp
mysql_mutex_lock(&other_thd->LOCK_thd_data);
const char *query= other_thd->query();
size_t length= other_thd->query_length();
// copy out what you need before releasing
mysql_mutex_unlock(&other_thd->LOCK_thd_data);
```

This is the canonical "another thread reads my THD" handoff. SHOW PROCESSLIST, KILL, and `SHOW ENGINE INNODB STATUS` all use it.

---

## Pitfalls

- **Raw `pthread_mutex_t` (or `std::mutex`) in new code.** Skips PSI; invisible in `INFORMATION_SCHEMA`. Use `mysql_mutex_t`.
- **`current_thd` from a context with no THD plugged in.** Signal handlers, very early init, plugin background threads that forgot `store_globals()`. The pointer is `NULL` (or stale, depending on how the thread was created); dereferencing crashes. Pass `thd` down the call chain instead.
- **Lock-order inversion.** Two paths acquire `A` and `B` in opposite orders → deadlock under load. `SAFE_MUTEX` Debug builds will hit this in test runs *if* the test exercises both paths. MDEV-29930 is a real example.
- **Re-reading a `std::atomic` and treating both reads as "the same value".** Between two loads, the value can change. If a decision depends on two related fields, you need a mutex, not two atomics.
- **`--sleep` in MTR instead of `wait_condition.inc`.** Flaky under CI load; reviewers reject it. PR4421, PR4765, PR4804, PR4998.
- **Background thread that doesn't `THD::store_globals()`, then crashes on `current_thd`.** Constructing a `new THD(...)` is not enough — you must also plug it into thread-local storage with `store_globals()`. The DBUG facility (`DBUG_ENTER` etc.) also depends on this.
- **Long-held latches around heap allocation.** `mysql_*_alloc` under `log_sys.latch.wr_lock()`, taking `current_thd` under a hot InnoDB latch, etc. — see [`.claude/review/innodb.md`](../review/innodb.md) §"Performance discipline" (PR4405, PR4914).
- **Reading another thread's `THD *` fields without `LOCK_thd_data`.** The owning thread can free or rewrite them at any time. Snapshot under the lock; act on the snapshot after release.
- **Sysvar pointer-to-string read without the rwlock long enough to copy.** PR4633 (server_audit). Take the lock, copy into a thread-local buffer, release, then use the copy.

---

## See also

- [`sql/CLAUDE.md`](../../sql/CLAUDE.md) §"THD lifecycle & the `current_thd` rule" — the rule, distilled for sql/.
- [`storage/innobase/CLAUDE.md`](../../storage/innobase/CLAUDE.md) §"Latch hierarchy & locking discipline" — InnoDB's two-layer (latches + row-locks) model.
- [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency" — PR-feedback-derived rules and 32-bit pitfalls.
- [`.claude/review/innodb.md`](../review/innodb.md) §"Performance discipline" — what reviewers flag under hot latches.
- [`.claude/review/testing.md`](../review/testing.md) §"Synchronisation: never `sleep`" — `wait_condition.inc` / `DEBUG_SYNC` / `--ping`.
- [`.claude/reference/memory-management.md`](memory-management.md) — MEM_ROOT and arena lifetimes that interact with THD scope.
- [`.claude/reference/glossary.md`](glossary.md) — short definitions of THD, DEBUG_SYNC, WSREP.

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `cab108b88f8` (branch `main`).
- **Files surveyed:**
  - [`include/mysql/psi/mysql_thread.h`](../../include/mysql/psi/mysql_thread.h) for the four wrapper types and their API surface.
  - [`include/my_pthread.h`](../../include/my_pthread.h) (lines 788-796 for `mysql_mutex_record_order`; line 340+ for `safe_mutex_t`).
  - [`sql/mysqld.cc`](../../sql/mysqld.cc) lines 733-742 for `THR_THD` / `set_current_thd` / `_current_thd`.
  - [`sql/sql_class.cc`](../../sql/sql_class.cc) `THD::store_globals` (2421), `THD::reset_globals` (2477), `mysql_mutex_record_order(&LOCK_thd_kill, &LOCK_thd_data)` (929).
  - [`sql/sql_class.h`](../../sql/sql_class.h) lines 1700-1718 for the `LOCK_thd_data` cross-thread protocol comment.
  - [`include/my_counter.h`](../../include/my_counter.h), [`include/my_atomic_wrapper.h`](../../include/my_atomic_wrapper.h), [`include/my_atomic.h`](../../include/my_atomic.h) for atomic helpers.
  - `CMakeLists.txt:362` for `-DSAFE_MUTEX` in Debug builds.
  - `grep -rn mysql_mutex_record_order sql/` for the small set of declared orderings.
  - Recent commit log filtered on `rwlock|lock_order|mutex` for currency (MDEV-29930, MDEV-39040, MDEV-37482, MDEV-19749).
  - [`.claude/review/correctness-and-security.md`](../review/correctness-and-security.md) §"Concurrency" for PR-derived rules.
- **Deliberately excluded:**
  - InnoDB's internal latch hierarchy — owned by `storage/innobase/CLAUDE.md`; cited, not duplicated.
  - MDL (`MDL_lock`, `MDL_ticket`) details — a separate subsystem; mentioned only in passing for MDEV-19749.
  - WSREP / Galera synchronisation — references the `wsrep-lib` submodule; out of scope.
  - The full PSI instrumentation registration mechanism (`mysql_mutex_register`, `PSI_mutex_key`) — covered by Performance Schema docs.
- **Refresh procedure:**
  - When a new lock-order edge is declared (`mysql_mutex_record_order` call added), re-run the `grep` recipe and consider whether the new pair changes guidance.
  - If `safe_mutex_t` or the `mysql_*` wrapper APIs change shape (rare), refresh the tables.
  - Bump `last-verified` and HEAD SHA.
