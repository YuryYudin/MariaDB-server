---
applies-to: main
last-verified: 2026-05-14
source-of-truth: sql/sql_yacc.yy, sql/lex.h, sql/sql_lex.{cc,h}, sql/gen_yy_files.cmake, sql/gen_lex_hash.cc, sql/gen_lex_token.cc
---

# Reference: the SQL parser

The MariaDB SQL parser. Bison grammar in [`sql/sql_yacc.yy`](../sql_yacc.yy), hand-written lexer in [`sql/sql_lex.cc`](../sql_lex.cc), keyword tables in [`sql/lex.h`](../lex.h). Loaded on demand from [`sql/CLAUDE.md`](../CLAUDE.md) §"Parser & lexer".

> **Most agents do not need to touch the parser.** New SQL functions go through the [`item_create.cc`](../item_create.cc) factory; only a feature that needs a brand-new SQL **keyword** touches this file cluster. See [`.claude/playbooks/add-sql-function.md`](../../.claude/playbooks/add-sql-function.md).

## TL;DR

- **One checked-in grammar:** [`sql_yacc.yy`](../sql_yacc.yy). The build splits it into MariaDB and Oracle-mode variants via `%ifdef MARIADB` / `%ifdef ORACLE` blocks (NOT C `#ifdef`). There is **no separate `sql_yacc_ora.yy`** checked in.
- **Hand-written lexer** in [`sql_lex.cc`](../sql_lex.cc); keyword recognition uses a perfect hash from `lex_hash.h`, generated at build time from [`lex.h`](../lex.h).
- **`LEX`** ([`sql_lex.h`](../sql_lex.h:3208)) is the per-statement parser state — query blocks, `sql_command`, parsed object refs, `sphead` for stored programs. **`Yacc_state`** is the bison stack; **`Lex_input_stream`** is the lexer cursor.
- **Adding a SQL keyword is non-trivial:** reserved vs non-reserved, choice of `keyword_*` list, Oracle-mode override, edit `lex.h` *and* `sql_yacc.yy`, rebuild (which regenerates the hash). See §7.
- **Optimizer hints** (`/*+ ... */`) have their **own** mini-parser in [`opt_hints_parser.cc`](../opt_hints_parser.cc); they are not part of the bison grammar.

## 1. The build pipeline

```
sql/lex.h ────> gen_lex_hash.cc     (build-time tool) ──> lex_hash.h   (perfect hash)
sql/lex.h ────> gen_lex_token.cc    (build-time tool) ──> lex_token.h  (token-id table)

sql/sql_yacc.yy ─> sql/gen_yy_files.cmake (CMake -P script)
                     ├──> yy_mariadb.yy ─ bison ─> yy_mariadb.cc / yy_mariadb.hh
                     └──> yy_oracle.yy  ─ bison ─> yy_oracle.cc  / yy_oracle.hh
```

Glue lives in [`sql/CMakeLists.txt`](../CMakeLists.txt) (~lines 67–96, 414–432). The split script is [`sql/gen_yy_files.cmake`](../gen_yy_files.cmake) — a small `cmake -P` program that streams `sql_yacc.yy` and routes each `%ifdef MARIADB` / `%ifdef ORACLE` block to one or the other output, preserving line numbers in the disabled output (so bison diagnostics still match the source).

Two bison-generated parsers are linked into `mariadbd`:

| Parser entry | Used when |
|---|---|
| `MYSQLparse()` (from `yy_mariadb.cc`) | Default `sql_mode`. |
| `ORAparse()` (from `yy_oracle.cc`) | `sql_mode=ORACLE`. |

Both share the lexer: [`MYSQLlex()`](../sql_lex.cc:1879) and [`ORAlex()`](../sql_lex.cc:1885) are both one-line wrappers around `Lex_input_stream::lex_token()`.

**You edit `sql_yacc.yy` and `lex.h` in source. Everything else is generated.** All four bison outputs (`yy_mariadb.{cc,hh}`, `yy_oracle.{cc,hh}`), `lex_hash.h` and `lex_token.h` live only in the build directory — do not commit them, do not hand-edit them.

## 2. Structure of `sql_yacc.yy`

~21 k lines. Layout (line numbers approximate):

| Lines | Contents |
|---|---|
| 1–375 | `%{ … %}` C++ preamble, `#include`s, `Lex = thd->lex` macro. |
| 376–391 | Bison options (`%pure-parser`, `%define api.pure`, `%parse-param { THD *thd }`, `%expect` for accepted-conflict count). |
| 392–1300 | Token declarations (`%token <type> NAME`). The `%token` comment grammar (`SQL-2011-R`, `SQL-2011-N`, `MYSQL`, `MYSQL-FUNC`, `INTERNAL`, `OPERATOR`, `FUTURE-USE`) is documented in-file and helps `grep`. |
| 1300–1500 | Precedence (`%left`, `%right`, `%nonassoc`) and the `%prec` helper tokens (`PREC_BELOW_IDENTIFIER_OPT_SPECIAL_CASE`, `PREC_BELOW_SP_OBJECT_TYPE`, `SUBQUERY_AS_EXPR`, …). |
| 1500–2090 | Type declarations (`%type <ident_sys> ident`, `%type <spblock> sp_decl`, …). Some `%type` blocks are inside `%ifdef MARIADB` / `%ifdef ORACLE` (see lines 2051–2088). |
| 2090–20956 | Rules (`%%` to end). The big content. |

Inside the rules section, two-mode constructs use `%ifdef`:

```
| ROWNUM_SYM
%ifdef MARIADB
   '(' ')'
%else
   optional_braces
%endif ORACLE
  { $$= new (thd->mem_root) Item_func_rownum(thd); … }
```

That's the same rule with two right-hand sides: MariaDB requires the empty parens, Oracle accepts them as optional. (Excerpt: [`sql_yacc.yy:11003-11013`](../sql_yacc.yy).)

The mode-specific blocks are reasonably contained — only 24 `%ifdef` directives in the whole file. List them with:

```sh
grep -n '^%ifdef\|^%else\|^%endif' sql/sql_yacc.yy
```

## 3. The lexer

[`sql_lex.cc`](../sql_lex.cc) — hand-written, character-by-character. Not flex-generated.

Entry points (both 3-line wrappers; the real work is in `Lex_input_stream::lex_token`):

- [`MYSQLlex()`](../sql_lex.cc:1879) — called by `yy_mariadb.cc`.
- [`ORAlex()`](../sql_lex.cc:1885) — called by `yy_oracle.cc`.

State lives in [`Lex_input_stream`](../sql_lex.h:2458): cursor, lookahead buffer, comment state, digest accumulator. `lex_token()` performs token-contraction for LALR(2) resolution (e.g. `WITH ROLLUP` → single `WITH_ROLLUP_SYM` token, see [`sql_lex.cc:1914-`](../sql_lex.cc)).

The lexer is charset-aware: multi-byte identifiers are decoded via the connection's `CHARSET_INFO` (`character_set_client`). Identifier classification uses the generated `lex_hash.h`:

| Table in `lex.h` | Contents | Used by |
|---|---|---|
| `symbols[]` (lines 49–751) | Reserved + non-reserved keywords. Sorted alphabetically; the build re-hashes. | Identifier resolution — "is this token a keyword". |
| `sql_functions[]` (lines 754–802) | Built-in function names. | "Is this `IDENT '('` a known function?" |

Note the warning in `lex.h` itself: **"The symbol tables should be the same regardless of what features are compiled into the server. Don't add ifdef'ed symbols to the lists."** Build-time conditional keywords are not supported.

## 4. Identifier wrappers — `LEX_STRING`, `LEX_CSTRING`, `Lex_ident_*`

A small zoo. Quick reference:

| Type | Defined in | Use |
|---|---|---|
| `LEX_STRING` | `include/mysql/plugin.h` / `mysql_com.h` | `{ char *str; size_t length; }`. Mutable. Legacy; new code prefers `LEX_CSTRING`. |
| `LEX_CSTRING` | `mysql_com.h` | `{ const char *str; size_t length; }`. The standard "string with explicit length" everywhere in `sql/`. |
| `Lex_cstring` | [`sql/lex_string.h`](../lex_string.h) | C++ wrapper over `LEX_CSTRING` with constructors and helpers. |
| `Lex_ident<Compare>` | [`sql/lex_ident.h`](../lex_ident.h) | Templated identifier with a `Compare_*` policy supplying `CHARSET_INFO *charset_info()`. Predefined for table names (`Compare_table_names` — case-sensitivity follows `table_alias_charset`), case-insensitive idents (`Compare_ident_ci`), and more. |
| `Lex_ident_cli_st` | [`sql/lex_ident_cli.h`](../lex_ident_cli.h) | An identifier still in **client charset**, with metadata about whether it's quoted, 8-bit, etc. What the lexer produces. |
| `Lex_ident_sys_st` / `Lex_ident_sys` | [`sql/lex_ident_sys.h`](../lex_ident_sys.h) | The same identifier after conversion to **system charset** (`system_charset_info`). What the grammar's semantic actions usually work with. The `%type <ident_sys> ident` declaration in `sql_yacc.yy` says: a parsed `ident` is a `Lex_ident_sys`. |

**Conversion happens in semantic actions**: `Lex_ident_sys(thd, &cli_ident)` invokes `copy_ident_cli` to convert client charset → system charset on the statement memroot.

## 5. The `LEX` struct

[`sql/sql_lex.h`](../sql_lex.h:3208) — `struct LEX : public Query_tables_list`. Per-statement parser state, accessed in semantic actions as `Lex` (a macro for `thd->lex`, see `sql_yacc.yy:33`).

Critical fields (this is not exhaustive — `LEX` has hundreds):

| Field | Type | Role |
|---|---|---|
| `current_select` | `SELECT_LEX *` | The query block currently being parsed; mutated as the grammar descends into subqueries. |
| `all_selects_list` | `SELECT_LEX *` | Singly-linked list of every `SELECT_LEX` in the statement. |
| `unit` | `SELECT_LEX_UNIT` | Outermost set-operation unit. |
| `query_tables` | `TABLE_LIST *` | Head of the parsed table-reference list (inherited from `Query_tables_list`). |
| `sql_command` | `enum_sql_command` | What kind of statement this is — drives the `mysql_execute_command()` dispatch in [`sql_parse.cc`](../sql_parse.cc). |
| `option_type` | `enum_var_type` | For `SET`: `OPT_DEFAULT` / `OPT_SESSION` / `OPT_GLOBAL`. |
| `sphead` | `sp_head *` | When parsing a stored-program body, the partially-compiled program. |
| `stmt_lex` | `LEX *` | The outer-statement LEX when parsing a nested unit (e.g. view body). |
| `needs_reprepare` | `bool` | Set if `JOIN::optimize` hit an unrecoverable error; the next execute will reprepare. |

Two adjacent state objects, kept in `THD::m_parser_state`:

- [`Lex_input_stream`](../sql_lex.h:2458) — the lexer's cursor + lookahead.
- [`Yacc_state`](../sql_lex.h:5250) — bison's value stack (`yacc_yyss` / `yacc_yyvs`, dynamically reallocated via `my_yyoverflow`) plus tiny grammar-helper fields (`m_lock_type`, `m_mdl_type`).

## 6. Adding a new keyword — recipe

This is the actionable centre of the doc. Steps (assume the keyword is `MY_NEW_KW`).

### 6.1 Reserved or non-reserved?

| | Reserved | Non-reserved |
|---|---|---|
| User can use as a column / table / alias name | No (or only with backtick quoting) | Yes |
| Wire-format / backward-compat impact | App SQL that used the word as an identifier breaks at upgrade | None |
| When to choose | Starts a new statement form, or has ambiguous positions a parser can't disambiguate without it being reserved | Default. Almost always. |

**Strongly prefer non-reserved.** Reviewers will push back on any unnecessary reservation; releasing one reserved keyword causes documented incompatibility (see the "Reserved Words" page of the KB).

### 6.2 The five-file edit

1. **Add the keyword to [`lex.h`](../lex.h)** — alphabetically in the right table:
   ```cpp
   { "MY_NEW_KW",          SYM(MY_NEW_KW_SYM)},
   ```
   `symbols[]` for keywords, `sql_functions[]` for built-in function names that need `IDENT '('` recognition. Keep alphabetical — the comment at top of `lex.h` flags that the perfschema `start_server_low_digest_sql_length` test's result file is keyed off the symbol count and must be updated if you change it.

2. **Declare the token in [`sql_yacc.yy`](../sql_yacc.yy)** with the right type tag:
   ```
   %token <kwd> MY_NEW_KW_SYM
   ```
   Token names by convention end with `_SYM`. Place near related tokens.

3. **For non-reserved keywords**, add the token to one of the `keyword_*` non-terminals near the bottom of `sql_yacc.yy`:

   | Non-terminal | Where the word can appear | Example contents |
   |---|---|---|
   | `keyword_table_alias` | Table alias position | `keyword_data_type \| keyword_sp_var_and_label \| …` |
   | `keyword_ident` | Most identifier positions (column, alias, …) | Same as above plus `REF_SYM`. |
   | `keyword_sysvar_name` | System-variable name in `SET` | |
   | `keyword_func_sp_var_and_label` | SP labels and variable names that may also be function names | |
   | `keyword_sp_var_not_label` | SP variable names that cannot be SP labels | `ASCII_SYM, BACKUP_SYM, BINLOG_SYM, …` |
   | `keyword_directly_assignable` | Oracle-mode direct assignment (`xxx := 10;`) | (Oracle-mode only) |

   List them with `grep -n '^keyword_' sql/sql_yacc.yy | head -30`. Pick by which production positions the word must be allowed in. Wrong list = the word silently becomes reserved-in-context.

   **For reserved keywords**, the `%token` declaration alone is sufficient — the word does not appear in any `keyword_*` list.

4. **Use the keyword in a grammar rule**:
   ```
   my_new_statement:
       MY_NEW_KW_SYM ident
       {
         /* semantic action — typically construct a Sql_cmd_* object,
            or set fields on Lex */
       }
   ;
   ```
   Then plumb that rule into a parent (`verb_clause`, `statement`, `keyword`, …) at the appropriate point.

5. **Oracle-mode considerations.** If the keyword conflicts with an Oracle-reserved word, gate either the token, the type, or the rule body with `%ifdef MARIADB` / `%ifdef ORACLE`. For type-tag declarations only, the type can be `%ifdef`-gated (see `sql_yacc.yy:2051-2088` for an example).

### 6.3 Build and test

The build regenerates `lex_hash.h` and `lex_token.h` automatically. After `cmake --build .`:

```sh
cd <build-dir>/mysql-test
./mtr keywords sql_mode                    # surfaces reserved-word regressions
./mtr suite/compat/oracle/keywords         # Oracle mode equivalent
./mtr perfschema.start_server_low_digest_sql_length   # if you changed symbols[] count
```

These three tests are the canary set for parser changes. Any new feature also needs at least one MTR test of its own — see [`mysql-test/CLAUDE.md`](../../mysql-test/CLAUDE.md) and [`.claude/playbooks/add-mtr-test.md`](../../.claude/playbooks/add-mtr-test.md).

Real examples to study:

- **[MDEV-5092 (UPDATE … RETURNING)](https://jira.mariadb.org/browse/MDEV-5092)** — added `RETURNING` and `OLD_VALUE` (later promoted to a function-name in MDEV-39119 / MDEV-39179 follow-ups).
- **[MDEV-34391 (`SET PATH`)](https://jira.mariadb.org/browse/MDEV-34391)** — new keyword on the `SET` statement form.
- **[MDEV-19683 (Oracle `TO_DATE`)](https://jira.mariadb.org/browse/MDEV-19683)** — Oracle-mode-only function.
- **[MDEV-37072 (`IS JSON` predicate)](https://jira.mariadb.org/browse/MDEV-37072)** — new predicate keyword.

`git log --oneline -- sql/sql_yacc.yy | head -30` for more.

## 7. Shift/reduce and reduce/reduce conflicts

The current MariaDB grammar accepts a non-zero number of shift/reduce conflicts:

```
%ifdef MARIADB
%expect 70
%else
%expect 71
%endif
```

(See [`sql_yacc.yy:387-391`](../sql_yacc.yy).) The file's own comment is explicit: **"We should not introduce any further shift/reduce conflicts."** Treat the `%expect` count as a ratchet — it must never go up. Bison's `-v` output (`sql_yacc.output`) is the diagnostic.

Tools the grammar uses today:

- **`%prec <token>`** — bind a rule to a precedence higher/lower than a "fence" token. There are special `PREC_BELOW_*` tokens declared near the top with `%left` / `%right` solely to act as precedence anchors:

  ```
  %left   PREC_BELOW_IDENTIFIER_OPT_SPECIAL_CASE
  %left   TRANSACTION_SYM TIMESTAMP PERIOD_SYM SYSTEM USER COMMENT_SYM
  ```

  Used at the rule site: `/* empty */ %prec PREC_BELOW_IDENTIFIER_OPT_SPECIAL_CASE`.

- **Rule restructuring** — split a context-sensitive rule into two variants so each individual production has the lookahead bison needs.

- **Token contraction in the lexer** — when a two-token pattern would need LALR(2), [`Lex_input_stream::lex_token`](../sql_lex.cc:1891) reads ahead and emits a single combined token. `WITH ROLLUP` → `WITH_ROLLUP_SYM` is the canonical example.

Find existing usage to crib from: `grep -n '%prec' sql/sql_yacc.yy | head -20`. The file's comment block around line 1290–1330 documents the patterns.

## 8. The optimizer-hint sub-parser

[`opt_hints_parser.{cc,h}`](../opt_hints_parser.cc) is a separate hand-written parser for the contents of `/*+ … */` comments. It does **not** go through bison.

The main lexer recognises a hint comment and returns `HINT_COMMENT` (see [`sql_lex.cc:2538`](../sql_lex.cc)); later — typically in `JOIN::prepare` — the hint payload is fed to `Optimizer_hint_parser` (instantiated at [`sql_lex.cc:13908`](../sql_lex.cc)). The result is an `Optimizer_hint_parser_output` containing `Opt_hints_qb` / `Opt_hints_table` / `Opt_hints_global` nodes, applied during `JOIN::optimize` via [`opt_hints.cc`](../opt_hints.cc).

The hint parser is a recursive-descent parser over a small `Extended_string_tokenizer`, with token IDs declared as a `enum class TokenID` in [`opt_hints_parser.h`](../opt_hints_parser.h). Adding a new hint:

1. Add a `TokenID` (and tokenizer recognition) for the new hint name.
2. Add a rule under `Optimizer_hint_parser` (a `simple_parser`-template-derived class).
3. Add an `opt_hints_enum` value and an entry in `opt_hint_info[]`.
4. Add an `Opt_hints_*` AST node if the hint carries data the optimizer needs to find by name.
5. Apply the hint in `JOIN::optimize` (or wherever it acts).

Out of scope for this reference — see [`sql/docs/optimizer.md`](optimizer.md) §"Hints".

## 9. Stored-program parsing

When the grammar sees `CREATE PROCEDURE` / `CREATE FUNCTION` / `CREATE TRIGGER` / `CREATE EVENT`, the body is parsed inside the **same** bison parser but with `LEX::sphead` set. Each SQL statement inside the routine produces an `sp_instr_*` instruction; per-routine declarations (variables, cursors, handlers, conditions) land in `sp_pcontext` (the **parse**-time scope tree); the program's instructions land in `sp_head::m_instr`.

The same parser state is **re-entered** for each statement inside the routine — `sp_head` accumulates instructions across many `MYSQLparse()` calls if the routine spans multiple statements (though for `CREATE`, it's all one `MYSQLparse()` invocation).

Runtime execution uses `sp_rcontext` (the **run**-time stack of variable values, cursor instances, and handlers). See [`sql/docs/stored-programs.md`](stored-programs.md) for the full compile-vs-execute model.

## 10. Pitfalls and review patterns

Patterns reviewers consistently flag:

- **New reserved keyword without a compatibility note** — needs at least a `disabled-list` / `noupgrade-test` discussion in the PR body. The KB "Reserved Words" page is also part of release-notes review.
- **Adding a rule that introduces a shift/reduce conflict** — `%expect` must not go up. Either restructure the rule, add a `%prec`, or contract tokens in the lexer.
- **Forgetting the Oracle-mode variant** when the feature should apply in both modes. The two parsers are independent — a rule added under `%ifdef MARIADB` is *invisible* to `ORAparse()`.
- **Inserting in the wrong `keyword_*` list** — production-position mismatch silently breaks `my_new_kw` as a column alias, or breaks it in only some positions. Pick by where the word must legally appear, not by "what feels close".
- **Adding the token in `sql_yacc.yy` but not in `lex.h`** — bison knows the token exists; the lexer never returns it; the rule is unreachable. Compile succeeds, parse fails.
- **Hand-editing `sql_yacc.cc` / `lex_hash.h` / `yy_mariadb.cc`** — these are generated. The change is lost on the next build.
- **Touching `sql/gen_yy_files.cmake` to "fix" a build issue** — almost always wrong. The fix belongs in `sql_yacc.yy`'s `%ifdef` shape.
- **Adding `#ifdef`-gated symbols to `lex.h`** — explicitly forbidden by the in-file comment. The symbol tables are feature-set-independent.
- **Not updating `perfschema.start_server_low_digest_sql_length.result`** when `symbols[]` or `sql_functions[]` changes — its digest length depends on the keyword count.
- **Forgetting MTR coverage for the new keyword as an alias / column name** if it's non-reserved. A passing `keywords.test` doesn't prove a new word *is* still usable as an identifier; add a focused test that uses it that way.

## 11. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) §"Parser & lexer" — the parent map.
- [`.claude/playbooks/add-sql-function.md`](../../.claude/playbooks/add-sql-function.md) — when a parser change is and isn't required (in most cases, it isn't).
- [`.claude/review/coding-style.md`](../../.claude/review/coding-style.md), [`.claude/review/api-and-architecture.md`](../../.claude/review/api-and-architecture.md) — style and architecture rules.
- Related references:
  - [`sql/docs/item-system.md`](item-system.md) — what a parsed `Item *` becomes.
  - [`sql/docs/optimizer.md`](optimizer.md) — how the optimizer-hint AST is applied.
- Related references:
  - [`sql/docs/stored-programs.md`](stored-programs.md) — `sp_head` / `sp_pcontext` / `sp_rcontext` in detail.

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `5b6d020d1fe72d7ce685ae6fe7a5bbab6029b507` (branch `main`).
- **Files surveyed:**
  - [`sql/sql_yacc.yy`](../sql_yacc.yy) — 20956 lines; sampled the preamble (1–100), token / type / precedence sections (376–2090), a representative `%ifdef ORACLE` body (11003–11045), the `keyword_*` cluster (16600–16830), and the `%ifdef MARIADB` `%type` block (2051–2088). Grep recipes: `grep -n '^%ifdef\|^%else\|^%endif' sql/sql_yacc.yy` (24 `%ifdef`s), `grep -n '^keyword_' sql/sql_yacc.yy` (the non-terminal cluster), `grep -n '%prec' sql/sql_yacc.yy`.
  - [`sql/lex.h`](../lex.h) — 807 lines; both tables (`symbols[]` 49–751, `sql_functions[]` 754–802), header comments, the symbol/feature warning.
  - [`sql/gen_yy_files.cmake`](../gen_yy_files.cmake) — full read (43 lines). Confirmed the file is in `sql/`, not `cmake/`.
  - [`sql/CMakeLists.txt`](../CMakeLists.txt) — lines around the parser pipeline (67–96, 388–432) to confirm how `gen_lex_hash`, `gen_lex_token`, and `BISON_TARGET` are wired.
  - [`sql/sql_lex.h`](../sql_lex.h) — `struct LEX` (3208–3500), `Lex_input_stream` (2458–), `Yacc_state` (5250–5328), the `MYSQLlex` extern.
  - [`sql/sql_lex.cc`](../sql_lex.cc) — `MYSQLlex` / `ORAlex` (1879–1888), `Lex_input_stream::lex_token` (1891–), the `HINT_COMMENT` site (2538), the `Optimizer_hint_parser` instantiation (13908).
  - [`sql/gen_lex_hash.cc`](../gen_lex_hash.cc), [`sql/gen_lex_token.cc`](../gen_lex_token.cc) — first 90 lines each, enough to verify role.
  - [`sql/opt_hints_parser.{cc,h}`](../opt_hints_parser.cc) — first 60 lines of each, confirms separate hand-written parser.
  - [`sql/lex_ident.h`](../lex_ident.h), [`sql/lex_ident_sys.h`](../lex_ident_sys.h), [`sql/lex_ident_cli.h`](../lex_ident_cli.h), [`sql/lex_string.h`](../lex_string.h) — header preambles to confirm the wrapper-zoo table.
  - Recent commit log (`git log --oneline -20 -- sql/sql_yacc.yy`, `git log --oneline -20 -- sql/lex.h`) to source the example MDEVs (MDEV-5092, MDEV-34391, MDEV-19683, MDEV-37072, MDEV-10152).
- **Deliberately excluded:**
  - Full grammar excerpts — the file is 21 k lines; this doc points at sections, it does not paraphrase them.
  - The full token type-tag list (`<lex_str>`, `<ident_sys>`, `<spblock>`, `<kwd>`, `<tril>`, …) — covered by `grep -n '^%type' sql/sql_yacc.yy`.
  - Bison-specific debugging (`yacc -v`, `bison.output` reading) — generic bison knowledge.
  - Charset/collation handling inside identifiers — covered in [`sql/docs/charset-and-collation.md`](charset-and-collation.md).
  - The `digest` / `Performance Schema` interaction (token digest, statement digest hash) — performance-schema concern, not a parser concern.
- **Refresh procedure:**
  - Re-run `wc -l sql/sql_yacc.yy sql/lex.h` and bump references if structure has shifted.
  - Re-walk `grep -n '^%ifdef' sql/sql_yacc.yy | wc -l` — if it changes meaningfully, the §2 layout table may need refreshing.
  - Re-walk `git log --oneline -20 -- sql/sql_yacc.yy` for fresher MDEV examples.
  - Bump `last-verified`.
