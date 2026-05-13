# Commit Hygiene & Review Process

The single biggest source of friction in the corpus. Every external-contributor PR has at least one comment about commit-message format, branch targeting, or squashing.

## Commit message

Authority: `CODING_STANDARDS.md`. Reviewers will refuse to start substantive review until the message conforms.

- **Subject is `MDEV-NNNNN <imperative description>`.** Sergei (`vuvova`) prefers no colon; either form is accepted as long as the MDEV leads.
  - PR4447 spetrunia: "Make the commit title be: `MDEV-38120: Move Json_string and Json_saved_parser_state into sql_json_lib.h`."
  - PR4425 grooverdan: "`MDEV-23893: Reject invalid numerical suffixes` is closer as a function description."
  - PR5007 vuvova: "I personally use `MDEV-12345 ` without a colon. The length of the commit subject is limited, various tools show only a prefix of it."
- **Subject ≤ ~70 chars; body wrapped at 72.**
  - PR4455 svoj: "Please also fix commit message according to https://github.com/MariaDB/server/blob/main/CODING_STANDARDS.md. Specifically lines must be under 72 characters."
- **Body explains what was wrong, what causes it, and what the fix does.** Not "fix bug" or one line.
  - PR4549 gkodinov: "please follow the https://github.com/MariaDB/server/blob/main/CODING_STANDARDS.md#git-commit-messages for the format of the commit message."
  - PR4649 gkodinov: "Please add a better commit message that according to the coding standard: describes what the issue is, how it was fixed and how it was tested."
  - PR4897 spetrunia: "The fix is ok, but the commit comment needs improvement."
  - PR4933 bnestere: "In the commit message where you say 'error on the others' it would be good to extend it with the actual error that is thrown."
- **Use C++ syntax in the body** (`Class::member()`, not `Class#member()`).
- **No license text in commit messages.** Licensing lives in the CLA.
  - PR4703 gkodinov: "remove the license reference from the commit message."
- **No typos.** PR4883 spetrunia rewrote a commit message containing "trum" (`trim` misspelled).
- **PR title and commit subject are different things.** The PR title may be hand-edited; the commit subject is the authoritative one. Both should be MDEV-prefixed.
  - PR4447 spetrunia, PR4883 grooverdan: "On MDEV Title - valgrind was only used towards the end of the bug and its not important because its a warning. Perhaps 'MDEV-32758: TRIM uses memory after freed'."

## Commit structure

- **One logical change per commit.** Squash all review-iteration commits into one before merge. Multi-commit PRs are acceptable only if each commit is independently self-contained.
  - PR4509 vuvova (APPROVED): "looks good, thanks. Would you mind squashing all commits into one? Then I'll merge it."
  - PR4569 vuvova (APPROVED): "Looks good, please squash into one commit."
  - PR4602 gkodinov: "I'd squash the two commits in one."
  - PR4625 gkodinov: "can you please squash all of your commits into a single one and put up a commit message that conforms to CODING_STANDARDS.md?"
  - PR4658 gkodinov: "Great that you managed to do a single commit. Please now add a commit message compliant to CODING_STANDARDS.md."
  - PR4678 gkodinov: "Please don't have multiple commits. Always squash your commits to a single one and update the commit message in the process."
  - PR4737, PR4764, PR4808, PR4829, PR4869, PR4881, PR4889, PR4966, PR4982 — same.
- **Split unrelated changes** into separate commits or PRs. Spelling fixes, formatting, submodule bumps, refactor — separate, please.
  - PR4509 vuvova: "It's mainly important to have COM_CHANGE_USER changes in a separate commit (and they were)."
  - PR4390 vuvova: "I thought you'll remove CHECK and that's it (and also mailx dependency, thanks). But you also used bash arrays, rewrote passwordless root check. Why is all that and why it's in the same MDEV-34902 commit?"
  - PR4998 grooverdan: "obvious bug. But lets put that in a separate commit, maybe even just a separate PR." / "not relevant to the fix of MDEV-39466. Omit and process separately if required."
  - PR4933 bnestere: "Is this just cleanup? The patch should be null-merged into 11.8, so let's keep it as minimal as possible. Though you can do the cleanup as a separate patch if you'd like."
  - PR4557 spetrunia: "What's the above? why in this patch?"
- **No whitespace-only changes** mixed into a fix.
  - PR4633 gkodinov, PR4508 gkodinov, PR4581 spetrunia (×3 PRs).
- **No submodule bumps** unrelated to your patch.
  - PR4829 grooverdan: "Remove submodule updates and .gitattribute additions from this commit."

## Branch targeting

This is a policy-driven decision, not a preference:

- **Bug fixes → lowest still-maintained branch where the bug reproduces.**
  - **10.11** is the current default for non-critical bugs.
  - **10.6** only for critical / crashing bugs (still maintained but more conservative).
  - **main / 12.x** if the bug doesn't exist in 10.11.
- **New features → `main`** (the current GitHub default).
- **Cleanup / test enhancements** may go to the branch where the relevant feature was introduced.

Reviewers:

- PR4569 gkodinov: "please re-base on 10.11. I am still (relatively) new here and it was pointed out to me that only 'critical' bugs currently go to 10.6."
- PR4534 gkodinov: "I'd also rebase on 10.11 at this point. I do not think it's that critical for 10.6."
- PR4606 gkodinov: "Can you re-base to 10.6 please? This is a crashing bug and the jira says it applies to 10.6 onwards."
- PR4441 bnestere: "I think we should put the whole patch into `main` (or `12.3`), it isn't an issue that any users/customers have complained about, and it doesn't have a broader impact. Better not to put those into older/more stable versions."
- PR4446 dr-m: "the bug is quite rare and a possible work-around exists... I think that it is OK not to fix this in the oldest maintained branch (10.6)."
- PR4731 gkodinov: "Please rebase to 10.11: this is enhanced test coverage and as such it should go to the earliest maintained version."
- PR5007 vuvova: "the lowest affected but not older than three years…"
- PR4913 dr-m: "I think that should count as a bug fix and target the earliest major version branch where such fixes are accepted. That would be 10.11."

You can rebase the existing branch and **`git push --force` to the same PR**; do *not* open a second PR for the same change unless the target branch needs to change drastically.

## Rebase, don't merge

- **No merge commits in PRs.** Project policy is rebase-only.
  - PR4703 sanja-byelkin: "Please rebase (we do not need merge dommits) and OK to push."
  - PR4703 sanja-byelkin: "The patch is OK, but please rebase it (we do not need additional merge commits with no sense)."
  - PR4508 grooverdan: "Can you rebase without a merge commit onto the 10.11 branch, squash commits together and force push to the same github branch."
  - PR4658 gkodinov: "The preferred way to update the base branch around here is with rebase... This guarantees that only your changes will [appear]."

## Attribution

- **Attribute upstream authors with `git commit --amend --author "Name <email>"`** when applying someone else's patch — not just by mention in the body.
  - PR4425 grooverdan: "`git commit --amend --author \"Sergei Golubchik <serg@mariadb.org>\"` is a right way to attribute an author. Credit yourself in the body of the message if you want."
- **Submitting another author's patch without credit is a hard policy violation.**
  - PR4688 grooverdan: "you appear to have taken @BjarneDMat's patches from JIRA and submitted them as your own without even an attribution to the author. Can you please credit the author `git commit --author '...' --amend`."

## CLA

External contributors must sign the CLA. Two acceptable choices: **3-clause BSD** or **MariaCLA**.

- **CLA bot must report "CLA signed"** before final review/merge.
  - PR4493, PR4601, PR4605, PR4618, PR4703, PR4712, PR4779, PR4881 — at least 8 PRs blocked on this.
  - PR4881 gkodinov: "sign the CLA please: either pick BSD or MariaCLA."
- **CLA-clicking workflow**: click the "CLA not signed yet" badge on the PR; pick a license; the CLA bot then re-runs and turns green.
- **Reviewers explicitly will not start final review** until CLA bot is green.

## Two-stage review process

This is the dominant workflow for external-contributor PRs:

1. **Preliminary review** (almost always `gkodinov`, sometimes `grooverdan` / `bnestere` / `spetrunia`):
   - Commit message, CLA, branch targeting, missing tests, build-bot failures, basic style.
   - Closes with "LGTM. Please stand by for the final review" or "Please stand by for the final approval."
   - Many PRs see *36+* "preliminary review" headers — it's not personal, it's procedural.
2. **Final reviewer (area expert)** does the substantive review:
   - InnoDB → `dr-m`, `Thirunarayanan`
   - Optimizer / parser / SQL semantics → `vuvova`, `spetrunia`
   - DDL / ALTER / partitions → `midenok`
   - Replication / binlog / GTID → `bnestere`, `andrelkin`, `knielsen`
   - Galera / WSREP → `janlindstrom`, `sjaakola`
   - ACL / vector / general server core → `vuvova`
   - Client / build / packaging / portability → `svoj`, `grooverdan`, `vaintroub`
   - Windows / byte-order / threadpool / build → `vaintroub`

**Two approvals are expected** before merge. A single LGTM rarely merges anything.

- PR5007 vuvova: "you can mention that we try to have two reviewers for every PR."
- PR4913 gkodinov: "please keep working with Marko on the final review."

## Buildbot

- **Buildbot must be green on the full grid before merge** — including Windows, MSAN, UBSAN, ASAN, Galera-required jobs.
  - PR4549, PR4569, PR4590, PR4632, PR4641, PR4658, PR4697 — many.
- **Authors are responsible for chasing platform-specific failures.** Re-record `.result` files, fix MSAN uninit reads, fix Windows path-length issues.
  - PR4869 gkodinov: "buildbot compile still failing. Please have a look."
  - PR4811 gkodinov: "Please address the buildbot issues."
- **Unrelated failures** are filed as separate MDEVs — but enumerate the failures you're claiming to be unrelated.
  - grooverdan: "Lets leave the test failures that are unrelated as JIRA entries…"
- **Don't ship code that breaks `WITH_INNODB_EXTRA_DEBUG=ON`** or other internal-testing combos.

## Re-request review

- **GitHub doesn't auto-notify reviewers** when you push. Explicitly re-request review in the UI after pushing fixes.
  - PR4793 gkodinov: "for future reference, re-request my review in github when you submitted a new changeset. This is what has caused the delay."

## Inactive PRs

- **No reply for ~3 weeks → moved to draft or closed.** Re-opening is welcome.
  - PR4425 gkodinov: "No update for over a month to the PR. I'm closing it. If you feel like resuming the work on it, please re-open."
  - PR4440 gkodinov: "Closing this due to inactivity. Please re-open if you intend to address my comments."
  - PR4881 gkodinov: "There was no reply to my preliminary review from couple of weeks ago. Moving this to 'draft' state. Please move back to 'open' when/if you intend to keep working on it."
- **Senior reviewer may close-and-rewrite** a stalled PR if the change is important and the contributor isn't responding.
  - PR4262 gkodinov rewrote the patch himself and merged via a separate PR.

## JIRA / MDEV

- **Every PR ties to an MDEV ticket.** If you don't have one, reviewers will file it for you, but it takes time.
  - PR4691 gkodinov: "processing on our end would be faster if there was a jira filed and mentioned in the topic. I did that for you now. But it takes some time for me."
  - PR4534 gkodinov: "Please use https://jira.mariadb.org/browse/MDEV-38550 instead of the original one."
  - PR4590 gkodinov: "it also feels like we need a new MDEV for this. Can you please open one with a good description?"
- **Don't submit a PR against an unrelated MDEV.**
  - PR4762 gkodinov: "Please never submit a pull request against an MDEV if you do not intend to solve the mdev."
- **PR title, PR description, JIRA description, and commit message must all match** what the patch actually does.
  - PR4889 gkodinov: "please also update the description of the PR."
  - PR4889 vaintroub: "The only remaining thing is to change the title of the pull request, and the comment."

## Cross-PR coordination

- **Dependent PRs**: merge the dependency first, then rebase the dependent.
  - PR4447 spetrunia: "Get this pushed, then rebase the #4255 on top of the newer main so that it doesn't include these changes."
  - PR4412 sjaakola: "moved to another PR for 10.11."
- **Closing a PR in favor of another** is standard when the target branch needs to change and rebase-in-PR isn't feasible.
  - PR4752 → PR4764, PR4727 → PR4755.
- **Mark PRs as draft vs open** based on readiness. Draft for in-progress; open for ready-for-review.
  - PR4830 — explicit discussion.

## Verification / QA gates

- **New features need QA sign-off and a Preview-release cycle** before being merged to GA. Bug fixes do not.
  - PR4904 ParadoxV5: "Before merging new features, they also need to be approved by QA and typically pre-released in a preview build for at least one release cycle. QA will let us know when this is good to go."
- **Internal QA (RQG-driven)** posts assertion failures as line comments on long-running PRs. Author responds with the commit hash that resolved each.

## "Bug-test first, fix second" workflow (emerging)

- One commit adds the failing test; the next commit fixes it and updates the result.
- DaveGosselin-MariaDB cited a "Recommended MariaDB Git workflow 2026" document. Not yet a hard rule but an increasingly common shape.

## AI-disclosure expectations

- **AI-bot review comments (copilot, gemini) are ignored** by senior maintainers. Don't paste them into discussions.
  - PR4938 midenok rejected wholesale Copilot suggestions: "That code was generated by yourself (as many of the above). You should recheck yourself better in the first place."
- **Don't use LLM-mediated arguments** in PR discussions.
  - PR4589 vuvova: "I can ask an LLM myself, no need to do it for me."
  - PR4869 gkodinov: "Thank you for attempting to fix this. Unfortunately, it's not as simple as letting some AI do it." (The PR was a sweeping `sprintf`→`snprintf` rewrite with bad AI-generated buffer-size guesses.)
- **COMMUNITY_CONTRIBUTIONS.md (PR5007)** is being actively defined as of 2026-05; it explicitly covers AI-assisted contribution marking expectations. See [`MDEV-39572`](https://jira.mariadb.org/browse/MDEV-39572).

## Communication

- **Zulip** (`mariadb.zulipchat.com`) is where escalation and guidance happen.
  - PR4829 gkodinov: "Please reach out on Zulip if you need guidance on adding the test."
- **GSoC PRs are a different workflow** — handled inside the GSoC programme rather than the normal preliminary/final review pipeline.

## Reviewer-area lookup table

| Area | Primary reviewers (login) |
|---|---|
| **Triage / preliminary** | `gkodinov`, `grooverdan`, `bnestere`, `spetrunia` |
| **InnoDB** | `dr-m`, `Thirunarayanan` |
| **Optimizer, parser, SQL** | `vuvova`, `spetrunia`, `sanja-byelkin` |
| **DDL / ALTER / partitions** | `midenok` |
| **Replication / binlog / GTID** | `bnestere`, `andrelkin`, `knielsen` |
| **Galera / WSREP** | `janlindstrom`, `sjaakola`, `mariadb-TeemuOllakka` |
| **ACL / vector / charset / server core** | `vuvova` |
| **Temporal types / Data types / Type system** | `vuvova` (historically `bar` = Alexander Barkov for older commits) |
| **Client / build / packaging** | `svoj`, `grooverdan` |
| **Windows / byte-order / threadpool / build** | `vaintroub` |
| **MDL** | `svoj` |
| **Final say on parser/style** | `vuvova` |

When unsure who to tag, use `gkodinov` for preliminary review and let them route.
