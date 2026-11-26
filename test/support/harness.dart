import 'package:booking_mobile/app.dart';
import 'package:booking_mobile/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// Pump the whole app against a fake backend, optionally signed in.
Future<({FakeBackend backend, Session session})> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  String? signedInAs,
  Widget? home,
}) async {
  final fake = backend ?? FakeBackend();
  final session = Session(fake.api());
  if (signedInAs != null) await session.signIn(signedInAs);
  await tester.pumpWidget(BookingApp(session: session, home: home));
  await tester.pumpAndSettle();
  return (backend: fake, session: session);
}
