import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../logic/selection.dart';
import '../theme.dart';

/// The venue, front to back. Each available seat is a toggle; screen readers
/// hear "Seat R2-5, $30.00" and whether it is selected. Sold seats stay in
/// place, as a darker seat with an X ("Seat R2-6, sold"), so rows keep their shape. They get
/// their own key (sold-seat-…), so seat-… always means a seat you can buy.
///
/// A venue layout is drawn as sections (price tiers), each with its color and
/// price. Rows stay on one line and are centered, so the venue tapers; a wide
/// section scrolls sideways while the row letters stay put. A plain block of
/// seats (one "General" section) wraps instead, with no section heading.
class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.seats,
    this.sold = const [],
    required this.selected,
    required this.onToggle,
  });

  final List<Seat> seats;
  final List<Seat> sold;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (seats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No seats are available for this event.'),
      );
    }
    final chosen = selected.toSet();
    final available = {for (final seat in seats) seat.id};
    final sections = groupBySection([
      ...seats,
      ...sold.where((seat) => !available.contains(seat.id)),
    ]);
    final plain = isPlainBlock(sections);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Stage(),
        const SizedBox(height: 12),
        if (plain)
          _PlainBlock(seats: sections.values.single, chosen: chosen, onToggle: onToggle)
        else
          for (final (i, MapEntry(key: name, value: sectionSeats)) in sections.entries.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _Section(
                name: name,
                seats: sectionSeats,
                tier: Palette.tiers[i % Palette.tiers.length],
                chosen: chosen,
                onToggle: onToggle,
              ),
            ),
      ],
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(999), bottom: Radius.circular(10)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.line, Palette.background],
            ),
          ),
          child: const Text(
            'Stage',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.muted),
          ),
        ),
      );
}

/// A plain block: rows labelled above and wrapped, as before venue layouts.
class _PlainBlock extends StatelessWidget {
  const _PlainBlock({required this.seats, required this.chosen, required this.onToggle});

  final List<Seat> seats;
  final Set<int> chosen;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: row, value: rowSeats) in groupByRow(seats).entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text('Row ${row.replaceFirst(RegExp('^R'), '')}', style: _rowLabelStyle),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final seat in rowSeats)
                  _SeatButton(seat: seat, selected: chosen.contains(seat.id), onToggle: onToggle),
              ],
            ),
          ],
        ],
      );
}

const _rowLabelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Palette.muted);
// Android's minimum tap target; the tests check it (androidTapTargetGuideline).
const _seatSize = 48.0;
const _seatGap = 6.0;

class _Section extends StatelessWidget {
  const _Section({
    required this.name,
    required this.seats,
    required this.tier,
    required this.chosen,
    required this.onToggle,
  });

  final String name;
  final List<Seat> seats;
  final Color tier;
  final Set<int> chosen;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final rows = groupByRow(seats);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$name section',
      child: Container(
        key: ValueKey('section-$name'),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: tier, width: 4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(name, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  Text(
                    sectionPrice(seats),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.muted),
                  ),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row letters stay put while the seats beside them scroll.
                Column(
                  children: [
                    for (final row in rows.keys)
                      SizedBox(
                        width: 22,
                        height: _seatSize + _seatGap,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(row, style: _rowLabelStyle),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Column(
                          children: [
                            for (final rowSeats in rows.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: _seatGap),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final (i, seat) in rowSeats.indexed)
                                      Padding(
                                        padding: EdgeInsets.only(left: i == 0 ? 0 : _seatGap),
                                        child: _SeatButton(
                                          seat: seat,
                                          selected: chosen.contains(seat.id),
                                          onToggle: onToggle,
                                          tier: tier,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatButton extends StatelessWidget {
  const _SeatButton({
    required this.seat,
    required this.selected,
    required this.onToggle,
    this.tier,
  });

  final Seat seat;
  final bool selected;
  final ValueChanged<int> onToggle;

  /// The section's color, shown as a stripe under the seat. None for a plain block.
  final Color? tier;

  @override
  Widget build(BuildContext context) {
    const shape = BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(6),
    );
    final stripe = tier;
    if (seat.status == 'sold') {
      return Semantics(
        identifier: 'sold-seat-${seat.label}',
        label: 'Seat ${seat.label}, sold',
        excludeSemantics: true,
        child: Container(
          key: ValueKey('sold-seat-${seat.label}'),
          width: _seatSize,
          height: _seatSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Palette.sold, borderRadius: shape),
          child: const Icon(Icons.close, size: 20, color: Palette.soldInk),
        ),
      );
    }
    return Semantics(
      identifier: 'seat-${seat.label}',
      label: 'Seat ${seat.label}, ${formatCents(seat.priceCents)}',
      selected: selected,
      button: true,
      excludeSemantics: true,
      onTap: () => onToggle(seat.id),
      child: SizedBox(
        width: _seatSize,
        height: _seatSize,
        child: Material(
          color: selected ? Palette.accent : Palette.seat,
          shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: BorderSide(color: selected ? Palette.accent : Palette.seatLine, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('seat-${seat.label}'),
            onTap: () => onToggle(seat.id),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    seat.number,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: selected ? Colors.white : Palette.ink,
                    ),
                  ),
                ),
                if (stripe != null && !selected)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 3,
                    child: ColoredBox(color: stripe),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
