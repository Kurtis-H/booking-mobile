import '../api/models.dart';

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
int totalCents(List<Seat> seats, List<int> selected) {
  final wanted = selected.toSet();
  return seats.where((s) => wanted.contains(s.id)).fold(0, (sum, s) => sum + s.priceCents);
}

/// "R3-12" -> row "R3". Rows keep the order they first appear in.
Map<String, List<Seat>> groupByRow(List<Seat> seats) {
  final rows = <String, List<Seat>>{};
  for (final seat in seats) {
    rows.putIfAbsent(seat.label.split('-').first, () => []).add(seat);
  }
  return rows;
}
