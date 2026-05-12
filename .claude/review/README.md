# MariaDB Review Guide

A set of code-review guidance documents distilled from **319 pull requests** that closed/merged against `MariaDB/server` between **2025-11-12 and 2026-05-12** (~3,500 review comments). Every rule here is derived from a real reviewer comment; almost every rule cites the originating PR.

Use these documents both ways:

- **Before pushing a commit or opening a PR** — run through the [pre-PR checklist](checklist.md) and the deep-dive files relevant to the area touched. Most "preliminary review" comments from `gkodinov` will be pre-empted if you do.
- **When reviewing someone else's code** (or asking Claude to review) — load the topic file(s) corresponding to the changed paths. Each rule has a *severity* (blocker / important / nit) so triage is straightforward.

## Files

| File | Scope |
|---|---|
| [`checklist.md`](checklist.md) | Quick pre-PR / pre-merge checklist. The 20 highest-frequency blockers. |
| [`coding-style.md`](coding-style.md) | Formatting, naming, operator spacing, switch/case, indentation, comments. Cross-cuts `CODING_STANDARDS.md`. |
| [`correctness-and-security.md`](correctness-and-security.md) | Buffer/length validation, format specifiers, NULL handling, signed/unsigned, MSAN/UBSAN/ASAN, lifetime, charset/collation, concurrency. |
| [`innodb.md`](innodb.md) | InnoDB-specific rules: `noexcept`, redo-log invariants, `mtr_t` discipline, hot-path optimization, file/page-format compatibility, span<> APIs. |
| [`testing.md`](testing.md) | MTR test-writing conventions: structure, headers, `DEBUG_SYNC`, embedded/Windows guards, `mtr --record`, common include scripts, test reduction. |
| [`api-and-architecture.md`](api-and-architecture.md) | API design choices the project enforces: error codes vs out-params, internal containers, plugin services, where features belong, on-disk/wire-format compatibility. |
| [`logging-and-errors.md`](logging-and-errors.md) | Error message wording, `sql_print_*` vs `ib::logger`, error code selection, `%iE`/`%M` for errno, identifier escaping. |
| [`build-and-cmake.md`](build-and-cmake.md) | CMake conventions, portability (Windows, FreeBSD, musl, ARM), sanitizer flags, third-party submodules. |
| [`commit-and-process.md`](commit-and-process.md) | Commit message format, branch targeting, squash/rebase rules, CLA, two-stage review, reviewer ownership, AI-disclosure expectations. |
| [`anti-patterns.md`](anti-patterns.md) | Catalogue of concrete bad patterns caught in the 6-month window, with PR references and the fix the reviewer wanted. Useful for self-screening. |

## How the project reviews

Reading the data, the dominant review pattern is:

1. **Preliminary review** by a triage maintainer (almost always `gkodinov`, occasionally `grooverdan` / `bnestere` / `spetrunia`). Catches commit-message issues, CLA, branch targeting, missing tests, build-bot failures, and style.
2. **Area expert ("final reviewer")** for the actual substance:
   - **InnoDB** → `dr-m` (Marko Mäkelä), `Thirunarayanan`
   - **Optimizer / parser / SQL semantics** → `vuvova` (Sergei Golubchik), `spetrunia` (Sergey Petrunia)
   - **DDL / ALTER / partitions** → `midenok`
   - **Replication / binlog / GTID** → `bnestere`, `andrelkin`, `knielsen`
   - **Galera / WSREP** → `janlindstrom`, `sjaakola`
   - **ACL / vector / charset / general server core** → `vuvova`
   - **Client / build / packaging / portability** → `svoj`, `grooverdan`, `vaintroub`
   - **Windows / byte-order / threadpool / build** → `vaintroub`
3. **Two approvals** are expected for merge. A single LGTM is rarely enough.
4. **CLA bot must be green** before final review starts. **Build-bot must be green** before merge — including Windows, MSAN, UBSAN, and ASAN runs.
5. **No reply for ~3 weeks** → PR is moved to draft or closed. Re-opening is fine.

## Severity legend used throughout

| Severity | What it means in this corpus |
|---|---|
| **blocker** | Reviewer will request changes / hold approval until fixed. Recurring real bugs, security, ABI/wire-format breakage, CLA, missing tests. |
| **important** | Reviewer will ask for the change but may approve conditional on a follow-up. Style with strong consensus, test convention, log wording. |
| **nit** | Pure preference. Reviewer mentions it but it doesn't block merge. |

## Project authority docs (read these first)

- [`CODING_STANDARDS.md`](../../CODING_STANDARDS.md) — formatting + spacing + naming + commit message rules.
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) — high-level contributor guide.
- [`CLAUDE.md`](../../CLAUDE.md) — Claude-Code-specific environment notes.

The review docs in this directory **extend** those — they capture the *unwritten* rules and high-frequency blockers that those documents don't state directly.

## Provenance & regeneration

The 11 docs in this directory were distilled from 6 months of real PR feedback. To preserve a lightweight audit trail without bloating the repo, only the human-readable intermediates and the regeneration scripts are kept in tree:

- `.claude/pr-research/findings/chunk_{00..04}.md` — per-chunk findings from the 5 parallel analysis agents, before synthesis. Useful if you want to verify a rule against the underlying agent output.
- `.claude/pr-research/fetch_pr.sh` — fetches `reviews`, `pulls/N/comments`, `issues/N/comments`, and PR meta for a given PR number into `raw/pr_N.json`.
- `.claude/pr-research/build_extracts.sh` — normalises the per-PR JSON into `extracts/all_comments.jsonl` (one comment per line, with author / association / path / line / body / diff_hunk).

The bulk data (319 raw GitHub-API dumps, ~37 MB of JSONL extracts, PR-inventory window files) is **not** committed — it would go stale on the next review and adds noise to `git log`. To regenerate after a future review window:

1. List substantive PRs for the new window via `gh pr list --repo MariaDB/server --state merged --search "merged:YYYY-MM-DD..YYYY-MM-DD" ... ` in 2-week chunks (the GraphQL endpoint times out on bigger spans).
2. `cat prs_to_fetch.txt | xargs -P 8 -I{} ./fetch_pr.sh {}` to repopulate `raw/`.
3. `./build_extracts.sh` to produce `extracts/all_comments.jsonl`.
4. `split -n l/5 -d --additional-suffix=.jsonl extracts/comments_filtered.jsonl extracts/chunk_` and re-dispatch 5 parallel analysis agents over the chunks (the prompt template is captured in the original commit history).
5. Re-synthesize into `.claude/review/*.md`.
