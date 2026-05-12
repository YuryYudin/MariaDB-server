# Pre-PR / Pre-merge Checklist

Run through this list before pushing. Each item points to the deep-dive doc with the supporting PR evidence. Every item here was a recurring **blocker** in the last 6 months of reviews — pre-empting them is the single biggest speed-up to the review cycle.

## Commit & branch (always)

- [ ] **One commit per logical change** — squash review-iteration commits before push. (PR4509, PR4569, PR4625, PR4658, PR4678, PR4737, PR4869, PR4881, PR4889, PR4966, PR4982, PR5007 — at least 10 PRs blocked on this in the window.)
- [ ] **Commit subject is `MDEV-NNNNN <imperative description>`** (Sergei prefers no colon; either is accepted, but the MDEV must lead). Subject ≤ ~70 chars; body wrapped at 72.
- [ ] **Commit message follows `CODING_STANDARDS.md`** — describes *what the bug was, what causes it, and what the fix does*. (PR4549, PR4569, PR4625, PR4649, PR4658, PR4664, PR4697, PR4703, PR4707, PR4869.)
- [ ] **Targeted at the lowest still-maintained branch where the bug reproduces.** Bug fixes → 10.11 by default; 10.6 only for critical / crashing bugs; only `main` if the issue does not exist in older branches. New features → `main`. (PR4534, PR4569, PR4602, PR4606, PR4680, PR4688, PR4706, PR4731, PR4752, PR4766, PR4789, PR4793, PR4804, PR4858, PR4869, PR4872, PR4881, PR4913, PR4998.)
- [ ] **Rebased onto the target branch, not merged.** No merge commits in the PR. Force-push to update the existing PR branch — do *not* open a second PR for the same change. (PR4508, PR4658, PR4703.)
- [ ] **CLA bot is green** (`CLA signed`). Without it, even an LGTM will not lead to merge. External contributors must click the CLA bot link and pick either BSD-3-clause or MariaCLA. (PR4493, PR4601, PR4605, PR4618, PR4703, PR4712, PR4779, PR4881.)
- [ ] **Build-bot is green on the full grid** — including Windows (AppVeyor), MSAN, UBSAN, ASAN, and Galera-required jobs. Re-record affected `.result` files and chase down platform failures yourself. Unrelated failures can be filed as separate MDEVs but you must enumerate them. (PR4549, PR4569, PR4590, PR4632, PR4641, PR4658, PR4697, PR4706, PR4712, PR4731, PR4811, PR4869, PR4918.)

## Tests (almost always)

- [ ] **At least one MTR regression test** that fails without the fix and passes with it. The exact case from the JIRA must be reproducible. If a test is impossible, explain why in the commit message and on the PR. (PR4549, PR4691, PR4717, PR4739, PR4743, PR4752, PR4769, PR4889, PR4913, PR4982.)
- [ ] **The test is minimal** — no irrelevant columns, joins, optimizer-trace, sysvar twiddling, or hex strings that don't matter. Two rows per table to avoid `const-table` short-circuits. (PR4505, PR4517, PR4687.)
- [ ] **Test header**: `--echo # MDEV-NNNNN <title>` (use `--echo`, not `# comment`). (PR4711, PR4739, PR4789, PR4804, PR4811, PR4829.)
- [ ] **Test footer**: `--echo # End of <maj.min> tests` on the last logical line — single line, no decorative block. Newline at end of file. (PR4710, PR4711, PR4743, PR4810, PR4811, PR4829, PR4874, PR4904, PR4455.)
- [ ] **`--source include/not_embedded.inc`** (or `--loose-` prefix the offending option) when the test needs a feature embedded mode lacks. Check buildbot for `embedded` failures. (PR4606, PR4641, PR4697, PR4904, PR4998.)
- [ ] **No `sleep`** — use `DEBUG_SYNC`, `wait_condition`, `--ping`, or existing helper scripts. If you must guard timing, use `--source include/have_debug.inc` + `--source include/have_debug_sync.inc`. (PR4421, PR4697, PR4765, PR4804, PR4874, PR4986, PR4998.)
- [ ] **`mtr --record`** the affected `.result` files locally; do not hand-edit. Verify the diff is plausible before pushing. (PR4455, PR4711, PR4712, PR4829.)
- [ ] **Place tests in the right suite** — for example a status-variable test belongs in `suite/rpl/`, not `sys_vars/`. (PR4904.) New test files prefixed with the subsystem (`mysql_`, `binlog_`, …) so `--do-test` selectors work. (PR4710, PR4766.)
- [ ] **Prefer extending an existing test** to creating a new one for a single regression case. (PR4706, PR4711, PR4789, PR4811.)

## Code (when touching C/C++ source)

- [ ] **No whitespace-only changes** in unrelated lines. No editor-driven reformatting. (PR4508, PR4581, PR4633.)
- [ ] **Match the file's existing indentation** — InnoDB (`storage/innobase/*`) is the special case: TAB inside *legacy* files, mandatory `{}` around single-statement `if/else`, K&R `switch` layout (no break after `switch (...)`, no extra braces around case bodies). **In *new* InnoDB code**: use spaces (no TAB) and `noexcept` on member functions. (PR4036, PR4446, PR4905, PR4914.)
- [ ] **Variable declarations at first real use** (inside the `for`/`while` head if possible). No declare-then-assign-later. (PR4036, PR4342.)
- [ ] **`var= 1;`** — no space before `=`, one space after, per `CODING_STANDARDS.md`. Pointer style is `TYPE *var`. (PR4446, PR4914.)
- [ ] **No C-style casts in C++** — use `int(len)`/`unsigned(x)`/`uint16_t(n)` (constructor-style), or `static_cast<>()` if widening. (PR4717, PR4783, PR4884, PR4913.)
- [ ] **No `long` / `ulong`** in new code — use `size_t`, `ptrdiff_t`, `uint64_t`, or fixed-width types. (PR4522, PR4884.)
- [ ] **Use mysys wrappers** (`my_strtol`, `my_strtod`, `my_stat`, `mysql_socket_*`, `my_open`, `snprintf`) over raw libc when you're in `sql/*` or `storage/*`. (PR4764, PR4874.)
- [ ] **`snprintf`, not `sprintf`** — and the size is a **parameter to the function**, not a hard-coded constant guessed at the call site. This was the single most-flagged issue in PR4869. (PR4522, PR4824, PR4869.)
- [ ] **Buffer bounds are validated against the actual remaining length**, e.g. `if (len > end - ptr) error`. Never trust client/wire/file-format length fields. Don't assume input is NUL-terminated. (PR4509, PR4534, PR4884, PR4889.)
- [ ] **Format specifiers match types**: `%llu`/`%lld` for `unsigned long long`/`long long` (drop the cast), `%zu` for `size_t`, `%.*s` with `int(len)` for explicit-length strings. (PR4869, PR4884.)
- [ ] **No bitwise-OR / bitwise-AND of error-returning calls** to chain checks — `|` and `&` don't short-circuit and the evaluation order is unspecified. Use `&&`/`||` for sequencing. *Exception:* in InnoDB hot paths, `|` over `||` is sometimes requested to avoid conditional branches — but only for plain bit tests, never for calls that can fail. (PR4441; PR4707, PR4717, PR4858.)
- [ ] **Initialise output variables on all paths** so MSAN doesn't catch uninit reads on error returns. (PR4764.)
- [ ] **Validity checks for new sysvars go in the `check` callback**, never `update`. (PR4633.)
- [ ] **Don't bundle unrelated cleanups** (spelling fixes, formatting, submodule bumps, AI-generated cleanups) into a bug-fix PR. Split into separate commits or separate PRs. (PR4390, PR4522, PR4557, PR4573, PR4697, PR4933, PR4998.)
- [ ] **Don't touch generated files** (Bison/Flex `.cc`, third-party submodule sources) directly — edit the source `.yy`/`.l` and rerun, or add CMake-level configuration. (PR4017, PR4293, PR4829.)
- [ ] **No `std::function` or `std::unordered_map` for serialized formats** (downgrade-breaks) — and avoid them in InnoDB hot paths. Prefer in-tree `HASH`, `Hash_set`, `my_decimal`. (PR4430, PR4884, PR4914.)

## Logging / error messages

- [ ] **Use `sql_print_error` / `sql_print_information`** in new code; avoid `ib::logger`/`ib::info` and `puts()`. (PR4036, PR4262.)
- [ ] **Error message includes the identifier(s) it refers to** (table name, constraint name, file path tail). Use `%.*s` with an `int(len)`. Use `ut_get_name()` / `dict_table_open_failed()` for InnoDB identifiers (charset conversion). (PR4342.)
- [ ] **Reuse existing error codes** — especially `ER_STD_INVALID_ARGUMENT` for generic validation errors. Don't mint hyper-specific codes copied from MySQL. (PR4569.)
- [ ] **`errno` formatting**: use `%iE` (13.0+) or `%M` (10.11) instead of hand-enumerating `EACCES`/`EMFILE`/etc. (PR4874.)

## InnoDB-specific (when in `storage/innobase/*`)

- [ ] **`noexcept` on every new non-throwing member function.** (PR4036, PR4884, PR4914.)
- [ ] **Document data members and public types with Doxygen** — but no `[in]`/`[out]` markers, use `@retval` for literal returns, don't repeat type names in `@param`. (PR4036, PR4884, PR4914.)
- [ ] **No heap allocation under `log_sys.latch.wr_lock()`** or other hot latches. Pre-compute strings and cache. (PR4405.)
- [ ] **`mtr_t::log_file_op()` is not directly callable** — go through `mtr_t::name_write()` or other higher wrappers. (PR5018.)
- [ ] **Hold `dict_sys` latch only for the SQL parser invocation**, not across transaction commit. Don't forget `lock_sys_tables(trx)` after creating the transaction. (PR4884, PR4936.)
- [ ] **AMD64 6-register parameter budget**: if you add a 7th parameter, restructure (e.g. pass `const dict_index_t&`, use `st_::span<const char>` for `(ptr, len)` pairs). (PR4746, PR4887, PR4884.)
- [ ] **Prefer existing return-code encoding** (`DB_SUCCESS_LOCKED_REC`, etc.) over adding an out-param. (PR4884.)
- [ ] **No `std::string` in InnoDB** — use `my_printf_error` / `%.*s` / in-place buffers. Heap fragmentation cost is real. (PR4342.)
- [ ] **No 32-bit torn reads** for new `SHOW GLOBAL STATUS` `ulonglong` vars on IA-32. Route through `export_vars` or `Atomic_relaxed<lsn_t>`. (PR4405.)

## API / compatibility

- [ ] **Don't change wire format / on-disk format ordering** for downgrade compatibility. `unordered_map` iteration is non-deterministic and breaks this. (PR4430.)
- [ ] **`information_schema` column widths** stay backwards-compatible. Don't widen / rename without a compat flag. (PR4243, PR4573.)
- [ ] **Cross-engine features belong above the engine layer** (e.g. vector / HL indexes). Don't put the check inside one engine. (PR4706.)
- [ ] **Don't reuse privileges** (FEDERATED ADMIN, SUPER) for new functionality — mint a new privilege. (PR4743.)

## Things that may pause review

- [ ] You replied to the previous review. If you pushed fixes, **explicitly re-request review** in the GitHub UI — reviewers do not auto-notice new pushes. (PR4793.)
- [ ] You're attributing co-authored work correctly (`git commit --amend --author "Name <email>"` for patches applied from JIRA / mailing list). Stripping author credit is treated as a hard policy violation. (PR4425, PR4688.)
- [ ] PR title and description match what the patch actually does. The PR title is **not** the commit title — both must be correct. (PR4447, PR4883, PR4889.)
- [ ] No "AI-driven" review noise in the PR (especially copilot, gemini comments not validated by humans). Senior maintainers will explicitly ignore those — and will reject contributors who paste LLM-generated arguments back at them. (PR4589, PR4869, PR4938.)
