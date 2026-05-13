#!/usr/bin/env bash
# derive-areas.sh: map a touched-paths.txt file (one path per line) to a
# unique, unordered list of coarse "area" labels (one per line). Used to
# select which rulebook sections apply to a review.
#
# Usage: derive-areas.sh <touched-paths.txt>
# Exit 64 on missing arg or unreadable file.
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: derive-areas.sh <touched-paths.txt>" >&2
  exit 64
fi

input=$1
if [ ! -r "$input" ]; then
  echo "derive-areas.sh: cannot read '$input'" >&2
  exit 64
fi

# Print first-appearance-ordered unique labels.
seen_sql=0
seen_storage_innobase=0
seen_storage=0
seen_mysql_test=0
seen_plugin=0
seen_cmake=0
seen_client=0
seen_extra=0
seen_errmsg=0

emit() {
  # $1: label, $2: name of "seen" flag variable
  local label=$1 flag=$2
  if [ "${!flag}" -eq 0 ]; then
    printf '%s\n' "$label"
    eval "$flag=1"
  fi
}

while IFS= read -r path || [ -n "$path" ]; do
  # Skip blank lines.
  [ -z "$path" ] && continue

  case "$path" in
    sql/share/errmsg-utf8.txt)
      emit "errmsg" seen_errmsg
      ;;
    sql/*)
      emit "sql/" seen_sql
      ;;
    storage/innobase/*)
      emit "storage/innobase/" seen_storage_innobase
      ;;
    storage/*)
      emit "storage/" seen_storage
      ;;
    mysql-test/*)
      emit "mysql-test/" seen_mysql_test
      ;;
    plugin/*)
      emit "plugin/" seen_plugin
      ;;
    CMakeLists.txt|cmake/*|*.cmake)
      emit "cmake" seen_cmake
      ;;
    client/*)
      emit "client/" seen_client
      ;;
    extra/*)
      emit "extra/" seen_extra
      ;;
    *)
      # No area emitted.
      ;;
  esac
done < "$input"
