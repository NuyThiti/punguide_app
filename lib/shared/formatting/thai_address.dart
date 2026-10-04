/// Reading a Thai address well enough to name the place it is in.
///
/// Lives here rather than inside one feature because two of them need the same
/// answer from the same strings: the post composer fills a post's
/// `destination` with it, and Ai Chat uses it to say which province it is
/// looking around. One parser means they can never disagree about what
/// "เขตพระนคร กรุงเทพมหานคร 10200" is called.

/// The province an address ends in — "เชียงใหม่", "กรุงเทพมหานคร" — or null
/// when nothing in it is usable.
///
/// This now fills the post's `destination`, so it has to be a name a reader
/// recognises. Two shapes have to survive it, and Google answers with both:
///
///  * comma-separated, as it writes English — "…, Phra Nakhon, Bangkok 10200,
///    Thailand" — where the last segment is the country and the one before it
///    the city;
///  * one unbroken run of words, as it writes Thai, with no commas at all —
///    "ถนน ราชดำเนินกลาง แขวงพระบรมมหาราชวัง เขตพระนคร กรุงเทพมหานคร 10200".
///    There the postcode is the anchor and the word in front of it is the
///    province; with no postcode, the last word is.
///
/// A place with no street number of its own is led by a Plus Code, which is a
/// coordinate in disguise and must never be what a post says it was about.
String? localityOf(String? address) {
  final text = _withoutPlusCode((address ?? '').trim()).trim();
  if (text.isEmpty) return null;

  final parts = text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  if (parts.length > 1) {
    final city = parts[parts.length - 2].replaceAll(_postcode, '').trim();
    return city.isEmpty ? null : city;
  }
  return _provinceInRun(parts.first);
}

/// The province inside one unbroken run of words. See [localityOf].
String? _provinceInRun(String run) {
  // The last match, not the first: a house number can be five digits too, and
  // the postcode is always near the end.
  final postcodes = _postcode.allMatches(run);
  final head = postcodes.isEmpty ? run : run.substring(0, postcodes.last.start);
  final words = head.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  return words.isEmpty ? null : words.last;
}

/// Drops a leading Plus Code, keeping whatever the segment says after it.
String _withoutPlusCode(String part) => part.replaceFirst(_plusCode, '');

final _postcode = RegExp(r'\b\d{4,6}\b');

/// Open Location Code: four to eight characters of its own alphabet, a plus,
/// then two or three more — "QF4V+88R", "7P88+5C".
final _plusCode = RegExp(
    r'^\s*[23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,3}\b',
    caseSensitive: false);
