#!/usr/bin/env bash
# Print Maestro's screenshots to the log as base64, one per line, so a failed
# run can be seen from the job log alone (for environments that can read logs
# but not artifacts). Decode a line with: base64 -d > shot.png
set -uo pipefail
dir="${1:-maestro-output}"
echo "--- Files Maestro wrote"
find "$dir" -type f 2>/dev/null | head -40
find "$dir" -type f -name '*.png' 2>/dev/null | head -4 | while read -r shot; do
  echo "--- SCREENSHOT $shot"
  base64 -w 0 "$shot"
  echo
done
