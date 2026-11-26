import 'package:booking_mobile/api/models.dart';
import 'package:booking_mobile/widgets/seat_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seat map with three seats selected', (tester) async {
    final seats = [
      for (var n = 0; n < 24; n++)
        Seat(id: n + 1, label: 'R${n ~/ 8 + 1}-${n % 8 + 1}', priceCents: 2500, status: 'available'),
    ];
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2448A8)), useMaterial3: true),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SeatMap(seats: seats, selected: const [3, 4, 12], onToggle: (_) {}),
          ),
        ),
      ),
    );
    await expectLater(find.byType(SeatMap), matchesGoldenFile('goldens/seat_map.png'));
  });
}
