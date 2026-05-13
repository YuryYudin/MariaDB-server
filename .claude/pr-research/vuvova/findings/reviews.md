# Sergei Golubchik (vuvova) — review-comment findings (2025-05-13 .. 2026-05-13)

Corpus: 346 comments across 71 PRs (266 line comments, 48 review bodies, 32 issue
comments). Of the 48 review bodies, 31 are `CHANGES_REQUESTED`, 15 `APPROVED`,
2 `COMMENTED`. Every quote below is verbatim from
`.claude/pr-research/vuvova/reviews/vuvova-comments.jsonl`, truncated only with
`…`.

---

## Architectural preferences he insists on

### Push fixes into the engine that has the special case; keep the server engine-agnostic

- PR #4050 line `sql/transaction.cc:221`:
  "The explanation looks very InnoDB-specific, why would a serializable mode
  need to start a consistent snapshot 'so that write/read conflicts can be
  detected' in a more general case? Perhaps it's something that can be done
  inside InnoDB? Like if `ha_innobase::external_lock()` detects that the
  isolation mode is SERIALIZABLE, it starts a consistent snapshot."
- PR #4050 follow-up: "we get another such storage engine, we can adjust this
  logic … all these special cases will be spread everywhere through the code
  … So my preference would be not to introduce them in the first place."
- PR #4706 review_body (vector index size): "this is completely wrong. … 'hlindexes'
  are called **High-Level** Indexes because they are implemented on a higher
  level, not in the engine, but above it. Size check must also be done not in
  the engine, but above it."
- PR #4254 issue: "really does this have to be done per engine? It would be
  more robust to fix it somewhere in the server for all engines at once."

**Confidence:** high.
**Applies to:** any code that branches by `handlerton`/engine name inside
generic server paths.

### Don't widen APIs to accept invalid input; fix the caller

- PR #4865 review_body (`my_realpath` accepting empty string): "Empty string is
  an invalid path, just don't pass it to `my_realpath()` in the first place."
- PR #4088 line `sql/sql_insert.cc:4391`: "Why InnoDB returns an error, if the
  server is expected to ignore it?"
- PR #4161 (XA rollback assert): "this is wrong, it'll unilaterally rollback
  part of the global transaction … The correct fix is not to relax the assert,
  but to change XA transaction state … relaxing the assertion to allow for
  buggy behavior is wrong, better keep the assert and fix the bug."

**Confidence:** high.

### Prefer fixing the root cause once, not normalizing in every call site

- PR #4632 (negative zero): "Fixing all val_real() everywhere is error prone
  (easy to miss something), not future proof … The problem is not that a zero
  value can be negative … The problem is that it is **printed** not as zero …
  This is easy to fix in `dtoa.c` … fix `hp_rec_hashnr()` … do **not** fix
  every place where floating point calculations can happen."
- PR #4929 (`Ssl_cipher_list` workaround): "this is wrong. … The error doesn't
  happen during the update, the error happens when P_S generates a dataset
  internally. This is a bug that must be fixed, not worked around."

**Confidence:** high.
**Applies to:** changes that loop-fix many call sites or skip tests instead of
fixing the underlying bug.

### Validity checks belong in the right callback / right layer

- PR #4633 `plugin/server_audit/server_audit.cc:2361`: "validity checks must be
  done in the `check` callback, not in the `update` callback."
- PR #4287 (UUID size disallow): "why do you need a new `allowed()` method when
  you can put the check into `Column_definition_set_attributes()`? … Perhaps
  you can move the check into the parser?" (offers a `field_type_all_with_typedefs`
  yacc sketch).
- PR #4254 line `sql_table.cc:8262`: "why did you put this check in three
  different places, could it be possible to have it just once on a common code
  path? e.g. see where `HA_STATUS_AUTO` is also used."

**Confidence:** high.

### Don't leave artifacts on failure; clean up in the function that created them

- PR #4659 `sql/sql_table.cc:4942`: "`ha_create_table()` was not supposed to
  leave artifacts in case of a failure … if creating of a hlindex fails,
  `ha_create_table()` should drop the table it has created **before
  returning**. This would be also consistent with how partitioning … handles
  errors. See `ha_partition::create()`."

**Confidence:** medium (one PR but spelled out as a general principle).

### Choose engine-capability via `table_flags()`, not bespoke checks

- PR #4627 `sql/sql_lex.cc:5511`: "It must be either table_flags() check or
  something that doesn't need any capability checks at all. Generally I prefer
  the latter, but if it cannot be done without a capability check, then it is
  table_flags()."
- PR #4627 `sql/sql_lex.cc:5505`: "file->ht can never be NULL".

**Confidence:** medium.

### 2PC discipline: a transaction that writes to binlog must go through `tc->prepare()`

- PR #4301: "There's no `tc->prepare()` call. Even though a transaction must
  be logged by a tc. This looks wrong. If a transaction needs to be written
  into binlog, it should go through `tc->prepare()` whether it's commit or
  rollback."
- "a 'rollback' when a non-trans engine is involved is not really a rollback.
  That engine has the changes **committed**. And binlog needs to commit … so
  it's a commit, of a sort. And must be subjected to full 2pc."

**Confidence:** medium (one PR, but stated as protocol-level rule).

### Prefer modifying one existing utility over inventing a parallel one

- PR #4718 `sql_table.cc:2817`: "don't use `make_unique_invisible_field_name()`.
  It does pretty much the same as `make_internal_field_name()` … except that
  `make_internal_field_name()` is actually used, while
  `make_unique_invisible_field_name()` only ever needed in debug builds … And
  why not to use `add_internal_field()` instead?"
- PR #4287: prefers extending the parser rule over adding plugin-type-specific
  error code.

**Confidence:** medium.

---

## Code-style preferences (beyond CODING_STANDARDS.md)

### Comments must add information; drop opinions, mood, and MDEV titles

- PR #4254 `sql_table.cc:11075`: "drop these comments, they aren't helpful in
  the long run. The function name is good and clearly explains what it does."
- PR #4682 `ha_innodb.cc:16774`: "Also, don't mention MDEV in the comment."
- PR #4356 `my_compress.c:36`: "use the same comment style as elsewhere in this
  file."
- PR #4633 `server_audit.cc:1141`: "dunno, looks hackish."

**Confidence:** high.

### Avoid `alloca` for unbounded input; prefer `my_safe_alloca`, `malloc/free`, or a class-member `String` buffer

- PR #4096 line 137: "an argument might be big, `alloca` is not a good idea
  here. Either use `my_safe_alloca` or malloc/free or, like above, a member
  of `Item_func_gen_embedding`."
- PR #4096 line 113: "A better solution would be to have a `String
  converted_buffer;` member in your `Item_func_gen_embedding` class. This way
  you'll keep the buffer when the function is invoked for every next row,
  avoiding per-row malloc calls."

**Confidence:** high.

### Don't allocate from `thd->mem_root` per-row; understand statement vs execution arena

- PR #4096 line 113: "memroot is an allocator that is always freed as a whole
  … you cannot keep allocating in a memroot in a loop. thd->mem_root is
  usually freed at the end of the statement execution … A second problem — you
  use 'statement arena', not 'execution arena'. There is no difference in your
  tests, but in prepared statements … the execution arena is freed after every
  execution, while statement arena has the same lifetime as stmt1."
- PR #4096 line 236: "ok, this is allocated once per statement, not per row.
  so ok to do on a memroot. but still, not on a statement arena, on execution
  arena."

**Confidence:** high.

### Don't copy `CHARSET_INFO`, take the address

- PR #4096 line 109: "talked about that already, don't copy a charset, use a
  pointer to it: `CHARSET_INFO *cs_openai = &my_charset_utf8mb4_general_ci;`"

**Confidence:** medium.

### Don't comment-out code, just remove the line

- PR #4356 `my_compress.c:109`: "just remove the line, don't comment it out."

**Confidence:** low.

### Don't put `--echo` end-of-tests banners as three lines; one is enough

- PR #4743: "one line for the end marker, not three. Just `--echo # End of
  11.8 tests`."
- PR #4874: "one line here, not three. Just `--echo # End of 13.0 tests`".

But three-line banners are required for new test sections opening an MDEV:

- PR #4504 (parsec test):
  ```
  --echo #
  --echo # MDEV-35254 PARSEC plugin should allow DBAs to specify number of iterations
  --echo #
  ```

**Confidence:** medium. End markers = single line; MDEV section openers =
three-line frame.

### `current_thd` is the spelled name (it's a macro)

- PR #4096 line 125 reply: "the common pattern is `current_thd` because of
  `#define current_thd _current_thd()` in one of the headers."

**Confidence:** low.

### Use named parameters in public headers

- PR #4356 `include/my_sys.h:970`: "use named parameters in the header, it's
  impossible to understand what the function is doing otherwise."
- Same PR: "why the parameter is `void*` if it's `Compress_buffer*`?"

**Confidence:** medium.

### Many of his helper functions can be `static` inside their `.c`

- PR #4356 `include/my_sys.h:970`: "judging from how many files you had to
  change, many of these functions can be static in my_compress.c and don't
  need to be in the common header at all."
- PR #4096 line 71: "could be global and static, I suppose."

**Confidence:** medium.

### Defensive checks: prove every condition is reachable, otherwise drop them

- PR #4254 `sql_table.cc:154` enumerates each `!` clause and asks "what does
  it mean?", "is it even possible here?", "the table has no auto-increment
  column. Is it possible here or the earlier checks must've prevented that?"
- PR #4718 `sql_table.cc:2761`: "I understand defensive programming, but I
  think it's way too much defensive. You create an invisible auto-inc key, so
  I'd say it's enough to check just that … Besides, can `field` really be NULL
  here?"

**Confidence:** high.

### Variable-help text vs warning text: keep info in the right one

- PR #4504 `server_parsec.cc:112`: "remove 'parsec:' prefix, it's redundant.
  And may be ' (next supported value)' too, because the variable help text
  should say that, not a warning message after the fact."
- PR #4504 `server_parsec.cc:118`: "perhaps, add '. Must be a power of two'. Or
  '. Will be rounded up to a power of two'."

**Confidence:** low.

### `static_assert` is preferred over hand-written constants

- PR #4504 `server_parsec.cc:249`: "I'd add `static_assert(ITER_MAX_VAL ==
  'z');` just in case."

**Confidence:** low (singleton).

---

## Container / library preferences

### Prefer `StringBuffer<>` over manual concat / allocation

- PR #4618 `sql/sql_show.cc:6655`: "use `StringBuffer<>` instead".
- PR #4096 line 153 (instead of `std::string + concat`): "you don't really
  need to convert `char*` to `std::string` if all you want is to concatenate
  it with something. You can do, for example `strxnmov(post_fields,
  post_fields_size, …);` or you can use `my_snprintf`."

**Confidence:** high.

### Use `strxnmov` / `my_snprintf` instead of `std::string` concatenation

- See PR #4096 line 153 above.
- PR #4096 line 299: "why do you create a static std::string, if all you ever
  need is char*?"

**Confidence:** medium.

### Keep `include/my_bit.h` and similar small headers dependency-free; don't include `my_global.h` from plugin code

- PR #4504 `include/my_bit.h:106`: "no, `my_bit.h`, again, is a small clean
  header-only library with no dependencies. don't contaminate with with
  `my_global.h` or mysys or anything."
- Same PR: "`my_global.h` is not for plugins, it's contains too much stuff
  that only server needs."
- Same PR: "change `my_bit.h` to use `unsigned char`, `unsigned int`, etc.,
  making it independent from `my_global.h`".

**Confidence:** high.
**Applies to:** plugin code; cleanup of widely-included shared headers.

### Use server services from plugins (don't reimplement the server)

- PR #4633 `server_audit.cc:291`: "don't use strftime. The server already has
  date-to-string formatting function DATE_FORMAT() … We should not let
  different parts of the server to implement formatting differently … invoke
  server's date-to-string function. And to do that, it must be in a
  [service](.../libservices/HOWTO). But, perhaps, you can add a new method to
  the timezone service and not create a new one."
- PR #4633 `item_timefunc.cc:1372`: "The service is good. How you use it is
  good. It is very correct to pass NULL as the thd here … which means 'use
  global time zone and locale', because session settings should not affect the
  global audit log."

**Confidence:** high.
**Applies to:** plugins; any duplicated server primitive (formatting, locale,
charset, time).

### `mysql_*` wrappers (instrumented I/O) are only for code Performance Schema watches

- PR #4874 `sql/mysqld.cc:2723`: "there's no need to use `mysql_` wrappers
  here, this is not the code that performance schema is interested in. So,
  simply `socket`, `connect`, etc."

**Confidence:** low (singleton, but explicit).

### Use `CREATE_TYPELIB_FOR()` macro for new TYPELIB initializers

- PR #4333 `ha_innodb.cc:351`: "`TYPELIB` is changed, so every `TYPELIB`
  static initializer has to be too. I'll change this place to use
  `CREATE_TYPELIB_FOR()` macro (like few lines above)."

**Confidence:** low (singleton).

### Prefer XXH3_128 over XXH3_64 where MD5 used to be — same width = same collision risk

- PR #4573 review_body: "I've looked at `xxhash.h` that you're using and
  noticed that it has 128-bit hash. This is the same width as MD5 so less
  changes and also same chance of collison, 64-bit hash has it much higher.
  could you try with XXH3_128bit please?"

**Confidence:** low (singleton, but a concrete steer).

### Reusable C++ wrappers for in-tree primitives, not new function families

- PR #4503 `rpl_info_file.h:77` (str2int): "may be (quoting from my
  yet-unpushed commit) `template<typename T> inline char *str2int(...)` … it's
  type safe and universally usable (could be in a common header). and doesn't
  add a new str->int, but wraps existing one."

**Confidence:** low.

---

## Error / message wording

### Use `ER_STD_INVALID_ARGUMENT` rather than introducing new specific errors

- PR #4569 `item_func.cc:2033`: "This patently stupid error message came from
  MySQL where it should've never been added in the first place. We shouldn't
  use it, sorry for suggesting it earlier, my mistake. Please use
  `ER_STD_INVALID_ARGUMENT` which we consistently use everywhere. And
  `ErrConvDouble` for `value`."
- PR #4569 `func_math.result:50`: "Let's not create too many very specific
  errors. I've just found `ER_INVALID_ARGUMENT_FOR_LOGARITHM` — let's use it
  for all these cases."

**Confidence:** medium.

### `%iE` (13.0+) or `%M` (pre-13.0) for `errno` in `sql_print_error`; never decode the errno yourself

- PR #4874 `sql/mysqld.cc:2729`: "I'd use just `sql_print_error('Cannot
  create a socket: %iE. Aborting', errno);` note it's `%iE` in 13.0 but `%M`
  in 10.11, if you'll backport it."
- PR #4874 `sql/mysqld.cc:2765`: "Remove the `EACESS` if(), and in the second
  use `%iE` (or `%M`): `sql_print_error('Unexpected error checking socket %s
  (%M). Aborting.', path, socket_errno);`"

**Confidence:** medium.

### User-facing errors don't go to the error log

- PR #4096 line 101: "generally user errors aren't printed into the error
  log."
- PR #4096 reply: "I mean, just remove `ME_ERROR_LOG`, the warning will be
  sent to the user, but won't be written into the system-wide error log."
- PR #4281 line 1293: "yes, the user won't read the error packet … If you
  want the error in the error log, use `MYF(ERROR_LOG)` or `sql_print_error`."

**Confidence:** high.

### NULL vs empty string for "list of options": empty list = empty string

- PR #4618 `sql_show.cc:6663`: "NULL generally means that there can be no
  create options, that it the concept is not applicable here. But it is not
  the case, the list is simply empty, I'd expect an empty string here, not
  NULL."
- PR #4618 line 10129: "not nullable (same below)" → and don't bother calling
  `set_notnull()` on a column declared NOT NULL.

**Confidence:** medium.

### Print clean messages; drop redundant prefixes; abort on truly fatal

- PR #4874 `mysqld.cc:2729`: "From all possible errors here, as far as I can
  see, we can only ever get `EMFILE`, `ENFILE`, `ENOMEM`. Either way,
  mariadbd should abort and not because the socket file exists."
- PR #4504: "remove 'parsec:' prefix, it's redundant."

**Confidence:** medium.

### Server side uses `sql_print_information()`, not `puts()`

- PR #4262 issue: "in the server it should be `sql_print_information()` not
  `puts()`. Or nothing at all, client is sufficient, I think."

**Confidence:** low.

---

## Test conventions he enforces

### Use `--replace_result` with maximally specific tokens, not user-controlled values

- PR #4219 `failed_auth_unixsocket.test:23`: "generally it's not a good idea,
  we've had cases before when a user name (we cannot control the value of
  $USER) indiscriminately matched some random part of the message, so more
  specific replacements are preferred."

**Confidence:** medium.

### Avoid `max_session_mem_used` and similar fragile triggers in tests

- PR #4659 `vector_innodb.result:1823`: "I'd prefer to avoid
  max_session_mem_used in tests, it's very unreliable. Is there any other way
  of failing the create table? May be, you can create a file from mysqltest
  with the name of the future .idb file, then file creation will fail."

**Confidence:** medium.

### EXPLAIN of query X must use literally the same SQL as the executed query X

- PR #4654 `mdev_35327.result:56`: "why you don't use EXPLAIN of exactly the
  same query as above? You cannot see whether the query above uses the index
  … please, do a query with EXPLAIN and **exactly the same query** without
  EXPLAIN."
- PR #4627 `innodb_null_only.test:161`: "you must have the same query in
  EXPLAIN and here, otherwise EXPLAIN makes no sense."

**Confidence:** high.

### Tests must actually demonstrate the claimed property

- PR #4053 `galera_provider_options_long.cnf`: "does it test the bug? how can
  you know it'll be above 2K?"
- PR #4654 `mdev_35327.test:32`: "This is an index created with the euclidean
  distance. It cannot be used for searches with manhattan distance. You
  didn't implement support for manhattan distance at all."
- PR #4654 `mdev_35327.test:23`: "this isn't a very good dataset. L1 distance
  between your vectors is 0,3,12, as your tests show. L2 distance would be
  0, 1.732, 6.9282. That is, you cannot know if the index works correctly,
  Euclidean and Manhattan provide exactly the same ordering. Try vectors
  where L1 and L2 produce different results."

**Confidence:** high.

### Prefer adding to an existing many-engine test over creating a new singleton test file

- PR #4706 review_body: "Could you please move the test to vector.test? no
  need to create a new small test file and a new combination file.
  vector.test is good for many-engines test. oh, and add `SHOW TABLE STATUS`
  tests, as it's mentioned in the title."
- PR #4519 `rpl_do_grant.test:250`: "wrapping the test in `if (0) { ... }`
  would likely create a smaller diff."

**Confidence:** medium.

### Test negative / boundary cases (CHANGE/MODIFY/DROP/RENAME variants for every new restriction)

- PR #4718 `sql_table.cc:3363`: "Add this test case: … verify that it fails
  now, then fix."
- PR #4718 follow-up: "Also add tests for `CHANGE COLUMN`, `MODIFY COLUMN`,
  `DROP COLUMN`, `RENAME COLUMN` and `RENAME INDEX`. All should return an
  error, just as your test for `DROP PRIMARY KEY` does."
- PR #4793 `type_enum.result:2624`: "`insert into t1 values ('0'); insert into
  t1 values (0);` to show the behavior is the same in both cases."

**Confidence:** high.

### `--echo #` framing — three-line frame at section start, one-line at end

- PR #4504 (PARSEC): full three-line frame at the head of a new MDEV section
  (quoted above under code-style).
- PR #4743 / PR #4874: single line at end of section.

**Confidence:** medium.

### Set the `.opt` file when testing a command-line flag, don't restart inside the test

- PR #4633 reply: "I meant, adding `--server-audit-timestamp-format=CMD-LINE-%Y-%m-%d`
  here in the .opt file. That's why I commented in the opt file. your method
  works too, but restarting the server takes time, better to keep the number
  of restarts to the minimum."

**Confidence:** low.

### `connect` already opens the connection — don't follow with `--connection`

- PR #4743 `grant_server.test:105`: "you don't need `--connection con1` after
  `--connect con1`, remove it."

**Confidence:** low.

### Don't re-invent disconnect-wait — cherry-pick the existing helper

- PR #4281 `userstat.test:81`: "this is fixed in 12.1, commit bead24b7f3df,
  mariadb-test there waits for disconnect to be processed. options: * fix
  this bug only in 12.1 * cherry-pick mariadb-test change … * use
  wait_until_count_sessions.inc here in 10.11."

**Confidence:** medium.

### Verify the actual stored bytes, not only the SQL surface

- PR #4504 `parsec.test:103`: "print the password here, that is, `select
  left(json_value(...)) from mysql.global.priv where user='t_iter'` to verify
  that the password indeed has a correct iteration character. Perhaps even
  repeat it for a couple of different iteration values."
- PR #4706: "put here `FLUSH TABLES` and then repeat again your `select … from
  information_schema.tables`".

**Confidence:** medium.

### Don't use `DBUG_EXECUTE_IF` if a `DEBUG_SYNC` will do

- PR #4374 `sql_select.cc:5441`: "can you do it without DBUG_EXECUTE_IF
  please? E.g. with existing DEBUG_SYNC, if possible. Those DBUG_EXECUTE_IF
  don't improve readability, they're a necessary evil, but still evil."

**Confidence:** low.

### Prefer waiting on a log/known string in Perl helpers over hard-coded sleeps

- PR #4096 line 50 (gen_embedding/suite.pm): "eventually we'll want here a
  proper waiting logic. … `do { sleep 1 and seek LOG,0,1 until $_=<LOG>; }
  until /known string/;`"

**Confidence:** low.

### Use plain Perl modules in MTR Perl blocks instead of layering bash/perl trickery

- PR #4874 `socket_conflict.test:55`: "too much perl here, I'd suggest to
  simplify as … `use IO::Socket::UNIX; my $path= $ENV{MASTER_MYSOCK}; unlink
  $path; close STDOUT; my $srv= IO::Socket::UNIX->new(Local => $path, Listen
  => 1,) or die … fork and exit; exit if $srv->accept();`"

**Confidence:** low.

---

## Commit hygiene asks

### "Squash to one commit, then I'll merge"

- PR #4509 review_body: "looks good, thanks. Would you mind squashing all
  commits into one? Then I'll merge it."
- PR #4569 review_body: "Looks good, please squash into one commit."
- PR #4618 review_body: "And, the man thing, please squash all commits into
  one, then I'll approve and merge."
- PR #4356 review_body: "And squash commits into two. One with purely style
  changes and one with functional feature. Thanks."

**Confidence:** high. He squashes at the merge boundary; he is willing to
accept two commits when one is "pure style".

### Move unrelated changes into a separate commit (and ideally a separate PR)

- PR #4281 `mysqltest.cc:5775`: "please put this and the related test change
  in a separate commit, with a comment, like, cherry-pick of commit XXX from
  12.Y etc etc."
- PR #4390 issue: "But you also used bash arrays, rewrote passwordless root
  check. Why is all that and why it's in the same MDEV-34902 commit?"
- PR #4509 issue: "It's mainly important to have COM_CHANGE_USER changes in a
  separate commit … after you push PRs won't matter anymore, the history only
  contains commits, not PRs."

**Confidence:** high.

### One logical change per commit — but not "exactly one commit" as a rule

- PR #5007 line 55: "No, absolutely not. It often can (and should) do with a
  single commit. But it's not an absolute rule, it depends on the case. If a
  contributor puts unrelated changes in one commit we **will** ask him to
  split it. Say, one commit = one logical change."
- PR #5007 line 128: "no, not a single commit".

**Confidence:** high.

### Target the lowest still-maintained branch where the bug reproduces; features go to main

- PR #5007 line 138 (CONTRIBUTING.md wording he proposes):
  "> The pull request should target the right branch. Rule of thumb: the
  lowest affected but [not older than three years](https://mariadb.org/about/#maintenance-policy)
  GA branch for bugs, main branch for features and refactorings."
- PR #4254 line 326: "don't do it in 10.6, please. rebase your PR 11.4
  please."
- PR #4254 review_body: "targeting 11.4 looks strange. a bug fix normally
  goes into the earliest applicable version, a feature goes into main."
- PR #4793: "please rebase to 10.11 though".

**Confidence:** high.

### Commit subject: `MDEV-12345 ` (space, no colon), MDEV at the front

- PR #5007 line 60: "I do not insist on everyone doing that, but I personally
  use `MDEV-12345 ` without a colon. The length of the commit subject is
  limited, various tools show only a prefix of it, and any characters that
  don't carry information effectively reduce the length of the prefix."

**Confidence:** low (singleton, his preference).

### Rebase, don't merge

- PR #4618: "please rebase on top of the main branch".
- PR #5007 line 55 reply: "there's normally an extra roundtrip anyway 'please
  rebase on top of the latest main' or something. Could as well be 'please
  squash and rebase on top of the latest main'."

**Confidence:** medium.

---

## Process / interaction patterns

### "Looks good, please squash, then I'll merge" — the standard close

- PR #4509 / PR #4569 / PR #4618 / PR #4706: explicit "I'll approve and
  merge" / "I'll merge" once one final cleanup is done. He distinguishes the
  approval from the actual merge — he merges after the squash.

**Confidence:** high.

### Approves with conditions ("Approved either way, but…")

- PR #4569 review_body[APPROVED]: "Looks good, please squash into one commit.
  I'd also suggest to make `signal_log_domain_error()` non-static method …
  Anyway, it's just a suggestion. Approved either way."
- PR #4144 review_body[APPROVED]: "Looks ok, thanks. Please also replace
  other instances of `mysql_install_db` in `support-files/mariadb*.service.in`
  (there are two, in comments)."
- PR #4076 review_body[APPROVED]: "basically ok to push, I'm approving the
  PR, but please check the following: …"

**Confidence:** high.

### Asks a second reviewer for domain coverage

- PR #4083 review_body[APPROVED]: "looks ok to me, but I still think
  @spetrunia should see it too".
- PR #4503 review_body[COMMENTED]: "And let Brandon review the
  `std::initializer_list` changes."
- PR #4633 review_body[APPROVED]: "I've asked the original developer of the
  audit plugin to take a look, in case he'd have a cleaner idea how to
  achieve the same."

**Confidence:** high. Pattern: "I'll approve; please get domain owner X to
sign off on Y."

### "In-Testing" handoff message after approval

- PR #4573 / PR #4633 issue: "This is what happens now: MDEV-XXX is moved to
  the 'In-Testing' status, if everything is fine, a tester will approve it
  and it'll be pushed into main in time for the 13.0.1 release which is
  planned for the beginning of May. There is nothing you need to to anymore,
  unless testing finds bugs."

Reusable boilerplate — copy near-verbatim when a community PR is approved.

**Confidence:** high.

### Pushes back on LLM-generated arguments

- PR #4589 issue: "Thank you. I can ask an LLM myself, no need to do it for
  me, though." Followed by a substantive technical rebuttal about dot product
  not being a distance and benchmarks needing real data, not synthetic.

**Confidence:** low (singleton, but very directive).

### Suggests taking the commit over when contributor stalls; mentions Blocker deadlines politely

- PR #4534 issue: "This issue is marked in MDEV-38550 as a **Blocker** …
  Meaning, it blocks the release, we won't release until it's closed. One of
  the consequences is that we won't be able to wait for you forever, when a
  deadline comes we'll have to take to take over. The release it planned for
  the end of April, there's a whole month though, plenty of time, no hurry."
- PR #4633 issue: "@abhishek593 never mind, I'll merge and do remaining
  changes."
- PR #4161: "I don't care, it's one-liner … Please, fix it, if you don't
  mind, as you're already on it. Or tell me to."

**Confidence:** medium.

### Re-targets / re-bases the PR himself when he wants to unblock it

- PR #4929 review_body: "I've rebased on the latest 10.11, performance schema
  and feedback plugin are now fixed, please remove all related workarounds
  from your PR."

**Confidence:** low.

### "why?" / "why??" / "why???" — terse interrogatives

He frequently writes a single "why?" on test lines and code lines, indicating
"there is no apparent justification, explain or remove":

- PR #4329 `mariadb.service.in:82`, PR #4096 `plugin.cc:293`, PR #4356
  `net_serv.cc:589`, PR #4627 `item.cc:931`, PR #4644
  `mariadb.service.in:69`, PR #4654 `item_vectorfunc.cc:104` — all "why?"
- PR #4627 `innodb_null_only.test:186` — "why??"
- PR #4627 `innodb_null_only.test:173` — "why???"

**Confidence:** high. This is a signature opening for "explain the rationale
or remove."

### Disagrees with the technical thesis, not the contributor

- PR #4050: he runs three rounds of debate and finishes "If you'd like I can
  try to fix it inside InnoDB", offering the work himself.
- PR #4632: he pushes back on the bottom-up approach, then provides a precise
  three-step plan ("fix dtoa.c, fix `hp_rec_hashnr()`, do **not** fix every
  place").

**Confidence:** high.

---

## Domain-specific opinions

### Vector / HNSW

- "hlindexes are called **High-Level** Indexes because they are implemented
  on a higher level, not in the engine, but above it." (PR #4706)
- Dot product not accepted as a distance without benchmarks on real data;
  ann-benchmarks-style insert-speed-vs-recall 2D chart is the bar. (PR #4589)
- New distance functions must come with an index test using vectors where
  the new distance gives a **different ordering** than existing distances.
  (PR #4654)

### Replication / XA / 2PC

- "If a transaction needs to be written into binlog, it should go through
  `tc->prepare()` whether it's commit or rollback." (PR #4301)
- Don't relax an XA assertion to allow unilateral rollback — set
  `xid_state.set_rollback_only()` instead. (PR #4161)
- Binlog can be in the middle of the 2PC participant list when there's a
  non-transactional engine; full 2PC must be done. (PR #4301)

### ACL / privileges / packet parsing

- "MariaDB the read function zero-terminates the packet, we don't rely on
  the sender to zero-terminate it. This is precisely to have simpler packet
  parsing code. In other words, `strlen` is safe here." (PR #4534)
- Combine `CLIENT_SECURE_CONNECTION` branches and put a single
  `ER_UNKNOWN_COM_ERROR` validity check that covers both. (PR #4534)
- `BACKUP SERVER` should require global `SELECT_ACL` because it reads all
  data. (PR #4817)
- JSON_TABLE / generated tables: `any_db` means "no db needed"; `null_clex_str`
  means "no db specified, infer from current db". (PR #4233)

### Parser / Item

- Plugin-data-type checks belong in the parser rule (he provides a
  `field_type_all_with_typedefs` skeleton). (PR #4287)
- Use `ErrConvDouble` for double values in errors. (PR #4569)
- Walk-the-tree visitors are "kind of expensive and we're doing it a lot.
  could this be done in `fix_fields`?" (PR #4627)
- `Item_field` walkers can be defined out-of-line as
  `bool Item_field::clear_null_only_fields_processor(void *) { … }`. (PR #4627)

### InnoDB

- InnoDB `external_lock()` is where engine-specific isolation work belongs.
  (PR #4050)
- Multi-update / multi-delete: read-only tables in the join don't need
  S-locks. (PR #4682)
- Comment shouldn't mention "subquery" if the fix is about multi-update
  generally. (PR #4682)

### Charset

- "json_escape can take an argument in any charset, it looks like it does
  the conversion internally" — don't transcode to utf8mb4 first. (PR #4096)
- The output of a vector parsing function is `my_charset_bin`, not the
  source JSON's charset. (PR #4096)

### Plugin / service architecture

- Plugins that need a server primitive must consume it via a `libservices/`
  service; if the service is missing, add a method to an existing service
  before creating a new one. (PR #4633)
- For audit/log code, pass `NULL` as `thd` to thd-services so global
  time-zone / locale apply. (PR #4633)

### Packaging / systemd

- A plugin packaged separately needs a `*.cnf` for autoload; a plugin shipped
  inside the server package does **not** want a separate `cnf` (the
  `plugin.cmake` `CONFIG` keyword was originally a tokudb special case).
  (PR #4644)
- `systemctl` reads `lib/systemd/system/<service>.service.d/*.conf` (he
  worked this out in PR #4644).
- "I'd suggest the opposite, keep socket in the `RUNDATADIR`, as was always
  the intention, but make `RUNDATADIR=/run/mysql`." (PR #4329)
- For DEB version migrations: there are historical commits doing
  `conflicts/replaces` correctly — copy them. (PR #4644)

### CMake

- "`MATCHES` is regex" — use it for OS lists like `"fedora|rhel$|centos"`.
  (PR #4308)
- Avoid `set_package_properties(... REQUIRED ...)` when the dep is genuinely
  optional. (PR #4096)
- `INSTALL_RUNDATADIR is always set, no need to check`. (PR #4329)
- Suspicious patterns: `EXECUTE_PROCESS(COMMAND "${GIT_EXECUTABLE}"` right
  after `SET(GIT_EXECUTABLE)`. (PR #4903)

---

## Catchphrases / turns of phrase

- **"why?"** — one-word challenge; the cheapest comment in the dataset and
  the most frequent shape of "delete this or justify it."
- **"why??" / "why???"** — escalation for repeated unjustified test changes
  (PR #4627).
- **"Looks good, [thing], then I'll [approve/merge]"** — closing recipe.
- **"basically ok to push, I'm approving the PR, but please check the
  following: …"** — approval-with-loose-ends.
- **"I don't insist, but…"** — a suggestion he expects you to consider but
  won't block on. PR #5007: "I do not insist on everyone doing that, but I
  personally use `MDEV-12345 `…"
- **"This is what happens now: MDEV-XXX is moved to the 'In-Testing'
  status…"** — boilerplate explaining the next process step to community
  contributors (PR #4573, PR #4633).
- **"Don't mention MDEV in the comment"** (PR #4682) — comments document
  intent, not history.
- **"so, here it's an empty db, and below it's any_db. Shouldn't there be a
  consistent way to distinguish …"** — pushing for a single
  representation/invariant rather than two equivalent encodings.

---

## Singletons worth noting

These appeared only once in the window but are concrete and quotable:

- **`__has_feature`**: "shouldn't we have `__has_feature` in my_global.h or
  somewhere? I see it's being declared over and over in various headers."
  (PR #4309)
- **OpenSSL compat**: "A proper fix would've been to add `#define
  OPENSSL_cleanup()` in a couple of places in `include/ssl_compat.h`."
  (PR #4947)
- **Tests under `--ssl`**: extract repeated `--ssl`-skip logic into a
  dedicated `.inc` (PR #4929).
- **Galera applier strings**: `"wsrep applier"` is the spelling. (PR #4412)
- **Server greeting at startup**: nothing in the server log preferred —
  "client is sufficient, I think." (PR #4262)
- **Empty-string database from old-protocol auth**: when
  `CLIENT_SECURE_CONNECTION` isn't set the pointer isn't incremented, so the
  `+1` is real; verify against the comment in `sql_acl.cc:13866`. (PR #4509)
- **CMake regex**: `cpack_rpm.cmake` should use `MATCHES "fedora|rhel$|centos"`
  not `STREQUAL`. (PR #4308)
- **`alloca` argument size**: when the input is user-provided, `alloca` is
  never acceptable. (PR #4096)
- **`xxhash.h` has 128-bit hash** — see PR #4573 for the choice.
- **`Compress_buffer compress_buf= {buf, buf_end, buf};`** as a single-line
  C99 aggregate init. (PR #4356)
- **For tests that need a present file:** create the file from `mysqltest`
  to force a downstream failure, instead of triggering it with a session
  variable like `max_session_mem_used`. (PR #4659)
- **For "is this even reachable?" review questions:** list each clause and
  ask per-clause; PR #4254 is the model.
- **For Manhattan/Euclidean parity tests:** ensure the vectors place the
  expected target at a different rank under each distance. (PR #4654)
- **`SET GLOBAL var=default`** — preferred over restart-to-reset in MTR.
  (PR #4633)
- **`SHOW CREATE SERVER`** privilege: requires `FEDERATED ADMIN`. (PR #4743,
  context only — he reviewed the test framing here, not the rule itself.)
- **Backward-compatible defaults over "empty = special-case-hardcoded":**
  "don't make it 'empty = hard-coded', it's not very intuitive, simply set
  the default value of timestamp_format to the correct (backward compatible)
  value." (PR #4633)
- **Don't put a per-file COPYING in a directory that only contains a
  CMakeLists.txt** — the project license covers it. (PR #4903)
- **Don't add 'preliminary reviewer' / 'final reviewer' — use 'first
  reviewer' / 'second reviewer'** because we "try to have two reviewers for
  every PR, for years." (PR #5007)
