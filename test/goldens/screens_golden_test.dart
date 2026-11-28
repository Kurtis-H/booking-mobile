import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/screens/orders_screen.dart';
import 'package:booking_mobile/screens/sign_in_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// Every key screen on a phone-sized view (412x915 at 2x), compared with an
/// approved screenshot. The data is fixed (FakeBackend.showcase), so only a
/// change to the app can change a screenshot.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 2, 915 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> shot(String name) =>
    expectLater(find.byType(MaterialApp), matchesGoldenFile('images/$name.png'));

void main() {
  testWidgets('event list', (tester) async {
    phone(tester);
    await pumpApp(tester, backend: FakeBackend.showcase());
    await shot('event_list');
  });

  testWidgets('seat map with seats selected', (tester) async {
    phone(tester);
    await pumpApp(tester, backend: FakeBackend.showcase(), signedInAs: 'key-user-1', home: eventHome(1));
    for (final seat in ['B-3', 'B-4', 'B-5']) {
      await tester.tap(find.byKey(ValueKey('seat-$seat')));
    }
    await tester.pumpAndSettle();
    await shot('seat_map');
  });

  testWidgets('seat taken by someone else first', (tester) async {
    phone(tester);
    final backend = FakeBackend.showcase();
    final app = await pumpApp(tester, backend: backend, signedInAs: 'key-user-1', home: eventHome(1));
    await tester.tap(find.byKey(const ValueKey('seat-A-1')));
    await tester.pump();
    app.backend.sellBehindTheScenes(1);
    await tester.tap(find.text('Buy 1 seat'));
    await tester.pumpAndSettle();
    await shot('seat_taken');
  });

  testWidgets('sold-out event', (tester) async {
    phone(tester);
    await pumpApp(tester, backend: FakeBackend.showcase(), home: eventHome(4));
    await shot('sold_out');
  });

  testWidgets('order confirmation', (tester) async {
    phone(tester);
    await pumpApp(tester, backend: FakeBackend.showcase(), signedInAs: 'key-user-1', home: eventHome(1));
    for (final seat in ['B-3', 'B-4']) {
      await tester.tap(find.byKey(ValueKey('seat-$seat')));
    }
    await tester.pump();
    await tester.tap(find.text('Buy 2 seats'));
    await tester.pumpAndSettle();
    await shot('order_confirmation');
  });

  testWidgets('my orders', (tester) async {
    phone(tester);
    final backend = FakeBackend.showcase();
    final app = await pumpApp(tester, backend: backend, signedInAs: 'key-user-1', home: eventHome(1));
    await tester.tap(find.byKey(const ValueKey('seat-C-3')));
    await tester.pump();
    await tester.tap(find.text('Buy 1 seat'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(BookingApp(session: app.session, home: const OrdersScreen()));
    await tester.pumpAndSettle();
    await shot('my_orders');
  });

  testWidgets('sign in', (tester) async {
    phone(tester);
    await pumpApp(tester, backend: FakeBackend.showcase(), home: const SignInScreen());
    await shot('sign_in');
  });
}
