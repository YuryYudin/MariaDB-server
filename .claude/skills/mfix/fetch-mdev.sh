#!/usr/bin/env bash
# Fetch a MariaDB JIRA ticket and emit structured JSON for the mfix skill.
#
# Usage:
#   ./fetch-mdev.sh MDEV-23676            # one ticket
#   ./fetch-mdev.sh MDEV-23676 MDEV-29924 # ticket + linked references
#
# No auth required — jira.mariadb.org is public.
# Output is JSON; pipe through `jq` further if needed.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 MDEV-NNNNN [MDEV-NNNNN ...]" >&2
  exit 2
fi

# Fields we care about for bug-fix workflow. If you need attachments' content
# you'll need a second call per attachment — they're not embedded.
FIELDS='summary,status,priority,fixVersions,affectsVersions,components,labels,description,issuetype,resolution,assignee,reporter,subtasks,issuelinks,comment,attachment,created,updated'

for ticket in "$@"; do
  if ! [[ "$ticket" =~ ^MDEV-[0-9]+$ ]]; then
    echo "warn: '$ticket' is not in MDEV-NNNNN form, skipping" >&2
    continue
  fi
  curl --fail --silent --show-error \
       --header 'Accept: application/json' \
       "https://jira.mariadb.org/rest/api/2/issue/${ticket}?fields=${FIELDS}" \
  | jq --arg key "$ticket" '{
      key: .key,
      summary: .fields.summary,
      type: .fields.issuetype.name,
      status: .fields.status.name,
      resolution: (.fields.resolution.name // null),
      priority: .fields.priority.name,
      created: .fields.created[0:10],
      updated: .fields.updated[0:10],
      components: [.fields.components[].name],
      labels: .fields.labels,
      affects:  [.fields.versions[]?.name],
      fix:      [.fields.fixVersions[]?.name],
      reporter: .fields.reporter.displayName,
      assignee: (.fields.assignee.displayName // null),
      description: .fields.description,
      comments: [.fields.comment.comments[] | {
        author: .author.displayName,
        created: .created[0:10],
        body
      }],
      subtasks: [.fields.subtasks[]? | {
        key,
        summary: .fields.summary,
        status: .fields.status.name
      }],
      links: [.fields.issuelinks[] | {
        type: .type.name,
        direction: (if .inwardIssue then "inward" else "outward" end),
        target: (.inwardIssue.key // .outwardIssue.key),
        target_summary: (.inwardIssue.fields.summary // .outwardIssue.fields.summary),
        target_status: (.inwardIssue.fields.status.name // .outwardIssue.fields.status.name)
      }],
      attachments: [.fields.attachment[] | {filename, size, mimeType, url: .content}]
    }'
done
