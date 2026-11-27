#!/usr/bin/env bash
# Runs the integration tests on the emulator, and deals with a stuck run.
#
# A run can end three ways:
#   passed    every test passed: exit 0.
#   failed    a test reported a failure (a ❌ line): never retried, exit 1.
#   stuck     the app stopped responding (issue #14). Either a test's
#             watchdog printed a "WATCHDOG:" line, or the run ended with no
#             failure and no pass, or hit the time limit. Diagnostics are
#             captured into diagnostics/attempt-N while the emulator is
#             still in that state, then the run is retried once.
#
# Settings (the defaults suit CI; the self-test shortens them):
#   RUN_LIMIT         time limit for one attempt (default 6m)
#   WATCHDOG_SECONDS  how long one test step may take (default 60)
#   POLL_SECONDS      how often to check for the watchdog line (default 2)
set -uo pipefail

RUN_LIMIT=${RUN_LIMIT:-6m}
WATCHDOG_SECONDS=${WATCHDOG_SECONDS:-60}
POLL_SECONDS=${POLL_SECONDS:-2}
APP_ID=dev.kurtish.booking_mobile
DIAGNOSTICS=diagnostics

# Runs one attempt. Prints the outcome (passed, failed or stuck) on the last line.
attempt() {
  local log=$1
  : >"$log"
  timeout "$RUN_LIMIT" flutter test integration_test \
    --dart-define=API_URL=http://10.0.2.2:8000 \
    --dart-define=WATCHDOG_SECONDS="$WATCHDOG_SECONDS" \
    -d emulator-5554 >"$log" 2>&1 &
  local runner=$!
  tail -n +1 -f "$log" --pid="$runner" >&2 &
  local tailer=$!

  local watchdog=no
  while kill -0 "$runner" 2>/dev/null; do
    if grep -q 'WATCHDOG:' "$log"; then
      watchdog=yes
      break
    fi
    sleep "$POLL_SECONDS"
  done

  if [ "$watchdog" = yes ]; then
    capture "$log"
    kill "$runner" 2>/dev/null
  fi
  wait "$runner"
  local code=$?
  wait "$tailer" 2>/dev/null

  if [ "$code" -eq 0 ] && [ "$watchdog" = no ]; then
    echo passed
  elif grep -qE '^❌ ' "$log"; then
    echo failed
  else
    [ "$watchdog" = no ] && capture "$log"
    echo stuck
  fi
}

# Saves what the emulator looks like right now. Every command may fail on a
# broken emulator, so none of them can stop the script.
capture() {
  local log=$1 dir
  dir="$DIAGNOSTICS/attempt-$ATTEMPT"
  mkdir -p "$dir"
  echo "--- Capturing diagnostics into $dir" >&2
  grep 'WATCHDOG:' "$log" >"$dir/watchdog.txt" 2>/dev/null
  timeout 20 adb exec-out screencap -p >"$dir/screen.png" 2>/dev/null
  timeout 20 adb shell dumpsys activity top >"$dir/activity-top.txt" 2>&1
  timeout 20 adb shell dumpsys gfxinfo "$APP_ID" >"$dir/gfxinfo.txt" 2>&1
  timeout 20 adb shell cat /proc/meminfo >"$dir/emulator-meminfo.txt" 2>&1
  timeout 20 adb shell top -b -n 1 -m 15 >"$dir/emulator-top.txt" 2>&1
  local pid
  pid=$(timeout 10 adb shell pidof "$APP_ID" 2>/dev/null | tr -d '\r')
  if [ -n "$pid" ]; then
    # Asks the app's runtime to write every thread's stack into logcat.
    timeout 10 adb shell kill -3 "$pid" 2>/dev/null
    sleep 2
  fi
  echo "app pid: ${pid:-not running}" >"$dir/app-pid.txt"
  timeout 30 adb logcat -d >"$dir/logcat.txt" 2>&1
  free -m >"$dir/host-memory.txt" 2>&1
  [ -f api.log ] && tail -n 60 api.log >"$dir/api-log-tail.txt"
  grep 'WATCHDOG:' "$dir/watchdog.txt" >&2 || echo "(no watchdog line: the run ended or timed out)" >&2
}

for ATTEMPT in 1 2; do
  outcome=$(attempt "integration-$ATTEMPT.log" | tail -n 1)
  echo "--- Attempt $ATTEMPT: $outcome" >&2
  case "$outcome" in
    passed) exit 0 ;;
    failed)
      echo "--- A test failed; not retrying." >&2
      exit 1
      ;;
    stuck)
      # The ✅ list of an interrupted run includes tests that started but never
      # finished; only the "N tests passed" line counts.
      echo "--- The app got stuck (issue #14); diagnostics are in $DIAGNOSTICS/attempt-$ATTEMPT." >&2
      ;;
  esac
done
echo "--- Stuck on both attempts." >&2
exit 1
