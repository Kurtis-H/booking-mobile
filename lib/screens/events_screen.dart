import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
import '../widgets/status.dart';
import 'event_screen.dart';
import 'orders_screen.dart';
import 'sign_in_screen.dart';

const eventsPerPage = 12;

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int _page = 1;
  Future<EventPage>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<EventPage> _load() => SessionScope.of(context)
      .api
      .listEvents(limit: eventsPerPage, offset: (_page - 1) * eventsPerPage);

  void _goTo(int page) => setState(() {
        _page = page;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming events'),
        actions: [
          if (session.isSignedIn) ...[
            IconButton(
              tooltip: 'My orders',
              icon: const Icon(Icons.receipt_long),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const OrdersScreen())),
            ),
            TextButton(onPressed: session.signOut, child: const Text('Sign out')),
          ] else
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<bool>(builder: (_) => const SignInScreen())),
              child: const Text('Sign in'),
            ),
        ],
      ),
      body: FutureBuilder<EventPage>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => _goTo(_page));
          if (!snap.hasData) return const LoadingView(label: 'Loading events…');
          final page = snap.data!;
          final pages = (page.total / eventsPerPage).ceil().clamp(1, 1 << 30);
          return Column(
            children: [
              Expanded(
                child: page.items.isEmpty
                    ? const Center(child: Text('No events on this page.'))
                    : ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _EventTile(event: page.items[i]),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _page > 1 ? () => _goTo(_page - 1) : null,
                        child: const Text('Previous'),
                      ),
                      Semantics(liveRegion: true, child: Text('Page $_page of $pages')),
                      OutlinedButton(
                        onPressed: _page < pages ? () => _goTo(_page + 1) : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final soldOut = event.availableSeats == 0;
    return ListTile(
      key: ValueKey('event-${event.id}'),
      title: Text(event.name),
      subtitle: Text('${event.venue}\n${formatDateTime(event.startsAt)}'),
      isThreeLine: true,
      trailing: Text(
        soldOut ? 'Sold out' : '${pluralize(event.availableSeats, 'seat')} left',
        style: soldOut ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
      ),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => EventScreen(eventId: event.id))),
    );
  }
}
