import 'package:material_ui/material_ui.dart';

import '../theme.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A ticket-stub date: month over day, on white. Decoration only; the full
/// date is written out next to it, so screen readers skip it.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.when});
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final local = when.toLocal();
    return ExcludeSemantics(
      child: Container(
        width: 54,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _months[local.month - 1],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Palette.muted),
            ),
            Text(
              '${local.day}',
              style: const TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
