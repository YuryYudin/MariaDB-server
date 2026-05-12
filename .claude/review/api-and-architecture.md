# API & Architecture

How the project decides *where* code goes, *what* APIs look like, and *what* must not change.

## Use server services, not libc

Plugins and server code should go through MariaDB's services rather than calling libc directly. Reviewers will reject `strftime` / raw `fopen` / `fprintf` / etc.

- **`thd_gmt_sec_to_TIME` / `thd_TIME_to_str` over `strftime`.** Uses the server's time-zone semantics.
  - PR4633 vuvova on `server_audit.cc:291`: "Big issue: don't use strftime. The server already has date-to-string formatting functions."
  - PR4633 vuvova: "The service is good. How you use it is good. It is very correct to pass NULL as the thd here."
- **mariabackup IO**: `ds_open` / `ds_write` / `dst_close`, not raw `fopen`/`fprintf`.
  - PR4605 gkodinov on `backup_copy.cc:1935-1947`: "I'd use ds_open() instead and not the C LIB FILE functions." / "I'd use ds_write() here" / "I'd use dst_close() here" / "close does flush. No need to do it separately." / "fprintf(\"%s\", ...) is a less performant equivalent to fwrite(). NEVER use that."
- **mysys wrappers**: `my_strtol`, `my_strtod`, `my_stat`, `my_open`, `my_close`, `mysql_socket_socket`, `mysql_socket_connect`. They provide PSI instrumentation, Windows handling, consistent error reporting.
  - PR4764 gkodinov (×3): "please use my_strtol", "please use my_strtod()", "use the mysys functions please."
  - PR4874 gkodinov: "please use the mysys functions. my_stat in this case." / "Please use mysql_socket_socket... please use mysql_socket_connect."
  - **Caveat**: vuvova pushed back on overuse of `mysql_*` wrappers in *mysqld init paths* (PR4874). Use judgment when bootstrapping.

## Internal containers preferred over STL

This is a hard rule for code in `sql/*` and `storage/*`:

- **`HASH`, `Hash_set`, `my_decimal`, `IO_CACHE`, `String`, `StringBuffer<>`** over `std::unordered_map`, `std::string`, etc.
  - PR4430 bnestere on `rpl_master_info_file.h:640`: "we should prefer MariaDB data types (when available) to promote a standard way of doing things. Here, you should be able to just use `HASH`."
  - PR4430 bnestere on `rpl_master_info_file.hh:501` (re unordered_map): cited Monty's policy "No work ever planned for allocator implementation. The issue is that for most cases MariaDB string functions are superior to std::"
- **`StringBuffer<>` for SHOW output** instead of manual `alloc()+concat`.
  - PR4618 vuvova on `sql_show.cc:6655`: "use `StringBuffer<>` instead."

## Where features live

- **Cross-engine features belong above the engine layer.** Don't put the check inside one engine.
  - PR4706 vuvova: "No, this is completely wrong. This doesn't fix MyISAM or Aria. 'hlindexes' are called **High-Level** Indexes because they are implemented on a higher level, not in the engine, but above it. Size check must also be done not in the engine, but above it."
- **Drop-table helpers live in `dict/drop.cc`**, not exported from `fsp0fsp.cc`.
  - PR4884 dr-m: "This function as well as `delete_from_sys_table_entries()` would seem to logically belong to the compilation unit `dict/drop.cc`."

## Errors and return values

- **Reuse generic error codes** — `ER_STD_INVALID_ARGUMENT` for generic validation. Don't mint hyper-specific codes copied from MySQL.
  - PR4569 vuvova on `item_func.cc:2033`: "This patently stupid error message came from MySQL where it should've never been added in the first place. We shouldn't use it... Please use `ER_STD_INVALID_ARGUMENT` which we consistently use for cases like this."
  - PR4569 vuvova: "Let's not create too many very specific errors."
- **Add new error codes to `errmsg-utf8.txt`** (rather than overload an existing one) when the translation needs to be unique.
  - PR4712 grooverdan: "Just a thought, should we add `ER_CANT_ALTER_TABLE HY000` in sql/share/errmsg-utf8.txt with the same error number HY000 as `ER_CANT_CREATE_TABLE` so translations can be added?"
- **Encode richer return info in existing return codes** rather than adding output parameters.
  - PR4884 dr-m: "Instead of using an output parameter, can we use the special return value `DB_SUCCESS_LOCKED_REC` to indicate that some unknown tables were dropped?"
  - PR4036 dr-m: "Could we make the function return an error code? That would allow simpler execution: `if (dberr_t err= sqlRunner.open_table(fts_table, &table)) return err;`."
- **Prefer status variables over read-only system variables.**
  - PR4904 gkodinov: "I personally find a non-settable system variable to be an abomination and a gotcha: why would you put something non-settable in a settable bucket… Status variables are more light-weight than system variables: less locking needed etc."

## API design discipline

- **Don't over-engineer.** Prefer flat, readable code over polymorphism if there's only one or two niche subclasses. Reviewers (especially vuvova and bnestere) routinely reject `std::function`-heavy designs.
  - PR4284 bnestere: "I think the overengineering here hurts readability, and I don't really see the benefit of extensbility, as the use case is very niche... Generally I think combining a class which both abstracts how to query something, along with the behavior of using that queried data is too much in the same abstraction."
  - PR4284 vuvova: "Really? I understand that you love `std::function` but this is seriously overdoing it." (showed a simple ternary as the desired refactor.)
- **Pass `st_::span<const char>`** (or a struct) instead of `(ptr, len)` pairs for new APIs.
  - PR4884 dr-m (×2): "Could we pass `st_::span<const char> name` instead of passing a name and a length separately?"
- **Don't add default values for behaviour-changing boolean parameters.** Defaults = forgotten overrides = silent bugs.
  - PR4858 dr-m: "By far the most callers would seem to pass this flag as `false`. Hence the default parameter kind of makes sense. However, it would be safer not to define a default value and require each caller to specify this parameter."
- **Don't widen utility APIs to accept invalid inputs** so a single caller works — fix the caller.
  - PR4865 vuvova: "I don't understand the logic here. `error_if_data_home_dir()` can strip the file name... and that's why the latter must accept empty strings? It doesn't make any sense."
- **De-THD direction.** Don't bloat THD with new fields; don't kill virtual functions in `MDL_context_owner` for "performance" without measurements.
  - PR4808 svoj/vaintroub: "For the unmeasurable performance benefit of removing virtual function we'll plant this THD dependency everywhere. We should actually de-THD as much as we can." (PR4808 was rejected on architecture grounds.)
- **Don't sprinkle new state into globally shared structs.** `LEX::save_list` is parser-scope; respect lifetime.
  - PR4433 spetrunia: "The patch makes use of LEX::save_list. I was concerned what other users are there. LEX::save_list should get a comment... I'm also wondering if we could move save_list to somewhere where it's clear its lifetime is parser."
- **Don't duplicate logic across `handler::scan_time()`, `cost`, etc.** Defensively return 0 for divide-by-zero cases.
  - PR5024 — `handler::scan_time()` returns `0.0` when `stats.block_size == 0` to prevent NaN propagation.

## On-disk and wire format

This is a hard line:

- **Don't break wire format / on-disk ordering for downgrade compatibility.**
  - PR4430 bnestere on `rpl_master_info_file.hh:501`: "Why unordered? As the `FIELDS_MAP` is iterated over when saving the KV pairs, wouldn't that make it non-deterministic? The fields should be written in the same order as pre-MDEV-37530 so users can downgrade without breaking anything."
- **Don't change `information_schema` column widths.** Existing apps query and store these.
  - PR4573 vuvova on `check_digest.inc:6`: "let's keep it at 32 here... existing applications... will continue to work."
  - PR4573 vuvova on `sql_digest.cc:162`: "[`XXH3_128bits`] has the same width as md5, so less changes and... same chance of collisions as before."
- **Don't rename `BASE TABLE` → `SYSTEM TABLE` without a compat flag.** Tools break.
  - PR4243 vaintroub: "How much was that change had been tested with external tools and connectors that rely on I_S.TABLES? It has the potential to break a lot of things."
  - PR4243 sanja-byelkin: "I could understand it under compatibility flag (like sql_mode MySQL) but change it in 10.6 now IMHO too big risk."
- **Don't claim a downgrade path you haven't tested.** Don't add ad-hoc compat shims "just in case".
  - PR4342 dr-m: "We must not create an impression that a downgrade would work if it has not been tested. The check for `'\377'` must not be added."
- **TODO + JIRA when feature reaches EOL** (e.g. `SHOW SLAVE STATUS` parsing supported until 11.4 EOL).
  - PR4284 bnestere on `client/mysqldump.cc:181`: "Please add a code comment w/ a TODO to remove this and associated code once 11.4 goes eol... I'd suggest filing a JIRA to remove support for SHOW SLAVE STATUS from mariadb-dump after 11.4 goes EOL."
- **Don't change the user-visible width of a digest column** without thinking about backward compat.
  - PR4573 — extensive vuvova thread on MD5→XXH3.

## Replication / binlog wire format

- **Bug fixes that touch binlog format are reviewed extra-carefully** (`bnestere`/`andrelkin`).
- **`max_binlog_row_event_max_size` default changes** are explicitly version-gated (PR4697).
- **`binlog_database` / GTID format invariants** — don't change ordering, don't drop fields.

## Submodules

- **Submodule bumps are out-of-band PRs.** Don't include them in a feature/bug-fix PR.
  - PR3726 gkodinov: "do you really need to change these? It looks like there's a conflict on these in buildbot."
  - PR3726 vuvova: "`libmariadb` needs a special PR there's no automatic propagation."
  - PR4557 spetrunia: a wolfssl submodule bump was flagged as unrelated to the patch.
  - PR4829 grooverdan: "Remove submodule updates and .gitattribute additions from this commit."

## ACL / privileges

- **Don't reuse existing privileges** (FEDERATED ADMIN, SUPER) for new functionality. Mint a new privilege.
  - PR4743 gkodinov: "It usually is not a good idea to reuse privileges. This turns them into roles... I'd advocate to adding a different privilege."
  - PR4743 gkodinov: "Why are you revoking SUPER as well? Would SUPER allow SHOW CREATE SERVER? If it would, please document that into the Jira and the commit message."

## Plugin / sysvar API

- **Validity checks live in the `check` callback**, not `update`.
  - PR4633 vuvova: "validity checks must be done in the `check` callback, not in the `update` callback."
- **Don't have `update` rewrite the sysvar's own storage**, the server already does that.
  - PR4633 vuvova on `server_audit.cc:2372`.
- **Plugin maturity in `.cnf` samples** must match release reality. Don't ship `plugin-maturity=alpha` in a stable example.
  - PR4453.

## Connector / ABI

- **Don't break the Connector/C ABI** silently. `libmariadb` propagation is manual; cross-cutting changes need parallel PRs in `mariadb-corporation/mariadb-connector-c`.
  - PR3726 vuvova: "`libmariadb` needs a special PR there's no automatic propagation."
- **Don't break MySQL-compatible client behaviour** in stable branches (PR4243, PR4536).

## Backports

- **New API surface usually lands in the dev branch first.** Backport after 6–9 months without regressions.
  - PR4065 ottok: "I propose we put this in the dev version first, and backport to 11.4+ in 6-9 months if there are no regressions."

## Codership / Galera

- **Galera/WSREP development happens externally** in `codership/` repos. Don't reference deprecated org names. Cross-repo coordination required.

## Documentation links

- **Don't link to volatile KB URLs.** GitBook links break. Prefer canonical short links.
  - PR4453 — entire PR was about stale config link.
- **Don't include license text in commit messages** — license decisions live in the CLA.
  - PR4703 gkodinov: "remove the license reference from the commit message."

## Performance claims need evidence

- **Cite `oltp_point_select cached` numbers** when claiming sql-layer overhead changes.
  - PR4808 vaintroub.
- **Micro-optimisation suggestions need Godbolt evidence.**
  - PR4783 vaintroub: "Nope, memcpy with odd length is not better at all... here is the proof https://godbolt.org/z/77T7rE1zM (you could have checked too, before suggesting?)"

## Modernization direction

- **InnoDB**: removing `*.inl` files and writing inline functions directly in headers is dr-m's stated direction. Some debates remain about specific cases.
- **`std::map`, `std::vector`** are tolerated outside hot paths. `std::unordered_map` and `std::function` are not.
- **`std::span<const char>`** (or `st_::span` until C++20 is the project baseline) is the modern API direction.

## When to file a separate MDEV

Reviewers frequently file new MDEVs for issues found during review rather than expanding the current PR.

- PR4036 → MDEV-38914, MDEV-38968.
- PR4747 → MDEV-37789.

If your PR uncovers something *adjacent* to its scope, file a separate MDEV and link it; don't grow the PR.
