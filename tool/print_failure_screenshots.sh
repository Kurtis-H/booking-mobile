#!/usr/bin/env bash
# Print Maestro's failure screenshots to the log as base64, one per line, so a
# failed run can be seen from the job log alone (for environments that can read
# logs but not artifacts). Decode a line with: base64 -d > shot.png
set -uo pipefail
dir="${1:-maestro-output}"
find "$dir" -name '*.png' -path '*❌*' 2>/dev/null | head -5 | while read -r shot; do
  echo "--- SCREENSHOT $shot"
  base64 -w 0 "$shot"
  echo
done
