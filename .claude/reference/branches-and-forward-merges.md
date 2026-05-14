---
applies-to: main
last-verified: 2026-05-14
source-of-truth: .claude/review/commit-and-process.md, git refs, https://mariadb.org/about/#maintenance-policy
---

# Branches and forward-merges

How MariaDB uses its release branches and the forward-merge workflow.

## 1. The branch policy

MariaDB ships from `main` plus several LTS and stable release branches.
**Bug fixes land on the oldest still-maintained branch where the bug
reproduces** and are *forward-merged* up the chain to `main` — not
cherry-picked. The merge history is the authoritative record that a fix
reached a given branch. **Features land on `main` only.** Cleanup / test
enhancements may target the branch where the relevant feature was introduced.
The maintained set drifts over time; the canonical list lives at
<https://mariadb.org/about/#maintenance-policy>. Release team owns the
forward-merge schedule.

## 2. Currently-maintained branches

Verified against `git branch -r` and `VERSION` on **2026-05-14**. This table
is date-sensitive — re-verify at every refresh.

| Branch  | Status      | Marketing version |
|---------|-------------|-------------------|
| `10.6`  | LTS         | 10.6.x            |
| `10.11` | LTS         | 10.11.x           |
| `11.4`  | LTS         | 11.4.x            |
| `11.8`  | stable      | 11.8.x            |
| `12.0`  | stable      | 12.0.x            |
| `12.1`  | stable      | 12.1.x            |
| `12.2`  | stable      | 12.2.x            |
| `12.3`  | stable      | 12.3.x            |
| `main`  | development | 13.0.x (per `VERSION`, maturity `gamma`) |

Older branches (`10.5` and below, `11.0`–`11.3`, `11.5`–`11.7`) still exist
as refs but are unmaintained — do not target them.

## 3. The forward-merge chain

```
10.6 → 10.11 → 11.4 → 11.8 → 12.0 → 12.1 → 12.2 → 12.3 → main
```

Each arrow is a `git merge` from the lower branch into the next-higher one.
Order is strict. Skipping a branch creates a **merge skid**: the next merge
inherits an unresolved conflict, and the dropped branch silently misses the
fix until the skid is unwound.

## 4. "Where does this fix belong?" — decision tree

```
Does the bug exist on `main`?
├── No  → Probably already fixed. Verify, then close JIRA.
└── Yes
    ├── New feature, or cleanup with no user-visible bug? → main only.
    ├── Security fix? → https://mariadb.org/about/security-policy/ — NOT public.
    └── Bug fix → oldest maintained branch that reproduces:
        10.6  → 10.11  → 11.4  → 11.8  → 12.0…12.3  → main
```

Find the introducing commit
(`git log --oneline -- <touched-file> | head -50`); target the first release
branch containing it. Reviewer shorthand: "10.11 is the default for
non-critical bugs; 10.6 only for critical / crashing." See
[`commit-and-process.md` §"Branch targeting"](../review/commit-and-process.md)
for cited examples (PR4569, PR4534, PR4606, PR4441, PR4446, PR4731, PR4913,
PR5007).

## 5. Forward-merge mechanics

Release-team workflow (agents should recognise it, rarely drive it):

```sh
git checkout 11.4 && git pull
git merge --no-edit origin/10.11    # resolve conflicts, then push
```

Real examples (`git log --merges --grep='^Merge'` for fresh ones):
`e13d89949c2 Merge 12.3 into main`, `b70e0810692 Merge branch '11.8' into
12.3`, `7598e4e95d2 Merge branch '10.11' into 11.4`,
`6828ff7390a Merge branch '10.6' into 10.11`.

Subject: `Merge <source> into <target>` (or `Merge branch '<source>' into
<target>`). Body is **empty** by default — add text only for a non-obvious
conflict decision.

## 6. Conflict-resolution norms

- **Keep both fixes** when the same line was touched for different reasons
  (lower had a bug-fix; upper had a refactor).
- **Take the newer branch's version** of rewritten code — older edits may
  be incompatible with the newer architecture.
- **Never introduce new logic in a forward-merge** — new code goes into a
  separate follow-up commit on the target branch.
- **Empty merge commits are OK** and are the default.
- **Never `git rebase` for a forward-merge** — it loses merge history; the
  release team rejects this. (Inverse of the PR rule: PRs rebase,
  forward-merges merge.) See
  [`commit-and-process.md`](../review/commit-and-process.md) §"Branch
  targeting" and §"Rebase, don't merge".

## 7. When to involve the release manager

- Non-trivial conflict where the right side is unclear.
- Target-branch CI breaks on the merge commit (beyond known-flaky tests).
- A merge would need to **drop** a fix entirely — usually means the fix
  never belonged in the lower branch; revisit targeting.
- Cross-branch `.result` / `.rdiff` divergence: lower-branch tests pass but
  the result-file matrix breaks on the higher branch.

## 8. Common forward-merge mistakes

- **Skipping a branch** → merge skid.
- **Resolving a conflict by deleting just-added code** → silently reverts
  the fix; merge looks clean but the fix is gone.
- **Targeting `main` for a bug that exists on 10.6** → forces re-target or
  back-port (PR4569, PR4534, PR4606, PR4731).
- **Mixing a forward-merge with a new fix in one commit** → non-mechanical
  and unverifiable.
- **`git rebase` instead of `git merge`** → release team rejects on sight.
- **Merge commits inside a PR** → PRs are rebase-only
  (`commit-and-process.md` §"Rebase, don't merge": PR4703, PR4508, PR4658).
  Rebase applies to *PR commits*, **not** to release-team forward-merges.

## 9. See also

- Root [`CLAUDE.md`](../../CLAUDE.md) §"Working with the tree" — short
  branch-policy summary.
- [`commit-and-process.md`](../review/commit-and-process.md) §"Branch
  targeting", §"Rebase, don't merge" — formal rules with cited PRs.
- `glossary.md` §"forward-merge chain", §"`VERSION` file", §"maintained
  branches" — companion term definitions.
- `.claude/playbooks/forward-merge.md` (Phase 3) — step-by-step recipe.

## 10. How this doc was built

- Branch list: `git branch -r | grep -E 'origin/(10|11|12)\.[0-9]+$'` plus
  `cat VERSION` on 2026-05-14.
- Merge examples: `git log --oneline --merges --grep='^Merge' -30`.
- Policy: distilled from `commit-and-process.md` §"Branch targeting", root
  `CLAUDE.md` §"Working with the tree", and the maintenance-policy URL.

**Date-sensitive**: §2 and §3 drift as branches retire / open. Re-verify at
every refresh.
