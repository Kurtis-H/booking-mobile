import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

Finder seatButton(String label) => find.byKey(ValueKey('seat-$label'));

void main() {
  group('events list', () {
    testWidgets('shows a page of events and pages through them', (tester) async {
      await pumpApp(tester);
      expect(find.text('Event 1'), findsOneWidget);
      expect(find.text('24 seats left'), findsWidgets);
      expect(find.text('Page 1 of 3'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Event 13'), findsOneWidget);
      expect(find.text('Page 2 of 3'), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 3'), findsOneWidget);
    });

    testWidgets('marks sold-out events', (tester) async {
      final backend = FakeBackend();
      for (final s in backend.seats.where((s) => s['event'] == 1)) {
        s['status'] = 'sold';
      }
      await pumpApp(tester, backend: backend);
      expect(find.text('Sold out'), findsOneWidget);
    });

    testWidgets('explains when it is offline and retries', (tester) async {
      final backend = FakeBackend()..offline = true;
      await pumpApp(tester, backend: backend);
      expect(find.textContaining("You're offline"), findsOneWidget);
      backend.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Event 1'), findsOneWidget);
    });
  });

  group('buying', () {
    testWidgets('adds up the seats you pick', (tester) async {
      await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.tap(seatButton('R2-1'));
      await tester.pump();
      expect(find.text(r'Total: $55.00'), findsOneWidget);
      expect(find.text('Buy 2 seats'), findsOneWidget);
    });

    testWidgets('stops at 10 seats and says why', (tester) async {
      await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      for (var n = 1; n <= 11; n++) {
        await tester.tap(seatButton('R1-$n'));
      }
      await tester.pump();
      expect(find.text('You can buy up to 10 seats in one order.'), findsOneWidget);
      expect(find.text('Buy 10 seats'), findsOneWidget);
    });

    testWidgets('buys seats and shows the confirmation', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(2));
      await tester.tap(seatButton('R1-3'));
      await tester.pump();
      await tester.tap(find.text('Buy 1 seat'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order-confirmation')), findsOneWidget);
      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text(r'$25.00'), findsWidgets);
      expect(app.backend.orders, hasLength(1));
    });

    testWidgets('recovers when someone else takes the seat first', (tester) async {
      final app = await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      app.backend.sellBehindTheScenes(1);

      await tester.tap(find.text('Buy 1 seat'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Someone just took one of those seats'), findsOneWidget);
      expect(seatButton('R1-1'), findsNothing);
      expect(find.text(r'Total: $0.00'), findsOneWidget);
      expect(app.backend.orders, isEmpty);
    });

    testWidgets('keeps the selection when rate limited', (tester) async {
      final backend = FakeBackend()
        ..failNextOrderWith = 429
        ..retryAfter = '3';
      await pumpApp(tester, backend: backend, signedInAs: 'key-user-1', home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      await tester.tap(find.text('Buy 1 seat'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Please wait 3 seconds'), findsOneWidget);
      expect(find.text(r'Total: $25.00'), findsOneWidget);
    });

    testWidgets('signs you in first, then buys', (tester) async {
      final app = await pumpApp(tester, home: eventHome(1));
      await tester.tap(seatButton('R1-1'));
      await tester.pump();
      await tester.tap(find.text('Sign in to buy 1 seat'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use the demo account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-confirmation')), findsOneWidget);
      expect(app.session.apiKey, Session.demoKey);
    });

    testWidgets('loads more seats on request', (tester) async {
      await pumpApp(tester, backend: FakeBackend(events: 1, seatsPerEvent: 130), home: eventHome(1));
      await tester.scrollUntilVisible(find.text('Show more seats'), 300);
      await tester.tap(find.text('Show more seats'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(seatButton('R11-10'), 300);
      expect(seatButton('R11-10'), findsOneWidget);
      expect(find.text('Show more seats'), findsNothing);
    });

    testWidgets("an event that doesn't exist", (tester) async {
      await pumpApp(tester, home: eventHome(999));
      expect(find.text("We couldn't find that."), findsOneWidget);
    });
  });

  group('sign in and orders', () {
    testWidgets('rejects an unknown key and an empty box', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an API key.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('api-key-field')), 'key-nobody');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text("That API key wasn't recognised."), findsOneWidget);
    });

    testWidgets('signs in, lists your orders, opens one, signs out', (tester) async {
      final backend = FakeBackend();
      final api = backend.api();
      await api.createOrder([1], 'key-user-1');
      await api.createOrder([2, 3], 'key-user-1');
      await api.createOrder([4], 'key-user-2');

      await pumpApp(tester, backend: backend);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('api-key-field')), 'key-user-1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('My orders'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-3')), findsNothing); // someone else's

      await tester.tap(find.text('Order #1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order-detail-total')), findsOneWidget);
      expect(find.byKey(const ValueKey('order-confirmation')), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('empty order history', (tester) async {
      await pumpApp(tester, signedInAs: 'key-user-2');
      await tester.tap(find.byTooltip('My orders'));
      await tester.pumpAndSettle();
      expect(find.text("You haven't bought anything yet."), findsOneWidget);
    });
  });

  testWidgets('seats are announced to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, signedInAs: 'key-user-1', home: eventHome(1));
    expect(find.bySemanticsLabel(r'Seat R1-1, $25.00'), findsOneWidget);
    await tester.tap(seatButton('R1-1'));
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel(r'Seat R1-1, $25.00')),
      matchesSemantics(label: r'Seat R1-1, $25.00', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
