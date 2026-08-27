#!/usr/bin/env bash
set -euo pipefail

root="${1:-al/src}"
permissions_dir="$root/Permissions"
permission_files=(
  "$permissions_dir/AdminPermissionSet.al"
  "$permissions_dir/UserPermissionSet.al"
  "$permissions_dir/ViewPermissionSet.al"
)

missing=0
for file in "${permission_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL permission file missing: $file"
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] || exit 1

while IFS= read -r file; do
  [[ "$file" == "$permissions_dir/"* ]] && continue
  object_id="$(awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*(table|tableextension|page|pageextension|codeunit|report|xmlport|query|enum|enumextension|profile|controladdin)[[:space:]]+[0-9]+/ { print $2; exit }' "$file")"
  [[ -n "$object_id" ]] || continue
  if grep -Eiq "(^|[^0-9])${object_id}([^0-9]|$)" "${permission_files[@]}"; then
    echo "PASS $file object $object_id mapped"
  else
    echo "FAIL $file object $object_id missing from Admin/User/View permission sets"
    missing=1
  fi
done < <(find "$root" -type f -name '*.al' | sort)

exit "$missing"
