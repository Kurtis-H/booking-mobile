import 'package:booking_mobile/api/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order items carry the seat label', () {
    final item = OrderItem.fromJson({'seat_id': 42, 'label': 'R3-12', 'price_cents': 2500});
    expect(item.label, 'R3-12');
  });

  test('falls back to the seat id when an older API sends no label', () {
    final item = OrderItem.fromJson({'seat_id': 42, 'price_cents': 2500});
    expect(item.label, '#42');
  });

  test('seats carry their section, row and number', () {
    final seat = Seat.fromJson({
      'id': 7,
      'label': 'E-7',
      'price_cents': 6500,
      'status': 'available',
      'section': 'Mezzanine',
      'row': 'E',
      'number': 7,
    });
    expect((seat.section, seat.rowName, seat.number), ('Mezzanine', 'E', '7'));
  });

  test('a seat from an API without venue layouts reads its row and number from the label', () {
    final seat =
        Seat.fromJson({'id': 7, 'label': 'R3-12', 'price_cents': 2500, 'status': 'available'});
    expect((seat.section, seat.rowName, seat.number), ('General', 'R3', '12'));
  });
}
