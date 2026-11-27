// Reports a stuck integration test while it is still stuck.
//
// On the CI emulator a test once hung for 9 minutes with no output until the
// job's timeout killed it, and by then the evidence was gone (issue #14).
// Every wait in the tests has its own deadline, but in a live test
// `tester.pump()` waits for a real frame: if the emulator never draws one,
// that await never returns and the deadline is never checked. A timer still
// fires, though, because the event loop is idle rather than blocked.
//
// So each test marks the step it is on, and if one step takes longer than
// [limit], the watchdog prints one line starting with "WATCHDOG:". The run
// script watches for that line, captures diagnostics from the emulator while
// it is still hung, then stops the run.
import 'dart:async';

typedef StartTimer = Timer Function(Duration limit, void Function() onFire);

/// What the frame scheduler is doing when the watchdog fires. A frame that
/// stays scheduled but never arrives points at rendering, not the app.
typedef FrameState = String Function();

class Watchdog {
  Watchdog(
    this.testName, {
    this.limit = const Duration(seconds: 60),
    this.frameState,
    void Function(String line)? report,
    StartTimer? startTimer,
  })  : _report = report ?? _toLogcat,
        _startTimer = startTimer ?? Timer.new;

  /// Read from --dart-define=WATCHDOG_SECONDS, so CI can tune it per run.
  static const configuredLimit = Duration(
    seconds: int.fromEnvironment('WATCHDOG_SECONDS', defaultValue: 60),
  );

  final String testName;
  final Duration limit;
  final FrameState? frameState;
  final void Function(String line) _report;
  final StartTimer _startTimer;

  Timer? _timer;
  String _step = 'not started';
  bool _fired = false;

  String get currentStep => _step;
  bool get fired => _fired;

  /// Starts the clock for a new step. Each step gets the full [limit].
  void mark(String step) {
    _step = step;
    _timer?.cancel();
    _timer = _startTimer(limit, _fire);
  }

  /// Runs [body] as one named step.
  Future<T> step<T>(String name, Future<T> Function() body) {
    mark(name);
    return body();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _step = 'finished';
  }

  /// testWidgets captures print() inside the test's zone and sends it to the
  /// host only when the run ends, which a hung run never does. The root
  /// zone's print goes straight to logcat, where the run script sees it live.
  static void _toLogcat(String line) => Zone.root.print(line);

  void _fire() {
    if (_fired) return; // one report per test is enough to act on
    _fired = true;
    final frames = frameState == null ? '' : ' (${frameState!()})';
    _report('WATCHDOG: "$testName" stuck at "$_step" for ${limit.inSeconds}s$frames');
  }
}
