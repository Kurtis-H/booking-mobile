// Runs on an Android emulator against the real booking API
// (api-performance-lab). The emulator reaches the host at 10.0.2.2.
import 'dart:async';
import 'dart:convert';

import 'package:booking_mobile/api/booking_api.dart';
import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/session.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'support/watchdog.dart';

final base = BookingApi.defaultBaseUrl;

/// Every direct call to the API gets a deadline, so a stuck server fails the
/// test with a message instead of hanging the emulator job.
const apiDeadline = Duration(seconds: 20);

Future<T> withDeadline<T>(String what, Future<T> call) {
  return call.timeout(apiDeadline, onTimeout: () => throw TimeoutException(what, apiDeadline));
}

/// pumpAndSettle waits up to 10 minutes by default; nothing here should take
/// more than a few seconds.
Future<void> settle(WidgetTester tester) {
  const step = Duration(milliseconds: 100);
  return tester.pumpAndSettle(step, EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
}

/// pumpAndSettle stops when no frames are pending, which can happen while the
/// app is still waiting on the network. Keep pumping until [finder] matches
/// what we expect, or fail after [limit] with a clear message.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder,
  Matcher matcher, {
  Duration limit = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(limit);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (matcher.matches(finder, {})) return;
  }
  expect(finder, matcher, reason: 'still not true after ${limit.inSeconds}s');
}

/// If the emulator stops drawing frames, a frame stays scheduled but never
/// arrives. That points at rendering rather than at the app or the network.
String frameState() {
  final binding = SchedulerBinding.instance;
  return 'scheduler phase ${binding.schedulerPhase.name}, '
      'frame scheduled ${binding.hasScheduledFrame}, '
      'transient callbacks ${binding.transientCallbackCount}';
}

/// testWidgets with a watchdog that reports the step a stuck test is on.
void watchedTest(String name, Future<void> Function(WidgetTester tester, Watchdog dog) body) {
  testWidgets(name, (tester) async {
    final dog = Watchdog(name, limit: Watchdog.configuredLimit, frameState: frameState);
    try {
      await body(tester, dog);
    } finally {
      dog.stop();
    }
  });
}

Map<String, String> headers(String key) {
  return {'X-API-Key': key, 'Content-Type': 'application/json'};
}

/// Each test gets its own event, so tests never compete for seats.
Future<({int id, List<int> seatIds})> newEvent(int seats) async {
  final body = jsonEncode({
    'name': 'Emulator test',
    'venue': 'Android Hall',
    'starts_at': '2027-06-01T19:00:00Z',
    'seats': seats,
    'price_cents': 3500,
  });
  final createUrl = Uri.parse('$base/admin/events');
  final created = await withDeadline(
    'POST /admin/events',
    http.post(createUrl, headers: headers('key-admin'), body: body),
  );
  expect(created.statusCode, 201, reason: created.body);
  final id = (jsonDecode(created.body) as Map<String, dynamic>)['id'] as int;

  final seatsUrl = Uri.parse('$base/events/$id/seats?limit=100');
  final listed = await withDeadline('GET /events/$id/seats', http.get(seatsUrl));
  final page = jsonDecode(listed.body) as Map<String, dynamic>;
  final ids = [
    for (final s in page['items'] as List<dynamic>) (s as Map<String, dynamic>)['id'] as int,
  ];
  return (id: id, seatIds: ids);
}

Future<Session> signedIn(String key) async {
  final session = Session(BookingApi(baseUrl: base));
  await withDeadline('sign in', session.signIn(key));
  return session;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  watchedTest('buys two seats against the real API', (tester, dog) async {
    final event = await dog.step('create the event', () => newEvent(4));
    final session = await dog.step('sign in', () => signedIn('key-user-30'));
    await dog.step('show the seat map', () async {
      await tester.pumpWidget(BookingApp(session: session, home: eventHome(event.id)));
      await settle(tester);
    });

    await dog.step('pick two seats', () async {
      await tester.tap(find.byKey(const ValueKey('seat-S-1')));
      await tester.tap(find.byKey(const ValueKey('seat-S-2')));
      await tester.pump();
    });
    expect(find.text(r'Total: $70.00'), findsOneWidget);

    await dog.step('buy and wait for the confirmation', () async {
      await tester.tap(find.text('Buy 2 seats'));
      await pumpUntil(tester, find.byKey(const ValueKey('order-confirmation')), findsOneWidget);
    });
    expect(find.text(r'$70.00'), findsWidgets);
  });

  watchedTest('loses a seat to another buyer and recovers', (tester, dog) async {
    final event = await dog.step('create the event', () => newEvent(2));
    final session = await dog.step('sign in', () => signedIn('key-user-31'));
    await dog.step('show the seat map', () async {
      await tester.pumpWidget(BookingApp(session: session, home: eventHome(event.id)));
      await settle(tester);
    });
    await dog.step('pick a seat', () async {
      await tester.tap(find.byKey(const ValueKey('seat-S-1')));
      await tester.pump();
    });

    final orderBody = jsonEncode({
      'seat_ids': [event.seatIds.first]
    });
    final ordersUrl = Uri.parse('$base/orders');
    final rival = await dog.step(
      'rival buys the seat',
      () => withDeadline(
        'rival POST /orders',
        http.post(ordersUrl, headers: headers('key-user-32'), body: orderBody),
      ),
    );
    expect(rival.statusCode, 201, reason: rival.body);

    await dog.step('buy and wait for the conflict message', () async {
      await tester.tap(find.text('Buy 1 seat'));
      final message = find.textContaining('Someone just took one of those seats');
      await pumpUntil(tester, message, findsOneWidget);
    });
    // The app reloads the seat map; the taken seat must disappear.
    await dog.step('wait for the seat map to reload', () async {
      await pumpUntil(tester, find.byKey(const ValueKey('seat-S-1')), findsNothing);
    });
  });
}
