#!/usr/bin/env bash
set -euo pipefail

root="${1:-al/src}"
failed=0

while IFS= read -r line; do
  file="${line%%:*}"
  rest="${line#*:}"
  decl="${rest#*:}"
  object_name="$(printf '%s\n' "$decl" | sed -E 's/^[[:space:]]*[A-Za-z]+[[:space:]]+[0-9]+[[:space:]]+"?([^"]+)"?.*/\1/')"
  if printf '%s\n' "$object_name" | grep -Eiq '^DOPSWHS'; then
    echo "PASS $file uses DOPSWHS prefix"
  else
    echo "FAIL $file object name '$object_name' does not start with DOPSWHS"
    failed=1
  fi
done < <(grep -RInE '^[[:space:]]*(table|tableextension|page|pageextension|codeunit|report|xmlport|query|enum|enumextension|controladdin)[[:space:]]+[0-9]+[[:space:]]+' "$root" --include='*.al' | sort)

exit "$failed"
