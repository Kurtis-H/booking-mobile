import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/date_badge.dart';
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: page.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _EventTile(event: page.items[i]),
                      ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Palette.card,
                  border: Border(top: BorderSide(color: Palette.line)),
                ),
                child: SafeArea(
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
    final textTheme = Theme.of(context).textTheme;
    // The identifier becomes the Android resource-id, so UI tests can find a
    // card without matching its whole merged label.
    return Semantics(
      identifier: 'event-${event.id}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('event-${event.id}'),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => EventScreen(eventId: event.id))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The event's color band, with its date.
              Container(
                width: 78,
                color: Palette.hueFor(event.id),
                alignment: Alignment.center,
                child: DateBadge(when: event.startsAt),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(event.venue, style: const TextStyle(color: Palette.muted)),
                      Text(formatDateTime(event.startsAt), style: textTheme.bodySmall),
                      const SizedBox(height: 8),
                      _Chip(
                        text: soldOut
                            ? 'Sold out'
                            : '${pluralize(event.availableSeats, 'seat')} left',
                        soldOut: soldOut,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.soldOut});
  final String text;
  final bool soldOut;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: soldOut ? Palette.badSoft : Palette.accentSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: soldOut ? Palette.bad : Palette.accent,
          ),
        ),
      );
}
