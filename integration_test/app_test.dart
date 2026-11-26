// Runs on an Android emulator against the real booking API
// (api-performance-lab). The emulator reaches the host at 10.0.2.2.
import 'dart:convert';

import 'package:booking_mobile/api/booking_api.dart';
import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

final base = BookingApi.defaultBaseUrl;

/// Each test gets its own event, so tests never compete for seats.
Future<({int id, List<int> seatIds})> newEvent(int seats) async {
  final created = await http.post(
    Uri.parse('$base/admin/events'),
    headers: {'X-API-Key': 'key-admin', 'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': 'Emulator test',
      'venue': 'Android Hall',
      'starts_at': '2027-06-01T19:00:00Z',
      'seats': seats,
      'price_cents': 3500,
    }),
  );
  expect(created.statusCode, 201, reason: created.body);
  final id = (jsonDecode(created.body) as Map<String, dynamic>)['id'] as int;
  final page = jsonDecode((await http.get(Uri.parse('$base/events/$id/seats?limit=100'))).body) as Map<String, dynamic>;
  final ids = [for (final s in page['items'] as List<dynamic>) (s as Map<String, dynamic>)['id'] as int];
  return (id: id, seatIds: ids);
}

Future<Session> signedIn(String key) async {
  final session = Session(BookingApi(baseUrl: base));
  await session.signIn(key);
  return session;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('buys two seats against the real API', (tester) async {
    final event = await newEvent(4);
    await tester.pumpWidget(BookingApp(session: await signedIn('key-user-30'), home: eventHome(event.id)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('seat-S-1')));
    await tester.tap(find.byKey(const ValueKey('seat-S-2')));
    await tester.pump();
    expect(find.text(r'Total: $70.00'), findsOneWidget);

    await tester.tap(find.text('Buy 2 seats'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    expect(find.byKey(const ValueKey('order-confirmation')), findsOneWidget);
    expect(find.text(r'$70.00'), findsWidgets);
  });

  testWidgets('loses a seat to another buyer and recovers', (tester) async {
    final event = await newEvent(2);
    await tester.pumpWidget(BookingApp(session: await signedIn('key-user-31'), home: eventHome(event.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seat-S-1')));
    await tester.pump();

    final rival = await http.post(
      Uri.parse('$base/orders'),
      headers: {'X-API-Key': 'key-user-32', 'Content-Type': 'application/json'},
      body: jsonEncode({'seat_ids': [event.seatIds.first]}),
    );
    expect(rival.statusCode, 201);

    await tester.tap(find.text('Buy 1 seat'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
    expect(find.textContaining('Someone just took one of those seats'), findsOneWidget);
    expect(find.byKey(const ValueKey('seat-S-1')), findsNothing);
  });
}
