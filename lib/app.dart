import 'package:material_ui/material_ui.dart';

import 'screens/event_screen.dart';
import 'screens/events_screen.dart';
import 'session.dart';
import 'theme.dart';

class BookingApp extends StatelessWidget {
  const BookingApp({super.key, required this.session, this.home});

  final Session session;

  /// Lets tests open the app on a specific screen.
  final Widget? home;

  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: MaterialApp(
          title: 'Booking',
          debugShowCheckedModeBanner: false,
          theme: bookingTheme(),
          home: home ?? const EventsScreen(),
        ),
      );
}

/// Convenience for tests and deep links.
Widget eventHome(int eventId) => EventScreen(eventId: eventId);
