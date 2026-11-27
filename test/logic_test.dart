import 'package:booking_mobile/api/booking_api.dart';
import 'package:booking_mobile/api/models.dart';
import 'package:booking_mobile/logic/errors.dart';
import 'package:booking_mobile/logic/format.dart';
import 'package:booking_mobile/logic/planted_bug.dart';
import 'package:booking_mobile/logic/selection.dart';
import 'package:flutter_test/flutter_test.dart';

Seat seat(int id, String label, [int price = 1000]) =>
    Seat(id: id, label: label, priceCents: price, status: 'available');

void main() {
  group('formatCents', () {
    for (final (cents, text) in [
      (2500, r'$25.00'),
      (0, r'$0.00'),
      (5, r'$0.05'),
      (123456, r'$1,234.56'),
      (100000000, r'$1,000,000.00'),
      (-250, r'-$2.50'),
    ]) {
      test('$cents -> $text', () => expect(formatCents(cents), text));
    }
  });

  test('formatDateTime in UTC', () {
    expect(formatDateTime(DateTime.utc(2027, 1, 2, 19), utc: true), 'Sat, Jan 2, 2027, 7:00 PM');
    expect(formatDateTime(DateTime.utc(2027, 1, 4, 0, 5), utc: true), 'Mon, Jan 4, 2027, 12:05 AM');
    expect(formatDateTime(DateTime.utc(2027, 1, 4, 12), utc: true), 'Mon, Jan 4, 2027, 12:00 PM');
  });

  test('pluralize', () {
    expect(pluralize(1, 'seat'), '1 seat');
    expect(pluralize(0, 'seat'), '0 seats');
    expect(pluralize(3, 'seat'), '3 seats');
  });

  group('toggleSeat', () {
    test('adds and removes', () {
      expect(toggleSeat([1], 2).selected, [1, 2]);
      expect(toggleSeat([1, 2, 3], 2).selected, [1, 3]);
    });

    test('does not change the list it was given', () {
      final before = [1];
      toggleSeat(before, 2);
      expect(before, [1]);
    });

    test('refuses an 11th seat and says why', () {
      final ten = List.generate(10, (i) => i + 1);
      final result = toggleSeat(ten, 99);
      expect(result.selected, ten);
      expect(result.error, 'You can buy up to 10 seats in one order.');
    });

    test('still unselects at the limit', () {
      expect(toggleSeat(List.generate(10, (i) => i + 1), 10).selected, hasLength(9));
    });
  });

  test('totalCents adds selected seats and ignores unknown ids', () {
    final seats = [seat(1, 'R1-1', 2500), seat(2, 'R1-2', 2500), seat(3, 'R2-1', 3000)];
    expect(totalCents(seats, [1, 3]), 5500);
    expect(totalCents(seats, []), 0);
    expect(totalCents(seats, [2, 404]), 2500);
  });

  test('the planted bug switch is off in normal builds', () {
    final seats = [seat(1, 'R1-1', 2500), seat(2, 'R1-2', 3000)];
    expect(plantedBug, isEmpty);
    expect(totalCents(seats, [1, 2]), 5500);
  });

  test("the planted 'total' bug counts only the first seat", () {
    final seats = [seat(1, 'R1-1', 2500), seat(2, 'R1-2', 3000)];
    expect(totalCents(seats, [1, 2], bug: 'total'), 2500);
    expect(totalCents(seats, [], bug: 'total'), 0);
    expect(totalCents(seats, [1, 2], bug: 'other'), 5500);
  });

  test('groupByRow keeps first-seen row order', () {
    final rows = groupByRow([seat(1, 'R1-1'), seat(2, 'R2-1'), seat(3, 'R1-2'), seat(4, 'A')]);
    expect(rows.keys, ['R1', 'R2', 'A']);
    expect(rows['R1']!.map((s) => s.id), [1, 3]);
  });

  group('orderErrorMessage', () {
    test('per status', () {
      expect(orderErrorMessage(const ApiException(409, 'x')), contains('Someone just took'));
      expect(orderErrorMessage(const ApiException(404, 'x')), contains('no longer exists'));
      expect(orderErrorMessage(const ApiException(401, 'x')), contains('sign in again'));
      expect(orderErrorMessage(const ApiException(500, 'x')), contains('Something went wrong'));
      expect(orderErrorMessage(const ApiException(0, 'x')), contains("You're offline"));
      expect(orderErrorMessage(StateError('x')), contains('Something went wrong'));
    });

    test('rate limits say how long to wait', () {
      expect(
        orderErrorMessage(const ApiException(429, 'x', retryAfterSeconds: 7)),
        'Too many requests. Please wait 7 seconds and try again.',
      );
      expect(orderErrorMessage(const ApiException(429, 'x')), contains('wait a moment'));
    });
  });

  test('loadErrorMessage', () {
    expect(loadErrorMessage(const ApiException(404, 'x')), "We couldn't find that.");
    expect(loadErrorMessage(const ApiException(0, 'x')), contains("You're offline"));
    expect(loadErrorMessage(Exception('x')), contains('try again'));
  });
}
