import 'package:flutter/material.dart';

import '../api/booking_api.dart';
import '../api/models.dart';
import '../logic/errors.dart';
import '../logic/format.dart';
import '../logic/selection.dart';
import '../session.dart';
import '../widgets/seat_map.dart';
import '../widgets/status.dart';
import 'order_screen.dart';
import 'sign_in_screen.dart';

const seatsPerPage = 100;

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.eventId});
  final int eventId;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  EventSummary? _event;
  final List<Seat> _seats = [];
  bool _moreSeats = false;
  Object? _loadError;
  bool _loading = true;
  bool _loadingMore = false;
  bool _buying = false;
  List<int> _selected = [];
  String? _notice;

  BookingApi get _api => SessionScope.of(context).api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final event = await _api.getEvent(widget.eventId);
      final seats = await _api.listSeats(widget.eventId, limit: seatsPerPage, offset: 0);
      if (!mounted) return;
      setState(() {
        _event = event;
        _seats
          ..clear()
          ..addAll(seats);
        _moreSeats = seats.length == seatsPerPage;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final more = await _api.listSeats(widget.eventId, limit: seatsPerPage, offset: _seats.length);
      if (!mounted) return;
      setState(() {
        _seats.addAll(more);
        _moreSeats = more.length == seatsPerPage;
      });
    } catch (e) {
      if (mounted) setState(() => _notice = loadErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _toggle(int seatId) {
    final result = toggleSeat(_selected, seatId);
    setState(() {
      _selected = result.selected;
      _notice = result.error;
    });
  }

  Future<void> _buy() async {
    final session = SessionScope.of(context);
    if (!session.isSignedIn) {
      final ok = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const SignInScreen()));
      if (ok != true || !mounted) return;
    }
    setState(() {
      _buying = true;
      _notice = null;
    });
    try {
      final order = await _api.createOrder(_selected, session.apiKey!);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OrderScreen(orderId: order.id, justBought: true)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _notice = orderErrorMessage(e));
      if (e.statusCode == 409 || e.statusCode == 404) {
        setState(() => _selected = []);
        await _reload();
      } else if (e.statusCode == 401) {
        session.signOut();
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final event = _event;
    return Scaffold(
      appBar: AppBar(title: Text(event?.name ?? 'Event')),
      body: () {
        if (_loading && event == null) return const LoadingView(label: 'Loading event…');
        if (_loadError != null && event == null) return ErrorView(error: _loadError!, onRetry: _reload);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(event!.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('${event.venue} · ${formatDateTime(event.startsAt)}'),
            const SizedBox(height: 4),
            Text('${pluralize(event.availableSeats, 'seat')} available'),
            const SizedBox(height: 16),
            Text('Choose your seats', style: Theme.of(context).textTheme.titleMedium),
            const Text('Up to $maxSeatsPerOrder seats per order.'),
            SeatMap(seats: _seats, selected: _selected, onToggle: _toggle),
            if (_moreSeats)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(_loadingMore ? 'Loading…' : 'Show more seats'),
                ),
              ),
          ],
        );
      }(),
      bottomNavigationBar: event == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_notice != null)
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _notice!,
                            key: const ValueKey('order-notice'),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ),
                    Text(
                      'Total: ${formatCents(totalCents(_seats, _selected))}',
                      key: const ValueKey('order-total'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _selected.isEmpty || _buying ? null : _buy,
                      child: Text(
                        _buying
                            ? 'Placing order…'
                            : _selected.isEmpty
                                ? 'Select seats to buy'
                                : session.isSignedIn
                                    ? 'Buy ${pluralize(_selected.length, 'seat')}'
                                    : 'Sign in to buy ${pluralize(_selected.length, 'seat')}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
