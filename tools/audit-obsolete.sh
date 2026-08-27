#!/usr/bin/env bash
set -euo pipefail

root="${1:-al/src}"
failed=0

while IFS= read -r file; do
  if grep -qi 'ObsoleteState[[:space:]]*=' "$file"; then
    if grep -qi 'ObsoleteReason[[:space:]]*=' "$file" && grep -qi 'ObsoleteTag[[:space:]]*=' "$file"; then
      echo "PASS $file obsolete metadata complete"
    else
      echo "FAIL $file has ObsoleteState without ObsoleteReason and ObsoleteTag"
      failed=1
    fi
  fi
done < <(find "$root" -type f -name '*.al' | sort)

if [[ "$failed" -eq 0 ]]; then
  echo "PASS obsolete audit complete"
fi
exit "$failed"
