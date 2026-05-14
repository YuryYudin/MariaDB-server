---
applies-to: main
last-verified: 2026-05-14
source-of-truth: include/m_ctype.h, sql/sql_string.{cc,h}, sql/sql_type.{cc,h}, sql/item.cc, strings/
---

# Reference: charsets and collations

Deep dive on how MariaDB represents character sets, collations, padding, and how collation propagates through string operands. The *expression-tree side* (how an `Item_str_func` picks a result collation) lives in [`sql/docs/item-system.md`](item-system.md) §"Charset / collation propagation through Items" — this doc explains the underlying machinery and is its source-of-truth pointer.

---

## 1. TL;DR

- **A `CHARSET_INFO` describes one collation.** Encoding + comparison rules + padding semantics are bundled together. `utf8mb4_general_ci` and `utf8mb4_bin` share an encoding but are two distinct `CHARSET_INFO` instances. Defined in [`include/m_ctype.h`](../../include/m_ctype.h) ~856.
- **Every `String` and every `Field` carries a `CHARSET_INFO *`.** [`class String`](../sql_string.h) inherits from [`class Charset`](../sql_string.h) (line 107). Operations that look like "just memcpy" silently rely on the source and destination sharing a charset; they're a bug when they don't.
- **Collation aggregation is explicit, not implicit.** For multi-operand string functions you *must* call one of `agg_arg_charsets_*` from `fix_length_and_dec()`. Skipping it gets "Illegal mix of collations" at the wrong time, or — worse — a silently wrong result collation.
- **Derivation is the priority code.** `EXPLICIT < NONE < IMPLICIT < SYSCONST < CAST < USERVAR < COERCIBLE < NUMERIC < IGNORABLE`. The strongest (lowest number) wins; ties on equal collation are fine, ties on different collation are an error.
- **Per-byte access without charset awareness is a recurring bug.** Raw `my_charset_filename` bytes are not UTF-8 (InnoDB identifier display, PR4342). `length()` is bytes; `numchars()` is characters. They differ by up to 4× for utf8mb4.

---

## 2. The `CHARSET_INFO` structure

[`include/m_ctype.h`](../../include/m_ctype.h) ~856:

```sh
grep -n 'struct charset_info_st$' include/m_ctype.h     # the struct
grep -n 'struct my_charset_handler_st\|struct my_collation_handler_st' include/m_ctype.h
grep -n 'extern MYSQL_PLUGIN_IMPORT struct charset_info_st' include/m_ctype.h
```

One instance per (charset, collation) pair. Static, link-time data — there is no per-thread mutation.

| Field | Role |
|---|---|
| `number` | Numeric collation ID (the `id` column in `INFORMATION_SCHEMA.COLLATIONS`). Stable across versions. |
| `primary_number` / `binary_number` | The "default" and `_bin` collation IDs for the same charset family. Used to derive sibling collations. |
| `state` | Bitmask. `MY_CS_PRIMARY` (32), `MY_CS_BINSORT` (16), `MY_CS_COMPILED` (1), `MY_CS_NOPAD` (0x20000), `MY_CS_STRNXFRM` (64), `MY_CS_PUREASCII`, … — full list at [`m_ctype.h`](../../include/m_ctype.h) ~280. |
| `cs_name` / `coll_name` | `LEX_CSTRING`s, e.g. `"utf8mb4"` / `"utf8mb4_general_ci"`. |
| `mbminlen` / `mbmaxlen` | Bytes-per-character bounds. utf8mb4: 1..4. utf16: 2..4. ucs2: 2..2. latin1: 1..1. `use_mb() == (mbmaxlen > 1)`. |
| `pad_char` | The space-padding code-point (`0x20` for most). |
| `min_sort_char` / `max_sort_char` | Lowest / highest sort weight — used by `like_range()`, `min_str()`, `max_str()` for range index lookups. |
| `cset` | `MY_CHARSET_HANDLER *` — encoding-level virtuals: `mb_wc`, `wc_mb`, `numchars`, `well_formed_char_length`, `lengthsp`, `caseup`, `casedn`, `numcells`, `charpos`. ([`m_ctype.h`](../../include/m_ctype.h) ~556 sets it via the typedef on line 81.) |
| `coll` | `MY_COLLATION_HANDLER *` — comparison-level virtuals: `strnncoll`, `strnncollsp`, `strnncollsp_nchars`, `strnxfrm`, `strnxfrmlen`, `hash_sort`, `wildcmp`, `like_range`, `instr`. ([`m_ctype.h`](../../include/m_ctype.h) ~555.) |
| `uca` | Per-collation UCA (Unicode Collation Algorithm) tables, when applicable. |
| `casefold` | Per-codepoint case-folding tables. |

There is one "well known" `CHARSET_INFO` per common collation, extern'd from `m_ctype.h` ~1542:

| Symbol | Meaning |
|---|---|
| `my_charset_bin` | Binary "no-collation" charset. Equality is `memcmp`. Carrier for `BLOB` / `BINARY`. |
| `my_charset_latin1` / `my_charset_latin1_nopad` | latin1 with the two padding regimes. |
| `my_charset_filename` | Server-internal encoding used for on-disk filenames. **Not UTF-8.** Names round-trip through `filename_to_tablename()` / `tablename_to_filename()`. Misreading these bytes as UTF-8 is the InnoDB identifier-display bug class (PR4342). |
| `my_charset_utf8mb3_general_ci`, `my_charset_utf8mb4_unicode_nopad_ci`, … | The named user-facing collations. |
| `system_charset_info` | The current "server identifier" charset. Set during startup to `my_charset_utf8mb3_general1400_as_ci` (see [`sql/mysqld.cc`](../mysqld.cc) ~5990, ~8282). Use for all user-visible identifier display. |
| `system_charset_info_for_i_s` | Same role but for older I_S compatibility. |
| `files_charset_info` | Charset of filesystem-level metadata (`.frm` strings, etc.). |

Per-charset implementations live in [`strings/ctype-*.c`](../../strings/) — one file per encoding family. `ctype-utf8.c`, `ctype-uca.c` (the UCA-based collations), `ctype-big5.c`, `ctype-latin1.c`, …. Read [`strings/CHARSET_INFO.txt`](../../strings/CHARSET_INFO.txt) for the original design notes.

---

## 3. The `String` class

[`sql/sql_string.h`](../sql_string.h) ~833. `class String : public Charset, public Binary_string`. Charset-aware mutable buffer; the workhorse for SQL string values. `Binary_string` holds the byte buffer; `Charset` (line 107) holds the `CHARSET_INFO *`.

Common operations and the charset rule each follows:

```sh
grep -n 'class String\b\|class Charset\b\|^bool String::\|^int sortcmp\|^int stringcmp' sql/sql_string.h sql/sql_string.cc
```

| Operation | Charset behaviour |
|---|---|
| `String(s, len, cs)` ([`sql_string.h`](../sql_string.h) ~844) | Adopts `cs`. No conversion. |
| `operator=`, copy ctor ([`sql_string.h`](../sql_string.h) ~913) | Copies the source's charset; no transcoding. |
| `set(char *, len, cs)` ([`sql_string.h`](../sql_string.h) ~859) | Adopts `cs`. No transcoding. |
| `copy(const char *, len, cs_from, cs_to, &errors)` ([`sql_string.h`](../sql_string.h) ~960, impl `sql_string.cc`) | **The transcoding entry point.** Converts byte-by-byte through `mb_wc` → `wc_mb`. `*errors` counts characters that couldn't be encoded. |
| `copy(const String *str, CHARSET_INFO *tocs, &errors)` | Wrapper that picks up `str`'s charset as `cs_from`. |
| `can_be_safely_converted_to(tocs)` ([`sql_string.h`](../sql_string.h) ~951) | True if every character of `this` is representable in `tocs`. |
| `String_copier::well_formed_copy` ([`sql_string.h`](../sql_string.h) ~83) | Copy at most `nchars` characters, replacing malformed bytes with `?`. Used by storage-engine writes. |

**Pitfall.** `set()`, `operator=`, the copy ctor, `Binary_string::operator=`, and `memcpy` between `String` buffers all preserve bytes — they do **not** transcode. If the source and destination are in different charsets, the result is byte-coherent in neither. The fix is `String::copy(..., cs_to, ...)`.

---

## 4. `DTCollation` and collation derivation

[`sql/sql_type.h`](../sql_type.h) ~3110 (`enum Derivation`) and ~3163 (`class DTCollation`). A `DTCollation` is a (charset, derivation, repertoire) triple.

### Derivation values

```sh
grep -n 'enum Derivation\b' sql/sql_type.h
```

Lower number = stronger. The enum (`sql_type.h` ~3110) is, in priority order:

| Value | Name | Where it comes from |
|---|---|---|
| 0 | `DERIVATION_EXPLICIT` | An explicit `COLLATE ...` clause. Strongest. |
| 1 | `DERIVATION_NONE` | A mix of two different collations that have **already been aggregated**. Acts as a "poison" marker — further aggregation with a different collation fails. |
| 2 | `DERIVATION_IMPLICIT` | Table columns, SP variables, `BINARY(expr)`, `CAST(expr AS BINARY)`. |
| 3 | `DERIVATION_SYSCONST` | utf8 metadata functions: `DATABASE()`, `CURRENT_ROLE()`, `USER()`. |
| 4 | `DERIVATION_CAST` | `CAST(string_expr AS CHAR)`, `CONVERT(expr USING cs)`. |
| 5 | `DERIVATION_USERVAR` | String user variables (`@var`). |
| 6 | `DERIVATION_COERCIBLE` | String literals — `'foo'`. |
| 7 | `DERIVATION_NUMERIC` | Number/temporal coerced to string (e.g. `CONCAT('x', 42)`). |
| 8 | `DERIVATION_IGNORABLE` | Explicit `NULL`. Weakest. |

The names are slightly confusing: `EXPLICIT` is *strongest* (0), `IGNORABLE` is *weakest* (8). Read as "specificity": an `EXPLICIT COLLATE` is the most specific request the user can make.

### `DTCollation::aggregate()`

The pairwise merge. Implementation: [`sql/item.cc`](../item.cc) ~2549:

```sh
grep -n '^bool DTCollation::aggregate' sql/item.cc
```

Algorithm (paraphrased from `item.cc:2549`):

1. **Different encodings.**
   - If one side is `my_charset_bin` and its derivation ≤ the other's → take `my_charset_bin` (binary "wins" at equal or stronger derivation).
   - Else with `MY_COLL_ALLOW_SUPERSET_CONV`, if one side's charset is a superset of the other → keep the superset.
   - Else with `MY_COLL_ALLOW_COERCIBLE_CONV`, the weaker side (higher derivation) gets converted to the stronger side — but only above `DERIVATION_SYSCONST`.
   - Otherwise → set `(my_charset_bin, DERIVATION_NONE)` and return error.
2. **Same encoding, different derivations.** Take the one with the *stronger* (lower) derivation.
3. **Same encoding, same derivation, different collation.**
   - If `DERIVATION_EXPLICIT` → set `(0, DERIVATION_NONE)` and **return error** (`Illegal mix of collations`).
   - If both are `_bin` → error.
   - If exactly one is `_bin` → take the `_bin` side.
   - Otherwise → fall back to the encoding's `_bin` collation at `DERIVATION_NONE`.
4. **Repertoire** is OR-ed across the two sides (`MY_REPERTOIRE_ASCII | MY_REPERTOIRE_EXTENDED = MY_REPERTOIRE_UNICODE30`).

The repertoire bit lets the optimizer prove that an ASCII-only string can be safely reinterpreted in *any* ASCII-compatible charset without a `copy()`.

---

## 5. `agg_arg_charsets_*` helpers

Defined in [`sql/sql_type.h`](../sql_type.h) ~3488 (on `Type_std_attributes`); thin wrappers exposed on `Item_func` at [`sql/item.h`](../item.h) ~5976.

```sh
grep -n 'agg_arg_charsets' sql/item.h sql/sql_type.h
grep -n 'agg_arg_charsets_for_string_result' sql/item_strfunc.cc | head
```

**Call exactly one of these from `fix_length_and_dec()` of any string-returning or string-comparing function.** Each picks a flag set:

| Helper | Flags ([`sql_type.h`](../sql_type.h) ~3506–3540) | Use for |
|---|---|---|
| `agg_arg_charsets_for_string_result(coll, args, n)` | `SUPERSET_CONV \| COERCIBLE_CONV \| NUMERIC_CONV` | Concat-like: `CONCAT`, `LOWER`, `UPPER`, `LPAD`, `RPAD`, `REVERSE`. Allows `DERIVATION_NONE` (the result can be unaggregated). |
| `agg_arg_charsets_for_string_result_with_comparison(coll, args, n)` | adds `DISALLOW_NONE` | String result + internal comparison: `REPLACE`, `INSERT`, `IF` on strings. |
| `agg_arg_charsets_for_comparison(coll, args, n)` | `SUPERSET_CONV \| COERCIBLE_CONV \| DISALLOW_NONE` (no `NUMERIC_CONV`) | `=`, `<`, `LIKE`, `RLIKE`. Numeric args don't force conversion to `@@character_set_connection`. |
| `agg_arg_charsets(coll, args, n, flags, item_sep)` | caller-supplied | Generic primitive. |

The functions do two things in sequence (see [`sql_type.h`](../sql_type.h) ~3491):

1. `agg_item_collations(c, fname, items, n, flags, item_sep)` — runs `DTCollation::aggregate` over every operand, returning `true` on incompatible mix (raises `ER_CANT_AGGREGATE_2COLLATIONS` / `ER_CANT_AGGREGATE_3COLLATIONS` / `ER_CANT_AGGREGATE_NCOLLATIONS`).
2. `agg_item_set_converter(...)` — wraps any operand whose charset differs from the aggregated result in an `Item_func_conv_charset`, so the runtime gets identically-encoded inputs.

**Forgetting to call one is the canonical "Illegal mix of collations" rejection** ([`sql/docs/item-system.md`](item-system.md) §"Charset / collation propagation"). The symptom may be subtle — the function may "happen to work" until the user uses a non-default collation in an operand.

The `item_sep` argument is the stride between successive `Item *`s in the `args` array. `1` for consecutive, `3` for e.g. `REPLACE(s, from, to)` where `from` is wedged between two string operands at non-consecutive indices.

---

## 6. `well_formed_len` / `well_formed_char_length` and `mb_charlen`

Multi-byte encodings (utf8mb4, utf16, big5, sjis, …) accept some byte sequences and reject others as malformed. Before storing user input into a fixed-width column — or before any operation that assumes well-formedness — the server validates with `well_formed_char_length`.

```sh
grep -n 'well_formed_char_length\b' include/m_ctype.h
```

The function-pointer member on `MY_CHARSET_HANDLER` ([`m_ctype.h`](../../include/m_ctype.h) ~802):

```c
size_t (*well_formed_char_length)(CHARSET_INFO *cs,
                                  const char *str, const char *end,
                                  size_t nchars,
                                  MY_STRCOPY_STATUS *status);
```

Returns the number of *characters* in `[str, end)` that form a valid prefix of at most `nchars` characters. The byte offset where validation stopped lands in `status->m_source_end_pos`; the location of the first malformed byte (if any) lands in `status->m_well_formed_error_pos` (`NULL` if the entire prefix is well-formed).

There is a wrapper `my_well_formed_length()` ([`m_ctype.h`](../../include/m_ctype.h) ~2002) that returns the byte length. Use it when you need to truncate to the longest valid prefix.

Related per-character helper: `charlen(cs, str, end)` ([`m_ctype.h`](../../include/m_ctype.h) ~777) — returns the byte length of the leftmost character. Returns `MY_CS_ILSEQ` on a bad byte, `MY_CS_TOOSMALLN(x)` on a truncated sequence.

**Pattern.** `Field_string::store()`, `Field_varstring::store()`, etc. use `well_formed_copy_nchars()` / `String_copier::well_formed_copy()` ([`sql_string.h`](../sql_string.h) ~83). New code that hand-validates should follow the same path; do not roll a parallel validator.

---

## 7. `strnxfrm` — comparison weights

For ORDER BY, GROUP BY, index lookup, and (sometimes) equality, the server precomputes a *sort weight* via `strnxfrm`. Two strings collation-equal iff their weights byte-equal — which makes index keys comparable with `memcmp`.

```sh
grep -n 'strnxfrm\|strnncollsp\|hash_sort' include/m_ctype.h
```

The collation handler ([`m_ctype.h`](../../include/m_ctype.h) ~618):

```c
my_strnxfrm_ret_t (*strnxfrm)(CHARSET_INFO *,
                              uchar *dst, size_t dstlen, uint nweights,
                              const uchar *src, size_t srclen, uint flags);
size_t (*strnxfrmlen)(CHARSET_INFO *, size_t);
```

`strnxfrmlen(srclen)` tells you how much output buffer to allocate. For simple 8-bit collations `dst_len == src_len`; for UCA collations weights can be several bytes per source character.

The companion comparator is `strnncollsp(s, slen, t, tlen)` ([`m_ctype.h`](../../include/m_ctype.h) ~561), which compares two strings under the collation's *pad space* semantics — the most-common comparison entry point. `sortcmp()` ([`sql/sql_string.cc`](../sql_string.cc) ~853) is the `String` wrapper.

For hash partitioning, hash join, and `MEMORY` engine keys, `hash_sort()` ([`m_ctype.h`](../../include/m_ctype.h) ~639) computes a 64-bit weight without materialising the full `strnxfrm` output.

---

## 8. Padding semantics: `PAD SPACE` vs `NO PAD`

Two intersecting axes:

1. **Collation `PAD SPACE` / `NO PAD` attribute** — `MY_CS_NOPAD` (`0x20000`) flag in `state` ([`m_ctype.h`](../../include/m_ctype.h) ~297). When set, `strnncollsp` treats trailing spaces as significant (`'a' < 'a '`); when clear, trailing spaces are ignored (`'a' = 'a '`). Modern Unicode collations like the `_0900_*` family are `NO PAD`; the legacy collations are `PAD SPACE`. SQL-standard behaviour is `NO PAD`. Every PAD-SPACE collation has a `_nopad` sibling (`my_charset_latin1_nopad`, `my_charset_utf8mb4_unicode_nopad_ci`, …).
2. **`PAD_CHAR_TO_FULL_LENGTH` SQL mode** — orthogonal. Controls whether `CHAR(N)` columns return their stored padding on read; see [`sql/sql_mode.h`](../sql_mode.h) ~42–107.

The `nopad` family was added piecewise; recent collation infrastructure work to track:

```sh
git log --oneline -- strings/ sql/lex_charset.cc | head
```

- **MDEV-20912** — `utf8mb4_0900_*` collations (the SQL-standard `NO PAD` UCA-9.0 family). Multiple commits, e.g. `3bbe11acd93`, `7fcaab7aaac`.
- **MDEV-9826** — hash-algorithm dispatch on `my_collation_handler_st` for `PARTITION BY [LINEAR] KEY` (`bd1e74aa0b4`). Commit `0f4eaad51cf` restored `my_hash_sort_simple_nopad` after a test regression.
- **MDEV-30746** — `ucs2_general_mysql500_ci` order-changed handling, baked into [`Charset::collation_changed_order()`](../sql_string.h) ~178.
- **MDEV-35620** — UBSAN: applying zero offset to null pointer in `my_hash_sort_mb_nopad_bin` and `my_strnncollsp_utf8mb4_bin`.

`strnncollsp_nchars` ([`m_ctype.h`](../../include/m_ctype.h) ~613) is the "compare with a CHAR(N) shape" variant that produces consistent results for `NO PAD` collations even when the operands have already been trimmed (e.g. InnoDB compact-format `CHAR`).

---

## 9. Common bug patterns

Patterns that recur in PR review of this subsystem. Citations are the canonical examples; the full list is in [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Charset / collation" and [`.claude/review/logging-and-errors.md`](../../.claude/review/logging-and-errors.md) §"InnoDB identifier display".

- **InnoDB raw `my_charset_filename` bytes printed as UTF-8.** PR4342. Use `ut_get_name()` / convert to `system_charset_info` before display. Add a test with non-ASCII identifiers — *the test is part of the rule* (PR4342 dr-m: "A test case for this must in...").
- **Forgotten `agg_arg_charsets_*` in a new `Item_str_func`.** Result is either always-`@@character_set_connection` (wrong for column inputs) or "Illegal mix" at a baffling time. Every `Item_str_func` in [`sql/item_strfunc.cc`](../item_strfunc.cc) calls one — copy from a sibling.
- **`memcpy` between two `String`s in different charsets.** Bytes survive, characters don't. The destination ends up internally inconsistent (`charset()` says one thing, contents are another). Fix is `String::copy(src->ptr(), src->length(), src->charset(), this_cs, &errors)`.
- **`strcmp(a, b)` on identifiers.** Identifiers compare under `system_charset_info` (case-insensitive utf8mb3 by default), not byte-equal. PR4906 — use a `cmp` helper or `my_charset_utf8_bin` strncoll. The same applies to index names, column names, role names.
- **Hard-coded `system_charset_info` where `thd->variables.character_set_results` belongs.** Output to the client uses the *result* charset, not the *system* charset. Audit any new client-facing string production for this.
- **`length()` (bytes) where `numchars()` (characters) is needed.** utf8mb4: one character is 1–4 bytes. `SUBSTRING(x, 1, 5)` slices characters, not bytes; `LENGTH(x)` returns bytes, `CHAR_LENGTH(x)` returns characters.
- **Comparing two `String *` via `memcmp`.** Use `sortcmp(s, t, cs)` ([`sql_string.cc`](../sql_string.cc) ~853) for collation-aware comparison; `stringcmp(s, t)` ([`sql_string.cc`](../sql_string.cc) ~877) for byte-exact (no collation, end spaces compared). The implicit collation context is the caller's responsibility.
- **Storing user input into a fixed-width `CHAR`/`VARCHAR` without `well_formed_copy`.** Malformed bytes that bypass validation cause downstream `strnncollsp` UB and assertion failures (see MDEV-35620 et al.). The `String_copier::well_formed_copy` path is the canonical one.
- **Aliasing a `String`'s buffer with a `set()` and then mutating the source.** The destination keeps the source's `CHARSET_INFO *` plus a dangling buffer. `String_copier::well_formed_copy` plus `String::copy` is the safe path. Compare MDEV-32758 / PR4883 (the `Item_func_trim` family of buffer-alias bugs).
- **Repertoire reset across an aggregation.** `DTCollation::aggregate` *ORs* repertoires, but `DTCollation::set(cs)` *re-derives* from `cs->state & MY_CS_PUREASCII`. Use `set(cs, deriv, repertoire)` when you've already established a tighter repertoire.

---

## 10. See also

- [`sql/CLAUDE.md`](../CLAUDE.md) §"Where to start, by task type" — "Charset / collation issue" row.
- [`sql/docs/item-system.md`](item-system.md) §"Charset / collation propagation through Items" — the Item-side surface: `Item::collation`, the `agg_arg_charsets_*` family in expression context, repertoire propagation through `fix_length_and_dec()`.
- [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Charset / collation" — rule list with PR citations.
- [`.claude/review/logging-and-errors.md`](../../.claude/review/logging-and-errors.md) §"InnoDB identifier display" — `my_charset_filename` → `system_charset_info` pattern.
- [`strings/CHARSET_INFO.txt`](../../strings/CHARSET_INFO.txt) — original (pre-handler-split) design notes; read after this doc, not before.
- [`include/m_ctype.h`](../../include/m_ctype.h) — the authoritative API. Don't paraphrase, grep it.

---

## How this doc was built

- **Date:** 2026-05-14.
- **HEAD at write time:** `23097b2d825` (branch `main`).
- **Files surveyed (with line landmarks):**
  - [`include/m_ctype.h`](../../include/m_ctype.h) — `struct charset_info_st` (~856), `MY_CHARSET_HANDLER` (~711), `MY_COLLATION_HANDLER` (~555), state flags (~280–300), well-known extern decls (~1542+).
  - [`sql/sql_string.h`](../sql_string.h) — `class Charset` (~107), `class String` (~833), copy/set/operator semantics; `class String_copier` (~58) and `well_formed_copy` (~83).
  - [`sql/sql_string.cc`](../sql_string.cc) — `sortcmp` (~853), `stringcmp` (~877).
  - [`sql/sql_type.h`](../sql_type.h) — `enum Derivation` (~3110), `class DTCollation` (~3163), `Type_std_attributes::agg_arg_charsets*` (~3488–3544).
  - [`sql/item.cc`](../item.cc) — `DTCollation::aggregate()` (~2549) — the canonical aggregation algorithm.
  - [`sql/item.h`](../item.h) — `Item_args::agg_arg_charsets*` wrappers (~5976–6017).
  - [`sql/mysqld.cc`](../mysqld.cc) — `system_charset_info` initialisation (~5990, ~8282).
  - [`sql/sql_mode.h`](../sql_mode.h) — `PAD_CHAR_TO_FULL_LENGTH` (~42–107).
  - [`.claude/review/correctness-and-security.md`](../../.claude/review/correctness-and-security.md) §"Charset / collation" — PR4342, PR4906.
  - [`.claude/review/logging-and-errors.md`](../../.claude/review/logging-and-errors.md) §"InnoDB identifier display" — PR4342.
  - [`sql/docs/item-system.md`](item-system.md) §"Charset / collation propagation through Items" (commit `3d669e661c8` and follow-ups) — for the cross-reference.
- **Commands used:**
  - `grep -n 'struct charset_info_st\b' include/m_ctype.h`
  - `grep -n 'class DTCollation\|enum Derivation' sql/sql_type.h`
  - `grep -n 'DTCollation::aggregate\b' sql/item.cc`
  - `grep -n 'agg_arg_charsets' sql/sql_type.h sql/item.h`
  - `git log --oneline -- strings/ sql/lex_charset.cc sql/sql_string.cc | head -25`
- **Deliberately excluded:**
  - The Item-side rules of collation derivation in `fix_length_and_dec()` — that's [`sql/docs/item-system.md`](item-system.md)'s ground.
  - UCA implementation internals (`ctype-uca.c`) — beyond the scope of "what every server contributor needs". Read the file when you need it.
  - Plugin-supplied collations (`add_collation` callbacks) — rare, plugin-specific.
  - On-disk encoding of `.frm` strings, binlog event encoding — call sites of `system_charset_info` / `files_charset_info`, covered by [`sql/docs/replication.md`](replication.md) where it matters.
- **Refresh procedure:**
  - When `m_ctype.h` line numbers drift, re-grep with the recipes above; this doc treats names as load-bearing, not line numbers.
  - If a new `agg_arg_charsets_*` variant lands ([`sql/sql_type.h`](../sql_type.h)), add it to §5.
  - When a new `_0900_*` / `NO PAD` collation family arrives, extend §8's MDEV list (`git log --oneline -- strings/ sql/lex_charset.cc | head`).
  - On a new charset/collation PR-rejection pattern, add the bullet to §9 with the PR number and link the rulebook entry.
  - Bump `last-verified`.
