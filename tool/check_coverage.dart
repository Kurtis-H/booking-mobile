// Fails if line coverage of lib/ (excluding main.dart) is below the minimum.
// Usage: dart run tool/check_coverage.dart coverage/lcov.info 80
import 'dart:io';

void main(List<String> args) {
  final file = File(args.isNotEmpty ? args[0] : 'coverage/lcov.info');
  final minimum = double.parse(args.length > 1 ? args[1] : '80');
  var found = 0;
  var hit = 0;
  var include = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll(r'\', '/');
      include = path.contains('lib/') && !path.endsWith('lib/main.dart');
    } else if (include && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (include && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }
  final percent = found == 0 ? 0.0 : hit * 100 / found;
  stdout.writeln('Line coverage: ${percent.toStringAsFixed(1)}% ($hit/$found), minimum $minimum%');
  if (percent < minimum) exit(1);
}
