---
applies-to: main
last-verified: 2026-05-14
source-of-truth: .claude/reference/branches-and-forward-merges.md, .claude/review/commit-and-process.md
---

# Playbook: Forward-merge between maintained branches

**Use when:** a bug fix has landed on an older maintained branch (e.g. `10.6`) and you need to propagate it up the chain — `10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → main` — by mechanical `git merge`, not cherry-pick.
**Skip if:** the fix needs reshaping because surrounding code diverged (that's a forward-*port* — a separate commit on the newer branch, **not** a merge), or the conflict is non-mechanical (escalate to the release manager — see step 5 and §7 of `branches-and-forward-merges.md`).
**Typical effort:** 5–15 minutes per chain step when clean; can blow up to hours per step when an old fix touches code that was rewritten on newer branches.

## Overview

A *forward-merge* is the canonical way MariaDB propagates bug fixes between maintained branches. The merge graph itself is the authoritative record that a fix reached each branch — cherry-picks would lose that record, so policy is "fixes land on the oldest reproducing maintained branch and are merged up." Each arrow in the chain is a real `git merge` commit with subject `Merge <source> into <target>`. See [`.claude/reference/branches-and-forward-merges.md`](../reference/branches-and-forward-merges.md) §"The forward-merge chain" for the chain and §"Forward-merge mechanics" for the policy.

This playbook is the *procedure* for executing one chain step. The release team owns the schedule; agents may be asked to perform a step or unblock a stuck one. Inverse rule of thumb: **PRs rebase, forward-merges merge** — see [`commit-and-process.md`](../review/commit-and-process.md) §"Rebase, don't merge". Mixing those up gets a merge rejected on sight.

## Files you'll touch (with role)

| File / area | Role |
|---|---|
| Working tree, conflict markers | Where you resolve conflicts. |
| `.gitlab-ci.yml` | **Don't take from the source branch.** CI config is intentionally branch-specific (root `CLAUDE.md` §"CI"). Resolve to the receiving branch's version. |
| `VERSION` | **Don't take from the source branch.** Each branch encodes its own marketing version + maturity. Keep the receiving branch's. |
| Submodules (`libmariadb`, `wsrep-lib`, `extra/wolfssl`, `storage/rocksdb`, `storage/maria/libmarias3`, `storage/columnstore`) | Submodule SHAs are branch-specific. Resolve to the receiving branch's pinned SHA unless the release manager says otherwise. |
| `mysql-test/<suite>/r/*.result`, `*.rdiff` | May legitimately differ across branches. Re-record only if behaviour actually changed; otherwise prefer the receiving branch's expected output and let MTR confirm. |
| Generated files (`sql_yacc.cc`, `lex_hash.h`, …) | Live only in the build dir; never appear in a merge. Ignore. |

## Steps (numbered, ordered)

1. **Confirm the chain order.** The maintained set drifts; re-check before each chain step:

   ```sh
   git fetch origin
   git branch -r | grep -E '^  origin/(10\.|11\.|12\.)[0-9]+$' | sort -V
   ```

   Cross-reference [`branches-and-forward-merges.md`](../reference/branches-and-forward-merges.md) §"Currently-maintained branches". **Skipping a branch in the chain causes a merge skid** — the next merge inherits unresolved conflict and the dropped branch silently misses the fix.

2. **Identify what's outstanding on the source branch.** The source is the next-lower maintained branch; the receiving branch is one step higher in the chain.

   ```sh
   # Example: forwarding 10.6 -> 10.11
   git log origin/10.6 ^origin/10.11 --oneline | head -20
   ```

   If this is empty, there's nothing to forward-merge — stop. If it lists unexpected commits (features, refactors), pause and check with the release manager: a forward-merge isn't the right vehicle for new logic.

3. **Check out the receiving branch and fast-forward it.** Never merge into a stale local branch — that resurrects already-resolved conflicts.

   ```sh
   git checkout 10.11
   git pull --ff-only origin 10.11
   ```

   If `--ff-only` refuses, your local branch has diverged — reset it or work on a fresh clone. Don't paper over with a merge.

4. **Perform the merge with an empty body by default.**

   ```sh
   git merge --no-edit origin/10.6
   ```

   `--no-edit` keeps the subject as `Merge 10.6 into 10.11` and the body empty. **Empty body is the expected default** for a mechanical merge; reviewers actively prefer it (`.claude/reference/branches-and-forward-merges.md` §"Forward-merge mechanics"). Only add a body when a conflict decision is non-obvious — see step 5 and the `6660d0bdd7c` example below.

5. **Resolve conflicts (if any) using these norms.** Authoritative source: [`branches-and-forward-merges.md`](../reference/branches-and-forward-merges.md) §"Conflict-resolution norms".

   - **Keep both** when the same line was touched for different reasons on each side (lower branch had a bug-fix, upper branch had a refactor — both still apply).
   - **Take the newer branch's version** when the lower-branch code has been rewritten upstream; the older edit is incompatible with the new architecture.
   - **Don't introduce new logic in a merge commit.** New code lands as a separate commit on the receiving branch — never inside the merge. A merge with new logic is non-mechanical and unverifiable, and bisect will blame the merge for issues unrelated to the conflict resolution.
   - **Don't silently drop a just-added fix.** If the conflict tempts you to delete the lower-branch change, stop — that erases the fix the merge was supposed to propagate. Either keep both or escalate.
   - **Escalate to the release manager** when: the right side is genuinely unclear; the merge would have to drop a fix entirely (usually means targeting was wrong); the receiving branch's CI breaks on the merge beyond known flakies; result-file matrix diverges across branches (see [`branches-and-forward-merges.md`](../reference/branches-and-forward-merges.md) §"When to involve the release manager").
   - After non-trivial resolution, re-run tests (step 6) before committing.

   When a body *is* needed, keep it to one or two lines naming what you decided and why. Real example: commit `6660d0bdd7c Merge branch '12.3' into 13.0` carries the body "changed deprecation version for wsrep_slave_FK_checks, because it was just deprecated this month" — one sentence explaining a non-obvious choice.

6. **Verify the merge.** First the commit shape:

   ```sh
   git log --merges -1                # subject is "Merge <source> into <target>"
   git log --oneline -5               # the merge sits on top of the receiving branch
   ```

   Then a build sanity check, scoped to the merge size. From a build dir:

   ```sh
   cmake --build . -j$(nproc)         # must compile
   cd mysql-test && ./mtr --suite=main  # plus the affected suite(s)
   ```

   The merge must not break tests that pass on the receiving branch alone. For docs-only / build-system-only merges, a successful configure + build is sufficient. If a test that was green before the merge is now red, you've almost certainly mis-resolved a conflict — go back to step 5.

7. **Push the merge to the receiving branch.**

   ```sh
   git push origin 10.11
   ```

   **Never force-push** to a maintained branch — that rewrites public history (`.claude/review/commit-and-process.md` §"Branch targeting" warns against this). If the push is rejected because someone else merged ahead of you and your merge was **conflict-free**, `git pull --rebase` is OK. If your merge **resolved conflicts**, do **not** rebase the merge commit — abort, fetch, and redo from step 3 so the conflict resolution lives on top of the new tip.

8. **Repeat up the chain.** The receiving branch from step 3 becomes the source for the next step. So `10.6 → 10.11` is followed by `10.11 → 11.4`, then `11.4 → 11.8`, `11.8 → 12.0`, `12.0 → 12.1`, `12.1 → 12.2`, `12.2 → 12.3`, and finally `12.3 → main`. Order is strict; do not skip.

## Examples from past PRs (real merge commits)

Sampled from `git log --merges --grep='^Merge' -50`:

- `e13d89949c2 Merge 12.3 into main` — typical clean top-of-chain merge, empty body.
- `1a144f713ab Merge 11.4 into 11.8` — mid-chain step with empty body.
- `29be734aaf9 Merge 10.6 into 10.11` — bottom-of-chain step, empty body.
- `7c5cac0d515 Merge 10.11 into 11.4` — empty-body chain step.
- `6660d0bdd7c Merge branch '12.3' into 13.0` — non-empty body, one sentence: *"changed deprecation version for wsrep_slave_FK_checks, because it was just deprecated this month."* This is the shape a body should take when one is needed: short, specific, naming the decision.

Subject style varies slightly — `Merge X into Y`, `Merge branch 'X' into Y`, occasionally `Merge X -> Y` — all are accepted. `Merge X into Y` is the dominant form.

## Pitfalls and rejection patterns

- **Skipping a branch in the chain** → merge skid: the conflict reaches the next branch and is harder to resolve there, and the skipped branch silently misses the fix. (`branches-and-forward-merges.md` §"Common forward-merge mistakes").
- **Resolving a conflict by deleting the just-added code from the lower branch** → silently reverts the fix the merge was supposed to deliver. The merge looks clean; the bug returns.
- **Mixing new logic into a merge commit** → makes the merge non-mechanical, hard to bisect, and reviewers will reject. New code = separate follow-up commit on the receiving branch.
- **Using `git rebase` instead of `git merge`** → loses the merge history that's the authoritative record of propagation. Release team rejects on sight. Inverse of the PR rule (`commit-and-process.md` §"Rebase, don't merge": PR4703, PR4508, PR4658) — PRs rebase, forward-merges merge.
- **Taking `.gitlab-ci.yml` / `VERSION` / submodule SHAs from the source branch** → breaks the receiving branch's CI / version string / submodule pinning. Each branch owns its own. (Root `CLAUDE.md` §"CI": "intentionally per-branch — don't merge changes across branches.")
- **Force-pushing a merge commit to a maintained branch** → rewrites public history; catastrophic. If the push is rejected, redo the merge cleanly.
- **Merging into a stale local branch** → resurrects already-resolved conflicts and produces a misleading merge commit. Always `git pull --ff-only` first (step 3).
- **Empty body on a non-mechanical merge** → if you made a real conflict decision, reviewers want a one-line body naming the decision (see `6660d0bdd7c`). Default is empty, but "no body when a decision was made" is the wrong default.
- **Wrong-branch targeting upstream of the merge** → if the fix never belonged on the lower branch (e.g. it was a feature, or the bug doesn't reproduce there), the merge will have to drop it entirely. Re-targeting is cited at PR4569, PR4534, PR4606, PR4731 (`commit-and-process.md` §"Branch targeting"). Catch this **before** starting the merge.

## Validation

After step 6, you should have:

- `git log --merges -1` showing `Merge <source> into <target>` on top of the receiving branch.
- `cmake --build . -j$(nproc)` succeeds.
- `./mtr --suite=main` (plus any directly-affected suite) passes — no regressions vs. the receiving branch tip pre-merge.
- For docs-only or build-only merges, the build step alone is sufficient evidence.

If any of these fail, treat the merge as un-pushed: fix or abort. Don't push first and patch later — that pollutes the chain.

## See also

- [`.claude/reference/branches-and-forward-merges.md`](../reference/branches-and-forward-merges.md) — branch policy, chain order, conflict-resolution norms, release-manager escalation criteria. This playbook is the *procedure*; that doc is the *reference*.
- [`.claude/review/commit-and-process.md`](../review/commit-and-process.md) §"Branch targeting", §"Rebase, don't merge", §"Cross-PR coordination" — formal rules with cited PR comments.
- Root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree", §"CI" — short branch-policy summary, branch-specific CI rationale.
- [`.claude/reference/glossary.md`](../reference/glossary.md) §"forward-merge chain", §"maintained branches", §"`VERSION` file" — companion term definitions.

## How this doc was built

- Real merge commits surveyed via `git log --oneline --merges --grep='^Merge' -30` on 2026-05-14, and `git log -1 --format='%s%n---%n%b' <sha>` to inspect bodies. Used to confirm subject conventions and find a real non-empty-body example (`6660d0bdd7c`).
- Branch list cross-checked with `git branch -r | grep -E '^  origin/(10\.|11\.|12\.)[0-9]+$' | sort -V`, then matched against the maintained set in `.claude/reference/branches-and-forward-merges.md` §"Currently-maintained branches".
- Policy and conflict-resolution norms distilled from `.claude/reference/branches-and-forward-merges.md` and `.claude/review/commit-and-process.md` — not re-derived; cited.
- Deliberately excluded: the "where does this fix belong" decision tree (lives in the reference doc); the full per-PR citation list for branch-targeting mistakes (lives in `commit-and-process.md`); the build-flag matrix (lives in root `CLAUDE.md`).
- **Refresh procedure:** at every `last-verified` bump, re-run the `git log --merges` and `git branch -r` commands above; spot-check that the chain in step 8 still matches `branches-and-forward-merges.md` §"The forward-merge chain"; replace stale merge-SHA examples with fresh ones from the last 30 days.
