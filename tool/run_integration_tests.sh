#!/usr/bin/env bash
# Runs the integration tests on the emulator.
#
# Retries once, but only when no test ran at all: on a cold CI emulator the
# Flutter tool sometimes installs the app and never starts the tests. A test
# that runs and fails is never retried.
set -uo pipefail

run() {
  timeout 10m flutter test integration_test \
    --dart-define=API_URL=http://10.0.2.2:8000 -d emulator-5554 2>&1 | tee integration.log
  return "${PIPESTATUS[0]}"
}

run && exit 0
if grep -qE '^(✅|❌) ' integration.log; then
  echo "--- Tests ran and failed; not retrying."
else
  echo "--- No test ran (tooling didn't start them); retrying once."
  run && exit 0
fi
echo '--- API health'; curl -sS -m 5 localhost:8000/health; echo
echo '--- API log'; tail -n 60 api.log
exit 1
