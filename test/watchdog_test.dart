import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/watchdog.dart';

/// A timer the test fires by hand, so no real time passes.
class ManualTimer implements Timer {
  ManualTimer(this.limit, this.onFire);

  final Duration limit;
  final void Function() onFire;
  bool cancelled = false;

  void fire() {
    if (!cancelled) onFire();
  }

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled;

  @override
  int get tick => 0;
}

void main() {
  late List<ManualTimer> timers;
  late List<String> lines;

  Watchdog watchdog({FrameState? frameState}) {
    timers = [];
    lines = [];
    return Watchdog(
      'buys two seats',
      limit: const Duration(seconds: 60),
      frameState: frameState,
      report: lines.add,
      startTimer: (limit, onFire) {
        final timer = ManualTimer(limit, onFire);
        timers.add(timer);
        return timer;
      },
    );
  }

  test('reports the test and the step it is stuck on', () {
    final dog = watchdog();
    dog.mark('tap Buy 2 seats');
    timers.last.fire();
    expect(lines, ['WATCHDOG: "buys two seats" stuck at "tap Buy 2 seats" for 60s']);
    expect(dog.fired, isTrue);
  });

  test('includes the frame scheduler state when it has one', () {
    final dog = watchdog(frameState: () => 'frame scheduled, phase idle');
    dog.mark('settle');
    timers.last.fire();
    expect(lines.single, endsWith('for 60s (frame scheduled, phase idle)'));
  });

  test('each step restarts the clock', () {
    final dog = watchdog();
    dog.mark('one');
    dog.mark('two');
    expect(timers, hasLength(2));
    expect(timers.first.cancelled, isTrue, reason: 'the old step no longer counts');
    timers.first.fire();
    expect(lines, isEmpty);
    timers.last.fire();
    expect(lines.single, contains('"two"'));
  });

  test('reports once, even if fired again', () {
    final dog = watchdog();
    dog.mark('one');
    timers.last.fire();
    dog.mark('two');
    timers.last.fire();
    expect(lines, hasLength(1));
  });

  test('stop cancels the clock', () {
    final dog = watchdog();
    dog.mark('one');
    dog.stop();
    timers.last.fire();
    expect(lines, isEmpty);
    expect(dog.currentStep, 'finished');
  });

  test('step() marks the step and returns the body result', () async {
    final dog = watchdog();
    final value = await dog.step('load', () async => 42);
    expect(value, 42);
    expect(dog.currentStep, 'load');
    expect(timers.single.limit, const Duration(seconds: 60));
  });

  test('the configured limit defaults to 60 seconds', () {
    expect(Watchdog.configuredLimit, const Duration(seconds: 60));
  });
}
