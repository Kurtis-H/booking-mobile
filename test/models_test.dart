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
}
