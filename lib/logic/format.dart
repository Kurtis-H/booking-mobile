/// 2500 -> "$25.00". Written by hand so it needs no intl package.
String formatCents(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final dollars = (abs ~/ 100).toString();
  final rest = (abs % 100).toString().padLeft(2, '0');
  final grouped = StringBuffer();
  for (var i = 0; i < dollars.length; i++) {
    final fromRight = dollars.length - i;
    grouped.write(dollars[i]);
    if (fromRight > 1 && fromRight % 3 == 1) grouped.write(',');
  }
  return '${negative ? '-' : ''}\$$grouped.$rest';
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// "Sat, Jan 2, 2027, 7:00 PM" in the device's time zone (or UTC when asked).
String formatDateTime(DateTime when, {bool utc = false}) {
  final t = utc ? when.toUtc() : when.toLocal();
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.hour < 12 ? 'AM' : 'PM';
  return '${_days[t.weekday - 1]}, ${_months[t.month - 1]} ${t.day}, ${t.year}, $hour12:$minute $period';
}

/// "1 seat", "3 seats".
String pluralize(int count, String word) => '$count $word${count == 1 ? '' : 's'}';

/// Time left as "9:41". Never negative.
String formatCountdown(Duration left) {
  final total = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}
