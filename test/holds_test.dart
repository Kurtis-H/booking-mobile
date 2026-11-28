import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/screens/event_screen.dart' show clockNow;
import 'package:booking_mobile/logic/errors.dart';
import 'package:booking_mobile/logic/format.dart';
import 'package:booking_mobile/api/booking_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Finder seatButton(String label) => find.byKey(ValueKey('seat-$label'));

/// While a hold is active its countdown ticks every second, so the screen never
/// "settles": pump a little instead of pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('seat holds', () {
    testWidgets('holds the selected seats, counts down, and keeps them selected', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.tap(seatButton('R1-2'));
      await tester.pump();
      await tester.tap(find.text('Hold for 10 minutes'));
      await settle(tester);

      expect(find.textContaining(RegExp(r'^Held for you · (10:00|9:5\d)$')), findsOneWidget);
      expect(find.text('2 seats held for you for 10 minutes.'), findsOneWidget);
      expect(app.backend.holds.keys.toList()..sort(), [1, 2]);
      // The hold matches the selection: nothing more to hold, and Buy is unchanged.
      expect(find.text('Hold for 10 minutes'), findsNothing);
      expect(find.text('Buy 2 seats'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(RegExp(r'^Held for you · 9:5\d$')), findsOneWidget);
    });

    testWidgets('offers to update the hold when the selection changes', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      await tester.tap(find.text('Hold for 10 minutes'));
      await settle(tester);
      await tester.tap(seatButton('R1-3'));
      await tester.pump();
      await tester.tap(find.text('Update hold'));
      await settle(tester);
      expect(app.backend.holds.keys.toList()..sort(), [1, 3]);
    });

    testWidgets('picks up an existing hold when the screen opens', (tester) async {
      final backend = FakeBackend()..holdBehindTheScenes(4, owner: 'key-user-1');
      final session = (await pumpApp(tester, backend: backend, signedInAs: 'key-user-1')).session;
      await tester.pumpWidget(BookingApp(session: session, home: eventHome(1)));
      await settle(tester);
      expect(find.byKey(const ValueKey('hold-banner')), findsOneWidget);
      expect(find.text('Buy 1 seat'), findsOneWidget);
    });

    testWidgets("shows seats someone else holds in place, and they can't be picked",
        (tester) async {
      final backend = FakeBackend()..holdBehindTheScenes(2);
      await pumpApp(tester, backend: backend, signedInAs: 'key-user-1', home: eventHome(1));
      final held = find.byKey(const ValueKey('held-seat-R1-2'));
      expect(held, findsOneWidget);
      expect(find.bySemanticsLabel('Seat R1-2, held by someone else'), findsOneWidget);
      expect(seatButton('R1-2'), findsNothing);
      await tester.tap(held);
      await tester.pump();
      expect(find.text(r'Total: $0.00'), findsOneWidget);
    });

    testWidgets('explains when someone else holds a seat first', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      app.backend.holdBehindTheScenes(1);
      await tester.tap(find.text('Buy 1 seat'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Someone is holding one of those seats right now.'), findsOneWidget);
    });

    testWidgets('releases the hold', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      await tester.tap(find.text('Hold for 10 minutes'));
      await settle(tester);
      await tester.tap(find.text('Release'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
      expect(app.backend.holds, isEmpty);
      expect(find.text('Your seats are released.'), findsOneWidget);
      expect(find.text(r'Total: $0.00'), findsOneWidget);
    });

    testWidgets('says so when the hold runs out', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      await tester.tap(find.text('Hold for 10 minutes'));
      await settle(tester);
      expect(find.byKey(const ValueKey('hold-banner')), findsOneWidget);

      // Eleven minutes later: the server has let the hold go, and the
      // countdown's next tick sees the time is up.
      app.backend.expireHolds();
      clockNow = () => DateTime.now().add(const Duration(minutes: 11));
      addTearDown(() => clockNow = DateTime.now);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      expect(find.byKey(const ValueKey('hold-banner')), findsNothing);
      expect(find.textContaining('Your hold ran out, so those seats are back on sale.'),
          findsOneWidget);
      expect(find.text(r'Total: $0.00'), findsOneWidget);
    });

    testWidgets('has no hold button when signed out', (tester) async {
      await pumpApp(tester, home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      expect(find.text('Hold for 10 minutes'), findsNothing);
    });
  });

  group('messages', () {
    test('tell a held seat apart from a sold one, and explain the buyer limit', () {
      const held = ApiException(409, 'One or more seats are held by another buyer');
      const limit = ApiException(409, 'You can hold at most 10 seats for one event');
      expect(orderErrorMessage(held), contains('Someone is holding one of those seats'));
      expect(holdErrorMessage(held), contains('Someone is holding one of those seats'));
      expect(orderErrorMessage(limit), startsWith('You can have at most 10 seats for one event'));
      expect(orderErrorMessage(const ApiException(409, 'x')), startsWith('Someone just took'));
      expect(holdErrorMessage(const ApiException(500, 'x')),
          "We couldn't hold those seats. Please try again.");
    });

    test('count down as minutes and seconds', () {
      expect(formatCountdown(const Duration(seconds: 581)), '9:41');
      expect(formatCountdown(const Duration(minutes: 10)), '10:00');
      expect(formatCountdown(const Duration(milliseconds: 400)), '0:01');
      expect(formatCountdown(const Duration(seconds: -5)), '0:00');
    });
  });
}
