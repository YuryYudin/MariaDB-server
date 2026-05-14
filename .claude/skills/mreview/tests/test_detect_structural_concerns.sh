#!/usr/bin/env bash
# Plain-bash test for lib/detect-structural-concerns.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"
SCRIPT="$LIB_DIR/detect-structural-concerns.sh"

fails=0
total=0
case_failed=0

case_start() { echo "--- $1"; total=$((total+1)); case_failed=0; }
fail() { echo "  FAIL: $1"; fails=$((fails+1)); case_failed=1; }
pass() { [ "$case_failed" -eq 0 ] && echo "  PASS"; }

assert_eq() { [ "$1" = "$2" ] || { fail "expected '$2' got '$1'"; return 1; }; }
assert_contains() {
  echo "$1" | grep -qE "$2" || { fail "output missing pattern: $2"; return 1; }
}

case_start "1: empty diff -> exit 0, no output"
empty=$(mktemp); : > "$empty"
out=$(bash "$SCRIPT" "$empty"); rc=$?
assert_eq "$rc" 0 && assert_eq "$out" ""
pass
rm -f "$empty"

case_start "2: no args -> exit 64"
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" 64
pass

case_start "3: S1 — non-trivial + line 3 times -> exit 1, S1 finding"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+  uint decimals= item->time_precision(thd);
+  t.trunc(decimals);
+  return t.to_native(to, decimals);
+  uint decimals= item->time_precision(thd);
+  t.trunc(decimals);
+  return t.to_native(to, decimals);
+  uint decimals= item->time_precision(thd);
+  t.trunc(decimals);
+  return t.to_native(to, decimals);
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 1
assert_contains "$out" "S1 \(likely DRY violation\)"
assert_contains "$out" "t\.trunc\(decimals\);"
pass
rm -f "$d"

case_start "4: trivial lines (} alone, blank) do not trigger S1"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+}
+}
+}
+
+
+
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 0
assert_eq "$out" ""
pass
rm -f "$d"

case_start "5: S5 — line appearing exactly 2 times -> exit 1, S5 finding"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+  return item->val_native_via_some_helper(thd, native_buffer_out);
+  return item->val_native_via_some_helper(thd, native_buffer_out);
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 1
assert_contains "$out" "S5 \(possible copy-paste\)"
pass
rm -f "$d"

case_start "6: S3 — diff adds a 'mirroring X' inline comment"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+/* MDEV-12345: truncate before pack, mirroring SomeSibling::TIME_to_native */
+/* Equivalent to the timestamp_common path at line 9314. */
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 1
assert_contains "$out" "S3 \(claim to verify\)"
pass
rm -f "$d"

case_start "7: S2/S6 — 2+ methods on same class in diff"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+bool Type_handler_time_common::Item_val_native_with_conversion(THD *thd, Item *item) {
+}
+bool Type_handler_time_common::Item_val_native_with_conversion_result(THD *thd, Item *item) {
+}
+bool Type_handler_time_common::Item_param_val_native(THD *thd, Item_param *item) {
+}
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 1
assert_contains "$out" "S2/S6 \(sibling-pattern check\)"
assert_contains "$out" "Type_handler_time_common"
pass
rm -f "$d"

case_start "8: clean diff (1 hunk, 1 method, no copy-paste) -> exit 0"
d=$(mktemp)
cat > "$d" <<'EOF'
diff --git a/foo.cc b/foo.cc
--- a/foo.cc
+++ b/foo.cc
@@ -1 +1 @@
+int new_function_that_does_one_thing_clean(int x) {
+  return x * 2;
+}
EOF
out=$(bash "$SCRIPT" "$d"); rc=$?
assert_eq "$rc" 0
assert_eq "$out" ""
pass
rm -f "$d"

echo "---"
echo "$((total-fails))/$total passed"
exit $fails
