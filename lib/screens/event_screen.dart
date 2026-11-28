import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../api/booking_api.dart';
import '../api/models.dart';
import '../logic/errors.dart';
import '../logic/format.dart';
import '../logic/selection.dart';
import '../session.dart';
import '../theme.dart';
import '../widgets/date_badge.dart';
import '../widgets/seat_map.dart';
import '../widgets/status.dart';
import 'order_screen.dart';
import 'sign_in_screen.dart';

const seatsPerPage = 100;

/// The time, for the hold countdown. Tests move it forward to run a hold out.
@visibleForTesting
DateTime Function() clockNow = DateTime.now;

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.eventId});
  final int eventId;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  EventSummary? _event;
  final List<Seat> _seats = [];

  /// Seats already sold: drawn greyed out in place, so rows keep their shape.
  final List<Seat> _sold = [];

  /// Seats someone holds, possibly you.
  final List<Seat> _held = [];

  /// Your hold on this event, if any, and a ticker for its countdown.
  Hold? _hold;
  Timer? _ticker;
  DateTime _now = clockNow();
  bool _holding = false;

  /// Polite news about the hold ("2 seats held for you for 10 minutes.").
  String? _holdNews;
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
    // Read before any await: the screen may be gone by the time they finish.
    final key = SessionScope.of(context).apiKey;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final event = await _api.getEvent(widget.eventId);
      final seats = await _api.listSeats(widget.eventId, limit: seatsPerPage, offset: 0);
      final sold = await _all('sold');
      final held = await _all('held');
      final hold = key == null ? null : await _api.getHold(widget.eventId, key);
      if (!mounted) return;
      _setHold(hold);
      setState(() {
        _held
          ..clear()
          ..addAll(held);
        if (hold != null) _selected = List.of(hold.seatIds);
        _event = event;
        _seats
          ..clear()
          ..addAll(seats);
        _sold
          ..clear()
          ..addAll(sold);
        _moreSeats = seats.length == seatsPerPage;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Every seat with this status, a page at a time. An event has at most 1,000 seats.
  Future<List<Seat>> _all(String status) async {
    final all = <Seat>[];
    while (true) {
      final page = await _api.listSeats(
        widget.eventId,
        limit: seatsPerPage,
        offset: all.length,
        status: status,
      );
      all.addAll(page);
      if (page.length < seatsPerPage) return all;
    }
  }

  Set<int> get _mine => {...?_hold?.seatIds};

  /// Seats you can pick: the available ones, plus the ones you hold.
  List<Seat> get _pickable => [
        ..._seats,
        for (final seat in _held)
          if (_mine.contains(seat.id)) seat.withStatus('available'),
      ];

  List<Seat> get _heldByOthers => [
        for (final seat in _held)
          if (!_mine.contains(seat.id)) seat,
      ];

  bool get _holdMatchesSelection {
    final hold = _hold;
    return hold != null &&
        hold.seatIds.length == _selected.length &&
        hold.seatIds.every(_selected.contains);
  }

  /// Keep the hold, and tick the countdown once a second while there is one.
  void _setHold(Hold? hold) {
    _hold = hold;
    _ticker?.cancel();
    _ticker = null;
    if (hold == null) return;
    _now = clockNow();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final hold = _hold;
    if (!mounted || hold == null) return;
    setState(() => _now = clockNow());
    if (!_now.isBefore(hold.expiresAt)) {
      setState(() {
        _setHold(null);
        _selected = [];
        _holdNews = null;
        _notice =
            "Your hold ran out, so those seats are back on sale. Pick them again if they're still free.";
      });
      unawaited(_reload());
    }
  }

  Future<void> _placeHold() async {
    final key = SessionScope.of(context).apiKey;
    if (key == null) return;
    setState(() {
      _holding = true;
      _notice = null;
    });
    try {
      final hold = await _api.holdSeats(widget.eventId, _selected, key);
      if (!mounted) return;
      setState(() {
        _holdNews = '${pluralize(hold.seatIds.length, 'seat')} held for you for 10 minutes.';
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _notice = holdErrorMessage(e));
      if (e is ApiException && e.statusCode == 409) await _reload();
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  Future<void> _release() async {
    final key = SessionScope.of(context).apiKey;
    if (key == null) return;
    try {
      await _api.releaseHold(widget.eventId, key);
      if (!mounted) return;
      setState(() {
        _setHold(null);
        _selected = [];
        _holdNews = 'Your seats are released.';
      });
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _notice = holdErrorMessage(e));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
      // The hero names the event, so the bar names the task.
      appBar: AppBar(title: const Text('Choose seats')),
      body: () {
        if (_loading && event == null) return const LoadingView(label: 'Loading event…');
        if (_loadError != null && event == null) {
          return ErrorView(error: _loadError!, onRetry: _reload);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _Hero(event: event!, seats: _pickable),
            const SizedBox(height: 16),
            Card(
              // Keep the heading, the hint and each seat as their own
              // accessibility nodes; a Card merges its text into one by default.
              semanticContainer: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Choose your seats', style: Theme.of(context).textTheme.titleMedium),
                    const Text(
                      'Up to $maxSeatsPerOrder seats per order.',
                      style: TextStyle(color: Palette.muted),
                    ),
                    const SizedBox(height: 12),
                    SeatMap(
                      seats: _pickable,
                      sold: _sold,
                      heldByOthers: _heldByOthers,
                      selected: _selected,
                      onToggle: _toggle,
                    ),
                  ],
                ),
              ),
            ),
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
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: Palette.card,
                border: Border(top: BorderSide(color: Palette.line)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
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
                        'Total: ${formatCents(totalCents(_pickable, _selected))}',
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
                      if (session.isSignedIn && _selected.isNotEmpty && !_holdMatchesSelection)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton(
                            key: const ValueKey('hold-button'),
                            onPressed: _holding ? null : _placeHold,
                            child: Text(
                              _holding
                                  ? 'Holding…'
                                  : _hold == null
                                      ? 'Hold for 10 minutes'
                                      : 'Update hold',
                            ),
                          ),
                        ),
                      if (_hold case final hold?)
                        _HoldBanner(
                          left: hold.expiresAt.difference(_now),
                          onRelease: _release,
                        ),
                      if (_holdNews case final news?)
                        Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              news,
                              key: const ValueKey('hold-news'),
                              style: const TextStyle(color: Palette.muted, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The event in its own color: date, name, venue and what's left.
class _Hero extends StatelessWidget {
  const _Hero({required this.event, required this.seats});
  final EventSummary event;
  final List<Seat> seats;

  @override
  Widget build(BuildContext context) {
    const onHue = TextStyle(color: Colors.white);
    final cheapest =
        seats.isEmpty ? null : seats.map((s) => s.priceCents).reduce((a, b) => a < b ? a : b);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.hueFor(event.id),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateBadge(when: event.startsAt),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('${event.venue} · ${formatDateTime(event.startsAt)}', style: onHue),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  children: [
                    Text(
                      '${pluralize(event.availableSeats, 'seat')} available',
                      style: onHue.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (cheapest != null)
                      Text(
                        'From ${formatCents(cheapest)}',
                        style: onHue.copyWith(fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Held for you · 9:41", with a way to let the seats go. The ticking time
/// isn't a live region, so TalkBack doesn't read it out every second.
class _HoldBanner extends StatelessWidget {
  const _HoldBanner({required this.left, required this.onRelease});
  final Duration left;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('hold-banner'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
        decoration: BoxDecoration(
          color: Palette.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 18, color: Palette.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Held for you · ${formatCountdown(left)}',
                key: const ValueKey('hold-time-left'),
                style: const TextStyle(color: Palette.accent, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: onRelease, child: const Text('Release')),
          ],
        ),
      );
}
