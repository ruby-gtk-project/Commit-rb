#!/usr/bin/env bash
# The single source of truth for this fork's runtime gate.
#
# Every number any report, banner or external harness states about this
# port's test/drive suite must come from actually running this script, not
# from memory, a prior round's figure, or a subtotal computed by hand. Run
# it from the dev shell:
#
#   nix develop --command bash test/run_all.sh
#
# It runs every test/drive file in the suite, prints each file's own
# "N of N checks passed" / "DRIVE OK" line unmodified, then sums the totals
# itself and prints one final line of the form:
#
#   TOTAL: <passed> of <total> checks passed, 0 failed, covering 16 components
#
# That final line, and only a freshly-printed copy of it, is the fork's
# runtime gate. A gate figure that does not match a fresh run of this
# script is wrong and must not be repeated.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

NON_GUI_TESTS=(test/test_scm.rb test/test_settings.rb test/test_potfiles.rb)
GUI_TESTS=(test/test_translations.rb test/drive_welcome.rb test/drive_editor.rb test/drive_dev.rb)

total=0
passed=0
failed_files=()

run_one() {
  local file=$1
  local use_xvfb=$2
  local out
  if [ "$use_xvfb" = "xvfb" ]; then
    out=$(xvfb-run -a bundle exec ruby "$file" 2>&1)
  else
    out=$(bundle exec ruby "$file" 2>&1)
  fi
  local status=$?
  printf '%s\n' "$out"

  local line
  line=$(printf '%s\n' "$out" | grep -E '^[0-9]+ of [0-9]+ checks passed$' | tail -1)
  if [ -z "$line" ] || [ "$status" -ne 0 ]; then
    failed_files+=("$file")
    return
  fi
  local p t
  p=$(printf '%s' "$line" | awk '{print $1}')
  t=$(printf '%s' "$line" | awk '{print $3}')
  passed=$((passed + p))
  total=$((total + t))

  if [ "$use_xvfb" = "xvfb" ]; then
    case "$file" in
      *drive_*)
        printf '%s\n' "$out" | grep -q '^DRIVE OK$' || failed_files+=("$file (no DRIVE OK)")
        ;;
    esac
  fi
}

for f in "${NON_GUI_TESTS[@]}"; do
  echo "=== $f ==="
  run_one "$f" plain
done

for f in "${GUI_TESTS[@]}"; do
  echo "=== $f ==="
  run_one "$f" xvfb
done

echo
if [ "${#failed_files[@]}" -eq 0 ]; then
  echo "TOTAL: ${passed} of ${total} checks passed, 0 failed, covering 16 components"
  exit 0
else
  echo "TOTAL: ${passed} of ${total} checks passed, ${#failed_files[@]} FAILED file(s): ${failed_files[*]}"
  exit 1
fi
