#!/usr/bin/env bash
set -u
n="$1"
out="raw/pr_${n}.json"
[ -s "$out" ] && exit 0
tmp="/tmp/prfetch_$$"
mkdir -p "$tmp"
gh api "repos/MariaDB/server/pulls/${n}/reviews" --paginate > "$tmp/reviews.json" 2>/dev/null || echo "[]" > "$tmp/reviews.json"
gh api "repos/MariaDB/server/pulls/${n}/comments" --paginate > "$tmp/comments.json" 2>/dev/null || echo "[]" > "$tmp/comments.json"
gh api "repos/MariaDB/server/issues/${n}/comments" --paginate > "$tmp/issue_comments.json" 2>/dev/null || echo "[]" > "$tmp/issue_comments.json"
gh api "repos/MariaDB/server/pulls/${n}" > "$tmp/meta.json" 2>/dev/null || echo "{}" > "$tmp/meta.json"
# normalize: paginated output is concatenated arrays — wrap in a single array
for f in reviews comments issue_comments; do
  if [ "$(head -c1 $tmp/$f.json)" = "[" ]; then
    jq -s 'add // []' "$tmp/$f.json" > "$tmp/$f.norm.json" 2>/dev/null && mv "$tmp/$f.norm.json" "$tmp/$f.json"
  fi
done
jq -n \
  --slurpfile m "$tmp/meta.json" \
  --slurpfile r "$tmp/reviews.json" \
  --slurpfile c "$tmp/comments.json" \
  --slurpfile ic "$tmp/issue_comments.json" \
  '{meta: $m[0], reviews: $r[0], line_comments: $c[0], issue_comments: $ic[0]}' > "$out"
rm -rf "$tmp"
