#!/usr/bin/env bash
set -euo pipefail

translation_dir="${1:-al/Translations}"
# The compiler names the generated base XLIFF after app.json `name`
# (currently BCWMSApp.g.xlf). Keep the legacy DOPSWHS name as a fallback for
# older worktrees, but do not fail a valid build because of a stale hard-code.
base="$translation_dir/BCWMSApp.g.xlf"
if [[ ! -f "$base" && -f "$translation_dir/DOPSWHS.g.xlf" ]]; then
  base="$translation_dir/DOPSWHS.g.xlf"
fi
tr="$translation_dir/DOPSWHS.tr-TR.xlf"
de="$translation_dir/DOPSWHS.de-DE.xlf"
status=0

count_units() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }
  grep -Eic '<trans-unit[[:space:]>]' "$file"
}

for file in "$base" "$tr" "$de"; do
  if [[ -f "$file" ]]; then
    echo "PASS translation file present: $file"
  else
    echo "FAIL translation file missing: $file"
    status=1
  fi
done

base_count="$(count_units "$base")"
tr_count="$(count_units "$tr")"
de_count="$(count_units "$de")"
echo "PASS translation counts source=$base_count tr-TR=$tr_count de-DE=$de_count"

for locale in "tr-TR:$tr_count" "de-DE:$de_count"; do
  name="${locale%%:*}"
  count="${locale##*:}"
  delta=$(( base_count - count ))
  [[ "$delta" -lt 0 ]] && delta=$(( -delta ))
  if [[ "$delta" -gt 0 ]]; then
    echo "WARN translation delta for $name is $delta"
  else
    echo "PASS translation coverage for $name"
  fi
done

exit "$status"
