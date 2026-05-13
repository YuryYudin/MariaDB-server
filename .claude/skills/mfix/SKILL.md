---
name: mfix
description: Use when the user references an MDEV bug ticket (e.g. "fix MDEV-23676", "look at https://jira.mariadb.org/browse/MDEV-NNNNN") or asks to investigate a server crash, assertion failure, hang, or regression in this MariaDB tree. Not for new features, improvements, refactors, or documentation-only PRs — those get their own skills.
---

# mfix — End-to-end MDEV bug-fix workflow

Walks a JIRA MDEV bug from `https://jira.mariadb.org/browse/MDEV-NNNNN` to a properly-formatted PR against the right branch with a working regression test and a clean buildbot. Every step is gated — do not advance to the next phase until the current phase's deliverable is in hand.

## When to use

- User says "fix MDEV-NNNNN" / "look at MDEV-NNNNN" / pastes a `jira.mariadb.org/browse/MDEV-…` URL **and** the ticket type is *Bug* / *Crash* / *Regression*.
- User describes a server-side symptom that points at an existing MDEV (assertion failure, crash, wrong result, hang).

**Do not** use this skill for:

- New features → use `mfeature` (planned, not yet written).
- Cosmetic / cleanup-only PRs → use `mcleanup` (planned).
- Pure documentation updates.
- Changes to `libmariadb` / `wsrep-lib` / `extra/wolfssl` / other submodules — those need their own PR in the submodule repo.

## Required reading (load when entering each phase)

The review-guidance documents in `.claude/review/` are the authoritative project rulebook. The Plan phase decides which files apply; load them then. **Do not duplicate their content** in chat — cite them.

### Phase 0 — branch-portable rulebook setup (do this FIRST)

The review docs and the skill itself live on the **main** branch only. They are intentionally **not** backported to release branches (10.6, 10.11, 11.4, 11.8, 12.x), so after the Phase-3 `git checkout origin/<target>` they will not be in the working tree. Set up branch-portable access **before** any branch switch:

```sh
REVIEW_REF="${MFIX_REVIEW_REF:-main}"       # branch/tag where the rulebook lives
WORK_DIR="${MFIX_WORK_DIR:-$HOME/.cache/mfix/$TICKET}"
RULEBOOK_DIR="$WORK_DIR/rulebook"
mkdir -p "$RULEBOOK_DIR"

# Sanity-check the rulebook is available on the chosen ref
git ls-tree "$REVIEW_REF" .claude/review/ >/dev/null 2>&1 || {
  echo "ERROR: .claude/review/ not found on '$REVIEW_REF'." \
       "Set MFIX_REVIEW_REF or run from a repo where it exists." >&2
  exit 1
}

# Cache the rulebook into $WORK_DIR/rulebook/ so it survives branch switches
for f in checklist commit-and-process testing coding-style innodb \
         correctness-and-security api-and-architecture logging-and-errors \
         build-and-cmake anti-patterns README; do
  git show "$REVIEW_REF:.claude/review/$f.md" > "$RULEBOOK_DIR/$f.md" 2>/dev/null
done
ls "$RULEBOOK_DIR"   # verify
```

From this point on, **every reference below to `.claude/review/<file>.md` means `$RULEBOOK_DIR/<file>.md`**. The cached copies are read-only references; they don't change when you switch branches.

If the sanity-check fails: the rulebook is missing from this clone. Either pull from the upstream that has it, or, in a clone where the docs were never committed, the skill is not usable yet — report and stop.

### Files in the rulebook

- `checklist.md` — the pre-PR / pre-merge checklist used at the Commit phase.
- `commit-and-process.md` — branch targeting, commit format, reviewer ownership table.
- `testing.md` — MTR conventions (test header/footer, `DEBUG_SYNC`, `mtr --record`, embedded/Windows guards).
- `coding-style.md` — coding style for any file touched outside InnoDB.
- `innodb.md` — InnoDB sub-dialect (load when touching `storage/innobase/*`).
- `correctness-and-security.md` — buffer/format/sanitizer pitfalls.
- `api-and-architecture.md` — wire/on-disk format compat, where features belong.
- `logging-and-errors.md` — message wording, `sql_print_*`, `%iE`/`%M`.
- `build-and-cmake.md` — load if any `CMakeLists.txt` is touched.
- `anti-patterns.md` — concrete bad patterns to self-screen against.

## Workflow (9 phases, gated)

```
1. Discover    →  JIRA fetched, key facts extracted
2. Plan        →  Target branch, reviewer, test file, prior-fix scan done
3. Branch+build → Debug build of target branch exists locally
4. Reproduce   →  Crash/assertion reproduced; root SQL captured
5. Investigate →  Cause located in source; design decided (pattern-continuity check)
6. Fix         →  Minimal patch applied; reproducer no longer crashes; prior bug still fixed
7. Test        →  Regression test added; wider MTR suite green
7.5. Auto-review →  code-reviewer + silent-failure-hunter agents run; blockers resolved
8. Commit+PR   →  Single squashed commit; checklist.md walked
```

**Stop-gate rule:** if the deliverable for a phase is not in hand, stop and report back. Do not proceed by guessing. Three rationalizations to refuse:

| Rationalization | Reality |
|---|---|
| "I can't repro but I can see the bug from the stack — let me just patch it." | Patch with no repro = no test. Patch without test = won't merge. Stop. Find a repro or report blocked. |
| "The JIRA is sparse but I'll wing it." | Sparse JIRA → ask the user for missing info before burning a build. |
| "10.11 is the default target, so don't bother checking fix-versions." | Wrong target branch is the most common preliminary-review rejection. **Always** verify from `fixVersions`. |

## Phase 1 — Discover

Set up a per-ticket working directory and pull the JIRA via the public REST API (no auth needed):

```sh
TICKET=MDEV-23676
WORK_DIR="${MFIX_WORK_DIR:-$HOME/.cache/mfix/$TICKET}"
mkdir -p "$WORK_DIR"
.claude/skills/mfix/fetch-mdev.sh $TICKET > "$WORK_DIR/jira.json"
```

`fetch-mdev.sh` returns one JSON object per ticket with the fields the rest of this skill assumes: `summary`, `type`, `status`, `resolution`, `fix`, `components`, `labels`, `assignee`, `reporter`, `description`, `comments[]`, `links[]`, `subtasks[]`, `attachments[]`.

### Mine the JIRA payload

```sh
# Headline facts
jq '{key, summary, type, status, fix, components, labels, assignee, reporter}' "$WORK_DIR/jira.json"

# Stack-trace paths (anchor for which files to read)
jq -r '.description' "$WORK_DIR/jira.json" | grep -oE '/?[^ )]+\.(cc|h|c):[0-9]+' | sort -u

# Reproducer SQL blocks
jq -r '.description' "$WORK_DIR/jira.json" | sed -n '/{code:sql}/,/{code}/p; /{noformat[^}]*}/,/{noformat}/p'

# Any regression-introducing commit hash named in the description
jq -r '.description' "$WORK_DIR/jira.json" | grep -oE 'commit [0-9a-f]{40}'

# Comments newest-first — often a newer reproducer than the description
jq -r '.comments | sort_by(.created) | reverse | .[] | "--- \(.author) @ \(.created) ---\n\(.body)"' "$WORK_DIR/jira.json"
```

### Fetch linked AND regression-source MDEVs

The skill says "fetch each linked MDEV" — but `.links[]` only contains JIRA-managed links. A regression-introducing commit mentioned in the description text refers to *another MDEV* that is **not** in `.links[]`. You must look that one up too.

```sh
# Linked MDEVs from .links[]
jq -r '.links[].target' "$WORK_DIR/jira.json" \
  | xargs -I{} .claude/skills/mfix/fetch-mdev.sh {} > "$WORK_DIR/linked.json"

# Regression-introducing commit → its MDEV (the subject line carries it)
for hash in $(jq -r '.description' "$WORK_DIR/jira.json" | grep -oE 'commit [0-9a-f]{40}' | awk '{print $2}'); do
  info=$(git log -1 --format='%H %P %s' "$hash")
  echo "$info"
  # If two parents, the "regression-introducing commit" is a merge — see below.
done
# Then fetch any MDEVs named in non-merge subjects via fetch-mdev.sh.
```

**If the regression-introducing commit is a merge** (two parents), reading the commit itself is not useful — it's an N-file forward-merge with no narrative. Three responses:

1. Look in the JIRA comments for a narrower bisection result the reporter or assignee already posted.
2. `git bisect` between the merge base and the merge parent on the merged-from branch (much smaller scope than the merge).
3. If steps 1–2 aren't tractable, document in the notebook: "regression-introducing commit is a merge; defer narrower bisection to the assignee" and move on. Don't try to read the merge.

### What to capture in the notebook

Write to `$WORK_DIR/notebook.md`:

- **Summary** → use verbatim for commit subject (with `MDEV-NNNNN ` prefix).
- **Assertion / error text** → the exact predicate. Use this for `git log --grep` and as the regression-test name anchor — **not** the file:line tuples, which drift.
- **Reproducer SQL** → inside `{code:sql}…{code}` or `{noformat}…{noformat}`. There may be multiple — collect all.
- **Stack trace** → list of `path/to/file.cc:LINENO`. **Treat line numbers as advisory** — they routinely drift by a few lines vs the current source. The *function* and *expression* are stable; grep by those, not by line number.
- **"Started happening on … after this commit"** → the regression-introducing commit hash + its kind (regular / merge). See merge-handling note above.
- **Comments** with newer reproducers and exact crash revisions — the comment header `Server version: X.Y.Z-MariaDB-debug-log source revision: <hash>` is gold. Note it for Phase 4.

**Phase 1 deliverable**: `$WORK_DIR/notebook.md` covers assertion text, all reproducers (with the comment-supplied ones flagged as more current), stack-trace paths *as approximate anchors*, target `fixVersions`, components, labels, assignee, all linked AND regression-source MDEVs with their statuses, all exact crash revisions named in comments.

## Phase 2 — Plan

Decisions to make, each cross-referenced to a rule file:

1. **Target branch**: `cat VERSION`, then compare to JIRA `fixVersions`. Pick the lowest branch in `fixVersions` that is *still maintained* per https://mariadb.org/about/#maintenance-policy. See [`commit-and-process.md` § Branch targeting](../../review/commit-and-process.md). When in doubt: 10.11 for non-critical bugs; 10.6 only if the ticket is marked critical / crashing-data-loss and the bug reproduces there.
2. **Area expert / final reviewer**: look up the JIRA `components` field against the reviewer table in [`commit-and-process.md` § Reviewer-area lookup table](../../review/commit-and-process.md). E.g. *Temporal Types* → `vuvova`; *InnoDB* → `dr-m`/`Thirunarayanan`; *Replication* → `bnestere`. Cross-check against the JIRA's `assignee` — if there's a conflict, prefer the assignee.
3. **Test home**: based on the components and the files in the stack trace, identify the most likely existing test file. Patterns: `sql/compat56.cc` + Temporal Types → `mysql-test/main/type_time_hires.{test,result}`. `sql/sql_acl.cc` → `mysql-test/main/grant.test` or similar. `storage/innobase/handler/*` → `mysql-test/suite/innodb/t/*`. **Important exception**: when the bug is in *SQL-layer state* (THD, sysvars, parser, ACL) but the crash *happens to fire* inside an engine (e.g. an `ut_ad` in `row0ins.cc` that detects a desync set by `SET transaction_read_only`), the test belongs in `mysql-test/main/` near the SQL-layer code that *creates* the bad state — not in `suite/innodb/`. Ask: "where is the fix going to live?" The test goes near the fix, not near the crash.
4. **Prior fixes to imitate** — find them via:
   ```sh
   # By linked MDEV
   git log --all --oneline --grep='MDEV-29924'
   # By assertion text
   git log --all --oneline --grep='log_10_int\[6 - dec\]'
   # By symptom phrase
   git log --all --oneline --grep='my_time_packed_to_binary'
   ```
   Read those commits — they're often 5-20 lines and they tell you both the fix pattern and the test pattern.
5. **Loaded review-guide files** — pick from the table at top. Always: `checklist.md`, `commit-and-process.md`, `testing.md`. Plus area-specific files based on which directories will be touched.

**Phase 2 deliverable**: a short written plan stating target branch, reviewer, test file, prior-fix commit(s) to imitate, and a fix-direction hypothesis (A/B/C-style options when not obvious — see how MDEV-23676 had three plausible directions).

## Phase 3 — Branch + build

### Prereqs (one-time per machine)

Verify the build toolchain is present:

```sh
cmake --version    # >= 3.12
gcc --version      # >= 9.0  (or clang >= 10)
which ninja        # optional but ~2× faster than make for incremental rebuilds
```

If a fresh machine: install build deps. The simplest path is whatever the project's CI uses:

```sh
# Ubuntu/Debian (matches what .gitlab-ci.yml's fedora job rebuilds against)
sudo apt-get install -y cmake gcc g++ ninja-build \
  libssl-dev libncurses-dev libpcre2-dev bison \
  libsystemd-dev pkg-config libaio-dev libnuma-dev

# Fedora — let yum compute it from the spec file
sudo yum-builddep -y mariadb-server
```

### Configure + build

**Pre-checkout cleanliness check.** Any uncommitted change in the working tree — especially to `.claude/*` — will block the checkout or leak across branches. Stash it:

```sh
if [ -n "$(git status --porcelain)" ]; then
  git stash push -m "mfix $TICKET checkout-stash" --include-untracked
  echo "Stashed working-tree changes; will pop on return to main."
fi
```

Then check out the target branch:

```sh
git fetch --tags origin
TARGET=10.11           # from Phase 2
TICKET=MDEV-23676
git checkout -b ${TARGET}-${TICKET} origin/${TARGET}

BUILD_DIR="../build-${TARGET}-debug"
mkdir -p "$BUILD_DIR"

# Prefer Ninja when available — substantial speedup
GENERATOR=""
command -v ninja >/dev/null && GENERATOR="-G Ninja"

cmake -S . -B "$BUILD_DIR" ${GENERATOR} \
  -DCMAKE_BUILD_TYPE=Debug \
  -DWITH_DBUG_TRACE=ON \
  -DWITH_SSL=system \
  -DPLUGIN_COLUMNSTORE=NO -DPLUGIN_ROCKSDB=NO -DPLUGIN_S3=NO \
  -DPLUGIN_MROONGA=NO -DPLUGIN_CONNECT=NO -DPLUGIN_TOKUDB=NO \
  -DPLUGIN_SPIDER=NO -DPLUGIN_OQGRAPH=NO -DPLUGIN_SPHINX=NO \
  -DPLUGIN_FEDERATED=NO -DPLUGIN_FEDERATEDX=NO \
  -DWITH_WSREP=OFF

# Build minbuild (just enough binaries for mtr). Log to disk so a background
# build is followable from a separate terminal.
cmake --build "$BUILD_DIR" -j"$(nproc)" -t minbuild > "$BUILD_DIR/build.log" 2>&1 &
BUILD_PID=$!
tail -f "$BUILD_DIR/build.log"   # Ctrl-C this when build finishes
```

**Variations** (decide based on the area):

- **InnoDB issue** → add `-DWITH_INNODB_EXTRA_DEBUG=ON`. dr-m's internal combo also disables PerfSchema with `-DPLUGIN_PERFSCHEMA=NO` (rr-record friendly).
- **MSAN-only reproducer** → `-DWITH_MSAN=ON` and rebuild from scratch (sanitizers don't compose with a stale cache).
- **UBSAN-only reproducer** → `-DWITH_UBSAN=ON`.
- **Galera issue** → keep `-DWITH_WSREP=ON` and don't disable PerfSchema.

**Phase 3 deliverable**: `${BUILD_DIR}/sql/mariadbd` exists and is freshly built against the target branch.

## Phase 4 — Reproduce

### Test-file layout (read this first)

- **Tests live in the SOURCE tree**, not the build tree: `mysql-test/main/MDEV_NNNNN.test`.
- The `main` suite uses **no `t/` subdir** — files go directly in `mysql-test/main/`. Secondary suites (`innodb`, `rpl`, `galera`, etc.) use `mysql-test/suite/<name>/t/`.
- `mariadb-test-run.pl` is run from the **build tree's** `mysql-test/` (the build dir contains the configured `mariadb-test-run.pl` and the test `var/` workspace, but reads `.test` files from the source tree).
- On 11.x and newer the driver is named `mariadb-test-run.pl`. On 10.x the canonical name is `mysql-test-run.pl` (with a `mariadb-test-run.pl` symlink). Use whichever is present; they're the same program.
- **Do NOT pass `--debug-server`** in our standard flow. That flag is for environments with both a release `mariadbd` and a separately-built `mariadbd-debug`; we built `CMAKE_BUILD_TYPE=Debug` so the single `mariadbd` already has debug symbols and assertions. Passing `--debug-server` looks for a non-existent `mariadbd-debug` binary and fails.

### Drop in the reproducer

```sh
cd "$REPO_ROOT"
# Pick suite based on the area:
#   sql/*, default     → mysql-test/main/$NAME.test
#   storage/innobase/* → mysql-test/suite/innodb/t/$NAME.test
#   replication        → mysql-test/suite/rpl/t/$NAME.test
#   galera             → mysql-test/suite/galera/t/$NAME.test

NAME="${TICKET//-/_}"   # e.g. mdev_23676
cat > mysql-test/main/$NAME.test <<'EOF'
--echo #
--echo # MDEV-NNNNN <verbatim summary, one line>
--echo #
<reproducer SQL from JIRA, verbatim, with --disable_warnings / --enable_warnings around it>
EOF

cd "$BUILD_DIR/mysql-test"
./mariadb-test-run.pl --suite=main $NAME
```

(`--debug-server` was already covered in the layout section above — don't add it.)

### Outcomes

| Outcome | Action |
|---|---|
| **Crashes with the same assertion / stack** | Proceed to Phase 5. Save the gdb backtrace from `var/log/` and the abridged stack into `$WORK_DIR/notebook.md`. |
| **Crashes with a *different* assertion** | The reproducer drifted. Try a more recent comment-supplied reproducer; if a *different* assertion fires, **stop and report** — a separate MDEV is likely needed. |
| **Does not crash on target branch** | This is **NOT** evidence the bug is fixed. Newer branches often *mask* a bug while the underlying invariant violation is still in place. **See "Reproducer doesn't fire" below** before drawing any conclusion. |

Reduce the reproducer to its minimal form **before** writing the fix (per [`testing.md` § Minimal repro](../../review/testing.md) — spetrunia is the most insistent reviewer on this). Strip irrelevant columns, joins, optimizer-trace, IFNULLs. Use two rows per table to avoid const-table short-circuits.

### Reproducer doesn't fire — what to do BEFORE concluding "blocked"

A "doesn't crash on target branch" result is a **soft signal**, not a definitive one. Many real, open MariaDB bugs reproduce only on the branch the bug-reporter tested, because newer branches contain unrelated refactors that happen to short-circuit the offending path before it reaches the asserting code. The bug is still real. **Do not declare it fixed.**

Work through these checks in order:

1. **Reality check the JIRA status.** Is the ticket *Closed/Fixed*? If so, fine — bug really is fixed. If it's *Confirmed* or *Open* with an active assignee, the bug exists. The assignee doesn't sit on a non-bug; you're missing something.

2. **Re-check the comments for an exact crash revision.** Reporters often paste headers like
   `Server version: 10.6.23-MariaDB-debug-log source revision: 49febfad21ab6131a4ca421cd08fb25107d42509`.
   That revision is gold — it's a known-crashing checkpoint. Note it.

3. **Build the branch where the reporter saw the crash, not just `fixVersions[0]`.** A bug listed with `fixVersions = [10.11, 11.4, 11.8]` may currently *only* reproduce on 10.6 (or wherever the last known crash was reported). `fixVersions` describes where the fix **should land**, not where the bug **currently reproduces**. Spin up a parallel build dir for the reporter's branch:
   ```sh
   git checkout -B <reporter_branch>-${TICKET} origin/<reporter_branch>
   BUILD_DIR_ALT="../build-<reporter_branch>-debug"
   # same cmake + ninja as Phase 3
   ```
   Run the reproducer there. If it crashes, the bug is real — you just need a reproducer that survives on `fixVersions[0]`.

4. **If reproducing only on an older branch**: the gap between that branch and `fixVersions[0]` is where the masking change lives. The fix on `fixVersions[0]` will need a reproducer that bypasses that masking. Options:
   - File a comment on the JIRA: "Bug reproduces on `origin/<older>` (rev $(rev)) but not `origin/$TARGET` head. The path is masked at some point in between; the fix on $TARGET will need a different reproducer or a `DBUG_EXECUTE_IF` to force the path."
   - Spend Phase 5 hunting for what masks it on newer branches — sometimes the *masking* is itself a regression candidate worth surfacing.
   - In rare cases the assignee already has a `DBUG_EXECUTE_IF`-based reproducer; ask them.

5. **Only after all of the above** does "this JIRA may already be closeable" become a defensible conclusion. Even then, the right move is to comment on the JIRA with negative-reproduction evidence on **every** affected branch and ask QA, not to silently close.

6. **Never write a defensive patch for a bug you cannot reproduce.** Reviewers will reject it as scope creep, you have no test to verify the fix, and you're papering over a real-but-hidden bug instead of fixing it.

**Phase 4 deliverable**: either (a) a minimal reproducer that crashes (or returns a wrong result) on the branch you'll actually push the fix on — *or* (b) a written-down negative-reproduction notebook that names the branches checked, the revisions tested, and the question to put back to the JIRA assignee.

### Skill anti-pattern from validation run

The first MDEV the skill was tested against was **MDEV-23676**. On the listed `fixVersions[0]` (`origin/10.11.17`), neither reproducer crashed — both returned NULL. **Premature conclusion**: "the bug appears already fixed." **Reality**: the same reproducer crashed deterministically on `origin/10.6.26`, the bug is still real on every branch, and `fixVersions` describes intent not current status. Don't make that mistake. The "target branch ≠ branch where bug currently reproduces" pattern is common for old regression-labelled tickets.

## Phase 5 — Investigate

1. **Read the regression-introducing commit** (named in the JIRA) end-to-end:
   ```sh
   git show <hash>
   ```
2. **Read each prior-fix commit** identified in Phase 2.
3. **Walk up the gdb stack** from the failing assertion. For each frame, ask: who computed the offending parameter? Where did the invariant slip?
4. **Look for sibling code paths that already solve the same problem.** If a related type-handler / Item / operation has been through the same kind of fix, copy its pattern. Example: when fixing `Type_handler_time_common::Item_val_native_with_conversion`, check what `Type_handler_timestamp_common::TIME_to_native` does at the analogous call site — if it already truncates *at the caller*, your Time-side fix should mirror that, not invent a new layer.
5. **Decide between fix options.** Typical patterns:
   - **A. Defensive truncate/clamp** at the inner layer where the invariant is checked. Narrow, low-risk, *but*: low-level primitives often have surprising sign/aliasing/edge cases (e.g. signed-`%` truncation, sentinel-vs-data overloads). Adding logic there frequently introduces a *new* silent bug while masking the *real* upstream defect.
   - **B. Metadata propagation fix at the caller.** Mirrors the way the related prior-fix MDEV solved an adjacent path. Usually correct. Usually what the assignee already considered.
   - **C. Semantic redesign** — e.g. mixing TIME with INT in `GREATEST` should return NULL. Larger scope; **file a separate MDEV** rather than expanding this one ([`api-and-architecture.md` § When to file a separate MDEV](../../review/api-and-architecture.md)).
6. **Pattern continuity is a strong default.** If a previous MDEV for the *same* assertion / *same* invariant was fixed by the *same* assignee using pattern X, X is the strong default for your fix. Picking a different pattern needs explicit justification on the JIRA *before* you implement, not after. Reviewers spot this kind of inconsistency immediately.
7. **Stop-gate: don't pick A just because A is smaller to write.** A is the *operator-easy* option, not the *project-correct* option. Defensive low-level fixes appear ~3× in the 6-month PR-review corpus *and were rejected each time* in favour of upstream fixes (see `.claude/review/api-and-architecture.md` "don't widen utility APIs to accept invalid inputs — fix the caller"). If you are reaching for A while B or C exists, **post your A-vs-B analysis on the JIRA before implementing**.

**Phase 5 deliverable**: a one-paragraph design note saying which fix option you chose, why, and which file(s) and function(s) you plan to change. **If you chose A and a sibling path uses B-style** — record explicitly why A is right *for this case* and why a sibling-pattern B fix would be wrong. If you can't articulate that, the choice is wrong.

## Phase 6 — Fix

Apply the minimal patch. Load the area-specific review file(s) from Phase 2 and self-screen against [`coding-style.md`](../../review/coding-style.md) plus [`anti-patterns.md`](../../review/anti-patterns.md) **before** saving.

Style red flags to self-check (this list is not exhaustive — use [`coding-style.md`](../../review/coding-style.md) as the master):

- C-style cast in C++ code → use `int(x)` or `static_cast<>()`.
- `long` / `ulong` → use `size_t` / `uint64_t` / `int32_t`.
- Whitespace changes in lines you didn't otherwise touch.
- New `noexcept`-missing C++ member function inside `storage/innobase/*`.
- TAB in new code inside `storage/innobase/*`.
- `std::function` / `std::unordered_map` introduced in InnoDB hot paths.
- Format-specifier mismatch (`%llu` for `unsigned long long`; drop the cast).
- Hard-coded buffer size at the `snprintf` call site.

Rebuild and rerun the reproducer:

```sh
cmake --build "$BUILD_DIR" -j"$(nproc)" -t mariadbd   # incremental — ~30s typically
cd "$BUILD_DIR/mysql-test"
./mariadb-test-run.pl --suite=main ${TICKET//-/_}   # no --debug-server
```

**Sanity-probe the *prior* bug.** When the JIRA names a regression-introducing commit (Phase 1), that commit was *fixing* an earlier bug. Your patch is at the boundary of that earlier fix and could silently reintroduce it. Run an ad-hoc test against the prior bug's reproducer (typically findable from `git show <regression-hash>` or the prior MDEV's description):

```sh
# Example for MDEV-23676: the regression-introducing commit fixed MDEV-23525
# ("Wrong result of MIN(time_expr) and MAX(time_expr) with GROUP BY"). Sanity-
# check that fix still holds:
cat > mysql-test/main/${TICKET//-/_}_sanity.test <<'EOF'
CREATE TABLE t1 (id INT, t TIME) ENGINE=HEAP;
INSERT INTO t1 VALUES (1,'10:20:30'),(1,'100:20:30'),(1,'5:00:00');
SELECT id, MIN(t), MAX(t) FROM t1 GROUP BY id;  -- must compare numerically
DROP TABLE t1;
EOF
./mariadb-test-run.pl --suite=main ${TICKET//-/_}_sanity
rm -f mysql-test/main/${TICKET//-/_}_sanity.test   # ad-hoc, don't commit
```

If the prior bug reappears, the choice between options A/B/C from Phase 5 was wrong. Restart Phase 5 with that constraint added.

**Phase 6 deliverable**: the reproducer test passes, the prior-bug sanity probe still produces the correct (post-prior-fix) behavior, and the fix touches the minimum set of files.

## Phase 7 — Test

1. **Delete the Phase-4 ad-hoc test file** before integrating:
   ```sh
   rm -f mysql-test/main/${TICKET//-/_}*.test mysql-test/suite/*/t/${TICKET//-/_}*.test
   ```

2. **Promote the reproducer to a permanent test** in the file identified in Phase 2 (e.g. `type_time_hires.test`, `trans_read_only.test`). **Place it in the right region of the file.** MariaDB test files accumulate region markers like `--echo # End of 10.4 tests`, `--echo # Start of 10.9 tests` over their history; insert your new test in the region for your target branch:
   - If your target is `10.6` and the file has `End of 10.4 tests` but no `End of 10.6 tests` yet → insert after the `End of 10.4 tests` block and add a new `End of 10.6 tests` block after your test.
   - If `End of <your_branch> tests` already exists → insert just before it.

   ```sh
   $EDITOR mysql-test/main/<file>.test
   # Mirror the surrounding style. If the file uses 3-line frames
   # (--echo # / --echo # End of M.m tests / --echo #), use those. If
   # it uses bare single-line markers, match those. Don't mix.
   ```
   Test-body conventions (per [`testing.md`](../../review/testing.md)):
   - `--echo # MDEV-NNNNN <title>` header using `--echo`, not `#`.
   - `--echo # End of <maj.min> tests` is the *marker*; the surrounding `--echo #` blank-comment frame is project-normal and acceptable. **Match the file's existing style.**
   - Newline at end of file.
   - `--source include/not_embedded.inc` (or `--loose-` prefix the options) if the test needs features embedded mode lacks.
   - No `sleep` — use `DEBUG_SYNC` / `--ping` / `wait_condition`.

3. **`mtr --record`** to generate the result block:
   ```sh
   cd "$BUILD_DIR/mysql-test"
   ./mariadb-test-run.pl --record main.<file_basename>
   cd -
   git diff mysql-test/main/<file>.result   # eyeball the new block
   ```

4. **Run the wider local suite** matching the changed area. Enumerate candidates first because test names vary across branches:
   ```sh
   # List candidates by keyword:
   ls mysql-test/main/ | grep -iE 'time|group|func_group|type_time'
   # or use prefix selectors:
   #   ./mariadb-test-run.pl --suite=main --do-test=type_time
   #   ./mariadb-test-run.pl --suite=main --do-test=func_time
   ```
   Then run the selected tests:
   ```sh
   cd "$BUILD_DIR/mysql-test"
   ./mariadb-test-run.pl --suite=main \
     func_time func_time_hires func_time_round \
     type_time type_time_hires type_time_round type_time_6065 \
     type_timestamp type_timestamp_hires type_timestamp_round \
     datetime_456 type_temporal_mariadb53 \
     func_group func_group_innodb group_by group_by_innodb group_by_null
   # For InnoDB fixes, swap in:
   #   ./mariadb-test-run.pl --suite=innodb --do-test=<keyword>
   ```
5. **Re-record any drifted `.result` files**. Do not hand-edit. Verify each diff is plausible. For each drifted test:
   ```sh
   ./mariadb-test-run.pl --record main.<drifted_test_name>
   git diff mysql-test/main/<drifted_test>.result
   ```
   A drifted result that you can't immediately explain is a *yellow flag* — your patch may be affecting something you didn't intend. Investigate before re-recording.

**Phase 7 deliverable**: the new regression test is in the right file, in the right region, with the right framing style; its `.result` is recorded; the wider local suite is green; no other test's `.result` was silently rewritten.

## Phase 7.5 — Automated review (mandatory, before commit)

A single-operator walk through Phases 5–7 is not enough. Senior reviewers consistently catch issues a same-session walk-through misses — especially:

- Correctness bugs in *the fix itself* (a defensive truncate that silently corrupts negative-input boundary cases; a metadata-propagation fix that copies the wrong field).
- Architecture mismatches with how the *adjacent* code path solves the same problem.
- Replication / on-disk / wire-format byte divergence from the canonical writer for the "same" logical value.

Stage the changes (don't commit yet — Phase 8 wraps that), then delegate to the [`mreview`](../mreview/SKILL.md) skill, which orchestrates the agent dispatch, severity merging, and verdict synthesis:

```
Skill mreview --staged --standard --no-profile --no-post
```

That invocation runs `code-reviewer` + `silent-failure-hunter` in parallel against the staged diff, with the cached rulebook from `$RULEBOOK_DIR/`. Combined wall-time ~7 minutes. The report lands at `$HOME/.cache/mreview/<timestamp>/report.md` and the chat summary is printed inline. See `mreview/SKILL.md` for what the tiers and `--no-profile` flag do.

**Read the report before Phase 8.** Categorise findings by severity:

| Severity | Action |
|---|---|
| **Blocker** (correctness, replication, architecture rejection) | Stop. Go back to Phase 5 with the finding as a new constraint. Do not commit. |
| **Important** | Apply or document why not. If documenting, add a comment in the code or a note in the commit-message body. |
| **Nit** | Apply if cheap; otherwise note for follow-up. |

Common patterns the agents catch that humans miss:

- Packed-integer arithmetic that's incorrect for negative inputs (signed `%`/`>>` interaction).
- Bytes-on-disk that differ from what the canonical field writer produces for the same logical value (replication divergence; `cmp_native` short-circuits on `memcmp`).
- The "sibling type-handler already does the right thing at the caller level" architecture call.
- The "your test only exercises the no-crash path, not the produced-value-correctness path" coverage gap.

**Phase 7.5 deliverable**: `mreview` returned a verdict; all blockers resolved; remaining important/nit items recorded in a follow-up notebook (`$WORK_DIR/review-followups.md`) or addressed in code. If the verdict is `request-changes`, **do not proceed to Phase 8**.

## Phase 8 — Commit + PR

```sh
git add <changed files>
git diff --cached            # final read-through
git commit -m "$(cat <<'EOF'
MDEV-NNNNN <verbatim summary from JIRA, ≤70 chars>

<2-4 paragraph body, ≤72 chars per line>
<what was wrong, what causes it, what the fix does>
<reference to the regression-introducing MDEV and any prior partial fix>
EOF
)"

# Verify the message format
git log -1 --format='%s' | awk '{print "subject: " length " chars"}'   # should be ≤ 70
git log -1 --format='%b' | awk 'length>72{print "BODY LINE " NR ": " length " chars (too long)"}' | head
# (silent output means all body lines ≤ 72 ✓)
```

Then walk [`checklist.md`](../../review/checklist.md) end-to-end. Common things you'll catch in this pass:

- Forgot to remove the ad-hoc `t/MDEV_NNNNN.test` test file from the build dir before adding the real one.
- Whitespace-only changes in nearby lines.
- Bundled an unrelated cleanup into the same commit (split it out).
- Forgot to `git push --force` to the same branch / forgot to re-request review in GitHub UI.

**Phase 8 deliverable**: a single rebased commit on the correct target branch, with a CODING_STANDARDS-compliant message, ready to push. If you have permission to open a PR (`gh pr create`), use the JIRA summary as the PR title and reference the MDEV link in the body.

## Common rationalizations to resist

| Rationalization | Counter |
|---|---|
| "I'll skip Phase 1 — the user already pasted the URL." | Pasting a URL is not the same as parsing the description, fix-versions, comments, and linked MDEVs. Run the curl. |
| "The regression-introducing commit is mentioned but I don't need to read it." | You will end up reimplementing one of the things it intentionally changed. Read it. |
| "Phase 4 (reproduce) is optional — I can see the bug from the stack." | No reproducer = no test = won't merge. Reproduce or stop. |
| "I'll write the test after the fix to save time." | Tests-after answer "what does this do?" Tests-first answer "what should this do?" Write the failing test, then make it pass. |
| "Phase 7's wider-suite run takes too long; I'll let buildbot find any drift." | Letting buildbot find drift wastes 24-72 hours per cycle. Run the related suites locally. |
| "I'll skip the checklist walk-through — I've read it before." | The checklist is the muscle-memory for ~30 PR-rejection causes. Walk it every time. |
| "10.11 is the obvious target." | Verify from `fixVersions` every time. Wrong target = "please rebase to X" preliminary-review hit. |
| "The reproducer doesn't crash on my target branch, so the bug is fixed." | Wrong on two counts: `fixVersions` says where the fix *should land*, not where the bug *currently reproduces*; older branches commonly still crash when newer branches have refactor-masked the path. **Always test the branch named in the latest crash-report comment.** See *Phase 4 → Reproducer doesn't fire*. |
| "The JIRA's Confirmed status is old — maybe it really is fixed." | If the assignee is a senior maintainer they haven't been sitting on a non-bug for months. Trust the JIRA state more than your absent reproducer. |
| "Option A is smaller, I'll just do A and skip the JIRA discussion." | "Smaller" is operator-easy, not project-correct. Defensive low-level fixes appear in the 6-month PR-review corpus *3× and were rejected each time*. If the sibling type-handler already does B at the caller (`Type_handler_timestamp_common::TIME_to_native` does `tm.trunc(decimals)` at `sql_type.cc:9363-9374`), B is required for the Time path too. Post your A-vs-B analysis on the JIRA before implementing. |
| "Phase 7.5 (automated review) is overkill — I read my own diff carefully." | Real measured outcome: on the MDEV-23676 dry-run, my Phase-5-through-7 walk produced a fix that introduced **a silent data-corruption bug for negative TIME values** (verified numerically), a **replication byte-divergence bug**, and **violated my own documented `api-and-architecture.md` rule**. The `pr-review-toolkit:code-reviewer` + `:silent-failure-hunter` agents in ~7 min flagged all three. Skipping 7.5 = guaranteed reviewer-reject. |
| "I'll write the regression test against the bug's symptom, not the fix's edge cases." | Reproducing the crash is necessary; covering the *fix's* edge cases is what makes the test catch your-own-future-introduced bugs. A defensive truncate needs a negative-input test. A metadata-propagation fix needs a precision-mismatch test. The bug's reproducer alone doesn't exercise these. |

## Red flags — stop and reconsider

- You're about to push without having reproduced the bug locally.
- You're modifying a `*lex.cc` / `*yacc.cc` generated file directly.
- You're bumping a submodule (`libmariadb`, `wsrep-lib`, etc.) as part of the fix.
- Your patch removes a `DBUG_ASSERT` rather than fixing the invariant the assertion documented.
- Your patch silences a UBSAN / MSAN warning rather than fixing the underlying issue.
- You're about to widen a utility function's contract to accept invalid input so a caller works.
- Your patch is touching files in 3+ unrelated subsystems.
- The MDEV mentions wire format / on-disk format compatibility.

If any apply: stop, re-read the relevant review-guide file, and either redesign or report back to the user before continuing.

## Quick reference (one screen)

| Phase | One-liner |
|---|---|
| 1. Discover | `curl jira.mariadb.org/rest/api/2/issue/$T \| jq ...` |
| 2. Plan | Target branch from `fixVersions`; reviewer from components → `commit-and-process.md`; test home from stack paths; prior fix via `git log --grep`. |
| 3. Branch+build | `git checkout -b $T origin/$BRANCH`; out-of-source Debug build with plugins disabled for speed. |
| 4. Reproduce | Drop reproducer at `mysql-test/main/$T.test` (source tree); from `$BUILD_DIR/mysql-test/` run `./mariadb-test-run.pl --suite=main $T` (NO `--debug-server`); reduce. |
| 5. Investigate | Read the regression commit + prior fixes; pattern-continuity check (if prior fix used B-style, B is the strong default); pick A/B/C; design note. |
| 6. Fix | Minimal patch; self-screen against `coding-style.md` + `anti-patterns.md`; rerun reproducer **and** the prior-bug sanity probe. |
| 7. Test | Promote to permanent test; `mtr --record`; wider suite green locally. |
| 7.5. Auto-review | `Agent(pr-review-toolkit:code-reviewer ...)` + `Agent(pr-review-toolkit:silent-failure-hunter ...)` in parallel; resolve all blockers before Phase 8. |
| 8. Commit | Single commit, MDEV-NNNNN subject; walk `checklist.md`; force-push. |
