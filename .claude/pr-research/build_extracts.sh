#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")"
> extracts/all_comments.jsonl
for f in raw/pr_*.json; do
  jq -c -r '
    .meta as $m |
    ([.line_comments[] | {
      pr: $m.number, pr_title: $m.title, pr_state: $m.state, merged: $m.merged,
      base: ($m.base.ref // null), type: "line",
      author: .user.login, author_assoc: .author_association,
      created: .created_at, path: .path,
      line: (.line // .original_line), side: .side,
      in_reply_to: .in_reply_to_id, body: .body,
      diff_hunk: .diff_hunk
    }] + [.reviews[] | select(.body != null and .body != "") | {
      pr: $m.number, pr_title: $m.title, pr_state: $m.state, merged: $m.merged,
      base: ($m.base.ref // null), type: "review_body",
      author: .user.login, author_assoc: .author_association,
      created: .submitted_at, state: .state, body: .body
    }] + [.issue_comments[] | select(.body != null and .body != "") | {
      pr: $m.number, pr_title: $m.title, pr_state: $m.state, merged: $m.merged,
      base: ($m.base.ref // null), type: "issue_comment",
      author: .user.login, author_assoc: .author_association,
      created: .created_at, body: .body
    }])
    | .[]
  ' "$f" >> extracts/all_comments.jsonl
done
echo "total comments: $(wc -l < extracts/all_comments.jsonl)"
