import 'package:booking_mobile/api/models.dart';
import 'package:booking_mobile/theme.dart';
import 'package:booking_mobile/widgets/seat_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpMap(WidgetTester tester, List<Seat> seats, List<int> selected) async {
  tester.view.physicalSize = const Size(412 * 2, 620 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: bookingTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SeatMap(seats: seats, selected: selected, onToggle: (_) {}),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a plain block of seats wraps, with no section heading', (tester) async {
    final seats = [
      for (var n = 0; n < 24; n++)
        Seat(id: n + 1, label: 'R${n ~/ 8 + 1}-${n % 8 + 1}', priceCents: 2500, status: 'available'),
    ];
    await pumpMap(tester, seats, const [3, 4, 12]);
    await expectLater(find.byType(SeatMap), matchesGoldenFile('images/seat_map_plain.png'));
  });

  testWidgets('a venue layout is drawn as sections', (tester) async {
    const layout = [('Orchestra', 'AB', 9000), ('Balcony', 'C', 4000)];
    var id = 0;
    final seats = [
      for (final (section, rows, price) in layout)
        for (final row in rows.split(''))
          for (var n = 1; n <= 9; n++)
            Seat(
              id: ++id,
              label: '$row-$n',
              priceCents: price,
              status: 'available',
              section: section,
              row: row,
              number: n,
            ),
    ];
    await pumpMap(tester, seats, const [4, 5]);
    await expectLater(find.byType(SeatMap), matchesGoldenFile('images/seat_map_sections.png'));
  });
}
