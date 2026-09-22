import '../extensions/currency_extensions.dart';

/// How a content spot's extras read on screen: its hours, the way there, and
/// the hour the writer went.
///
/// The composer collects these as `TimeOfDay`s and the viewer reads them back
/// off the wire as `HH:mm`, so the formatting works on the wire shape and both
/// sides call these rather than each phrasing "06.00 - 14.30 น." its own way.

/// "06.00 - 14.30 น.", or null when neither hour was given.
///
/// An em dash stands in for a missing half — a place can record only the hour
/// it opens. [closesAt] earlier than [opensAt] is not an error: a bar that
/// opens 18:00 and closes 02:00 reads exactly like that.
String? hoursRangeText(String? opensAt, String? closesAt) {
  if (opensAt == null && closesAt == null) return null;
  final from = opensAt == null ? '—' : opensAt.replaceAll(':', '.');
  final to = closesAt == null ? '—' : closesAt.replaceAll(':', '.');
  return '$from - $to น.';
}

/// "6:00 AM" from a 24-hour `HH:mm`. Returns the input unchanged when it is
/// not a clock, so a surprise from the server shows rather than disappears.
String clock12Text(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]);
  if (hour == null) return hhmm;
  final period = hour < 12 ? 'AM' : 'PM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display:${parts[1]} $period';
}

/// "MRT · เดิน ฿100", dropping whichever half is missing.
String transportText(List<String> modes, double? cost) {
  final joined = modes.join(' · ');
  if (cost == null) return joined;
  if (joined.isEmpty) return cost.asBaht;
  return '$joined ${cost.asBaht}';
}

/// The one time a spot shows: the hour the writer went if they said, else the
/// place's own hours. Empty when it has neither.
String spotTimeText({
  String? visitedAt,
  String? opensAt,
  String? closesAt,
}) {
  if (visitedAt != null) return clock12Text(visitedAt);
  return hoursRangeText(opensAt, closesAt) ?? '';
}
