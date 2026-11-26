#!/usr/bin/env bash
# Runs the integration tests on the emulator.
#
# Retries once, but only when no test reported a failure: on CI emulators the
# Flutter tool sometimes never starts the tests, or loses the app partway
# through, so the run ends without any result for some tests. A test that
# runs and fails (a ❌ line) is never retried.
set -uo pipefail

run() {
  timeout 10m flutter test integration_test \
    --dart-define=API_URL=http://10.0.2.2:8000 -d emulator-5554 2>&1 | tee integration.log
  return "${PIPESTATUS[0]}"
}

diagnose() {
  echo '--- App log'; adb logcat -d -s flutter:V AndroidRuntime:E ActivityManager:I | tail -n 40
  echo '--- API health'; curl -sS -m 5 localhost:8000/health; echo
  echo '--- API log'; tail -n 60 api.log
}

run && exit 0
if grep -qE '^❌ ' integration.log; then
  echo "--- A test failed; not retrying."
else
  echo "--- The run ended without a failing test (the tool lost the app); retrying once."
  diagnose
  run && exit 0
fi
diagnose
exit 1
