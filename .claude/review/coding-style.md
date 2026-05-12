# Coding Style

`CODING_STANDARDS.md` is the project's authoritative style document; this file adds the *unwritten* rules that reviewers actually enforce, with concrete PR examples.

## Critical baseline

These rules are stated in `CODING_STANDARDS.md` but get enforced repeatedly during review:

| Rule | Why reviewers flag it | Severity |
|---|---|---|
| **Assignment style: `a= 1;`** (no space before `=`, one space after, single-line). | Used by `grep`-driven debugging. | important |
| **Pointer style: `TYPE *var`** (asterisk binds to the variable). | `TABLE* t` is rejected on sight in InnoDB and elsewhere. PR4914 dr-m: "`TABLE*` should be written as `TABLE *`." | important |
| **2-space indent, never TAB** in new code. | Exception: legacy InnoDB files use TAB *within those files*. Don't mix. PR4905, PR4914 — dr-m: "Please do not use TAB in new code." | important |
| **Allman braces, 80-col line limit.** | `clang-format` settings differ — don't rely on it. PR4446 dr-m: "I wish everyone could just agree on consistently applying a common .clang-format." | nit |
| **K&R `switch`**: `switch (x) {` on one line, `case` aligned with `switch`, no extra braces around case bodies unless declaring locals. | PR4036 dr-m: "we are following the K&R formatting for the `switch` statement body. That is, there must not be a line break here." | important |
| **Variable declarations at first real use**. Declare inside `for`/`while` head when possible. | PR4036 dr-m: "`rec` is being declared unnecessarily early. It could be declared in the `while` expression." | nit |
| **No `long` / `unsigned long` / `ulong`** in new code. Use `size_t`, `ptrdiff_t`, `uint32_t`, `int64_t`, etc. | Width differs between Linux and Windows. PR4522 vaintroub: "That they are ulong, is non-essential (and also unnecessary, better if they used a more portable type)." | important |
| **`snake_case`** for variables and functions; **`Capital_snake_case`** for new types (not `st_*`, not `CamelCase`). | PR4430 bnestere quoting CODING_STANDARDS.md verbatim. | important |
| **No Yoda conditions** (`if (0 == err)`). | `CODING_STANDARDS.md`. | nit |
| **No trailing whitespace, no trailing blank lines, `\n` line endings**. | Standard. Editor-driven changes are caught and rejected. | important |
| **Functions separated by two blank lines.** | `CODING_STANDARDS.md`. | nit |

## Don't touch what you're not changing

- **No whitespace-only edits in unrelated lines.** Configure your editor to not re-save whole files.
  - PR4508 gkodinov: "please don't do white-space only changes" (`extra/perror.c:355`).
  - PR4633 gkodinov: "don't do white-space only changes please!" (server_audit.cc, two places).
  - PR4581 spetrunia: "Does your editor still damage the characters it cannot recognize? Please remove changes like this." — re: UTF-8-corrupted `.result` lines.
  - PR4342 dr-m: "I think that we should avoid any changes to formatting unless some code nearby is being changed."

## Casts

- **No C-style casts in C++ code.** Use the constructor-style cast (`int(len)`, `unsigned(x)`, `uint16_t(n)`); it's shorter and equivalent. `static_cast<>()` is acceptable but `int(len)` is preferred for narrowing in idiomatic InnoDB code.
  - PR4717 dr-m: "`unsigned(` would be shorter than `static_cast<unsigned>(`."
  - PR4783 dr-m: "I would suggest to avoid C-style casts in C++ code. A constructor-style cast would be shorter too: `uint16(val * prec_fact...)`."
  - PR4884 dr-m: "`int(len)` is shorter and equivalent to `static_cast<int>(len)`."
  - PR4913 dr-m: "I would rather avoid using C-style casts in C++ code."
- **Drop redundant casts** when migrating `sprintf`→`snprintf`. If the value is already `unsigned long long`, use `%llu` and remove the `(unsigned long long)` cast.
  - PR4869 gkodinov: "since you are touching on this line, please use %llu and remove the casts." (×2 in `client/mysql.cc`.)

## Inline / static / noexcept

- **Drop redundant `inline`** when the function is defined inline in a header at first declaration. The keyword is only required when there's a separate `inline`-linked declaration.
  - PR4717 dr-m: "The function is being defined `inline` elsewhere, but this declaration is missing an `inline` keyword."
  - PR4717 dr-m: "If there is a combined declaration and definition... we usually omit the `inline` keyword because it is redundant."
- **File-local helpers must be `static`**. Catches symbol leakage and avoids accidental ODR.
  - PR4342 dr-m on `row0ins.cc:748`: "This is missing `static`."
  - PR4455 svoj on `mysql.cc:1210`: "It should be `static`."
- **New InnoDB C++ member functions need `noexcept`** — see [`innodb.md`](innodb.md) for details.

## Constants and magic numbers

- **Use a named constant for any non-trivial literal** that appears in more than one place or has type semantics.
  - PR4869 gkodinov on hard-coded `255`/`60` in MD5/binlog code: "it's painful to watch this 255 constant. I'd add a define in mysql_com.h."
  - PR4869 sanja-byelkin: "I'd define `MD5_BUFF_LENGTH` as `(VIEW_MD5_LEN + 1)` and wrote that calc_md5 always requires the buffer of 33 byte."
  - PR4633 gkodinov: "I'd use some named const size_t for the 1k constant."
- **`static const` / `constexpr` rather than `#define`** for typed constants.
  - PR4651 grooverdan on `ha_innodb.cc:19305`: "`static const` instead of define."
- **`static_assert`** to lock in numeric invariants and document magic numbers.
  - PR4717 dr-m: "Add `static_assert` to document what the `2` is about." Followed by a four-`static_assert` block.
  - PR4824 dr-m: "we could use the unary form of `static_assert` and reduce the source code line count by 1."

## Control flow

- **Early return / flat `if` chains over nested `if/else` for error handling.**
  - PR4605 gkodinov: "we typically do not do nested if() else ... for errors. We'd typically do something like: `if (call_function() == error) { do something; return; // or goto handle_error; }`."
  - PR4615 DaveGosselin-MariaDB: "No else after return."
- **Reorder branches so the common case is the fall-through**, the rare case is the body.
  - PR4717 dr-m: "Generally, I think that it would be better to check the less likely condition first."
  - PR4858 dr-m: "Can we make a separate loop for the rare online DDL case? Only the likely case would be handled inline here."
- **Move precondition assertions to the top of the function**, not inside a conditional path.
  - PR4036 dr-m: "Can the assertion be moved to the start of the function, like they were before this refactoring? Here it is inside a conditional execution path."
- **Don't introduce a local boolean for a one-shot condition** that reads naturally inline.
  - PR4717 dr-m: "As far as I understand, there is no need to introduce the local variable `is_temp`. We can simply check that condition first."

## Comments

- **State facts, no opinions / emotions / jokes** in code comments.
  - PR4441 bnestere: "I'd suggest avoiding emotion in code comments, and stick to the facts. I.e., instead of 'disappointingly, decimal2double() is implemented…' to something like 'but as of this patch, decimal2double() is implemented…'"
- **Don't quote MDEV-NNNNN with backticks** in code comments — plain text suffices.
  - PR4711 gkodinov (×3 in same PR): "you can skip quoting the mdev number here."
- **Don't paste the MDEV title** into the source comment; `git blame` finds it.
  - PR4811 grooverdan: "Listing MDEV and title in code comment not desirable. Focus on the message. There's git blame if people want to look it up."
- **Add a comment when surprising-but-correct code can mislead a reader.** Negative-zero canonicalisation, `+ 1` buffer offsets, intentional `const`/`mutable` asymmetry, etc.
  - PR4632 vuvova on `field.cc:4709`: "may be with a comment? Like `if (nr == 0.0) nr= 0.0; // correct negative zero` otherwise looks very confusing."
  - PR4517 spetrunia: "Please add a comment like 'We can end up with a zero-length index for (SELECT '' as col FROM t1) as DT. Such indexes are not allowed for regular tables...'"
  - PR4618 vuvova on `sql_show.cc:6654`: "add a comment, why `+ 1`."
  - PR4405 Thirunarayanan: "end is const, but access deliberately is non-const. The asymmetry between `const end` and mutable `access` is fine but worth a comment explaining the design intent."
- **No "MySQL" references in MariaDB source.** Update legacy comments while you're there.
  - PR4858 dr-m: "What is MySQL? We're MariaDB."

## Naming

- **Function names describe behaviour**, not vague verbs.
  - PR4874 vuvova: "may be, just a suggestion, `unlink_socket_if_unused()`? 'handle' doesn't really explain anything. Or `unlink_socket_or_abort()`."
  - PR4373 bnestere: "I like the `inline` change, but the change to the function name I'm still not sold on... It isn't guaranteed to flush if the content should all be held in-memory." → renamed to `flush_write_buffer_if_file_backed()`.
  - PR4284 bnestere: "`is` here reads as a verb" — naming convention nit.
- **Naming consistency between enum identifiers and the strings they emit.**
  - PR4342 dr-m: "The added symbol `WSREP_MODE_APPLIER_DISABLE_WARNINGS` does not include `FK_` like the added string literal `APPLIER_DISABLE_FK_WARNINGS` does. Is this intentional?"
- **Don't invent parallel header extensions.** MariaDB uses `.h` everywhere; don't introduce `.hh`.
  - PR4430 bnestere: discussion about why `.hh` was wrong here.
- **Macros are UPPER_SNAKE.**
  - PR4522 vaintroub: "Suggest a more meaningful name, also e.g `MY_CHARSET_UTF8MB4_BIN` (also capitalized, this is the usual convention for macros)."
- **Watch for system-macro collisions.** `MAX_KEY_SIZE` is taken on Windows ARM64.
  - PR4430 ParadoxV5: build failure due to collision; rename your new constant.

## Headers / generated files

- **Don't edit Bison/Flex-generated files** (`sql_yacc.cc`, `*lex.cc`). Edit the source `.yy`/`.l` and rerun, or skip the generated file via the build configuration.
  - PR4293 dr-m: "Instead of modifying the `flex` or `bison` generated files that are included in the source repository (as well as the scripts that could be used for rebuilding them), can we please tweak the Infer invocation so that these files will be excluded from analysis?"
  - PR4293 dr-m: "mention in the commit message the Bison version that was used."
- **Don't modify third-party libraries** under `extra/` (`extra/readline`, `extra/zlib`) directly — add `-D` flags via the local `CMakeLists.txt` instead.
  - PR4017 svoj: "`readline` is a third party library. It would be good to keep it intact and add `-DHAVE_VSNPRINTF` to `extra/readline/CMakeLists.txt` instead. The very same point applies to `zlib`."

## Removing things cleanly

- **When removing a `HAVE_*` feature-detect, remove all consumers** and clean up the `*Cache.cmake` file too. Don't leave `#ifdef HAVE_*` debris.
  - PR4017 svoj: "Please cleanup compatibility code as well." "`git grep HAVE_ALLOCA` and `git grep HAVE_MEMCPY` still return quite a few items that should be cleaned up."
  - PR4017 vuvova: "why would we want garbage like `#ifdef HAVE_PERROR` in the code, when `PERROR` is always defined?"

## CMake style

CMake conventions covered separately in [`build-and-cmake.md`](build-and-cmake.md); the headline points are: UPCASE commands, `ELSEIF()` over `ENDIF() ... IF()`, validate numeric variables, and prefer `#cmakedefine` over `add_definitions(-DFOO=...)`.

## What `clang-format` *won't* solve

The repo has a `.clang-format` file at the root, but its bracket-wrapping and spacing settings differ from `CODING_STANDARDS.md`. **Don't run it over server code** — the established style is to match the *file's existing* layout. PR4446 dr-m's review of `trx0undo.cc`: "This function has been formatted in the original InnoDB style, which uses TAB for indentation. In that style, `{}` braces around single-statement blocks (like the two `if` body above) are mandatory…"
