import '../api/models.dart';
import 'format.dart';
import 'planted_bug.dart';

/// The API accepts at most 10 seats per order.
const maxSeatsPerOrder = 10;

class ToggleResult {
  const ToggleResult(this.selected, [this.error]);

  final List<int> selected;
  final String? error;
}

/// Select or unselect a seat. Never changes [selected]; returns a new list.
ToggleResult toggleSeat(List<int> selected, int seatId) {
  if (selected.contains(seatId)) {
    return ToggleResult(selected.where((id) => id != seatId).toList());
  }
  if (selected.length >= maxSeatsPerOrder) {
    return ToggleResult(
      List.of(selected),
      'You can buy up to $maxSeatsPerOrder seats in one order.',
    );
  }
  return ToggleResult([...selected, seatId]);
}

/// Sum the prices of the selected seats. Unknown ids are ignored.
///
/// [bug] is only for tests of the planted-bug switch; see planted_bug.dart.
int totalCents(List<Seat> seats, List<int> selected, {String bug = plantedBug}) {
  final wanted = selected.toSet();
  if (bug == 'total') {
    // Planted on purpose for test-sensitivity runs.
    for (final s in seats) {
      if (wanted.contains(s.id)) return s.priceCents;
    }
    return 0;
  }
  return seats.where((s) => wanted.contains(s.id)).fold(0, (sum, s) => sum + s.priceCents);
}

/// "R3-12" -> row "R3". Rows keep the order they first appear in.
Map<String, List<Seat>> groupByRow(List<Seat> seats) {
  final rows = <String, List<Seat>>{};
  for (final seat in seats) {
    rows.putIfAbsent(seat.rowName, () => []).add(seat);
  }
  return rows;
}

/// Seats by section (price tier), front to back. Seat ids follow seating
/// order, so sorting by id puts sections, rows and seats in venue order.
Map<String, List<Seat>> groupBySection(List<Seat> seats) {
  final sections = <String, List<Seat>>{};
  for (final seat in [...seats]..sort((a, b) => a.id.compareTo(b.id))) {
    sections.putIfAbsent(seat.section, () => []).add(seat);
  }
  return sections;
}

/// True for an event that is one plain block of seats, with no venue layout.
bool isPlainBlock(Map<String, List<Seat>> sections) =>
    sections.length == 1 && sections.containsKey('General');

/// "\$90.00", or "From \$25.00" when a section's rows are priced differently.
String sectionPrice(List<Seat> seats) {
  final prices = seats.map((s) => s.priceCents);
  final low = prices.reduce((a, b) => a < b ? a : b);
  final high = prices.reduce((a, b) => a > b ? a : b);
  return low == high ? formatCents(low) : 'From ${formatCents(low)}';
}
