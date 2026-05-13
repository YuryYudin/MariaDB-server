# vuvova reviewer-profile research

Source data for `.claude/reviewers/vuvova.md`. The final guidance doc is the deliverable; this directory keeps the audit trail and the steps to regenerate.

**Window analysed**: 2025-05-13 → 2026-05-13 (12 months).
**Corpus**: 375 unique commits authored across all maintained branches + 346 of his comments (266 line, 48 review-body, 32 issue) on 71 PRs.

## What's in tree

```
all-shas.txt              # 375 commit SHAs (input list, small)
findings/                 # 5 per-chunk findings reports — human-readable audit trail
  ├── commits_00.md       # 97 commits — code style, refactoring, bug-fix patterns
  ├── commits_01.md       # 81 commits — same lens, different sample
  ├── commits_02.md       # 99 commits — JSON / parser / ACL focus
  ├── commits_03.md       # 98 commits — spatial / vector / ACL focus
  └── reviews.md          # 346 review comments — what he asks of others
reviewed-pr-numbers.txt   # 97 PR numbers he reviewed in the window
reviewed-prs.json         # gh-pr-list output for those 97 PRs
```

## What's NOT in tree (bulk data, regenerable)

These were intermediates that aren't committed because they're large and would go stale:

- `commits.jsonl` (1.2 MB) — per-commit JSONL with subject + body + stat + truncated diff for all 375 commits.
- `chunks/commits_{00..03}.jsonl` (~290 KB each, 1.2 MB total) — `commits.jsonl` split into 4 chunks for parallel analysis.
- `reviews/raw/pr_<N>.json` (~8.7 MB total, 97 files) — full GitHub-API dump per PR (`/pulls/N`, `/pulls/N/reviews`, `/pulls/N/comments`, `/issues/N/comments`).
- `reviews/vuvova-comments.jsonl` (690 KB) — filtered to vuvova's comments only across the 97 PRs.

## How to regenerate

```sh
cd $REPO_ROOT
mkdir -p .claude/pr-research/vuvova/{chunks,findings,reviews/raw}

# 1. List all unique SHAs authored by him across maintained branches in the window
{
  for ref in origin/10.6 origin/10.11 origin/11.4 origin/11.8 \
             origin/12.0 origin/12.1 origin/12.2 origin/12.3 origin/main; do
    git log "$ref" --author='Sergei Golubchik' \
      --since='2025-05-13' --until='2026-05-13' --pretty=format:'%H'
    echo
  done
} | awk 'NF' | sort -u > .claude/pr-research/vuvova/all-shas.txt

# 2. Build per-commit JSONL (subject + body + stat + 400-line diff)
> .claude/pr-research/vuvova/commits.jsonl
while read sha; do
  meta=$(git log -1 --format='%H%x09%ad%x09%s%x09%P' --date=short "$sha")
  body=$(git log -1 --format='%b' "$sha")
  stat=$(git show --stat --pretty=format: "$sha" | head -50)
  diff=$(git show --pretty=format: "$sha" -- '*.cc' '*.cpp' '*.h' '*.hpp' \
                                              '*.c' '*.yy' '*.l' \
                                              'CMakeLists.txt' '*.cmake' \
         | head -400)
  jq -c -n --arg sha "$(echo "$meta" | cut -f1)" \
           --arg date "$(echo "$meta" | cut -f2)" \
           --arg subject "$(echo "$meta" | cut -f3)" \
           --arg parents "$(echo "$meta" | cut -f4)" \
           --arg body "$body" --arg stat "$stat" --arg diff "$diff" \
     '{sha:$sha,date:$date,subject:$subject,parents:$parents,
       body:$body,stat:$stat,diff:$diff}' \
    >> .claude/pr-research/vuvova/commits.jsonl
done < .claude/pr-research/vuvova/all-shas.txt
split -n l/4 -d --additional-suffix=.jsonl \
  .claude/pr-research/vuvova/commits.jsonl \
  .claude/pr-research/vuvova/chunks/commits_

# 3. Fetch PRs he reviewed
gh pr list --repo MariaDB/server \
  --search 'reviewed-by:vuvova created:>=2025-05-13' \
  --state all --limit 200 \
  --json number,title,baseRefName,state,mergedAt,author \
  > .claude/pr-research/vuvova/reviewed-prs.json
jq -r '.[].number' .claude/pr-research/vuvova/reviewed-prs.json \
  | sort -u > .claude/pr-research/vuvova/reviewed-pr-numbers.txt

# 4. Pull each PR's reviews + comments + meta (8 in parallel)
while read n; do
  out=".claude/pr-research/vuvova/reviews/raw/pr_${n}.json"
  [ -s "$out" ] && continue
  tmp=$(mktemp -d)
  gh api "repos/MariaDB/server/pulls/${n}/reviews" --paginate > "$tmp/r.json"
  gh api "repos/MariaDB/server/pulls/${n}/comments" --paginate > "$tmp/c.json"
  gh api "repos/MariaDB/server/issues/${n}/comments" --paginate > "$tmp/ic.json"
  gh api "repos/MariaDB/server/pulls/${n}" > "$tmp/m.json"
  for f in r c ic; do
    [ "$(head -c1 $tmp/$f.json)" = "[" ] && \
      jq -s 'add // []' "$tmp/$f.json" > "$tmp/${f}.n.json" && mv "$tmp/${f}.n.json" "$tmp/$f.json"
  done
  jq -n --slurpfile m "$tmp/m.json" --slurpfile r "$tmp/r.json" \
        --slurpfile c "$tmp/c.json" --slurpfile ic "$tmp/ic.json" \
    '{meta:$m[0],reviews:$r[0],line_comments:$c[0],issue_comments:$ic[0]}' \
    > "$out"
  rm -rf "$tmp"
done < .claude/pr-research/vuvova/reviewed-pr-numbers.txt

# 5. Extract vuvova-only comments
> .claude/pr-research/vuvova/reviews/vuvova-comments.jsonl
for f in .claude/pr-research/vuvova/reviews/raw/pr_*.json; do
  jq -c '
    .meta as $m |
    ([.line_comments[]? | select(.user.login == "vuvova") | {
       pr:$m.number,pr_title:$m.title,base:($m.base.ref // null),type:"line",
       created:.created_at,path:.path,line:(.line // .original_line),side:.side,
       in_reply_to:.in_reply_to_id,body:.body,diff_hunk:.diff_hunk
     }] + [.reviews[]? | select(.user.login == "vuvova") |
                         select(.body != null and .body != "") | {
       pr:$m.number,pr_title:$m.title,base:($m.base.ref // null),
       type:"review_body",created:.submitted_at,state:.state,body:.body
     }] + [.issue_comments[]? | select(.user.login == "vuvova") |
                                select(.body != null and .body != "") | {
       pr:$m.number,pr_title:$m.title,base:($m.base.ref // null),
       type:"issue_comment",created:.created_at,body:.body
     }]) | .[]' "$f"
done >> .claude/pr-research/vuvova/reviews/vuvova-comments.jsonl

# 6. Dispatch 5 parallel analysis agents — see the prompt template in the
#    original SKILL_VALIDATION session, or any commit that adds this dir.
#    Each agent writes to .claude/pr-research/vuvova/findings/<chunk>.md.
```

## Synthesis prompt structure (one prompt per chunk)

Inputs: one `chunks/commits_NN.jsonl` (or `reviews/vuvova-comments.jsonl`).
Output: a markdown report under `findings/`.

Per-chunk reports cover:

- **Commit message conventions** (subject form, body norms, cross-refs, cherry-picks)
- **Code style (as he writes it)** (casts, `nullptr`, `if (T*p=expr)`, `unlikely()`, asserts, comments, `StringBuffer`, `my_safe_alloca`)
- **Refactoring / cleanup habits** (`cleanup:` commits, renames, helper extraction, dead-code removal, bundling args, transient state on the stack)
- **Bug-fix approach** (test + fix same commit, test placement, body diagnoses cause, sanitizer subject = raw output, severity reductions, minimal patches)
- **Architecture / API choices** (helpers as class methods, RAII guards, strongly-typed enums, `HA_*` flags, parameter bundling, single allocation)
- **Domain quirks** (vector / parser / ACL / spatial / JSON / charset / packaging / CMake)
- **Maintenance branch handling** (forward-merge chain, empty merge bodies, per-branch variants, stable-branch policy)
- **Singletons worth noting** (PR-specific gems)

The reviews-side prompt has different sections — architectural preferences, container/library preferences, error/message wording, test conventions he enforces, commit hygiene asks, process/interaction patterns, domain-specific opinions, catchphrases.

## Why bulk data isn't committed

- It's 11+ MB of GitHub-API dumps and JSONL — would bloat clones.
- It goes stale immediately when the window rolls forward.
- The findings/*.md files (168 KB total) carry the same information at a fraction of the size, with verbatim quotes and SHAs to re-look-up when needed.
- The regeneration commands above are deterministic for a fixed window.

## Lineage

| Source | Lines | What it became |
|---|---|---|
| `findings/commits_00.md` (403 lines) | code-style + bug-fix patterns across 97 commits | `.claude/reviewers/vuvova.md` §§ How he writes code, Bug-fix approach |
| `findings/commits_01.md` (267) | refactoring habits + cleanup commits across 81 | §§ Refactoring habits, How he writes code |
| `findings/commits_02.md` (560) | domain quirks (JSON / parser / ACL) across 99 | §§ Domain-specific opinions, Refactoring habits |
| `findings/commits_03.md` (286) | spatial / vector / ACL patterns across 98 | §§ Domain-specific opinions, Bug-fix approach |
| `findings/reviews.md` (875) | 346 review comments | §§ What he asks of others, Process / interaction, Catchphrases, Singletons |
