import 'package:material_ui/material_ui.dart';

import '../api/models.dart';
import '../logic/format.dart';
import '../logic/selection.dart';

/// Available seats grouped by row. Each seat is a toggle; screen readers hear
/// "Seat R2-5, $30.00" and whether it is selected.
class SeatMap extends StatelessWidget {
  const SeatMap({super.key, required this.seats, required this.selected, required this.onToggle});

  final List<Seat> seats;
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final MapEntry(key: row, value: rowSeats) in groupByRow(seats).entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              'Row ${row.replaceFirst(RegExp('^R'), '')}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final seat in rowSeats)
                Semantics(
                  identifier: 'seat-${seat.label}',
                  label: 'Seat ${seat.label}, ${formatCents(seat.priceCents)}',
                  selected: chosen.contains(seat.id),
                  button: true,
                  excludeSemantics: true,
                  onTap: () => onToggle(seat.id),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: chosen.contains(seat.id) ? scheme.primary : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        key: ValueKey('seat-${seat.label}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onToggle(seat.id),
                        child: Center(
                          child: Text(
                            seat.label.split('-').last,
                            style: TextStyle(
                              color: chosen.contains(seat.id)
                                  ? scheme.onPrimary
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
