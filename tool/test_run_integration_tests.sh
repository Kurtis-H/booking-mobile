#!/usr/bin/env bash
# Tests run_integration_tests.sh without an emulator. Fake `flutter` and `adb`
# commands act out each way a run can end, and the script must react right.
#
#   ./tool/test_run_integration_tests.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/run_integration_tests.sh"
failures=0

# Makes a work folder whose fake flutter plays one scenario per attempt.
#   pass     prints ✅ lines and exits 0
#   fail     prints a ❌ line and exits 1
#   hang     logs a WATCHDOG line on the device only (flutter batches the
#            device output until the end), then hangs until killed
#   hang-out prints the WATCHDOG line through flutter's output instead
#   silent   hangs with no output until the time limit
#   lost     exits 1 with no ❌ line (the tool lost the app)
setup() {
  WORK=$(mktemp -d)
  mkdir -p "$WORK/bin"
  printf '%s\n' "$@" >"$WORK/scenarios"
  cat >"$WORK/bin/flutter" <<'EOF'
#!/usr/bin/env bash
n=$(( $(cat calls 2>/dev/null || echo 0) + 1 )); echo "$n" > calls
case "$(sed -n "${n}p" scenarios)" in
  pass)   echo "✅ buys two seats against the real API"; echo "🎉 2 tests passed."; exit 0 ;;
  fail)   echo "❌ buys two seats against the real API"; exit 1 ;;
  hang)   echo 'I flutter : WATCHDOG: "buys two seats" stuck at "show the seat map" for 60s (frame scheduled true)' >> device-log
          exec sleep 300 ;;
  hang-out) echo 'WATCHDOG: "buys two seats" stuck at "pick two seats" for 60s'
          exec sleep 300 ;;
  silent) exec sleep 300 ;;
  lost)   echo "🎉 0 tests passed."; exit 1 ;;
esac
EOF
  cat >"$WORK/bin/adb" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> adb-calls
case "$*" in
  "shell pidof dev.kurtish.booking_mobile") echo 4242 ;;
  "exec-out screencap -p") printf 'PNG' ;;
  "logcat -c") : > device-log ;;
  "logcat -d -s flutter:I") cat device-log 2>/dev/null ;;
  "logcat -d") echo "--- thread dump for 4242"; cat device-log 2>/dev/null ;;
  *) echo "fake adb output" ;;
esac
EOF
  chmod +x "$WORK/bin/flutter" "$WORK/bin/adb"
}

# The time limit is 20s, so "stopped quickly" can only pass if the watchdog
# line stopped the run. A silent hang has no line, so its test uses 3s.
run_script() {
  local start=$SECONDS
  (cd "$WORK" && PATH="$WORK/bin:$PATH" RUN_LIMIT=${LIMIT:-20s} POLL_SECONDS=0.2 "$SCRIPT" >output.txt 2>&1)
  CODE=$?
  TOOK=$((SECONDS - start))
  ATTEMPTS=$(cat "$WORK/calls")
}

check() {
  local name=$1 condition=$2
  if eval "$condition"; then
    echo "ok    $name"
  else
    echo "FAIL  $name  ($condition)"
    sed 's/^/      | /' "$WORK/output.txt"
    failures=$((failures + 1))
  fi
}

setup pass
run_script
check "a passing run exits 0 after one attempt" '[ $CODE -eq 0 ] && [ $ATTEMPTS -eq 1 ]'
check "a passing run captures no diagnostics" '[ ! -d $WORK/diagnostics ]'

setup fail pass
run_script
check "a failing test exits 1 and is never retried" '[ $CODE -eq 1 ] && [ $ATTEMPTS -eq 1 ]'
check "a failing test is reported as such" 'grep -q "A test failed; not retrying" $WORK/output.txt'

setup hang pass
run_script
check "a watchdog report stops the hung run and retries" '[ $CODE -eq 0 ] && [ $ATTEMPTS -eq 2 ]'
check "the hung run is stopped quickly, not at the time limit" '[ $TOOK -lt 5 ]'
check "diagnostics are captured while it is hung" \
  '[ -s $WORK/diagnostics/attempt-1/screen.png ] && [ -s $WORK/diagnostics/attempt-1/gfxinfo.txt ]'
check "the watchdog line is saved with them" \
  'grep -q "stuck at \"show the seat map\"" $WORK/diagnostics/attempt-1/watchdog.txt'
check "a thread dump is requested from the app" 'grep -qx "shell kill -3 4242" $WORK/adb-calls'
check "the logcat with the dump is saved" 'grep -q "thread dump for 4242" $WORK/diagnostics/attempt-1/logcat.txt'
check "logcat is cleared before each attempt, so attempt 1's line can't fail attempt 2" \
  '[ "$(grep -cx "logcat -c" $WORK/adb-calls)" -eq 2 ]'
check "the job log gets a summary with the stuck step" \
  'grep -q "Diagnostics summary" $WORK/output.txt && grep -q "stuck at \"show the seat map\"" $WORK/output.txt'

setup hang-out pass
run_script
check "a watchdog line in flutter's own output works too" '[ $CODE -eq 0 ] && [ $ATTEMPTS -eq 2 ] && [ $TOOK -lt 5 ]'

setup hang hang
run_script
check "stuck twice exits 1" '[ $CODE -eq 1 ] && [ $ATTEMPTS -eq 2 ]'
check "both attempts keep their diagnostics" \
  '[ -d $WORK/diagnostics/attempt-1 ] && [ -d $WORK/diagnostics/attempt-2 ]'

setup silent pass
LIMIT=3s run_script
check "a silent hang is caught by the time limit and retried" '[ $CODE -eq 0 ] && [ $ATTEMPTS -eq 2 ]'
check "a silent hang still gets diagnostics" '[ -s $WORK/diagnostics/attempt-1/logcat.txt ]'

setup lost pass
run_script
check "a run that loses the app is retried" '[ $CODE -eq 0 ] && [ $ATTEMPTS -eq 2 ]'

setup hang fail
run_script
check "a real failure on the retry still fails" '[ $CODE -eq 1 ] && [ $ATTEMPTS -eq 2 ]'

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
