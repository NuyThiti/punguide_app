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

/// A single `("HH:mm", "HH:mm")` out of one of Google's own worded hours
/// lines — `"วันจันทร์: 10:00–20:00"`. Null for anything that does not look
/// like exactly that: closed that day, open 24 hours, or a format this did
/// not anticipate — a guess here would read as real data to whoever sees it
/// next.
(String, String)? openCloseFromLine(String line) {
  final clock = RegExp(r'(\d{1,2}):(\d{2})').allMatches(line).toList();
  if (clock.length < 2) return null;
  String at(RegExpMatch m) => '${m.group(1)!.padLeft(2, '0')}:${m.group(2)!}';
  return (at(clock[0]), at(clock[1]));
}

/// Today's pair out of Google's own worded hours —
/// `["วันจันทร์: 10:00–20:00", ...]`, Monday through Sunday regardless of
/// locale, the same order `DateTime.weekday` counts in.
///
/// Null when the list is not the standard seven lines, on top of whatever
/// [openCloseFromLine] already refuses to guess at.
(String, String)? todayOpenCloseText(List<String> weekdayDescriptions) {
  if (weekdayDescriptions.length != 7) return null;
  return openCloseFromLine(weekdayDescriptions[DateTime.now().weekday - 1]);
}

/// Monday first, the order Google's `weekdayDescriptions` comes in.
const _thaiDaysShort = <String>['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

/// Google's seven worded lines, grouped into runs of days that share hours —
/// `"จ - อา : 06.00 - 14.30 น."`, or
/// `"จ - ศ : 09.00 - 18.00 น. · ส - อา : 10.00 - 16.00 น."` when they differ.
///
/// With [only], a day counts only when its hours are exactly that pair. That
/// is how the writer's own hours get their days: the days are printed only
/// where Google agrees with what the writer said, never invented around it.
///
/// Null when the list is not the standard seven lines or no day qualifies —
/// a closed day, "open 24 hours" and anything [openCloseFromLine] cannot read
/// are simply left out of the runs rather than guessed at.
String? weeklyHoursText(
  List<String> weekdayDescriptions, {
  (String, String)? only,
}) {
  if (weekdayDescriptions.length != 7) return null;

  final pairs = <(String, String)?>[
    for (final line in weekdayDescriptions)
      switch (openCloseFromLine(line)) {
        final pair? when only == null || pair == only => pair,
        _ => null,
      },
  ];

  final runs = <String>[];
  var i = 0;
  while (i < 7) {
    final pair = pairs[i];
    if (pair == null) {
      i++;
      continue;
    }
    var end = i;
    while (end + 1 < 7 && pairs[end + 1] == pair) {
      end++;
    }
    final days = i == end
        ? _thaiDaysShort[i]
        : '${_thaiDaysShort[i]} - ${_thaiDaysShort[end]}';
    runs.add('$days : ${hoursRangeText(pair.$1, pair.$2)}');
    i = end + 1;
  }
  return runs.isEmpty ? null : runs.join(' · ');
}
