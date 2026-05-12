# Logging & Error Messages

A surprisingly hot review topic. Reviewers — `vuvova`, `gkodinov`, `dr-m`, `grooverdan` — routinely rewrite user-facing messages. Most failures here are silent (the wording becomes part of the release) so prevention matters.

## Logging functions

- **`sql_print_error` / `sql_print_information` / `sql_print_warning`** in new code, anywhere in the server.
- **Avoid `ib::logger`, `ib::info`, `ib::warn`, `ib::error`** in *new* InnoDB code.
  - PR4036 dr-m on `fts0fts.cc:2764`: "Can we please avoid `ib::logger` in new code?"
  - PR4036 dr-m on `fts0opt.cc:1305`: "Can we please use `sql_print_error` in new code?"
- **Avoid `puts()` / `fprintf(stderr, ...)`** in server code.
  - PR4262 gkodinov on `client/mysql.cc:1428`: "Please use put_info as the rest of them do."
  - PR4262 vuvova: "in the server it should be `sql_print_information()` not `puts()`."
- **`fprintf("%s", str)` is forbidden** when writing to a `FILE*` — use `fwrite()` instead. Same applies to mariabackup: use `ds_write()`.
  - PR4605 gkodinov on `backup_copy.cc:1940`: "`fprintf(\"%s\", ...)` is a less performant equivalent to `fwrite()`. NEVER use that."

## `errno` formatting

- **`%iE` (13.0+) or `%M` (10.11)** — never hand-enumerate `EACCES` / `EMFILE` / `ENOMEM` etc.
  - PR4874 vuvova: "From all possible errors here, as far as I can see, we can only ever get EMFILE, ENFILE, ENOMEM. Either way, mariadbd should abort... So I'd use just `sql_print_error(\"Cannot create a socket: %iE. Aborting\", errno);` note it's `%iE` in 13.0 but `%M` in 10.11."
  - PR4874 vuvova: "Remove the `EACESS` if(), and in the second use `%iE` (or `%M`)."

## Message wording

These show up across many PRs. Run new messages past the list before pushing:

- **The message tells the user what happened and what they can do about it.** Not just an observation.
  - PR4874 vuvova: "This isn't a very helpful error message. From all possible errors here... mariadbd should abort and not because the socket file exists."
  - PR4789 grooverdan: "On commit message, its more than just preventing an assertion, its about giving a error message to the user."
- **Describe what we're *doing*, not what we observed.** Especially for `sql_print_information` log lines.
  - PR4884 dr-m on `fsp0fsp.cc`: "The message does not say what we are going to do with the table: `sql_print_information(\"InnoDB: DROP TABLE %.*s\", int(len), rec);` I think that using the SQL syntax should make it clear even for DBAs who do not speak English."
- **No indefinite/definite articles** when the natural-language meaning is ambiguous.
  - PR4884 dr-m: "In my native language, we don't have indefinite and definite articles. I would suggest 'Found an unknown table'."
- **Mention any new variable or flag the user should set** in response.
  - PR4884 dr-m: "Should the message mention `:autoshrink` too, to give the end user a hint what this is about?"
- **Include the table/constraint/object name** in any error message about it.
  - PR4342 dr-m on `row0ins.cc:1038`: "The message is very confusing, because CHECK TABLE looks like a SQL statement. Why is the name of the failing constraint not being displayed? That together with the referencing table name should be sufficient."
  - PR4884 dr-m on `sys_truncate_debug.test`: "Can we please include the name of the table in the search pattern?"
- **No duplicated tokens like `err: err:`** — cover each message in a test to catch this.
  - PR4342 dr-m (×2): "The output would seem to include `err: err:`. Please cover each message in the test cases."
- **No absolute paths** in server messages.
  - PR4342 dr-m: "Absolute path names do not add any useful information. Some other redundant information had been removed in 88d9348dfc..."
- **Bound user-input components** in formatted messages — long inputs explode buffer sizes and produce useless log lines.
  - PR4455 grooverdan on `mysql.cc:4565`: "Use a modifier on `%s` to restrict the message to the right most portion of the `source_name`. Adjust buffer size accordingly. Message should be '.. it is a directory, block device, or memory allocation failed'."
- **Tell the truth.** The thread name in a log line is "wsrep applier", not "applier".
  - PR4412 vuvova on `mysqld.cc:301`: "isn't it supposed to be 'wsrep applier'?"
- **No emojis, no opinions, no jokes** in code comments — applies to messages too.
- **For server-internal binlog events**: a stable prefix users can grep, with the details after.
  - PR4942 bnestere: "Server restart truncated MEMORY table %`s.%`s; a TRUNCATE event was written to the binary log at GTID %u-%u-%llu. As this server is a read-only slave, this event may diverge replication."

## InnoDB identifier display

- **InnoDB identifiers need charset conversion.** Raw `my_charset_filename` bytes aren't UTF-8; use `ut_get_name()` or `dict_table_open_failed()`.
  - PR4342 dr-m: "we are aware of a more efficient way of displaying InnoDB table names. A conversion from `my_charset_filename` to `system_charset_info` (UTF-8). A test case for this must in..."
- **Test the conversion.** Add a test case using identifiers that exercise non-ASCII characters.
  - PR4342 dr-m: same review thread.

## Format-string and printf safety

- **`%.*s` with `int(len)`** for explicit-length strings; never assume NUL-termination on bytes you read from InnoDB records, wire packets, or files.
- **Match types**: `%llu` for `unsigned long long` (drop the cast); `%zu` for `size_t`; `%lld` for `long long`. Don't keep the legacy `(unsigned long long) val` cast when migrating.
  - PR4869 gkodinov (×2): "since you are touching on this line, please use %llu and remove the casts."
- **`snprintf(buf, sizeof(buf), ...)`** for stack-local buffers; never `sprintf`, never hard-coded sizes that don't match the receiving buffer.
  - PR4455 grooverdan: "use a `snprintf(sizeof(buff),...`."
  - PR4869 — see [`correctness-and-security.md`](correctness-and-security.md) for the long discussion.

## Cold-path warnings — don't flood

- **Production builds should not flood the error log** on legitimate operations.
  - PR4342 janlindstrom: "`DB_LOCK_WAIT` is normal behavior even in applier, it would flood error log if this warning is enabled in release builds."
  - PR4342 dr-m: "Why does the logic differ between `CMAKE_BUILD_TYPE=Debug` and `CMAKE_BUILD_TYPE=RelWithDebInfo`?"

## Error codes / `errmsg-utf8.txt`

- **Reuse generic codes** like `ER_STD_INVALID_ARGUMENT` for generic validation. Don't mint hyper-specific ones.
  - PR4569 vuvova: see [`api-and-architecture.md`](api-and-architecture.md).
- **Add a *new* code (with `errmsg-utf8.txt` entry) if the message is genuinely new** and translatable.
  - PR4712 grooverdan: "Just a thought, should we add `ER_CANT_ALTER_TABLE HY000` in sql/share/errmsg-utf8.txt with the same error number HY000 as `ER_CANT_CREATE_TABLE` so translations can be added?"

## Naming consistency between enum and string

- **Enum identifier and its emitted string** should agree.
  - PR4342 dr-m: "The added symbol `WSREP_MODE_APPLIER_DISABLE_WARNINGS` does not include `FK_` like the added string literal `APPLIER_DISABLE_FK_WARNINGS` does. Is this intentional?"

## Comment / docstring for messages

- **Update the sysvar docstring** when you change the user-visible behavior.
  - PR4633 gkodinov on `server_audit.cc:283`: provided exact wording for the docstring.
  - PR4633 vuvova: "you can now remove references to the 'system strftime' from comments."

## Replicaton-specific log content

- **Server-internal binlog comments** include a stable prefix users can grep:
  - PR4942 bnestere — "generated by server …" style prefix.
- **Include GTID context** in events the user might want to correlate with replication state.

## Testing every message you add

- **A test must verify the exact wording, with the identifier in it.**
  - PR4342 dr-m: "If the tests are not revised to actually cover the constraint names that the messages are expected to output, then such conflicts will remain undetected."
- **Use `include/search_pattern_in_file.inc`** for log-message coverage. Suppression alone is not enough.

## Don't lose context

- **When refactoring error paths**, keep the original error code. Don't return `1` where callers expect `-1` for "ignore_errors".
  - PR4455 svoj on `mysql.cc:4774`: detailed correction.

## Identifier quoting

- **Use `%`s` for identifier formatting** (with backtick quoting), not `%s`, in messages that name SQL objects.
  - PR4942 example: `... TRUNCATE event was written... GTID %u-%u-%llu ...` — context-appropriate formatting.
