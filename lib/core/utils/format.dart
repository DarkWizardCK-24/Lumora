import 'package:intl/intl.dart';

String fmtMinutes(num m) {
  final v = m.round();
  if (v < 60) return '${v}m';
  final h = v ~/ 60, r = v % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

String fmtHours(num minutes) => (minutes / 60).toStringAsFixed(1);

String fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String fmtDateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);

String humanDuration(num minutes) {
  final m = minutes.round();
  if (m < 60) return '$m min';
  final h = m / 60;
  return '${h.toStringAsFixed(h == h.roundToDouble() ? 0 : 1)} h';
}

String shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

String fmtDuration(num minutes) => humanDuration(minutes);

/// "9 PM" or "21:00", matching the user's 24-hour preference.
String fmtHourOfDay(int hour, {bool use24h = false}) {
  if (use24h) return '${hour.toString().padLeft(2, '0')}:00';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h ${hour < 12 ? 'AM' : 'PM'}';
}
